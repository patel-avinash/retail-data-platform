{{ config(materialized='table') }}

SELECT
    CITY,
    STATUS,
    COUNT(*) AS TOTAL_CUSTOMERS
FROM {{ ref('stg_customers') }}
GROUP BY
    CITY,
    STATUS