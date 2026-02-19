--liquibase formatted sql

--changeset amalik:sales
create table sales (
    id int,
    first_name varchar (50),
    last_name varchar (50)
);
-- rollback drop table sales

