{{ config(materialized='table') }}

WITH source_customers AS (

    SELECT
        CUSTOMER_ID,
        CUSTOMER_NAME,
        CITY,
        EMAIL,
        STATUS
    FROM {{ ref('stg_customers') }}

)

SELECT
    ROW_NUMBER() OVER (
        ORDER BY CUSTOMER_ID
    ) AS CUSTOMER_KEY,

    CUSTOMER_ID,
    CUSTOMER_NAME,
    CITY,
    EMAIL,
    STATUS,

    CURRENT_TIMESTAMP() AS EFFECTIVE_FROM,
    TO_TIMESTAMP_NTZ('9999-12-31 23:59:59') AS EFFECTIVE_TO,

    TRUE AS IS_CURRENT

FROM source_customers