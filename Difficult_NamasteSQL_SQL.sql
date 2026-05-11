CREATE SCHEMA namaste_sql;

use namaste_sql;
-- ============================================================
-- 203 - The Revenue Leakage
-- Category - Analytics
-- Extreme Hard - 75 Points
-- ============================================================

/*
You work at a SaaS company that sells software licenses to enterprise clients.
Each client has a contracted price agreed upon at the time of signing.
However, the actual invoices raised each month sometimes differ from the contracted price — either due to discounts,
billing errors, or unapproved price changes.

The finance team wants to identify revenue leakage — cases where clients are being billed less than their contracted
price consistently over time.

The Ask
Find all contracts where the client was billed less than the contracted amount for 3 or more consecutive months.

For each such contract return:
  contract_id
  client_id
  consecutive_months — the maximum streak of consecutive under-billed months
  totalLeakage — total shortfall (contracted_amount - invoice_amount) across the entire contract, not just the streak
  first_leakage_date — invoice date when the leakage streak first started
  last_leakage_date — invoice date when the longest streak ended

Constraints & Traps
  A month within the contract window where no invoice was raised also counts as under-billing
  (leakage = full contracted_amount)
  A contract can have multiple leakage streaks — report only the longest one
  If two streaks are equally long, report the earliest one
  invoice_amount can never exceed contracted_amount in this dataset
*/

----------------------------------------------------------
-- CREATE CONTRACTS TABLE
----------------------------------------------------------

CREATE TABLE contracts (
    contract_id       INT PRIMARY KEY,
    client_id         INT,
    contracted_amount INT,
    start_date        DATE,
    end_date          DATE
);

----------------------------------------------------------
-- CREATE INVOICES TABLE
----------------------------------------------------------

CREATE TABLE invoices (
    invoice_id     INT PRIMARY KEY,
    contract_id    INT,
    invoice_amount INT,
    invoice_date   DATE
);

----------------------------------------------------------
-- INSERT CONTRACTS
----------------------------------------------------------

INSERT INTO contracts VALUES
(1, 101, 1000, '2024-01-01', '2024-06-30'),
(2, 102, 2000, '2024-01-01', '2024-06-30'),
(3, 103, 1500, '2024-01-01', '2024-06-30'),
(4, 104, 1200, '2024-01-01', '2024-06-30'),
(5, 105, 1800, '2024-01-01', '2024-06-30'),
(6, 106, 2500, '2024-01-01', '2024-06-30');

----------------------------------------------------------
-- INSERT INVOICES
----------------------------------------------------------

INSERT INTO invoices VALUES

-- CONTRACT 1: 4 consecutive leakage months
(1,  1, 1000, '2024-01-01'),
(2,  1,  900, '2024-02-01'),
(3,  1,  850, '2024-03-01'),
(4,  1,  800, '2024-04-01'),
(5,  1,  750, '2024-05-01'),
(6,  1, 1000, '2024-06-01'),

-- CONTRACT 2: leakage but NOT consecutive enough
(7,  2, 1800, '2024-01-01'),
(8,  2, 2000, '2024-02-01'),
(9,  2, 1700, '2024-03-01'),
(10, 2, 2000, '2024-04-01'),
(11, 2, 1600, '2024-05-01'),
(12, 2, 2000, '2024-06-01'),

-- CONTRACT 3: missing invoice counts as FULL leakage (February missing)
(13, 3, 1500, '2024-01-01'),
(14, 3, 1200, '2024-03-01'),
(15, 3, 1100, '2024-04-01'),
(16, 3, 1000, '2024-05-01'),
(17, 3, 1500, '2024-06-01'),

-- CONTRACT 4: two equal streaks — earliest streak should win
(18, 4, 1000, '2024-01-01'),
(19, 4, 1000, '2024-02-01'),
(20, 4,  900, '2024-03-01'),
(21, 4,  800, '2024-04-01'),
(22, 4,  700, '2024-05-01'),
(23, 4, 1200, '2024-06-01'),

-- CONTRACT 5: ALL months leakage
(24, 5, 1500, '2024-01-01'),
(25, 5, 1600, '2024-02-01'),
(26, 5, 1700, '2024-03-01'),
(27, 5, 1400, '2024-04-01'),
(28, 5, 1300, '2024-05-01'),
(29, 5, 1200, '2024-06-01'),

-- CONTRACT 6: no leakage
(30, 6, 2500, '2024-01-01'),
(31, 6, 2500, '2024-02-01'),
(32, 6, 2500, '2024-03-01'),
(33, 6, 2500, '2024-04-01'),
(34, 6, 2500, '2024-05-01'),
(35, 6, 2500, '2024-06-01');

----------------------------------------------------------
-- FINAL QUERY
----------------------------------------------------------

-- Step 1: Generate all months within each contract window using a recursive CTE,
--         because a missing invoice month is treated as full leakage.

WITH RECURSIVE months AS (

    SELECT
        contract_id,
        client_id,
        contracted_amount,
        start_date AS month_date,
        end_date
    FROM contracts

    UNION ALL

    SELECT
        contract_id,
        client_id,
        contracted_amount,
        DATE_ADD(month_date, INTERVAL 1 MONTH),
        end_date
    FROM months
    WHERE DATE_ADD(month_date, INTERVAL 1 MONTH) < end_date
),

-- Step 2: Left-join with invoices to expose missing months and flag leakage rows.
base AS (
    SELECT
        m.contract_id,
        client_id,
        contracted_amount,
        month_date,
        COALESCE(invoice_amount, 0) AS invoice_amount,
        CASE
            WHEN invoice_amount IS NULL
              OR invoice_amount < contracted_amount THEN 1
            ELSE 0
        END AS leakage
    FROM months m
    LEFT JOIN invoices i
        ON  m.contract_id  = i.contract_id
        AND month_date     = invoice_date
    ORDER BY m.contract_id, client_id, month_date, invoice_date
),

-- Step 3: Build streak groups using the classic ROW_NUMBER gap technique.
grp AS (
    SELECT
        *,
        DATE_ADD(
            month_date,
            INTERVAL -ROW_NUMBER() OVER (PARTITION BY contract_id ORDER BY month_date) MONTH
        ) AS grp
    FROM base
    WHERE leakage = 1
),

-- Step 4: Collapse each streak into one row.
streaks AS (
    SELECT
        contract_id,
        client_id,
        MIN(month_date) AS first_leakage_date,
        MAX(month_date) AS last_leakage_date,
        COUNT(*)        AS consecutive_months
    FROM grp
    GROUP BY 1, 2, grp
),

-- Step 5: Rank streaks per contract — longest first, earliest on tie.
ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY contract_id
            ORDER BY consecutive_months DESC, first_leakage_date
        ) AS rn
    FROM streaks
)

-- Final Output
SELECT
    r.contract_id,
    r.client_id,
    r.consecutive_months,
    (
        SELECT SUM(contracted_amount - invoice_amount)
        FROM   base b
        WHERE  b.contract_id = r.contract_id
          AND  leakage = 1
    ) AS totalLeakage,
    r.first_leakage_date,
    r.last_leakage_date
FROM ranked r
WHERE rn = 1
  AND consecutive_months >= 3;


-- ============================================================
-- 204 - The Silent Bestsellers
-- Category - Analytics
-- Medium - 20 Points
-- ============================================================

/*
You work at a retail analytics company managing data for a chain of stores across multiple cities.
The product team wants to identify "Silent Bestsellers" — products that are among the top 3 best-selling
products by revenue in their category, but have never been promoted or discounted in any way.
The idea is simple — these products sell well purely on merit, with no marketing push.
The business wants to reward these products with premium shelf placement.
*/

---------------------------------------------------------
-- CREATE SALES TABLE
---------------------------------------------------------

CREATE TABLE sales (
    sale_id    INT PRIMARY KEY,
    product_id INT,
    category   VARCHAR(50),
    store_id   INT,
    sale_date  DATE,
    quantity   INT,
    unit_price DECIMAL(10, 2)
);

---------------------------------------------------------
-- CREATE PROMOTIONS TABLE
---------------------------------------------------------

CREATE TABLE promotions (
    promo_id   INT PRIMARY KEY,
    product_id INT,
    promo_type VARCHAR(50),
    start_date DATE,
    end_date   DATE
);

---------------------------------------------------------
-- INSERT SALES DATA
---------------------------------------------------------

INSERT INTO sales VALUES

-- ELECTRONICS
(1,  101, 'Electronics', 1, '2024-01-01', 5, 1000),
(2,  101, 'Electronics', 2, '2024-01-03', 4, 1000),
(3,  101, 'Electronics', 1, '2024-01-05', 6, 1000),
(4,  102, 'Electronics', 1, '2024-01-02', 8,  900),
(5,  102, 'Electronics', 2, '2024-01-06', 7,  900),
(6,  103, 'Electronics', 1, '2024-01-01', 3, 1500),
(7,  103, 'Electronics', 2, '2024-01-04', 2, 1500),
(8,  104, 'Electronics', 1, '2024-01-03', 10, 800),
(9,  104, 'Electronics', 2, '2024-01-07',  9, 800),

-- GROCERY
(10, 201, 'Grocery', 1, '2024-01-01', 20, 50),
(11, 201, 'Grocery', 2, '2024-01-02', 18, 50),
(12, 202, 'Grocery', 1, '2024-01-03', 25, 40),
(13, 202, 'Grocery', 2, '2024-01-05', 20, 40),
(14, 203, 'Grocery', 1, '2024-01-04', 15, 60),
(15, 203, 'Grocery', 2, '2024-01-06', 12, 60),
(16, 204, 'Grocery', 1, '2024-01-07', 30, 35),
(17, 204, 'Grocery', 2, '2024-01-08', 28, 35),

-- FASHION
(18, 301, 'Fashion', 1, '2024-01-01', 12, 500),
(19, 301, 'Fashion', 2, '2024-01-04', 10, 500),
(20, 302, 'Fashion', 1, '2024-01-02', 15, 450),
(21, 302, 'Fashion', 2, '2024-01-05', 14, 450),
(22, 303, 'Fashion', 1, '2024-01-03',  8, 700),
(23, 303, 'Fashion', 2, '2024-01-07',  9, 700),
(24, 304, 'Fashion', 1, '2024-01-06', 18, 400),
(25, 304, 'Fashion', 2, '2024-01-08', 16, 400),

-- STORE 3 ADDITIONS
(26, 101, 'Electronics', 3, '2024-01-10',  5, 1000),
(27, 102, 'Electronics', 3, '2024-01-11',  7,  900),
(28, 104, 'Electronics', 3, '2024-01-12',  8,  800),
(29, 201, 'Grocery',     3, '2024-01-10', 20,   50),
(30, 202, 'Grocery',     3, '2024-01-11', 25,   40),
(31, 204, 'Grocery',     3, '2024-01-12', 35,   35),
(32, 301, 'Fashion',     3, '2024-01-10', 12,  500),
(33, 302, 'Fashion',     3, '2024-01-11', 15,  450),
(34, 304, 'Fashion',     3, '2024-01-12', 20,  400);

---------------------------------------------------------
-- INSERT PROMOTION DATA
---------------------------------------------------------

INSERT INTO promotions VALUES
(1, 102, 'Discount',       '2024-01-01', '2024-01-10'),
(2, 103, 'BOGO',           '2024-01-05', '2024-01-15'),
(3, 202, 'Discount',       '2024-01-01', '2024-01-20'),
(4, 301, 'Festival Offer', '2024-01-01', '2024-01-07'),
(5, 303, 'Clearance',      '2024-01-03', '2024-01-12');

---------------------------------------------------------
-- FINAL QUERY
---------------------------------------------------------

WITH cte AS (
    -- Products that have never been in any promotion
    SELECT DISTINCT product_id
    FROM   sales s
    WHERE  NOT EXISTS (
        SELECT 1
        FROM   promotions p
        WHERE  s.product_id = p.product_id
    )
),

cte1 AS (
    -- Revenue summary for unpromoted products sold in at least 2 stores
    SELECT
        s.product_id,
        category,
        SUM(quantity * unit_price)  AS total_revenue,
        COUNT(DISTINCT store_id)    AS stores_sold_in,
        MIN(sale_date)              AS first_sale_date,
        MAX(sale_date)              AS last_sale_date
    FROM   cte c
    JOIN   sales s ON c.product_id = s.product_id
    GROUP  BY 1, 2
    HAVING COUNT(DISTINCT store_id) >= 2
)

SELECT
    product_id,
    category,
    total_revenue,
    rnk,
    stores_sold_in,
    first_sale_date,
    last_sale_date
FROM (
    SELECT
        *,
        DENSE_RANK() OVER (PARTITION BY category ORDER BY total_revenue DESC) AS rnk
    FROM cte1
) AS a
WHERE  rnk <= 3
ORDER BY product_id;


-- ============================================================
-- 205 - The Comeback Customers
-- Category - Analytics
-- Hard - 40 Points
-- ============================================================

/*
You work at an e-commerce company. The marketing team wants to identify "Comeback Customers" —
customers who had a period of inactivity (no orders for 60 or more days) and then came back to purchase again.
The team wants to understand their buying behaviour before and after the comeback.

The Ask
Find all comeback customers and return one row per customer:
  customer_id
  gap_days               — the longest gap (in days) between any two consecutive orders
  orders_before_comeback — number of orders placed before the gap
  orders_after_comeback  — number of orders placed after the gap
  spend_before_comeback  — total amount spent before the gap

Constraints & Traps
  Only consider customers who have placed at least 2 orders
  Gap is measured between consecutive orders sorted by date
  If a customer has multiple gaps >= 60 days, report only the longest gap
  If two gaps are equal in length, pick the earliest one
  Customers with no gap >= 60 days should not appear in the result
  orders_before_comeback and orders_after_comeback are split at the longest gap
*/

---------------------------------------------------------
-- CREATE TABLE
---------------------------------------------------------

CREATE TABLE orders (
    order_id      INT PRIMARY KEY,
    customer_id   INT,
    order_date    DATE,
    order_amount  INT
);

---------------------------------------------------------
-- INSERT DATA
---------------------------------------------------------

INSERT INTO orders VALUES

-- CUSTOMER 101: longest gap = 99 days — qualifies
(1,  101, '2024-01-01', 100),
(2,  101, '2024-01-15', 200),
(3,  101, '2024-02-01', 300),
(4,  101, '2024-05-10', 400),
(5,  101, '2024-05-25', 500),

-- CUSTOMER 102: no gap >= 60 — should NOT appear
(6,  102, '2024-01-01', 150),
(7,  102, '2024-01-20', 200),
(8,  102, '2024-02-10', 250),
(9,  102, '2024-03-01', 300),

-- CUSTOMER 103: multiple qualifying gaps — longest should be selected
(10, 103, '2024-01-01', 100),
(11, 103, '2024-02-01', 150),  -- 31 days
(12, 103, '2024-05-01', 200),  -- 90 days
(13, 103, '2024-05-20', 250),  -- 19 days
(14, 103, '2024-09-01', 300),  -- 104 days (LONGEST)
(15, 103, '2024-09-10', 350),

-- CUSTOMER 104: exactly 60-day gap — qualifies
(16, 104, '2024-01-01', 500),
(17, 104, '2024-03-01', 600),

-- CUSTOMER 105: only one order — should NOT appear
(18, 105, '2024-01-01', 700),

-- CUSTOMER 106: equal gaps — earliest one should win
(19, 106, '2024-01-01', 100),
(20, 106, '2024-03-01', 150),  -- 60 days
(21, 106, '2024-04-01', 200),  -- 31 days
(22, 106, '2024-06-01', 250),  -- 61 days
(23, 106, '2024-06-15', 300),

-- CUSTOMER 107: very long comeback gap
(24, 107, '2024-01-01', 1000),
(25, 107, '2024-01-10', 1100),
(26, 107, '2024-12-01', 1200),

-- CUSTOMER 108: consecutive small gaps only
(27, 108, '2024-01-01', 100),
(28, 108, '2024-01-15', 100),
(29, 108, '2024-01-30', 100),
(30, 108, '2024-02-14', 100),

-- CUSTOMER 109: multiple gaps, same longest twice — earliest should win
(31, 109, '2024-01-01', 100),
(32, 109, '2024-03-15', 150),  -- 74 days
(33, 109, '2024-04-01', 200),
(34, 109, '2024-06-14', 250),  -- 74 days again
(35, 109, '2024-07-01', 300),

-- CUSTOMER 110: gap just below threshold — should NOT appear
(36, 110, '2024-01-01', 100),
(37, 110, '2024-02-28', 200);  -- 58 days

---------------------------------------------------------
-- FINAL QUERY
---------------------------------------------------------

WITH cte AS (
    SELECT
        *,
        LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date) AS previous_order_date
    FROM orders
),

cte1 AS (
    SELECT
        *,
        DATEDIFF(order_date, previous_order_date) AS gap_days
    FROM cte
    WHERE previous_order_date IS NOT NULL
),

ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY gap_days DESC, order_date
        ) AS rnk
    FROM cte1
    WHERE gap_days >= 60
)

SELECT
    r.customer_id,
    gap_days,
    (
        SELECT COUNT(*)
        FROM   orders o
        WHERE  o.customer_id = r.customer_id
          AND  o.order_date  < r.previous_order_date
    ) AS orders_before_comeback,
    (
        SELECT COUNT(*)
        FROM   orders o
        WHERE  o.customer_id = r.customer_id
          AND  o.order_date  > r.previous_order_date
    ) AS orders_after_comeback,
    (
        SELECT SUM(order_amount)
        FROM   orders o
        WHERE  o.customer_id = r.customer_id
          AND  o.order_date  < r.previous_order_date
    ) AS spend_before_comeback,
    order_date AS comeback_date
FROM ranked r
WHERE rnk = 1;


-- ============================================================
-- 206 - The Shift Handover Problem
-- Category - Analytics
-- ============================================================

/*
You work at a 24/7 logistics company that operates in shifts. Each shift has an opening stock count and a
closing stock count for a warehouse. The closing stock of one shift should match the opening stock of the next shift.
When they don't match, it indicates a handover discrepancy — stock went missing or was incorrectly recorded
during the shift change.

The operations team wants to identify all discrepancies, understand their impact, and flag the worst handover
per warehouse.

The Ask
Find all handover discrepancies and return one row per discrepancy:
  warehouse_id
  outgoing_shift_id  — the shift that closed
  incoming_shift_id  — the shift that opened next
  closing_stock      — closing stock of outgoing shift
  opening_stock      — opening stock of incoming shift
  discrepancy        — difference (opening_stock - closing_stock), negative means stock missing
  gap_minutes        — minutes between shift end and next shift start
  discrepancy_type   — "shortage" if discrepancy < 0, "surplus" if discrepancy > 0
  is_worst_handover  — "Y" if this is the largest absolute discrepancy in the warehouse, "N" otherwise

Constraints & Traps
  Only compare shifts consecutive within the same warehouse
  Skip terminal shifts (no next shift)
  Skip clean handovers (closing_stock = opening_stock)
  gap_minutes can be 0 or positive
*/

-- =========================================
-- CREATE TABLE
-- =========================================

CREATE TABLE shifts (
    shift_id      INT PRIMARY KEY,
    warehouse_id  INT,
    shift_start   DATETIME,
    shift_end     DATETIME,
    opening_stock INT,
    closing_stock INT
);

-- =========================================
-- INSERT SAMPLE DATA
-- =========================================

INSERT INTO shifts VALUES

-- WAREHOUSE 1
(1,  1, '2024-05-01 06:00:00', '2024-05-01 14:00:00', 100, 95),   -- clean handover -> NOT appear
(2,  1, '2024-05-01 14:00:00', '2024-05-01 22:00:00',  90, 110),  -- shortage (-5)
(3,  1, '2024-05-01 22:30:00', '2024-05-02 06:00:00', 120, 130),  -- surplus (+10)
(4,  1, '2024-05-02 06:00:00', '2024-05-02 14:00:00', 130, 125),  -- clean handover -> NOT appear
(5,  1, '2024-05-02 14:30:00', '2024-05-02 22:00:00', 125, 140),  -- terminal shift -> NOT appear

-- WAREHOUSE 2
(6,  2, '2024-05-01 08:00:00', '2024-05-01 16:00:00', 200, 180),  -- surplus (+15)
(7,  2, '2024-05-01 16:00:00', '2024-05-02 00:00:00', 195, 210),
(8,  2, '2024-05-02 00:30:00', '2024-05-02 08:00:00', 190, 170),  -- worst shortage (-20)
(9,  2, '2024-05-02 08:00:00', '2024-05-02 16:00:00', 150, 160),
(10, 2, '2024-05-02 16:30:00', '2024-05-03 00:00:00', 160, 175),  -- clean handover
(11, 2, '2024-05-03 00:00:00', '2024-05-03 08:00:00', 175, 180);  -- terminal shift

-- =========================================
-- FINAL QUERY
-- =========================================

WITH cte AS (
    SELECT
        warehouse_id,
        shift_id AS outgoing_shift_id,
        shift_start,
        shift_end,
        closing_stock,
        LEAD(shift_id)      OVER (PARTITION BY warehouse_id ORDER BY shift_start) AS incoming_shift_id,
        LEAD(shift_start)   OVER (PARTITION BY warehouse_id ORDER BY shift_start) AS incoming_shift_start,
        LEAD(opening_stock) OVER (PARTITION BY warehouse_id ORDER BY shift_start) AS incoming_shift_stock
    FROM shifts
),

discrepancy AS (
    SELECT
        warehouse_id,
        outgoing_shift_id,
        closing_stock,
        shift_end,
        incoming_shift_id,
        incoming_shift_stock,
        incoming_shift_start,
        (incoming_shift_stock - closing_stock) AS discrepancy,
        TIMESTAMPDIFF(MINUTE, shift_end, incoming_shift_start) AS gap_minutes
    FROM cte
)

SELECT
    warehouse_id,
    outgoing_shift_id,
    incoming_shift_id,
    closing_stock,
    incoming_shift_stock AS opening_stock,
    discrepancy,
    gap_minutes,
    CASE
        WHEN discrepancy < 0 THEN 'shortage'
        ELSE 'surplus'
    END AS discrepancy_type,
    CASE
        WHEN ABS(discrepancy) = MAX(ABS(discrepancy)) OVER (PARTITION BY warehouse_id)
        THEN 'Y'
        ELSE 'N'
    END AS is_worst_handover
FROM discrepancy
WHERE incoming_shift_start IS NOT NULL
  AND closing_stock <> incoming_shift_stock;


-- ============================================================
-- 207 - The Ticket Escalation Trap
-- Category - Analytics
-- ============================================================

/*
You work at a SaaS customer support company. Support tickets are raised by customers and assigned to agents.
Tickets can be escalated from one agent to another when the current agent cannot resolve them.
Each escalation is logged with a timestamp.

The Ask
Find all tickets in an "Escalation Trap" and return one row per ticket:
  ticket_id
  customer_id
  priority
  escalation_count           — total number of escalations for this ticket
  total_hours_open           — hours since ticket was created until now (use '2024-06-01 00:00:00' as current time)
  avg_hours_per_escalation   — average hours spent at each escalation level
  most_frequent_escalator    — from_agent_id who escalated this ticket the most.
                               If two or more agents escalated equally many times, pick the one with the lowest agent_id
  current_agent_id           — the to_agent_id of the most recent escalation (currently holding the ticket)

Constraints & Traps
  Only include tickets with status = 'open'
  Only include tickets escalated 3 or more times
  If two agents escalated equally, pick the one with the lower agent_id
  avg_hours_per_escalation = total_hours_open / escalation_count, rounded to 2 decimal places
  A ticket can be escalated to the same agent multiple times
*/

-- =========================
-- CREATE TABLES
-- =========================

CREATE TABLE tickets (
    ticket_id   INT PRIMARY KEY,
    customer_id INT,
    created_at  DATETIME,
    status      VARCHAR(20),
    priority    VARCHAR(20)
);

CREATE TABLE escalations (
    escalation_id INT PRIMARY KEY,
    ticket_id     INT,
    from_agent_id INT,
    to_agent_id   INT,
    escalated_at  DATETIME
);

-- =========================
-- INSERT DATA INTO tickets
-- =========================

INSERT INTO tickets VALUES
(1, 101, '2024-05-20 08:00:00', 'open',   'high'),
(2, 102, '2024-05-22 10:00:00', 'open',   'medium'),
(3, 103, '2024-05-25 09:30:00', 'closed', 'low'),
(4, 104, '2024-05-27 11:00:00', 'open',   'critical'),
(5, 105, '2024-05-29 14:00:00', 'open',   'high');

-- =========================
-- INSERT DATA INTO escalations
-- =========================

INSERT INTO escalations VALUES

-- Ticket 1: qualifies (4 escalations, open)
(1,  1, 201, 202, '2024-05-20 10:00:00'),
(2,  1, 202, 203, '2024-05-21 09:00:00'),
(3,  1, 201, 204, '2024-05-22 12:00:00'),
(4,  1, 201, 205, '2024-05-23 15:00:00'),

-- Ticket 2: qualifies (3 escalations, open)
--           tie between agent 301 and 302 — lower agent_id wins
(5,  2, 301, 302, '2024-05-22 11:00:00'),
(6,  2, 302, 303, '2024-05-23 13:00:00'),
(7,  2, 301, 304, '2024-05-24 16:00:00'),

-- Ticket 3: should NOT appear (closed ticket)
(8,  3, 401, 402, '2024-05-25 11:00:00'),
(9,  3, 402, 403, '2024-05-26 10:00:00'),
(10, 3, 403, 404, '2024-05-27 09:00:00'),

-- Ticket 4: should NOT appear (< 3 escalations)
(11, 4, 501, 502, '2024-05-27 12:00:00'),
(12, 4, 502, 503, '2024-05-28 14:00:00'),

-- Ticket 5: qualifies — same agent escalates multiple times
(13, 5, 601, 602, '2024-05-29 15:00:00'),
(14, 5, 601, 603, '2024-05-29 18:00:00'),
(15, 5, 602, 604, '2024-05-30 10:00:00'),
(16, 5, 601, 605, '2024-05-31 09:00:00');

-- =========================
-- FINAL QUERY
-- =========================

WITH cte AS (
    SELECT
        t.ticket_id,
        customer_id,
        created_at,
        priority,
        escalation_id,
        from_agent_id,
        to_agent_id,
        escalated_at,
        COUNT(escalation_id) OVER (PARTITION BY t.ticket_id)                           AS escalation_count,
        ROW_NUMBER()         OVER (PARTITION BY t.ticket_id ORDER BY escalated_at DESC) AS escalation_rnk
    FROM tickets t
    JOIN escalations e ON t.ticket_id = e.ticket_id
    WHERE status = 'open'
),

freq_cte AS (
    SELECT
        ticket_id,
        from_agent_id,
        COUNT(*) AS cnt,
        ROW_NUMBER() OVER (
            PARTITION BY ticket_id
            ORDER BY COUNT(*) DESC, from_agent_id
        ) AS agent_rnk
    FROM cte
    GROUP BY 1, 2
)

SELECT
    c.ticket_id,
    customer_id,
    priority,
    escalation_count,
    ROUND(TIMESTAMPDIFF(HOUR, created_at, '2024-06-01 00:00:00'), 2)                               AS total_hours_open,
    ROUND(TIMESTAMPDIFF(HOUR, created_at, '2024-06-01 00:00:00') / c.escalation_count, 2)          AS avg_hours_per_escalation,
    f.from_agent_id                                                                                 AS most_frequent_escalator,
    c.to_agent_id                                                                                   AS current_agent_id
FROM cte c
JOIN freq_cte f
    ON  c.ticket_id = f.ticket_id
    AND f.agent_rnk = 1
WHERE escalation_rnk = 1
  AND escalation_count >= 3;