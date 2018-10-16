using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace iPortal.Models.PkView
{
    /// <summary>
    /// Represents study pk data
    /// </summary>
    public class PkData
    {
        public List<PkDataSection> Sections;
    }

    public class PkDataSection
    {
        /// <summary> Cohort name</summary>
        public string Cohort;
        /// <summary> Study period (parallel only)</summary>
        public string Period;
        /// <summary> Measured Analyte </summary>
        public string Analyte;
        /// <summary> Sampled specimen</summary>
        public string Specimen;
        /// <summary> Group or treatment</summary>
        public string TreatmentOrGroup;
        /// <summary> The subsections contain the individual data for every arm/period</summary>
        public List<PkDataSubSection> SubSections;
        /// <summary> List of pk parameters found in this data section</summary>
        public List<string> Parameters;

        /// <summary>
        /// Extract the list of pk parameters from the individual data
        /// </summary>
        public void FindPkParameters() 
        {
            var parameters = new List<string>();
            foreach (var subsection in this.SubSections)
            {
                foreach (var subject in subsection.Individual)
                {
                    foreach (var pkValue in subject.PkValues)
                    {
                        if (!parameters.Contains(pkValue.Parameter))
                            parameters.Add(pkValue.Parameter);
                    }
                }
            }
            this.Parameters = parameters;
        }
    }

    /// <summary>
    /// Represents, in the context of a pk data section, the individual 
    /// pk data for a specific period (excluding parallel studies) and arm
    /// </summary>
    public class PkDataSubSection
    {
        /// <summary> Arm within the cohort</summary>
        public string Arm;
        /// <summary> Study period (null for parallel)</summary>
        public string Period;
        /// <summary> Individual pk data</summary>
        public List<IndividualPk> Individual;
    }

    /// <summary>
    /// Defines the pk values for a single individual and test
    /// </summary>
    public class IndividualPk
    {
        /// <summary>Subject Id</summary>
        public string Subject { get; set; }
        public List<PkValuePair> PkValues { get; set; }
    }

    /// <summary>
    /// Represents a single pk parameter value
    /// </summary>
    public class PkValuePair
    {
        /// <summary> Name of the pk parameter</summary>
        public string Parameter;
        /// <summary> Value</summary>
        public double? Value;
    }
}