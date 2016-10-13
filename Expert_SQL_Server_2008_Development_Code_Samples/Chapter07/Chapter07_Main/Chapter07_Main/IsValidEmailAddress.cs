using System;
using System.Data;
using System.Data.SqlClient;
using System.Data.SqlTypes;
using Microsoft.SqlServer.Server;
using Utils;

public partial class UserDefinedFunctions
{
    [Microsoft.SqlServer.Server.SqlFunction]
    public static SqlBoolean IsValidEmailAddress(
        SqlString emailAddress)
    {
        //Return NULL on NULL input
        if (emailAddress.IsNull)
            return (SqlBoolean.Null);

        bool isValid = UtilityMethods.IsValidEmailAddress(emailAddress.Value);
        return (new SqlBoolean(isValid));
    }
};

