/**
 * Expert SQL Server 2008 (Apress)
 * Alastair Aitchison
 *
 * Chapter 9 : Concurrency
 */

-- Create a table to demonstrate blocking
USE TempDB;
GO
CREATE TABLE Blocker
(
  Blocker_Id int NOT NULL PRIMARY KEY
);
GO
INSERT INTO Blocker VALUES (1), (2), (3);
GO

-- Begin a transaction in the BLOCKING window
BEGIN TRANSACTION;
UPDATE Blocker
SET Blocker_Id = Blocker_Id + 1;

-- Try to select from the table in a BLOCKED window
SELECT *
FROM Blocker;

-- Rollback the transaction in the BLOCKING window
ROLLBACK;

/*
 * READ COMMITTED
 * Locks held only for duration of statement
 */

-- BLOCKING window
BEGIN TRANSACTION;
SELECT *
FROM Blocker;
GO

-- BLOCKED window will succeed
BEGIN TRANSACTION;
UPDATE Blocker
SET Blocker_Id = Blocker_Id + 1;
GO


/*
 * REPEATABLE READ
 */
 
 -- BLOCKING window
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN TRANSACTION;
SELECT *
FROM Blocker;
GO

-- UPDATES in the BLOCKED window will fail
BEGIN TRANSACTION;
UPDATE Blocker
SET Blocker_Id = Blocker_Id + 1;
GO

-- INSERTS in the BLOCKED window will succeed
BEGIN TRANSACTION;
INSERT INTO Blocker VALUES (4);
COMMIT;
GO


/*
 * SERIALIZABLE
 */
 
-- BLOCKING window
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN TRANSACTION;
SELECT *
FROM Blocker;
GO

-- BLOCKED window will fail
BEGIN TRANSACTION;
INSERT INTO Blocker VALUES (4);
COMMIT;
GO


/*
 * READ UNCOMMITTED
 */

-- BLOCKING window
BEGIN TRANSACTION;
UPDATE Blocker
SET Blocker_Id = 10
WHERE Blocker_Id = 1;
GO

-- This will not be blocked in the BLOCKED window
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT *
FROM Blocker;
GO


/*
 * Pessimistic Concurrency Control
 */

/*
 * #1: The Basic Approach
 */
CREATE TABLE CustomerLocks
(
  CustomerId int NOT NULL PRIMARY KEY
    REFERENCES Customers (CustomerId),
  IsLocked bit NOT NULL DEFAULT (0)
);
GO

-- Requesting a Lock
DECLARE @LockAcquired bit = 0;
IF
  (
    SELECT IsLocked
    FROM CustomerLocks
    WHERE CustomerId = @CustomerId
  ) = 0
BEGIN
  UPDATE CustomerLocks
  SET IsLocked = 1
  WHERE CustomerId = @CustomerId;

  SET @LockAcquired = 1;
END

-- A Better Approach at requesting a lock
DECLARE @LockAcquired bit;
UPDATE CustomerLocks
SET IsLocked = 1
WHERE
  CustomerId = @CustomerId
  AND IsLocked = 0;

SET @LockAcquired = @@ROWCOUNT;

/*
 * #2: A Better Approach
 */
CREATE TABLE CustomerLocks 
(
  CustomerId int NOT NULL PRIMARY KEY
    REFERENCES Customers (CustomerId)
);
GO

-- Requesting a lock
DECLARE @LockAcquired bit;
BEGIN TRY
  INSERT INTO CustomerLocks
  (
    CustomerId
  )
  VALUES
  (
    @CustomerId
  )
  SET @LockAcquired = 1;
END TRY
BEGIN CATCH
  SET @LockAcquired = 0;
END CATCH
GO

-- Releasing a lock
DELETE FROM CustomerLocks
WHERE CustomerId = @CustomerId;
GO

/*
 * #3: Using Lock Tokens
 */
CREATE TABLE CustomerLocks
(
  CustomerId int NOT NULL PRIMARY KEY
    REFERENCES Customers (CustomerId),
  LockToken uniqueidentifier NOT NULL UNIQUE
);
GO

-- Requesting a Lock
DECLARE @LockToken uniqueidentifier

BEGIN TRY
  SET @LockToken = NEWID();
  INSERT INTO CustomerLocks
  (
    CustomerId,
    LockToken
  )
  VALUES
  (
    @CustomerId,
    @LockToken
  )
END TRY
BEGIN CATCH
  SET @LockToken = NULL;
END CATCH
GO

-- Releasing the lock
DELETE FROM CustomerLocks
WHERE LockToken = @LockToken;
IF @@ROWCOUNT = 0
  RAISERROR('Lock token not found!', 16, 1);
GO

/*
 * #4: Adding an audit column to the table
 */
CREATE TABLE CustomerLocks
(
  CustomerId int NOT NULL PRIMARY KEY
    REFERENCES Customers (CustomerId),
  LockToken uniqueidentifier NOT NULL UNIQUE,
  LockGrantedDate datetime NOT NULL DEFAULT (GETDATE())
);
GO

-- Expiring old locks
DELETE FROM CustomerLocks
WHERE LockGrantedDate < DATEADD(hour, -5, GETDATE());
GO

-- Renewing open locks
UPDATE CustomerLocks
SET LockGrantedDate = GETDATE()
WHERE LockToken = @LockToken;

-- Enforcing pessimistic locks
ALTER TABLE CustomerLocks
ADD CONSTRAINT UN_Customer_Token
    UNIQUE (CustomerId, LockToken);
GO

ALTER TABLE Customers
ADD
  LockToken uniqueidentifier NULL,
  CONSTRAINT FK_CustomerLocks
    FOREIGN KEY (CustomerId, LockToken)
    REFERENCES CustomerLocks (CustomerId, LockToken);
GO

CREATE TRIGGER tg_EnforceCustomerLocks
ON Customers
FOR UPDATE
AS
BEGIN
  SET NOCOUNT ON;

  IF EXISTS
  (
    SELECT *
    FROM inserted
    WHERE LockToken IS NULL; 
  )
  BEGIN
    RAISERROR('LockToken is a required column', 16, 1);
    ROLLBACK;
  END

  UPDATE Customers
  SET LockToken = NULL
  WHERE
    LockToken IN
    (
      SELECT LockToken
      FROM inserted
    );
END
GO

-- Requesting an Application Lock
BEGIN TRAN;
DECLARE @ReturnValue int;
EXEC @ReturnValue = sp_getapplock
    @Resource = 'customers',
    @LockMode = 'exclusive',
    @LockTimeout = 2000;
IF @ReturnValue IN (0, 1)
    PRINT 'Lock granted';
ELSE
    PRINT 'Lock not granted';

-- Releasing a lock
EXEC sp_releaseapplock
    @Resource = 'customers';

/*
 * Creating an exclusive lock queue using Service Broker
 */
 
-- Create the necessary infrastructure
CREATE TABLE AppLocks
(
  AppLockName nvarchar(255) NOT NULL,
  AppLockKey uniqueidentifier NULL,
  InitiatorDialogHandle uniqueidentifier NOT NULL,
  TargetDialogHandle uniqueidentifier NOT NULL,
  LastGrantedDate datetime NOT NULL DEFAULT(GETDATE()),
  PRIMARY KEY (AppLockName)
);
GO

CREATE MESSAGE TYPE AppLockGrant
VALIDATION = EMPTY;
GO

CREATE CONTRACT AppLockContract (
  AppLockGrant SENT BY INITIATOR
);
GO

CREATE QUEUE AppLock_Queue;
GO

CREATE SERVICE AppLock_Service
ON QUEUE AppLock_Queue (AppLockContract);
GO

CREATE QUEUE AppLockTimeout_Queue;
GO

CREATE SERVICE AppLockTimeout_Service
ON QUEUE AppLockTimeOut_Queue;
GO

-- Create the procedure to request an application lock
CREATE PROC GetAppLock
  @AppLockName nvarchar(255),
  @LockTimeout int,
  @AppLockKey uniqueidentifier = NULL OUTPUT
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  SET @AppLockKey = NULL;
  DECLARE @LOCK_TIMEOUT_LIFETIME int = 18000;
  DECLARE @startWait datetime = GETDATE();
  DECLARE @init_handle uniqueidentifier;
  DECLARE @target_handle uniqueidentifier;

  BEGIN TRAN;
  DECLARE @RETURN int;
  EXEC @RETURN = sp_getapplock
    @resource = @AppLockName,
    @lockmode = 'exclusive',
    @LockTimeout = @LockTimeout;

  IF @RETURN NOT IN (0, 1)
  BEGIN
    RAISERROR(
      'Error acquiring transactional lock for %s', 16, 1, @AppLockName);
    ROLLBACK;
    RETURN;
  END
  --Find out whether someone has requested this lock before
  SELECT
    @target_handle = TargetDialogHandle
  FROM AppLocks
  WHERE AppLockName = @AppLockName;

  --If we're here, we have the transactional lock
  IF @target_handle IS NOT NULL
  BEGIN
    --Find out whether the timeout has already expired...
    SET @LockTimeout = @LockTimeout - DATEDIFF(ms, @startWait, GETDATE());

    IF @LockTimeout > 0
    BEGIN
      --Wait for the OK message
      DECLARE @message_type nvarchar(255);

      --Wait for a grant message
      WAITFOR
      (
        RECEIVE
          @message_type = message_type_name
        FROM AppLock_Queue
        WHERE conversation_handle = @target_handle
      ), TIMEOUT @LockTimeout;
      IF @message_type = 'AppLockGrant'
      BEGIN
        BEGIN DIALOG CONVERSATION @AppLockKey
        FROM SERVICE AppLockTimeout_Service
        TO SERVICE 'AppLockTimeout_Service'
        WITH
          LIFETIME = @LOCK_TIMEOUT_LIFETIME,
          ENCRYPTION = OFF;

        UPDATE AppLocks
        SET
          AppLockKey = @AppLockKey,
          LastGrantedDate = GETDATE()
        WHERE
          AppLockName = @AppLockName;
      END

      ELSE IF @message_type IS NOT NULL
      BEGIN
        RAISERROR('Unexpected message type: %s', 16, 1, @message_type);
        ROLLBACK;
      END
    END
  END
  ELSE
  BEGIN
    --No one has requested this lock before
    BEGIN DIALOG @init_handle
    FROM SERVICE AppLock_Service
    TO SERVICE 'AppLock_Service'
    ON CONTRACT AppLockContract
    WITH ENCRYPTION = OFF;

    --Send a throwaway message to start the dialog on both ends
    SEND ON CONVERSATION @init_handle
    MESSAGE TYPE AppLockGrant;

    --Get the remote handle
    SELECT
      @target_handle = ce2.conversation_handle
    FROM sys.conversation_endpoints ce1
    JOIN sys.conversation_endpoints ce2 ON
      ce1.conversation_id = ce2.conversation_id
    WHERE
      ce1.conversation_handle = @init_handle
      AND ce2.is_initiator = 0;

    --Receive the throwaway message
    RECEIVE
      @target_handle = conversation_handle
    FROM AppLock_Queue
    WHERE conversation_handle = @target_handle;
    BEGIN DIALOG CONVERSATION @AppLockKey
    FROM SERVICE AppLockTimeout_Service
    TO SERVICE 'AppLockTimeout_Service'
    WITH
      LIFETIME = @LOCK_TIMEOUT_LIFETIME,
      ENCRYPTION = OFF;

    INSERT INTO AppLocks
    (
      AppLockName,
      AppLockKey,
      InitiatorDialogHandle,
      TargetDialogHandle
    )
    VALUES
    (
      @AppLockName,
      @AppLockKey,
      @init_handle,
      @target_handle
    );
  END

  IF @AppLockKey IS NOT NULL
    COMMIT;
  ELSE
  BEGIN
    RAISERROR(
      'Timed out waiting for lock on resource: %s', 16, 1, @AppLockName);
    ROLLBACK;
  END
END;
GO

-- Create the Procedure to Release the Lock
CREATE PROC ReleaseAppLock
  @AppLockKey uniqueidentifier
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  BEGIN TRAN;

  DECLARE @dialog_handle uniqueidentifier;

  UPDATE AppLocks
  SET
    AppLockKey = NULL,
    @dialog_handle = InitiatorDialogHandle
  WHERE
    AppLockKey = @AppLockKey;

  IF @@ROWCOUNT = 0
  BEGIN
    RAISERROR('AppLockKey not found', 16, 1);
    ROLLBACK;
  END

  END CONVERSATION @AppLockKey;

  --Allow another caller to acquire the lock
  SEND ON CONVERSATION @dialog_handle
  MESSAGE TYPE AppLockGrant;

  COMMIT;
END;
GO

-- Create the Activation Procedure
CREATE PROC AppLockTimeout_Activation
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  DECLARE @dialog_handle uniqueidentifier;

  WHILE 1=1
  BEGIN
    SET @dialog_handle = NULL;

    BEGIN TRAN;

    WAITFOR
    (
      RECEIVE @dialog_handle = conversation_handle
      FROM AppLockTimeout_Queue
    ), TIMEOUT 10000;

    IF @dialog_handle IS NOT NULL
    BEGIN
      EXEC ReleaseAppLock @AppLockKey = @dialog_handle;
    END

    COMMIT;
  END
END;
GO

ALTER QUEUE AppLockTimeout_Queue
WITH ACTIVATION
(
  STATUS = ON,
  PROCEDURE_NAME = AppLockTimeout_Activation,
  MAX_QUEUE_READERS = 1,
  EXECUTE AS OWNER
);
GO

-- Request a new Application Lock
DECLARE @AppLockKey uniqueidentifier
EXEC GetAppLock
    @AppLockName = 'Customers',
    @LockTimeout = 2000,
    @AppLockKey = @AppLockKey OUTPUT;

-- Print the locktoken
PRINT @AppLockKey

-- Release the lock
EXEC ReleaseAppLock @AppLockKey;


/*
 * OPTIMISTIC CONCURRENCY CONTROL
 */

CREATE TABLE CustomerNames
(
  CustomerId int NOT NULL PRIMARY KEY,
  CustomerName varchar(50) NOT NULL,
  Version rowversion NOT NULL
);
GO

-- Create some sample data
INSERT INTO CustomerNames
(
  CustomerId,
  CustomerName
)
VALUES
  (123, 'Mickey Mouse'),
  (456, 'Minnie Mouse');
GO

-- Select the data
SELECT *
FROM CustomerNames;
GO

-- Update a row
UPDATE CustomerNames
SET CustomerName = 'Pluto'
WHERE CustomerId = 456;
GO

-- Select again. Notice rowversion has changed
SELECT *
FROM CustomerNames;
GO

DECLARE
  @CustomerIdToUpdate int = 456,
  @Version rowversion;

SET @Version = 
(SELECT Version
FROM CustomerNames
WHERE CustomerId = @CustomerIdToUpdate);

UPDATE CustomerNames
SET CustomerName = 'Pluto'
WHERE
  CustomerId = @CustomerIdToUpdate
  AND Version = @Version;
IF @@ROWCOUNT = 0
  RAISERROR('Version conflict encountered', 16, 1);


  --Problem #1:
--What if not everyone follows the rules?
--Fix: Yet another trigger!
DROP TABLE CustomerNames
GO

--Use a UNIQUEIDENTIFIER or DATETIME
--instead of ROWVERSION
CREATE TABLE CustomerNames
(
    CustomerId INT NOT NULL PRIMARY KEY,
    CustomerName VARCHAR(50) NOT NULL,
    Version UNIQUEIDENTIFIER NOT NULL
        DEFAULT (NEWID())
)
GO


CREATE TRIGGER tg_UpdateCustomerNames
ON CustomerNames
FOR UPDATE AS
BEGIN
    SET NOCOUNT ON

	--Force the caller to update the Version column
	--treat the version as a lock token!
    IF NOT UPDATE(Version)
    BEGIN
        RAISERROR('Updating the Version column is required', 16, 1)
        ROLLBACK
    END

	--Are the versions the same?
    IF EXISTS
        (
            SELECT *
            FROM inserted i
            JOIN deleted d ON i.CustomerId = d.CustomerId
            WHERE i.Version <> d.Version        
        )
    BEGIN
        RAISERROR('Version conflict encountered', 16, 1)
        ROLLBACK
    END
    ELSE
        --Set new versions for the updated rows
        UPDATE CustomerNames
        SET Version = NEWID()
        WHERE 
            CustomerId IN
            (
                SELECT CustomerId
                FROM inserted
            )
END
GO

--Problem 2:
--User experience isn't great when
--a conflict occurs.
--Fix: Send back some data...
ALTER TRIGGER tg_UpdateCustomerNames
ON CustomerNames
FOR UPDATE AS
BEGIN
    SET NOCOUNT ON

	--Force the caller to update the Version column
	--treat the version as a lock token!
    IF NOT UPDATE(Version)
    BEGIN
        RAISERROR('Updating the Version column is required', 16, 1)
        ROLLBACK
    END

	--Are the versions the same?
    IF EXISTS
        (
            SELECT *
            FROM inserted i
            JOIN deleted d ON i.CustomerId = d.CustomerId
            WHERE i.Version <> d.Version        
        )
    BEGIN
		--Fake an XML DiffGram
		SELECT
			(
				SELECT 
					ROW_NUMBER() OVER (ORDER BY CustomerId) AS [@row_number],
					*
				FROM inserted
				FOR XML PATH('customer_name'), TYPE
			) new_values,
			(
				SELECT 
					ROW_NUMBER() OVER (ORDER BY CustomerId) AS [@row_number],
					*
				FROM deleted
				FOR XML PATH('customer_name'), TYPE
			) old_values
		FOR XML PATH('customer_name_rows')

        RAISERROR('Version conflict encountered', 16, 1)
        ROLLBACK
    END
    ELSE
        --Set new versions for the updated rows
        UPDATE CustomerNames
        SET Version = NEWID()
        WHERE 
            CustomerId IN
            (
                SELECT CustomerId
                FROM inserted
            )
END
GO


/*
 * MVCC
 */
USE TempDB
GO

-- Create a table to test updates...
CREATE TABLE Test_Updates
(
    PK_Col INT NOT NULL PRIMARY KEY,
    Other_Col VARCHAR(100) NOT NULL
)
GO
-- Insert some data
INSERT Test_Updates
(
    PK_Col,
    Other_Col
)
SELECT
    EmployeeId,
    Title
FROM AdventureWorks.HumanResources.Employee
GO
-- Now create a table to test inserts
CREATE TABLE Test_Inserts
(
    PK_Col INT NOT NULL,
    Other_Col VARCHAR(100) NOT NULL,
    Version INT IDENTITY(1,1) NOT NULL,
    PRIMARY KEY (PK_Col, Version)
)
GO

--Get the latest version of each row
SELECT
    ti.PK_Col,
    ti.Other_Col,
    ti.Version
FROM Test_Inserts ti
WHERE
    Version = 
    (
        SELECT MAX(ti1.Version)
        FROM Test_Inserts ti1
        WHERE 
            ti1.PK_Col = ti.PK_Col
    )
GO

-- Get a snapshot as of a given version
SELECT
    ti.PK_Col,
    ti.Other_Col,
    ti.Version
FROM Test_Inserts ti
WHERE
    Version = 
    (
        SELECT MAX(ti1.Version)
        FROM Test_Inserts ti1
        WHERE 
            ti1.PK_Col = ti.PK_Col
			--Pass in the version you want
			--a snapshot at
			AND Version <= 200
    )
GO

-- Clean up
DROP TABLE Test_Updates
GO
DROP TABLE Test_Inserts
GO