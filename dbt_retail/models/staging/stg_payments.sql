WITH source_data AS (
    SELECT *
    FROM {{ source('retail_raw', 'RAW_PAYMENTS') }}   
),
cleaned_data AS (
    SELECT
        PAYMENT_ID,
        ORDER_ID,
        UPPER(TRIM(PAYMENT_STATUS)) AS PAYMENT_STATUS,
        AMOUNT,
        INGESTED_AT
    FROM source_data    
)
SELECT *
FROM cleaned_data