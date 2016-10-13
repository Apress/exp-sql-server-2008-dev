using System;
using System.Collections.Generic;
using System.Text;
using Microsoft.SqlServer.Server;

public partial class StoredProcedures
{
  [Microsoft.SqlServer.Server.SqlProcedure]
  public static void NullComparison()
  {
    int? a = 10;
    int? b = null;
    if (a != b)
      SqlContext.Pipe.Send("test is true");
    else
      SqlContext.Pipe.Send("test is false");
  }
}
