using iPortal.Models.Shared.System;
using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Web;
using System.Web.Hosting;
using System.Web.Http;

namespace iPortal.Controllers
{
    public class DownloadController : ApiController
    {
        // List of repositories
        public static IDictionary<string, string> Repositories =
            new Dictionary<string, string> {
                {"templates", HostingEnvironment.MapPath(@"~/Content/templates/") },
                {"apps", HostingEnvironment.MapPath(@"~/Content/apps/") }
            };

        // locks for file access
        private static NamedLocker filelocks = new NamedLocker();

        // GET api/file
        [Route("api/download/{repository}/{filename}")]
        public HttpResponseMessage Get(string repository, string filename, string subfolder = "")
        {
            try
            {
                var result = new HttpResponseMessage(HttpStatusCode.OK);

                // Create a memory stream to dump the file to
                MemoryStream virtualStream = null;

                // Replace [USER] by the user folder in repository path if present
                string repositoryPath = this.GetRepositoryPath(repository);

                // Use a lock to control mutual exclusion on file access                
                lock (filelocks.GetLock(repository + subfolder + filename))
                {
                    // Copy the file to the virtual stream
                    using (var fileStream = new FileStream(
                        String.Format("{0}\\{1}\\{2}", repositoryPath, 
                            subfolder, filename), FileMode.Open, FileAccess.Read))
                    {
                        virtualStream = new MemoryStream((int)fileStream.Length);
                        fileStream.CopyTo(virtualStream);
                    }
                }

                // Set the read cursor at the beginning of the memory stream
                virtualStream.Seek(0, SeekOrigin.Begin);

                // Set the memory stream as the content for the response
                result.Content = new StreamContent(virtualStream);

                //a text file is actually an octet-stream (pdf, etc)
                result.Content.Headers.ContentType = new MediaTypeHeaderValue("application/octet-stream");
                
                //we used attachment to force download
                result.Content.Headers.ContentDisposition = new ContentDispositionHeaderValue("attachment")
                    { FileName = filename };
                return result;
            }
            catch (Exception ex)
            {
                throw new HttpResponseException(HttpStatusCode.InternalServerError);
            }

        }

        /// <summary>
        /// Get the repository path for the named repository
        /// </summary>
        /// <param name="repositoryName">repository name</param>
        /// <returns>the repository path</returns>
        public string GetRepositoryPath(string repositoryName) {
            string repositoryPath = Repositories[repositoryName];
            
            // Replace [USER] by the user folder in repository path if present            
            if (repositoryPath.Contains("[USER]"))
            {
                var userName = HttpContext.Current.User.Identity.Name ?? "DEFAULT";
                userName = userName.Substring(userName.LastIndexOfAny(new[] { '/', '\\' }) + 1);
                repositoryPath = repositoryPath.Replace("[USER]", userName);
            }
            return repositoryPath;
        }
    }
}
