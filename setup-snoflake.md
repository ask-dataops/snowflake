# Snowflake + dbt + Harness CD Setup
https://developer.harness.io/docs/feature-management-experimentation/warehouse-native/integrations/snowflake/
## Overview
This document describes a practical setup for using Harness CD with a Delegate to run dbt against Snowflake.

## Architecture
- Git repository contains the dbt project.
- Harness CD orchestrates deploy and execution.
- Harness Delegate runs the pipeline steps in your environment.
- Snowflake hosts the warehouse, database, schemas, roles, and service account.

## Prerequisites
- A Snowflake account.
- A dbt project in Git.
- A Harness account with CD enabled.
- A Kubernetes cluster for the Harness Delegate.
- A private key for Snowflake key-pair authentication.

## Snowflake Setup

### 1. Create warehouse, roles, and databases
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
Upload the RSA public key to the Snowflake user and keep the private key in a secret store.

### 4. Grant permissions
```sql
GRANT USAGE ON WAREHOUSE dbt_wh TO ROLE dbt_dev;
GRANT USAGE ON WAREHOUSE dbt_wh TO ROLE dbt_prod;
GRANT USAGE ON DATABASE dbt_dev TO ROLE dbt_dev;
GRANT USAGE ON DATABASE dbt_prod TO ROLE dbt_prod;
```

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

### Recommended repo layout
```text
.
├── dbt_project.yml
├── profiles.yml
├── models/
├── tests/
└── macros/
```

## Harness Delegate Setup

### 1. Install the Delegate
Install the Harness Delegate in Kubernetes using the Helm chart provided by Harness.

### 2. Verify the Delegate
Check that the Delegate pod is running and healthy, then confirm it appears in Harness with a green status.

### 3. Add Delegate Selector
Tag the Delegate, for example `firstk8sdel`, and use that selector in your pipelines and connectors.

## Harness Connectors

### Snowflake connector
Create a Snowflake connector in Harness using key-pair auth and point it to the appropriate Snowflake account, warehouse, database, schema, and role.

### Kubernetes connector
Create a Kubernetes connector that points to the cluster where the Delegate runs.

## Harness CD Pipeline

### Suggested flow
1. Checkout the dbt repo.
2. Install dependencies.
3. Run `dbt build` for dev or prod.
4. Optionally deploy Snowflake dbt project objects.
5. Promote to production after validation.

### Example pipeline YAML
```yaml
pipeline:
  name: snowflake-dbt-prod-cd-pipeline
  projectIdentifier: your_project
  orgIdentifier: your_org
  stages:
    - stage:
        name: run-dbt-prod
        type: Deploy
        spec:
          serviceRefs:
            - snowflake-dbt-service
          environmentRefs:
            - k8s-prod-env
          infrastructure:
            type: Kubernetes
            spec:
              connectorRef: k8s-cluster-connector
              namespace: dpt-prod
              delegateSelectors:
                - firstk8sdel
          execution:
            steps:
              - step:
                  name: dbt-build-prod
                  type: Run
                  spec:
                    image: dbt-snowflake:latest
                    shell: Bash
                    command: |-
                      cd /workspace/repo
                      dbt deps
                      dbt build --target prod
```

## Promotion Strategy
- Run CI in dev or on pull requests.
- Validate models and tests.
- Promote the same version to prod using Harness CD.
- Use separate Snowflake roles and schemas for each environment.

## Troubleshooting
- If the Delegate is offline, verify pod health and network access.
- If Snowflake auth fails, confirm the private key, account name, and role.
- If dbt cannot connect, check `profiles.yml`, warehouse permissions, and schema grants.
- If Harness cannot find the Delegate, verify the delegate selector tags.
