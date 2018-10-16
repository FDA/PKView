using System;
using System.Runtime.Serialization;

namespace SasJobs.Messages
{
    /// <summary>
    /// Represents the current status of a running SAS job
    /// </summary>
    [DataContract]
    public class JobFeedback
    {
        /// <summary>
        /// Gets or sets the job Id
        /// </summary>
        [DataMember]
        public Guid JobId { get; set; }

        /// <summary>
        /// Gets or sets the status code
        /// </summary>
        [DataMember]
        public StatusCode Status { get; set; }

        /// <summary>
        /// Gets or sets the percentaje of completion
        /// </summary>
        [DataMember]
        public int? PercentComplete { get; set; }

        /// <summary>
        /// Gets or sets the feedback message
        /// </summary>
        [DataMember]
        public string FeedbackMessage { get; set; }
    }
}
