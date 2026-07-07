--liquibase formatted sql

--changeset alice:1
CREATE TABLE address (
    id INT PRIMARY KEY,
    person_id INT,
    street VARCHAR(100),
    city VARCHAR(50),
    CONSTRAINT fk_person FOREIGN KEY (person_id) REFERENCES person(id)
);

--rollback DROP TABLE address;
