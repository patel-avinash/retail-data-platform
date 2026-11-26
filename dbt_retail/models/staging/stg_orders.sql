WITH source_data AS (
    SELECT *
    FROM {{ source('retail_raw', 'RAW_ORDERS') }}
),

cleaned_data AS (
    SELECT
        ORDER_ID,
        CUSTOMER_ID,
        ORDER_DATE,
        UPPER(TRIM(STATUS)) AS STATUS,
        INGESTED_AT
    FROM source_data
)

SELECT *
FROM cleaned_data