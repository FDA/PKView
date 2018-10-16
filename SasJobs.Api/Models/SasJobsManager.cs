using System;
using System.Collections.Generic;
using System.Collections.Concurrent;
using System.Linq;
using System.Web;
using SasJobs.Messages;
using System.Threading.Tasks;
using SasJobs.Api.BackgroundWorker;
using System.ServiceModel;

namespace SasJobs.Api.Models
{
    /// <summary>
    /// Represents a SAS jobs store. This class cannot be inherited
    /// </summary>
    public sealed class SasJobsManager
    {
        /// <summary>
        /// Represents a SAS jobs service callback
        /// </summary>
        private sealed class SasJobsServiceCallback : ISasJobsServiceCallback
        {
            /// <summary>
            /// Occurs every time the execution of the job progresses
            /// </summary>
            /// <param name="feedback">Feedback data</param>
            public void OnProgress(Messages.JobFeedback feedback)
            {
                SasJobsManager.Current.OnProgress(feedback);
            }

            /// <summary>
            /// Occurs when the SAS job has finished executing
            /// </summary>
            /// <param name="feedback">Feedback data</param>
            /// <param name="xmlResult">the results in xml format</param>
            public void OnCompleted(Messages.JobFeedback feedback, string xmlResult)
            {
                SasJobsManager.Current.OnCompleted(feedback, xmlResult);
            }
        }

        /// <summary>
        /// Represents a SAS jobs service operation
        /// </summary>
        private sealed class SasJobsServiceOperation
        {
            /// <summary>
            /// Gets or sets the settings for the SAS job
            /// </summary>
            public JobSettings Settings { get; set; }

            /// <summary>
            /// Gets or sets the job feedback status
            /// </summary>
            public JobFeedback Feedback { get; set; }

            /// <summary>
            /// Gets or sets the result in xml format
            /// </summary>
            public string XmlResult { get; set; }

            /// <summary>
            /// Gets or sets the WCF client being used for this job
            /// </summary>
            public SasJobsServiceClient Client { get; set; }
        }

        private ConcurrentDictionary<Guid, SasJobsServiceOperation> operations;
        private readonly object operationsLock = new object();
        private static SasJobsManager current = new SasJobsManager();

        /// <summary>
        /// Gets the current store
        /// </summary>
        public static SasJobsManager Current
        {
            get { return current; }
        }

        /// <summary>
        /// Initializes a new instance of the object
        /// </summary>
        private SasJobsManager()
        {
            operations = new ConcurrentDictionary<Guid, SasJobsServiceOperation>();
        }

        /// <summary>
        /// Begin a SAS Job
        /// </summary>
        /// <param name="settings">SAS job settings</param>
        /// <returns>a unique GUID to reference the current job</returns>
        public Guid BeginJob(JobSettings settings)
        {
            lock (operationsLock)
            {
                Guid? existingJobId = null;
                Messages.StatusCode status = Messages.StatusCode.Undefined;

                // Find out if a job is already running with identical settings
                ParallelLoopResult result = Parallel.For(0, operations.Count, (i, loopState) =>
                {
                    // If the current element has identical settings
                    if (operations.ElementAt(i).Value.Settings.Equals(settings))
                    {
                        // Retrieve job status
                        if (operations.ElementAt(i).Value.Feedback != null)
                        {
                            status = operations.ElementAt(i).Value.Feedback.Status;
                        }
                        // Save the id of the job and break the parallel loop
                        existingJobId = operations.ElementAt(i).Key;
                        loopState.Break();
                    }
                });                                

                // If the parallel loop was forced to break and a job id was found
                // running or with successful completion status return it
                if (!result.IsCompleted && existingJobId != null)
                {
                    // Verify the status of the job
                    switch (status)
                    {
                        // If running or done return the job id
                        case StatusCode.Running: return existingJobId.Value; 
                        case StatusCode.Done: return existingJobId.Value; 

                        // Clear the aborted/ undefined state job but keep the Guid 
                        // in case status was not reported yet (recovery)
                        default:
                            settings.Id = existingJobId.Value; break;
                    }
                }
                else // Job doesnt exist
                {
                    do // generate a unique job id
                    {
                        settings.Id = Guid.NewGuid();
                    } while (settings.Id.Equals(Guid.Empty) || operations.ContainsKey(settings.Id));
                }

                // Create a new operation entry or overwrite an aborted/undefined one
                var newOperation = new SasJobsServiceOperation
                {
                    Client = new SasJobsServiceClient(new InstanceContext(new SasJobsServiceCallback())),
                    Settings = settings,
                    Feedback = new JobFeedback 
                    { 
                        Status = StatusCode.Running, 
                        PercentComplete = 0, 
                        FeedbackMessage = "Starting"
                    }
                };             
                operations.AddOrUpdate(settings.Id, newOperation, (id,o) => newOperation);

                // start a new job with the provided settings
                newOperation.Client.BeginJob(settings);

                return settings.Id;
            }
        }

        /// <summary>
        /// Get the SAS job progress
        /// </summary>
        /// <param name="id">job id</param>
        /// <returns>progress and feedback data</returns>
        public JobFeedback GetProgress(Guid id)
        {  
            // return error if key does not exist
            if (!operations.ContainsKey(id))
                return new JobFeedback
                {
                    PercentComplete = 100,
                    FeedbackMessage = "The specified job does not exist in the server",
                    Status = StatusCode.Aborted
                };

            // Try to get feedback 
            SasJobsServiceOperation operation = null;      
            if (operations.TryGetValue(id, out operation))
                return operation.Feedback;

            return null;
        }

        /// <summary>
        /// Get the SAS job results
        /// </summary>
        /// <param name="id">job id</param>
        /// <returns>an xml formatted string containing the result data</returns>
        public string GetResult(Guid id)
        {
            SasJobsServiceOperation operation = null;

            if (operations.TryGetValue(id, out operation))
                return operation.XmlResult;

            return null;            
        }

        /// <summary>
        /// Delete all completed operations from the cache
        /// </summary>
        /// <returns>true if all entries were removed successfully</returns>
        public bool DeleteCache()
        {
            bool success = true;

            lock (operationsLock)
            {
                // Get the keys of all non-running operations
                var finishedOperations = operations.Where(o => o.Value.Feedback.Status != StatusCode.Running);

                // Remove all of them
                SasJobsServiceOperation dummy;
                foreach (var operation in finishedOperations)
                    success &= operations.TryRemove(operation.Key, out dummy);

                return success;
            }
        }

        /// <summary>
        /// Occurs every time the execution of the job progresses
        /// </summary>
        /// <param name="feedback">Feedback data</param>
        private void OnProgress(Messages.JobFeedback feedback)
        {
            operations.AddOrUpdate(feedback.JobId, 
                new SasJobsServiceOperation { Feedback = feedback },
                (id, o) => { o.Feedback = feedback; return o; });
        }

        /// <summary>
        /// Occurs when the SAS job has finished executing
        /// </summary>
        /// <param name="feedback">Feedback data</param>
        /// <param name="xmlResult">the results in xml format</param>
        private void OnCompleted(Messages.JobFeedback feedback, string xmlResult)
        { 
            operations.AddOrUpdate(feedback.JobId, 
                new SasJobsServiceOperation { Feedback = feedback, XmlResult = xmlResult },
                (id, o) => { o.Feedback = feedback; o.XmlResult = xmlResult; return o; });

            SasJobsServiceOperation operation = null;
            if (operations.TryGetValue(feedback.JobId, out operation))
            {
                try
                {
                    operation.Client.Close();
                }
                catch
                {
                    operation.Client.Abort();
                }
            }
        }
    }
}