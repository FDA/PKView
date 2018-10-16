using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web;
using System.Web.Http;
using iPortal.App_Data;
using iPortal.Models.ForestPlot;
using iPortal.Config;

namespace iPortal.Controllers.ForestPlot
{
    public class ProjectCreateController : ApiController
    {
        // POST api/<controller>
        [Route("api/forestplot/newproject")]
        public HttpResponseMessage Post([FromBody]string projectName)
        {
            int? projectId = null;
            //  Using LINQ to SQL to insert excel data into database
            using (var fpContext = new OCPSQLEntities())
            {
                // string query = "Select [CATEGORY], [SUBCATEGORY], [PARAMETER], [RATIO], [LOWER_CI], [UPPER_CI], [COMMENT] from [Sheet1$]";
                if (fpContext.SYSTEM_USER.Any(u => u.USER_NAME == User.Identity.Name))
                {
                    var user = fpContext.SYSTEM_USER.SingleOrDefault(u => u.USER_NAME == User.Identity.Name);
                    //  Insert new project data into database
                    var newProject = new FPTOOLS_PROJECT()
                    {
                        USER_ID = user.USER_ID,
                        FILE_NAME = "",
                        PROJECT_NAME = projectName ?? "",
                    };

                    //  Initialize new Plot data into database
                    var newPlot = new IPORTAL_FP
                    {
                        TITLE = "",
                        SCALE_ID = 1,
                        FOOTNOTE = "",
                        XLABEL = "",
                        FP_STYLE_ID = 1,
                        RANGE_BOTTOM = 10,
                        RANGE_TOP = 30,
                        RANGE_STEP = 3,
                    };

                    IPORTAL_FP_ROW newPlotData = new IPORTAL_FP_ROW();
                    {
                        newPlotData.CATEGORY = "";
                        newPlotData.SUBCATEGORY = "";
                        newPlotData.PARAMETER = "";
                        newPlotData.RATIO = 0;
                        newPlotData.LOWER_CI = 1;
                        newPlotData.UPPER_CI = 10;
                        newPlotData.COMMENT = "New Plot comment";
                        newPlotData.FP_ID = newPlot.FP_ID;
                        newPlot.IPORTAL_FP_ROW.Add(newPlotData);
                    }
                    newProject.IPORTAL_FP.Add(newPlot);
                    fpContext.FPTOOLS_PROJECT.Add(newProject);
                    fpContext.SaveChanges();

                    // Retrieve the id of the submitted project
                    projectId = newProject.PROJECT_ID;
                }
                else // TODO: error check for no login user
                {
                    throw new HttpResponseException(HttpStatusCode.InternalServerError);
                };
            }
            return Request.CreateResponse(HttpStatusCode.OK, projectId);
        }
    }
}