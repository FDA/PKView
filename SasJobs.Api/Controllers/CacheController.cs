using System;
using System.Web.Http;
using SasJobs.Messages;
using SasJobs.Api.Models;

namespace SasJobs.Api.Controllers
{
    /// <summary>
    /// Cache manipulation controller for the SAS Jobs Api
    /// </summary>
    [ExceptionHandlingFilter]
    public class CacheController : ApiController
    {
       /// <summary>
        /// Clear the job cache
        /// </summary>
        /// <param name="command">New job parameters</param>
        /// <returns></returns>
        [HttpGet, Route("api/cache/clear")]
        public bool Get(string key = "")
        {
            return Models.SasJobsManager.Current.DeleteCache();
        }
    }
}
