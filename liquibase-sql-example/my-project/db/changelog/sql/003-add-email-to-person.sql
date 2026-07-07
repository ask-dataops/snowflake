--liquibase formatted sql

--changeset bob:1 context:all labels:v1.1
--comment: add email column for user contact info
ALTER TABLE person ADD COLUMN email VARCHAR(100);

--rollback ALTER TABLE person DROP COLUMN email;
