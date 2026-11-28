# Phase 5: Incremental Processing and Automation

## Objective
Automate ingestion and change processing.

## What was built
- **Streams and Tasks:** 6 streams on RAW tables; 6 Tasks using `SYSTEM$STREAM_HAS_DATA` and `MERGE` into STAGING targets.
- **Dynamic Table demo:** `DT_PRODUCTS_DEMO` with a 1-minute target lag.
- **dbt incremental demo:** `dim_products_incremental_demo` (merge strategy, `PRODUCT_ID` key).
- **Metadata-driven ingestion:** `INGESTION_CONTROL`, `INGESTION_AUDIT_LOG`, JavaScript procedure `PROCESS_RETAIL_INGESTION`.
- **Scheduling:** `RETAIL_INGESTION_TASK` every 5 minutes.

## Results
- First run: Loaded 6, Skipped 0, Failed 0. Repeat run: Loaded 0, Skipped 6, Failed 0.
- A new day-01 customer file loaded 27 rows; later repeats were skipped.
- Task history showed successful runs.

## Dynamic Tables vs dbt incremental

| | Dynamic Table | dbt incremental |
|---|---|---|
| Refresh | Snowflake managed (target lag) | When dbt runs |
| Logic control | Snowflake | Developer |
| Fits | Auto-maintained tables | Tested, version-controlled workflows |

## Limitations
- Duplicate protection checks table and filename only. Changed content under the same name is skipped; a renamed copy can load again.
- Business keys are not deduplicated: customers had 2,030 rows and 2,022 distinct IDs.
- Streams track table changes, not files in the stage.
- Delete propagation and automatic schema evolution are not implemented.
- The audit `INSERT` sits outside the per-file error handling.
