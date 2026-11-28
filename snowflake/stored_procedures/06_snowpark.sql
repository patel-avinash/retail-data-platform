-- using snowpark
-- Imagine the retail company receives a daily customer CSV file.

-- Before processing that data, we need to validate it:
-- - Customer ID must not be NULL.
-- - Customer name must not be NULL.
-- - Email must follow a valid format.
-- - Customer city must not be empty.
-- We'll build a Python Snowpark validation procedure that checks customer records and produces validation results for our ingestion pipeline.
-- first check snoeflake environment
SELECT CURRENT_DATABASE(), CURRENT_SCHEMA(), CURRENT_WAREHOUSE();

USE DATABASE RETAIL_DEV;

USE SCHEMA RETAIL_DEV.RAW;

--inspect the customer table
DESCRIBE TABLE RETAIL_DEV.RAW.RAW_CUSTOMERS;

-- Our business requirement is to detect:
-- 1. Missing customer IDs.
-- 2. Missing customer names.
-- 3. Missing cities.
-- 4. Missing emails.
-- 5. Invalid email formats.
-- 6. Duplicate customer IDs.

WITH CUSTOMER_PROFILE AS (
    SELECT
        COUNT(*) AS TOTAL_CUSTOMERS,

        COUNT_IF(
            CUSTOMER_ID IS NULL OR TRIM(CUSTOMER_ID) = ''
        ) AS MISSING_CUSTOMER_ID,

        COUNT_IF(
            NAME IS NULL OR TRIM(NAME) = ''
        ) AS MISSING_NAME,

        COUNT_IF(
            CITY IS NULL OR TRIM(CITY) = ''
        ) AS MISSING_CITY,

        COUNT_IF(
            EMAIL IS NULL OR TRIM(EMAIL) = ''
        ) AS MISSING_EMAIL,

        COUNT_IF(
            EMAIL IS NOT NULL
            AND TRIM(EMAIL) <> ''
            AND NOT REGEXP_LIKE(
                TRIM(EMAIL),
                '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
            )
        ) AS INVALID_EMAIL

    FROM RETAIL_DEV.RAW.RAW_CUSTOMERS
),

DUPLICATE_PROFILE AS (
    SELECT COUNT(*) AS DUPLICATE_CUSTOMER_ID_GROUPS
    FROM (
        SELECT CUSTOMER_ID
        FROM RETAIL_DEV.RAW.RAW_CUSTOMERS
        WHERE CUSTOMER_ID IS NOT NULL
        GROUP BY CUSTOMER_ID
        HAVING COUNT(*) > 1
    )
)

SELECT *
FROM CUSTOMER_PROFILE
CROSS JOIN DUPLICATE_PROFILE;

--inspect duplicates rows
SELECT
    CUSTOMER_ID,
    COUNT(*) AS RECORD_COUNT,
    COUNT(DISTINCT NAME) AS NAME_VARIATIONS,
    COUNT(DISTINCT CITY) AS CITY_VARIATIONS,
    COUNT(DISTINCT EMAIL) AS EMAIL_VARIATIONS
FROM RETAIL_DEV.RAW.RAW_CUSTOMERS
WHERE CUSTOMER_ID IS NOT NULL
GROUP BY CUSTOMER_ID
HAVING COUNT(*) > 1
ORDER BY RECORD_COUNT DESC;

--inspect customers
SELECT
    CUSTOMER_ID,
    NAME,
    CITY,
    EMAIL,
    STATUS,
    INGESTED_AT
FROM RETAIL_DEV.RAW.RAW_CUSTOMERS
WHERE CUSTOMER_ID IN (
    SELECT CUSTOMER_ID
    FROM RETAIL_DEV.RAW.RAW_CUSTOMERS
    WHERE CUSTOMER_ID IS NOT NULL
    GROUP BY CUSTOMER_ID
    HAVING COUNT(*) > 1
)
ORDER BY CUSTOMER_ID, INGESTED_AT;

-- Build a duplicate classification check
-- IDENTICAL_RECORDS: Same customer business attributes.
-- CONFLICTING_RECORDS: Different customer business attributes.
SELECT
    CUSTOMER_ID,
    COUNT(*) AS TOTAL_RECORDS,

    COUNT(DISTINCT HASH(
        NAME, CITY, EMAIL, STATUS
    )) AS DISTINCT_BUSINESS_RECORDS,

    COUNT_IF(INGESTED_AT IS NULL) AS NULL_INGESTED_AT_ROWS,

    CASE
        WHEN COUNT(DISTINCT HASH(
            NAME, CITY, EMAIL, STATUS
        )) = 1
        THEN 'IDENTICAL_RECORDS'
        ELSE 'CONFLICTING_RECORDS'
    END AS DUPLICATE_TYPE

FROM RETAIL_DEV.RAW.RAW_CUSTOMERS
WHERE CUSTOMER_ID IS NOT NULL
GROUP BY CUSTOMER_ID
HAVING COUNT(*) > 1
ORDER BY CUSTOMER_ID;

-- Create our Snowpark procedure



CREATE OR REPLACE PROCEDURE RETAIL_DEV.RAW.SP_VALIDATE_CUSTOMERS()
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python==1.9.0','setuptools==80.9.0')
HANDLER = 'main'
EXECUTE AS OWNER
AS
$$
import json
from snowflake.snowpark.functions import col

def main(session):

    # Read existing retail customer data
    customers = session.table(
        "RETAIL_DEV.RAW.RAW_CUSTOMERS"
    )

    # Total records
    total_customers = customers.count()

    # Missing mandatory fields
    missing_customer_id = customers.filter(
        "CUSTOMER_ID IS NULL OR TRIM(CUSTOMER_ID) = ''"
    ).count()

    missing_name = customers.filter(
        "NAME IS NULL OR TRIM(NAME) = ''"
    ).count()

    missing_city = customers.filter(
        "CITY IS NULL OR TRIM(CITY) = ''"
    ).count()

    missing_email = customers.filter(
        "EMAIL IS NULL OR TRIM(EMAIL) = ''"
    ).count()

    # Invalid email addresses
    invalid_email = customers.filter(
        """
        EMAIL IS NOT NULL
        AND TRIM(EMAIL) <> ''
        AND NOT REGEXP_LIKE(
            TRIM(EMAIL),
            '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+[.][A-Za-z]{2,}$'
        )
        """
    ).count()

    # Duplicate customer ID groups
    duplicate_groups = (
        customers
        .filter("CUSTOMER_ID IS NOT NULL")
        .group_by("CUSTOMER_ID")
        .count()
        .filter("COUNT > 1")
        .count()
    )

    # Return validation summary
    result = {
        "total_customers": total_customers,
        "missing_customer_id": missing_customer_id,
        "missing_name": missing_name,
        "missing_city": missing_city,
        "missing_email": missing_email,
        "invalid_email": invalid_email,
        "duplicate_customer_id_groups": duplicate_groups
    }

    return json.dumps(result)

$$;

CALL RETAIL_DEV.RAW.SP_VALIDATE_CUSTOMERS();

SELECT PACKAGE_NAME, VERSION, RUNTIME_VERSION
FROM INFORMATION_SCHEMA.PACKAGES
WHERE LANGUAGE = 'python'
  AND PACKAGE_NAME = 'setuptools'
ORDER BY VERSION DESC
LIMIT 10;

-- Next: Build the parent procedure
-- 1. Calls the customer validation procedure.
-- 2. Captures success or failure.
-- 3. Writes an execution audit record.
-- 4. Later, sends an email notification when needed.

---inspect existing audit table
DESCRIBE TABLE RETAIL_DEV.RAW.INGESTION_AUDIT_LOG;

--check audit table data
SELECT *
FROM RETAIL_DEV.RAW.INGESTION_AUDIT_LOG
ORDER BY AUDIT_ID DESC
LIMIT 5;

--create a new audit table for procedures
CREATE TABLE IF NOT EXISTS RETAIL_DEV.RAW.PROCEDURE_AUDIT_LOG (
    AUDIT_ID NUMBER AUTOINCREMENT START 1 INCREMENT 1,
    PROCEDURE_NAME VARCHAR(100),
    EXECUTION_STATUS VARCHAR(30),
    STARTED_AT TIMESTAMP_NTZ,
    COMPLETED_AT TIMESTAMP_NTZ,
    RESULT_SUMMARY VARCHAR(5000),
    ERROR_MESSAGE VARCHAR(5000)
);

--create parent procedure
CREATE OR REPLACE PROCEDURE RETAIL_DEV.RAW.SP_RUN_CUSTOMER_VALIDATION()
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = (
    'snowflake-snowpark-python==1.9.0',
    'setuptools==80.9.0'
)
HANDLER = 'main'
EXECUTE AS OWNER
AS
$$
import json

def main(session):

    started_at = session.sql(
        "SELECT CURRENT_TIMESTAMP()"
    ).collect()[0][0]

    try:
        # Execute child procedure
        result = session.call(
            "RETAIL_DEV.RAW.SP_VALIDATE_CUSTOMERS"
        )

        # Record successful execution
        session.sql("""
            INSERT INTO RETAIL_DEV.RAW.PROCEDURE_AUDIT_LOG
            (
                PROCEDURE_NAME,
                EXECUTION_STATUS,
                STARTED_AT,
                COMPLETED_AT,
                RESULT_SUMMARY,
                ERROR_MESSAGE
            )
            SELECT
                ?, 'SUCCESS', ?, CURRENT_TIMESTAMP(), ?, NULL
        """, params=[
            "SP_VALIDATE_CUSTOMERS",
            started_at,
            str(result)
        ]).collect()

        return "SUCCESS: Customer validation completed and audit recorded."

    except Exception as e:

        # Record failed execution
        session.sql("""
            INSERT INTO RETAIL_DEV.RAW.PROCEDURE_AUDIT_LOG
            (
                PROCEDURE_NAME,
                EXECUTION_STATUS,
                STARTED_AT,
                COMPLETED_AT,
                RESULT_SUMMARY,
                ERROR_MESSAGE
            )
            SELECT
                ?, 'FAILED', ?, CURRENT_TIMESTAMP(), NULL, ?
        """, params=[
            "SP_VALIDATE_CUSTOMERS",
            started_at,
            str(e)
        ]).collect()

        return "FAILED: " + str(e)

$$;

CALL RETAIL_DEV.RAW.SP_RUN_CUSTOMER_VALIDATION();

--verify the audit table
SELECT *
FROM RETAIL_DEV.RAW.PROCEDURE_AUDIT_LOG
ORDER BY AUDIT_ID DESC
LIMIT 10;

SHOW PARAMETERS LIKE 'TIMEZONE' IN SESSION;

ALTER SESSION SET TIMEZONE = 'Asia/Kolkata';

-- Simulate a child procedure failure
-- for practice of failure check we crete this procedure for show output
CREATE OR REPLACE PROCEDURE RETAIL_DEV.RAW.SP_TEST_FAILURE_HANDLING()
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = (
    'snowflake-snowpark-python==1.9.0',
    'setuptools==80.9.0'
)
HANDLER = 'main'
EXECUTE AS OWNER
AS
$$
def main(session):

    try:
        # Deliberately call a nonexistent child procedure
        session.call(
            "RETAIL_DEV.RAW.SP_CHILD_DOES_NOT_EXIST"
        )

        return "SUCCESS"

    except Exception as e:

        # Record the failure
        session.sql("""
            INSERT INTO RETAIL_DEV.RAW.PROCEDURE_AUDIT_LOG
            (
                PROCEDURE_NAME,
                EXECUTION_STATUS,
                STARTED_AT,
                COMPLETED_AT,
                RESULT_SUMMARY,
                ERROR_MESSAGE
            )
            SELECT
                ?, 'FAILED', CURRENT_TIMESTAMP(),
                CURRENT_TIMESTAMP(), NULL, ?
        """, params=[
            "SP_TEST_FAILURE_HANDLING",
            str(e)
        ]).collect()

        return "FAILURE CAPTURED AND AUDITED"

$$;

CALL RETAIL_DEV.RAW.SP_TEST_FAILURE_HANDLING();

SELECT
    AUDIT_ID,
    PROCEDURE_NAME,
    EXECUTION_STATUS,
    ERROR_MESSAGE
FROM RETAIL_DEV.RAW.PROCEDURE_AUDIT_LOG
WHERE PROCEDURE_NAME = 'SP_TEST_FAILURE_HANDLING'
ORDER BY AUDIT_ID DESC;

---------------------------------------------------------------------------------
-- email notifiaction in snowflake
---------------------------------------------------------------------------------
SHOW NOTIFICATION INTEGRATIONS;

SELECT CURRENT_ROLE();

CREATE NOTIFICATION INTEGRATION RETAIL_EMAIL_INT
    TYPE = EMAIL
    ENABLED = TRUE;

SHOW NOTIFICATION INTEGRATIONS;
DESC NOTIFICATION INTEGRATION RETAIL_EMAIL_INT;

CALL SYSTEM$SEND_EMAIL(
    'RETAIL_EMAIL_INT',
    '***************@gmail.com',
    'Retail Data Warehouse - Failure Alert',
    'Customer validation failed. Please check the audit log.'
);

--update parent procedure add email alert inprocedure

CREATE OR REPLACE PROCEDURE RETAIL_DEV.RAW.SP_RUN_CUSTOMER_VALIDATION()
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = (
    'snowflake-snowpark-python==1.9.0',
    'setuptools==80.9.0'
)
HANDLER = 'main'
EXECUTE AS OWNER
AS
$$

def main(session):

    started_at = session.sql(
        "SELECT CURRENT_TIMESTAMP()"
    ).collect()[0][0]

    try:
        # Execute child procedure
        result = session.call(
            "RETAIL_DEV.RAW.SP_VALIDATE_CUSTOMERS"
        )

        # Record successful execution
        session.sql("""
            INSERT INTO RETAIL_DEV.RAW.PROCEDURE_AUDIT_LOG
            (
                PROCEDURE_NAME,
                EXECUTION_STATUS,
                STARTED_AT,
                COMPLETED_AT,
                RESULT_SUMMARY,
                ERROR_MESSAGE
            )
            SELECT
                ?, 'SUCCESS', ?, CURRENT_TIMESTAMP(), ?, NULL
        """, params=[
            "SP_VALIDATE_CUSTOMERS",
            started_at,
            str(result)
        ]).collect()

        return "SUCCESS: Customer validation completed and audit recorded."

    except Exception as e:

        error_message = str(e)

        # Record failed execution
        session.sql("""
            INSERT INTO RETAIL_DEV.RAW.PROCEDURE_AUDIT_LOG
            (
                PROCEDURE_NAME,
                EXECUTION_STATUS,
                STARTED_AT,
                COMPLETED_AT,
                RESULT_SUMMARY,
                ERROR_MESSAGE
            )
            SELECT
                ?, 'FAILED', ?, CURRENT_TIMESTAMP(), NULL, ?
        """, params=[
            "SP_VALIDATE_CUSTOMERS",
            started_at,
            error_message
        ]).collect()

        # Send failure email
        try:
            session.sql("""
                CALL SYSTEM$SEND_EMAIL(
                    'RETAIL_EMAIL_INT',
                    '***************@gmail.com',
                    'Retail Data Warehouse - Failure Alert',
                    ?
                )
            """, params=[
                "Customer validation failed.\n\nError: " + error_message
            ]).collect()

            return "FAILED: Error audited and email notification sent."

        except Exception as email_error:
            return (
                "FAILED: Error audited, but email notification failed: "
                + str(email_error)
            )

$$;

CALL RETAIL_DEV.RAW.SP_RUN_CUSTOMER_VALIDATION();

SELECT * 
FROM RETAIL_DEV.RAW.PROCEDURE_AUDIT_LOG 
ORDER BY COMPLETED_AT DESC;

DESC TABLE RETAIL_DEV.RAW.INGESTION_CONTROL;


-- we create metadata pipeline using javascript in phase 5 but now in this phase we create using snowpark and also add email

CREATE OR REPLACE PROCEDURE RETAIL_DEV.RAW.SP_PROCESS_RETAIL_INGESTION()
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python==1.9.0', 'setuptools==80.9.0')
HANDLER = 'run'
EXECUTE AS OWNER
AS
$$
import uuid
import re

def run(session):

    batch_id = str(uuid.uuid4())

    loaded = 0
    skipped = 0
    failed = 0
    failed_details = []

    # Read active ingestion configurations
    configs = session.sql("""
        SELECT SOURCE_TABLE, SOURCE_FILE, TARGET_SCHEMA,
               TARGET_TABLE, FILE_FORMAT, STAGE_NAME
        FROM RETAIL_DEV.RAW.INGESTION_CONTROL
        WHERE IS_ACTIVE = TRUE
        ORDER BY CONFIG_ID
    """).collect()

    for config in configs:

        source_table = config["SOURCE_TABLE"]
        source_file = config["SOURCE_FILE"]
        target_schema = config["TARGET_SCHEMA"]
        target_table = config["TARGET_TABLE"]
        file_format = config["FILE_FORMAT"]
        stage_name = config["STAGE_NAME"]

        rows_loaded = 0
        rows_parsed = 0
        rows_rejected = 0
        status = "Failed"
        error_message = ""

        try:
            # Validate SQL identifiers and file path
            if not re.fullmatch(r"[A-Za-z0-9_]+", target_schema):
                raise ValueError("Invalid target schema")

            if not re.fullmatch(r"[A-Za-z0-9_]+", target_table):
                raise ValueError("Invalid target table")

            if not re.fullmatch(r"[A-Za-z0-9_]+", file_format):
                raise ValueError("Invalid file format")

            if not re.fullmatch(r"[A-Za-z0-9_.$@]+", stage_name):
                raise ValueError("Invalid stage name")

            if not re.fullmatch(r"[A-Za-z0-9_./=-]+", source_file):
                raise ValueError("Invalid source file name")

            stage = stage_name if stage_name.startswith("@") else "@" + stage_name

            copy_sql = f"""
                COPY INTO "{target_schema}"."{target_table}"
                FROM {stage}/{source_file}
                FILE_FORMAT = (
                    FORMAT_NAME = 'RETAIL_DEV.RAW.{file_format}'
                )
                ON_ERROR = 'ABORT_STATEMENT'
            """

            copy_results = session.sql(copy_sql).collect()

            for result in copy_results:
                result_data = result.as_dict()

                rows_loaded += int(result_data.get("rows_loaded") or 0)
                rows_parsed += int(result_data.get("rows_parsed") or 0)
                rows_rejected += int(result_data.get("errors_seen") or 0)

                copy_status = str(result_data.get("status", "")).upper()

                if copy_status == "LOAD_SKIPPED":
                    skipped += 1
                    status = "Skipped"

                elif copy_status == "LOADED":
                    status = "Loaded"

            if status == "Loaded":
                loaded += 1

            elif status == "Failed":
                status = "Skipped"
                skipped += 1

        except Exception as err:
            failed += 1
            status = "Failed"
            error_message = str(err)[:4900]

            failed_details.append(
                f"Table: {source_table}\n"
                f"File: {source_file}\n"
                f"Error: {error_message}"
            )

        # Audit insertion will use the existing audit table.
        # Its exact column names must match your Phase 5 definition.

        
        # Insert audit record into existing Phase 5 table
        try:
            session.sql("""
                INSERT INTO RETAIL_DEV.RAW.INGESTION_AUDIT_LOG
                (
                    TABLE_NAME,
                    FILE_NAME,
                    LOAD_STATUS,
                    ROWS_LOADED,
                    ROWS_PARSED,
                    BATCH_ID,
                    ROWS_REJECTED,
                    ERROR_MESSAGE
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, params=[
                source_table,
                source_file,
                status,
                rows_loaded,
                rows_parsed,
                batch_id,
                rows_rejected,
                error_message
            ]).collect()

        except Exception as audit_error:
            failed += 1
            failed_details.append(
                f"Audit logging failed for {source_table}: {str(audit_error)}"
            )


    # Send one email only if something failed
    email_status = ""

    if failed > 0:

        email_body = (
            "Retail Data Warehouse ingestion failure\n\n"
            f"Batch ID: {batch_id}\n"
            f"Loaded: {loaded}\n"
            f"Skipped: {skipped}\n"
            f"Failed: {failed}\n\n"
            "Failure details:\n\n"
            + "\n\n".join(failed_details)
        )

        try:
            session.sql("""
                CALL SYSTEM$SEND_EMAIL(?, ?, ?, ?)
            """, params=[
                "RETAIL_EMAIL_INT",
                "***************@gmail.com",
                "Retail Data Warehouse - Ingestion Failure",
                email_body
            ]).collect()

            email_status = " | Email alert sent"

        except Exception as email_error:
            email_status = " | Email alert failed: " + str(email_error)[:500]

    return (
        f"Batch: {batch_id} | "
        f"Loaded: {loaded} | "
        f"Skipped: {skipped} | "
        f"Failed: {failed}" +
        email_status
    )
$$;

CREATE OR REPLACE TASK RETAIL_DEV.RAW.RETAIL_INGESTION_TASK_PYTHON
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = '5 MINUTE'
AS
    CALL RETAIL_DEV.RAW.SP_PROCESS_RETAIL_INGESTION();

ALTER TASK RETAIL_DEV.RAW.RETAIL_INGESTION_TASK_PYTHON RESUME;
ALTER TASK RETAIL_DEV.RAW.RETAIL_INGESTION_TASK_PYTHON SUSPEND;

SHOW TASKS LIKE 'RETAIL_INGESTION_TASK_PYTHON'
IN SCHEMA RETAIL_DEV.RAW;

SELECT * FROM RETAIL_DEV.RAW.INGESTION_AUDIT_LOG;
SELECT *
FROM RETAIL_DEV.RAW.INGESTION_AUDIT_LOG
ORDER BY BATCH_ID DESC
LIMIT 10;

DESC TABLE RETAIL_DEV.RAW.INGESTION_AUDIT_LOG;

SELECT *
FROM RETAIL_DEV.RAW.INGESTION_AUDIT_LOG
WHERE BATCH_ID = '37ba5111-17a0-4290-836e-39477f9a0963';

SHOW TASKS LIKE 'RETAIL_INGESTION_TASK_PYTHON'
IN SCHEMA RETAIL_DEV.RAW;

--verify
SELECT
    NAME,
    STATE,
    SCHEDULED_TIME,
    COMPLETED_TIME,
    ERROR_MESSAGE
FROM TABLE(
    RETAIL_DEV.INFORMATION_SCHEMA.TASK_HISTORY(
        SCHEDULED_TIME_RANGE_START => DATEADD('HOUR', -2, CURRENT_TIMESTAMP())
    )
)
WHERE NAME = 'RETAIL_INGESTION_TASK_PYTHON'
ORDER BY SCHEDULED_TIME DESC
LIMIT 10;




----------------------------------------------
-- check consumption due to too much credits uses
SHOW WAREHOUSES;

SHOW TASKS IN ACCOUNT;
--stop all task 
ALTER TASK RETAIL_DEV.RAW.PROCESS_CUSTOMER_STREAM_TASK SUSPEND;
ALTER TASK RETAIL_DEV.RAW.PROCESS_INVENTORY_STREAM_TASK SUSPEND;
ALTER TASK RETAIL_DEV.RAW.PROCESS_ORDERS_STREAM_TASK SUSPEND;
ALTER TASK RETAIL_DEV.RAW.PROCESS_ORDER_ITEMS_STREAM_TASK SUSPEND;
ALTER TASK RETAIL_DEV.RAW.PROCESS_PAYMENTS_STREAM_TASK SUSPEND;
ALTER TASK RETAIL_DEV.RAW.PROCESS_PRODUCTS_STREAM_TASK SUSPEND;
ALTER TASK RETAIL_DEV.RAW.RETAIL_INGESTION_TASK SUSPEND;


-- check credit consuptions
SELECT
    WAREHOUSE_NAME,
    SUM(CREDITS_USED) AS TOTAL_CREDITS,
    SUM(CREDITS_USED_COMPUTE) AS COMPUTE_CREDITS,
    SUM(CREDITS_USED_CLOUD_SERVICES) AS CLOUD_SERVICE_CREDITS
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE START_TIME >= DATEADD(DAY, -7, CURRENT_TIMESTAMP())
GROUP BY WAREHOUSE_NAME
ORDER BY TOTAL_CREDITS DESC;

SELECT
    QUERY_TYPE,
    USER_NAME,
    COUNT(*) AS QUERY_COUNT,
    SUM(TOTAL_ELAPSED_TIME) / 1000 AS TOTAL_SECONDS
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE START_TIME >= DATEADD(DAY, -7, CURRENT_TIMESTAMP())
  AND WAREHOUSE_NAME = 'COMPUTE_WH'
GROUP BY QUERY_TYPE, USER_NAME
ORDER BY TOTAL_SECONDS DESC;

SHOW DYNAMIC TABLES IN ACCOUNT;

ALTER DYNAMIC TABLE RETAIL_DEV.STAGING.DT_PRODUCTS_DEMO SUSPEND;