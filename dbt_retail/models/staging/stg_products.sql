
WITH source_data AS (

    SELECT *
    FROM {{ source('retail_raw', 'RAW_PRODUCTS') }}

),

cleaned_data AS (

    SELECT
        PRODUCT_ID,
        UPPER(TRIM(CATEGORY)) AS CATEGORY,
        PRICE,
        COST,
        PRICE - COST AS PROFIT_PER_UNIT,
        INGESTED_AT

    FROM source_data

)

SELECT *
FROM cleaned_data
