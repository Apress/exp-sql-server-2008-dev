--Implied contract?
CREATE PROCEDURE GetAggregateTransactionHistory
    @CustomerId INT
AS
BEGIN
    SET NOCOUNT ON

    SELECT
        SUM
        (
            CASE TransactionType
                WHEN 'Deposit' THEN Amount
                ELSE 0
            END
        ) AS TotalDeposits,
        SUM
        (
            CASE TransactionType
                WHEN 'Withdrawal' THEN Amount
                ELSE 0
            END
        ) AS TotalWithdrawals
    FROM TransactionHistory
    WHERE
        CustomerId = @CustomerId
END
GO



--A slightly different implied contract
CREATE PROCEDURE GetAggregateTransactionHistory
    @CustomerId INT
AS
BEGIN
    SET NOCOUNT ON

    SELECT
        SUM
        (
            CASE TH.TransactionType
                WHEN 'Deposit' THEN TH.Amount
                ELSE 0
            END
        ) AS TotalDeposits,
        SUM
        (
            CASE TH.TransactionType
                WHEN 'Withdrawal' THEN TH.Amount
                ELSE 0
            END
        ) AS TotalWithdrawals
    FROM Customers AS C
    LEFT JOIN TransactionHistory AS TH ON C.CustomerId = TH.CustomerId
    WHERE
        C.CustomerId = @CustomerId
END
GO



/*
//C# NUnit test for these stored procedures
[TestMethod]
public void TestAggregateTransactionHistory()
{
    //Set up a command object
    SqlCommand comm = new SqlCommand();

    //Set up the connection
    comm.Connection = new SqlConnection(
        @"server=serverName; trusted_connection=true;");

    //Define the procedure call
    comm.CommandText = "GetAggregateTransactionHistory";
    comm.CommandType = CommandType.StoredProcedure;

    comm.Parameters.AddWithValue("@CustomerId", 123);

    //Create a DataSet for the results
    DataSet ds = new DataSet();

    //Define a DataAdapter to fill a DataSet
    SqlDataAdapter adapter = new SqlDataAdapter();
    adapter.SelectCommand = comm;

    try
    {
        //Fill the dataset
        adapter.Fill(ds);
    }
    catch
    {
        Assert.Fail("Exception occurred!");
    }

    //Now we have the results -- validate them...

    //There must be exactly one returned result set
    Assert.IsTrue(
        ds.Tables.Count == 1,
        "Result set count != 1");

    DataTable dt = ds.Tables[0];

    //There must be exactly two columns returned
    Assert.IsTrue(
        dt.Columns.Count == 2,
        "Column count != 2");

    //There must be columns called TotalDeposits and TotalWithdrawals
    Assert.IsTrue(
        dt.Columns.IndexOf("TotalDeposits") > -1,
        "Column TotalDeposits does not exist");

    Assert.IsTrue(
        dt.Columns.IndexOf("TotalWithdrawals") > -1,
        "Column TotalWithdrawals does not exist");

    //Both columns must be decimal
    Assert.IsTrue(
        dt.Columns["TotalDeposits"].DataType == typeof(decimal),
        "TotalDeposits data type is incorrect");

    Assert.IsTrue(
        dt.Columns["TotalWithdrawals"].DataType == typeof(decimal),
        "TotalWithdrawals data type is incorrect");

    //There must be zero or one rows returned
    Assert.IsTrue(
        dt.Rows.Count <= 1,
        "Too many rows returned");
}
*/


