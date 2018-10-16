using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Web.Http;
using iPortal;
using iPortal.App_Data;
using iPortal.Models.PkView;
using iPortal.Config;
using iPortal.Models;
using SasJobs.ClientLibrary;
using SasJobs.Messages;
using System.IO;
using System.Web;

namespace iPortal.Controllers.PkView
{
    /// <summary>
    /// Study Design related operations
    /// </summary>
    public class StudyDesignController : ApiController
    {
        /// <summary>
        /// Determine treatments from a list of arms in string form
        /// </summary>
        /// <param name="arms"></param>
        /// <returns></returns>
        [HttpPost, Route("api/pkview/armsToTreatments")]
        public IEnumerable<ArmMapping> DetermineArmTreatments([FromBody]IEnumerable<string> arms)
        {
            return new StudyDataManager().DetermineArmTreatments(arms);  
        }

        /// <summary>
        /// Determine a standarized mapping for the visit values
        /// </summary>
        /// <param name="arms"></param>
        /// <returns></returns>
        [HttpPost, Route("api/pkview/mapValues/{Domain}/{Variable}")]
        public IEnumerable<ValueMapping> MapValues([FromBody]IEnumerable<string> values, string domain, string variable)
        {
            domain = domain.ToUpper();
            variable = variable.ToUpper();

            // Generate visit value mappings
            if (new[] {"PC","PP"}.Contains(domain) && variable == "VISIT")
                return new StudyDataManager().DetermineVisits(values);

            // Generate timepoint value mappings
            if (domain == "PC" && variable == "PCTPTNUM")
                return new StudyDataManager().DetermineTpts(values);

            return null;
        }
    }
}
