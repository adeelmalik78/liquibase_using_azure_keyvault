--liquibase formatted sql

--changeset nvoxland:DB-1022
INSERT INTO employee (id, name, address1, address2, city, country)
   VALUES(10, 'Nathan', '5 State St.', '', 'Minneapolis', 'MN');
INSERT INTO employee (id, name, address1, address2, city, country)
   VALUES(20, 'Adeel', '201 Park Ave.', '', 'New York', 'NY');
INSERT INTO employee (id, name, address1, address2, city, country)
   VALUES(30, 'Annette', '85 Lincoln Blvd.', '', 'Austin', 'TX');
INSERT INTO employee (id, name, address1, address2, city, country)
   VALUES(40, 'Lelsey', '8981 Commonwealth Ave.', '', 'Boston', 'MA');
--rollback TRUNCATE TABLE employee;