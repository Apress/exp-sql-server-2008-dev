using System;
using System.Data;
using System.Data.SqlClient;
using System.Data.SqlTypes;
using Microsoft.SqlServer.Server;

public partial class StoredProcedures
{
    [Microsoft.SqlServer.Server.SqlProcedure]
    public static void GetTableFromBinary(SqlBytes theTable)
    {
        //Deserialize the input
        object[] dt = (object[])(
            serialization_helper.getObject(theTable.Value));

        //First, get the fields
        object[] fields = (object[])(dt[0]);
        SqlMetaData[] cols = new SqlMetaData[fields.Length];

        //Loop over the fields and populate SqlMetaData objects
        for (int i = 0; i<fields.Length; i++)
        {
            object[] field = (object[])(fields[i]);
            SqlDbType dbType = (SqlDbType)field[1];

                    //Different SqlMetaData overloads are required
            //depending on the data type
            switch (dbType)
            {
                case SqlDbType.Decimal:
                    cols[i] = new SqlMetaData(
                        (string)field[0],
                        dbType,
                        (byte)field[3],
                        (byte)field[4]);
                    break;
                case SqlDbType.Binary:
                case SqlDbType.Char:
                case SqlDbType.NChar:
                case SqlDbType.NVarChar:
                case SqlDbType.VarBinary:
                case SqlDbType.VarChar:
                    switch ((int)field[2])
                    {
                        //If it's a MAX type, use -1 as the size
                        case 2147483647:
                            cols[i] = new SqlMetaData(
                                (string)field[0],
                                dbType,
                                -1);
                            break;
                        default:
                            cols[i] = new SqlMetaData(
                                (string)field[0],
                                dbType,
                                (long)((int)field[2]));
                            break;
                    }
                    break;
                default:
                    cols[i] = new SqlMetaData(
                        (string)field[0],
                        dbType);
                    break;
            }
        }

        //Start the result stream
        SqlDataRecord rec = new SqlDataRecord(cols);
        SqlContext.Pipe.SendResultsStart(rec);

        for (int i = 1; i < dt.Length; i++)
        {
            rec.SetValues((object[])dt[i]);
            SqlContext.Pipe.SendResultsRow(rec);
        }

        //End the result stream
        SqlContext.Pipe.SendResultsEnd();
    }
};
