using SasJobs.Messages;
using System;
using System.ServiceModel;

namespace SasJobs.BackgroundWorker
{
    /// <summary>
    /// Allows executing sas jobs
    /// </summary>
    [ServiceContract(SessionMode = SessionMode.Required, CallbackContract = typeof(ISasJobsServiceCallback))]
    public interface ISasJobsService
    {
        /// <summary>
        /// Begin executing a SAS job and return the job id
        /// </summary>
        /// <param name="settings">SAS job settings</param>
        [OperationContract(IsOneWay=true)]
        void BeginJob(JobSettings settings);
    }
}
