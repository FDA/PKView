using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace iPortal.Models.PkView
{
    /// <summary> 
    /// Represents study concentration data 
    /// </summary>
    public class ConcentrationData
    {
        /// <summary> List of normalized time points, mapped from their original values</summary>
        public List<NormalizedTimePoint> NormalizedTimePoints;
        /// <summary> Individual concentrations</summary>
        public List<ConcentrationDataSection> Sections;
    }

    /// <summary>
    /// Represents a single normalized time point with the original value
    /// </summary>
    public class NormalizedTimePoint
    {
        /// <summary> Original string value of the time point</summary>
        public string RawTime;
        /// <summary> Normalized time value</summary>
        public double? NormalizedTime;
    }

    /// <summary>
    /// Represents the individual and mean concentration data of a specific 
    /// data section defined by a cohort, period (parallel studies only),
    /// analyte, specimen and treatment. 
    /// </summary>
    public class ConcentrationDataSection 
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
        public List<ConcentrationDataSubSection> SubSections;
        /// <summary> Mean concentration data</summary>
        public List<MeanConcentrationPoint> Mean;

        /// <summary>
        /// Calculate and store the mean and standard deviation of the individual data
        /// </summary>
        /// <param name="individualData"></param>
        /// <returns></returns>
        public void CalculateMean ()
        {
            var means = this.SubSections
                .SelectMany(s => s.Individual) // get all individual Concentration
                .SelectMany(i => i.Concentration // Get all data points
                    .GroupBy(p => p.NominalTime, (key,g) => g.Last()))  // eliminate duplicate time
                .GroupBy(p => p.NominalTime) // Group by nominal time
                .Where(g => g.Key != null) // Remove null time
                .Select(g =>
                {
                    double mean = 0.0, variance = 0.0, std = 0.0;
                    var g2 = g.Where(p => p.Value.HasValue);
                    var n = g2.Count();

                    // Calculate mean and std
                    if (n > 1)
                    {
                        mean = g2.Average(p => p.Value.Value);
                        variance = g2.Aggregate(0.0, (v, p) => v += Math.Pow(p.Value.Value - mean, 2));
                        variance = variance / (g2.Count() - 1);
                        std = Math.Sqrt(variance);
                    }
                    else if (n == 1) mean = g2.First().Value.Value;

                    return new MeanConcentrationPoint
                    {
                        NominalTime = g.Key,
                        RawTime = g.First().RawTime,
                        Value = mean,
                        StandardDeviation = std
                    };
                }).Where(mean => mean.Value > 0)
                .OrderBy(p => p.NominalTime).ToList();
            this.Mean = means;
        }
    }

    /// <summary>
    /// Represents, in the context of a concentration data section,
    /// the individual concentration data for a specific
    /// period (excluding parallel studies) and arm
    /// </summary>
    public class ConcentrationDataSubSection
    {
        /// <summary> Arm within the cohort</summary>
        public string Arm;
        /// <summary> Study period (null for parallel)</summary>
        public string Period;
        /// <summary> Individual concentration data</summary>
        public List<IndividualConcentration> Individual;
    }

    /// <summary>
    /// Defines a concentration curve for a single individual
    /// </summary>
    public class IndividualConcentration 
    {
        /// <summary>Subject Id</summary>
        public string Subject { get; set; }
        public List<ConcentrationPoint> Concentration { get; set; }
    }

    public class ConcentrationPoint
    {
        /// <summary> If time was derived from a string variable, value of such string</summary>
        public string RawTime;
        /// <summary> Nominal time</summary>
        public double? NominalTime;
        /// <summary> Mean concentration across subjects</summary>
        public double? Value;
    }

    /// <summary> 
    /// Represents a single mean concentration data point
    /// </summary>
    public class MeanConcentrationPoint: ConcentrationPoint
    {
        /// <summary> Standard deviation</summary>
        public double StandardDeviation;
    }
}