# Semantic Layer

The MetricFlow definitions live inside the dbt project because MetricFlow requires it:

`dbt_retail/models/marts/semantic_models.yml`

- Semantic model: `retail_sales` (on `fact_order_items`)
- Time spine: `dim_date.FULL_DATE`, day grain
- Metrics: `total_revenue`, `total_profit`, `total_cost`, `units_sold`, `total_orders`

Validate and query:

```bash
mf validate-configs
mf list metrics
mf query --metrics total_revenue
```

See `docs/phases/phase_07_semantic_bi_recovery.md` for details.
