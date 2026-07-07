--liquibase formatted sql

--changeset alice:1
CREATE TABLE person (
    id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50)
);

--rollback DROP TABLE person;
