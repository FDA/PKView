using SasJobs.Messages;
using System.ServiceModel;

namespace SasJobs.BackgroundWorker
{
    /// <summary>
    /// Provides a set of callbacks for <see cref="SasJobs.BackgroundWorker.ISasJobsService"/>
    /// </summary>
    public interface ISasJobsServiceCallback
    {
        /// <summary>
        /// Occurs every time the SAS job progresses
        /// </summary>
        /// <param name="feedback">Job status feedback</param>
        [OperationContract(IsOneWay = true)]
        void OnProgress(JobFeedback feedback);

        /// <summary>
        /// Occurs when the SAS job has finished executing
        /// </summary>
        /// <param name="feedback">Job status feedback</param>
        /// <param name="xmlResult">Xml data returned by the SAS job</param>
        [OperationContract(IsOneWay = true)]
        void OnCompleted(JobFeedback feedback, string xmlResult);
    }
}
