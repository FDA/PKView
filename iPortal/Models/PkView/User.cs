using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace iPortal.Models.PkView
{
    /// <summary>
    /// Represents a pkview user
    /// </summary>
    public class User
    {
        /// <summary>
        /// User name excluding the domain prefix
        /// </summary>
        public string UserName { get; set; }

        /// <summary>
        /// Name of the user for display purposes
        /// </summary>
        public string DisplayName { get; set; }
    }
}