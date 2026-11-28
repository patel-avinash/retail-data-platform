# Phase 3: dbt Core and Transformation

## Objective
Build the transformation layer on top of RAW.

## Setup
dbt Core 1.12.7, dbt-snowflake 1.12.5, role `DBT_DEVELOPER`, project and profile `dbt_retail`.

## What was built
- Six staging views: `stg_customers`, `stg_products`, `stg_orders`, `stg_order_items`, `stg_payments`, `stg_inventory`.
- Macro `clean_string` (trim and case handling), used in `stg_customers`.
- Seeds: `order_status_mapping` (6 rows), `city_pincode_mapping` (9 rows), with views `int_order_status` and `int_city_pincode`.
- `int_customer_summary` (table) and `int_orders_incremental` (incremental, keyed on `ORDER_ID`).
- Generic tests (`unique`, `not_null`, `relationships`, `accepted_values`) and singular tests (no future orders, price greater than cost).
- Source freshness on `INGESTED_AT` (warn after 1 day, error after 2).
- Generated dbt docs and lineage.

## Final verified build
`PASS=37, WARN=0, ERROR=0`, including 25 data tests.

## Lessons
- A custom `+schema` on seeds caused a `CREATE SCHEMA` privilege error. Removing it kept least privilege intact.
- `accepted_values` failed because YAML used `ORDER_STATUS` while the model exposed `STATUS`.
- Sources reported `ERROR STALE` because load times were old. This was correct; timestamps were not falsified.
- A macro does not make SQL faster. It improves reuse.

## Limitations at this phase
The incremental filter (`INGESTED_AT > max`) can miss updates and late-arriving rows. `INGESTED_AT` values were backfilled from a manual audit log.

## Code location
`dbt_retail/`
