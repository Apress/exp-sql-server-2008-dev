using System;
using System.Collections;
using System.Text;
using System.Globalization;
using Microsoft.Win32;

namespace TimeZoneSample {


    // Container for time zone information
    public class TimeZoneInfo {

        private String m_displayName;
        private String m_standardName;
        private String m_daylightName;
        private Int32 m_index;
        private Boolean m_supportsDst;
        private TimeSpan m_bias;
        private TimeSpan m_daylightBias;
        private DateTime m_standardTransitionTimeOfDay;
        private Int32 m_standardTransitionMonth;
        private Int32 m_standardTransitionWeek;
        private Int32 m_standardTransitionDayOfWeek;
        private DateTime m_daylightTransitionTimeOfDay;
        private Int32 m_daylightTransitionMonth;
        private Int32 m_daylightTransitionWeek;
        private Int32 m_daylightTransitionDayOfWeek;

        private TimeZoneInfo() {
        }

        public override string ToString() {
            return DisplayName;
        }

        public String DisplayName {
            get {
                return m_displayName;
            }
        }

        public String StandardName {
            get {
                return m_standardName;
            }
        }

        public String DaylightName {
            get {
                return m_daylightName;
            }
        }

        public Int32 Index {
            get {
                return m_index;
            }
        }

        public Boolean SupportsDaylightSavings {
            get {
                return m_supportsDst;
            }
        }

        public TimeSpan Bias {
            get {
                return m_bias;
            }
        }

        public TimeSpan DaylightBias {
            get {
                return m_daylightBias;
            }
        }

        public DateTime StandardTransitionTimeOfDay {
            get {
                return m_standardTransitionTimeOfDay;
            }
        }

        public Int32 StandardTransitionMonth {
            get {
                return m_standardTransitionMonth;
            }
        }

        public Int32 StandardTransitionWeek {
            get {
                return m_standardTransitionWeek;
            }
        }

        public Int32 StandardTransitionDayOfWeek {
            get {
                return m_standardTransitionDayOfWeek;
            }
        }


        public DateTime DaylightTransitionTimeOfDay {
            get {
                return m_daylightTransitionTimeOfDay;
            }
        }

        public Int32 DaylightTransitionMonth {
            get {
                return m_daylightTransitionMonth;
            }
        }


        public Int32 DaylightTransitionWeek {
            get {
                return m_daylightTransitionWeek;
            }
        }

        public Int32 DaylightTransitionDayOfWeek {
            get {
                return m_daylightTransitionDayOfWeek;
            }
        }



        public static TimeZoneInfo[] GetTimeZonesFromRegistry() {

            ArrayList timeZoneList = new ArrayList();

            // Extract the information from the registry into an arraylist.
            String timeZoneKeyPath = "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Time Zones";
            using (RegistryKey timeZonesKey = Registry.LocalMachine.OpenSubKey(timeZoneKeyPath)) {
                String[] zoneKeys = timeZonesKey.GetSubKeyNames();
                Int32 zoneKeyCount = zoneKeys.Length;
                for (Int32 i = 0; i < zoneKeyCount; i++) {
                    using (RegistryKey timeZoneKey = timeZonesKey.OpenSubKey(zoneKeys[i])) {
                        TimeZoneInfo newTimeZone = new TimeZoneInfo();
                        newTimeZone.m_displayName = (String)timeZoneKey.GetValue("Display");
                        newTimeZone.m_daylightName = (String)timeZoneKey.GetValue("Dlt");
                        newTimeZone.m_standardName = (String)timeZoneKey.GetValue("Std");
                        newTimeZone.m_index = (Int32)timeZoneKey.GetValue("Index");
                        Byte[] bytes = (Byte[])timeZoneKey.GetValue("TZI");
                        newTimeZone.m_bias = new TimeSpan(0, BitConverter.ToInt32(bytes, 0), 0);
                        newTimeZone.m_daylightBias = new TimeSpan(0, BitConverter.ToInt32(bytes, 8), 0);
                        newTimeZone.m_standardTransitionMonth = BitConverter.ToInt16(bytes, 14);
                        newTimeZone.m_standardTransitionDayOfWeek = BitConverter.ToInt16(bytes, 16);
                        newTimeZone.m_standardTransitionWeek = BitConverter.ToInt16(bytes, 18);
                        newTimeZone.m_standardTransitionTimeOfDay = new DateTime(1, 1, 1,
                                                                    BitConverter.ToInt16(bytes, 20),
                                                                    BitConverter.ToInt16(bytes, 22),
                                                                    BitConverter.ToInt16(bytes, 24),
                                                                    BitConverter.ToInt16(bytes, 26));
                        newTimeZone.m_daylightTransitionMonth = BitConverter.ToInt16(bytes, 30);
                        newTimeZone.m_daylightTransitionDayOfWeek = BitConverter.ToInt16(bytes, 32);
                        newTimeZone.m_daylightTransitionWeek = BitConverter.ToInt16(bytes, 34);
                        newTimeZone.m_daylightTransitionTimeOfDay = new DateTime(1, 1, 1,
                                                                    BitConverter.ToInt16(bytes, 36),
                                                                    BitConverter.ToInt16(bytes, 38),
                                                                    BitConverter.ToInt16(bytes, 40),
                                                                    BitConverter.ToInt16(bytes, 42));
                        newTimeZone.m_supportsDst = (newTimeZone.m_standardTransitionMonth != 0);
                        timeZoneList.Add(newTimeZone);
                    }
                }
            }
            // Put the time zone infos into an array and sort them by the Index Property
            TimeZoneInfo[] timeZoneInfos = new TimeZoneInfo[timeZoneList.Count];
            Int32[] timeZoneOrders = new Int32[timeZoneList.Count];
            for (Int32 i = 0; i < timeZoneList.Count; i++) {
                TimeZoneInfo zoneInfo = (TimeZoneInfo)timeZoneList[i]; 
                timeZoneInfos[i] = zoneInfo;
                timeZoneOrders[i] = zoneInfo.Index;
            }
            Array.Sort(timeZoneOrders, timeZoneInfos);

            return timeZoneInfos;
        }

        private static DateTime GetRelativeDate(int year, int month, int targetDayOfWeek, int numberOfSundays) {
            DateTime time;

            if (numberOfSundays <= 4) {
                //
                // Get the (numberOfSundays)th Sunday.
                //
                time = new DateTime(year, month, 1);

                int dayOfWeek = (int)time.DayOfWeek;
                int delta = targetDayOfWeek - dayOfWeek;
                if (delta < 0) {
                    delta += 7;
                }
                delta += 7 * (numberOfSundays - 1);

                if (delta > 0) {
                    time = time.AddDays(delta);
                }
            }
            else {
                //
                // If numberOfSunday is greater than 4, we will get the last sunday.
                //
                Int32 daysInMonth = DateTime.DaysInMonth(year, month);
                time = new DateTime(year, month, daysInMonth);
                // This is the day of week for the last day of the month.
                int dayOfWeek = (int)time.DayOfWeek;
                int delta = dayOfWeek - targetDayOfWeek;
                if (delta < 0) {
                    delta += 7;
                }

                if (delta > 0) {
                    time = time.AddDays(-delta);
                }
            }
            return time;
        }

        private static DaylightTime GetDaylightTime(Int32 year, TimeZoneInfo zone) {
            TimeSpan delta = zone.DaylightBias;
            DateTime startTime = GetRelativeDate(year, zone.DaylightTransitionMonth, zone.DaylightTransitionDayOfWeek, zone.DaylightTransitionWeek);
            startTime = startTime.AddTicks(zone.DaylightTransitionTimeOfDay.Ticks);
            DateTime endTime = GetRelativeDate(year, zone.StandardTransitionMonth, zone.StandardTransitionDayOfWeek, zone.StandardTransitionWeek);
            endTime = endTime.AddTicks(zone.StandardTransitionTimeOfDay.Ticks);
            return new DaylightTime(startTime, endTime, delta);
        }

        public static Boolean GetIsDalightSavingsFromLocal(DateTime time, TimeZoneInfo zone) {
            if (!zone.SupportsDaylightSavings) {
                return false;
            }
            DaylightTime daylightTime = GetDaylightTime(time.Year, zone);

            // startTime and endTime represent the period from either the start of DST to the end and includes the 
            // potentially overlapped times
            DateTime startTime = daylightTime.Start - zone.DaylightBias;
            DateTime endTime = daylightTime.End;

            Boolean isDst = false;
            if (startTime > endTime) {
                // In southern hemisphere, the daylight saving time starts later in the year, and ends in the beginning of next year.
                // Note, the summer in the southern hemisphere begins late in the year.
                if (time >= startTime || time < endTime) {
                    isDst = true;
                }
            }
            else if (time>=startTime && time < endTime) {
                // In northern hemisphere, the daylight saving time starts in the middle of the year.
                isDst = true;
            }

            return isDst;
        }

        public static Boolean GetIsDalightSavingsFromUtc(DateTime time, TimeZoneInfo zone) {
            if (!zone.SupportsDaylightSavings) {
                return false;
            }

            // Get the daylight changes for the year of the specified time.
            TimeSpan offset = -zone.Bias;
            DaylightTime daylightTime = GetDaylightTime(time.Year, zone);

            // The start and end times represent the range of universal times that are in DST for that year.                
            // Within that there is an ambiguous hour, usually right at the end, but at the beginning in
            // the unusual case of a negative daylight savings delta.
            DateTime startTime = daylightTime.Start - offset;
            DateTime endTime = daylightTime.End - offset + zone.DaylightBias;

            Boolean isDst = false;
            if (startTime > endTime) {
                // In southern hemisphere, the daylight saving time starts later in the year, and ends in the beginning of next year.
                // Note, the summer in the southern hemisphere begins late in the year.
                isDst = (time < endTime || time >= startTime);
            }
            else {
                // In northern hemisphere, the daylight saving time starts in the middle of the year.
                isDst = (time >= startTime && time < endTime);
            }
            return isDst;
        }

        public static TimeSpan GetUtcOffsetFromLocal(DateTime time, TimeZoneInfo zone) {
            TimeSpan baseOffset = -zone.Bias;
            Boolean isDaylightSavings = GetIsDalightSavingsFromLocal(time, zone);
            TimeSpan finalOffset = baseOffset -= (isDaylightSavings ? zone.DaylightBias : TimeSpan.Zero);
            return baseOffset;
        }

        public static TimeSpan GetUtcOffsetFromUtc(DateTime time, TimeZoneInfo zone) {
            TimeSpan baseOffset = -zone.Bias;
            Boolean isDaylightSavings = GetIsDalightSavingsFromUtc(time, zone);
            TimeSpan finalOffset = baseOffset -= (isDaylightSavings ? zone.DaylightBias : TimeSpan.Zero);
            return baseOffset;
        }


        public static DateTime ConvertTimeZoneToUtc(DateTime time, TimeZoneInfo zone) {
            TimeSpan offset = GetUtcOffsetFromLocal(time, zone);
            DateTime utcConverted = new DateTime(time.Ticks - offset.Ticks);
            return utcConverted;
        }

        public static DateTime ConvertUtcToTimeZone(DateTime time, TimeZoneInfo zone) {
            TimeSpan offset = GetUtcOffsetFromUtc(time, zone);
            DateTime localConverted = new DateTime(time.Ticks + offset.Ticks);
            return localConverted;
        }

        public static DateTime ConvertTimeZoneToTimeZone(DateTime time, TimeZoneInfo zoneSource, TimeZoneInfo zoneDestination) {
            DateTime utcConverted = ConvertTimeZoneToUtc(time, zoneSource);
            DateTime localConverted = ConvertUtcToTimeZone(utcConverted, zoneDestination);
            return localConverted;
        }

    }

}
