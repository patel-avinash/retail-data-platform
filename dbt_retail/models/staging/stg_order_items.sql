WITH source_data AS (
    SELECT *
    FROM {{ source('retail_raw','RAW_ORDER_ITEMS') }}
),
cleaned_data AS (
    SELECT
        ORDER_ID,
        PRODUCT_ID,
        QUANTITY,
        UNIT_PRICE,
        QUANTITY * UNIT_PRICE AS TOTAL_PRICE,
        INGESTED_AT
    FROM source_data    
)
SELECT *
FROM cleaned_data