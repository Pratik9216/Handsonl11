# Hands-On Lab 11 — AWS Athena Analytics with S3, Glue & Crawler

## Overview

This lab walks through setting up a serverless analytics pipeline on AWS:

> **Amazon S3** (store data) → **AWS Glue Crawler** (discover schema) → **Glue Data Catalog** (register table) → **Amazon Athena** (run SQL queries) → **S3** (save results)

**Dataset:** [Amazon Sales Report](https://www.kaggle.com/datasets/thedevastator/unlock-profits-with-e-commerce-sales-data) — a real-world e-commerce CSV with order-level sales data.

---

## Step 1 — Amazon S3 (Simple Storage Service)

### What is Amazon S3?

**Amazon S3 (Simple Storage Service)** is an object storage service offered by AWS that lets you store and retrieve any amount of data from anywhere on the internet. It organizes data into **buckets** (like folders in the cloud), where each file is stored as an object with a unique key. S3 is highly durable (99.999999999% durability), scalable, and cost-effective. In this lab, we use S3 to store the raw CSV dataset as input and to hold the output results from Athena queries.

### How to Create S3 Buckets

We need **two S3 buckets**:

| Bucket | Purpose |
|--------|---------|
| `itcs6190-l11-raw-data` | Stores the raw CSV dataset |
| `itcs6190-l11-athena-results` | Stores Athena query output files |

### Instructions

1. Open the **AWS Console → S3 → Create bucket**
2. **Bucket 1 — Raw Data:**
   - Name: `itcs6190-l11-raw-data`
   - Region: `us-east-1` (or your preferred region — keep consistent throughout)
   - Block all public access: ✅ (leave default)
   - Click **Create bucket**
3. **Bucket 2 — Athena Results:**
   - Name: `itcs6190-l11-athena-results`
   - Same region as above
   - Click **Create bucket**
4. **Upload the dataset:**
   - Open `itcs6190-l11-raw-data`
   - Click **Create folder** → name it `amazon_sales/`
   - Upload `Amazon Sale Report.csv` into that folder

> Optionally, refer to `Doc.pdf` or the screenshots folder for the visual S3 bucket verification.

---

## Step 2 — IAM Role (Identity and Access Management)

### What is an IAM Role?

**AWS IAM (Identity and Access Management)** is the service that controls who or what can access AWS resources. An **IAM Role** is a set of permissions that can be assigned to AWS services so they can act on your behalf. Instead of giving credentials to a service directly, you attach a Role with specific **policies** (rules) that allow or deny actions. In this lab, we create a Role so that AWS Glue can read data from S3 and register it in the Glue Catalog, and so Athena can read from S3 and write query results.

### How to Create the IAM Role

Glue and Athena need permissions to access S3.

1. Open **AWS Console → IAM → Roles → Create role**
2. **Trusted entity:** AWS service → **Glue**
3. **Attach the following policies:**
   - `AmazonS3FullAccess`
   - `AWSGlueServiceRole`
   - `AmazonAthenaFullAccess`
4. **Role name:** `AthenaGlueLabRole`
5. Click **Create role**

> Optionally, refer to `Doc.pdf` or the screenshots folder for the IAM role verification.

---

## Step 3 — Create a Glue Database

1. Open **AWS Console → AWS Glue → Databases → Add database**
2. **Database name:** `sales_db`
3. Click **Create**

---

## Step 4 — AWS Glue Crawler

### What is a Glue Crawler?

**AWS Glue** is a fully managed ETL (Extract, Transform, Load) service. A **Glue Crawler** is a tool within Glue that automatically scans a data source (like an S3 bucket), detects the file format and column structure, and registers the schema as a table in the **Glue Data Catalog**. This catalog acts as a central metadata repository, making your data immediately queryable by services like Amazon Athena without writing any schema manually. The Crawler can be run on demand or on a schedule.

### How to Create and Run a Glue Crawler

The Glue Crawler scans your S3 data and automatically infers the schema, registering it as a queryable table in the Glue Data Catalog.

1. Open **AWS Glue → Crawlers → Create crawler**
2. **Crawler name:** `amazon-sales-crawler`
3. **Data source:**
   - Type: S3
   - Path: `s3://itcs6190-l11-raw-data/amazon_sales/`
4. **IAM role:** Select `AthenaGlueLabRole`
5. **Target database:** `sales_db`
6. **Schedule:** On demand
7. Click **Create crawler**
8. Select the crawler → click **Run**

After the crawl completes (1–2 minutes), go to **Glue → Tables**. You should see a new table named `amazon_sales` under the `sales_db` database, with all columns automatically detected.

---

## Step 5 — Configure Amazon Athena

1. Open **AWS Console → Amazon Athena → Query editor**
2. First-time setup — click **Settings → Manage**:
   - **Query result location:** `s3://itcs6190-l11-athena-results/`
   - Click **Save**
3. In the Query editor:
   - **Data source:** `AwsDataCatalog`
   - **Database:** `sales_db`
   - **Table:** `amazon_sales` (visible in the left panel)

> Optionally, refer to `Doc.pdf` or the screenshots folder for the Athena / CloudWatch configuration.

---

## Step 6 — Run the SQL Queries

All queries are in [`queries/athena_queries.sql`](queries/athena_queries.sql).  
Copy each query into the Athena Query Editor and click **Run**.  
Download the results as CSV from the **Results** panel and save them into the `results/` folder.

---

### Query 1 — Basic Table Exploration

Retrieves the first 10 records to verify the table is set up correctly.

```sql
SELECT *
FROM amazon_sales
LIMIT 10;
```

**Result:** [`results/query1_basic_exploration.csv`](results/query1_basic_exploration.csv)

---

### Query 2 — Orders by Product Category

Returns the count of orders in each product category, sorted by most popular.

```sql
SELECT
    category,
    COUNT(*) AS total_orders
FROM amazon_sales
GROUP BY category
ORDER BY total_orders DESC
LIMIT 10;
```

**Result:** [`results/query2_orders_by_category.csv`](results/query2_orders_by_category.csv)

---

### Query 3 — Revenue and Quantity by Fulfilment Method

Compares fulfilment methods (Easy Ship vs Merchant) by order volume, units sold, and revenue — excluding cancelled and pending orders.

```sql
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
```

**Result:** [`results/query3_revenue_by_fulfilment.csv`](results/query3_revenue_by_fulfilment.csv)

---

### Query 4 — Monthly Sales Trend

Shows how orders and revenue changed month-over-month, sorted chronologically.  
Uses `DATE_PARSE` to parse the `MM-DD-YY` string date column.

```sql
SELECT
    DATE_TRUNC('month', DATE_PARSE(date, '%m-%d-%y'))   AS sales_month,
    COUNT(*)                                              AS total_orders,
    ROUND(SUM(amount), 2)                                AS total_revenue
FROM amazon_sales
WHERE LOWER(status) NOT IN ('cancelled', 'pending', 'pending - waiting for pick up')
GROUP BY DATE_TRUNC('month', DATE_PARSE(date, '%m-%d-%y'))
ORDER BY sales_month ASC
LIMIT 10;
```

**Result:** [`results/query4_monthly_sales_trend.csv`](results/query4_monthly_sales_trend.csv)

---

### Query 5 — Top 5 Best-Selling SKUs per Category

Uses a CTE + `ROW_NUMBER()` window function to rank SKUs within each category by total revenue, returning only the top 5 per category.

```sql
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
```

**Result:** [`results/query5_top5_skus_per_category.csv`](results/query5_top5_skus_per_category.csv)

---

## Repository Structure

```
Hands-on-11-AWS-Core-Services/
├── queries/
│   └── athena_queries.sql                  # All 5 Athena SQL queries
├── results/
│   ├── query1_basic_exploration.csv
│   ├── query2_orders_by_category.csv
│   ├── query3_revenue_by_fulfilment.csv
│   ├── query4_monthly_sales_trend.csv
│   └── query5_top5_skus_per_category.csv
├── Doc.pdf                                 # Documentation and Screenshots
├── README.md.docx                          # Word version of this README
└── README.md                               # This file
```

---

## Key Takeaways

- **Glue Crawler** eliminates manual schema definition — it auto-detects column names and types from the raw CSV.
- **Athena is serverless** — no clusters to manage; you pay only per query (per TB scanned).
- **Date parsing** in Athena uses Presto's `DATE_PARSE` with explicit format strings (`%m-%d-%y`).
- **Window functions** (`ROW_NUMBER OVER PARTITION BY`) allow per-group rankings without subquery hacks.
- Always **filter cancelled/pending orders** before computing business revenue metrics to avoid inflated numbers.
