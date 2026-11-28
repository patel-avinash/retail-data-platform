# Phase 4: Star Schema and Slowly Changing Dimensions

## Objective
Model facts and dimensions, and keep customer history accurate.

## What was built

| Model | Role |
|---|---|
| `fact_order_items` | 25,000 rows, one per order item |
| `dim_customers_scd2_custom` | Customer versions with surrogate `CUSTOMER_KEY` |
| `dim_customers_scd1` | Type 1 practice dimension (overwrite) |
| `dim_products` | 500 products |
| `dim_date` | 669 dates |
| `snap_customers` | dbt snapshot (check strategy) |

## SCD Type 2 design
- SHA-256 hash over name, city, email and status, with `COALESCE` for NULLs.
- Compare new hash with the latest stored version; if different, expire the old row and insert a new one.
- Columns: `CUSTOMER_KEY`, `CUSTOMER_ID`, `HASH_VALUE`, `EFFECTIVE_FROM`, `EFFECTIVE_TO`, `IS_CURRENT`.
- A re-run with no source change inserted zero rows.

## Historical join
```sql
ON f.CUSTOMER_ID = d.CUSTOMER_ID
AND f.ORDER_DATE >= TO_DATE(d.EFFECTIVE_FROM)
AND f.ORDER_DATE <  TO_DATE(d.EFFECTIVE_TO)
```

## Validation results
- 25,000 fact rows, 25,000 distinct `ORDER_ITEM_KEY`.
- Zero NULL customer, product or date keys.
- Zero invalid customer keys (anti-join).
- Revenue 455,160,674.32; cost 272,427,569.02; profit 182,733,105.30; zero calculation errors.
- Snapshot showed three versions for `CUST00005` (Ahmedabad, Pune, Mumbai).

## Limitations
- Surrogate keys use `MAX(key) + ROW_NUMBER()`: fine single-user, unsafe under concurrency.
- Product-price SCD2 was discussed, not built.
- Snapshot only sees changes present when it runs.
