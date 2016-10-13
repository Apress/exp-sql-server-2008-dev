--Statement-level exception
SELECT POWER(2, 32)
PRINT 'This will print!'
GO

--Batch-level exception
SELECT CONVERT(INT, 'abc')
PRINT 'This will NOT print!'
GO

--Connection-level exception
SELECT CONVERT(INT, 'abc')
GO
PRINT 'This will print!'
GO

--Another connection-level exception
CREATE PROCEDURE ConversionException
AS
BEGIN
    SELECT CONVERT(INT, 'abc')
END
GO

EXEC ConversionException
PRINT 'This will NOT print!'
GO

--Parse exception
SELECTxzy FROM SomeTable
PRINT 'This will NOT print!'
GO

--Parse exception in another level of scope
EXEC('SELECTxzy FROM SomeTable')
PRINT 'This will NOT print!'
GO

--Scope-resolution in a stored procedure?
CREATE PROCEDURE NonExistantTable
AS
BEGIN
    SELECT xyz
    FROM SomeTable
END
GO

--Turning on XACT_ABORT
SET XACT_ABORT ON
GO

--Modifying exception types with XACT_ABORT
SET XACT_ABORT ON
SELECT POWER(2, 32)
PRINT 'This will NOT print!'
GO

--Viewing exception text
SELECT text
FROM sys.messages
WHERE
    message_id = 208
    AND language_id = 1033
GO

--Observing line numbers in exceptions
SELECT 1
GO
SELECT 2
GO
SELECT 1/0
GO

--Raising an exception
RAISERROR('General exception', 16, 1)
GO

--More advanced custom error
DECLARE @ProductId INT
SET @ProductId = 100

/* ... problem occurs ... */

DECLARE @ErrorMessage VARCHAR(200)
SET @ErrorMessage =
    'Problem with ProductId ' + CONVERT(VARCHAR, @ProductId)

RAISERROR(@ErrorMessage, 16, 1)
GO

--And a better way to do it
DECLARE @ProductId INT
SET @ProductId = 100

/* ... problem occurs ... */

RAISERROR('Problem with ProductId %i', 16, 1, @ProductId)
GO

--Multiple designators
DECLARE @ProductId1 INT
SET @ProductId1 = 100

DECLARE @ProductId2 INT
SET @ProductId2 = 200

DECLARE @ProductId3 INT
SET @ProductId3 = 300

/* ... problem occurs ... */

RAISERROR('Problem with ProductIds %i, %i, %i',
    16, 1, @ProductId1, @ProductId2, @ProductId3)
GO

--Adding a custom error
EXEC sp_addmessage
    @msgnum = 50005,
    @severity = 16,
    @msgtext = 'Problem with ProductIds %i, %i, %i'
GO

--Raising the custom error
RAISERROR(50005, 15, 1, 100, 200, 300)
GO

--Changing the error level
RAISERROR(50005, -1, 1, 100, 200, 300)
GO

--Modifying an already-defined error
EXEC sp_addmessage
    @msgnum = 50005,
    @severity = 16,
    @msgtext = 'Problem with ProductId numbers %i, %i, %i',
    @Replace = 'Replace'
GO

--This error will be logged
RAISERROR('This will be logged.', 16, 1) WITH LOG
GO

--Using @@ERROR
SELECT 1/0 AS DivideByZero
SELECT @@ERROR AS ErrorNumber
GO

--@@ERROR reset
SELECT 1/0 AS DivideByZero
IF @@ERROR <> 0
    SELECT @@ERROR AS ErrorNumber
GO

--Basic TRY/CATCH
BEGIN TRY
    SELECT 1/0 AS DivideByZero
END TRY
BEGIN CATCH
    SELECT 'Exception Caught!' AS CatchMessage
END CATCH
GO

--Another TRY/CATCH
BEGIN TRY
    SELECT 1/0 AS DivideByZero
    SELECT 1 AS NoError
END TRY
BEGIN CATCH
    SELECT 'Exception Caught!' AS CatchMessage
END CATCH
GO

--ERROR_* functions
BEGIN TRY
    SELECT CONVERT(int, 'ABC') AS ConvertException
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 123
        SELECT 'Error 123'
    ELSE
        SELECT ERROR_NUMBER() AS ErrorNumber
END CATCH
GO

--Implementing "rethrow"
BEGIN TRY
    SELECT CONVERT(int, 'ABC') AS ConvertException
END TRY
BEGIN CATCH
    DECLARE
        @ERROR_SEVERITY INT,
        @ERROR_STATE INT,
        @ERROR_NUMBER INT,
        @ERROR_LINE INT,
        @ERROR_MESSAGE VARCHAR(245)

    SELECT
        @ERROR_SEVERITY = ERROR_SEVERITY(),
        @ERROR_STATE = ERROR_STATE(),
        @ERROR_NUMBER = ERROR_NUMBER(),
        @ERROR_LINE = ERROR_LINE(),
        @ERROR_MESSAGE = ERROR_MESSAGE()

    RAISERROR('Msg %d, Line %d: %s',
        @ERROR_SEVERITY,
        @ERROR_STATE,
        @ERROR_NUMBER,
        @ERROR_LINE,
        @ERROR_MESSAGE)
END CATCH
GO

--A basic retry loop
DECLARE @Retries INT
SET @Retries = 3

WHILE @Retries > 0
BEGIN
    BEGIN TRY
        /*
        Put deadlock-prone code here
        */

        --If execution gets here, success
        BREAK
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER = 1205
        BEGIN
            SET @Retries = @Retries - 1

            IF @Retries = 0
                RAISERROR('Could not complete transaction!', 16, 1)
        END
        ELSE
            RAISERROR('Non-deadlock condition encountered', 16, 1)
    END CATCH
END
GO

--Effect of exceptions on transactions
BEGIN TRANSACTION
GO
SELECT 1/0 AS DivideByZero
GO
SELECT @@TRANCOUNT AS ActiveTransactionCount
GO

----
--What happens with stored proc transactions and exceptions?
--Create a table for some data
CREATE TABLE SomeData
(
    SomeColumn INT
)
GO

--This procedure will insert one row, then throw a divide by zero exception
CREATE PROCEDURE NoRollback
AS
BEGIN
    INSERT SomeData VALUES (1)

    INSERT SomeData VALUES (1/0)
END
GO

--Execute the procedure
EXEC NoRollback
GO

--Select the rows from the table
SELECT *
FROM SomeData
GO
----

--XACT_ABORT and transactions
SET XACT_ABORT ON
BEGIN TRANSACTION
GO
SELECT 1/0 AS DivideByZero
GO
SELECT @@TRANCOUNT AS ActiveTransactionCount
GO

--XACT_ABORT in a stored procedure
CREATE PROCEDURE NoRollback
AS
BEGIN
    SET XACT_ABORT ON

    BEGIN TRANSACTION
        INSERT SomeData VALUES (1)

        INSERT SomeData VALUES (1/0)
    COMMIT TRANSACTION
END
GO

--"Doomed" transactions
CREATE TABLE SomeData
(
    SomeColumn INT
)
GO

BEGIN TRANSACTION

BEGIN TRY
    --Throw an exception on insert
    INSERT SomeData VALUES (CONVERT(INT, 'abc'))
END TRY
BEGIN CATCH
    --Try to commit...
    COMMIT TRANSACTION
END CATCH
GO
