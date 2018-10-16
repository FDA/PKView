using iPortal.Models;
using iPortal.Models.OgdTool;
using System.Linq;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Web;
using System.Web.Hosting;
using System.Web.Http;
using iPortal.Models.Shared;
using System.DirectoryServices.AccountManagement;
using System;

namespace iPortal.Controllers.OgdTool
{
    /// <summary>
    /// Script generator controller
    /// </summary>

    public class ProjectController : ApiController
    {
        /// <summary>
        /// Save a project
        /// </summary>
        [Route("api/ogdtool/saveproject"), HttpPost]
        public void Save([FromBody] Project project)
        {
            var projectFilename = string.Format(@"{0}{1}_{2}",
                project.SubmissionType, project.SubmissionNumber, project.ProjectName);
            XmlUserData.Save<Project>(project, projectFilename, "OgdTool"); 
        }

        /// <summary>
        /// Get a list of projects for the current user
        /// </summary>
        [Route("api/ogdtool/listmyprojects"), HttpGet]
        public List<UserProjectsListItem> List()
        {
            string outputPath = new DownloadController().GetRepositoryPath("OgdTool");
            IEnumerable<string> userProjects = XmlUserData.Find("*", "OgdTool");
            var splitProjects = userProjects.Select(p => {
                var i = p.IndexOf('_');
                var submission = p.Substring(0,i);
                var projectName = p.Substring(i+1);
                return new { submission, projectName };
            });
          
            return splitProjects.GroupBy(p => p.submission, (s, l) =>
                new UserProjectsListItem
                {
                    Submission = s,
                    Projects = l.Select(pro => new ProjectMetadata {
                        Name = pro.projectName,
                        HasPackage = File.Exists(
                            Path.Combine(outputPath, pro.submission, pro.projectName + ".zip"))
                    }).ToList()
                }).ToList();
        }

        /// <summary>
        /// Get a list of projects for the selected submission by user
        /// </summary>
        [Route("api/ogdtool/listsubmissionprojects"), HttpGet]
        public List<SubmissionProjectsListItem> List(string submission)
        {
            var userName = Users.GetCurrentUserName();

            using (var context = new PrincipalContext(ContextType.Domain, "localhost"))
            {
                var users = XmlUserData.GetUsers(context);
                if (users == null) return null;

                return users.SelectMany(u =>
                {
                    // Do not return profiles for the current user
                    if (userName.Equals(u.Name, StringComparison.InvariantCultureIgnoreCase))
                        return new SubmissionProjectsListItem[] { };

                    // Do not return a user without profiles
                    var projects = this.getUserProjects(submission, u.Name);
                    if (projects == null || !projects.Any())
                        return new SubmissionProjectsListItem[] { };

                    // return the list of profiles for the user
                    return new[] { new SubmissionProjectsListItem
                    {
                        User = u.Name,
                        DisplayUser = String.Format("{0}, {1}{2}", u.Surname, u.GivenName,
                            u.Name.StartsWith("AD_APP_") ? " (admin)" : ""),
                        Projects = projects
                    }};
                }).ToList();
            }
        }

        /// <summary>
        /// Load a project
        /// </summary>
        [Route("api/ogdtool/loadproject"), HttpGet]
        public Project Load(string submission, string project)
        {
            var projectFilename = string.Format(@"{0}_{1}",submission, project);
            return XmlUserData.Load<Project>(projectFilename, "OgdTool");
        }

        /// <summary>
        /// Load a project
        /// </summary>
        [Route("api/ogdtool/deleteproject"), HttpGet]
        public bool Delete(string submission, string project)
        {
            var projectFilename = string.Format(@"{0}_{1}",submission, project);
            var userName = Users.GetCurrentUserName();

            // Delete output files
            var outputPath = string.Format(@"\\{0}\Output Files\OgdTool\{1}\{2}\{3}",
                iPortalApp.AppServerName, userName, submission, project);
            if (Directory.Exists(outputPath))
                Directory.Delete(outputPath, true);

            // Delete output package if present
            if (File.Exists(outputPath + ".zip"))
                File.Delete(outputPath + ".zip");

            // Delete config file
            return XmlUserData.Delete(projectFilename, "OgdTool");
        }

        /// <summary>
        /// Import a project from another user
        /// </summary>
        /// <param name="submission">submission</param>
        /// <param name="user">original owner of the project</param>
        /// <param name="project">project to import</param>
        /// <returns>true if project was successfully imported</returns>
        [Route("api/ogdtool/importproject"), HttpGet]
        public bool Import(string submission, string user, string project)
        {          
            var projectFilename = string.Format(@"{0}_{1}", submission, project);
            bool success = XmlUserData.Import(projectFilename, user, "OgdTool");
            if (!success) return false;

            // Copy output folder
            var userNameDest = Users.GetCurrentUserName();
            user = Users.LongUserToShort(user);

            var sourcePath = string.Format(@"\\{0}\Output Files\OgdTool\{1}\{2}\{3}",
                iPortalApp.AppServerName, user, submission, project);
            var destPath = string.Format(@"\\{0}\Output Files\OgdTool\{1}\{2}\{3}",
                iPortalApp.AppServerName, userNameDest, submission, project);
            if (Directory.Exists(sourcePath))
                DirectoryTools.DirectoryCopy(sourcePath, destPath, true, true);

            // Copy ouptut package if it exists
            FileInfo pkgFile = new FileInfo(sourcePath + ".zip");
            if (pkgFile.Exists)
                pkgFile.CopyTo(destPath + ".zip", true);

            return true;
        }

        /// <summary>
        /// Retrieve list of profiles for a given user
        /// </summary>
        /// <param name="submission">Name of the selected submission</param>
        /// <param name="userName">Name of the user excluding the domain</param>
        /// <returns>A list of analysis profiles</returns>
        private IEnumerable<string> getUserProjects(string submission, string userName)
        {
            var configFiles = XmlUserData.FindFiles(submission + "_*", "OgdTool", userName)
                .OrderBy(f => f.LastWriteTime).Reverse()
                .Select(f => f.Name.Substring(f.Name.IndexOf("_") + 1, 
                    f.Name.LastIndexOf('.') - f.Name.IndexOf("_") - 1));
            return configFiles;
        }
    }
}
