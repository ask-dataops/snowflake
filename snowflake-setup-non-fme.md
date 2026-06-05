# Snowflake + dbt + Harness NG CD Setup

## Purpose
This document describes how to deploy and promote a dbt project to Snowflake using Harness NG CD only. It uses a Harness Delegate and a Custom stage for script execution.

## Architecture
- Git repository stores the dbt project.
- Harness NG CD orchestrates the pipeline.
- Harness Delegate executes the pipeline steps in your environment.
- Snowflake hosts the warehouse, databases, schemas, roles, and service account.
- dbt connects to Snowflake from inside a Harness Custom stage.

## Prerequisites
- A Snowflake account.
- A dbt project stored in Git.
- A Harness NG CD account.
- A Harness Delegate installed in Kubernetes or another supported environment.
- A private key for Snowflake key-pair authentication.
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

### 2. Create a service user
```sql
CREATE USER dbt_service
  DEFAULT_ROLE = dbt_dev
  MUST_CHANGE_PASSWORD = FALSE;
```

### 3. Configure key-pair authentication
Upload the RSA public key to the Snowflake user and keep the private key in a secret store such as Harness Secrets.

### 4. Grant permissions
```sql
GRANT USAGE ON WAREHOUSE dbt_wh TO ROLE dbt_dev;
GRANT USAGE ON WAREHOUSE dbt_wh TO ROLE dbt_prod;

GRANT USAGE ON DATABASE dbt_dev TO ROLE dbt_dev;
GRANT USAGE ON DATABASE dbt_prod TO ROLE dbt_prod;

GRANT USAGE ON SCHEMA dbt_dev.results TO ROLE dbt_dev;
GRANT USAGE ON SCHEMA dbt_prod.results TO ROLE dbt_prod;
```

### 5. Keep dev and prod separate
Use one Snowflake target for dev and another for prod. Snowflake CI/CD guidance recommends separate environments for development and production [web:4].

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
      private_key_path: /secrets/dbt_service_key.pem
      role: dbt_dev
      database: dbt_dev
      schema: results
      warehouse: dbt_wh
    prod:
      type: snowflake
      account: YOUR_ACCOUNT
      user: dbt_service
      private_key_path: /secrets/dbt_service_key.pem
      role: dbt_prod
      database: dbt_prod
      schema: results
      warehouse: dbt_wh
```

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

Snowflake’s docs describe a CI/CD flow where pull requests validate in dev and merges promote to prod [web:4].

## Harness Delegate Setup

### 1. Install the Delegate
Install the Harness Delegate in the environment where the pipeline will run. Harness uses the Delegate to execute work in your environment [web:38][web:44].

### 2. Verify the Delegate
Confirm the Delegate pod or process is running and healthy, and confirm it appears in Harness as available.

### 3. Add a delegate selector
Assign a selector such as `firstk8sdel` and reference that selector in your pipeline infrastructure or stage config.

## Harness NG CD Pipeline

### Pipeline model
Use a **Deploy stage** for the overall release flow and a **Custom stage** for dbt command execution. The Custom stage is the right choice when you need script-style execution in Harness CD [web:47][web:90].

### Example pipeline
```yaml
pipeline:
  name: snowflake-dbt-cd
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
                          dbt build --target prod
```

### Step behavior
- `dbt-deps` installs dbt packages.
- `dbt-build-prod` runs the production build against Snowflake.
- The Delegate executes the steps in the selected environment.

## Secrets and Variables

### Store these as Harness secrets
- Snowflake private key.
- Git credentials or token if the repo is private.
- Any environment-specific values not meant to live in Git.

### Typical variables
- `SNOWFLAKE_ACCOUNT`
- `SNOWFLAKE_USER`
- `SNOWFLAKE_PRIVATE_KEY_PATH`
- `DBT_TARGET`
- `DBT_ROLE`
- `DBT_DATABASE`
- `DBT_SCHEMA`

## Promotion Approach
- Run dev validation in a non-prod stage or pipeline.
- Merge code only after tests pass.
- Run the production pipeline after approval or merge.
- Keep the prod Snowflake role separate from the dev role.

## Validation Checklist
- Delegate is healthy and selected correctly.
- Snowflake key-pair authentication works.
- `profiles.yml` points to the right target.
- Dev and prod databases are separate.
- Harness pipeline can clone the repo and run `dbt build`.
- Prod runs use the prod role and prod database.

## Troubleshooting
- If the Delegate is not available, check pod health, networking, and selector tags.
- If dbt cannot connect, verify the private key, Snowflake account, and role.
- If permissions fail, confirm database, schema, and warehouse grants.
- If the pipeline cannot clone the repo, check Git credentials and network access.

## Notes
Snowflake supports dbt CI/CD with separate dev and prod environments and a `profiles.yml` configured for both targets [web:4]. Harness CD runs work through the Delegate in your environment [web:38][web:44].
