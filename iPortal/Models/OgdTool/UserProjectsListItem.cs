using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace iPortal.Models.OgdTool
{
    /// <summary>
    /// List item for a list of user projects
    /// </summary>
    public class UserProjectsListItem
    {
        /// <summary> Submission </summary>
        public string Submission { get; set; }
        /// <summary> List of project metadata</summary>
        public List<ProjectMetadata> Projects { get; set; }
    }

    /// <summary>
    /// Project metadata
    /// </summary>
    public class ProjectMetadata
    {
        /// <summary> Project name</summary>
        public string Name { get; set; }

        /// <summary> A zip output package exists for this project</summary>
        public bool HasPackage { get; set; }
    }
}