using System;
using System.Data;
using System.Data.SqlClient;
using System.Data.SqlTypes;
using Microsoft.SqlServer.Server;
using System.Security.Permissions;
using System.Runtime.Serialization.Formatters.Binary;

public partial class serialization_helper
{
    public static byte[] getBytes(object o)
    {
        SecurityPermission sp =
            new SecurityPermission(
                SecurityPermissionFlag.SerializationFormatter);
        sp.Assert();

        BinaryFormatter bf = new BinaryFormatter();

        using (System.IO.MemoryStream ms =
            new System.IO.MemoryStream())
        {
            bf.Serialize(ms, o);

            return (ms.ToArray());
        }
    }

    public static object getObject(byte[] theBytes)
    {
        using (System.IO.MemoryStream ms =
            new System.IO.MemoryStream(theBytes, false))
        {
            return (getObject(ms));
        }
    }

    public static object getObject(System.IO.Stream s)
    {
        SecurityPermission sp =
            new SecurityPermission(
                SecurityPermissionFlag.SerializationFormatter);
        sp.Assert();

        BinaryFormatter bf = new BinaryFormatter();

        return (bf.Deserialize(s));
    }
};
