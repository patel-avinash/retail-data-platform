
{{
    config(
        materialized='table'
    )
}}

WITH order_items AS (

    SELECT
        ORDER_ID,
        PRODUCT_ID,
        QUANTITY,
        UNIT_PRICE,
        TOTAL_PRICE
    FROM {{ ref('stg_order_items') }}

),

orders AS (

    SELECT
        ORDER_ID,
        CUSTOMER_ID,
        ORDER_DATE,
        STATUS
    FROM {{ ref('stg_orders') }}

),

joined_data AS (

    SELECT
        oi.ORDER_ID,
        o.CUSTOMER_ID,
        oi.PRODUCT_ID,
        o.ORDER_DATE,
        o.STATUS,
        oi.QUANTITY,
        oi.UNIT_PRICE,
        oi.TOTAL_PRICE

    FROM order_items oi

    INNER JOIN orders o
        ON oi.ORDER_ID = o.ORDER_ID

),

final AS (

    SELECT
        ROW_NUMBER() OVER (
            ORDER BY jd.ORDER_ID, jd.PRODUCT_ID
        ) AS ORDER_ITEM_KEY,

        jd.ORDER_ID,

        dc.CUSTOMER_KEY,

        dp.PRODUCT_KEY,

        dd.DATE_KEY,

        jd.ORDER_DATE,

        jd.STATUS AS ORDER_STATUS,

        jd.QUANTITY,

        jd.UNIT_PRICE,

        jd.TOTAL_PRICE AS TOTAL_REVENUE,

        dp.COST AS UNIT_COST,

        jd.QUANTITY * dp.COST AS TOTAL_COST,

        jd.TOTAL_PRICE - (jd.QUANTITY * dp.COST)
            AS TOTAL_PROFIT

    FROM joined_data jd

    INNER JOIN {{ ref('dim_customers_scd2_custom') }} dc
    ON jd.CUSTOMER_ID = dc.CUSTOMER_ID
    AND jd.ORDER_DATE >= TO_DATE(dc.EFFECTIVE_FROM)
    AND jd.ORDER_DATE < TO_DATE(dc.EFFECTIVE_TO)

    INNER JOIN {{ ref('dim_products') }} dp
        ON jd.PRODUCT_ID = dp.PRODUCT_ID
        AND dp.IS_CURRENT = TRUE

    INNER JOIN {{ ref('dim_date') }} dd
        ON jd.ORDER_DATE = dd.FULL_DATE

)

SELECT * FROM final
