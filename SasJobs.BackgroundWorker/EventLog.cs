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
    /// Represents a SAS Jobs event logger
    /// </summary>
    class EventLog : SasLog
    {
        /// <summary>
        /// Reference to client callback
        /// </summary>
        private ISasJobsServiceCallback callback { get; set; }

        /// <summary>
        /// The Id of the SAS job we are logging events from
        /// </summary>
        private Guid jobId { get; set; }

        /// <summary>
        /// Creates a SAS Jobs event logger
        /// </summary>
        /// <param name="callback">client callback reference</param>
        public EventLog(ISasJobsServiceCallback callback, Guid jobId)
        {
            this.callback = callback;
            this.jobId = jobId;
        }

        /// <summary>
        /// Default logging mechanism discards mesages
        /// </summary>
        /// <param name="message">The message</param>
        public override void Default(string message) { }

        /// <summary>
        /// Log a normal message, parsing event data
        /// </summary>
        /// <param name="message">The message</param>
        public override void Normal(string message)
        {
            message = message.Trim();
            if (message.StartsWith(":I:"))
            {
                int delim1 = ":I:".Length;
                int delim2 = message.IndexOf(',', delim1 + 1);
                int length2 = delim2 - delim1 - 1;
                string progress = message.Substring(delim1 + 1, length2);
                int percent = 0;
                int.TryParse(progress, out percent);
                string msg = message.Substring(delim2 + 1).Trim(new [] {'"'});

                // Report progress back to the client
                callback.OnProgress(new Messages.JobFeedback 
                { 
                    JobId = this.jobId,
                    PercentComplete = percent,
                    FeedbackMessage = msg,
                    Status = Messages.StatusCode.Running
                });

                Console.WriteLine(
                    String.Format(@"{0}% complete. {1}...", percent, msg));
            }            
        }      
    }
}
