
{{
    config(
        materialized='table'
    )
}}

SELECT
    CUSTOMER_ID,
    '2025-01-01 00:00:00'::TIMESTAMP_NTZ AS EFFECTIVE_FROM
FROM {{ ref('dim_customers') }}
