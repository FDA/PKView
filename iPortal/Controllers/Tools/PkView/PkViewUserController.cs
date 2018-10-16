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
    /// PkView users controller
    /// </summary>

    public class PkViewUserController : ApiController
    {
        /// <summary>
        /// Get the list of pkview users
        /// </summary>
        /// <returns></returns>
        [Route("api/pkview/users"), HttpGet]
        public List<User> Get() {
            using (var context = new PrincipalContext(ContextType.Domain, "localhost"))
            {
                var users = XmlUserData.GetUsers(context);
                
                if (users != null)
                    return users.Select(u => new User
                    {
                        UserName = u.Name,
                        DisplayName = String.Format("{0}, {1}{2}", u.Surname, u.GivenName,
                            u.Name.StartsWith("AD_APP_") ? " (admin)" : "")
                    }).ToList();
            }
            return null;           
        }      
    }
}
