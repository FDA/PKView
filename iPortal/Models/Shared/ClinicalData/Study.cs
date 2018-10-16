using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace iPortal.Models.Shared.ClinicalData
{
    /// <summary>
    /// Represents a single clinical study
    /// </summary>
    public class Study
    {
        /// <summary> Parent submission id</summary>
        public string SubmissionId { get; set; }
        /// <summary> Study id</summary>
        public string StudyId { get; set; }
        /// <summary> Communication serial number where the data for this study can be found </summary>
        public string SerialNumber { get; set; }
    }
}