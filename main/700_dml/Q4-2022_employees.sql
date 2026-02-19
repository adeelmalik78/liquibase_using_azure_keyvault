--liquibase formatted sql
--changeset amalik:employees
INSERT INTO employee (id, name, address1, address2, city, country)
   VALUES(1, 'Nathan', '5 State St.', '', 'Minneapolis', 'MN');
INSERT INTO employee (id, name, address1, address2, city, country)
   VALUES(2, 'Adeel', '201 Park Ave.', '', 'New York', 'NY');
INSERT INTO employee (id, name, address1, address2, city, country)
   VALUES(3, 'Annette', '85 Lincoln Blvd.', '', 'Austin', 'TX');
INSERT INTO employee (id, name, address1, address2, city, country)
   VALUES(4, 'Lelsey', '8981 Commonwealth Ave.', '', 'Boston', 'MA');
--rollback truncate table employees