using System;
using System.Data;
using System.Data.SqlClient;
using System.Data.SqlTypes;
using Microsoft.SqlServer.Server;
using System.Collections.Generic;

public partial class UserDefinedFunctions
{
    [Microsoft.SqlServer.Server.SqlFunction(
        DataAccess = DataAccessKind.Read)]
    public static SqlBytes GetBinaryFromQueryResult(string query)
    {
        List<object[]> theList = new List<object[]>();

        using (SqlConnection conn =
            new SqlConnection("context connection = true;"))
        {
            SqlCommand comm = new SqlCommand();
            comm.Connection = conn;
            comm.CommandText = query;

            conn.Open();

            SqlDataReader read = comm.ExecuteReader();

            DataTable dt = read.GetSchemaTable();

            //Populate the field list from the schema table
            object[] fields = new object[dt.Rows.Count];
            for (int i = 0; i < fields.Length; i++)
            {
                object[] field = new object[5];
                field[0] = dt.Rows[i]["ColumnName"];
                field[1] = dt.Rows[i]["ProviderType"];
                field[2] = dt.Rows[i]["ColumnSize"];
                field[3] = dt.Rows[i]["NumericPrecision"];
                field[4] = dt.Rows[i]["NumericScale"];

                fields[i] = field;
            }

            //Add the collection of fields to the output list
            theList.Add(fields);

            //Add all of the rows to the output list
            while (read.Read())
            {
                object[] o = new object[read.FieldCount];
                read.GetValues(o);
                theList.Add(o);
            }
        }

        //Serialize and return the output
        return new SqlBytes(
            serialization_helper.getBytes(theList.ToArray()));
    }
};

