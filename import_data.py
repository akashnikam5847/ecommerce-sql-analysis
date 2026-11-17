"""
Loads the Olist CSV files into the MySQL database `olist_ecommerce`.

Usage:
    1. Run schema.sql first (creates the tables).
    2. Put the Olist CSVs in a folder named `data/` next to this script
       (or set OLIST_DATA_DIR to another folder).
    3. Set your MySQL password as an environment variable and run:

           export MYSQL_PASSWORD="your_password"
           python3 import_data.py

Requires: pandas, sqlalchemy, pymysql, cryptography
"""
import os
from urllib.parse import quote_plus

import pandas as pd
from sqlalchemy import create_engine

PASSWORD = os.environ.get("MYSQL_PASSWORD", "")
FOLDER = os.environ.get("OLIST_DATA_DIR", "data")

if not PASSWORD:
    raise SystemExit("Set the MYSQL_PASSWORD environment variable first.")

engine = create_engine(
    f"mysql+pymysql://root:{quote_plus(PASSWORD)}@localhost:3306/olist_ecommerce"
)

# (table, csv file, date columns). Parent tables are loaded first.
jobs = [
    ("category_translation", "product_category_name_translation.csv", []),
    ("customers", "olist_customers_dataset.csv", []),
    ("sellers", "olist_sellers_dataset.csv", []),
    ("products", "olist_products_dataset.csv", []),
    ("orders", "olist_orders_dataset.csv", [
        "order_purchase_timestamp", "order_approved_at",
        "order_delivered_carrier_date", "order_delivered_customer_date",
        "order_estimated_delivery_date"]),
    ("order_items", "olist_order_items_dataset.csv", ["shipping_limit_date"]),
    ("order_payments", "olist_order_payments_dataset.csv", []),
    ("order_reviews", "olist_order_reviews_dataset.csv",
        ["review_creation_date", "review_answer_timestamp"]),
]

for table, csv_name, date_cols in jobs:
    df = pd.read_csv(
        os.path.join(FOLDER, csv_name),
        parse_dates=date_cols,
        dtype={"customer_zip_code_prefix": str, "seller_zip_code_prefix": str},
    )
    df.to_sql(table, engine, if_exists="append", index=False, chunksize=5000)
    print(f"{table}: {len(df)} rows imported")

print("Done!")
