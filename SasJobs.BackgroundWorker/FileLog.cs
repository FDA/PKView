using SasJobs.Bridge;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace SasJobs.BackgroundWorker
{
    /// <summary>
    /// Represents a SAS Jobs logger
    /// </summary>
    class FileLog : SasLog, IDisposable
    {
        /// <summary>
        /// Gets or sets the file stream writer
        /// </summary>
        private StreamWriter file { get; set; }

        /// <summary>
        /// Create a file logger
        /// </summary>
        /// <param name="path">path to the log file</param>
        public FileLog(string path)
        {
            // Make sure folder exists
            var folder = new FileInfo(path).DirectoryName;
            if (!Directory.Exists(folder))
                Directory.CreateDirectory(folder);

            // Avoid the rare case of name collision
            string filePath = path;
            int c = 0;
            while (File.Exists(filePath))
            {
                filePath = path + '_' + c;
                c++;
            }

            file = new StreamWriter(filePath);
            file.AutoFlush = true;
        }

        /// <summary>
        /// Log an information message
        /// </summary>
        /// <param name="message">The message</param>
        public override void Default(string message)
        {
            file.WriteLine("INFO: " + message);
        }

        /// <summary>
        /// Log a warning message
        /// </summary>
        /// <param name="message">The message</param>
        public override void Warning(string message)
        {
            file.WriteLine("WARNING: " + message);
        }

        /// <summary>
        /// Log an error message
        /// </summary>
        /// <param name="message">The message</param>
        public override void Error(string message)
        {
            file.WriteLine("ERROR: " + message);
        }

        public void Dispose()
        {
            file.Close();
        }
    }
}
