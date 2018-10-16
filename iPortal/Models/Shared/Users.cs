using System;
using System.Collections.Generic;
using System.DirectoryServices.AccountManagement;
using System.Linq;
using System.Web;
using System.Web.Security;

namespace iPortal.Models.Shared
{
    /// <summary>
    /// User management functions
    /// </summary>
    public static class Users
    {
        /// <summary>
        /// Get the current user identity
        /// </summary>
        /// <returns>A string representing the current user identity</returns>
        public static string GetCurrentUser()
        {
            return HttpContext.Current.User.Identity.Name ?? "DEFAULT";
        }

        /// <summary>
        /// Get the current user name
        /// </summary>
        /// <returns>The current user name</returns>
        public static string GetCurrentUserName()
        {
            return LongUserToShort(GetCurrentUser());
        }

        /// <summary>
        /// Returns the user only part from a domain/user string
        /// </summary>
        /// <param name="longUser">The domain/user string</param>
        /// <returns>only the user name</returns>
        public static string LongUserToShort(string longUser)
        {
            return longUser.Substring(longUser.LastIndexOfAny(new[] { '/', '\\' }) + 1);
        }

        public static string FindUserByEmail(string email)
        {
            using (var context = new PrincipalContext(ContextType.Domain, "localhost"))
            {
                var user = new UserPrincipal(context);
                user.EmailAddress = email;

                var searcher = new PrincipalSearcher(user);
                var result = searcher.FindAll();

                if (result.Count() > 0) return result.First().Name;
                else return null;
            }
            
        }
    }
}