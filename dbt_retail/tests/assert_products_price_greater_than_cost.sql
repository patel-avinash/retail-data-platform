SELECT *
FROM {{ ref('stg_products') }}
WHERE PRICE <= COST