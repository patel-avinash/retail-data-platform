
{{
    config(
        materialized='incremental',
        unique_key='ORDER_ID'
    )
}}

SELECT
    ORDER_ID,
    CUSTOMER_ID,
    ORDER_DATE,
    STATUS,
    INGESTED_AT
FROM {{ ref('stg_orders') }}

{% if is_incremental() %}
WHERE INGESTED_AT > (
    SELECT COALESCE(MAX(INGESTED_AT), '1900-01-01'::TIMESTAMP_NTZ)
    FROM {{ this }}
)
{% endif %}
