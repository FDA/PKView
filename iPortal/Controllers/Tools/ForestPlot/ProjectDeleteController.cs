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
using System.DirectoryServices.AccountManagement;


namespace iPortal.Controllers.ForestPlot
{
    public class ProjectDeleteController : ApiController
    {
        // POST api/<controller>
        /// <summary>
        /// Delete Project
        /// </summary>
        /// <param name="value"></param>
        [HttpDelete, Route("api/forestplot/deleteproject/{id}")]
        public HttpResponseMessage Delete(int id)
 //       public string DELETE (int projectId)
        {
            //try
            //{
                //using (var context = new PrincipalContext(ContextType.Domain))
                //{
                //    var principal = UserPrincipal.FindByIdentity(context, User.Identity.Name);
                //}
                
               // string userName = HttpContext.Current.User.Identity.Name;
                string projectName = "projectName";
                //  Using LINQ to SQL, work with the database context, Retrieve project list from database 
                using (var fpContext = new OCPSQLEntities())
                {
                    var userId = fpContext.SYSTEM_USER
                        .Where(u => u.USER_NAME == HttpContext.Current.User.Identity.Name)
                        .SingleOrDefault().USER_ID;                // TODO : error checking for null user 

                    // Retrieve project list from database        
                    var selectedProject = (from p in fpContext.FPTOOLS_PROJECT
                                           //Retrieve User Id & Project Id from database
                                           where (p.PROJECT_ID == id && p.USER_ID == userId)
                                           //Temp Test Run Demo: TODO : fix Anonymous user 
                                           //where (p.PROJECT_ID == id && p.USER_ID == 4)  
                                           select p).FirstOrDefault();
                    projectName = selectedProject.PROJECT_NAME;
                    fpContext.FPTOOLS_PROJECT.Attach(selectedProject);
                    fpContext.FPTOOLS_PROJECT.Remove(selectedProject);
                    fpContext.SaveChanges();
                }
            //    return projectName;
            //    return new HttpResponseMessage(HttpStatusCode.NoContent);
                return Request.CreateResponse(HttpStatusCode.OK, projectName);
            //}
            //catch (System.Exception e)
            //{
            //    return Request.CreateErrorResponse(HttpStatusCode.InternalServerError, e);
            //}
        }
    }
        //// DELETE api/<controller>/5
        //public void Delete(int id)
        //{
        //}
}