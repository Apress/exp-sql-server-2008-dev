using System;
using System.Data;
using System.Data.SqlClient;
using System.Data.SqlTypes;
using Microsoft.SqlServer.Server;

public partial class UserDefinedFunctions
{
    [Microsoft.SqlServer.Server.SqlFunction(
        DataAccess = DataAccessKind.Read)]
    public static SqlBytes GetDataTable_Binary(string query)
    {
        SqlConnection conn =
            new SqlConnection("context connection = true;");

        SqlCommand comm = new SqlCommand();
        comm.Connection = conn;
        comm.CommandText = query;

        SqlDataAdapter da = new SqlDataAdapter();
        da.SelectCommand = comm;

        DataTable dt = new DataTable();
        da.Fill(dt);

        /**********************
         * Uncomment this block for better performance
         * 
         * 
        dt.RemotingFormat = SerializationFormat.Binary;
         */

        //Serialize and return the output
        return new SqlBytes(
            serialization_helper.getBytes(dt));
    }
};

