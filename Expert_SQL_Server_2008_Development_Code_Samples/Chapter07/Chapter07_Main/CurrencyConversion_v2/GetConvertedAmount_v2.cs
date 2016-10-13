using System;
using System.Data;
using System.Data.SqlClient;
using System.Data.SqlTypes;
using Microsoft.SqlServer.Server;
using SafeDictionary;

public class CurrencyConversion_v2
{
  static readonly ThreadSafeDictionary<string, decimal> rates_v2 =
        new ThreadSafeDictionary<string, decimal>();

  static CurrencyConversion_v2()
    {
      // Put some dummy exchange rates into the dictionary
      rates_v2.Add("GBP", 1m);
      rates_v2.Add("USD", 1.63380m);
    }

    [SqlFunction]
    public static SqlDecimal GetConvertedAmount_v2(
        SqlDecimal InputAmount,
        SqlString InCurrency,
        SqlString OutCurrency)
    {
        //Convert the input amount to the base
        decimal BaseAmount =
           GetRate_v2(InCurrency.Value) *
           InputAmount.Value;

        //Return the converted base amount
        return (new SqlDecimal(
           GetRate_v2(OutCurrency.Value) * BaseAmount));
    }

    private static decimal GetRate_v2(string Currency)
    {
      return (rates_v2[Currency]);
    }
};

