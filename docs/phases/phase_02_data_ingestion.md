# Phase 2: Data Ingestion and Snowflake Internals

## Objective
Load six CSV files into RAW tables and understand how Snowflake loads and stores data.

## What was built
- Internal stage `RETAIL_SOURCE_STAGE` with six CSV files.
- File format `RETAIL_CSV_FORMAT` (comma delimited, skip 1 header row, optional quotes, trimmed spaces, empty fields as NULL).
- Six RAW tables, loaded with `COPY INTO` and `ON_ERROR = 'ABORT_STATEMENT'`.
- Basic `INGESTION_AUDIT_LOG`, filled manually from `COPY_HISTORY`.
- Standard view `VW_ACTIVE_CUSTOMERS` (1,773 active, 227 inactive).

## Results

| File | Rows loaded |
|---|---|
| customers | 2,000 |
| products | 500 |
| orders | 10,000 |
| order_items | 25,000 |
| payments | 10,000 |
| inventory | 1,500 |
| **Total** | **49,000** |

## Concepts covered
Stages, file formats, positional columns (`$1`, `$2`), `METADATA$FILENAME` and related metadata, `COPY_HISTORY`, micro-partitions and pruning, permanent / transient / temporary tables, views.

## Lessons
- Reducing a `VARCHAR` length with `ALTER` is not supported.
- Table-specific `COPY_HISTORY` needs `TABLE_NAME` and `START_TIME`.
- Re-running `COPY INTO` on the same file without `FORCE` did not reload it. This is file-level protection, not row-level deduplication.

## Limitations at this phase
Audit log was manual. Ingestion was not metadata driven. Table types and micro-partitions were studied, not demonstrated.

## SQL location
`snowflake/stages/`
