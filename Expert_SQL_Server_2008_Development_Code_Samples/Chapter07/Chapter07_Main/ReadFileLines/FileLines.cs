using System;
using System.Collections.Generic;
using System.Text;
using System.Security.Permissions;

/**************************
 * Uncomment this block if the assembly is strong named
 * 
 * 
[assembly: System.Security.AllowPartiallyTrustedCallers]
*/

namespace ReadFileLines
{
    public class FileLines
    {
        public static string[] ReadFileLines(string FilePath)
        {
            // Assert that anything File IO-related that this
            // assembly has permission to do, callers can do
            FileIOPermission fp = new FileIOPermission(
                PermissionState.Unrestricted);
            fp.Assert();

            List<string> theLines = new List<string>();

            using (System.IO.StreamReader sr =
                new System.IO.StreamReader(FilePath))
            {
                string line;
                while ((line = sr.ReadLine()) != null)
                    theLines.Add(line);
            }
            return (theLines.ToArray());
        }
    }
}
