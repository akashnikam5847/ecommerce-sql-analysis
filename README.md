# E-commerce Sales Analysis (MySQL)

SQL analysis of ~100K real e-commerce orders (2016-2018) from the Brazilian marketplace Olist. The project covers schema design, data loading, and 11 business queries that use joins, CTEs, subqueries, `CASE`, and window functions (`LAG`, `RANK`, running totals).

## Business questions answered

- How much revenue is the business making, and what is the average order value?
- Which product categories, states, and sellers drive the revenue?
- How did revenue grow month over month?
- How does delivery performance affect customer reviews?
- How many customers come back to buy again?

## Key findings

| Area | Finding |
|---|---|
| Revenue | 96,478 delivered orders, about 13.2M (BRL) in item revenue, average order value about 137 |
| Categories | `health_beauty` is the top category (~1.23M); the top 10 categories bring about 62% of revenue |
| Geography | São Paulo (`SP`) alone gives about 38% of revenue; SP, RJ, MG together about 63% |
| Sellers | 9 of the top 10 sellers by revenue are based in SP |
| Growth | Monthly revenue grew about 4x between Jan 2017 (~112K) and Jul 2017 (~482K) |
| Delivery vs reviews | On-time orders average **4.29** stars, late orders only **2.57**; about 8% of reviewed orders were late |
| Retention | **97%** of customers ordered only once; just 3% (2,801 customers) are repeat buyers |

## Dataset

[Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) on Kaggle (license: CC BY-NC-SA 4.0).

The CSV files are not included in this repository. 8 of the 9 files are used (the geolocation file is skipped because the analysis does not need it).

## Database schema

```
customers ──< orders ──< order_items >── products
                │             └────────< sellers
                ├──< order_payments
                └──< order_reviews
category_translation (lookup for product category names)
```

All relationships are enforced with foreign keys (see `schema.sql`).

## Repository structure

| File | Purpose |
|---|---|
| `schema.sql` | Creates the database, tables, and foreign keys |
| `import_data.py` | Loads the CSV files into MySQL using pandas and SQLAlchemy |
| `queries.sql` | The 11 analysis queries, with insights as comments |

## How to run

1. Download the dataset from Kaggle and place the CSV files in a folder named `data/`.
2. Run `schema.sql` in MySQL Workbench (MySQL 8).
3. Install the Python libraries and load the data:
   ```bash
   pip3 install pandas sqlalchemy pymysql cryptography
   export MYSQL_PASSWORD="your_mysql_password"
   python3 import_data.py
   ```
4. Run `queries.sql` and explore the results.

## SQL skills demonstrated

- Multi-table joins (`INNER`, `LEFT`) across 6 tables
- Aggregations, `GROUP BY`, `CASE` expressions
- CTEs and subqueries
- Window functions: `LAG`, `RANK`, `SUM() OVER`
- Schema design with primary and foreign keys
- Data cleaning checks (NULL delivery dates, duplicate keys, missing category translations)

## Notes and limitations

- Revenue means the sum of item prices (freight excluded) for orders with status `delivered`.
- Early months of 2016 have very few orders, so month-over-month growth percentages look extreme there. November 2016 has no delivered orders.
- Query 7 uses two separate CTEs for revenue and reviews. Joining them directly would repeat order items per review and inflate revenue.
- Data ends in 2018, so these are historical insights, not current figures.
