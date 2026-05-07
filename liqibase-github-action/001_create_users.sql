-- liquibase formatted sql

-- changeset dev:001 dbms:snowflake contextFilter:dev,staging,performance,preprod,prod
-- comment: Create USERS table
CREATE TABLE IF NOT EXISTS USERS (
    USER_ID     NUMBER AUTOINCREMENT PRIMARY KEY,
    EMAIL       VARCHAR(255)  NOT NULL,
    FIRST_NAME  VARCHAR(100),
    LAST_NAME   VARCHAR(100),
    STATUS      VARCHAR(50)   DEFAULT 'ACTIVE',
    CREATED_AT  TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT  TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- rollback DROP TABLE IF EXISTS USERS;
