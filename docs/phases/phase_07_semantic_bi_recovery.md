# Phase 7: Semantic Layer, BI and Recovery

## Objective
Publish trusted metrics and a dashboard, and demonstrate recovery features.

## Semantic layer
Semantic model `retail_sales` on `fact_order_items`, time spine `dim_date.FULL_DATE` (day).

| Metric | Logic |
|---|---|
| `total_revenue` | `SUM(TOTAL_REVENUE)` |
| `total_profit` | `SUM(TOTAL_PROFIT)` |
| `total_cost` | `SUM(TOTAL_COST)` |
| `units_sold` | `SUM(QUANTITY)` |
| `total_orders` | `COUNT(DISTINCT ORDER_ID)` |

`mf validate-configs` passed with zero errors and warnings. All five metrics were listed; revenue (about 45.52 crore) and profit (about 18.27 crore) were queried.

## Tableau dashboard
Tableau Cloud over `RETAIL_DEV.MART` via a virtual connection and Cloud OAuth. KPIs: revenue, profit, 10,000 orders. Charts: monthly trend (Jan 2025 to Oct 2026), order status, sales by category. Filters: date, category, status.

## dbt docs
Generated and inspected locally (`dbt docs serve`).

## Recovery demos
- **Time Travel:** queried the table before an update using the statement query ID and restored it.
- **UNDROP:** dropped and restored a table.
- **Zero-copy clone:** changed the clone without affecting the source.
- **Fail-safe:** studied only; recovery goes through Snowflake Support and is not guaranteed.

## Limitations
- Tableau reads MART tables directly and does not use MetricFlow.
- Only two of five metrics were queried through MetricFlow.
- Static hosting of dbt docs is still pending.

## Code location
`dbt_retail/models/marts/semantic_models.yml`, `snowflake/recovery/`, `dashboards/`
