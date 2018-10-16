using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace iPortal.Models.OgdTool
{
    /// <summary>
    /// Represents a single treatment comparison
    /// </summary>
    public class TreatmentComparison
    {
        /// <summary>Comparison title</summary>
        public string Title { get; set; }

        /// <summary>Level for plotting purposes</summary>
        public string Level { get; set; }

        /// <summary>Drug for plotting purposes</summary>
        public string Drug { get; set; }

        /// <summary>Dose for plotting purposes</summary>
        public string Dose { get; set; }

        /// <summary>Study type for plotting purposes</summary>
        public string StudyType { get; set; }

        /// <summary>AUC units for plotting purposes</summary>
        public string AucUnits { get; set; }

        /// <summary>CMAX units for plotting purposes</summary>
        public string CmaxUnits { get; set; }

        /// <summary>Time units for plotting purposes</summary>
        public string TimeUnits { get; set; }

        /// <summary>Concentration data file</summary>
        public DataFile ConcentrationFile { get; set; }

        /// <summary>Pk data file</summary>
        public DataFile PkFile { get; set; }

        /// <summary>Time data file (optional)</summary>
        public DataFile TimeFile { get; set; }

        /// <summary>Ke data file (optional)</summary>
        public DataFile KeFile { get; set; }

        /// <summary> Use a separate file for sampling times</summary>
        public bool UseTimeFile { get; set; }

        /// <summary> Use a separate file for ke values</summary>
        public bool UseKeFile { get; set; }

        /// <summary> How to map the data files</summary>
        public VariableMappings Mappings { get; set; }
    }

}