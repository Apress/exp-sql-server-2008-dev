using System;
using System.Collections.Generic;
using System.Text;
using System.Text.RegularExpressions;

namespace Utils
{
    public class UtilityMethods
    {
        public static bool IsValidEmailAddress(string emailAddress)
        {
            //Validate the e-mail address
            Regex r =
                new Regex(@"\w+([-+.]\w+)*@\w+([-.]\w+)*\.\w+([-.]\w+)*");

            return (r.IsMatch(emailAddress));
        }
    }
}
