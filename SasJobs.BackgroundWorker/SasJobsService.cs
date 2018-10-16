using SasJobs.Bridge;
using System;
using System.Collections.Generic;
using System.Linq;
using System.ServiceModel;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace SasJobs.BackgroundWorker
{
    /// <summary>
    /// Represents a SAS jobs service
    /// </summary>
    [ServiceBehavior(InstanceContextMode = InstanceContextMode.PerSession)]
    public class SasJobsService: ISasJobsService
    {
        /// <summary>
        /// Gets the client callback
        /// </summary>
        private ISasJobsServiceCallback callback { get; set; }

        /// <summary>
        /// Gets or sets the SAS code execution bridge
        /// </summary>
        private ISasBridge bridge { get; set; }

        /// <summary>
        /// Gets or sets the job settings
        /// </summary>
        private Messages.JobSettings settings { get; set; }

        /// <summary>
        /// Gets the path were log files will be stored
        /// </summary>
        private string logPath { get { return SasBridge.SasServicePath + "\\Logs\\SAS"; } }

        /// <summary>
        /// Gets or sets the event logger
        /// </summary>
        private ISasLog eventLog { get; set; }

        /// <summary>
        /// Gets or sets the internal helper timer
        /// </summary>
        private TimerHelper myTimer { get; set; }

        /// <summary>
        /// Gets or sets the execution time stopwatch
        /// </summary>
        private System.Diagnostics.Stopwatch myStopwatch { get; set; }

        /// <summary>
        /// Creates a SAS Jobs Service
        /// </summary>
        public SasJobsService()
        {
            this.callback = OperationContext.Current.
                GetCallbackChannel<ISasJobsServiceCallback>();    
        }      

        /// <summary>
        /// Begins executing a SAS Job
        /// </summary>
        /// <param name="settings"></param>
        public void BeginJob(Messages.JobSettings settings)
        {
            // Timer cleanup if needed
            if (myTimer != null)
            {
                myTimer.Dispose();
                myTimer = null;
            }

            this.eventLog = new EventLog(this.callback, settings.Id);

            Console.WriteLine("Starting job..");
            this.myStopwatch = System.Diagnostics.Stopwatch.StartNew();

            this.bridge = new SasBridge();
            ((SasBridge)this.bridge).Events.Done += this.JobFinished;
            ((SasBridge)this.bridge).Events.Error += this.JobError;

            this.settings = settings;
            this.myTimer = new TimerHelper();
            this.myTimer.TimerEvent += (timer, state) => this.doBeginJob();
            this.myTimer.Start(TimeSpan.FromSeconds(10), true);

            this.callback.OnProgress(new Messages.JobFeedback 
            {
                JobId = this.settings.Id,
                PercentComplete = 1,
                FeedbackMessage = "Starting Job on server",
                Status = Messages.StatusCode.Running
            });
        }


        private void doBeginJob()
        {
            bool success = this.bridge.RunProcedure(settings.ProcedureName, settings.XmlInputData, settings.XmlMap);

            if (success)
            {
                this.myTimer.ClearEvents();
                this.myTimer.TimerEvent += (timer, state) => this.logEvents();
                this.myTimer.Change(TimeSpan.FromSeconds(5), true);
            }
            else
            {
                Console.WriteLine("job " + this.settings.Id + " attempted to get a slot.");
                this.callback.OnProgress(new Messages.JobFeedback
                {
                    JobId = this.settings.Id,
                    PercentComplete = 2,
                    FeedbackMessage = "Waiting for a server slot to become available",
                    Status = Messages.StatusCode.Running
                });
            }
        }

        /// <summary>
        /// Forwards feedback events from the list output to the
        /// event logger.This is triggered at regular intervals
        /// by the internal timer
        /// </summary>
        private void logEvents()
        {
            this.bridge.FlushList(eventLog);
        }

        /// <summary>
        /// Handle Job finalization event. Stops the execution stopwatch
        /// and prepares for cleanup after a one second timer.
        /// </summary>
        /// <remarks>
        /// Cleanup cannot happen at this time because both attempting to
        /// unsubscribe from the SAS IT COM events and attempting to
        /// return the workspace to the pool will produce an exception
        /// that is silently handled and discarded by the SAS IT assembly
        /// </remarks>
        /// <param name="rc"></param>
        private void JobFinished(int rc)
        {
            this.myTimer.ClearEvents();
            Console.WriteLine("Code finished executing successfully");
            Console.WriteLine("Retrieving results");
            
            string xmlResult = this.bridge.GetResult();
            //string xmlResult = null;
            Console.WriteLine("Successfully retrieved  output data");

            this.callback.OnCompleted(new Messages.JobFeedback
            {
                JobId = this.settings.Id,
                PercentComplete = 100,
                FeedbackMessage = "Task completed successfully",
                Status = Messages.StatusCode.Done
            }, xmlResult);

            // SAS job log, rotate folder every day
            using (FileLog jobLog = new FileLog(String.Format(
                @"{0}\{1}\sasjob_{2}_{3}.log", this.logPath, 
                DateTime.Now.ToString("yyyy-MM-dd"),
                DateTime.Now.ToString("HHmmssffff"),
                this.settings.ProcedureName)))
            {
                int numLines = 0;
                do
                {
                    numLines = this.bridge.FlushLog(jobLog);
                } while (numLines > 0);
            }


            this.FinalizeJob();
        }

        /// <summary>
        /// Handles an error in the SAS Job, generating a dump file
        /// with the full sas log and informing the client
        /// </summary>
        private void JobError()
        {
            this.myTimer.ClearEvents();
            Console.WriteLine("Sas Error Occurred");

            // Save the error log, rotate folder every day
            using (FileLog errorLog = new FileLog(String.Format(
                @"{0}\{1}\error_{2}_{3}.log", this.logPath,
                DateTime.Now.ToString("yyyy-MM-dd"),
                DateTime.Now.ToString("HHmmssffff"),
                settings.ProcedureName)))
            {
                int numLines = 0;
                do
                {
                    numLines = this.bridge.FlushLog(errorLog);
                } while (numLines > 0);
            }
            
            this.callback.OnCompleted(new Messages.JobFeedback
            {
                JobId = this.settings.Id,
                PercentComplete = 100,
                FeedbackMessage = "An error occurred and an error trace log " +
                "has been generated for our staff to review. Should you " +
                "have any questions or concerns, feel free to contact us.",
                Status = Messages.StatusCode.Aborted
            }, null);

            this.FinalizeJob();
        }

        /// <summary>
        /// Job finalization routine
        /// </summary>
        private void FinalizeJob()
        {            
            this.myTimer.TimerEvent += (timer, state) => this.CloseBridge();
            this.myTimer.Change(TimeSpan.FromSeconds(1));
            myStopwatch.Stop();
            Console.WriteLine(myStopwatch.Elapsed.TotalSeconds + " seconds elapsed");
        }

        /// <summary>
        /// Close the sas bridge and release the associated resources
        /// </summary>
        private void CloseBridge()
        {
            this.bridge.Release();            
            this.bridge = null;
            Console.WriteLine("Workspace Freed");

            this.myTimer.Stop();
            this.myTimer = null;
        }
    }
}
