{{
    config(
        materialized='incremental',
        incremental_strategy='append',
        pre_hook=[
            "
            {% if is_incremental() %}
            UPDATE {{ this }} AS target
            SET
                EFFECTIVE_TO = CURRENT_TIMESTAMP()::TIMESTAMP_NTZ,
                IS_CURRENT = FALSE
            FROM (
                SELECT
                    CUSTOMER_ID,
                    SHA2(
                        CONCAT_WS('|',
                            COALESCE(CUSTOMER_NAME, ''),
                            COALESCE(CITY, ''),
                            COALESCE(EMAIL, ''),
                            COALESCE(STATUS, '')
                        ),
                        256
                    ) AS HASH_VALUE
                    FROM {{ ref('stg_customers') }}            ) AS source
            WHERE target.CUSTOMER_ID = source.CUSTOMER_ID
              AND target.IS_CURRENT = TRUE
              AND target.HASH_VALUE <> source.HASH_VALUE
            {% endif %}
            "
        ]
    )
}}

WITH source_data AS (

    SELECT
        CUSTOMER_ID,
        CUSTOMER_NAME,
        CITY,
        EMAIL,
        STATUS,

        SHA2(
            CONCAT_WS('|',
                COALESCE(CUSTOMER_NAME, ''),
                COALESCE(CITY, ''),
                COALESCE(EMAIL, ''),
                COALESCE(STATUS, '')
            ),
            256
        ) AS HASH_VALUE

    FROM {{ ref('stg_customers') }}

),



{% if is_incremental() %}

latest_records AS (

    SELECT
        CUSTOMER_ID,
        HASH_VALUE
    FROM {{ this }}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY CUSTOMER_ID
        ORDER BY EFFECTIVE_FROM DESC, CUSTOMER_KEY DESC
    ) = 1

),

{% endif %}

new_records AS (

    SELECT s.*
    FROM source_data s

    {% if is_incremental() %}

    LEFT JOIN latest_records lr
        ON s.CUSTOMER_ID = lr.CUSTOMER_ID

    WHERE lr.CUSTOMER_ID IS NULL
       OR lr.HASH_VALUE <> s.HASH_VALUE

    {% endif %}

),



numbered_records AS (

    SELECT
        ROW_NUMBER() OVER (
            ORDER BY CUSTOMER_ID
        ) AS ROW_NUM,
        *
    FROM new_records

)

SELECT
    {% if is_incremental() %}
        (SELECT COALESCE(MAX(CUSTOMER_KEY), 0) FROM {{ this }})
    {% else %}
        0
    {% endif %}
    + ROW_NUM AS CUSTOMER_KEY,

    CUSTOMER_ID,
    CUSTOMER_NAME,
    CITY,
    EMAIL,
    STATUS,
    HASH_VALUE,

    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ AS EFFECTIVE_FROM,
    TO_TIMESTAMP_NTZ('9999-12-31 23:59:59') AS EFFECTIVE_TO,
    TRUE AS IS_CURRENT

FROM numbered_records
