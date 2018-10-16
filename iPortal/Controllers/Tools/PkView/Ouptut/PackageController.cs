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
using System.Web;
using System.IO;
using iPortal.Models.Shared;

namespace iPortal.Controllers.PkView
{
    /// <summary>
    /// Results Package creation controller
    /// </summary>
    public class PackageController : ApiController
    {
        /// <summary>
        /// Run the packaging procedure
        /// </summary>
        /// <returns>A job id</returns>
        [HttpGet, Route("api/pkview/createPackage")]        
        public string Get(string ndaFolderName, string profileName = null)
        {
            var userName = HttpContext.Current.User.Identity.Name ?? "DEFAULT";
            userName = userName.Substring(userName.LastIndexOfAny(new[] { '/', '\\' }) + 1);

            // Run the 'CreatePackage' stored procedure in the SAS server. This procedure will create a 
            // zip files with the results of the individual study analyses          
            return SasClientObject.NewJob("CreatePackage", new {
                NDAName = ndaFolderName,
                userName = userName,
                profileName = profileName,
                timestamp = DateTime.Now.ToString("yyyyMMddHHmmssffff"), // Timestamp added to avoid caching in the backend
            }).ToString();
        }

        /// <summary>
        /// Run the packaging procedure
        /// </summary>
        /// <returns>A job id</returns>
        [HttpGet, Route("api/pkview/createMetaPackage")]
        public string Get(string foldername = "Meta", string ndaFolderName = null, string profileName = null, string activeSupplement = null)
        {
            var userName = HttpContext.Current.User.Identity.Name ?? "DEFAULT";
            userName = userName.Substring(userName.LastIndexOfAny(new[] { '/', '\\' }) + 1);

            // Run the 'CreatePackage' stored procedure in the SAS server. This procedure will create a 
            // zip files with the results of the individual study analyses          
            return SasClientObject.NewJob("CreateMetaPackage", new
            {
                NDAName = ndaFolderName,
                userName = userName,
                profileName = profileName,
                activeSupplement = "'" + activeSupplement + "'",
                foldername = foldername,
                timestamp = DateTime.Now.ToString("yyyyMMddHHmmssffff"), // Timestamp added to avoid caching in the backend
            }).ToString();
        }

        /// <summary>
        /// Run the study packaging procedure
        /// </summary>
        /// <returns>A job id</returns>
        [HttpGet, Route("api/pkview/createStudyPackage")]
        public string Get(string ndaFolderName = null, string profileName = null, string activeStudy = null, string activeSupplement = null,int xxxx = 0)
        {
            var userName = HttpContext.Current.User.Identity.Name ?? "DEFAULT";
            userName = userName.Substring(userName.LastIndexOfAny(new[] { '/', '\\' }) + 1);

            // Run the 'CreatePackage' stored procedure in the SAS server. This procedure will create a 
            // zip files with the results of the individual study analyses 
            DeleteAllZipPackageUnderStudyFolder(profileName, ndaFolderName, activeSupplement, activeStudy);

            return SasClientObject.NewJob("CreateStudyPackage", new
            {
                NDAName = ndaFolderName,
                activeStudy = activeStudy,
                activeSupplement = "'" + activeSupplement + "'",
                userName = userName,
                profileName = profileName,
                timestamp = DateTime.Now.ToString("yyyyMMddHHmmssffff"), // Timestamp added to avoid caching in the backend
            }).ToString();
        }

        /// <summary>
        /// Main Get function
        /// </summary>
        /// <returns>A list of results</returns>
        [HttpGet, Route("api/pkview/waitForPackage")]
        public JobResponse<int> Get(Guid jobId)
        {
            var response = SasClientObject.Getjob(jobId);
            return new JobResponse<int>(response);
        }

        private void DeleteAllZipPackageUnderStudyFolder(string project, string submission, string supplement, string study)
        {
            var userName = Users.GetCurrentUserName();
            var reportPath = string.Format(@"\\{0}\Output Files\PKView\{1}\{2}\{3}\{4}\{5}",
                iPortalApp.AppServerName, userName, project, submission, supplement, study);
            var reportFolder = new DirectoryInfo(reportPath);
            FileInfo[] files = reportFolder.GetFiles("*.zip")
                     .Where(p => p.Extension == ".zip").ToArray();
            foreach (FileInfo file in files)
                try
                {
                    file.Attributes = FileAttributes.Normal;
                    File.Delete(file.FullName);
                }
                catch { }
        }
    }
}
