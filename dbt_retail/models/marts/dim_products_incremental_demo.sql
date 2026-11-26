
{{ config(
    materialized='incremental',
    unique_key='PRODUCT_ID',
    incremental_strategy='merge'
) }}

SELECT
    PRODUCT_ID,
    CATEGORY,
    PRICE,
    COST,
    INGESTED_AT
FROM {{ source('retail_raw', 'RAW_PRODUCTS') }}

{% if is_incremental() %}
WHERE INGESTED_AT > (
    SELECT COALESCE(MAX(INGESTED_AT), '1900-01-01'::TIMESTAMP_NTZ)
    FROM {{ this }}
)
{% endif %}
