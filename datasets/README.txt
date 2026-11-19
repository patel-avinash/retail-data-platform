# Retail Sales Data Warehouse — Synthetic Source Data

All records in these files are fictional and generated for this learning project.
Email addresses use the reserved example.com domain; no real customer data is included.

## Files and row counts
- customers.csv — 2,000 rows
- products.csv — 500 rows
- orders.csv — 10,000 rows
- order_items.csv — 25,000 rows
- payments.csv — 10,000 rows
- inventory.csv — 1,500 rows

Total: 49,000 data rows (headers excluded).

## Relationships
- orders.customer_id -> customers.customer_id
- order_items.order_id -> orders.order_id
- order_items.product_id -> products.product_id
- payments.order_id -> orders.order_id
- inventory.product_id -> products.product_id
- inventory.warehouse_id identifies one of three synthetic warehouses:
  WH_AHMEDABAD, WH_MUMBAI, WH_DELHI

## Notes
- Order dates span 2025-01-01 through 2026-10-31.
- Each order has either two or three order-item rows; total order_items rows = 25,000.
- Each order has one payment record.
- Each product has one inventory row per warehouse.
- Customer city/status and product price can be changed in future incremental batches for SCD exercises.
- The files contain the baseline dataset only. Daily incremental/change files will be generated separately when we reach the incremental-processing module.

## Column definitions
- customers: customer_id, name, city, email, status
- products: product_id, category, price, cost
- orders: order_id, customer_id, order_date, status
- order_items: order_id, product_id, quantity, unit_price
- payments: payment_id, order_id, payment_status, amount
- inventory: product_id, warehouse_id, stock_quantity
