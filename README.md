# Hands-On Lab 11 — AWS Athena Analytics with S3, Glue & Crawler

## Overview
This lab walks through setting up a serverless analytics pipeline on AWS:

> **Amazon S3** → **AWS Glue Crawler** → **Glue Data Catalog** → **Amazon Athena** → **S3 (results)**

**Dataset:** Amazon Sales Report — a real-world e-commerce CSV with order-level sales data.

---

## Step 1 — Amazon S3 (Simple Storage Service)
### What is Amazon S3?
Amazon S3 (Simple Storage Service) is an object storage service offered by AWS that lets you store and retrieve any amount of data from anywhere on the internet. It organizes data into buckets (like folders in the cloud), where each file is stored as an object with a unique key. S3 is highly durable, scalable, and cost-effective. In this lab, we use S3 to store the raw CSV dataset as input and to hold Athena query output files.

### S3 Bucket Setup
Only one bucket was used in this lab:

<img width="691" height="327" alt="image" src="https://github.com/user-attachments/assets/c0b8a15c-1d43-461e-bfed-9720eb7b6421" />


| Bucket Name | Purpose |
|-------------|---------|
| `handson-11cc` | Stores the raw CSV dataset (`raw/` folder) and Athena-processed output (`processed/` folder) |

### Instructions
1. Open the **AWS Console → S3 → Create bucket**
2. Name: `handson-11cc` | Region: `us-east-1` (N. Virginia) | Block all public access: ✅ | Click **Create bucket**
3. Open `handson-11cc` → Create folder → name it `raw`
4. Upload `Amazon Sale Report.csv` into the `raw/` folder (65.7 MB, uploaded April 7, 2026)

<img width="693" height="332" alt="image" src="https://github.com/user-attachments/assets/f1d92967-570f-4adc-9d6f-962846fea76d" />

Below is the processed data in the S3 bucket; this bucket also contains a `processed/` folder (auto-created by Athena when saving query results).

<img width="693" height="332" alt="image" src="https://github.com/user-attachments/assets/249c5e97-14eb-47a3-af5d-90c4133fd43d" />

## Step 2 — IAM Role (Identity and Access Management)
### What is an IAM Role?
AWS IAM (Identity and Access Management) is the service that controls who or what can access AWS resources. An IAM Role is a set of permissions that can be assigned to AWS services so they can act on your behalf. In this lab, we create a Role so that AWS Glue can read data from S3 and register it in the Glue Catalog.

### IAM Role Created

| Property | Value |
|----------|-------|
| Role Name | `chicken_roll` |
| Trusted Entity | AWS Service — Glue |
| Creation Date | April 07, 2026, 11:40 (UTC-04:00) |
| Max Session Duration | 1 hour |
| ARN | `arn:aws:iam::444952541752:role/chicken_roll` |

### Attached Policies (3)

| Policy Name | Type |
|-------------|------|
| `AmazonS3FullAccess` | AWS managed |
| `AWSGlueConsoleFullAccess` | AWS managed |
| `AWSGlueServiceRole` | AWS managed |

### How to Create the IAM Role
1. Open **AWS Console → IAM → Roles → Create role**
2. Trusted entity: AWS service → **Glue**
3. Attach policies: `AmazonS3FullAccess`, `AWSGlueConsoleFullAccess`, `AWSGlueServiceRole`
4. Role name: `chicken_roll`
5. Click **Create role**

<img width="692" height="325" alt="image" src="https://github.com/user-attachments/assets/ec28d313-0827-4f26-9721-4e85ab001159" />

---

## Step 3 — Create a Glue Database
1. Open **AWS Console → AWS Glue → Databases → Add database**
2. Database name: `output_db`
3. Click **Create**

---

## Step 4 — AWS Glue Crawler
### What is a Glue Crawler?
AWS Glue is a fully managed ETL (Extract, Transform, Load) service. A Glue Crawler is a tool within Glue that automatically scans a data source (like an S3 bucket), detects the file format and column structure, and registers the schema as a table in the Glue Data Catalog. This catalog acts as a central metadata repository, making your data immediately queryable by services like Amazon Athena without writing any schema manually. The Crawler can be run on demand or on a schedule.

### Crawler Configuration

| Property | Value |
|----------|-------|
| Crawler Name | `handsoncrawler` |
| Data Source | S3 — `s3://handson-11cc/raw/` |
| IAM Role | `chicken_roll` |
| Target Database | `output_db` |
| Schedule | On demand |
| State | READY |

### How to Create and Run the Crawler
1. Open **AWS Glue → Crawlers → Create crawler**
2. Crawler name: `handsoncrawler`
3. Data source: S3 | Path: `s3://handson-11cc/raw/`
4. IAM role: `chicken_roll`
5. Target database: `output_db`
6. Schedule: On demand → Click **Create crawler**
7. Select the crawler → click **Run**

<img width="692" height="331" alt="image" src="https://github.com/user-attachments/assets/f75c7964-d8c8-4aff-8954-44ccceb3fecf" />


### Crawler Run History

| Run # | Start Time (UTC) | End Time (UTC) | Duration | Status | Table Changes |
|-------|------------------|----------------|----------|--------|---------------|
| 1 | April 7, 2026, 15:52:17 | April 7, 2026, 15:52:58 | ~40 sec | ✅ Completed | 1 table change, 0 partition changes |
| 2 | April 7, 2026, 16:10:35 | April 7, 2026, 16:12:01 | ~1 min 25 sec | ✅ Completed | 1 table change, 0 partition changes |

After the crawl completes, navigate to **Glue → Tables**. You will see the table `amazon_sale_report_csv` created under the `output_db` database.

### CloudWatch Logs Confirmation
The CloudWatch log group `/aws-glue/crawlers` confirms the following key events for `handsoncrawler`:
- Running Start Crawl for Crawler `handsoncrawler`
- Classification complete, writing results to database `output_db`
- Crawler configured with CreatePartitionIndex:true
- Created table `amazon_sale_report_csv` in database `output_db`
- Finished writing to Catalog
- Crawler has finished running and is in state READY
- Run Summary: ADD: 1

<img width="692" height="366" alt="image" src="https://github.com/user-attachments/assets/33335e25-55fa-4f48-a6a3-3da53b4ad678" />

---

## Step 5 — Configure Amazon Athena
1. Open **AWS Console → Amazon Athena → Query editor**
2. First-time setup: click **Query settings → Manage** → set Query result location to `s3://handson-11cc/processed/` → Save
3. In the Query editor, set: Data source: `AwsDataCatalog` | Database: `output_db`

### Tables Visible in Left Panel

| Table Name | Database | Notes |
|------------|----------|-------|
| `amazon_sale_report_csv` | `output_db` | Created by Glue Crawler — full dataset |
| `raw` | `output_db` | Also visible as a queryable table |

<img width="691" height="368" alt="image" src="https://github.com/user-attachments/assets/fce75f54-ae35-4fa0-9c60-3c0290b0013e" />

---

## Step 6 — Run the SQL Queries
All queries are run in the Athena Query Editor. **Data source:** `AwsDataCatalog` | **Database:** `output_db` | **Table:** `raw`.
Copy each query into the Athena Query Editor and click **Run**. Download results as CSV from the Results panel.

### Query 1 — Basic Table Exploration
Retrieves the first 10 records to verify the table is set up correctly.

<img width="692" height="371" alt="image" src="https://github.com/user-attachments/assets/9de41a80-0160-48c2-9c19-3ffc2ab829a0" />

Result:

<img width="692" height="334" alt="image" src="https://github.com/user-attachments/assets/351061e2-5266-4739-af79-677e6a30fa06" />

### Query 2 — Orders by Product Category
Returns the count of orders in each product category, sorted by most popular.

<img width="691" height="331" alt="image" src="https://github.com/user-attachments/assets/1ad54d16-cd27-4384-8246-8750f632405a" />

Result:

<img width="692" height="330" alt="image" src="https://github.com/user-attachments/assets/fe9c48e9-4d42-4695-a4f7-28646e67983e" />


### Query 3 — Revenue and Quantity by Fulfilment Method
Compares fulfilment methods (Amazon vs Merchant) by order volume, units sold, and revenue — excluding cancelled and pending orders.

<img width="691" height="330" alt="image" src="https://github.com/user-attachments/assets/a61edbbd-6522-4bec-8399-4a9cb48cc320" />

Result:

<img width="692" height="330" alt="image" src="https://github.com/user-attachments/assets/add5fe8f-09b3-416c-98c2-134e1ca10a0c" />


### Query 4 — Monthly Sales Trend
Shows how orders and revenue changed month-over-month, sorted chronologically. Uses `DATE_PARSE` to parse the `MM-DD-YY` string date column.

<img width="691" height="330" alt="image" src="https://github.com/user-attachments/assets/f49b3286-72ea-4c3c-8646-10ab5c13a9f9" />

Result:

<img width="691" height="331" alt="image" src="https://github.com/user-attachments/assets/fc59b5ba-d87f-4063-b080-50705f3e3ebb" />




### Query 5 — Top 5 Best-Selling SKUs per Category
Uses a CTE + `ROW_NUMBER()` window function to rank SKUs within each category by total revenue, returning only the top 5 per category.

<img width="692" height="326" alt="image" src="https://github.com/user-attachments/assets/6ce8fb05-fe37-4a5f-b18f-1d49717aeb44" />

Result:

<img width="692" height="330" alt="image" src="https://github.com/user-attachments/assets/282dbf2c-893d-4b8f-b782-8e349b939efd" />

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
├── screenshots/
│   ├── s3_buckets.png                      # handson-11cc bucket
│   ├── iam_role.png                        # chicken_roll role & policies
│   └── cloudwatch.png                      # handsoncrawler CloudWatch logs
└── README.md
```

---

## Key Takeaways
- Glue Crawler eliminates manual schema definition — it auto-detects column names and types from the raw CSV and registers them in the Glue Data Catalog.
- Athena is serverless — no clusters to manage; you pay only per query (per TB scanned). All 5 queries in this lab scanned 65.73 MB each.
- Date parsing in Athena uses Presto's `DATE_PARSE` with explicit format strings (`%m-%d-%y` for MM-DD-YY dates).
- Window functions (`ROW_NUMBER OVER PARTITION BY`) allow per-group rankings without subquery hacks.
- Always filter cancelled/pending orders before computing business revenue metrics to avoid inflated numbers.
- A single S3 bucket (`handson-11cc`) can serve dual purpose — storing raw input in `raw/` and Athena query output in `processed/`.

---

## Summary of Corrections from Original README

| Section | Original README | Actual (per screenshots) |
|---------|-----------------|--------------------------|
| S3 Bucket (raw) | `itcs6190-l11-raw-data` | `handson-11cc` |
| S3 Bucket (results) | `itcs6190-l11-athena-results` (separate) | `handson-11cc/processed/` (same bucket) |
| IAM Role Name | `AthenaGlueLabRole` | `chicken_roll` |
| IAM Policy 3 | `AmazonAthenaFullAccess` | `AWSGlueConsoleFullAccess` |
| Glue Database | `sales_db` | `output_db` |
| Crawler Name | `amazon-sales-crawler` | `handsoncrawler` |
| Glue Table Name | `amazon_sales` | `amazon_sale_report_csv` (also: `raw`) |
| Athena Database | `output_db` | `output_db` ✅ |
| Athena Table (queries) | `amazon_sales` | `raw` |
| Query 2 Result Rows | 10 (LIMIT 10) | 9 (only 9 categories exist) |
| Query 3 Fulfilment Values | Easy Ship vs Merchant | Amazon vs Merchant |
| Query 4 Result Rows | 10 (LIMIT 10) | 4 (only 4 months of data) |
