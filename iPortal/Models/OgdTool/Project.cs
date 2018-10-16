using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace iPortal.Models.OgdTool
{
    /// <summary>
    /// Represents an analysis project in the OGD Tool
    /// </summary>
    public class Project
    {
        /// <summary>
        /// Name given to this project
        /// </summary>
        public string ProjectName { get; set; }

        /// <summary>
        /// Submission Type
        /// </summary>
        public string SubmissionType { get; set; }

        /// <summary>
        /// Submission Number
        /// </summary>
        public string SubmissionNumber { get; set; }

        /// <summary>
        /// List of treatment comparisons in the submission
        /// </summary>
        public List<TreatmentComparison> Comparisons { get; set; }

        /// <summary>
        /// List of all xpt files found in the submission
        /// </summary>
        public List<string> AllFiles { get; set; }
    }
}