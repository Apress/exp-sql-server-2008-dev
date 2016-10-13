--British/French style
SELECT CONVERT(DATETIME, '01/02/2003', 103)

--U.S. style
SELECT CONVERT(DATETIME, '01/02/2003', 101)
GO



--British/French style
SET DATEFORMAT DMY
SELECT CONVERT(DATETIME, '01/02/2003')

--U.S. style
SET DATEFORMAT MDY
SELECT CONVERT(DATETIME, '01/02/2003')
GO



--British/French style
SELECT CONVERT(VARCHAR(50), GETDATE(), 103)

--U.S. style
SELECT CONVERT(VARCHAR(50), GETDATE(), 101)
GO



/*
//C# CLR UDF

public static SqlString FormatDate(
    SqlDateTime Date,
    SqlString FormatString)
{
    DateTime theDate = Date.Value;
    return new SqlString(theDate.ToString(FormatString.ToString()));
}
*/

SELECT dbo.FormatDate(GETDATE(), 'MM yyyy dd')
GO



USE TempDB
GO

--Create a table for dates
CREATE TABLE VariousDates
(
    ADate DATETIME NOT NULL,
    PRIMARY KEY (ADate) WITH (IGNORE_DUP_KEY = ON)
)
GO




--Insert data
;WITH Numbers
AS
(
    SELECT DISTINCT
        number
    FROM master..spt_values
    WHERE number BETWEEN 1001 AND 1256
)
INSERT VariousDates
(
    ADate
)
SELECT
    CASE x.n
        WHEN 1 THEN
            DATEADD(millisecond,
                POWER(a.number, 2) * b.number,
                DATEADD(day, a.number-1000, '20060201'))
        WHEN 2 THEN
            DATEADD(millisecond,
                b.number-1001,
                DATEADD(day, a.number-1000, '20060213'))
    END
FROM Numbers a
CROSS JOIN Numbers b
CROSS JOIN
(
    SELECT 1
    UNION ALL
    SELECT 2
) x (n)
GO




--First date in the table
SELECT MIN(ADate)
FROM VariousDates
GO



--Find all rows for Feb 13
SELECT *
FROM VariousDates
WHERE ADate = '20060213'
GO



--Convert the literal to a date/time instance
SELECT CONVERT(DATETIME, '20060213')
GO



--A non-sargable predicate
SELECT *
FROM VariousDates
WHERE CONVERT(VARCHAR(20), ADate, 112) = '20060213'
GO



--Sargable...
SELECT *
FROM VariousDates
WHERE ADate BETWEEN '20060213' AND '20060214'
GO




--A better predicate
SELECT *
FROM VariousDates
WHERE
    ADate >= '20060213'
    AND ADate < '20060214'
GO




--Difference in hours
SELECT DATEDIFF(hour, '20060113', '20060114')
GO



--Adding 24 hours
SELECT DATEADD(hour, 24, '20060113')
GO



--Difference in days
DECLARE @InputDate DATETIME
SET @InputDate = '2006-04-23 13:45:43.233'

SELECT DATEDIFF(day, 0, @InputDate)
GO



--Adding days...
SELECT DATEADD(day, 38828, 0)
GO



--Complete day truncation
SELECT DATEADD(day, DATEDIFF(day, 0, @InputDate), 0)
GO



--Month truncation
SELECT DATEADD(month, DATEDIFF(month, 0, @InputDate), 0)
GO



--Last day of the month
SELECT DATEADD(day, -1, DATEADD(month, DATEDIFF(month, 0, @InputDate)+1, 0))
GO



--... another way...
SELECT DATEADD(month, DATEDIFF(month, '19001231', @InputDate), '19001231')
GO



--Number of days...
DECLARE @Friday DATETIME
SET @Friday = '20000107'

SELECT DATEDIFF(day, @Friday, '20060209')
GO


--...
SELECT (2225 / 7) * 7
GO



--Last Friday before Feb 9, 2006
SELECT DATEADD(day, 2219, '20000107')
GO



--... Combined to simplify
DECLARE @Friday DATETIME
SET @Friday = '20000107'

SELECT DATEADD(day, ((DATEDIFF(day, @Friday, @InputDate) / 7) * 7), @Friday)
GO



--Even better
SELECT DATEADD(week, (DATEDIFF(day, @Friday, @InputDate) / 7), @Friday)
GO



--...
DECLARE @Friday DATETIME
SET @Friday = '20000107'
DECLARE @Saturday DATETIME
SET @Saturday = '20000108'

SELECT DATEADD(week, (DATEDIFF(day, @Saturday, @InputDate) / 7), @Friday)
GO



--Next Friday
SELECT DATEADD(week, (DATEDIFF(day, @Friday, GETDATE()) / 7)+1, @Friday)
GO



--2nd Thursday
DECLARE @Thursday DATETIME
SET @Thursday = '20000914'

DECLARE @FourteenthOfMonth DATETIME
SET @FourteenthOfMonth =
    DATEADD(month, DATEDIFF(month, @Thursday, @InputDate), @Thursday)

SELECT DATEADD(week, (DATEDIFF(day, @Thursday, @FourteenthOfMonth) / 7), @Thursday)
GO



--Next 2nd Thursday
DECLARE @Thursday DATETIME
SET @Thursday = '20000914'

DECLARE @FourteenthOfMonth DATETIME
SET @FourteenthOfMonth =
    DATEADD(month, DATEDIFF(month, @Thursday, @InputDate), @Thursday)

DECLARE @SecondThursday DATETIME
SET @SecondThursday =
    DATEADD(week, (DATEDIFF(day, @Thursday, @FourteenthOfMonth) / 7), @Thursday)

SELECT
    CASE
        WHEN @InputDate <= @SecondThursday
        THEN @SecondThursday
    ELSE
        DATEADD(
            week,
            CASE
                WHEN DATEPART(day, @SecondThursday) <= 10 THEN 5
                ELSE 4
            END,
            @SecondThursday)
    END
GO



--Find "today's rows"
SELECT *
FROM VariousDates
WHERE
    ADate >= DATEADD(day, DATEDIFF(day, 0, GETDATE()), 0)
    AND ADate < DATEADD(day, DATEDIFF(day, 0, GETDATE())+1, 0)
GO



--Does this find out how old you are?
SELECT DATEDIFF(year, @YourBirthday, GETDATE())
GO



--Probably not
SELECT DATEDIFF(year, '19650325', '20060324')
GO



--This does
SELECT
    DATEDIFF (
        YEAR,
        @YourBirthday,
        GETDATE()) -
    CASE
        WHEN 100 * MONTH(GETDATE()) + DAY(GETDATE())
            < 100 * MONTH(@YourBirthday) + DAY(@YourBirthday) THEN 1
        ELSE 0
    END
GO



/*
NOTE!

For the next section you need to create the calendar 
table using BIDS, as described in the chapter
*/

--Find today
SELECT *
FROM Temporal.Calendar AS Today
WHERE Today.PK_Date = DATEADD(day, DATEDIFF(day, 0, GETDATE()), 0)
GO



--Find last Friday
SELECT TOP(1) *
FROM Temporal.Calendar LastFriday
WHERE
    LastFriday.PK_Date < DATEADD(day, DATEDIFF(day, 0, GETDATE()), 0)
    AND LastFriday.Day_of_Week = 6
ORDER BY PK_Date DESC
GO



--Add day and month descriptions to the table
ALTER TABLE Temporal.Calendar
ADD
    Day_Description VARCHAR(15) NULL,
    Month_Description VARCHAR(15) NULL

UPDATE Temporal.Calendar
SET
    Day_Description = DATENAME(weekday, PK_Date),
    Month_Description = DATENAME(month, PK_Date)

ALTER TABLE Temporal.Calendar
ALTER COLUMN Day_Description VARCHAR(15) NOT NULL

ALTER TABLE Temporal.Calendar
ALTER COLUMN Month_Description VARCHAR(15) NOT NULL
GO



--First and last days of the week
SELECT
    MIN(ThisWeek.PK_Date) AS FirstDayOfWeek,
    MAX(ThisWeek.PK_Date) AS LastDayOfWeek
FROM Temporal.Calendar AS Today
JOIN Temporal.Calendar AS ThisWeek ON
    ThisWeek.Year = Today.Year
    AND ThisWeek.Week_of_Year = Today.Week_of_Year
WHERE
    Today.PK_Date = DATEADD(day, DATEDIFF(day, 0, GETDATE()), 0)
GO



--Friday of last week
SELECT FridayLastWeek.*
FROM Temporal.Calendar AS Today
JOIN Temporal.Calendar AS FridayLastWeek ON
    Today.Year = FridayLastWeek.Year
    AND Today.Week_Of_Year - 1 = FridayLastWeek.Week_Of_Year
WHERE
    Today.PK_Date = DATEADD(day, DATEDIFF(day, 0, GETDATE()), 0)
    AND FridayLastWeek.Day_Description = 'Friday'
GO



--Add a week number
ALTER TABLE Temporal.Calendar
ADD Week_Number INT NULL
GO



--Get all of the week numbers
;WITH StartOfWeek (PK_Date)
AS
(
    SELECT MIN(PK_Date)
    FROM Temporal.Calendar

    UNION

    SELECT PK_Date
    FROM Temporal.Calendar
    WHERE Day_of_Week = 1
),
EndOfWeek (PK_Date)
AS
(
    SELECT PK_Date
    FROM Temporal.Calendar
    WHERE Day_of_Week = 7

    UNION

    SELECT MAX(PK_Date)
    FROM Temporal.Calendar
)
SELECT
    StartOfWeek.PK_Date AS Start_Date,
    (
        SELECT TOP(1)
            EndOfWeek.PK_Date
        FROM EndOfWeek
        WHERE EndOfWeek.PK_Date >= StartOfWeek.PK_Date
        ORDER BY EndOfWeek.PK_Date
    ) AS End_Date,
    ROW_NUMBER() OVER (ORDER BY StartOfWeek.PK_Date) AS Week_Number
INTO #WeekNumbers
FROM StartOfWeek
GO



--Do the update
UPDATE Temporal.Calendar
SET Week_Number =
    (
        SELECT WN.Week_Number
        FROM #WeekNumbers AS WN
        WHERE
            Temporal.Calendar.PK_Date BETWEEN WN.Start_Date AND WN.End_Date
    )

ALTER TABLE Temporal.Calendar
ALTER COLUMN Week_Number INT NOT NULL
GO



--Friday of last week, using week number
SELECT FridayLastWeek.*
FROM Temporal.Calendar AS Today
JOIN Temporal.Calendar AS FridayLastWeek ON
    Today.Week_Number = FridayLastWeek.Week_Number + 1
WHERE
    Today.PK_Date = DATEADD(day, DATEDIFF(day, 0, GETDATE()), 0)
    AND FridayLastWeek.Day_Description = 'Friday'
GO



--Subquery instead of join
SELECT FridayLastWeek.*
FROM Temporal.Calendar AS FridayLastWeek
WHERE
    FridayLastWeek.Day_Description = 'Friday'
    AND FridayLastWeek.Week_Number =
    (
        SELECT Today.Week_Number - 1
        FROM Temporal.Calendar AS Today
        WHERE Today.PK_Date = DATEADD(day, DATEDIFF(day, 0, GETDATE()), 0)
    )
GO



--2nd Thursday, redux
;WITH NextTwoMonths
AS
(
    SELECT
        Year,
        Month_of_Year
    FROM Temporal.Calendar
    WHERE
        PK_Date IN
        (
            DATEADD(day, DATEDIFF(day, 0, GETDATE()), 0),
            DATEADD(month, 1, DATEADD(day, DATEDIFF(day, 0, GETDATE()), 0))
        )
),
NumberedThursdays
AS
(
    SELECT
        Thursdays.*,
        ROW_NUMBER() OVER (PARTITION BY Month ORDER BY PK_Date) AS ThursdayNumber
    FROM Temporal.Calendar Thursdays
    JOIN NextTwoMonths ON
        NextTwoMonths.Year = Thursdays.Year
        AND NextTwoMonths.Month_of_Year = Thursdays.Month_of_Year
    WHERE
        Thursdays.Day_Description = 'Thursday'
)
SELECT TOP(1)
    NumberedThursdays.*
FROM NumberedThursdays
WHERE
    NumberedThursdays.PK_Date >= DATEADD(day, DATEDIFF(day, 0, GETDATE()), 0)
    AND NumberedThursdays.ThursdayNumber = 2
ORDER BY NumberedThursdays.PK_Date
GO



--Need to find all holidays?
ALTER TABLE Temporal.Calendar
ADD Holiday_Description VARCHAR(50) NULL
GO



--How many business days this month?
SELECT COUNT(*)
FROM Temporal.Calendar AS ThisMonth
WHERE
    Holiday_Description IS NULL
    AND EXISTS
    (
        SELECT *
        FROM Temporal.Calendar AS Today
        WHERE
            Today.PK_Date = DATEADD(day, DATEDIFF(day, 0, GETDATE()), 0)
            AND Today.Year = ThisMonth.Year
            AND Today.Month_Of_Year = ThisMonth.Month_of_Year
    )
GO



/*
Following code uses TimeZoneSample and related functions, as described in the chapter
*/


--Get today's orders, v.1
CREATE PROCEDURE GetTodaysOrders
AS
BEGIN
    SET NOCOUNT ON

    SELECT
        OrderDate,
        SalesOrderNumber,
        AccountNumber,
        TotalDue
    FROM Sales.SalesOrderHeader
    WHERE
        OrderDate >= DATEADD(day, DATEDIFF(day, 0, GETDATE()), 0)
        AND OrderDate < DATEADD(day, DATEDIFF(day, 0, GETDATE())+1, 0)
END
GO



--A better version
CREATE PROCEDURE GetTodaysOrders
    @TimeZoneIndex = 35
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @TodayUtc DATETIME
    SET @TodayUtc = dbo.ConvertUtcToTimeZone(GETUTCDATE(), @TimeZoneIndex)
    SET @TodayUtc = DATEADD(day, DATEDIFF(day, 0, @TodayUtc), 0)
    SET @TodayUtc = dbo.ConvertTimeZoneToUtc(@TodayUtc, @TimeZoneIndex)
    SELECT @TodayUtc

    SELECT
        OrderDate,
        SalesOrderNumber,
        AccountNumber,
        TotalDue
    FROM Sales.SalesOrderHeader
    WHERE
        OrderDate >= @TodayUtc
        AND OrderDate < DATEADD(day, 1, @TodayUtc)
END
GO



--Job history table
CREATE TABLE JobHistory
(
    Company VARCHAR(100),
    Title VARCHAR(100),
    Pay DECIMAL(9, 2),
    StartDate SMALLDATETIME
)
GO

INSERT JobHistory
(
    Company,
    Title,
    Pay,
    StartDate
)
SELECT 'Acme Corp', 'Programmer', 50000.00, '1995-06-26'
UNION ALL
SELECT 'Software Shop', 'Programmer/Analyst', 62000.00, '1998-10-05'
UNION ALL
SELECT 'Better Place', 'Junior DBA', 82000.00, '2001-01-08'
UNION ALL
SELECT 'Enterprise', 'Database Developer', 95000.00, '2005-11-14'
GO




--Add a check constraint
ALTER TABLE JobHistory
ADD CONSTRAINT CK_StartDate_Midnight
    CHECK (StartDate = DATEADD(day, DATEDIFF(day, 0, StartDate), 0))
GO



--Start/end report
SELECT
    J1.*,
    COALESCE((
        SELECT MIN(J2.StartDate)
        FROM JobHistory AS J2
        WHERE J2.StartDate > J1.StartDate),
        GETDATE()
    ) AS EndDate
FROM JobHistory AS J1
GO



--Pay changes...
INSERT JobHistory
(
    Company,
    Title,
    Pay,
    StartDate
)
SELECT 'Acme Corp', 'Programmer', 55000.00, '1996-09-01'
UNION ALL
SELECT 'Acme Corp', 'Programmer 2', 58000.00, '1997-09-01'
UNION ALL
SELECT 'Acme Corp', 'Programmer 3', 58000.00, '1998-09-01'
UNION ALL
SELECT 'Software Shop', 'Programmer/Analyst', 62000.00, '1998-10-05'
UNION ALL
SELECT 'Software Shop', 'Programmer/Analyst', 67000.00, '2000-01-01'
UNION ALL
SELECT 'Software Shop', 'Programmer', 40000.00, '2000-03-01'
UNION ALL
SELECT 'Better Place', 'Junior DBA', 84000.00, '2002-06-01'
UNION ALL
SELECT 'Better Place', 'DBA', 87000.00, '2004-06-01'
GO



--Max pay per company
SELECT
    Pay,
    Title
FROM JobHistory AS J2
WHERE
    J2.Pay =
    (
        SELECT MAX(Pay)
        FROM JobHistory AS J3
        WHERE J3.Company = J2.Company
    )
GO



--Correct start/end dates
SELECT
    J1.Company,
    MIN(J1.StartDate) AS StartDate,
    COALESCE((
        SELECT MIN(J2.StartDate)
        FROM JobHistory AS J2
        WHERE
            J2.Company <> J1.Company
            AND J2.StartDate > MIN(J1.StartDate)),
        GETDATE()
    ) AS EndDate
FROM JobHistory AS J1
GROUP BY J1.Company
ORDER BY StartDate
GO



--What if the employee left and later returned?
SELECT
    J1.Company,
    J1.StartDate AS StartDate,
    COALESCE((
        SELECT MIN(J2.StartDate)
        FROM JobHistory AS J2
        WHERE
            J2.Company <> J1.Company
            AND J2.StartDate > J1.StartDate),
        GETDATE()
    ) AS EndDate
FROM JobHistory AS J1
WHERE
    J1.Company <>
    COALESCE((
        SELECT TOP(1)
            J3.Company
        FROM JobHistory J3
        WHERE J3.StartDate < J1.StartDate
        ORDER BY J3.StartDate DESC),
        '')
GROUP BY
    J1.Company,
    J1.StartDate
ORDER BY
    J1.StartDate
GO



--Maximum salary and associated title
SELECT
    x.Company,
    x.StartDate,
    x.EndDate,
    p.Pay,
    p.Title
FROM
(
    SELECT
        J1.Company,
        MIN(J1.StartDate) AS StartDate,
        COALESCE((
            SELECT MIN(J2.StartDate)
            FROM JobHistory AS J2
            WHERE
                J2.Company <> J1.Company
                AND J2.StartDate > MIN(J1.StartDate)),
            GETDATE()
        ) AS EndDate
    FROM JobHistory AS J1
    GROUP BY J1.Company
) x
CROSS APPLY
(
    SELECT
        Pay,
        Title
    FROM JobHistory AS J2
    WHERE
        J2.StartDate >= x.StartDate
        AND J2.StartDate < x.EndDate
        AND J2.Pay =
        (
            SELECT MAX(Pay)
            FROM JobHistory AS J3
            WHERE J3.Company = J2.Company
        )
) p
ORDER BY x.StartDate
GO



--Modified subquery
SELECT TOP(1)
    Pay,
    Title
FROM JobHistory AS J2
WHERE
    J2.StartDate >= x.StartDate
    AND J2.StartDate < x.EndDate
ORDER BY Pay DESC
GO



--Server statuses
CREATE TABLE ServerStatus
(
    ServerName VARCHAR(50),
    Status VARCHAR(15),
    StatusTime DATETIME
)
GO

INSERT ServerStatus
(
    ServerName,
    Status,
    StatusTime
)
SELECT 'WebServer', 'Available', '2005-04-20 03:00:00.000'
UNION ALL
SELECT 'DBServer', 'Available', '2005-04-20 03:00:00.000'
UNION ALL
SELECT 'DBServer', 'Unavailable', '2005-06-12 14:35:23.100'
UNION ALL
SELECT 'DBServer', 'Available', '2005-06-12 14:38:52.343'
UNION ALL
SELECT 'WebServer', 'Unavailable', '2005-06-15 09:16:03.593'
UNION ALL
SELECT 'WebServer', 'Available', '2005-06-15 09:28:17.006'
GO




--Unavailable intervals
SELECT
    S1.ServerName,
    S1.StatusTime,
    COALESCE((
        SELECT MIN(S2.StatusTime)
        FROM ServerStatus AS S2
        WHERE
            S2.StatusTime > S1.StatusTime),
        GETDATE()
    ) AS EndTime
FROM ServerStatus AS S1
WHERE S1.Status = 'Unavailable'
GO



--What if periodic statuses were sent?
SELECT
    S1.ServerName,
    MIN(S1.StatusTime) AS StartTime,
    p.EndTime
FROM ServerStatus AS S1
CROSS APPLY
(
    SELECT
        COALESCE((
            SELECT MIN(S2.StatusTime)
            FROM ServerStatus AS S2
            WHERE
                S2.StatusTime > S1.StatusTime
                AND S2.Status = 'Available'
            ),
            GETDATE()
        ) AS EndTime
) p
WHERE S1.Status = 'Unavailable'
GROUP BY
    S1.ServerName,
    p.EndTime
GO



--Employment history...
CREATE TABLE EmploymentHistory
(
    Employee VARCHAR(50) NOT NULL,
    Title VARCHAR(50) NOT NULL,
    StartDate SMALLDATETIME NOT NULL,
    EndDate SMALLDATETIME NULL,
    CONSTRAINT CK_Start_End CHECK (StartDate < EndDate)
)
GO




--Add a PK
ALTER TABLE EmploymentHistory
ADD PRIMARY KEY (Employee, StartDate)
GO



--Some data
INSERT EmploymentHistory
(
    Employee,
    Title,
    StartDate,
    EndDate
)
SELECT 'Jones', 'Developer', '2006-01-01', NULL
UNION ALL
SELECT 'Jones', 'Senior Developer', '2006-06-01', NULL
GO



--Some incorrect rows?
INSERT EmploymentHistory
(
    Employee,
    Title,
    StartDate,
    EndDate
)
SELECT 'Jones', 'Developer', '2006-01-01', '2006-07-01'
UNION ALL
SELECT 'Jones', 'Senior Developer', '2006-06-01', NULL
GO



--Yet another scenario
INSERT EmploymentHistory
(
    Employee,
    Title,
    StartDate,
    EndDate
)
SELECT 'Jones', 'Developer', '2004-01-05', '2004-09-01'
UNION ALL
SELECT 'Jones', 'Senior Developer', '2004-09-01', '2005-09-01'
UNION ALL
SELECT 'Jones', 'Principal Developer', '2005-09-01', '2005-10-07'
UNION ALL
SELECT 'Jones', 'Principal Developer', '2006-02-06', NULL
GO



--When did Jones work for the firm?
SELECT
    theStart.StartDate
FROM EmploymentHistory theStart
WHERE
    theStart.Employee = 'Jones'
    AND NOT EXISTS
    (
        SELECT *
        FROM EmploymentHistory Previous
        WHERE
            Previous.EndDate = theStart.StartDate
            AND theStart.Employee = Previous.Employee
    )
GO



--Find all covered intervals
SELECT
    theStart.StartDate,
    (
        SELECT
            MIN(EndDate)
        FROM EmploymentHistory theEnd
        WHERE
            theEnd.EndDate > theStart.StartDate
            AND theEnd.Employee = theStart.Employee
            AND NOT EXISTS
            (
                SELECT *
                FROM EmploymentHistory After
                WHERE
                    After.StartDate = theEnd.EndDate
                    AND After.Employee = theEnd.Employee
            )
    ) AS EndDate
FROM EmploymentHistory theStart
WHERE
    theStart.Employee = 'Jones'
    AND NOT EXISTS
    (
        SELECT *
        FROM EmploymentHistory Previous
        WHERE
            Previous.EndDate = theStart.StartDate
            AND theStart.Employee = Previous.Employee
    )
GO



--Find holes
SELECT
    theStart.EndDate AS StartDate,
    (
        SELECT MIN(theEnd.StartDate)
        FROM EmploymentHistory theEnd
        WHERE
            theEnd.StartDate > theStart.EndDate
            AND theEnd.Employee = theStart.Employee
    ) AS EndDate
FROM EmploymentHistory theStart
WHERE
    theStart.Employee = 'Jones'
    AND theStart.EndDate IS NOT NULL
    AND NOT EXISTS
    (
        SELECT *
        FROM EmploymentHistory After
        WHERE After.StartDate = theStart.EndDate
    )
GO



--Overlaps
SELECT *
FROM EmploymentHistory E1
JOIN EmploymentHistory E2 ON
    E1.Employee = E2.Employee
    AND (
        E1.StartDate < COALESCE(E2.EndDate, '2079-06-06')
        AND COALESCE(E1.EndDate, '2079-06-06') > E2.StartDate)
    AND E1.StartDate <> E2.StartDate
WHERE
    E1.Employee = 'Jones'
GO



--Avoid overlaps
CREATE TRIGGER No_Overlaps
ON EmploymentHistory
FOR UPDATE, INSERT
AS
BEGIN
    IF EXISTS
    (
        SELECT *
        FROM inserted i
        JOIN EmploymentHistory E2 ON
            i.Employee = E2.Employee
            AND (
                i.StartDate < COALESCE(E2.EndDate, '2079-06-06')
                AND COALESCE(i.EndDate, '2079-06-06') > E2.StartDate)
            AND i.StartDate <> E2.StartDate
    )
    BEGIN
        RAISERROR('Overlapping interval inserted!', 16, 1)
        ROLLBACK
    END
END
GO



--Which intervals had the most overlaps?
SELECT
    O1.StartTime,
    O1.EndTime,
    COUNT(*)
FROM Overlap_Trace O1
JOIN Overlap_Trace O2 ON
    (O1.StartTime < O2.EndTime AND O1.EndTime > O2.StartTime)
    AND O1.SPID <> O2.SPID
GROUP BY
    O1.StartTime,
    O1.EndTime
ORDER BY COUNT(*) DESC
GO



--A supporting index...
CREATE NONCLUSTERED INDEX IX_StartEnd
ON Overlap_Trace (StartTime, EndTime, SPID)
GO



--A better-performing version of the query
SELECT
    x.StartTime,
    x.EndTime,
    SUM(x.theCount)
FROM
(
SELECT
    O1.StartTime,
    O1.EndTime,
    COUNT(*) AS theCount
FROM Overlap_Trace O1
JOIN Overlap_Trace O2 ON
    (O1.StartTime >= O2.StartTime AND O1.StartTime < O2.EndTime)
    AND O1.SPID <> O2.SPID
GROUP BY
    O1.StartTime,
    O1.EndTime

UNION ALL

SELECT
    O1.StartTime,
    O1.EndTime,
    COUNT(*) AS theCount
FROM Overlap_Trace O1
JOIN Overlap_Trace O2 ON
    (O1.StartTime < O2.StartTime AND O1.EndTime > O2.StartTime)
    AND O1.SPID <> O2.SPID
GROUP BY
    O1.StartTime,
    O1.EndTime
) x
GROUP BY
    x.StartTime,
    x.EndTime
ORDER BY SUM(x.theCount) DESC
OPTION(HASH GROUP)
GO



--Time slicing function
ALTER FUNCTION TimeSlice
(
    @StartDate DATETIME,
    @EndDate DATETIME
)
RETURNS @t TABLE
(
    DisplayDate DATETIME NOT NULL,
    StartDate DATETIME NOT NULL,
    EndDate DATETIME NOT NULL,
    PRIMARY KEY (StartDate, EndDate) WITH (IGNORE_DUP_KEY=ON)
)
WITH SCHEMABINDING
AS
BEGIN
    IF (@StartDate > @EndDate)
        RETURN

    DECLARE @TruncatedStart DATETIME
    SET @TruncatedStart =
        DATEADD(second, DATEDIFF(second, '20000101', @StartDate), '20000101')

    DECLARE @TruncatedEnd DATETIME
    SET @TruncatedEnd =
        DATEADD(second, DATEDIFF(second, '20000101', @EndDate), '20000101')

    --Insert start and end date/times first
    --Make sure to match the same start/end interval passed in
    INSERT @t
    (
        DisplayDate,
        StartDate,
        EndDate
    )
    SELECT
        @TruncatedStart,
        @StartDate,
        CASE
            WHEN
                DATEADD(second, 1, @TruncatedStart) > @EndDate THEN @EndDate
            ELSE
                DATEADD(second, 1, @TruncatedStart)
        END
    UNION ALL
    SELECT
        @TruncatedEnd,
        CASE
            WHEN
               @TruncatedEnd < @StartDate THEN @StartDate
            ELSE
               @TruncatedEnd
        END,
        @EndDate

    SET @TruncatedStart =
        DATEADD(second, 1, @TruncatedStart)

    --Insert one time unit for each subinterval
    WHILE (@TruncatedStart < @TruncatedEnd)
    BEGIN
        INSERT @t
        (
            DisplayDate,
            StartDate,
            EndDate
        )
        VALUES
        (
            @TruncatedStart,
            @TruncatedStart,
            DATEADD(second, 1, @TruncatedStart)
        )

        SET @TruncatedStart =
            DATEADD(second, 1, @TruncatedStart)
    END

    RETURN
END
GO



--Get the time slices
SELECT *
FROM dbo.TimeSlice('2006-01-02 12:34:45.003', '2006-01-02 12:34:48.100')
GO



--Slice the overlaps?
SELECT
    Slices.DisplayDate
FROM
(
    SELECT MIN(StartTime), MAX(EndTime)
    FROM Overlap_Trace
) StartEnd (StartTime, EndTime)
CROSS APPLY
(
    SELECT *
    FROM dbo.TimeSlice(StartEnd.StartTime, StartEnd.EndTime)
) Slices
GO



--Find spikes using time slices
SELECT
    Slices.DisplayDate,
    OverLaps.thecount
FROM
(
    SELECT MIN(StartTime), MAX(EndTime)
    FROM Overlap_Trace
) StartEnd (StartTime, EndTime)
CROSS APPLY
(
    SELECT *
    FROM dbo.TimeSlice(StartEnd.StartTime, StartEnd.EndTime)
) Slices
CROSS APPLY
(
    SELECT COUNT(*) AS theCount
    FROM Overlap_Trace OT
    WHERE
        Slices.StartDate < OT.EndTime
        AND Slices.EndDate >  OT.StartTime
) Overlaps
GO



--Events table
CREATE TABLE Events
(
    EventId INT,
    StartTime DATETIME,
    DurationInMicroseconds INT
)
GO



/* 
//C# UDF for formatting durations

[Microsoft.SqlServer.Server.SqlFunction]
public static SqlString FormatDuration(SqlInt32 TimeInMicroseconds)
{
    //Ticks == Microseconds * 10
    //There are 10,000,000 ticks per second
    long ticks = TimeInMicroseconds.ToSqlInt64().Value * 10;

    //Create the TimeSpan based on the number of ticks
    TimeSpan ts = new TimeSpan(ticks);

    //Format the output
    return new SqlString(ts.ToString());
}
*/



--Table of transactions
CREATE TABLE Transactions
(
    TransactionId INT,
    Customer VARCHAR(50),
    TransactionDate DATETIME,
    TransactionType VARCHAR(50),
    TransactionAmount DECIMAL(9,2)
)
GO



--A transaction
INSERT Transactions
VALUES
(1001, 'Smith', '2005-06-12', 'DEPOSIT', 5000.00)
GO



--An offset transaction
INSERT Transactions
VALUES
(1001, 'Smith', '2005-06-12', 'OFFSET', -4500.00)
GO



--Should it be dated this way instead?
INSERT Transactions
VALUES
(1001, 'Smith', '2005-06-13', 'OFFSET', -4500.00)
GO



--A different table for transactions
CREATE TABLE Transactions
(
    TransactionId INT,
    Customer VARCHAR(50),
    TransactionDate DATETIME,
    TransactionType VARCHAR(50),
    TransactionAmount DECIMAL(9,2),
    ValidDate DATETIME
)
GO



--Insert the tran with a valid date
INSERT Transactions
VALUES
(1001, 'Smith', '2005-06-12', 'DEPOSIT', 5000.00, '2005-06-12')
GO



--Offset and record BOTH dates
INSERT Transactions
VALUES
(1001, 'Smith', '2005-06-12', 'DEPOSIT', 500.00, '2005-06-13')
GO



--Get a current version of the data
SELECT
    T1.TransactionId,
    T1.Customer,
    T1.TransactionType,
    T1.TransactionAmount
FROM Transactions AS T1
WHERE
    T1.TransactionDate = '2005-06-12'
    AND T1.ValidDate =
    (
        SELECT MAX(ValidDate)
        FROM Transactions AS T2
        WHERE T2.TransactionId = T1.TransactionId
    )
GO



--A snapshot
SELECT
    T1.TransactionId,
    T1.Customer,
    T1.TransactionType,
    T1.TransactionAmount
FROM Transactions AS T1
WHERE
    T1.TransactionDate = '2005-06-12'
    AND T1.ValidDate =
    (
        SELECT MAX(ValidDate)
        FROM Transactions AS T2
        WHERE
            T2.TransactionId = T1.TransactionId
            AND ValidDate <= '2005-06-12'
    )
GO



--Future data?
INSERT Transactions
VALUES
(1002, 'Smith', '2005-06-16', 'TRANSFER', -1000.00, '2005-06-14')
GO



