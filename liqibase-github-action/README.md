# Liquibase Snowflake Migrations

Database schema migration project using Liquibase 5.1 with Snowflake, deployed via GitHub Actions.

---

## Project Structure

```
repo-root/
│
├── config/                             # Non-sensitive config and Liquibase master files
│   ├── config.yaml                     # Environment definitions (account, db, warehouse, role)
│   ├── db.changelog-master.xml         # Liquibase entry point — includes catalog files only
│   └── liquibase.properties            # Default Liquibase connection settings
│
├── liquibase/
│   └── sql/                            # Catalog files and SQL changesets
│       ├── changelog.schema.xml        # Catalog for 1_SCHEMA/ folder
│       └── 1_SCHEMA/                   # DDL changesets (tables, indexes, constraints)
│           ├── 001_create_users.sql
│           └── 002_create_orders.sql
│
└── .github/
    └── workflows/
        └── deploy.yml                  # GitHub Actions workflow (manual trigger)
```

---

## How It Works

```
deploy.yml (workflow_dispatch)
    │
    ├── Job 1: load-config
    │       Reads config/config.yaml for the chosen environment
    │       Exports all non-sensitive values as job outputs
    │
    └── Job 2: migrate
            Uses GitHub Environment secrets (SNOWFLAKE_USER, SNOWFLAKE_PASSWORD)
            Combines with config outputs to build the JDBC URL
            Runs: validate → update → post-migration summary
```

---

## Environments

| Environment  | Purpose                        | Protection Rules     |
|-------------|--------------------------------|----------------------|
| `dev`        | Developer testing              | None                 |
| `staging`    | Integration testing            | None                 |
| `performance`| Load and performance testing   | Optional reviewer    |
| `preprod`    | Final pre-release validation   | Required reviewer    |
| `prod`       | Production                     | Required reviewer    |

---

## Setup

### 1. Configure GitHub Environments

Go to **Repo → Settings → Environments** and create each environment listed above.

For each environment, add these secrets:

| Secret             | Description                        |
|-------------------|------------------------------------|
| `SNOWFLAKE_USER`   | Service account username           |
| `SNOWFLAKE_PASSWORD` | Service account password         |

Set protection rules on `preprod` and `prod` to require manual approval.

### 2. Update `config/config.yaml`

Replace placeholder values with your actual Snowflake account identifiers:

```yaml
environments:
  dev:
    snowflake_account: xy12345.us-east-1   # your Snowflake account ID
    snowflake_db: DEV_DATABASE
    snowflake_schema: PUBLIC
    snowflake_warehouse: DEV_WH
    snowflake_role: DEV_ROLE
    liquibase_contexts: dev
```

### 3. Run the workflow

Go to **Actions → Liquibase Snowflake Migration → Run workflow**, pick an environment, and click Run.

---

## Adding a New Environment

**Step 1** — Add a block to `config/config.yaml`:
```yaml
  uat:
    snowflake_account: xy12345.us-east-1
    snowflake_db: UAT_DATABASE
    snowflake_schema: PUBLIC
    snowflake_warehouse: UAT_WH
    snowflake_role: UAT_ROLE
    liquibase_contexts: uat
```

**Step 2** — Add `uat` to the options list in `.github/workflows/deploy.yml`:
```yaml
options:
  - dev
  - staging
  - uat          # ← add here
  - performance
  - preprod
  - prod
```

**Step 3** — Create a `uat` GitHub Environment with `SNOWFLAKE_USER` and `SNOWFLAKE_PASSWORD` secrets.

No other changes needed — the workflow reads everything else dynamically.

---

## Adding a New SQL Changeset

1. Create a new `.sql` file in `liquibase/sql/1_SCHEMA/` (or a new subfolder for a new catalog)
2. Follow the naming convention: `NNN_description.sql`
3. Add the Liquibase header:

```sql
-- liquibase formatted sql

-- changeset author:NNN dbms:snowflake contextFilter:dev,staging,performance,preprod,prod
-- comment: Description of what this changeset does
CREATE TABLE IF NOT EXISTS MY_TABLE (
    ...
);

-- rollback DROP TABLE IF EXISTS MY_TABLE;
```

Rules:
- **Always use `IF NOT EXISTS`** on CREATE statements (Snowflake is case-sensitive for object names — use UPPERCASE)
- **Always add a rollback** comment
- **Never reuse a changeset ID** — IDs must be unique across the entire project
- **Never modify an existing changeset** that has already run — create a new one instead

---

## Adding a New Catalog (e.g. views, seed data)

**Step 1** — Create the catalog file `liquibase/sql/changelog.views.xml`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<databaseChangeLog ...>
    <includeAll path="2_VIEWS/"
                relativeToChangelogFile="true"
                errorIfMissingOrEmpty="false"/>
</databaseChangeLog>
```

**Step 2** — Create the folder `liquibase/sql/2_VIEWS/` and add your `.sql` files.

**Step 3** — Reference it in `config/db.changelog-master.xml`:
```xml
<include file="../liquibase/sql/changelog.views.xml" relativeToChangelogFile="true"/>
```

---

## Changelog Structure Rules

To avoid duplicate changeset errors (a common Liquibase pitfall):

- `db.changelog-master.xml` uses `<include>` — never `<includeAll>`
- Each catalog XML (`changelog.schema.xml`) uses `<includeAll>` on **its own subfolder only**
- No folder is ever scanned by more than one file

```
master.xml
  └── <include> changelog.schema.xml
        └── <includeAll> 1_SCHEMA/         ← only scanned here
```

---

## Secrets vs Config

| Type                                    | Lives in              |
|----------------------------------------|-----------------------|
| Snowflake account, db, warehouse, role | `config/config.yaml`  |
| Snowflake username, password           | GitHub Environment Secrets |
| Never committed to repo                | Credentials of any kind |

---

## Troubleshooting

**Duplicate changeset error**
- Check `config/db.changelog-master.xml` uses `<include>` not `<includeAll>`
- Verify no folder is referenced by more than one catalog file
- Run: `grep -r 'changeset' liquibase/sql/ | grep 'id:' | sort | uniq -d`

**Path mismatch after rename**
- Query: `SELECT DISTINCT FILENAME FROM DATABASECHANGELOG;`
- If old paths exist, update them or run `liquibase clearCheckSums`

**Snowflake warehouse suspended**
- Add to the workflow before the Liquibase step:
  ```yaml
  - run: snowsql -q "ALTER WAREHOUSE $WAREHOUSE RESUME IF SUSPENDED"
  ```

**Environment not found in config**
- The `load-config` job validates the environment exists in `config.yaml` before proceeding
- Add the missing environment block to `config/config.yaml`
