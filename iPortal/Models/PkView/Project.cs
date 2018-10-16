using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace iPortal.Models.PkView
{
    /// <summary>
    /// Represents a project in pkview
    /// </summary>
    public class Project
    {
        /// <summary>
        /// Name given to this project
        /// </summary>
        public string ProjectName { get; set; }

        /// <summary>
        /// Submission identifier
        /// </summary>
        public string SubmissionId { get; set; }

        /// <summary>
        /// List of studies in the submission
        /// </summary>
        public List<StudySettings> Studies { get; set; }

        /// <summary>
        /// Project revision history
        /// </summary>
        public List<ProjectRevision> RevisionHistory { get; set; }
    }

    /// <summary>
    /// Represents a change in a project
    /// </summary>
    public class ProjectRevision : IEquatable<ProjectRevision> {
        public int RevisionId { get; set; }
        public string Name { get; set; }
        public string Owner { get; set; }
        public ActionTypes Action { get; set; }
        public DateTime Date { get; set; }


        public bool Equals(ProjectRevision other)
        {
            if (other == null) return false;

            return RevisionId == other.RevisionId
                && Action == other.Action
                && Name == other.Name
                && Owner == other.Owner
                && Date == other.Date;
        }

        public override bool Equals(object obj)
        {
            return this.Equals(obj as ProjectRevision);
        }

        public override int GetHashCode()
        {
            int hash = 17;
            unchecked 
            {
                hash = hash * 31 + RevisionId;
                hash = hash * 31 + (int) Action;
                hash = hash * 31 + (Name == null ? 0 : Name.GetHashCode());
                hash = hash * 31 + (Owner == null ? 0 : Owner.GetHashCode());                
                hash = hash * 31 + (Date == null ? 0 : Date.GetHashCode());
            }
            return hash;
        }
    }

    /// <summary>
    /// Possible change actions on a project
    /// </summary>
    public enum ActionTypes {
        None = 0,
        Create = 1,
        Import = 2,
        Share = 3,
        Save = 4,
        Rename = 5
    }
}