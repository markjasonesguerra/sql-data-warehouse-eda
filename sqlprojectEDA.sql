

-- PROJECT: SQL Exploratory Data Analysis (EDA)
-- DATABASE: DataWarehouseAnalytics
-- NAME: Mark Jason Esguerra




USE DataWarehouseAnalytics;
GO


-- 1. DATABASE EXPLORATION

-- explore the all object in the DB
SELECT * FROM INFORMATION_SCHEMA.TABLES

SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, TABLE_TYPE 
FROM INFORMATION_SCHEMA.TABLES;


-- explore the all columns in the DB
SELECT * FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'dim_customers'


SELECT * FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'fact_sales'


SELECT * FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'dim_products'


-- view all column names and data types in dim_customers
SELECT COLUMN_NAME, DATA_TYPE 
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'dim_customers';






-- 2. DIMENSION EXPLORATION

-- identify distinct customer geographic locations
SELECT DISTINCT country FROM gold.dim_customers
ORDER by country


SELECT DISTINCT category, subcategory, product_name FROM gold.dim_products
ORDER BY category, subcategory, product_name;


-- list all unique product categories and subcategories
SELECT DISTINCT category, subcategory 
FROM gold.dim_products
ORDER BY category, subcategory;





-- 3. DATE RANGE EXPLORATION

-- identify order date boundaries and duration of sales data
SELECT 
MIN(order_date) first_order,
MAX(order_date) lst_order,
DATEDIFF(year, MIN(order_date), MAX(order_date)) as sales_range_years,
DATEDIFF(month, MIN(order_date), MAX(order_date)) as sales_range_years
FROM gold.fact_sales


-- determine customer age range 
SELECT 
    MIN(birthdate) AS oldest_birthdate,
    DATEDIFF(year, MIN(birthdate), GETDATE()) AS oldest_customer_age,
    MAX(birthdate) AS youngest_birthdate,
    DATEDIFF(year, MAX(birthdate), GETDATE()) AS youngest_customer_age
FROM gold.dim_customers;


-- average delivery delay in days
SELECT 
    AVG(DATEDIFF(day, order_date, shipping_date)) AS avg_shipping_days,
    MAX(DATEDIFF(day, order_date, shipping_date)) AS max_shipping_days
FROM gold.fact_sales;






-- 4. MEASURE EXPLORATION

--find overall total sales
SELECT SUM(sales_amount) as total_sales FROM gold.fact_sales

SELECT 'Total Revenue' AS metric_name, CAST(SUM(sales_amount) AS VARCHAR(50)) AS metric_value FROM gold.fact_sales

-- find how many items are sold
SELECT SUM(quantity) as 'Total Units Sold' FROM gold.fact_sales

-- find the average selling price 
SELECT AVG(price) as 'Average Unit Price' FROM gold.fact_sales

-- find the Total number of Orders
SELECT COUNT(order_number) AS 'Total Orders' FROM gold.fact_sales
SELECT COUNT(DISTINCT order_number) AS 'Total Distinct Orders' FROM gold.fact_sales
select * from gold.fact_sales

-- find the total number of products
SELECT COUNT(product_name) AS 'Total Products Listed' FROM gold.dim_products
SELECT COUNT(DISTINCT product_name) AS 'Total Distinct Products' FROM gold.dim_products

-- find the total number of customers
SELECT COUNT(customer_key) AS 'Total Active Customers' FROM gold.dim_customers;

-- find the total number of customers that has placed an order
SELECT COUNT(DISTINCT customer_key) AS total_customers FROM gold.fact_sales;


-- Consolidated business metrics report
SELECT 'Total Revenue' AS metric_name, CAST(SUM(sales_amount) AS VARCHAR(50)) AS metric_value FROM gold.fact_sales
UNION ALL
SELECT 'Total Units Sold', CAST(SUM(quantity) AS VARCHAR(50)) FROM gold.fact_sales
UNION ALL
SELECT 'Average Unit Price', CAST(AVG(price) AS VARCHAR(50)) FROM gold.fact_sales
UNION ALL
SELECT 'Total Distinct Orders', CAST(COUNT(DISTINCT order_number) AS VARCHAR(50)) FROM gold.fact_sales
UNION ALL
SELECT 'Total Products Listed', CAST(COUNT(product_key) AS VARCHAR(50)) FROM gold.dim_products
UNION ALL
SELECT 'Total Active Customers', CAST(COUNT(DISTINCT customer_key) AS VARCHAR(50)) FROM gold.fact_sales;





-- 5. MAGNITUDE ANALYSIS

-- total customer by country
SELECT country, COUNT(customer_key) as total_customers FROM gold.dim_customers
GROUP BY country
ORDER BY total_customers DESC;


-- total revenue generated per product category
SELECT 
    p.category,
    SUM(f.sales_amount) AS category_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
    ON p.product_key = f.product_key
GROUP BY p.category
ORDER BY category_revenue DESC;


-- order volume distribution by customer country
SELECT 
    c.country,
    SUM(f.quantity) AS total_units_sold
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
    ON c.customer_key = f.customer_key
GROUP BY c.country
ORDER BY total_units_sold DESC;


SELECT
    c.customer_key,
    c.first_name,
    SUM(f.sales_amount) AS 'TOTAL REVENUE' 
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
    ON c.customer_key = f.customer_key
GROUP BY
    c.customer_key,
    c.first_name
ORDER BY 'TOTAL REVENUE'  DESC;

-- average order value and  sales density by category
SELECT 
    p.category,
    COUNT(DISTINCT f.order_number) AS total_orders,
    SUM(f.sales_amount) AS total_revenue,
    AVG(f.sales_amount) AS avg_order_amount
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
    ON p.product_key = f.product_key
GROUP BY p.category
ORDER BY total_revenue DESC;





-- 6: RANKING ANALYSIS

SELECT TOP 10
    p.product_name,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
    ON p.product_key = f.product_key
GROUP BY p.product_name
ORDER BY total_revenue DESC;


--Top 10 products using Window Functions (ROW_NUMBER)
SELECT *
FROM (
    SELECT 
        p.product_name,
        SUM(f.sales_amount) AS total_revenue,
        ROW_NUMBER() OVER (ORDER BY SUM(f.sales_amount) DESC) AS rank_order
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
        ON p.product_key = f.product_key
    GROUP BY p.product_name
) ranked_table
WHERE rank_order <= 10;

-- The 5 customers with the fewest orders placed
SELECT TOP 5
    c.customer_key,
    c.first_name,
    c.last_name,
    COUNT(DISTINCT order_number) AS total_orders
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
    ON c.customer_key = f.customer_key
GROUP BY
    c.customer_key,
    c.first_name,
    c.last_name
ORDER BY total_orders ;

-- Top 20 highest spending customers
SELECT TOP 20
    c.customer_key,
    c.first_name,
    c.last_name,
    SUM(f.sales_amount) AS total_spend
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
    ON c.customer_key = f.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
ORDER BY total_spend DESC;


