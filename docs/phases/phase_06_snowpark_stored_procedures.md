# Phase 6: Snowpark and Stored Procedures

## Objective
Add validation, orchestration, audit logging and alerts using Python inside Snowflake.

## What was built

| Object | Purpose |
|---|---|
| `SP_VALIDATE_CUSTOMERS` | Child procedure: customer data-quality checks |
| `SP_RUN_CUSTOMER_VALIDATION` | Parent procedure: calls the child, writes audit row, handles failure |
| `PROCEDURE_AUDIT_LOG` | Procedure name, status, start/end, summary, error |
| `RETAIL_EMAIL_INT` | Email notification integration |
| `SP_PROCESS_RETAIL_INGESTION` | Python version of the ingestion procedure |
| `RETAIL_INGESTION_TASK_PYTHON` | Task scheduling the Python procedure |

## Verified results
- Validation: 2,030 customers, 0 missing required fields, 0 invalid emails, 8 duplicate `CUSTOMER_ID` groups.
- A simulated child failure (calling a nonexistent procedure) produced a `FAILED` audit row and an email.
- The email integration test returned TRUE and an email arrived.
- The Python ingestion procedure returned 0 loaded, 6 skipped, 0 failed.

## Lessons
- `ModuleNotFoundError: pkg_resources` was fixed by pinning `snowflake-snowpark-python 1.9.0` and `setuptools 80.9.0`.
- A procedure that catches errors and returns normally still shows the Task as SUCCEEDED, so monitor the audit table too.
- Detecting duplicates is not the same as removing them.

## Not yet verified
The Python Task was created and resumed, but a completed scheduled run and a load of a genuinely new file through the Python procedure were not shown. Describe it as configured, not production-validated.

## Code location
`snowflake/stored_procedures/`, `snowpark/`
