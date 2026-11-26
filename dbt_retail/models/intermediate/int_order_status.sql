SELECT
    ORDER_STATUS,
    STATUS_DESCRIPTION,
    IS_FINAL_STATUS
FROM {{ ref('order_status_mapping') }}