using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web;
using System.Web.Http;
using System.Data;
using iPortal.App_Data;
using iPortal.Models.ForestPlot;
using iPortal.Config;

namespace iPortal.Controllers.ForestPlot
{
    /// <summary>
    /// Plot controller 
    /// </summary>
    public class ProjectGetController : ApiController
    {
        /// <summary>
        /// Main Get function
        /// </summary>
        /// <returns>A list of results</returns>
        [Route("api/forestplot/plots")]
        public Project Get(int projectId)
        {
            string userName = HttpContext.Current.User.Identity.Name;
            //  Using LINQ to SQL, work with the database context, Retrieve project list from database 
            using (var fpContext = new OCPSQLEntities())
            {   
                var userId = fpContext.SYSTEM_USER
                    .Where(u => u.USER_NAME == HttpContext.Current.User.Identity.Name)
                    .SingleOrDefault().USER_ID;                // TODO : error checking for null user 

                 // Retrieve project list from database          
                var selectedProject = fpContext.FPTOOLS_PROJECT
                    .Where(i => i.USER_ID == userId && i.PROJECT_ID == projectId )
                    .Select(p => new Project
                    {
                            Id = p.PROJECT_ID,
                            ProjectName = p.PROJECT_NAME,
                            FileName = p.FILE_NAME,
                            PlotNumbers = p.IPORTAL_FP.Count(k => k.PROJECT_ID == projectId),
                            Plots = p.IPORTAL_FP.Where(i => i.PROJECT_ID == projectId)
                                    .ToList().Select(t => new Plot()
                                    {
                                        Id = t.FP_ID,
                                        Settings = new PlotSettings
                                        {
                                            DrugName = t.DRUGNAME,
                                            Title = t.TITLE,
                                            FootNote = t.FOOTNOTE,
                                            Xlabel = t.XLABEL,
                                            RangeBottom = t.RANGE_BOTTOM,
                                            RangeTop = t.RANGE_TOP,
                                            RangeStep = (double)t.RANGE_STEP,
                                            Style = t.FP_STYLE_ID,
                                            Scale = t.SCALE_ID
                                        },
                                        Rows = t.IPORTAL_FP_ROW.Where(r => r.FP_ID == t.FP_ID)
                                                .ToList().Select(w => new PlotData()
                                                {
                                                    Category = w.CATEGORY,
                                                    SubCategory = w.SUBCATEGORY,
                                                    Parameter = w.PARAMETER,
                                                    Comment = w.COMMENT,
                                                    Ratio = w.RATIO, // (double?)w.RATIO.Value ?? (double?) null,
                                                    Lower_CI = w.LOWER_CI, //(double?)w.LOWER_CI.Value ?? (double?)null,
                                                    Upper_CI = w.UPPER_CI, //(double?)w.UPPER_CI.Value ?? (double?)null,
                                                }).ToList()
                                    }).ToList()
                    }).FirstOrDefault();
                    return selectedProject;
            }   
        }
    }
}
