SELECT
    CITY,
    PINCODE,
    STATE
FROM {{ ref('city_pincode_mapping') }}