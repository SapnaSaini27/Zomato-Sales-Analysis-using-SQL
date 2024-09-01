

drop table if exists goldusers_signup;
CREATE TABLE goldusers_signup(
userid integer,
gold_signup_date date); 

INSERT INTO goldusers_signup(userid,gold_signup_date) 
 VALUES (1,'2017-09-22'),
(3,'2017-04-21');

drop table if exists users;
CREATE TABLE users(
userid integer,
signup_date date); 

INSERT INTO users(userid,signup_date) 
 VALUES (1,'2014-09-02'),
(2,'2015-01-15'),
(3,'2014-04-11');

drop table if exists sales2;
CREATE TABLE sales2(userid integer,
created_date date,
product_id integer); 

INSERT INTO sales2(userid,created_date,product_id) 
 VALUES (1,'2017-04-19',2),
(3,'2019-12-18',1),
(2,'2020-07-20',3),
(1,'2019-10-23',2),
(1,'2018-03-19',3),
(3,'2016-12-20',2),
(1,'2016-11-09',1),
(1,'2016-05-20',3),
(2,'2017-09-24',1),
(1,'2017-03-11',2),
(1,'2016-03-11',1),
(3,'2016-11-10',1),
(3,'2017-12-07',2),
(3,'2016-12-15',2),
(2,'2017-11-08',2),
(2,'2018-09-10',3);


drop table if exists product;
CREATE TABLE product(
product_id integer,
product_name text,
price integer); 

INSERT INTO product(product_id,product_name,price) 
 VALUES
(1,'p1',980),
(2,'p2',870),
(3,'p3',330);

select * from sales2;
select * from product;
select * from goldusers_signup;
select * from users;

-- 1. Total amount each customer spend on zoamto
select s.userid, sum(p.price) total
from sales2 s
join product p
on s.product_id = p.product_id
group by s.userid
order by 2 desc;

-- 2. Days each customer visited zomato
select userid, max(cnt) tot_days_visted
from
(select * , count(*) over(partition by userid order by created_date) cnt
from sales2) a
group by 1;

select userid, count(distinct created_date) cnt
from sales2
group by 1;

-- 3. First product purchased by each customer
select userid, product_id first_product_id
from
(select * , row_number() over(partition by userid order by created_date) rn
from sales2) a
where rn = 1;

-- 4. Most purchased item on the menu and how many times was it purchased by all customers

select userid, count(product_id) tot_cnt
from sales2
where product_id =
(select product_id
from (select s.*
from sales2 s
join product p
on s.product_id = p.product_id) a
group by 1
order by count(product_id) desc
limit 1)
group by 1;

-- 5. Which item was the most popular for each customers

select distinct userid, max(cnt)
from 
(
select *, count(product_id) over(partition by userid, product_id order by userid) cnt
from sales2) a
group by 1;

select userid, product_id
from(
select userid, product_id,cnt, dense_rank() over(partition by userid order by cnt desc) as rnk
from (
select userid, product_id, count(product_id) cnt
from sales2
group by 1,2
order by 1, count(product_id) desc) a) b
where rnk = 1;

-- 6. Which item was purchased first by the customer after they become a member

select *
from (
select s.*, gu.gold_signup_date, rank() over(partition by userid order by created_date) rnk
from sales2 s
join goldusers_signup gu
on s.userid = gu.userid
where created_date >= gold_signup_date ) a
where rnk  = 1;

-- 7. Which item was purchased just before the customer become a member

select *
from(
select s.*, gu.gold_signup_date, rank() over(partition by userid order by created_date desc) rnk
from sales2 s
join goldusers_signup gu
on s.userid = gu.userid
where created_date <=  gold_signup_date) a
where rnk = 1;

-- 8. What are total orders and amount spent for each customer before they become a member

select s.userid, count(s.product_id) cnt, sum(price) tot_price
from sales2 s
join goldusers_signup gu
on s.userid = gu.userid
join product p
on s.product_id = p.product_id
where created_date < gold_signup_date
group by 1;

-- 9. Calcualte point collected by each customers and for which product most points have been given till now.
-- Each product has different purchasing points like for p1 5rs = 1 zomato point, for p2 10rs = 5 zomato point,for p3 5rs = 1 zomato point
-- If buying each product generates points like 5rs = 2 zomato points

select *, tot_points*(5/2) total_savings_using_points
from
(select userid, sum(a.zomato_points) tot_points
from (
select s.*, p.price,
case when s.product_id = 1 or s.product_id = 3 then round(price*(1/5))
when s.product_id = 2 then round(price*(5/10)) end as zomato_points
from sales2 s
join product p
on s.product_id = p.product_id) as a
group by 1) b; 

select product_id, sum(zomato_points) tol_points
from(
select s.*, p.price,
case when s.product_id = 1 or s.product_id = 3 then round(price*(1/5))
when s.product_id = 2 then round(price*(5/10)) end as zomato_points
from sales2 s
join product p
on s.product_id = p.product_id) as a
group by 1
order by sum(zomato_points) desc
limit 1;

-- 10. In the first one year after a customer joined the gold program (including their join date) irrespective
-- of what the customer has purchased they earn 5 zomato points for every 10 rs spent who earned more points between 1 and 3

select userid, sum(tot_points) total_pt
from(
select s.userid,created_date, gold_signup_date, round(price*(5/10)) tot_points
from sales2 s
join goldusers_signup gu
on s.userid = gu.userid and 
created_date >= gold_signup_date and datediff(created_date, gold_signup_date) <=365
join product p
on s.product_id = p.product_id) a
group by 1
order by total_pt desc;

-- 11. rank all the transaction for each customers

select s.*, price, dense_rank() over(partition by userid order by created_date) rnk
from sales2 s
join product p
on s.product_id = p.product_id;

-- 12. rank all the transaction for each customers whenever they are a zomato gold member, for non-zomato member transaction mark as na

select *, 
case when gold_signup_date is null then "NA"
else dense_rank() over(partition by userid order by created_date desc) end as rnk
from
(select s.userid, created_date, gold_signup_date
from sales2 s
left join goldusers_signup gu
on s.userid = gu.userid and created_date>= gold_signup_date) a


