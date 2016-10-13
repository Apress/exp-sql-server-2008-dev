/**
 * Expert SQL Server 2008 (Apress)
 * Alastair Aitchison
 *
 * Chapter 7 : SQLCLR
 */

-- Create a new database for these examples
CREATE DATABASE ExpertSQLCLR;
GO

USE ExpertSQLCLR;
GO


/**
 * Comparing T-SQL to SQLCLR
 */
-- Null handling in T-SQL
DECLARE @a int = 10;
DECLARE @b int = null;
IF (@a != @b)
  PRINT 'test is true';
ELSE
  PRINT 'test is false';
GO

-- Null handling in SQLCLR
-- Create the assembly
CREATE ASSEMBLY Chapter07_Main  
FROM 'D:\Expert SQL Server 2008 Development\Code\Chapter07 - SQLCLR\Chapter07_Main\Chapter07_Main\bin\Debug\Chapter07_Main.dll'  
WITH PERMISSION_SET = SAFE;
GO
-- Register the function
CREATE PROCEDURE [dbo].[NullComparison]
AS EXTERNAL NAME [Chapter07_Main].[StoredProcedures].[NullComparison]
GO
-- Use the function
EXEC [dbo].[NullComparison];
GO


/*
 * Regular Expression Email Matching
 */
-- Register the wrapper function
CREATE FUNCTION [dbo].[IsValidEmailAddress](
  @emailAddress [nvarchar](4000)
  )
RETURNS [bit]
AS EXTERNAL NAME [Chapter07_Main].[UserDefinedFunctions].[IsValidEmailAddress]
GO

-- Test an email address
SELECT dbo.IsValidEmailAddress('support@apress.com');
GO


/*
 * Exceptions
 */
-- Generate a CAS Exception
CREATE PROCEDURE [dbo].[CAS_Exception]
AS
EXTERNAL NAME [Chapter07_Main].[StoredProcedures].[CAS_Exception];
GO

EXEC dbo.CAS_Exception;
GO

-- Generate a HPA Exception
CREATE PROCEDURE [dbo].[HPA_Exception]
AS
EXTERNAL NAME [Chapter07_Main].[StoredProcedures].[HPA_Exception];
GO

EXEC dbo.HPA_Exception;
GO

/*
 * Working with Host Protection Privileges
 */
 
-- In order to grant UNSAFE access, first set the database to trustworthy
ALTER DATABASE ExpertSQLCLR
SET TRUSTWORTHY ON;

-- Version 1
-- The whole assembly must be imported as UNSAFE 
CREATE ASSEMBLY CurrencyConversion_v1  
FROM 'D:\Expert SQL Server 2008 Development\Code\Chapter07 - SQLCLR\Chapter07_Main\CurrencyConversion_v1\bin\Debug\CurrencyConversion_v1.dll'  
WITH PERMISSION_SET = UNSAFE;
GO

-- Then, create the function
CREATE FUNCTION [dbo].[GetConvertedAmount_v1](
  @InputAmount [numeric](18, 2),
  @InCurrency [nvarchar](4000),
  @OutCurrency [nvarchar](4000)
  )
RETURNS [numeric](18, 2)
AS 
EXTERNAL NAME [CurrencyConversion_v1].[CurrencyConversion_v1].[GetConvertedAmount_v1];
GO

-- Test it
SELECT [dbo].[GetConvertedAmount_v1] (10, 'GBP', 'USD');
GO

-- Version 2
-- Register synchronisation code in its own UNSAFE assembly
CREATE ASSEMBLY [ThreadSafeDictionary]  
FROM 'D:\Expert SQL Server 2008 Development\Code\Chapter07 - SQLCLR\Chapter07_Main\ThreadSafeDictionary\bin\Debug\ThreadSafeDictionary.dll'  
WITH PERMISSION_SET = UNSAFE;
GO

-- The rest of the code can be registered as SAFE
CREATE ASSEMBLY CurrencyConversion_v2  
FROM 'D:\Expert SQL Server 2008 Development\Code\Chapter07 - SQLCLR\Chapter07_Main\CurrencyConversion_v2\bin\Debug\CurrencyConversion_v2.dll'  
WITH PERMISSION_SET = SAFE;
GO

-- Then, create the function
CREATE FUNCTION [dbo].[GetConvertedAmount_v2](
  @InputAmount [numeric](18, 2),
  @InCurrency [nvarchar](4000),
  @OutCurrency [nvarchar](4000)
  )
RETURNS [numeric](18, 2)
AS 
EXTERNAL NAME [CurrencyConversion_v2].[CurrencyConversion_v2].[GetConvertedAmount_v2];
GO

-- Test it
SELECT [dbo].[GetConvertedAmount_v2] (10, 'GBP', 'USD');
GO

/*
 * Working with Code Access Security
 */

-- Put the file I/O operations into an EXTERNAL_ACCESS assembly
CREATE ASSEMBLY [ReadFileLines]  
FROM 'D:\Expert SQL Server 2008 Development\Code\Chapter07 - SQLCLR\Chapter07_Main\ReadFileLines\bin\Debug\ReadFileLines.dll'  
WITH PERMISSION_SET = EXTERNAL_ACCESS;
GO

-- Now modify the previous CAS_Exception to assert the FileIOPermission
CREATE ASSEMBLY AssertPermission  
FROM 'D:\Expert SQL Server 2008 Development\Code\Chapter07 - SQLCLR\Chapter07_Main\AssertPermission\bin\Debug\AssertPermission.dll'  
WITH PERMISSION_SET = SAFE;
GO

-- Register the new function
CREATE PROCEDURE [dbo].[CAS_Exception_v2]
AS
EXTERNAL NAME AssertPermission.[StoredProcedures].[CAS_Exception_v2];
GO

-- Test the function (requires a file c:\b.txt to exist)
EXEC dbo.CAS_Exception_v2;
GO


/*
 * Granting Cross-Assembly Privileges
 */
-- Turn off database trustworthy setting
ALTER DATABASE ExpertSQLCLR
SET TRUSTWORTHY OFF;

-- Can no longer use the threadsafe dictionary
SELECT [dbo].[GetConvertedAmount_v2] (10, 'GBP', 'USD');
GO

-- Create a certificate and a proxy login
USE master
GO

CREATE CERTIFICATE Assembly_Permissions_Certificate
ENCRYPTION BY PASSWORD = 'uSe_a STr()nG PaSSW0rD!'
WITH SUBJECT = 'Certificate used to grant assembly permission'
GO

CREATE LOGIN Assembly_Permissions_Login
FROM CERTIFICATE Assembly_Permissions_Certificate
GO

-- Grant the assembly permission
GRANT UNSAFE ASSEMBLY TO Assembly_Permissions_Login
GO

-- Backup the certificate
BACKUP CERTIFICATE Assembly_Permissions_Certificate
TO FILE = 'C:\assembly_permissions.cer'
WITH PRIVATE KEY
(
    FILE = 'C:\assembly_permissions.pvk',
    ENCRYPTION BY PASSWORD = 'is?tHiS_a_VeRySTronGP4ssWoR|)?',
    DECRYPTION BY PASSWORD = 'uSe_a STr()nG PaSSW0rD!'
)
GO

-- Restore the certificate in the user database, create a proxy user
USE ExpertSQLCLR
GO

CREATE CERTIFICATE Assembly_Permissions_Certificate
FROM FILE = 'C:\assembly_permissions.cer'
WITH PRIVATE KEY
(
    FILE = 'C:\assembly_permissions.pvk',
    DECRYPTION BY PASSWORD = 'is?tHiS_a_VeRySTronGP4ssWoR|)?',
    ENCRYPTION BY PASSWORD = 'uSe_a STr()nG PaSSW0rD!'
);
GO

CREATE USER Assembly_Permissions_User
FOR CERTIFICATE Assembly_Permissions_Certificate;
GO

-- Sign the assembly
ADD SIGNATURE TO ASSEMBLY::ThreadSafeDictionary
BY CERTIFICATE Assembly_Permissions_Certificate
WITH PASSWORD='uSe_a STr()nG PaSSW0rD!';
GO

-- Can now use the threadsafe dictionary again
SELECT [dbo].[GetConvertedAmount_v2] (10, 'GBP', 'USD');
GO

/*****************************************
 * Performance Comparison: SQLCLR –v- TSQL
 *****************************************/

/*
 * Performance Test #1
 * Create a "Simple Sieve" for prime numbers
 */

-- Create the T-SQL Sieve
CREATE PROCEDURE ListPrimesTSQL (
  @Limit int
  )
AS BEGIN
DECLARE
  -- @n is the number we're testing to see if it's a prime
  @n int = @Limit,
  --@m is all the possible numbers that could be a factor of @n
  @m int = @Limit - 1;
  -- Loop descending through the candidate primes
  WHILE (@n > 1)
  BEGIN
    -- Loop descending through the candidate factors
    WHILE (@m > 0)
    BEGIN
      -- We've got all the way to 2 and haven't found any factors    
      IF(@m = 1)
      BEGIN
        PRINT CAST(@n AS varchar(32)) + ' is a prime'
        BREAK;
      END
      -- Is this @m a factor of this prime?
      IF(@n%@m) <> 0
      BEGIN
        -- Not a factor, so move on to the next @m
        SET @m = @m - 1;
        CONTINUE;
      END
      ELSE BREAK;
    END  
    SET @n = @n-1;
    SET @m = @n-1;
  END
END;
GO

-- Test the T-SQL Sieve
EXEC ListPrimesTSQL 2000;
GO

-- Create the SQLCLR Procedure
CREATE PROCEDURE [dbo].[ListPrimes]
	@Limit [int]
AS
EXTERNAL NAME [Chapter07_Main].[CLRTSQLComparison.StoredProcedures].[ListPrimes]
GO

-- Test the SQLCLR Sieve
EXEC ListPrimes 2000;
GO


/*
 * Performance Test #2
 * Calculate Running Aggregates
 */
-- Create a table and load it with 10,000 numbers
SELECT TOP 10000 IDENTITY(int,1,1) AS x 
INTO T 
FROM master..spt_values a, master..spt_values b;
GO

-- Add an index
CREATE NONCLUSTERED INDEX idx ON dbo.T( x );
GO

-- T-SQL Running Sum
SELECT
  T1.x,
  SUM(T2.x) AS running_x
FROM
  T AS T1 INNER JOIN T AS T2
    ON T1.x >= T2.x
GROUP BY
  T1.x;

-- Create the SQLCLR Procedure
CREATE PROCEDURE [dbo].[RunningSum]
AS
EXTERNAL NAME [Chapter07_Main].[CLRTSQLComparison.StoredProcedures].[RunningSum]
GO

-- SQLCLR Running Sum
EXEC dbo.RunningSum


/*
 * Performance Test #3
 * String Manipulation and Searching
 */
-- T-SQL
CREATE PROCEDURE SearchCharTSQL
(
  @needle nchar(1),
  @haystack nvarchar(max)
  )
AS BEGIN
  PRINT CHARINDEX(@needle, @haystack);
END;

-- SQLCLR
CREATE PROCEDURE [dbo].SearchCharCLR (
  @needle nchar(1),
  @haystack nvarchar(max)
)
AS
EXTERNAL NAME [Chapter07_Main].[CLRTSQLComparison.StoredProcedures].SearchCharCLR
GO

-- Test both functions
DECLARE @needle nvarchar(1) = 'x';
DECLARE @haystack nvarchar(max);
SELECT @haystack = REPLICATE(CAST('a' AS varchar(max)), 8000) + 'x';
EXEC dbo.SearchCharTSQL  @needle, @haystack;
EXEC dbo.SearchCharCLR  @needle, @haystack;
GO


/*
 * Using SQLCLR for Binary Serialization / Deserialization
 */

USE AdventureWorks2008;
GO

ALTER DATABASE AdventureWorks2008
SET TRUSTWORTHY ON;

-- XML Serialization
DECLARE @x xml;
SET @x = (
  SELECT *
  FROM HumanResources.Employee
  FOR XML RAW, ROOT('Employees')
);
GO

-- XML Serialization using TYPE directive
DECLARE @x xml;
SET @x = (
  SELECT *
  FROM HumanResources.Employee
  FOR XML RAW, ROOT('Employees'), TYPE
);
GO

-- XML Serilization / Deserialization
DECLARE @x xml;
SET @x = (
  SELECT *
  FROM HumanResources.Employee
  FOR XML RAW, ROOT('Employees'), TYPE
);

SELECT
   col.value('@BusinessEntityID', 'int') AS BusinessEntityID,
   col.value('@NationalIDNumber', 'nvarchar(15)') AS NationalIDNumber,
   col.value('@LoginID', 'nvarchar(256)') AS LoginID,
   CAST(col.value('@OrganizationNode', 'nvarchar(256)') AS hierarchyid)
     AS OrganizationNode,
   col.value('@JobTitle', 'nvarchar(50)') AS JobTitle,
   col.value('@BirthDate', 'datetime') AS BirthDate,
   col.value('@MaritalStatus', 'nchar(1)') AS MaritalStatus,
   col.value('@Gender', 'nchar(1)') AS Gender,
   col.value('@HireDate', 'datetime') AS HireDate,
   col.value('@SalariedFlag', 'bit') AS SalariedFlag,
   col.value('@VacationHours', 'smallint') AS VacationHours,
   col.value('@SickLeaveHours', 'smallint') AS SickLeaveHours,
   col.value('@CurrentFlag', 'bit') AS CurrentFlag,
   col.value('@rowguid', 'uniqueidentifier') AS rowguid,
   col.value('@ModifiedDate', 'datetime') AS ModifiedDate
FROM @x.nodes ('/Employees/row') x (col);
GO


-- Binary Serialization Using DataTable

-- Register the utilities assembly as EXTERNAL_ACCESS (for System.IO access)
CREATE ASSEMBLY SerializationUtilities  
FROM 'D:\Expert SQL Server 2008 Development\Code\Chapter07 - SQLCLR\Chapter07_Main\SerializationUtilities\bin\Debug\SerializationUtilities.dll'  
WITH PERMISSION_SET = EXTERNAL_ACCESS;
GO

-- Create the serialization assembly as SAFE
CREATE ASSEMBLY Serialization  
FROM 'D:\Expert SQL Server 2008 Development\Code\Chapter07 - SQLCLR\Chapter07_Main\Serialization\bin\Debug\Serialization.dll'  
WITH PERMISSION_SET = SAFE;
GO

-- Register the function
CREATE FUNCTION [dbo].[GetDataTable_Binary](
  @query [nvarchar](4000)
  )
RETURNS [varbinary](max)
AS EXTERNAL NAME [Serialization].[UserDefinedFunctions].[GetDataTable_Binary];
GO

-- Use the function to binary serialize the data
DECLARE @sql nvarchar(max);
SET @sql = 'SELECT
    BusinessEntityID,
    NationalIDNumber,
    LoginID,
    OrganizationNode.ToString(),
    OrganizationLevel,
    JobTitle,
    BirthDate,
    MaritalStatus,
    Gender,
    HireDate,
    SalariedFlag,
    VacationHours,
    SickLeaveHours,
    CurrentFlag,
    rowguid,
    ModifiedDate
  FROM HumanResources.Employee';

DECLARE @x varbinary(max);
SET @x = dbo.GetDataTable_Binary(@sql);
GO


-- Binary Serialization Using SqlDataReader
-- Register the function
CREATE FUNCTION [dbo].[GetBinaryFromQueryResult](
  @query [nvarchar](4000)
  )
RETURNS [varbinary](max)
AS EXTERNAL NAME [Serialization].[UserDefinedFunctions].[GetBinaryFromQueryResult];
GO

-- Use the function to binary serialize the data
DECLARE @sql nvarchar(max);
SET @sql = 'SELECT
    BusinessEntityID,
    NationalIDNumber,
    LoginID,
    OrganizationNode.ToString(),
    OrganizationLevel,
    JobTitle,
    BirthDate,
    MaritalStatus,
    Gender,
    HireDate,
    SalariedFlag,
    VacationHours,
    SickLeaveHours,
    CurrentFlag,
    rowguid,
    ModifiedDate
  FROM HumanResources.Employee';

DECLARE @x varbinary(max);
SET @x = dbo.GetBinaryFromQueryResult(@sql);
GO


--Serialize to binary, then deserialize
-- Register the function
CREATE PROCEDURE [dbo].GetTableFromBinary(
  @theTable [varbinary](max)
  )
AS EXTERNAL NAME [Serialization].[StoredProcedures].GetTableFromBinary;
GO
-- First, serialize
DECLARE @sql nvarchar(max);
SET @sql = 'SELECT
    BusinessEntityID,
    NationalIDNumber,
    LoginID,
    OrganizationNode.ToString(),
    OrganizationLevel,
    JobTitle,
    BirthDate,
    MaritalStatus,
    Gender,
    HireDate,
    SalariedFlag,
    VacationHours,
    SickLeaveHours,
    CurrentFlag,
    rowguid,
    ModifiedDate
  FROM HumanResources.Employee';
DECLARE @x varbinary(max);
SET @x = dbo.GetBinaryFromQueryResult(@sql);
-- Then, deserialise again
EXEC GetTableFromBinary @x;
GO
