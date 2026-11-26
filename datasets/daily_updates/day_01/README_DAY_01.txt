RETAIL DATA PLATFORM - DAY 1 INCREMENTAL DELIVERY

Generated to match the original synthetic baseline datasets used in the project.
Delivery date: 2026-11-01

Files use the same headers as the original CSVs. These are DELTA files, not replacement full datasets.
Do not overwrite the original datasets or load these directly into production tables without the Phase 5 deduplication/upsert logic.

Contents (file row counts include intentional repeated rows):
- customers.csv: 20 inserts + 5 updates + 2 exact duplicate rows = 27 rows
- products.csv: 10 inserts + 5 price updates + 2 exact duplicate rows = 17 rows
- orders.csv: 100 inserts + 5 exact duplicate rows = 105 rows
- order_items.csv: 250 inserts + 10 exact duplicate rows = 260 rows
- payments.csv: 100 inserts + 5 exact duplicate rows = 105 rows
- inventory.csv: 20 updates + 30 inserts + 5 exact duplicate rows = 55 rows

Important scenarios:
- Customer CUST00005 changes from Ahmedabad to Pune (for SCD Type 2 testing).
- Five existing product prices are increased by 8%.
- Inventory changes affect existing product/warehouse combinations; new products receive stock rows in all three existing warehouses.
- New orders are dated 2026-11-01; each new order has one payment and order items.
- Exact duplicate rows are intentionally included to test idempotency/deduplication.

The original six full datasets are not included in this ZIP and are not modified.
