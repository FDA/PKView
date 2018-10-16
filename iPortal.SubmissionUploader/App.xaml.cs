using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;

namespace iPortal.SubmissionUploader
{
    /// <summary>
    /// Interaction logic for App.xaml
    /// </summary>
    public partial class App : Application
    {
        /// <summary>
        /// Get the server name to upload to based on the target environment variable
        /// </summary>
        public static string AppServerName
        {
            get
            {               
                return "localhost";
            }
        }
    }
}
