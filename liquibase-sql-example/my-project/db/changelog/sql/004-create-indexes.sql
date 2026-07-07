--liquibase formatted sql

--changeset bob:2
CREATE INDEX idx_person_last_name ON person(last_name);

--rollback DROP INDEX idx_person_last_name;

--changeset bob:3
CREATE INDEX idx_address_city ON address(city);

--rollback DROP INDEX idx_address_city;
