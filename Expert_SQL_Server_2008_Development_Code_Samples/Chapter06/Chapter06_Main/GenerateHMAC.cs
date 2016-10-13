using System;
using System.Collections.Generic;
using System.Text;
using System.Security.Cryptography;
using System.Security.Permissions;
using System.Runtime.Serialization.Formatters.Binary;
using Microsoft.SqlServer.Server;
using System.Data.Sql;
using System.Data.SqlTypes;

namespace Chapter06_Main
{
  public partial class UserDefinedFunctions
  {
    [SqlFunction(IsDeterministic = true, DataAccess = DataAccessKind.None)]
    public static SqlBytes GenerateHMAC
    (
      SqlString Algorithm,
      SqlBytes PlainText,
      SqlBytes Key
    )
    {
      if (Algorithm.IsNull || PlainText.IsNull || Key.IsNull)
      {
        return SqlBytes.Null;
      }
      HMAC HMac = null;
      switch (Algorithm.Value)
      {
        case "MD5":
          HMac = new HMACMD5(Key.Value);
          break;
        case "SHA1":
          HMac = new HMACSHA1(Key.Value);
          break;
        case "SHA256":
          HMac = new HMACSHA256(Key.Value);
          break;
        case "SHA384":
          HMac = new HMACSHA384(Key.Value);
          break;
        case "SHA512":
          HMac = new HMACSHA512(Key.Value);
          break;
        case "RIPEMD160":
          HMac = new HMACRIPEMD160(Key.Value);
          break;
        default:
          throw new Exception("Hash algorithm not recognised");
      }
      byte[] HMacBytes = HMac.ComputeHash(PlainText.Value);
      return new SqlBytes(HMacBytes);
    }
  }
}
