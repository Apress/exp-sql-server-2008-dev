USE AdventureWorks
GO

--Use STATISTICS TIME 
SET STATISTICS TIME ON
GO

SELECT *
FROM HumanResources.Employee
WHERE EmployeeId IN (1, 2)
GO



--Check the plan cache
SELECT
    ecp.objtype,
    p.Text
FROM sys.dm_exec_cached_plans AS ecp
CROSS APPLY
(
    SELECT *
    FROM sys.dm_exec_sql_text(ecp.plan_handle)
) p
WHERE
    p.Text LIKE '%HumanResources%'
    AND p.Text NOT LIKE '%sys.dm_exec_cached_plans%'
GO



--An auto-parameterizable query
SELECT *
FROM HumanResources.Employee
WHERE EmployeeId = 1
GO



--Use for SQLQueryStress main query window
SELECT *
FROM HumanResources.Employee
WHERE EmployeeId IN (@EmpId1, @EmpId2)
GO

--Use for SQLQueryStress parameter substitution
SELECT 1 AS EmpId1, 2 AS EmpId2
GO



--Getting numbers from spt_values
SELECT Number, Number + 1 AS NumberPlus1
FROM master..spt_values
WHERE Type = 'P'
GO



--Basic dynamic SQL
DECLARE @sql VARCHAR(MAX)

SET @sql =
'SELECT *
FROM HumanResources.Employee
WHERE EmployeeId IN (' +
    CONVERT(VARCHAR, @EmpId1) + ', ' +
    CONVERT(VARCHAR, @EmpId2) + ')'

EXEC(@sql)
GO



--A query with potential for optional parameters
SELECT
    ContactId,
    LoginId,
    Title
FROM HumanResources.Employee
WHERE
    EmployeeId = 1
    AND NationalIdNumber = N'14417807'
GO



--Static optional params
CREATE PROCEDURE GetEmployeeData
    @EmployeeId INT = NULL,
    @NationalIdNumber NVARCHAR(15) = NULL
AS
BEGIN
    SET NOCOUNT ON

    SELECT
        ContactId,
        LoginId,
        Title
    FROM HumanResources.Employee
    WHERE
        EmployeeId = @EmployeeId
        AND NationalIdNumber = @NationalIdNumber
END
GO



--Using IF/ELSE to construct optional params
CREATE PROCEDURE GetEmployeeData
    @EmployeeId INT = NULL,
    @NationalIdNumber NVARCHAR(15) = NULL
AS
BEGIN
    SET NOCOUNT ON

    IF (@EmployeeId IS NOT NULL
        AND @NationalIdNumber IS NOT NULL)
    BEGIN
        SELECT
            ContactId,
            LoginId,
            Title
        FROM HumanResources.Employee
        WHERE
            EmployeeId = @EmployeeId
            AND NationalIdNumber = @NationalIdNumber
    END
    ELSE IF (@EmployeeId IS NOT NULL)
    BEGIN
        SELECT
            ContactId,
            LoginId,
            Title
        FROM HumanResources.Employee
        WHERE
            EmployeeId = @EmployeeId
    END
    ELSE IF (@NationalIdNumber IS NOT NULL)
    BEGIN
        SELECT
            ContactId,
            LoginId,
            Title
        FROM HumanResources.Employee
        WHERE
            NationalIdNumber = @NationalIdNumber
    END
    ELSE
    BEGIN
        SELECT
            ContactId,
            LoginId,
            Title
        FROM HumanResources.Employee
    END
END
GO



--Using COALESCE to control optional params
CREATE PROCEDURE GetEmployeeData
    @EmployeeId INT = NULL,
    @NationalIdNumber NVARCHAR(15) = NULL
AS
BEGIN
    SET NOCOUNT ON

    SELECT
        ContactId,
        LoginId,
        Title
    FROM HumanResources.Employee
    WHERE
        EmployeeId = COALESCE(@EmployeeId, EmployeeId)
        AND NationalIdNumber = COALESCE(@NationalIdNumber, NationalIdNumber)
END
GO



--Using OR to control optional params
CREATE PROCEDURE GetEmployeeData
    @EmployeeId INT = NULL,
    @NationalIdNumber NVARCHAR(15) = NULL
AS
BEGIN
    SET NOCOUNT ON

    SELECT
        ContactId,
        LoginId,
        Title
    FROM HumanResources.Employee
    WHERE
        (@EmployeeId IS NULL
            OR EmployeeId = @EmployeeId)
        AND (@NationalIdNumber IS NULL
            OR @NationalIdNumber = NationalIdNumber)
END
GO



--A more complex version using COALESCE
CREATE PROCEDURE GetEmployeeData
    @EmployeeId INT = NULL,
    @NationalIdNumber NVARCHAR(15) = NULL
AS
BEGIN
    SET NOCOUNT ON

    SELECT
        ContactId,
        LoginId,
        Title
    FROM HumanResources.Employee
    WHERE
        EmployeeId BETWEEN
            COALESCE(@EmployeeId, -2147483648)
                AND COALESCE(@EmployeeId, 2147483647)
        AND NationalIdNumber LIKE COALESCE(@NationalIdNumber, N'%')
END
GO



--Dynamic, v.1
EXEC('SELECT
    ContactId,
    LoginId,
    Title
FROM HumanResources.Employee')
GO



--This does not work
DECLARE @EmployeeId INT
SET @EmployeeId = 1

EXEC('SELECT
    ContactId,
    LoginId,
    Title
FROM HumanResources.Employee
WHERE EmployeeId = ' + CONVERT(VARCHAR, @EmployeeId))
GO



--Concatenate first
DECLARE @EmployeeId INT
SET @EmployeeId = 1

DECLARE @sql NVARCHAR(MAX)

SET @sql = 'SELECT
    ContactId,
    LoginId,
    Title
FROM HumanResources.Employee
WHERE EmployeeId = ' + CONVERT(VARCHAR, @EmployeeId)

EXECUTE(@sql)
GO



--Dynamic optional params, v.1
DECLARE @EmployeeId INT
SET @EmployeeId = 1

DECLARE @NationalIdNumber NVARCHAR(15)
SET @NationalIdNumber = N'14417807'

DECLARE @sql NVARCHAR(MAX)

SET @sql = 'SELECT
    ContactId,
    LoginId,
    Title
FROM HumanResources.Employee '

IF (@EmployeeId IS NOT NULL
    AND @NationalIdNumber IS NOT NULL)
BEGIN
    SET @sql = @sql +
        'WHERE EmployeeId = ' + CONVERT(NVARCHAR, @EmployeeId) +
            ' AND NationalIdNumber = N''' + @NationalIdNumber + ''''
END
ELSE IF (@EmployeeId IS NOT NULL)
BEGIN
    SET @sql = @sql +
        'WHERE EmployeeId = ' +
            CONVERT(NVARCHAR, @EmployeeId)
END
ELSE IF (@NationalIdNumber IS NOT NULL)
BEGIN
    SET @sql = @sql +
        'WHERE NationalIdNumber = N''' + @NationalIdNumber + ''''
END

EXEC(@sql)
GO



--Dynamic optional params with CASE
DECLARE @EmployeeId INT
SET @EmployeeId = 1

DECLARE @NationalIdNumber NVARCHAR(15)
SET @NationalIdNumber = N'14417807'

DECLARE @sql NVARCHAR(MAX)

SET @sql = 'SELECT
    ContactId,
    LoginId,
    Title
FROM HumanResources.Employee
WHERE 1=1' +
CASE
    WHEN @EmployeeId IS NULL THEN ''
    ELSE 'AND EmployeeId = ' + CONVERT(NVARCHAR, @EmployeeId)
END +
CASE
    WHEN @NationalIdNumber IS NULL THEN ''
    ELSE 'AND NationalIdNumber = N''' + @NationalIdNumber + ''''
END

/*Uncomment the following line to see a problem...*/
--PRINT @sql
EXEC(@sql)
GO



--A better way to format the SQL
DECLARE @EmployeeId INT
SET @EmployeeId = 1

DECLARE @NationalIdNumber NVARCHAR(15)
SET @NationalIdNumber = N'14417807'

DECLARE @sql NVARCHAR(MAX)

SET @sql = '' +
    'SELECT ' +
        'ContactId, ' +
        'LoginId, ' +
        'Title ' +
    'FROM HumanResources.Employee ' +
    'WHERE 1=1 ' +
    CASE
        WHEN @EmployeeId IS NULL THEN ''
        ELSE 'AND EmployeeId = ' + CONVERT(NVARCHAR, @EmployeeId) + ' '
    END +
    CASE
        WHEN @NationalIdNumber IS NULL THEN ''
        ELSE 'AND NationalIdNumber = N''' + @NationalIdNumber + ''' '
    END

EXEC(@sql)
GO



--A more fully-baked dynamic stored procedure (but not complete yet!)
CREATE PROCEDURE GetEmployeeData
    @EmployeeId INT = NULL,
    @NationalIdNumber NVARCHAR(15) = NULL
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @sql NVARCHAR(MAX)

    SET @sql = '' +
        'SELECT ' +
            'ContactId, ' +
            'LoginId, ' +
            'Title ' +
        'FROM HumanResources.Employee ' +
        'WHERE 1=1 ' +
        CASE
            WHEN @EmployeeId IS NULL THEN ''
            ELSE 'AND EmployeeId = ' + CONVERT(NVARCHAR, @EmployeeId) + ' '
        END +
        CASE
            WHEN @NationalIdNumber IS NULL THEN ''
            ELSE 'AND NationalIdNumber = N''' + @NationalIdNumber + ''' '
        END

    EXEC(@sql)
END
GO



--Testing the procedure
DBCC FREEPROCCACHE
GO

EXEC GetEmployeeData
    @EmployeeId = 1
GO

EXEC GetEmployeeData
    @EmployeeId = 2
GO

EXEC GetEmployeeData
    @EmployeeId = 3
GO




--A stored proc that can be injected
CREATE PROCEDURE FindAddressByString
    @String NVARCHAR(60)
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @sql NVARCHAR(MAX)

    SET @sql = '' +
        'SELECT AddressId ' +
        'FROM Person.Address ' +
        'WHERE AddressLine1 LIKE ''%' + @String + '%'''

    EXEC(@sql)
END
GO



--Calling the proc
EXEC FindAddressByString
    @String = 'Stone'
GO



--A simple injection
EXEC FindAddressByString
    @String = ''' ORDER BY AddressId --'
GO



--A more interesting injection
EXEC FindAddressByString
    @String = '''; SELECT * FROM HumanResources.EmployeePayHistory --'
GO



--Using parameterized sp_executesql to avoid injection
DECLARE @String NVARCHAR(60)
SET @String = 'Stone'

DECLARE @sql NVARCHAR(MAX)

SET @sql = '' +
    'SELECT AddressId ' +
    'FROM Person.Address ' +
    'WHERE AddressLine1 LIKE ''%'' + @String + ''%'''

EXEC sp_executesql
    @sql,
    N'@String NVARCHAR(60)',
    @String
GO



--The completed version of GetEmployeeData
CREATE PROCEDURE GetEmployeeData
    @EmployeeId INT = NULL,
    @NationalIdNumber NVARCHAR(15) = NULL
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @sql NVARCHAR(MAX)

    SET @sql = '' +
        'SELECT ' +
            'ContactId, ' +
            'LoginId, ' +
            'Title ' +
        'FROM HumanResources.Employee ' +
        'WHERE 1=1 ' +
        CASE
            WHEN @EmployeeId IS NULL THEN ''
            ELSE 'AND EmployeeId = @EmployeeId '
        END +
        CASE
            WHEN @NationalIdNumber IS NULL THEN ''
            ELSE 'AND NationalIdNumber = @NationalIdNumber '
        END

    EXEC sp_executesql
        @sql,
        N'@EmployeeId INT, @NationalIdNumber NVARCHAR(60)',
        @EmployeeId,
        @NationalIdNumber
END
GO



--To be used for SQLQueryStress testing
SELECT EmployeeId, NationalIdNumber
FROM HumanResources.Employee

UNION ALL

SELECT NULL, NationalIdNumber
FROM HumanResources.Employee

UNION ALL

SELECT NULL, NationalIdNumber
FROM HumanResources.Employee

UNION ALL

SELECT NULL, NULL
GO



--Example of sp_executesql output param
DECLARE @SomeVariable INT

EXEC sp_executesql
    N'SET @SomeVariable = 123',
    N'@SomeVariable INT OUTPUT',
    @SomeVariable OUTPUT
GO



--This does not work
CREATE PROC SelectDataFromTable
    @TableName VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @sql VARCHAR(MAX)

    SET @sql = '' +
        'SELECT ' +
            'ColumnA, ' +
            'ColumnB, ' +
            'ColumnC ' +
        'FROM ' + @TableName

    EXEC(@sql)
END
GO



--Abstraction of table names
CREATE PROC SelectDataFromTable
    @UseTableA BIT = 0,
    @UseTableB BIT = 0,
    @UseTableC BIT = 0
AS
BEGIN
    SET NOCOUNT ON

    IF (
        CONVERT(TINYINT, COALESCE(@UseTableA, 0)) +
        CONVERT(TINYINT, COALESCE(@UseTableB, 0)) +
        CONVERT(TINYINT, COALESCE(@UseTableC, 0))
        ) <> 1
    BEGIN
        RAISERROR('Must specify exactly one table', 16, 1)
        RETURN
    END

    DECLARE @sql VARCHAR(MAX)

    SET @sql = '' +
        'SELECT ' +
            'ColumnA, ' +
            'ColumnB, ' +
            'ColumnC ' +
        'FROM ' +
            CASE
                 WHEN @UseTableA = 1 THEN 'TableA'
                 WHEN @UseTableB = 1 THEN 'TableB'
                 WHEN @UseTableC = 1 THEN 'TableC'
            END

    EXEC(@sql)
END
GO



--Using QUOTENAME
CREATE PROC SelectDataFromTable
    @TableName VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @sql VARCHAR(MAX)

    SET @sql = '' +
        'SELECT ' +
            'ColumnA, ' +
            'ColumnB, ' +
            'ColumnC ' +
        'FROM ' + QUOTENAME(@TableName)

    EXEC(@sql)
END
GO



