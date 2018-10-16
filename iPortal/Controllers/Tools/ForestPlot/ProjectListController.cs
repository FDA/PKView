using System;
using System.Data;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web;
using System.Web.Http;
using iPortal.App_Data;
using iPortal.Models.ForestPlot;


namespace iPortal.Controllers.ForestPlot
{
    /// <summary>
    /// Search service controller
    /// </summary>
    public class ProjectListController : ApiController
    {
        /// <summary>
        /// Main Get function
        /// </summary>
        /// <returns>A list of results</returns>
        [Route("api/forestplot/projectlist")]
        public IEnumerable<Project> Get()
        {   
            string userName = HttpContext.Current.User.Identity.Name;

            //  Using LINQ to SQL
            using (var fpContext = new OCPSQLEntities())
            {   
                var user = fpContext.SYSTEM_USER
                    .Where(u => u.USER_NAME == userName)
                    .SingleOrDefault();                 

                if (user == null)
                {
                    user = new SYSTEM_USER { USER_NAME = userName };
                    fpContext.SYSTEM_USER.Add(user);
                    fpContext.SaveChanges();
                }

                var userId = user.USER_ID;

                 // Retrieve project list from database          
                var existProjects = fpContext.FPTOOLS_PROJECT
                    .Where(i => i.USER_ID == userId)
                    .Select(p => new Project
                        {
                            Id = p.PROJECT_ID,
                            ProjectName = p.PROJECT_NAME,
                            FileName = p.FILE_NAME,
                            PlotNumbers = p.IPORTAL_FP.Count(k => k.PROJECT_ID == p.PROJECT_ID)
                        }).ToList();
                return existProjects;
            }
        }
    }
} 