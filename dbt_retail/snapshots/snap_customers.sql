
{% snapshot snap_customers %}

{{
    config(
        schema='MART',
        unique_key='customer_id',
        strategy='check',
        check_cols=[
            'customer_name',
            'city',
            'email',
            'status'
        ]
    )
}}

SELECT
    CUSTOMER_ID,
    CUSTOMER_NAME,
    CITY,
    EMAIL,
    STATUS

{# FROM {{ ref('stg_customers') }} #}
FROM RETAIL_DEV.STAGING.TEST_STG_CUSTOMERS

{% endsnapshot %}
