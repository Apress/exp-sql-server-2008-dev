using System;
using System.Data;
using System.Data.SqlClient;
using System.Data.SqlTypes;
using Microsoft.SqlServer.Server;
using System.Collections;
using System.Collections.Generic;
using TimeZoneSample;

public class TimeZoneData
{
    private static readonly Dictionary<int, TimeZoneInfo> timeZones = new Dictionary<int, TimeZoneInfo>();

    static TimeZoneData()
    {
        TimeZoneInfo[] tz =
            TimeZoneInfo.GetTimeZonesFromRegistry();

        foreach (TimeZoneInfo info in tz)
        {
            timeZones.Add(info.Index, info);
        }
    }

    [Microsoft.SqlServer.Server.SqlFunction(
        FillRowMethodName="FillZoneTable", 
        TableDefinition="TimeZoneName NVARCHAR(100), TimeZoneIndex INT")]
    public static IEnumerable GetTimeZoneIndexes()
    {
        return (timeZones.Values);
    }

    public static void FillZoneTable(
        object obj, 
        out SqlString TimeZoneName, 
        out SqlInt32 TimeZoneIndex)
    {
        TimeZoneInfo tz = (TimeZoneInfo)obj;
        TimeZoneName = new SqlString(tz.DisplayName);
        TimeZoneIndex = new SqlInt32(tz.Index);
    }

    public static DateTime TimeZoneToUtc(
        DateTime time,
        int TimeZoneIndex)
    {
        TimeZoneInfo tzInfo = null;

        try
        {
            tzInfo = timeZones[TimeZoneIndex];
        }
        catch (KeyNotFoundException e)
        {
            //do nothing
        }

        if (tzInfo != null)
        {
            DateTime convertedTime =
                TimeZoneInfo.ConvertTimeZoneToUtc(time, tzInfo);

            return (convertedTime);
        }
        else
        {
            throw (new ArgumentOutOfRangeException("TimeZoneIndex"));
        }
    }

    [Microsoft.SqlServer.Server.SqlFunction]
    public static SqlDateTime ConvertTimeZoneToUtc(
        SqlDateTime time,
        SqlInt32 TimeZoneIndex)
    {
        try
        {
            DateTime convertedTime =
                TimeZoneToUtc(time.Value, TimeZoneIndex.Value);

            return (new SqlDateTime(convertedTime));
        }
        catch (ArgumentOutOfRangeException e)
        {
            return (SqlDateTime.Null);
        }
    }

    public static DateTime UtcToTimeZone(
        DateTime time,
        int TimeZoneIndex)
    {
        TimeZoneInfo tzInfo = null;

        try
        {
            tzInfo = timeZones[TimeZoneIndex];
        }
        catch (KeyNotFoundException e)
        {
            //do nothing
        }

        if (tzInfo != null)
        {
            DateTime convertedTime =
                TimeZoneInfo.ConvertUtcToTimeZone(time, tzInfo);

            return (convertedTime);
        }
        else
        {
            throw (new ArgumentOutOfRangeException("TimeZoneIndex"));
        }
    }

    [Microsoft.SqlServer.Server.SqlFunction]
    public static SqlDateTime ConvertUtcToTimeZone(
        SqlDateTime time,
        SqlInt32 TimeZoneIndex)
    {
        try
        {
            DateTime convertedTime =
                UtcToTimeZone(time.Value, TimeZoneIndex.Value);

            return (new SqlDateTime(convertedTime));
        }
        catch (ArgumentOutOfRangeException e)
        {
            return (SqlDateTime.Null);
        }
    }

};

