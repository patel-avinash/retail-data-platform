
WITH source_data AS (

    SELECT *
    FROM {{ source('retail_raw', 'RAW_CUSTOMERS') }}

),

cleaned_data AS (

    SELECT
        CUSTOMER_ID,
        {{ clean_string('NAME','initcap') }} AS CUSTOMER_NAME,
        {{ clean_string('CITY','initcap') }} AS CITY,
        {{ clean_string('EMAIL','lower') }} AS EMAIL,
        {{ clean_string('STATUS','upper') }} AS STATUS,
        INGESTED_AT

    FROM source_data

)

SELECT 
    * 
FROM cleaned_data
