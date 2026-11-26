
{{
    config(
        materialized='table'
    )
}}

WITH date_spine AS (

    SELECT
        DATEADD(
            DAY,
            SEQ4(),
            '2025-01-01'::DATE
        )::DATE AS FULL_DATE

    FROM TABLE(GENERATOR(ROWCOUNT => 669))

),

final AS (

    SELECT
        TO_NUMBER(TO_CHAR(FULL_DATE, 'YYYYMMDD')) AS DATE_KEY,

        FULL_DATE,

        DAY(FULL_DATE) AS DAY,

        MONTH(FULL_DATE) AS MONTH,

        MONTHNAME(FULL_DATE) AS MONTH_NAME,

        QUARTER(FULL_DATE) AS QUARTER,

        'Q' || QUARTER(FULL_DATE) AS QUARTER_NAME,

        YEAR(FULL_DATE) AS YEAR,

        DAYNAME(FULL_DATE) AS DAY_NAME,

        DAYOFWEEKISO(FULL_DATE) AS DAY_OF_WEEK,

        WEEKOFYEAR(FULL_DATE) AS WEEK_OF_YEAR,

        CASE
            WHEN DAYOFWEEKISO(FULL_DATE) IN (6, 7)
            THEN TRUE
            ELSE FALSE
        END AS IS_WEEKEND

    FROM date_spine

)

SELECT * FROM final
