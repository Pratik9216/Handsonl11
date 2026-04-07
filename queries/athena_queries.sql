-- ============================================================
-- AWS Athena SQL Queries — Hands-On Lab 11
-- Dataset: Amazon Sales Report (amazon_sales table)
-- All queries apply LIMIT 10 where applicable
-- ============================================================


-- ============================================================
-- Query 1 — Basic Table Exploration
-- Retrieves the first 10 records from the table
-- ============================================================
SELECT *
FROM amazon_sales
LIMIT 10;


-- ============================================================
-- Query 2 — Orders by Product Category
-- Returns count of each product category along with the
-- total number of orders placed in that category
-- ============================================================
SELECT
    category,
    COUNT(*) AS total_orders
FROM amazon_sales
GROUP BY category
ORDER BY total_orders DESC
LIMIT 10;


-- ============================================================
-- Query 3 — Revenue and Quantity by Fulfilment Method
-- Returns each fulfilment method with its total number of
-- orders, total units sold, and total revenue — excluding
-- cancelled and pending orders — sorted by highest revenue first
-- ============================================================
SELECT
    fulfilment,
    COUNT(*)                    AS total_orders,
    SUM(qty)                    AS total_units_sold,
    ROUND(SUM(amount), 2)       AS total_revenue
FROM amazon_sales
WHERE LOWER(status) NOT IN ('cancelled', 'pending', 'pending - waiting for pick up')
GROUP BY fulfilment
ORDER BY total_revenue DESC
LIMIT 10;


-- ============================================================
-- Query 4 — Monthly Sales Trend
-- Returns each month with total orders and total revenue,
-- excluding cancelled and pending orders,
-- sorted chronologically from earliest to latest
-- ============================================================
SELECT
    DATE_TRUNC('month', DATE_PARSE(date, '%m-%d-%y'))   AS sales_month,
    COUNT(*)                                              AS total_orders,
    ROUND(SUM(amount), 2)                                AS total_revenue
FROM amazon_sales
WHERE LOWER(status) NOT IN ('cancelled', 'pending', 'pending - waiting for pick up')
GROUP BY DATE_TRUNC('month', DATE_PARSE(date, '%m-%d-%y'))
ORDER BY sales_month ASC
LIMIT 10;


-- ============================================================
-- Query 5 — Top 5 Best-Selling SKUs per Category
-- Returns the top 5 SKUs in each product category ranked by
-- total revenue, showing category, SKU, total revenue,
-- total units sold, and rank — excluding cancelled, pending,
-- and zero-quantity orders
-- ============================================================
WITH sku_revenue AS (
    SELECT
        category,
        sku,
        ROUND(SUM(amount), 2)   AS total_revenue,
        SUM(qty)                AS total_units_sold,
        ROW_NUMBER() OVER (
            PARTITION BY category
            ORDER BY SUM(amount) DESC
        )                       AS rnk
    FROM amazon_sales
    WHERE LOWER(status) NOT IN ('cancelled', 'pending', 'pending - waiting for pick up')
      AND qty > 0
    GROUP BY category, sku
)
SELECT
    category,
    sku,
    total_revenue,
    total_units_sold,
    rnk AS rank
FROM sku_revenue
WHERE rnk <= 5
ORDER BY category, rnk
LIMIT 10;
