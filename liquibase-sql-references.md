# Liquibase SQL Changelog — Reference Links

## Main References

- **SQL Changelog Format (core guide)**
  https://docs.liquibase.com/concepts/changelogs/sql-format.html
  Full formatted SQL syntax, rollback options, and rules. Each SQL file must begin with the `--liquibase formatted sql` header comment; best practice is no space before that header.

- **SQL Change Type (`<sql>` element — for raw SQL inside XML/YAML/JSON changesets)**
  https://docs.liquibase.com/change-types/sql.html
  Lets you specify arbitrary SQL inside a non-SQL changelog. Useful for complex changes not supported by automated Change Types, such as stored procedures.

- **What is a Changelog? (format comparison — SQL vs XML vs YAML vs JSON)**
  https://docs.liquibase.com/concepts/changelogs/home.html
  Explains that formatted SQL changelogs give you exact control over the SQL that runs, while XML/YAML/JSON describe the *kind* of change and let Liquibase generate database-specific SQL for you.

- **Changelog Examples (skeleton syntax for `--changeset`, preconditions, rollback)**
  https://docs.liquibase.com/pro/user-guide-4-33/changelog-examples

## Version-Specific Pages (same content, different product tiers/versions)

- OSS 4.33: https://docs.liquibase.com/oss/user-guide-4-33/sql-changelog-example
- Community 5.0: https://docs.liquibase.com/community/user-guide-5-0-3/sql-changelog-example
- Pro 4.33: https://docs.liquibase.com/pro/user-guide-4-33/sql-changelog-example
- Secure 5.0: https://docs.liquibase.com/concepts/changelogs/sql-format.html
- Secure 5.1 (What is a Changelog?): https://docs.liquibase.com/concepts/changelogs/home.html

## Related Command Reference

- **generate-changelog** (auto-generate a `.sql` changelog from an existing DB)
  https://docs.liquibase.com/reference-guide/generate-changelog
  Filename extension determines output format — use `.sql` to get a formatted SQL changelog.

## Key Notes From the Docs

- `include` / `includeAll` tags **inside a formatted SQL root changelog** (to reference other SQL files) is a **Liquibase Pro-only** feature (since 4.28.0). Not available in Open Source.
- You **can** reference formatted SQL changelogs **from an XML, YAML, or JSON root changelog** in **all versions** of both Pro and Open Source — this is the standard pattern for Open Source users (thin XML/YAML root + `includeAll` pointing at a folder of `.sql` files).
- Standard SQL comments (`--` or `/* */`) are documentation only and are **not** written to the `DATABASECHANGELOG` table. Only the `--comment` attribute writes to `DATABASECHANGELOG.COMMENTS`.
- Statements are split on `;` or `GO` at the **end of a line** by default — don't put a trailing `;` or `GO` inside a comment or it will break parsing.
- Multi-line SQL statements are supported; a statement only ends on `;` or `GO` on its own line — a plain newline is not enough to split statements.
