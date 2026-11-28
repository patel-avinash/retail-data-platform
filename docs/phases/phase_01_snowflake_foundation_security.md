# Phase 1: Snowflake Foundation and Security

## Objective
Create the storage, compute and access foundation before loading any data.

## What was built
- Databases `RETAIL_DEV` and `RETAIL_PROD`.
- Schemas `RAW`, `STAGING`, `MART` in each.
- Reused the existing `COMPUTE_WH` (X-Small, auto-suspend 300 s) instead of creating another.
- Roles `DATA_ENGINEER`, `DBT_DEVELOPER`, `BI_ANALYST`, granted to `SYSADMIN`.
- Warehouse, database, schema and object privileges in both environments.

## Access matrix

| Schema | DATA_ENGINEER | DBT_DEVELOPER | BI_ANALYST |
|---|---|---|---|
| RAW | USAGE, create | USAGE, SELECT | none |
| STAGING | none | USAGE, create | none |
| MART | none | USAGE, create | USAGE, SELECT |

## Testing
Used temporary test tables under each role.
- `BI_ANALYST` reading RAW: denied (after `USE SECONDARY ROLES NONE`).
- `DBT_DEVELOPER` reading RAW: allowed.
- `BI_ANALYST` reading MART: allowed.
- `DBT_DEVELOPER` creating in STAGING: allowed.

## Lessons
- `CREATE ROLE` failed under `SYSADMIN`; it needed `ACCOUNTADMIN`.
- `BI_ANALYST` first appeared to read RAW because secondary roles were active.
- `USAGE` on a database does not grant access to its schemas or tables.

## SQL location
`snowflake/setup/`, `snowflake/security/`
