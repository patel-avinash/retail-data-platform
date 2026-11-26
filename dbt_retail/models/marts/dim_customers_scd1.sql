
{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='CUSTOMER_ID'
    )
}}

SELECT
    CUSTOMER_ID,
    CUSTOMER_NAME,
    CITY,
    EMAIL,
    STATUS
FROM {{ ref('stg_customers') }}
{# FROM RETAIL_DEV.STAGING.TEST_STG_CUSTOMERS #}
