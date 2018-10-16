using System;
using System.Data;

namespace SasJobs.Messages
{
    public class JobResponse<T>
    {
        public Guid CorrelationId { get; set; }
        public StatusCode Status { get; set; }
        public int? PercentComplete { get; set; }
        public string FeedbackMessage { get; set; }
        public T Data { get; set; }

        public JobResponse() { }

        public JobResponse(JobResponse raw)
        {
            CopyHeader(raw);
            this.Data = default(T); // TODO smart conversion into destination type
        }

        public JobResponse(JobResponse raw, T data)
        {
            CopyHeader(raw);
            this.Data = data;               
        }

        private void CopyHeader(JobResponse raw)
        {
            this.CorrelationId = raw.CorrelationId;
            this.Status = raw.Status;
            this.FeedbackMessage = raw.FeedbackMessage;
            this.PercentComplete = raw.PercentComplete;
        }
    }

    public class JobResponse : JobResponse<DataSet>
    {
        public JobResponse() { }
    }
}
