-- PROJECT: SQL Exploratory Data Analysis (EDA)
-- DATABASE: DataWarehouseAnalytics
-- AUTHOR: Mark Jason Esguerra

USE DataWarehouseAnalytics;
GO


-- =============================================================================
-- 01. DATABASE EXPLORATION
-- Purpose: Inspect database tables, views, and system metadata to understand
--          the schema layout before writing analytical queries.
-- =============================================================================

-- List all tables and views available in the database
SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, TABLE_TYPE 
FROM INFORMATION_SCHEMA.TABLES;

-- Check column names, data types, and text length limits for dim_customers
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'dim_customers';

-- Check column definitions for dim_products
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'dim_products';

-- Check column definitions for fact_sales
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'fact_sales';


-- =============================================================================
-- 02. DIMENSION EXPLORATION
-- Purpose: Explore categorical values (countries, categories, subcategories)
--          to check data uniqueness and business hierarchies.
-- =============================================================================

-- Get all unique countries where customers are based
SELECT DISTINCT country 
FROM gold.dim_customers
ORDER BY country;

-- View the full product hierarchy: category -> subcategory -> product name
SELECT DISTINCT category, subcategory, product_name 
FROM gold.dim_products
ORDER BY category, subcategory, product_name;

-- Quick high-level list of distinct product categories and subcategories
SELECT DISTINCT category, subcategory 
FROM gold.dim_products
ORDER BY category, subcategory;


-- =============================================================================
-- 03. DATE RANGE EXPLORATION
-- Purpose: Determine the overall historical date span of sales data, calculate
--          customer age ranges, and evaluate operational shipping lead times.
-- =============================================================================

-- Check first and latest order dates to measure overall sales duration
SELECT 
    MIN(order_date) AS first_order_date,
    MAX(order_date) AS latest_order_date,
    -- DATEDIFF calculates difference between two dates in years and months
    DATEDIFF(year, MIN(order_date), MAX(order_date)) AS sales_span_years,
    DATEDIFF(month, MIN(order_date), MAX(order_date)) AS sales_span_months
FROM gold.fact_sales;

-- Determine oldest and youngest customer ages based on birthdate
SELECT 
    MIN(birthdate) AS oldest_birthdate,
    DATEDIFF(year, MIN(birthdate), GETDATE()) AS max_customer_age,
    MAX(birthdate) AS youngest_birthdate,
    DATEDIFF(year, MAX(birthdate), GETDATE()) AS min_customer_age
FROM gold.dim_customers;

-- Check average shipping turnaround time and count deliveries that breached due date (SLA)
SELECT 
    AVG(DATEDIFF(day, order_date, shipping_date)) AS avg_shipping_days,
    MAX(DATEDIFF(day, order_date, shipping_date)) AS max_shipping_days,
    -- Count rows where actual delivery happened after the promised due date
    COUNT(CASE WHEN shipping_date > due_date THEN 1 END) AS late_deliveries
FROM gold.fact_sales
WHERE shipping_date IS NOT NULL;


-- =============================================================================
-- 04. MEASURE EXPLORATION
-- Purpose: Aggregate top-level metrics across fact and dimension tables into
--          a single executive KPI summary table.
-- =============================================================================

-- Consolidated scorecard combining core business measures using UNION ALL
SELECT 'Total Revenue' AS kpi_metric, CAST(SUM(sales_amount) AS VARCHAR(50)) AS kpi_value FROM gold.fact_sales
UNION ALL
SELECT 'Total Units Sold', CAST(SUM(quantity) AS VARCHAR(50)) FROM gold.fact_sales
UNION ALL
SELECT 'Average Unit Price', CAST(AVG(price) AS VARCHAR(50)) FROM gold.fact_sales
UNION ALL
-- COUNT(DISTINCT) ensures duplicate order numbers are only counted once
SELECT 'Total Orders Placed', CAST(COUNT(DISTINCT order_number) AS VARCHAR(50)) FROM gold.fact_sales
UNION ALL
SELECT 'Total Products Available', CAST(COUNT(product_key) AS VARCHAR(50)) FROM gold.dim_products
UNION ALL
SELECT 'Total Active Buyers', CAST(COUNT(DISTINCT customer_key) AS VARCHAR(50)) FROM gold.fact_sales;


-- =============================================================================
-- 05. MAGNITUDE ANALYSIS
-- Purpose: Compare volume, revenue, and customer counts across different
--          dimensions using GROUP BY and LEFT JOIN.
-- =============================================================================

-- Customer distribution by country (identifying primary geographic markets)
SELECT 
    country, 
    COUNT(customer_key) AS customer_count
FROM gold.dim_customers
GROUP BY country
ORDER BY customer_count DESC;

-- Revenue, unit volume, and average order amount per product category
SELECT 
    p.category,
    COUNT(DISTINCT f.order_number) AS order_count,
    SUM(f.quantity) AS units_sold,
    SUM(f.sales_amount) AS category_revenue,
    AVG(f.sales_amount) AS avg_ticket_size
FROM gold.fact_sales f
-- LEFT JOIN ensures all sales records match back to their product details
LEFT JOIN gold.dim_products p
    ON p.product_key = f.product_key
GROUP BY p.category
ORDER BY category_revenue DESC;

-- Total quantity of products shipped to each customer country
SELECT 
    c.country,
    SUM(f.quantity) AS total_units_sold
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
    ON c.customer_key = f.customer_key
GROUP BY c.country
ORDER BY total_units_sold DESC;


-- =============================================================================
-- 06. RANKING ANALYSIS
-- Purpose: Identify top and bottom performers for products and customers
--          using TOP, RANK(), and DENSE_RANK() window functions.
-- =============================================================================

-- Top 10 revenue-generating products using simple TOP
SELECT TOP 10
    p.product_name,
    SUM(f.sales_amount) AS total_sales
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
    ON p.product_key = f.product_key
GROUP BY p.product_name
ORDER BY total_sales DESC;

-- Top 10 products using DENSE_RANK() to handle ties cleanly without skipping rank numbers
SELECT *
FROM (
    SELECT 
        p.product_name,
        SUM(f.sales_amount) AS total_sales,
        DENSE_RANK() OVER (ORDER BY SUM(f.sales_amount) DESC) AS sales_rank
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
        ON p.product_key = f.product_key
    GROUP BY p.product_name
) ranked_items
WHERE sales_rank <= 10;

-- 5 worst-selling products (starting from dim_products with COALESCE to include items with 0 sales)
SELECT TOP 5
    p.product_name,
    COALESCE(SUM(f.sales_amount), 0) AS total_sales
FROM gold.dim_products p
LEFT JOIN gold.fact_sales f
    ON p.product_key = f.product_key
GROUP BY p.product_name
ORDER BY total_sales ASC;

-- Top 10 highest-spending customers
SELECT TOP 10
    c.customer_key,
    c.first_name,
    c.last_name,
    SUM(f.sales_amount) AS total_spent
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
    ON c.customer_key = f.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
ORDER BY total_spent DESC;


-- =============================================================================
-- 07. CHANGE OVER TIME ANALYSIS
-- Purpose: Analyze sales performance and customer trends across months and
--          years to detect seasonality and growth patterns.
-- =============================================================================

-- Sales trend by year and month using standard date functions
SELECT
    YEAR(order_date) AS sales_year,
    MONTH(order_date) AS sales_month,
    SUM(sales_amount) AS monthly_sales,
    COUNT(DISTINCT customer_key) AS unique_buyers,
    SUM(quantity) AS units_sold
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date), MONTH(order_date)
ORDER BY sales_year, sales_month;

-- Grouping by month using DATETRUNC (keeps proper date sorting without string conversion issues)
SELECT
    DATETRUNC(month, order_date) AS month_bucket,
    SUM(sales_amount) AS monthly_revenue,
    COUNT(DISTINCT customer_key) AS unique_buyers,
    SUM(quantity) AS units_sold
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(month, order_date)
ORDER BY month_bucket;


-- =============================================================================
-- 08. CUMULATIVE ANALYSIS
-- Purpose: Compute running totals and moving averages to track progressive
--          growth over time.
-- =============================================================================

-- Monthly sales with a running total that resets at the start of each year (PARTITION BY YEAR)
SELECT
    sales_month,
    monthly_sales,
    -- PARTITION BY resets the sum at year boundaries; ORDER BY makes it accumulate row by row
    SUM(monthly_sales) OVER (PARTITION BY YEAR(sales_month) ORDER BY sales_month) AS ytd_running_sales
FROM (
    SELECT
        DATETRUNC(month, order_date) AS sales_month,
        SUM(sales_amount) AS monthly_sales
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATETRUNC(month, order_date)
) monthly_data;

-- Overall running total of sales and moving average unit price across years
SELECT
    sales_year,
    yearly_sales,
    -- OVER (ORDER BY ...) without PARTITION accumulates across the entire historical timeline
    SUM(yearly_sales) OVER (ORDER BY sales_year) AS overall_cumulative_sales,
    AVG(avg_unit_price) OVER (ORDER BY sales_year) AS moving_avg_price
FROM (
    SELECT
        DATETRUNC(year, order_date) AS sales_year,
        SUM(sales_amount) AS yearly_sales,
        AVG(price) AS avg_unit_price
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATETRUNC(year, order_date)
) yearly_data;


-- =============================================================================
-- 09. PERFORMANCE ANALYSIS (YEAR-OVER-YEAR & BENCHMARKING)
-- Purpose: Evaluate annual product performance by comparing current sales
--          against historical product averages and previous year sales using LAG().
-- =============================================================================

WITH product_annual_sales AS (
    SELECT
        YEAR(f.order_date) AS order_year,
        p.product_name,
        SUM(f.sales_amount) AS current_year_sales
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
        ON f.product_key = p.product_key
    WHERE f.order_date IS NOT NULL
    GROUP BY YEAR(f.order_date), p.product_name
)
SELECT
    order_year,
    product_name,
    current_year_sales,
    
    -- Benchmark against the product's historical average sales across all years
    AVG(current_year_sales) OVER (PARTITION BY product_name) AS historical_avg_sales,
    current_year_sales - AVG(current_year_sales) OVER (PARTITION BY product_name) AS diff_from_avg,
    CASE
        WHEN current_year_sales > AVG(current_year_sales) OVER (PARTITION BY product_name) THEN 'Above Average'
        WHEN current_year_sales < AVG(current_year_sales) OVER (PARTITION BY product_name) THEN 'Below Average'
        ELSE 'On Par'
    END AS avg_status,
    
    -- Year-over-Year comparison: LAG grabs sales from the preceding year for the same product
    LAG(current_year_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS prior_year_sales,
    current_year_sales - LAG(current_year_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS yoy_growth,
    CASE
        WHEN current_year_sales > LAG(current_year_sales) OVER (PARTITION BY product_name ORDER BY order_year) THEN 'Growth'
        WHEN current_year_sales < LAG(current_year_sales) OVER (PARTITION BY product_name ORDER BY order_year) THEN 'Decline'
        ELSE 'Flat'
    END AS yoy_status
FROM product_annual_sales
ORDER BY product_name, order_year;


-- =============================================================================
-- 10. PART-TO-WHOLE ANALYSIS
-- Purpose: Calculate the percentage share of total revenue generated by each
--          product category relative to the overall company revenue.
-- =============================================================================

WITH category_totals AS (
    SELECT
        p.category,
        SUM(f.sales_amount) AS category_revenue
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
        ON p.product_key = f.product_key
    GROUP BY p.category
)
SELECT
    category,
    category_revenue,
    -- SUM() OVER() without parameters computes total revenue across all rows
    SUM(category_revenue) OVER () AS grand_total_revenue,
    -- Cast to float first to avoid integer division truncation
    ROUND((CAST(category_revenue AS FLOAT) / SUM(category_revenue) OVER ()) * 100, 2) AS revenue_share_pct
FROM category_totals
ORDER BY category_revenue DESC;


-- =============================================================================
-- 11. DATA SEGMENTATION ANALYSIS
-- Purpose: Group products into pricing tiers and segment customers into
--          spending/loyalty tiers using conditional CASE logic.
-- =============================================================================

-- Segment products into price brackets based on unit cost
WITH product_cost_brackets AS (
    SELECT
        product_key,
        product_name,
        cost,
        CASE
            WHEN cost < 100 THEN 'Budget (< $100)'
            WHEN cost BETWEEN 100 AND 500 THEN 'Mid-Tier ($100-$500)'
            WHEN cost BETWEEN 500 AND 1000 THEN 'Premium ($500-$1000)'
            ELSE 'Ultra High End (> $1000)'
        END AS cost_bracket
    FROM gold.dim_products
)
SELECT
    cost_bracket,
    COUNT(product_key) AS total_products
FROM product_cost_brackets
GROUP BY cost_bracket
ORDER BY total_products DESC;

-- Segment customers into VIP, Regular, and New based on active lifespan and spend
WITH customer_profiles AS (
    SELECT
        c.customer_key,
        SUM(f.sales_amount) AS total_spending,
        MIN(f.order_date) AS first_order_date,
        MAX(f.order_date) AS last_order_date,
        DATEDIFF(month, MIN(f.order_date), MAX(f.order_date)) AS tenure_months
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_customers c
        ON f.customer_key = c.customer_key
    GROUP BY c.customer_key
)
SELECT
    customer_tier,
    COUNT(customer_key) AS total_customers
FROM (
    SELECT
        customer_key,
        -- VIP: customers active 12+ months spending over 5000
        CASE
            WHEN tenure_months >= 12 AND total_spending > 5000 THEN 'VIP'
            WHEN tenure_months >= 12 AND total_spending <= 5000 THEN 'Regular'
            ELSE 'New / Casual'
        END AS customer_tier
    FROM customer_profiles
) segmented
GROUP BY customer_tier
ORDER BY total_customers DESC;


-- =============================================================================
-- 12. CUSTOMER REPORT VIEW
-- Purpose: Create an enterprise reporting view consolidating customer profiles,
--          demographic age brackets, loyalty tiers, recency, and average spend KPIs.
-- =============================================================================

IF OBJECT_ID('gold.report_customers', 'V') IS NOT NULL
    DROP VIEW gold.report_customers;
GO

CREATE VIEW gold.report_customers AS
WITH customer_base AS (
    SELECT
        f.order_number,
        f.product_key,
        f.order_date,
        f.sales_amount,
        f.quantity,
        c.customer_key,
        c.customer_number,
        CONCAT(c.first_name, ' ', c.last_name) AS full_name,
        DATEDIFF(year, c.birthdate, GETDATE()) AS customer_age
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_customers c
        ON c.customer_key = f.customer_key
    WHERE f.order_date IS NOT NULL
),
customer_summary AS (
    SELECT
        customer_key,
        customer_number,
        full_name,
        customer_age,
        COUNT(DISTINCT order_number) AS total_orders,
        SUM(sales_amount) AS total_sales,
        SUM(quantity) AS total_units_bought,
        COUNT(DISTINCT product_key) AS distinct_products_bought,
        MAX(order_date) AS latest_order_date,
        DATEDIFF(month, MIN(order_date), MAX(order_date)) AS tenure_months
    FROM customer_base
    GROUP BY
        customer_key,
        customer_number,
        full_name,
        customer_age
)
SELECT
    customer_key,
    customer_number,
    full_name,
    customer_age,
    -- Group age into demographic tiers
    CASE
        WHEN customer_age IS NULL THEN 'Unknown'
        WHEN customer_age < 20 THEN 'Under 20'
        WHEN customer_age BETWEEN 20 AND 29 THEN '20-29'
        WHEN customer_age BETWEEN 30 AND 39 THEN '30-39'
        WHEN customer_age BETWEEN 40 AND 49 THEN '40-49'
        ELSE '50+'
    END AS age_bracket,
    -- Group into loyalty and revenue segments
    CASE
        WHEN tenure_months >= 12 AND total_sales > 5000 THEN 'VIP'
        WHEN tenure_months >= 12 AND total_sales <= 5000 THEN 'Regular'
        ELSE 'New'
    END AS customer_segment,
    latest_order_date,
    -- Recency: number of months since customer last made a purchase
    DATEDIFF(month, latest_order_date, GETDATE()) AS recency_months,
    total_orders,
    total_sales,
    total_units_bought,
    distinct_products_bought,
    tenure_months,
    -- Average Order Value (AOV) protected against division by zero
    CASE 
        WHEN total_orders = 0 THEN 0
        ELSE total_sales / total_orders
    END AS avg_order_value,
    -- Average Monthly Spend protected if tenure is 0 months (single order customer)
    CASE 
        WHEN tenure_months = 0 THEN total_sales
        ELSE total_sales / tenure_months
    END AS avg_monthly_spend
FROM customer_summary;
GO

-- Verify customer report output
SELECT TOP 10 * FROM gold.report_customers ORDER BY total_sales DESC;


-- =============================================================================
-- 13. PRODUCT REPORT VIEW
-- Purpose: Create an enterprise reporting view consolidating product catalog
--          details, realized sale prices, sales lifespan, volume, and performance tiers.
-- =============================================================================

IF OBJECT_ID('gold.report_products', 'V') IS NOT NULL
    DROP VIEW gold.report_products;
GO

CREATE VIEW gold.report_products AS
WITH product_base AS (
    SELECT
        f.order_number,
        f.order_date,
        f.customer_key,
        f.sales_amount,
        f.quantity,
        p.product_key,
        p.product_name,
        p.category,
        p.subcategory,
        p.cost
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
        ON f.product_key = p.product_key
    WHERE f.order_date IS NOT NULL
),
product_summary AS (
    SELECT
        product_key,
        product_name,
        category,
        subcategory,
        cost,
        DATEDIFF(month, MIN(order_date), MAX(order_date)) AS sales_lifespan_months,
        MAX(order_date) AS last_order_date,
        COUNT(DISTINCT order_number) AS total_orders,
        COUNT(DISTINCT customer_key) AS unique_customers,
        SUM(sales_amount) AS total_sales,
        SUM(quantity) AS total_units_sold,
        -- NULLIF prevents division by zero if quantity is 0 or null
        ROUND(AVG(CAST(sales_amount AS FLOAT) / NULLIF(quantity, 0)), 1) AS realized_avg_price
    FROM product_base
    GROUP BY
        product_key,
        product_name,
        category,
        subcategory,
        cost
)
SELECT
    product_key,
    product_name,
    category,
    subcategory,
    cost,
    last_order_date,
    -- Recency: months since this product was last purchased
    DATEDIFF(month, last_order_date, GETDATE()) AS recency_months,
    -- Performance tier classification
    CASE
        WHEN total_sales > 50000 THEN 'Top Tier'
        WHEN total_sales >= 10000 THEN 'Mid Tier'
        ELSE 'Low Volume'
    END AS performance_segment,
    sales_lifespan_months,
    total_orders,
    total_sales,
    total_units_sold,
    unique_customers,
    realized_avg_price,
    -- Average revenue generated per order
    CASE
        WHEN total_orders = 0 THEN 0
        ELSE total_sales / total_orders
    END AS avg_order_revenue,
    -- Average monthly run-rate
    CASE
        WHEN sales_lifespan_months = 0 THEN total_sales
        ELSE total_sales / sales_lifespan_months
    END AS avg_monthly_revenue
FROM product_summary;
GO

-- Verify product report output
SELECT TOP 10 * FROM gold.report_products ORDER BY total_sales DESC;