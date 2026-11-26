SELECT *
FROM {{ ref('stg_orders') }}
WHERE ORDER_DATE > CURRENT_DATE()