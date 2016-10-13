--Table of edges
CREATE TABLE Edges
(
    X INT NOT NULL,
    Y INT NOT NULL,
    PRIMARY KEY (X, Y)
)
GO



--Insert some edges
INSERT Edges VALUES (1, 2)
INSERT Edges VALUES (2, 1)
GO



--Any duplicates?
CREATE TRIGGER CheckForDuplicates
ON Edges
FOR INSERT, UPDATE
AS
BEGIN
    IF EXISTS
    (
        SELECT *
        FROM Edges e
        WHERE
            EXISTS
            (
                SELECT *
                FROM inserted i
                WHERE
                    i.x = e.y
                    AND i.y = e.x
            )
    )
    BEGIN
        ROLLBACK
    END
END
GO



--Create a numbers table
SELECT TOP (8000)
    IDENTITY(int, 1, 1) AS Number
INTO Numbers
FROM master..spt_values a
CROSS JOIN master..spt_values b

ALTER TABLE Numbers
ADD PRIMARY KEY (Number)
GO



--Create a view of duplicates
CREATE VIEW DuplicateEdges
WITH SCHEMABINDING
AS
    SELECT
        CASE n.Number
            WHEN 1 THEN e.X
            ELSE e.Y
        END X,
        CASE n.Number
            WHEN 1 THEN e.Y
            ELSE e.X
        END Y
    FROM dbo.Edges e
    CROSS JOIN dbo.Numbers n
    WHERE
        n.Number BETWEEN 1 AND 2
GO



--Index it
CREATE UNIQUE CLUSTERED INDEX IX_NoDuplicates
ON DuplicateEdges (X,Y)
GO



--Insert some more edges
INSERT Edges VALUES (2, 1)
INSERT Edges VALUES (1, 3)
GO



--Find all nodes connected to 1 (directed)
SELECT Y
FROM Edges e
WHERE X = 1
GO


--Find all nodes connected to 1 (undirected)
SELECT
    CASE
        WHEN X = 1 THEN Y
        ELSE X
    END
FROM Edges e
WHERE
    X = 1 OR Y = 1
GO



--A better-performing version?
SELECT Y
FROM Edges e
WHERE X = 1

UNION ALL

SELECT X
FROM Edges e
WHERE Y = 1
GO



--Creating the streets table
CREATE TABLE Streets
(
    StreetId INT NOT NULL PRIMARY KEY,
    StreetName VARCHAR(75)
)
GO

INSERT Streets VALUES (1, '1st Ave')
INSERT Streets VALUES (2, '2nd Ave')
INSERT Streets VALUES (3, '3rd Ave')
INSERT Streets VALUES (4, '4th Ave')
INSERT Streets VALUES (5, 'Madison')
GO



--Creating the intersections table
CREATE TABLE Intersections
(
    IntersectionId INT NOT NULL PRIMARY KEY,
    IntersectionName VARCHAR(10)
)
GO

INSERT Intersections VALUES (1, 'A')
INSERT Intersections VALUES (2, 'B')
INSERT Intersections VALUES (3, 'C')
INSERT Intersections VALUES (4, 'D')
GO



--Creating the intersections/streets table
CREATE TABLE IntersectionStreets
(
    IntersectionId INT NOT NULL
        REFERENCES Intersections (IntersectionId),
    StreetId INT NOT NULL
        REFERENCES Streets (StreetId),
    PRIMARY KEY (IntersectionId, StreetId)
)

INSERT IntersectionStreets VALUES (1, 1)
INSERT IntersectionStreets VALUES (1, 5)
INSERT IntersectionStreets VALUES (2, 2)
INSERT IntersectionStreets VALUES (2, 5)
INSERT IntersectionStreets VALUES (3, 3)
INSERT IntersectionStreets VALUES (3, 5)
INSERT IntersectionStreets VALUES (4, 4)
INSERT IntersectionStreets VALUES (4, 5)
GO



--Creating the street segments table
CREATE TABLE StreetSegments
(
    IntersectionId_Start INT NOT NULL,
    IntersectionId_End INT NOT NULL,
    StreetId INT NOT NULL,
    CONSTRAINT FK_Start
        FOREIGN KEY (IntersectionId_Start, StreetId)
        REFERENCES IntersectionStreets (IntersectionId, StreetId),
    CONSTRAINT FK_End
        FOREIGN KEY (IntersectionId_End, StreetId)
        REFERENCES IntersectionStreets (IntersectionId, StreetId),
    CONSTRAINT CK_Intersections
        CHECK (IntersectionId_Start <> IntersectionId_End),
    CONSTRAINT PK_StreetSegments
        PRIMARY KEY (IntersectionId_Start, IntersectionId_End)
)

INSERT StreetSegments VALUES (1, 2, 5)
INSERT StreetSegments VALUES (2, 3, 5)
INSERT StreetSegments VALUES (3, 4, 5)
GO



--Function to get an intersection
CREATE FUNCTION GetIntersectionId
(
    @Street1 VARCHAR(75),
    @Street2 VARCHAR(75)
)
RETURNS INT
WITH SCHEMABINDING
AS
BEGIN
    RETURN
    (
        SELECT
            i.IntersectionId
        FROM dbo.IntersectionStreets i
        WHERE
            StreetId IN
            (
                SELECT StreetId
                FROM dbo.Streets
                WHERE StreetName IN (@Street1, @Street2)
            )
        GROUP BY i.IntersectionId
        HAVING COUNT(*) = 2
    )
END
GO



--Finding connected intersections
SELECT
    @Start = dbo.GetIntersectionId('Madison', '1st Ave'),
    @End = dbo.GetIntersectionId('Madison', '4th Ave')

;WITH Paths
AS
(
    SELECT
        @Start AS theStart,
        IntersectionId_End AS theEnd
    FROM dbo.StreetSegments
    WHERE
        IntersectionId_Start = @Start

    UNION ALL

    SELECT
        p.theEnd,
        ss.IntersectionId_End
    FROM Paths p
    JOIN dbo.StreetSegments ss ON ss.IntersectionId_Start = p.theEnd
    WHERE p.theEnd <> @End
)
SELECT *
FROM Paths
GO



--Insert more data
--New street
INSERT Streets VALUES (6, 'Lexington')
--New intersections
INSERT Intersections VALUES (5, 'E')
INSERT Intersections VALUES (6, 'F')
INSERT Intersections VALUES (7, 'G')
INSERT Intersections VALUES (8, 'H')
--New intersection/street mappings
INSERT IntersectionStreets VALUES (5, 1)
INSERT IntersectionStreets VALUES (5, 6)
INSERT IntersectionStreets VALUES (6, 2)
INSERT IntersectionStreets VALUES (6, 6)
INSERT IntersectionStreets VALUES (7, 3)
INSERT IntersectionStreets VALUES (7, 6)
INSERT IntersectionStreets VALUES (8, 4)
INSERT IntersectionStreets VALUES (8, 6)
--North/South segments
INSERT StreetSegments VALUES (2, 2, 6, 2)
INSERT StreetSegments VALUES (4, 4, 8, 4)
--East/West segments
INSERT StreetSegments VALUES (8, 6, 7, 6)
INSERT StreetSegments VALUES (7, 6, 6, 6)
INSERT StreetSegments VALUES (6, 6, 5, 6)
GO



--New start/end points
SELECT
    @Start = dbo.GetIntersectionId('Madison', '1st Ave'),
    @End = dbo.GetIntersectionId('Lexington', '1st Ave')
GO



--Getting the full path
SELECT
    @Start = dbo.GetIntersectionId('Madison', '1st Ave'),
    @End = dbo.GetIntersectionId('Madison', '4th Ave')

;WITH Paths
AS
(
    SELECT
        @Start AS theStart,
        IntersectionId_End AS theEnd,
		CONVERT(VARCHAR(900),
			CONVERT(VARCHAR, @Start) + '.' +
			CONVERT(VARCHAR, IntersectionId_End) + '.'
		) AS ThePath
    FROM dbo.StreetSegments
    WHERE
        IntersectionId_Start = @Start

    UNION ALL

    SELECT
        p.theEnd,
        ss.IntersectionId_End,
		CONVERT(VARCHAR(900),
			p.ThePath +
			CONVERT(VARCHAR, IntersectionId_End) + '.'
		)
    FROM Paths p
    JOIN dbo.StreetSegments ss ON ss.IntersectionId_Start = p.theEnd
    WHERE p.theEnd <> @End
)
SELECT *
FROM Paths
WHERE theEnd = @End
GO



--Finish the data...
INSERT StreetSegments VALUES (5, 1, 1, 1)
INSERT StreetSegments VALUES (7, 3, 3, 3)
GO



--Full, fixed CTE
DECLARE
    @Start INT,
    @End INT

SELECT
    @Start = dbo.GetIntersectionId('Madison', '1st Ave'),
    @End = dbo.GetIntersectionId('Lexington', '1st Ave')

;WITH Paths
AS
(
    SELECT
        @Start AS theStart,
        IntersectionId_End AS theEnd,
        CONVERT(VARCHAR(900),
            '.' +
            CONVERT(VARCHAR, @Start) + '.' +
            CONVERT(VARCHAR, IntersectionId_End) + '.'
        ) AS ThePath
    FROM dbo.StreetSegments
    WHERE
        IntersectionId_Start = @Start

    UNION ALL

    SELECT
        p.theEnd,
        ss.IntersectionId_End,
        CONVERT(VARCHAR(900),
            p.ThePath +
            CONVERT(VARCHAR, IntersectionId_End) + '.'
        )
    FROM Paths p
    JOIN dbo.StreetSegments ss ON ss.IntersectionId_Start = p.theEnd
    WHERE
        p.theEnd <> @End
        AND p.thePath NOT LIKE '%.' + CONVERT(VARCHAR, ss.IntersectionId_End) + '.%'
)
SELECT *
FROM Paths
WHERE theEnd = @End
GO



--Creating the temp, worker table
USE AdventureWorks
GO

CREATE TABLE Employee_Temp
(
    EmployeeId INT NOT NULL
        CONSTRAINT PK_Employee PRIMARY KEY,
    ManagerId INT NULL
        CONSTRAINT FK_Manager REFERENCES Employee_Temp (EmployeeId),
    Title NVARCHAR(100)
)
GO

INSERT Employee_Temp
(
    EmployeeId,
    ManagerId,
    Title
)
SELECT
    EmployeeId,
    ManagerId,
    Title
FROM HumanResources.Employee
GO



--Finding reports
DECLARE @ManagerId INT

SELECT
    @ManagerId = EmployeeId
FROM Employee_Temp
WHERE ManagerId IS NULL

SELECT *
FROM Employee_Temp
WHERE ManagerId = @ManagerId
GO


--A better clustered index?
BEGIN TRAN

ALTER TABLE Employee_Temp
DROP CONSTRAINT FK_Manager

ALTER TABLE Employee_Temp
DROP CONSTRAINT PK_Employee

CREATE CLUSTERED INDEX IX_Manager
ON Employee_Temp (ManagerId)

ALTER TABLE Employee_Temp
ADD CONSTRAINT PK_Employee
PRIMARY KEY NONCLUSTERED (EmployeeId)

COMMIT
GO



--Traversing down
WITH n AS
(
    SELECT
        EmployeeId,
        ManagerId,
        Title
    FROM Employee_Temp
    WHERE ManagerId IS NULL

    UNION ALL

    SELECT
        e.EmployeeId,
        e.ManagerId,
        e.Title
    FROM Employee_Temp e
    JOIN n ON n.EmployeeId = e.ManagerId
)
SELECT
    n.EmployeeId,
    n.ManagerId,
    n.Title
FROM n
GO



--Another way to write the query
WITH n AS
(
    SELECT
        EmployeeId
    FROM Employee_Temp
    WHERE ManagerId IS NULL

    UNION ALL

    SELECT
        e.EmployeeId
    FROM Employee_Temp e
    JOIN n ON n.EmployeeId = e.ManagerId
)
SELECT
    e.EmployeeId,
    e.ManagerId,
    e.Title
FROM n
JOIN Employee_Temp e ON e.EmployeeId = n.EmployeeId
GO



--Ordering the output
WITH n AS
(
    SELECT
        EmployeeId,
        ManagerId,
        Title,
        CONVERT(VARCHAR(900),
            RIGHT(REPLICATE('0', 10) + CONVERT(VARCHAR, EmployeeId), 10) + '.'
        ) AS thePath
    FROM Employee_Temp
    WHERE ManagerId IS NULL

    UNION ALL

    SELECT
        e.EmployeeId,
        e.ManagerId,
        e.Title,
        CONVERT(VARCHAR(900),
            n.thePath +
            RIGHT(REPLICATE('0', 10) + CONVERT(VARCHAR, e.EmployeeId), 10) + '.'
        ) AS thePath
    FROM Employee_Temp e
    JOIN n ON n.EmployeeId = e.ManagerId
)
SELECT
    n.EmployeeId,
    n.ManagerId,
    n.Title,
    n.thePath
FROM n
ORDER BY n.thePath
GO



--Path enumeration
WITH n AS
(
    SELECT
        EmployeeId,
        ManagerId,
        Title,
        CONVERT(VARCHAR(900),
            '0000000001.'
        ) AS thePath
    FROM Employee_Temp
    WHERE ManagerId IS NULL

    UNION ALL

    SELECT
        e.EmployeeId,
        e.ManagerId,
        e.Title,
        CONVERT(VARCHAR(900),
            n.thePath +
            RIGHT(
                REPLICATE('0', 10) +
                    CONVERT(VARCHAR, ROW_NUMBER() OVER (ORDER BY e.Title)),
                10
            ) + '.'
        ) AS thePath
    FROM Employee_Temp e
    JOIN n ON n.EmployeeId = e.ManagerId
)
SELECT
    n.EmployeeId,
    n.ManagerId,
    n.Title,
    n.thePath
FROM n
ORDER BY n.thePath
GO



--Expanding the width of the hierarchy
DECLARE @CEO INT
SELECT
    @CEO = EmployeeId
FROM Employee_Temp
WHERE ManagerId IS NULL

DECLARE @width INT
SET @width = 1

WHILE @width <= 16
BEGIN
    INSERT Employee_Temp
    (
        EmployeeId,
        ManagerId,
        Title
    )
    SELECT
        e.EmployeeId + (1000 * @width),
        CASE e.ManagerId
            WHEN @CEO THEN e.ManagerId
            ELSE e.ManagerId + (1000 * @width)
        END,
        e.Title
    FROM Employee_Temp e
    WHERE
        e.ManagerId IS NOT NULL

    SET @width = @width * 2
END
GO



--Expanding the depth of the hierarchy
DECLARE @CEO INT
SELECT
    @CEO = EmployeeId
FROM Employee_Temp
WHERE ManagerId IS NULL

DECLARE @depth INT
SET @depth = 32

WHILE @depth <= 256
BEGIN
    DECLARE @OldManagers TABLE
    (
        EmployeeId INT
    )

    --Insert intermediate managers
    --Find all managers, except the CEO, and increment their EmployeeId by 1000
    INSERT Employee_Temp
    (
        EmployeeId,
        ManagerId,
        Title
    )
    OUTPUT inserted.EmployeeId - (1000 * @depth) INTO @OldManagers
    SELECT
        e.EmployeeId + (1000 * @depth) as newemp,
        e.ManagerId,
        'Intermediate Manager'
    FROM Employee_Temp e
    WHERE
        e.EmployeeId <> @CEO
        AND EXISTS
        (
            SELECT *
            FROM Employee_Temp e1
            WHERE e1.ManagerId = e.EmployeeId
        )

    --Update existing managers to report to intermediates
    UPDATE Employee_Temp
    SET ManagerId = EmployeeId + (1000 * @depth)
    WHERE
        EmployeeId IN
        (
            SELECT EmployeeId
            FROM @OldManagers
        )

    SET @depth = @depth * 2
END
GO



--Testing the non-CTE version
DECLARE @n TABLE
(
    EmployeeId INT,
    ManagerId INT,
    Title NVARCHAR(100),
    Depth INT,
    thePath VARCHAR(900),
    PRIMARY KEY (Depth, EmployeeId)
)

DECLARE @depth INT
SET @depth = 1

INSERT @n
SELECT
    EmployeeId,
    ManagerId,
    Title,
    @depth,
    '0000000001.'
FROM Employee_Temp
WHERE ManagerId IS NULL

WHILE 1=1
BEGIN
    INSERT @n
    SELECT
        e.EmployeeId,
        e.ManagerId,
        e.Title,
        @depth + 1,
        n.thePath +
            RIGHT(
                    REPLICATE('0', 10) +
                        CONVERT(VARCHAR, ROW_NUMBER() OVER
                            (PARTITION BY e.ManagerId ORDER BY e.Title)),
                    10
                ) + '.'
    FROM Employee_Temp e
    JOIN @n n on n.EmployeeId = e.ManagerId
    WHERE n.Depth = @depth

    IF @@ROWCOUNT = 0
        BREAK

    SET @depth = @depth + 1
END

SELECT
    EmployeeId,
    ManagerId,
    Title,
    thePath
FROM @n
ORDER BY
    thePath
GO



--Traversing up the hierarchy
;WITH n AS
(
    SELECT
        ManagerId,
        CONVERT(VARCHAR(900),
            RIGHT(
                REPLICATE('0', 10) +
                    CONVERT(VARCHAR, EmployeeId) + '.', 10)
        ) AS thePath
    FROM Employee_Temp
    WHERE EmployeeId = 217

    UNION ALL

    SELECT
        e.ManagerId,
        CONVERT(VARCHAR(900),
            n.thePath +
                RIGHT(
                    REPLICATE('0', 10) +
                        CONVERT(VARCHAR, e.EmployeeId),
                    10) + '.'
        ) AS thePath
    FROM Employee_Temp e
    JOIN n ON n.ManagerId = e.EmployeeId
)
SELECT *
FROM n
WHERE ManagerId IS NULL
GO

--Use the following to get back a table of IDs instead
SELECT
    COALESCE(ManagerId, 217) AS EmployeeId
FROM n
ORDER BY
    CASE
        WHEN ManagerId IS NULL THEN 0
        ELSE 1
    END,
    thePath
GO



--A new CTO?
INSERT Employee_Temp
(
    EmployeeId,
    ManagerId,
    Title
)
VALUES
(
    999,
    109,
    'CTO'
)
GO

UPDATE Employee_Temp
SET ManagerId = 999
WHERE EmployeeId = 12
GO



--Deleting nodes
UPDATE Employee_Temp
SET ManagerId =
    (
        SELECT ManagerId
        FROM Employee_Temp
        WHERE EmployeeId = 999
    )
WHERE ManagerId = 999

DELETE FROM Employee_Temp
WHERE EmployeeId = 999
GO


--Only one root node
CREATE VIEW OnlyOneRoot
WITH SCHEMABINDING
AS
    SELECT
        ManagerId
    FROM dbo.Employee_Temp
    WHERE
        ManagerId IS NULL
GO

CREATE UNIQUE CLUSTERED INDEX IX_OnlyOneRoot
ON OnlyOneRoot (ManagerId)
GO



--At least one root node
CREATE TRIGGER tg_AtLeastOneRoot
ON Employee_Temp
FOR UPDATE
AS
BEGIN
    SET NOCOUNT ON

    IF NOT EXISTS
    (
        SELECT *
        FROM Employee_Temp
        WHERE ManagerId IS NULL
    )
    BEGIN
        RAISERROR('A root node is required', 16, 1)
        ROLLBACK
    END
END
GO



--An employee cannot be its own manager
ALTER TABLE Employee_Temp
ADD CONSTRAINT ck_ManagerIsNotEmployee
    CHECK (EmployeeId <> ManagerId)
GO



--Cycles are not allowed
CREATE TRIGGER tg_NoCycles
ON Employee_Temp
FOR UPDATE
AS
BEGIN
    SET NOCOUNT ON

    --Only check if the ManagerId column was updated
    IF NOT UPDATE(ManagerId)
        RETURN

    --Avoid cycles
    DECLARE @CycleExists BIT
    SET @CycleExists = 0

    --Traverse up the hierarchy toward the
    --leaf node
    ;WITH e AS
    (
        SELECT EmployeeId, ManagerId
        FROM inserted

        UNION ALL

        SELECT e.EmployeeId, et.ManagerId
        FROM Employee_Temp et
        JOIN e ON e.ManagerId = et.EmployeeId
        WHERE
            et.ManagerId IS NOT NULL
            AND e.ManagerId <> e.EmployeeId
    )
    SELECT @CycleExists = 1
    FROM e
    WHERE e.ManagerId = e.EmployeeId

    IF @CycleExists = 1
    BEGIN
        RAISERROR('The update introduced a cycle', 16, 1)
        ROLLBACK
    END
END
GO



--Adding and populating a materialized path
ALTER TABLE Employee_Temp
ADD thePath VARCHAR(900)
GO

WITH n AS
(
    SELECT
        EmployeeId,
        CONVERT(VARCHAR(900),
            RIGHT(REPLICATE('0', 10) + CONVERT(VARCHAR, EmployeeId), 10) + '.'
        ) AS thePath
    FROM Employee_Temp
    WHERE ManagerId IS NULL

    UNION ALL

    SELECT
        e.EmployeeId,
        CONVERT(VARCHAR(900),
            n.thePath +
            RIGHT(REPLICATE('0', 10) + CONVERT(VARCHAR, e.EmployeeId), 10) + '.'
        ) AS thePath
    FROM Employee_Temp e
    JOIN n ON n.EmployeeId = e.ManagerId
)
UPDATE Employee_Temp
    SET Employee_Temp.thePath = n.thePath
FROM Employee_Temp
JOIN n ON n.EmployeeId = Employee_Temp.EmployeeId
GO



--Indexing the path
CREATE NONCLUSTERED INDEX IX_Employee_Temp_Path
ON Employee_Temp (thePath)
INCLUDE (EmployeeId, Title)
GO


--Subordinates
DECLARE @Path VARCHAR(900)
SELECT @Path = thePath
FROM Employee_Temp
WHERE EmployeeId = 12

SELECT *
FROM Employee_Temp
WHERE
    thePath LIKE @Path + '%'
ORDER BY thePath
GO


--Finding specific direct reports
DECLARE @Path VARCHAR(900)
SELECT @Path = thePath
FROM Employee_Temp
WHERE EmployeeId = 12

SELECT *
FROM Employee_Temp
WHERE
    thePath LIKE @Path + '%.'
    AND thePath NOT LIKE @Path + '%.%.'
GO



--Navigating up
;WITH n AS
(
    SELECT
        CONVERT(INT,
            SUBSTRING(thePath, 1, 10)
        ) AS EmployeeId,
        SUBSTRING(thePath, 12, LEN(thePath)) AS thePath,
        1 AS theLevel
    FROM Employee_Temp
    WHERE EmployeeId = 217

    UNION ALL

    SELECT
        CONVERT(INT,
            SUBSTRING(thePath, 1, 10)),
        SUBSTRING(thePath, 12, LEN(thePath)),
        theLevel + 1
    FROM n
    WHERE thePath <> ''
)
SELECT *
FROM n
ORDER BY theLevel
OPTION(MAXRECURSION 81)
GO



--Encoding in base 251
CREATE FUNCTION EncodeBase251(@i INT)
RETURNS CHAR(4)
AS
BEGIN
    DECLARE @byte TINYINT

    DECLARE @base_to_char CHAR(4)
    SET @base_to_char = ''

    DECLARE @j INT
    SET @j = 1

    WHILE @j <= 4
    BEGIN
        --Get each byte of the input, carrying over values > 251
        SET @byte = @i / power(251, (4 - @j))
        SET @i = @i % power(251, (4 - @j))

        SET @byte =
            CASE
                --Avoid CHAR(0)
                WHEN @byte <= 35 THEN @byte + 1
                --Avoid CHAR(37)
                WHEN @byte BETWEEN 36 AND 88 THEN @byte + 2
                --Avoid CHAR(91), CHAR(93), and CHAR(95)
                WHEN @byte = 89 THEN 92
                WHEN @byte = 90 THEN 94
                WHEN @byte >= 91 THEN @byte + 5
            END

        SET @base_to_char = STUFF(@base_to_char, @j, 1, CHAR(@byte))
        SET @j = @j + 1
    END

    RETURN(@base_to_char)
END
GO



--Decoding from base 251
CREATE FUNCTION DecodeBase251(@base_to_char CHAR(4))
RETURNS INT
AS
BEGIN
    DECLARE @byte TINYINT

    DECLARE @i INT
    SET @i = 0

    DECLARE @j INT
    SET @j = 1

    WHILE @j <= 4
    BEGIN
        SET
            @byte = ASCII(SUBSTRING(@base_to_char, @j, 1))

        SET
            @byte =
            CASE
                WHEN @byte >= 96 THEN @byte - 5
                WHEN @byte = 94 THEN 90
                WHEN @byte = 92 THEN 89
                WHEN @byte BETWEEN 38 AND 90 THEN @byte - 2
                ELSE @byte - 1
            END

        SET @i = @i +
            @byte * POWER(251, (4 - @j))

        SET @j = @j + 1
    END

    RETURN(@i)
END
GO


--Testing the UDFs
DECLARE @i INT
SET @i = 1234567

SELECT @i, dbo.DecodeBase251(dbo.EncodeBase251(@i))
GO




--Updating the path
WITH n AS
(
    SELECT
        EmployeeId,
        CONVERT(VARCHAR(900),
            dbo.EncodeBase251(EmployeeId)
        ) AS thePath
    FROM Employee_Temp
    WHERE ManagerId IS NULL

    UNION ALL

    SELECT
        e.EmployeeId,
        CONVERT(VARCHAR(900),
            n.thePath + dbo.EncodeBase251(e.EmployeeId)
        ) AS thePath
    FROM Employee_Temp e
    JOIN n ON n.EmployeeId = e.ManagerId
)
UPDATE Employee_Temp
    SET Employee_Temp.thePath = n.thePath
FROM Employee_Temp
JOIN n ON n.EmployeeId = Employee_Temp.EmployeeId
GO



--A new subordinates query
SELECT *
FROM Employee_Temp
WHERE
    thePath LIKE @Path + '____'
GO



--A new query to move up
;WITH n AS
(
    SELECT
        CONVERT(INT,
            dbo.DecodeBase251(SUBSTRING(thePath, 1, 4))
        ) AS EmployeeId,
        SUBSTRING(thePath, 5, LEN(thePath)) AS thePath,
        1 AS theLevel
    FROM Employee_Temp
    WHERE EmployeeId = 217

    UNION ALL

    SELECT
        CONVERT(INT,
            dbo.DecodeBase251(SUBSTRING(thePath, 1, 4))),
        SUBSTRING(thePath, 5, LEN(thePath)),
        theLevel + 1
    FROM n
    WHERE thePath <> ''
)
SELECT *
FROM n
ORDER BY theLevel
OPTION(MAXRECURSION 225)
GO



--Insert new nodes?
CREATE TRIGGER tg_Insert
ON Employee_Temp
FOR INSERT
AS
BEGIN
    SET NOCOUNT ON

    IF @@ROWCOUNT > 1
    BEGIN
        RAISERROR('Only one node can be inserted at a time', 16, 1)
        ROLLBACK
    END

    UPDATE e
    SET
        e.thePath =
            Managers.thePath +
                RIGHT(
                    REPLICATE('0', 10) + CONVERT(VARCHAR, i.EmployeeId),
                    10
                ) + '.'
    FROM Employee_Temp e
    JOIN inserted i ON i.EmployeeId = e.EmployeeId
    JOIN Employee_Temp Managers ON Managers.EmployeeId = e.ManagerId
END
GO



--An insert that could cause issues
INSERT Employee_Temp
(
    EmployeeId,
    ManagerId,
    Title
)
SELECT 1000, 999, 'Subordinate'
UNION ALL
SELECT 999, 109, 'Manager'
GO



--Average number of subordinates
SELECT AVG(NumberOfSubordinates)
FROM
(
    SELECT COUNT(*) AS NumberOfSubordinates
    FROM Employee_Temp e
    JOIN Employee_Temp e2 ON e2.thePath LIKE e.thePath + '%'
    GROUP BY e.EmployeeId
) x
GO



--Relocating subtrees
CREATE TRIGGER tg_Update
ON Employee_Temp
FOR UPDATE
AS
BEGIN
    DECLARE @n INT
    SET @n = @@ROWCOUNT

    IF UPDATE(thePath)
    BEGIN
        RAISERROR('Direct updates to the path are not allowed', 16, 1)
        ROLLBACK
    END

    IF UPDATE(ManagerId)
    BEGIN
        IF @n > 1
        BEGIN
            RAISERROR('Only update one node''s manager at a time', 16, 1)
            ROLLBACK
        END

        --Update all nodes using the new manager's path
        UPDATE e
        SET
            e.thePath =
                REPLACE(e.thePath, i.thePath,
                    Managers.thePath +
                        RIGHT(
                            REPLICATE('0', 10) + CONVERT(VARCHAR, i.EmployeeId),
                            10
                        ) + '.'
                )
        FROM Employee_Temp e
        JOIN inserted i ON e.thePath LIKE i.thePath + '%'
        JOIN Employee_Temp Managers ON Managers.EmployeeId = i.ManagerId
    END
END
GO



--No cycles!
ALTER TABLE Employee_Temp
ADD CONSTRAINT ck_NoCycles
    CHECK
    (
        thePath NOT LIKE
        '%' +
        RIGHT(REPLICATE('0', 10) +
            CONVERT(VARCHAR, EmployeeId), 10) +
        '.%' +
        RIGHT(REPLICATE('0', 10) +
            CONVERT(VARCHAR, EmployeeId), 10) +
        '.'
    )
GO



--Add right and left columns for nested sets
ALTER TABLE Employee_Temp
ADD
    lft INT,
    rgt INT
GO



--Populating the new columns
WITH SortPathCTE
AS
(
    SELECT
        EmployeeId,
        nums.n,
        CONVERT(VARBINARY(900),
            CASE nums.n
                WHEN 1 THEN 0x00000001
                ELSE 0x00000001FFFFFFFF
            END
        ) AS SortPath
    FROM Employee_Temp
    CROSS JOIN
    (
        SELECT 1
        UNION ALL
        SELECT 2
    ) nums (n)
    WHERE ManagerId IS NULL

    UNION ALL

    SELECT
        e.EmployeeId,
        nums.n,
        CONVERT(VARBINARY(900),
            sp.SortPath +
                CONVERT(BINARY(4),
                    ROW_NUMBER() OVER(ORDER BY e.EmployeeId)
                ) +
                    CASE nums.n
                        WHEN 1 THEN 0x
                        ELSE 0xFFFFFFFF
                    END
        )
    FROM SortPathCTE sp
    JOIN Employee_Temp AS e ON e.ManagerId = sp.EmployeeId
    CROSS JOIN
    (
        SELECT 1
        UNION ALL
        SELECT 2
    ) nums (n)
    WHERE sp.n = 1
),
SortCTE
AS
(
    SELECT
        EmployeeId,
        ROW_NUMBER() OVER(ORDER BY SortPath) AS SortVal
    FROM SortPathCTE
),
FinalCTE
AS
(
    SELECT
        EmployeeId,
        MIN(SortVal) AS Lft,
        MAX(SortVal) AS Rgt
    FROM SortCTE
    GROUP BY EmployeeId
)
UPDATE e
SET
    e.lft = f.lft,
    e.rgt = f.rgt
FROM Employee_Temp e
JOIN FinalCTE f ON e.EmployeeId = f.EmployeeId
GO



--Indexing the columns
CREATE UNIQUE NONCLUSTERED INDEX IX_rgt_lft
ON Employee_Temp (rgt, lft)
INCLUDE (EmployeeId, ManagerId, Title)
GO



--Subordinates
SELECT
    children.EmployeeId,
    children.ManagerId,
    children.Title
FROM Employee_Temp parent
JOIN Employee_Temp children ON
    children.lft BETWEEN parent.lft AND parent.rgt
WHERE
    parent.EmployeeId = 12
ORDER BY
    children.lft
GO



--Direct reports
SELECT
    children.EmployeeId,
    children.ManagerId,
    children.Title
FROM Employee_Temp parent
JOIN Employee_Temp children ON
    children.lft > parent.lft
    AND children.lft < parent.rgt
WHERE
    parent.EmployeeId = 109
    AND NOT EXISTS (
        SELECT *
        FROM Employee_Temp middle
        WHERE
            middle.lft > parent.lft
            AND middle.lft < children.lft
            AND middle.rgt < parent.rgt
            AND middle.rgt > children.rgt
        )
ORDER BY
    children.lft
GO



--Traversing up
SELECT
    parent.EmployeeId,
    parent.Title
FROM Employee_Temp parent
JOIN Employee_Temp child ON
    parent.lft < child.lft
    AND parent.rgt > child.rgt
WHERE child.EmployeeId = 11
GO



--Inserting nodes
CREATE TRIGGER tg_INSERT
ON Employee_Temp
FOR INSERT
AS
BEGIN
    SET NOCOUNT ON

    IF @@ROWCOUNT > 1
    BEGIN
        RAISERROR('Only one row can be inserted at a time.', 16, 1)
        ROLLBACK
    END

    --Get the inserted employee and manager IDs
    DECLARE
        @employeeId INT,
        @managerId INT

    SELECT
        @employeeId = EmployeeId,
        @managerId = ManagerId
    FROM inserted

    --Find the left value
    DECLARE @left INT

    --First try the right value of the sibling to the left
    --Sibling ordering based on EmployeeId order
    SELECT TOP(1)
        @left = rgt + 1
    FROM Employee_Temp
    WHERE
        ManagerId = @managerId
        AND EmployeeId < @employeeId
    ORDER BY EmployeeId DESC

    --If there is no left sibling, get the parent node's value
    IF @left IS NULL
    BEGIN
        SELECT
            @left = lft + 1
        FROM Employee_Temp
        WHERE EmployeeId = @managerId
    END

    --Update the new node's left and right values
    UPDATE Employee_Temp
    SET
        lft = @left,
        rgt = @left + 1
    WHERE EmployeeId = @EmployeeId

    --Update the rest of the nodes in the hierarchy
    UPDATE Employee_Temp
    SET
        lft = lft +
            CASE
                WHEN lft > @left THEN 2
                ELSE 0
            END,
        rgt = rgt + 2
    WHERE
        rgt >= @left
        AND EmployeeId <> @employeeId
END
GO




--Relocating subtrees
CREATE TRIGGER tg_UPDATE
ON Employee_Temp
FOR UPDATE
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @rowCount INT
    SET @rowCount = @@ROWCOUNT

    --Do nothing if this trigger was fired from another
    IF TRIGGER_NESTLEVEL() > 1
        RETURN

    IF @rowCount > 1 AND UPDATE(ManagerId)
    BEGIN
        RAISERROR('Only one row can be updated at a time.', 16, 1)
        ROLLBACK
    END

    IF UPDATE(lft) OR UPDATE(rgt)
    BEGIN
        RAISERROR('The hierarchy cannot be directly updated.', 16, 1)
        ROLLBACK
    END

    --Get the employee ID, new manager ID, and previous lft and rgt values
    DECLARE
        @employeeId INT,
        @managerId INT,
        @previousLeft INT,
        @previousRight INT,
        @numNodes INT

    SELECT
        @employeeId = EmployeeId,
        @managerId = ManagerId,
        @previousLeft = lft,
        @previousRight = rgt,
        @numNodes = rgt - lft
    FROM inserted

    DECLARE
        @left INT,
        @right INT

    --First try the left value of the sibling to the right
    --Sibling ordering based on EmployeeId order
    SELECT TOP(1)
        @right = lft - 1
    FROM Employee_Temp
    WHERE
        ManagerId = @managerId
        AND EmployeeId > @employeeId
    ORDER BY EmployeeId ASC

    --If there is no right sibling, get the parent node's value
    IF @right IS NULL
    BEGIN
        SELECT
            @right = rgt - 1
        FROM Employee_Temp
        WHERE EmployeeId = @managerId
    END

    DECLARE @difference INT

    --This is a move to the right
    IF @right > @previousRight
    BEGIN
        SET @difference = @right - @previousRight
        SET @left = @previousLeft + @difference

        UPDATE Employee_Temp
        SET
            lft =
                CASE
                    WHEN lft BETWEEN @previousLeft AND @previousRight THEN
                        lft + @difference
                    WHEN lft > @previousLeft THEN lft - (@numNodes + 1)
                    ELSE lft
                END,
            rgt =
                CASE
                    WHEN lft BETWEEN @previousLeft AND @previousRight THEN
                        rgt + @difference
                    WHEN rgt <= @right THEN rgt - (@numNodes + 1)
                    ELSE rgt
                END
        WHERE
            lft BETWEEN @previousLeft AND @right
            OR rgt BETWEEN @previousLeft AND @right
    END
    --This is a move to the left
    ELSE
    BEGIN
        --First try the right value of the sibling to the left
        --Sibling ordering based on EmployeeId order
        SELECT TOP(1)
            @left = rgt + 1
        FROM Employee_Temp
        WHERE
            ManagerId = @managerId
            AND EmployeeId < @employeeId
        ORDER BY EmployeeId DESC

        --If there is no left sibling, get the parent node's value
        IF @left IS NULL
        BEGIN
            SELECT
                @left = lft + 1
            FROM Employee_Temp
            WHERE EmployeeId = @managerId
        END

        SET @difference = @previousLeft - @Left
        SET @right = @previousRight - @difference

        UPDATE Employee_Temp
        SET
            lft =
                CASE
                    WHEN lft BETWEEN @previousLeft AND @previousRight THEN
                        lft - @difference
                    WHEN lft >= @left THEN lft + (@numNodes + 1)
                    ELSE lft
                END,
            rgt =
                CASE
                    WHEN lft BETWEEN @previousLeft AND @previousRight THEN
                        rgt - @difference
                    WHEN rgt < @previousRight THEN rgt + (@numNodes + 1)
                    ELSE rgt
                END
        WHERE
            lft BETWEEN @Left AND @previousRight
            OR rgt BETWEEN @Left AND @previousRight
    END
END
GO



--Deleting nodes
CREATE TRIGGER tg_DELETE
ON Employee_Temp
FOR DELETE
AS
BEGIN
    SET NOCOUNT ON

    IF @@ROWCOUNT > 1
    BEGIN
        RAISERROR('Only one row can be deleted at a time.', 16, 1)
        ROLLBACK
    END

    --Get the deleted right value
    DECLARE
        @right int

    SELECT
        @right = rgt
    FROM deleted

    --Update the rest of the nodes in the hierarchy
    UPDATE Employee_Temp
    SET
        lft = lft -
            CASE
                WHEN lft > @right THEN 2
                ELSE 0
            END,
        rgt = rgt - 2
    WHERE
        rgt >= @right
END
GO



--Add a level? (materialized path)
ALTER TABLE Employee_Temp
ADD theLevel AS
    (
        LEN(thePath) -
        LEN(REPLACE(thePath, '.', ''))
    ) PERSISTED
GO



