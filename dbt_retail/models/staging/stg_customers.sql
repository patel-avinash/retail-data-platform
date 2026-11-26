
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

),

deduplicated AS (

    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY CUSTOMER_ID
            ORDER BY INGESTED_AT DESC NULLS LAST
        ) AS rn

    FROM cleaned_data

)

SELECT
    CUSTOMER_ID,
    CUSTOMER_NAME,
    CITY,
    EMAIL,
    STATUS,
    INGESTED_AT

FROM deduplicated
WHERE rn = 1
