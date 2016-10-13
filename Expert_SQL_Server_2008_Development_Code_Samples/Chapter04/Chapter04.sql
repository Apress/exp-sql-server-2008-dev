--Creating a certificate in the master database
USE master
GO

CREATE CERTIFICATE Dinesh_Certificate
ENCRYPTION BY PASSWORD = 'stR0n_G paSSWoRdS, pLE@sE!'
WITH SUBJECT = 'Certificate for Dinesh'
GO


--Create a proxy login from the certificate
CREATE LOGIN Dinesh
FROM CERTIFICATE Dinesh_Certificate
GO


--Create a proxy user
CREATE USER Bob
WITHOUT LOGIN
GO


--Create a schema
CREATE SCHEMA Sales
GO


--Create a table in the schema
CREATE TABLE Sales.SalesData
(
    SaleNumber INT,
    SaleDate DATETIME
)
GO


--Reference the schema in a query
SELECT *
FROM Sales.SalesData
GO


--Create a proxy user and grant access to the schema
CREATE USER Alejandro
WITHOUT LOGIN
GO

GRANT SELECT ON SCHEMA::Sales
TO Alejandro
GO



--Create a user and a table, and make the user the owner of the table
--Create a user
CREATE USER Javier
WITHOUT LOGIN
GO

--Create a table
CREATE TABLE JaviersData
(
    SomeColumn INT
)
GO

--Set Javier as the owner of the table
ALTER AUTHORIZATION ON JaviersData
TO Javier
GO



--Move tables between schemas
--Create a new schema
CREATE SCHEMA Purchases
GO

--Move the SalesData table into the new schema
ALTER SCHEMA Purchases
TRANSFER Sales.SalesData
GO

--Reference the table by its new schema name
SELECT *
FROM Purchases.SalesData
GO



--Create a user and a table, and make the user own the table
CREATE USER Tom
WITHOUT LOGIN
GO
CREATE TABLE TomsData
(
    AColumn INT
)
GO

ALTER AUTHORIZATION ON TomsData TO Tom
GO


--Impersonate the user
EXECUTE AS USER='Tom'
GO

SELECT USER_NAME()
GO


--Do something on the table the user owns
--This statement will succeed
ALTER TABLE TomsData
ADD AnotherColumn DATETIME
GO

--This statement will fail
CREATE TABLE MoreData
(
    YetAnotherColumn INT
)
GO


--Create a new user, and give it access to imporsonate another user
CREATE USER Paul
WITHOUT LOGIN
GO

GRANT IMPERSONATE ON USER::Tom TO PAUL
GO


--See the effects of multiple levels of impersonation
EXECUTE AS USER='Paul'
GO

--Fails
SELECT *
FROM TomsData
GO

EXECUTE AS USER='Tom'
GO

--Succeeds
SELECT *
FROM TomsData
GO

REVERT
GO

--Returns 'Paul' -- REVERT must be called again to fully revert
SELECT USER_NAME()
GO


--Create a database for ownership chaining
CREATE DATABASE OwnershipChain
GO

USE OwnershipChain
GO

CREATE USER Louis
WITHOUT LOGIN
GO

CREATE USER Hugo
WITHOUT LOGIN
GO


--Create a table for sensitive data
CREATE TABLE SensitiveData
(
    IntegerData INT
)
GO

ALTER AUTHORIZATION ON SensitiveData TO Louis
GO


--Create a proc and make one user its owner
CREATE PROCEDURE SelectSensitiveData
AS
BEGIN
    SET NOCOUNT ON

    SELECT *
    FROM dbo.SensitiveData
END
GO

ALTER AUTHORIZATION ON SelectSensitiveData TO Louis
GO


--Let the other user execute the proc
GRANT EXECUTE ON SelectSensitiveData TO Hugo
GO


--Change impersonation at the stored procedure level
CREATE PROCEDURE SelectSensitiveData
WITH EXECUTE AS 'Louis'
AS
BEGIN
    SET NOCOUNT ON

    SELECT *
    FROM dbo.SensitiveData
END
GO


--Create two users, with two different tables
CREATE USER Kevin
WITHOUT LOGIN
GO

CREATE TABLE KevinsData
(
    SomeData INT
)
GO

ALTER AUTHORIZATION ON KevinsData TO Kevin
GO

CREATE USER Hilary
WITHOUT LOGIN
GO

CREATE TABLE HilarysData
(
    SomeOtherData INT
)
GO

ALTER AUTHORIZATION ON HilarysData TO Hilary
GO



--How to let both users select from both tables at the same time?
CREATE PROCEDURE SelectKevinAndHilarysData
WITH EXECUTE AS 'Kevin'
AS
BEGIN
    SET NOCOUNT ON

    SELECT *
    FROM KevinsData

    UNION ALL

    SELECT *
    FROM HilarysData
END
GO

ALTER AUTHORIZATION ON SelectKevinAndHilarysData TO Hilary
GO


--Create a certificate and a user from the certificate
CREATE CERTIFICATE Greg_Certificate
WITH SUBJECT='Certificate for Greg'
GO

CREATE USER Greg
FOR CERTIFICATE Greg_Certificate
GO


--Create a table and grant access to the user
CREATE TABLE GregsData
(
    DataColumn INT
)
GO

GRANT ALL ON GregsData
TO Greg
GO


--Create a proc to select from the table, and allow another user to execute it
CREATE PROCEDURE SelectGregsData
AS
BEGIN
    SET NOCOUNT ON

    SELECT *
    FROM GregsData
END
GO

CREATE USER Steve
WITHOUT LOGIN
GO

ALTER AUTHORIZATION ON SelectGregsData TO Steve
GO



--Can this user get the data?
CREATE USER Linchi
WITHOUT LOGIN
GO

GRANT EXECUTE ON SelectGregsData TO Linchi
GO

EXECUTE AS USER='Linchi'
GO

--This will fail -- SELECT permission denied
EXEC SelectGregsData
GO


--Fix: Sign the proc
ADD SIGNATURE TO SelectGregsData
BY CERTIFICATE Greg_Certificate
GO


--Get information on signed procs from the catalog views
SELECT
    OBJECT_NAME(cp.major_id) AS signed_module,
    c.name AS certificate_name,
    dp.name AS user_name
FROM sys.crypt_properties AS cp
INNER JOIN sys.certificates AS c ON c.thumbprint = cp.thumbprint
INNER JOIN sys.database_principals dp ON SUBSTRING(dp.sid, 13, 32) = c.thumbprint
GO


--Create a certificate/login in the master database
USE master
GO

CREATE CERTIFICATE alter_db_certificate
   ENCRYPTION BY PASSWORD = 'stR()Ng_PaSSWoRDs are?BeST!'
   WITH SUBJECT = 'ALTER DATABASE permission'
GO

CREATE LOGIN alter_db_login FROM CERTIFICATE alter_db_certificate
GO


--Grant permission to the login
GRANT ALTER ANY DATABASE TO alter_db_login
GO


--Back up the certificate
BACKUP CERTIFICATE alter_db_certificate
TO FILE = 'C:\alter_db.cer'
WITH PRIVATE KEY
(
    FILE = 'C:\alter_db.pvk',
    ENCRYPTION BY PASSWORD = 'an0tHeR$tRoNGpaSSWoRd?',
    DECRYPTION BY PASSWORD = 'stR()Ng_PaSSWoRDs are?BeST!'
)
GO


--Create a database, restore the certificate there
CREATE DATABASE alter_db_example
GO

USE alter_db_example
GO

CREATE CERTIFICATE alter_db_certificate
FROM FILE = 'C:\alter_db.cer'
WITH PRIVATE KEY
(
    FILE = 'C:\alter_db.pvk',
    DECRYPTION BY PASSWORD = 'an0tHeR$tRoNGpaSSWoRd?',
    ENCRYPTION BY PASSWORD = 'stR()Ng_PaSSWoRDs are?BeST!'
)
GO



--Create a proc, sign it with the certificate
CREATE PROCEDURE SetMultiUser
AS
BEGIN
    ALTER DATABASE alter_db_example
    SET MULTI_USER
END
GO

CREATE USER alter_db_user
FOR CERTIFICATE alter_db_certificate
GO

ADD SIGNATURE TO SetMultiUser
BY CERTIFICATE alter_db_certificate
WITH PASSWORD = 'stR()Ng_PaSSWoRDs are?BeST!'
GO



--Try running the proc with a new user...
CREATE LOGIN test_alter WITH PASSWORD = 'iWanT2ALTER!!'
GO

CREATE USER test_alter FOR LOGIN test_alter
GO

GRANT EXECUTE ON SetMultiUser TO test_alter
GO

EXECUTE AS LOGIN='test_alter'
GO

EXEC SetMultiUser
GO
