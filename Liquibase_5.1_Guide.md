# Liquibase 5.1 — Changelogs, Includes & GitHub Actions Logging Guide

---

## 1. Logging Changeset Execution (GitHub Actions)

### Default INFO Level Output

Without any extra flags, Liquibase at INFO level logs every changeset result:

```
# Changeset executed
INFO  Running Changeset: changelog.xml::create-view-employee-summary::ak
INFO  ChangeSet changelog.xml::create-view-employee-summary::ak ran successfully in 62ms

# Changeset skipped (already applied)
INFO  ChangeSet changelog.xml::create-view-employee-summary::ak already ran. Skipping.

# Changeset failed
SEVERE  ChangeSet changelog.xml::create-view-employee-summary::ak failed.
```

### GitHub Actions — Capture and Assert

```yaml
- name: Run Liquibase
  run: |
    liquibase \
      --changelog-file=changelog.xml \
      --url=${{ secrets.DB_URL }} \
      --username=${{ secrets.DB_USER }} \
      --password=${{ secrets.DB_PASS }} \
      update 2>&1 | tee liquibase.log

- name: Check view changeset result
  run: |
    CS="create-view-employee-summary"
    if grep -q "${CS}.*ran successfully" liquibase.log; then
      echo "✅ View created/updated this run"
    elif grep -q "${CS}.*already ran" liquibase.log; then
      echo "ℹ️ View changeset skipped — already applied"
    elif grep -q "${CS}.*failed" liquibase.log; then
      echo "❌ View changeset FAILED"
      exit 1
    fi
```

### INFO vs DEBUG — What Each Shows

| Detail | INFO | DEBUG |
|---|---|---|
| Changeset executed / skipped | ✅ | ✅ |
| Execution time (ms) | ✅ | ✅ |
| Actual SQL sent to DB | ❌ | ✅ |
| Rows affected | ❌ | ✅ |
| JDBC connection details | ❌ | ✅ |

> For view creation, INFO is sufficient — the SQL is already in your changeset file.

---

## 2. View Changesets — Structure & Best Practices

### Option A — `<createView>` Tag (Recommended)

```xml
<changeSet id="create-view-employee-summary" author="ak" runOnChange="true">
    <createView viewName="EMPLOYEE_SUMMARY" replaceIfExists="true">
        SELECT emp_id, emp_name, department, salary
        FROM employees
        WHERE active = 1
    </createView>
</changeSet>
```

### Option B — `<sql>` Tag

```xml
<changeSet id="create-view-employee-summary" author="ak" runOnChange="true">
    <sql>
        CREATE OR REPLACE VIEW EMPLOYEE_SUMMARY AS
        SELECT emp_id, emp_name, department, salary
        FROM employees
        WHERE active = 1
    </sql>
</changeSet>
```

### `replaceIfExists` vs `runOnChange`

| Scenario | Use |
|---|---|
| View SQL never changes | Plain `<createView>` — runs once |
| View SQL evolves over time | `runOnChange="true"` + `replaceIfExists="true"` |
| Manual `CREATE OR REPLACE` control | `<sql>` tag with `runOnChange="true"` |

---

## 3. Including SQL Files in a Changeset

### `<sqlFile>` — For Views / DDL

```xml
<changeSet id="create-view-employee-summary" author="ak" runOnChange="true">
    <sqlFile path="sql/views/employee_summary.sql"
             relativeToChangelogFile="true"
             splitStatements="false"
             stripComments="true"/>
</changeSet>
```

### Key `<sqlFile>` Attributes

| Attribute | Purpose |
|---|---|
| `relativeToChangelogFile="true"` | Resolve path relative to the changelog XML (still valid in 5.1) |
| `splitStatements="false"` | Critical for views/procedures — prevents splitting on semicolons |
| `stripComments="true"` | Removes SQL comments before execution |
| `encoding="UTF-8"` | Set if SQL has special characters |

---

## 4. Liquibase 5.1 — `<include>` and `<includeAll>` Rules

> ⚠️ In Liquibase 5.1, `relativeToChangelogFile` was **removed** from `<include>` and `<includeAll>`. It is still valid on `<sqlFile>` inside a changeset.

### Correct Syntax

```xml
<!-- include = specific file, uses 'file' attribute only -->
<include file="GRANT/grants_schema.xml"/>

<!-- includeAll = whole folder, uses 'path' attribute only -->
<includeAll path="TEST/"/>
```

### Attribute Reference

| Tag | Correct Attribute | `relativeToChangelogFile` in 5.1 |
|---|---|---|
| `<include>` | `file` | ❌ Removed — error if used |
| `<includeAll>` | `path` | ❌ Removed — error if used |
| `<sqlFile>` | `path` | ✅ Still supported |

---

## 5. Folder Structure & master.xml Pattern

### Recommended Layout

```
liquibase/
├── master.xml
└── sql/
    ├── db.changelog.schema.xml
    ├── TEST/
    │   ├── 001_tables.sql
    │   └── 002_views.sql
    └── GRANT/
        ├── grants_schema.xml      ← included
        └── grants_other.xml       ← ignored
```

### master.xml

```xml
<databaseChangeLog
    xmlns="http://www.liquibase.org/xml/ns/dbchangelog"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.liquibase.org/xml/ns/dbchangelog
        http://www.liquibase.org/xml/ns/dbchangelog/dbchangelog-latest.xsd">

    <include file="sql/db.changelog.schema.xml"/>

</databaseChangeLog>
```

### db.changelog.schema.xml

```xml
<databaseChangeLog
    xmlns="http://www.liquibase.org/xml/ns/dbchangelog"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.liquibase.org/xml/ns/dbchangelog
        http://www.liquibase.org/xml/ns/dbchangelog/dbchangelog-latest.xsd">

    <includeAll path="TEST/"/>
    <include file="sql/GRANT/grants_schema.xml"/>

</databaseChangeLog>
```

---

## 6. Known 5.1 Behaviors & Gotchas

### Path Resolution Inconsistency

| Tag | Path Resolves From |
|---|---|
| `<includeAll path="TEST/"/>` | Current file (`db.changelog.schema.xml`) |
| `<include file="GRANT/..."/>` | Root changelog (`master.xml`) |

This is why `TEST/` works with a short path but `GRANT/` needs the full path prefixed from the master root (e.g. `sql/GRANT/grants_schema.xml`).

### Mixing `<includeAll>` and `<include>` in the Same File

> ⚠️ In Liquibase 5.1, mixing `<includeAll>` and `<include>` in the same changelog can cause the second tag to be silently ignored. If this happens, move all includes to `master.xml` directly.

**Workaround — Flatten into master.xml:**

```xml
<!-- master.xml — avoids mixed tag issue entirely -->
<databaseChangeLog>
    <includeAll path="sql/TEST/"/>
    <include file="sql/GRANT/grants_schema.xml"/>
</databaseChangeLog>
```

### Case Sensitivity on Linux / OpenShift

> ⚠️ Folder and file names are case-sensitive on Linux. `GRANT/` and `grant/` are different directories. Always match casing exactly.

### Debugging — Verify What Liquibase Scanned

```bash
liquibase \
  --changelog-file=master.xml \
  --url=... \
  status --verbose 2>&1 | tee status.log

grep -i "grant" status.log
```

Also useful to find exact file paths on disk:

```bash
find . -type f -name "*.xml" | grep -i grant
```

---

## 7. Quick Reference

| Goal | Best Approach |
|---|---|
| Did changeset run this deployment? | Parse INFO log with `grep` |
| Full audit trail | Query `DATABASECHANGELOG` table |
| Preview before running | `liquibase status --verbose` |
| Confirm DB state independently | Query DB catalog/views directly |
| Include one specific file from a folder | `<include file="path/file.xml"/>` |
| Include all files in a folder | `<includeAll path="folder/"/>` |
| SQL file for view/procedure | `<sqlFile splitStatements="false"/>` |
| Re-run changeset when SQL changes | `runOnChange="true"` |

---

*Generated from session notes · Liquibase 5.1 · GitHub Actions · OpenShift*
