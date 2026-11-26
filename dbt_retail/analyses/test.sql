SELECT 
    *
FROM {{ source('retail_raw', 'RAW_INVENTORY') }}    