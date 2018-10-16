using iPortal.Models;
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
using iPortal.Models.PkView;
using System.Net.Mail;

namespace iPortal.Controllers.PkView
{
    /// <summary>
    /// PkView projects controller
    /// </summary>

    public class PkViewProjectController : ApiController
    {
        private ProjectRepository projectRepository;

        /// <summary>
        /// project controller constructor
        /// </summary>
        public PkViewProjectController() 
        {
            this.projectRepository = new ProjectRepository();
        }

        /// <summary>
        /// Get a project that belongs to the current user
        /// </summary>
        /// <param name="submissionId">Parent submission for the project</param>
        /// <param name="projectName">Project name</param>
        /// <returns></returns>
        [Route("api/pkview/projects"), HttpGet]
        public Project Get(string submissionId, string projectName, string userName = null, bool metadataOnly = false) {
            var flag = metadataOnly ? ProjectRetrievalFlags.MetaDataOnly : ProjectRetrievalFlags.MeanDataOnly;
            return this.projectRepository.Find(submissionId, projectName, userName, flag);
        }

        /// <summary>
        /// Get a list of projects for the current user
        /// </summary>
        [Route("api/pkview/listmyprojects"), HttpGet]
        public List<UserProjectsListItem> List()
        {
            string outputPath = new DownloadController().GetRepositoryPath("PkView");
            IEnumerable<string> userProjects = XmlUserData.Find("*", "PkView");
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
                            Path.Combine(outputPath, pro.projectName, pro.submission +".zip"))
                    }).ToList()
                }).ToList();
        }

        /// <summary>
        /// Get a list of projects for the selected submission by user
        /// </summary>
        [Route("api/pkview/listsubmissionprojects"), HttpGet]
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
        /// Delete a project
        /// </summary>
        [Route("api/pkview/deleteproject"), HttpGet]
        public bool Delete(string submission, string project)
        {
            return this.projectRepository.Remove(submission, project); 
        }

        /// <summary>
        /// Import a project from another user
        /// </summary>
        /// <param name="submission">submission</param>
        /// <param name="user">original owner of the project</param>
        /// <param name="project">project to import</param>
        /// <returns>true if project was successfully imported</returns>
        [Route("api/pkview/importproject"), HttpGet]
        public bool Import(string submission, string user, string project)
        {
            return this.projectRepository.Import(submission, project, user);
        }

        [Route("api/pkview/shareproject"), HttpPost]
        public bool Share(string submission, string project, string user, [FromBody] List<string> studies)
        {
            // if user was provided as an fda email address, extract the real user name
            if (user.Contains("@"))
            {
                user = Users.FindUserByEmail(user);
                if (user == null) return false;
                return this.projectRepository.Share(submission, project, user, studies);
            }

            return this.projectRepository.Share(submission, project, user, studies);
        }

        /// <summary>
        /// Retrieve list of projects for a given user
        /// </summary>
        /// <param name="submission">Name of the selected submission</param>
        /// <param name="userName">Name of the user excluding the domain</param>
        /// <returns>A list of analysis profiles</returns>
        private IEnumerable<string> getUserProjects(string submission, string userName)
        {
            var configFiles = XmlUserData.FindFiles(submission + "_*", "PkView", userName)
                .OrderBy(f => f.LastWriteTime).Reverse()
                .Select(f => f.Name.Substring(f.Name.IndexOf("_") + 1, 
                    f.Name.LastIndexOf('.') - f.Name.IndexOf("_") - 1));
            return configFiles;
        }
    }
}
