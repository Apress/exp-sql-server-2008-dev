using System;
using System.Collections.Generic;
using System.Text;
using System.Data.SqlTypes;
using System.Net;
using System.Data;
using System.Data.SqlClient;
using Microsoft.SqlServer.Server;
using System.Data.Sql;

namespace CLRTSQLComparison
{
  public partial class StoredProcedures
  {

    // SQLCLR -v- TSQL Performance Test #1
    // Create a "Simple Sieve" for prime numbers
    [SqlProcedure]
    public static void ListPrimes(SqlInt32 Limit)
    {
      int n = (int)Limit;
      int m = (int)Limit - 1;

      while (n > 1)
      {
        while (m > 0)
        {
          if (m == 1)
          {
            SqlContext.Pipe.Send(n.ToString() + " is a prime");
          }

          if (n % m != 0)
          {
            m = m - 1;
            continue;
          }
          else
          {
            break;
          }
        }
        n = n - 1;
        m = n - 1;
      }
    }

    // SQLCLR -v- TSQL Performance Test #2
    // Calculate Running Aggregates
    [Microsoft.SqlServer.Server.SqlProcedure]
    public static void RunningSum()
    {
      using (SqlConnection conn = new SqlConnection("context connection=true;"))
      {
        SqlCommand comm = new SqlCommand();
        comm.Connection = conn;
        comm.CommandText = "SELECT x FROM T ORDER BY x";

        SqlMetaData[] columns = new SqlMetaData[2];
        columns[0] = new SqlMetaData("Value", SqlDbType.Int);
        columns[1] = new SqlMetaData("RunningSum", SqlDbType.Int);

        int RunningSum = 0;

        SqlDataRecord record = new SqlDataRecord(columns);

        SqlContext.Pipe.SendResultsStart(record);

        conn.Open();

        SqlDataReader reader = comm.ExecuteReader();

        while (reader.Read())
        {
          int Value = (int)reader[0];
          RunningSum += Value;

          record.SetInt32(0, (int)reader[0]);
          record.SetInt32(1, RunningSum);

          SqlContext.Pipe.SendResultsRow(record);
        }

        SqlContext.Pipe.SendResultsEnd();
      }
    }

    // SQLCLR -v- TSQL Performance Test #3
    // Search for character in string
    [SqlProcedure]
    public static void SearchCharCLR(SqlString needle, SqlString haystack)
    {
      SqlContext.Pipe.Send(haystack.ToString().IndexOf(needle.ToString()).ToString());
    }
  }
}