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
