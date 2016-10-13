using System;
using System.Data;
using System.Data.SqlClient;
using System.Data.SqlTypes;
using Microsoft.SqlServer.Server;
using System.IO;
using System.Threading;
using ReadFileLines;

public partial class StoredProcedures
{
    [SqlProcedure]
    public static void CAS_Exception_v2()
    {
        SqlContext.Pipe.Send("Starting...");

        string[] theLines =
            FileLines.ReadFileLines(@"C:\b.txt");

        SqlContext.Pipe.Send("Finished...");

        return;
    }

    [SqlProcedure]
    public static void HPA_Exception()
    {
        SqlContext.Pipe.Send("Starting...");

        //The next line will throw a CAS exception...
        Monitor.Enter(SqlContext.Pipe);

        //Release the lock (if the code even gets here)...
        Monitor.Exit(SqlContext.Pipe);

        SqlContext.Pipe.Send("Finished...");

        return;
    }

};
