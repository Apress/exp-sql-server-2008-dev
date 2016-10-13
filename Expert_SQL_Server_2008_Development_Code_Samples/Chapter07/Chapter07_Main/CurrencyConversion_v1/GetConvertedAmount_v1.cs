using System;
using System.Data;
using System.Data.SqlClient;
using System.Data.SqlTypes;
using Microsoft.SqlServer.Server;
using System.Collections.Generic;
using System.Threading;

  public class CurrencyConversion_v1
  {
    static readonly Dictionary<string, decimal>
        rates = new Dictionary<string, decimal>();

    static readonly ReaderWriterLock
        rwl = new ReaderWriterLock();

    static CurrencyConversion_v1()
    {
      // Put some dummy exchange rates into the dictionary
      rates.Add("GBP", 1m);
      rates.Add("USD", 1.63380m);
    }

    [SqlFunction]
    public static SqlDecimal GetConvertedAmount_v1(
        SqlDecimal InputAmount,
        SqlString InCurrency,
        SqlString OutCurrency)
    {
      //Convert the input amount to the base
      decimal BaseAmount =
         GetRate(InCurrency.Value) *
         InputAmount.Value;

      //Return the converted base amount
      return (new SqlDecimal(
         GetRate(OutCurrency.Value) * BaseAmount));
    }

    private static decimal GetRate(string Currency)
    {
      decimal theRate;
      rwl.AcquireReaderLock(100);

      try
      {
        theRate = rates[Currency];
      }
      finally
      {
        rwl.ReleaseLock();
      }

      return (theRate);
    }

};

