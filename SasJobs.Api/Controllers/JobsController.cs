using System;
using System.Web.Http;
using SasJobs.Messages;
using SasJobs.Api.Models;

namespace SasJobs.Api.Controllers
{
    /// <summary>
    /// Main controller for the sas jobs API
    /// </summary>
    [ExceptionHandlingFilter]
    public class JobsController : ApiController
    {       
        /// <summary>
        /// New job request handler 
        /// </summary>
        /// <param name="request">New job parameters</param>
        /// <returns></returns>
        [HttpPost, Route("api/jobs")]
        public JobResponse Post([FromBody]JobRequest request)
        {
            JobSettings settings = new JobSettings(request);
            Guid id = Models.SasJobsManager.Current.BeginJob(settings);

            return new JobResponse { 
                CorrelationId = id,
                Status = Messages.StatusCode.Running,
                PercentComplete = 0
            };
        }

        /// <summary>
        /// Sas jobs request handler
        /// </summary>
        /// <param name="request"></param>
        /// <returns></returns>
        [HttpGet, Route("api/jobs/{id:guid}")]
        public JobResponse Get(Guid id)
        {
            JobFeedback feedback = Models.SasJobsManager.Current.GetProgress(id);

            // if feedback is not ready respond with an empty response
            if (feedback == null)
            {
                feedback = new JobFeedback
                {
                    Status = Messages.StatusCode.Running,
                    PercentComplete = 0,
                    FeedbackMessage = null
                };
            }

            // Compose the response message
            JobResponse response = new JobResponse 
            {
                CorrelationId = id,
                FeedbackMessage = feedback.FeedbackMessage,
                PercentComplete = feedback.PercentComplete,
                Status = feedback.Status,
                Data = new System.Data.DataSet()
            };

            // retrieve result data
            if (feedback.Status == Messages.StatusCode.Done)
            {
                string xmlResult = Models.SasJobsManager.Current.GetResult(id);
                if (!String.IsNullOrWhiteSpace(xmlResult))
                {
                    var reader = new System.IO.StringReader(xmlResult);
                    response.Data.ReadXml(reader, System.Data.XmlReadMode.ReadSchema);
                }
            }

            return response;
        }
    }
}
