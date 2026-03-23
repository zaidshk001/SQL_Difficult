/*
==========================================================
Project: Amazon SQL Interview Practice Case Study
Author: Zaid Shaikh
Database: sql_practice
Purpose:
This project simulates real-world Amazon-style SQL interview 
questions covering aggregation, window functions, ranking,
anti-joins, anomaly detection, and time-series edge cases.
==========================================================
*/

-- ==========================================================
-- DATABASE SETUP
-- ==========================================================

CREATE DATABASE IF NOT EXISTS sql_practice;
USE sql_practice;

-- ==========================================================
-- TABLE CREATION
-- ==========================================================

CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(50),
    signup_date DATE
);

CREATE TABLE products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(50),
    category VARCHAR(50)
);

CREATE TABLE purchases (
    purchase_id INT PRIMARY KEY,
    customer_id INT,
    product_id INT,
    purchase_date DATE
);

CREATE TABLE sales (
    sale_id INT PRIMARY KEY,
    store_id INT,
    product_id INT,
    sale_amount DECIMAL(10,2),
    sale_date DATE
);

CREATE TABLE order_details (
    order_id INT,
    product_id INT
);

CREATE TABLE employees (
    employee_id INT PRIMARY KEY,
    name VARCHAR(50),
    manager_id INT,
    department_id INT,
    salary DECIMAL(10,2)
);

CREATE TABLE deliveries (
    supplier_id INT,
    order_date DATE,
    delivery_date DATE,
    quantity INT
);

CREATE TABLE orders (
    order_id INT PRIMARY KEY,
    customer_id INT,
    order_date DATE
);

CREATE TABLE agent_logs (
    log_id INT PRIMARY KEY,
    agent_id INT,
    login_time DATETIME,
    logout_time DATETIME
);

-- ==========================================================
-- DATA INSERTION
-- ==========================================================

INSERT INTO customers VALUES
(1,'Zaid','2025-01-10'),
(2,'Aisha','2025-02-15'),
(3,'Rahul','2025-03-01'),
(4,'Sara','2025-04-20'),
(5,'Omar','2025-05-05'),
(6,'Neha','2025-06-12');

INSERT INTO products VALUES
(101,'iPhone','Electronics'),
(102,'Laptop','Electronics'),
(103,'Headphones','Electronics'),
(201,'Shirt','Clothing'),
(202,'Jeans','Clothing'),
(301,'Blender','Home'),
(302,'Microwave','Home');

INSERT INTO purchases VALUES
(1,1,101,'2026-01-05'),
(2,1,201,'2026-01-10'),
(3,1,301,'2026-01-15'),
(4,2,101,'2026-01-05'),
(5,2,102,'2026-01-05'),
(6,2,201,'2026-02-01'),
(7,3,101,'2025-08-01'),
(8,3,102,'2025-09-01'),
(9,4,101,'2026-02-01'),
(10,4,201,'2026-02-10'),
(11,4,301,'2026-02-20'),
(12,5,101,'2026-02-01');

INSERT INTO sales VALUES
(1,1,101,1000,'2026-02-01'),
(2,1,101,1200,'2026-02-02'),
(3,1,101,800,'2026-02-03'),
(4,1,201,300,'2026-02-01'),
(5,1,201,500,'2026-02-02'),
(6,2,101,2000,'2026-02-01'),
(7,2,201,400,'2026-02-01'),
(8,2,301,700,'2026-02-02'),
(9,1,101,100,'2026-02-10'),
(10,1,101,5000,'2026-02-11');

INSERT INTO employees VALUES
(1,'John',NULL,1,100000),
(2,'Alice',1,1,70000),
(3,'Bob',1,2,60000),
(4,'Carol',2,1,75000),
(5,'David',NULL,2,90000),
(6,'Eve',5,2,50000),
(7,'Frank',NULL,3,120000);

INSERT INTO deliveries VALUES
(1,'2026-01-01','2026-01-03',200),
(1,'2026-01-05','2026-01-06',150),
(2,'2026-01-01','2026-01-10',50),
(2,'2026-01-05','2026-01-20',300),
(3,'2026-01-01','2026-01-02',500);

INSERT INTO orders VALUES
(1,1,'2026-01-01'),
(2,1,'2026-02-01'),
(3,1,'2026-02-05'),
(4,2,'2026-01-01'),
(5,2,'2026-02-01'),
(6,3,'2025-06-01'),
(7,4,'2026-02-01');

INSERT INTO agent_logs VALUES
(1,101,'2026-02-10 09:00:00','2026-02-10 17:00:00'),
(2,101,'2026-02-10 22:00:00','2026-02-11 02:00:00'),
(3,102,'2026-02-10 10:00:00','2026-02-12 15:00:00'),
(4,103,'2026-02-11 23:30:00','2026-02-12 00:30:00');

-- ==========================================================
-- SAMPLE AMAZON-STYLE QUESTIONS INCLUDED
-- ==========================================================

-- 1. Customers who purchased on exactly 3 days last month

# Method 1
Select
customer_id
From purchases
group by 1
HAVING Min(purchase_date) >= '2026-01-01'
AND MIN(purchase_date) < '2026-02-01'
AND COUNT(Distinct purchase_date) = 3;

# Method 2
Select Max(Order_date) as last_order_date From orders;
SELECT customer_id
FROM purchases
WHERE MONTH(purchase_date) = MONTH('2026-02-05' - INTERVAL 1 MONTH)
  AND YEAR(purchase_date) = YEAR('2026-02-05'- INTERVAL 1 MONTH)
GROUP BY customer_id
HAVING COUNT(DISTINCT purchase_date) = 3;   -- this is less efficient as functions are used in the WHere Clause and index is not happening 

# Method 3
WITH last_month_purchases AS (
    SELECT 
        customer_id,
        purchase_date
    FROM purchases
    WHERE purchase_date BETWEEN 
          DATE_FORMAT(DATE_SUB('2026-02-05', INTERVAL 1 MONTH), '%Y-%m-01')
      AND LAST_DAY(DATE_SUB('2026-02-05', INTERVAL 1 MONTH))
)

SELECT customer_id
FROM last_month_purchases
GROUP BY customer_id
HAVING COUNT(DISTINCT purchase_date) = 3;

-- ==========================================================

-- 2. Top selling product per category

WITH product_sales AS (
    SELECT 
        p.category,
        p.product_name,
        SUM(s.sale_amount) AS total_sales
    FROM products p
    LEFT JOIN sales s 
        ON s.product_id = p.product_id
    GROUP BY p.category, p.product_name
)

SELECT *
FROM (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY category 
               ORDER BY total_sales DESC
           ) AS rank_1
    FROM product_sales
) ranked
WHERE rank_1 = 1;

-- ==========================================================

-- 3. Product-level anomaly detection

# Method 1
Select * from sales;
SELECT *
FROM (
    SELECT *,
           AVG(sale_amount) OVER (PARTITION BY product_id) AS avg_sale
    FROM sales
) t
WHERE sale_amount < avg_sale;

# Method 2
Select     sale_id,
    product_id,
    sale_amount,
    Case 
    When sale_amount < AVG(sale_amount) over (partition by product_id) Then "Anamoly" Else "Good" End as status
    From sales;

-- ==========================================================

-- 4. Find employees who have never been a manager and worked in more than 1 department

With cte as (
Select * From employees Where employee_id NOT IN (
Select  DISTINCT
m.employee_id
From employees e
JOIN employees m
On e.manager_id = m.employee_id)) 

Select employee_id, name
From cte
Group by 1,2
Having COunt(Distinct department_id) > 1;

# Method 2  No need to self join

SELECT employee_id, name
FROM employees
WHERE employee_id NOT IN (
        SELECT DISTINCT manager_id
        FROM employees
        WHERE manager_id IS NOT NULL
)
GROUP BY employee_id, name
HAVING COUNT(DISTINCT department_id) > 1;

-- ==========================================================

-- 5. Median salary per department

with cte as (
Select department_id, salary, Row_number() Over (Partition by department_id Order BY Salary) as rnk,
COUNT(*) over (partition by department_id) as cnt
  From employees)
  
Select department_id, Avg(salary) as median_salary
From cte
Where rnk IN (FLoor(cnt+1)/2, CEIL(cnt+1)/2)
Group by 1;

-- ==========================================================

-- 6. Customers who purchased from all categories

Select customer_id
From purchases p
Left Join products pr
ON p.product_id = pr.product_id
Group by 1
Having COunt(distinct category) = (Select COUNT(distinct category) from products);

-- ==========================================================

-- 7. Calculate the cumulative sales for each store but only include dates where the daily sales exceeded the stores average daily sales 

with cte as(
Select store_id,
sale_date,
sum(sale_amount) as daily_rev
From sales
Group by 1,2),

cte2 AS (
Select *,
AVG(daily_rev) OVER (PARTITION BY store_id) as avg_daily_rev From cte)

Select
store_id, sale_date, daily_rev,
SUM(daily_rev) over (partition by store_id Order by sale_date) as cum_rev
From cte2
Where daily_rev > avg_daily_rev;

-- ==========================================================

-- 8. list employees earning more than dept avg

with cte1 as (
Select department_id, AVG(salary) as dept_avg From employees Group by 1)

Select employee_id from employees e
Join cte1 c on e.department_id = c.department_id
Where salary > dept_avg;

# method 2
SELECT employee_id
FROM (
    SELECT 
        employee_id,
        salary,
        AVG(salary) OVER (PARTITION BY department_id) AS dept_avg
    FROM employees
) t
WHERE salary > dept_avg;

-- ==========================================================

-- 9. identify products that have been sold but have no records in the product table and also calculate how many times each missing product have been sold 
    
Select s.product_id, COUNT(*) as cnt 
from sales s Left JOIN products p on s.product_id = p.product_id 
Where p.product_id is NULL 
Group by 1;

-- ==========================================================

-- 10. Identifies suppliers whose average delivery time is less than 2 days but only consider deliveries with quantities greater than 100 units

SELECT 
    supplier_id
FROM deliveries
WHERE quantity > 100
GROUP BY supplier_id
HAVING AVG(DATEDIFF(delivery_date, order_date)) < 2;

-- ==========================================================

-- 11. find customers who made no purchases last month but made at least one purchase prior to that

Select * from purchases;

# first find out customers who made purchase last month

Select Distinct customer_id From purchases Where customer_id NOT IN (
Select customer_id
From purchases
Where purchase_date Between date_format(date_add('2026-02-15', Interval -1 Month), '%Y-%m-01') 
AND Last_day(date_add('2026-02-15', Interval -1 Month))
)
ANd customer_id IN (purchase_date < date_format(date_add('2026-02-15', Interval -1 Month), '%Y-%m-01') ); # this ANd filters to month prior to last month

-- ==========================================================

-- 12. Calculate the moving average of sales for each product over a 5 day window 

Select * from sales;

Select product_id, sale_date,
AVG(sale_amount) OVER (Partition by product_id Order BY sale_date Rows Between 4 preceding and current row) as moving_avg
From sales
Order by 1,2;

-- ==========================================================

-- 13. rank stores by their monthly sales performance 

Select * from sales;
with cte as (
Select store_id, Year(sale_date) as year, 
Month(sale_date) as month,
SUM(sale_amount) as total_sales
From sales
Group by 1,2,3)

Select
*,
DENSE_RANK() OVER (partition by year, month Order by total_sales Desc) as rnk
from cte;

-- ==========================================================

-- 14. Find customers who place more than 20% of orders last month 

Select customer_id, COUNT(*) from purchases Group by 1 ;

with total_orders as (
Select customer_id, COUNT(*) as total_orders,
SUM(CASE WHEN purchase_date Between date_format(date_add('2026-02-15', Interval -1 Month), '%Y-%m-01') 
AND Last_day(date_add('2026-02-15', Interval -1 Month)) Then 1 ELse 0 ENd) as last_month_orders
From purchases
Group by 1)
Select * from total_orders
WHere last_month_orders > 0.2 * total_orders;

-- ==========================================================

-- 15. Agent login/logout Hours

Select * from agent_logs;
SELECT 
    agent_id,
    DATE(login_time) AS activity_date,
    CASE 
        WHEN DATE(login_time) = DATE(logout_time)
        THEN TIMESTAMPDIFF(SECOND, login_time, logout_time) / 3600.0
        
        ELSE TIMESTAMPDIFF(SECOND, login_time, 
                DATE_ADD(DATE(login_time), INTERVAL 1 DAY)) / 3600.0 # this part strips the time and add i day so it will be midnight 
    END AS online_hours
FROM agent_logs

UNION ALL

SELECT 
    agent_id,
    DATE(logout_time) AS activity_date,
    TIMESTAMPDIFF(SECOND,
        DATE(logout_time), # time is stripped 
        logout_time) / 3600.0 AS online_hours
FROM agent_logs
WHERE DATE(login_time) <> DATE(logout_time);

-- ==========================================================

-- 16. remove the duplicate rows, so rows with identical souce and destination with same price are considered identical

CREATE TABLE routes (
    source VARCHAR(50),
    destination VARCHAR(50),
    price INT
);

INSERT INTO routes VALUES
('mumbai', 'hyderabad', 10000),
('hyderabad', 'mumbai', 10000),
('bangalore', 'chennai', 6000),
('pune', 'kolkata', 8000),
('kolkata', 'pune', 8000),
('mumbai', 'hyderabad', 12000),  -- different price
('chennai', 'bangalore', 6000),  -- reverse duplicate
('delhi', 'goa', 9000);


Select * From routes;

with cte as (
    SELECT 
        CASE 
            WHEN source < destination THEN source 
            ELSE destination 
        END AS source,
        CASE 
            WHEN source < destination THEN destination 
            ELSE source 
        END AS destination,
        price
    FROM routes)
    
Select Distinct *
From cte;

--  method 2
    Select 
    LEAST(source, destination) AS source, -- smaller value 
    GREATEST(source, destination) AS destination, -- larger value
    MIN(price) as price -- If price can differ, we may need GROUP BY and decide which price to keep (MIN/MAX/AVG).
FROM routes
GROUP BY 1,2;

-- ==========================================================

-- 17. /*
Assign each student a grade based on their marks using the grades table.
For students with grade > 7, display:
student name
marks
grade

For students with grade ≤ 7, display:
NULL as student name
marks
grade
*/
-- Grades table (range-based)
CREATE TABLE grades (
    grade INT,
    min_marks INT,
    max_marks INT
);

-- Students table
CREATE TABLE students (
    student VARCHAR(50),
    marks INT
);


-- Insert grade ranges
INSERT INTO grades (grade, min_marks, max_marks) VALUES
(1, 0, 10),
(2, 11, 20),
(3, 21, 30),
(4, 31, 40),
(5, 41, 50),
(6, 51, 60),
(7, 61, 70),
(8, 71, 80),
(9, 81, 90),
(10, 91, 100);


-- Insert students
INSERT INTO students (student, marks) VALUES
('zaid', 90),
('ubed', 70),
('zainab', 60),
('moin', 80),
('zuha', 85);


Select * From grades;
Select * From students;


Select 
Case when grade > 7 Then student Else Null end as student,
marks, grade
From grades g
Join students s
ON s.marks Between g.min_marks ANd g.max_marks
order by 1 Desc;

-- ==========================================================

-- 17. get the top 5 and bottom 5 person based on salary

CREATE TABLE employees1 (
    emp_id INT,
    emp_name VARCHAR(50),
    salary INT
);

INSERT INTO employees1 VALUES
(1, 'A', 50000),
(2, 'B', 70000),
(3, 'C', 30000),
(4, 'D', 90000),
(5, 'E', 40000),
(6, 'F', 80000),
(7, 'G', 20000),
(8, 'H', 100000),
(9, 'I', 60000),
(10, 'J', 25000),
(11, 'K', 75000),
(12, 'L', 35000);
Select *
from (
Select *, row_number() over (order by salary Desc) as top,
row_number() over (order by salary) as bottom
 from employees1
 ) as a
 Where top <= 5 Or bottom <= 5; 
 

-- ==========================================================

-- 18.  /* You are given a table linkedin_users containing employment history of users.

Write a SQL query to find how many users worked at Microsoft and then immediately joined Google next (no company in between). */

CREATE TABLE linkedin_users (
    user_id INT,
    employer VARCHAR(50),
    position VARCHAR(50),
    start_date DATE,
    end_date DATE
);

INSERT INTO linkedin_users VALUES
(1, 'Microsoft', 'SDE', '2020-01-01', '2021-01-01'),
(1, 'Google', 'SDE', '2021-02-01', '2022-01-01'),
(2, 'Microsoft', 'SDE', '2019-01-01', '2020-01-01'),
(2, 'Amazon', 'SDE', '2020-02-01', '2021-01-01'),
(3, 'Microsoft', 'SDE', '2018-01-01', '2019-01-01'),
(3, 'Google', 'SDE', '2019-02-01', '2020-01-01'),
(4, 'Google', 'SDE', '2020-01-01', '2021-01-01');

Select * from linkedin_users;

with cte as(
Select *, Lead(employer) over (partition by user_id order by start_date) as next_employer
From linkedin_users)

Select COUNT(DIstinct user_id) as count
from cte 
Where employer = 'Microsoft'
ANd next_employer = 'Google';

-- ==========================================================

-- 19.  /* Given a friendship table where each row represents a connection:

Find the average number of friends per user.*/

CREATE TABLE google_friends_network (
    user_id INT,
    friend_id INT
);

INSERT INTO google_friends_network VALUES
(1,2),
(2,1),
(1,3),
(3,1),
(2,3),
(3,2),
(4,1);

Select * from google_friends_network;

with cte as (
    SELECT user_id, friend_id FROM google_friends_network
    UNION ALL
    SELECT friend_id AS user_id, user_id AS friend_id 
    FROM google_friends_network),

cte1 as (
Select user_id, COunt(Distinct friend_id) as count
From cte 
Group by 1)

Select
Avg(count) as arpu
From cte1;

-- “We can use LEAST/GREATEST to remove duplicate friendship pairs, but for counting friends per user 
-- we need directional relationships, so UNION is required to ensure each user gets all their connections.”

-- ==========================================================

-- 20.  /*Given match data with Team_1, Team_2, and Winner, generate:
team_name
matches_played
matches_won
matches_lost */

Create table matches (
    team_1 VARCHAR(50),
    team_2 VARCHAR(50),
    winner VARCHAR(50)
);

INSERT INTO matches VALUES
('India', 'SL', 'India'),
('SL', 'Aus', 'Aus'),
('SA', 'Eng', 'Eng'),
('Eng', 'NZ', 'NZ'),
('Aus', 'India', 'India');

Select * from matches;

with cte as (
Select team_1 as team, winner
From matches
Union ALl
Select team_2 as team,
winner
From matches)

Select
team,
COUNT(team) as match_played,
SUM(Case When team = winner then 1 else 0 end) as match_won,
COUNT(team) - SUM(Case When team = winner then 1 else 0 end) as match_lost
from cte
Group by 1
