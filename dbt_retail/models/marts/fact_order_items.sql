
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

customer_versions AS (

    SELECT
        dc.*,
        civ.EFFECTIVE_FROM AS INITIAL_EFFECTIVE_FROM,

        ROW_NUMBER() OVER (
            PARTITION BY dc.CUSTOMER_ID
            ORDER BY dc.EFFECTIVE_FROM, dc.CUSTOMER_KEY
        ) AS VERSION_NUMBER

    FROM {{ ref('dim_customers_scd2_custom') }} dc

    LEFT JOIN {{ ref('customer_initial_validity') }} civ
        ON dc.CUSTOMER_ID = civ.CUSTOMER_ID

),

customer_validity AS (

    SELECT
        *,
        CASE
            WHEN VERSION_NUMBER = 1
                THEN COALESCE(INITIAL_EFFECTIVE_FROM, EFFECTIVE_FROM)
            ELSE EFFECTIVE_FROM
        END AS MATCH_EFFECTIVE_FROM

    FROM customer_versions

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

    INNER JOIN customer_validity dc
        ON jd.CUSTOMER_ID = dc.CUSTOMER_ID
        AND jd.ORDER_DATE >= TO_DATE(dc.MATCH_EFFECTIVE_FROM)
        AND jd.ORDER_DATE < TO_DATE(dc.EFFECTIVE_TO)

    INNER JOIN {{ ref('dim_products') }} dp
        ON jd.PRODUCT_ID = dp.PRODUCT_ID
        AND dp.IS_CURRENT = TRUE

    INNER JOIN {{ ref('dim_date') }} dd
        ON jd.ORDER_DATE = dd.FULL_DATE

)

SELECT * FROM final
