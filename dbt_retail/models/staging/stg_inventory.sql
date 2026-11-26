WITH source_data AS (
    SELECT *
    FROM {{ source('retail_raw', 'RAW_INVENTORY') }}    
),
cleaned_data AS (
    SELECT
        PRODUCT_ID,
        UPPER(TRIM(WAREHOUSE_ID)) AS WAREHOUSE_ID,
        STOCK_QUANTITY,
        INGESTED_AT 
    FROM source_data    
)
SELECT *
FROM cleaned_data