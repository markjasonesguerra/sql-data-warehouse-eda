# SQL Exploratory Data Analysis (EDA) Project

End-to-end Exploratory Data Analysis (EDA) on an enterprise data warehouse database (`DataWarehouseAnalytics`) to uncover customer behavior, sales trends, operational SLAs, and revenue drivers.

---

## Database Architecture
Built on a star-schema architecture in Microsoft SQL Server:
* **`gold.dim_customers`**: Customer demographics, locations, and join dates.
* **`gold.dim_products`**: Product details, catalog hierarchy, and unit costs.
* **`gold.fact_sales`**: Transactional sales, quantities, prices, and shipping/due dates.

---

## Project Scope (Sections 01–13)
* **01. Database Exploration**: System metadata & table schema inspection (`INFORMATION_SCHEMA`).
* **02. Dimension Exploration**: Categorical cardinality, regions, and product hierarchies (`DISTINCT`).
* **03. Date Range & SLA Analysis**: Sales lifespan, customer age profiling, and shipping turnaround / SLA tracking (`DATEDIFF`).
* **04. Measure Exploration**: Consolidated executive KPI scorecard (`SUM`, `AVG`, `COUNT DISTINCT`).
* **05. Magnitude Analysis**: Revenue and volume breakdown by product category and geography (`GROUP BY`, `LEFT JOIN`).
* **06. Ranking Analysis**: Top/bottom products and customer spenders (`TOP`, `DENSE_RANK`).
* **07. Change Over Time**: Monthly/yearly transaction volume and revenue trends (`DATETRUNC`).
* **08. Cumulative Analysis**: Year-to-date (YTD) running totals and moving average prices (`SUM() OVER`).
* **09. Performance Analysis**: Year-over-Year (YoY) growth and product benchmarks (`LAG`).
* **10. Part-to-Whole Analysis**: Category market share percentage of total revenue (`SUM() OVER()`).
* **11. Data Segmentation**: Customer tiers (`VIP`, `Regular`, `New`) and product cost brackets (`CASE`).
* **12. Customer Report View**: Production reporting view for recency, frequency, and monetary metrics (`gold.report_customers`).
* **13. Product Report View**: Production reporting view for catalog sales velocity and margins (`gold.report_products`).

---

## Tech Stack
* **Database**: Microsoft SQL Server 2022 (Docker container)
* **Client Tool**: SQL Server Management Studio (SSMS) 22
* **Script**: [`sqlprojectEDA.sql`](./sqlprojectEDA.sql)

---

## Author
**Mark Jason Esguerra** 
