
{{
    config(
        materialized='table'
    )
}}

WITH source_products AS (

    SELECT
        PRODUCT_ID,
        CATEGORY,
        PRICE,
        COST,
        PROFIT_PER_UNIT
    FROM {{ ref('stg_products') }}

),

final AS (

    SELECT
        ROW_NUMBER() OVER (
            ORDER BY PRODUCT_ID
        ) AS PRODUCT_KEY,

        PRODUCT_ID,
        CATEGORY,
        PRICE,
        COST,
        PROFIT_PER_UNIT,

        CURRENT_TIMESTAMP()::TIMESTAMP_NTZ AS EFFECTIVE_FROM,
        TO_TIMESTAMP_NTZ('9999-12-31 23:59:59') AS EFFECTIVE_TO,
        TRUE AS IS_CURRENT

    FROM source_products

)

SELECT * FROM final
