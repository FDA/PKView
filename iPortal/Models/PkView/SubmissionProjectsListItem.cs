using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace iPortal.Models.PkView
{
    /// <summary>
    /// Item for a list of submission projects sorted by user
    /// </summary>
    public class SubmissionProjectsListItem
    {
        /// <summary> User name </summary>
        public string User { get; set; }

        /// <summary> user string for display purposes, typically 'last name, first name'</summary>
        public string DisplayUser { get; set; }

        /// <summary> List of project names</summary>
        public IEnumerable<string> Projects { get; set; }
    }
}