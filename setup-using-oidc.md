# Snowflake + dbt + Harness NG CD Setup with OIDC

## Purpose
This document describes how to deploy and promote a dbt project to Snowflake using Harness NG CD only. It uses a Harness Delegate for execution and OIDC for passwordless Snowflake authentication where supported.

## Architecture
- Git repository stores the dbt project.
- Harness NG CD orchestrates the pipeline.
- Harness Delegate executes the pipeline steps in your environment.
- Snowflake hosts the warehouse, databases, schemas, roles, and service user.
- dbt connects to Snowflake from inside a Harness Custom stage.
- OIDC is used for short-lived, passwordless authentication when supported by the execution environment.

## Prerequisites
- A Snowflake account.
- A dbt project stored in Git.
- A Harness NG CD account.
- A Harness Delegate installed in Kubernetes or another supported environment.
- A supported OIDC identity provider or CI runtime for the Snowflake auth flow.
- Access to create Snowflake users, roles, databases, schemas, and warehouses.

## Snowflake Setup

### 1. Create warehouse, roles, databases, and schemas
```sql
CREATE WAREHOUSE dbt_wh WITH WAREHOUSE_SIZE = 'SMALL';

CREATE ROLE dbt_dev;
CREATE ROLE dbt_prod;

CREATE DATABASE dbt_dev;
CREATE DATABASE dbt_prod;

CREATE SCHEMA dbt_dev.results;
CREATE SCHEMA dbt_prod.results;
```

### 2. Create a service user for OIDC
Use a Snowflake service user mapped to your OIDC issuer and subject.

```sql
CREATE USER dbt_service
  TYPE = SERVICE
  WORKLOAD_IDENTITY = (
    TYPE = OIDC
    ISSUER = 'YOUR_OIDC_ISSUER'
    SUBJECT = 'YOUR_OIDC_SUBJECT'
  );
```

Replace `YOUR_OIDC_ISSUER` and `YOUR_OIDC_SUBJECT` with the values required by your OIDC provider and execution environment.

### 3. Grant permissions
```sql
GRANT USAGE ON WAREHOUSE dbt_wh TO ROLE dbt_dev;
GRANT USAGE ON WAREHOUSE dbt_wh TO ROLE dbt_prod;

GRANT USAGE ON DATABASE dbt_dev TO ROLE dbt_dev;
GRANT USAGE ON DATABASE dbt_prod TO ROLE dbt_prod;

GRANT USAGE ON SCHEMA dbt_dev.results TO ROLE dbt_dev;
GRANT USAGE ON SCHEMA dbt_prod.results TO ROLE dbt_prod;
```

### 4. Keep dev and prod separate
Use one Snowflake target for dev and another for prod. Snowflake CI/CD guidance recommends separate environments for development and production [web:109][web:4].

## dbt Project Setup

### profiles.yml
```yaml
config:
  send_anonymous_usage_stats: false

my_dbt_project:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: YOUR_ACCOUNT
      user: dbt_service
      authenticator: oauth
      role: dbt_dev
      database: dbt_dev
      schema: results
      warehouse: dbt_wh
    prod:
      type: snowflake
      account: YOUR_ACCOUNT
      user: dbt_service
      authenticator: oauth
      role: dbt_prod
      database: dbt_prod
      schema: results
      warehouse: dbt_wh
```

If your dbt adapter requires a specific token path or OIDC-specific connection setting, adjust the profile to match the Snowflake CLI or dbt Snowflake auth guidance used in your runtime.

### Suggested repo layout
```text
.
├── dbt_project.yml
├── profiles.yml
├── models/
├── tests/
└── macros/
```

### Recommended dbt commands
- `dbt deps`
- `dbt build --target dev`
- `dbt build --target prod`
- `dbt test --target dev`
- `dbt test --target prod`

## Harness Delegate Setup

### 1. Install the Delegate
Install the Harness Delegate in the environment where the pipeline will run. Harness uses the Delegate to execute work in your environment [web:38][web:44].

### 2. Verify the Delegate
Confirm the Delegate pod or process is running and healthy, and confirm it appears in Harness as available.

### 3. Add a delegate selector
Assign a selector such as `firstk8sdel` and reference that selector in your pipeline stage config.

## Harness NG CD Pipeline

### Pipeline model
Use a **Custom stage** for dbt command execution. The Custom stage is the right choice when you need script-style execution in Harness CD [web:47][web:90].

### Example pipeline
```yaml
pipeline:
  name: snowflake-dbt-cd-oidc
  projectIdentifier: your_project
  orgIdentifier: your_org
  stages:
    - stage:
        name: run-dbt
        type: Custom
        spec:
          execution:
            steps:
              - step:
                  name: dbt-deps
                  type: ShellScript
                  spec:
                    shell: Bash
                    delegateSelectors:
                      - firstk8sdel
                    source:
                      type: Inline
                      spec:
                        script: |-
                          cd /workspace/repo
                          dbt deps

              - step:
                  name: dbt-build-prod
                  type: ShellScript
                  spec:
                    shell: Bash
                    delegateSelectors:
                      - firstk8sdel
                    source:
                      type: Inline
                      spec:
                        script: |-
                          cd /workspace/repo
                          snow auth oidc read-token --type github
                          dbt build --target prod
```

### Step behavior
- `dbt-deps` installs dbt packages.
- `snow auth oidc read-token` retrieves the OIDC token in supported environments.
- `dbt-build-prod` runs the production build against Snowflake.
- The Delegate executes the steps in the selected environment.

## OIDC Notes

### When to use OIDC
Use OIDC when your execution environment can obtain a short-lived identity token and Snowflake can validate that identity directly [web:98][web:109].

### Why it helps
- No long-lived Snowflake private key.
- Better secret hygiene.
- Short-lived authentication aligned with CI/CD best practices [web:98][web:109].

### What to verify
- The OIDC issuer is allowed by Snowflake.
- The subject claim matches the service user mapping.
- The runtime can request an OIDC token.
- The pipeline step has the required environment variables or auth context.

## Secrets and Variables

### Store these as Harness secrets
- Git credentials or token if the repo is private.
- Any environment-specific values not meant to live in Git.

### Typical variables
- `SNOWFLAKE_ACCOUNT`
- `SNOWFLAKE_USER`
- `SNOWFLAKE_ROLE`
- `DBT_TARGET`
- `DBT_DATABASE`
- `DBT_SCHEMA`
- `OIDC_ISSUER`
- `OIDC_SUBJECT`

## Promotion Approach
- Run dev validation in a non-prod stage or pipeline.
- Merge code only after tests pass.
- Run the production pipeline after approval or merge.
- Keep the prod Snowflake role separate from the dev role.

## Validation Checklist
- Delegate is healthy and selected correctly.
- Snowflake OIDC service user is configured correctly.
- `profiles.yml` points to the right target.
- Dev and prod databases are separate.
- Harness pipeline can clone the repo and run `dbt build`.
- Prod runs use the prod role and prod database.

## Troubleshooting
- If the Delegate is not available, check pod health, networking, and selector tags.
- If OIDC auth fails, verify the issuer, subject, and runtime token availability.
- If dbt cannot connect, verify account, role, database, and schema.
- If permissions fail, confirm database, schema, and warehouse grants.
- If the pipeline cannot clone the repo, check Git credentials and network access.

## Notes
Snowflake recommends workload identity federation with OIDC for CI/CD so that no long-lived secrets are stored in the CI system [web:109]. Harness CD runs work through the Delegate in your environment [web:38][web:44].
