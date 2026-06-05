# Promote to Production

Use this promotion checklist after dev validation succeeds.

## Preconditions
- dbt models passed tests in dev.
- Harness pipeline succeeded in non-prod.
- Snowflake credentials and private key secret are available in Harness.
- Delegate is healthy and reachable.

## Promotion Steps
1. Confirm the approved Git commit or release tag.
2. Switch the dbt target from `dev` to `prod`.
3. Verify the Harness pipeline is using the prod environment and prod delegate selector.
4. Run the CD pipeline in Harness.
5. Review logs for dbt run, test, and deploy steps.
6. Confirm the prod Snowflake schema has the expected objects.

## Example release command
```bash
dbt build --target prod
```

## Rollback
- Re-run the previous successful release.
- Revert the Git commit if the issue is code-related.
- Drop or replace only the affected prod objects if the issue is environment-related.
