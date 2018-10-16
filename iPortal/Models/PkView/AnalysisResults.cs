using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Web;

namespace iPortal.Models.PkView
{
    /// <summary>
    /// Represents pk and concentration analysis results
    /// </summary>
    public class AnalysisResults
    {
        public string SubmissionId;
        public string SupplementId;
        public string StudyId;
        
        public string User;
        public string Profile;

        public int StudyDesign;
        public List<string> Analytes;
        public List<string> Parameters;

        public ConcentrationData Concentration;
        public PkData Pharmacokinetics;

        /// <summary>
        /// Default constructor
        /// </summary>
        public AnalysisResults() { }

        /// <summary>
        /// Populate the data based on the results dataset
        /// </summary>
        /// <param name="sasResults"></param>
        public AnalysisResults(DataSet sasResults)
        {
            this.storeStudyData(sasResults);
            this.storePkData(sasResults);
            this.storeConcentrationData(sasResults);        
        }

        /// <summary>
        /// Store study information from the dataset
        /// </summary>
        /// <param name="sasResults"></param>
        private void storeStudyData(DataSet sasResults)
        {
            var rawStudyData = sasResults.Tables["study"].AsEnumerable().First();
            var rawUserConfig = sasResults.Tables["userData"].AsEnumerable();

            this.SubmissionId = rawStudyData["Submission"].ToString();
            this.SupplementId = rawStudyData["Supplement"].ToString().Trim(new []{'"'});
            this.StudyId = rawStudyData["StudyCode"].ToString();

            this.StudyDesign = this.objectToInt(rawStudyData["Design"]);

            foreach (var row in rawUserConfig)
            {
                var name = row["Name"].ToString().ToLower();
                if (name == "username") this.User = row["value"].ToString().Trim(new[] { '"' });
                if (name == "profilename") this.Profile = row["value"].ToString().Trim(new[] { '"' });
            }
        }

        /// <summary>
        /// Store the pk data from the dataset
        /// </summary>
        /// <param name="sasResults"></param>
        private void storePkData(DataSet sasResults)
        {
            // Save list of analytes and list of parameters
            this.Analytes = sasResults.Tables["AnalyteList"]
                .AsEnumerable().Select(row => row["Analyte"].ToString()).ToList();
            this.Parameters = sasResults.Tables["ParameterList"]
                .AsEnumerable().Select(row => row["Parameter"].ToString()).ToList();

            // Determine which optional columns are included
            bool hasPeriods = sasResults.Tables["individualPk"].Columns.Contains("Period");
            bool hasSpecimen = sasResults.Tables["individualPk"].Columns.Contains("Specimen");

            // Get individual pk data
            var rawPkData = sasResults.Tables["individualPk"].AsEnumerable();
            var pkValues = rawPkData.Select(row => new
            {
                Subject = row["Subject"].ToString(),
                Cohort = row["Cohort"].ToString(),
                Arm = row["Arm"].ToString(),
                Analyte = row["Analyte"].ToString(),
                TreatmentOrGroup = row["Treatment"].ToString(),
                Parameter = row["Parameter"].ToString(),
                Result = this.objectToNullableDouble(row["Result"]),

                Period = hasPeriods ? row["Period"].ToString() : null,
                Specimen = hasSpecimen ? row["Specimen"].ToString() : null
            });

            this.Pharmacokinetics = new PkData();

            // Get the mean concentration curves
            this.Pharmacokinetics.Sections = pkValues
                .GroupBy(v => new 
                { 
                    v.Cohort, v.Analyte, v.Specimen, v.TreatmentOrGroup,
                    Period = this.StudyDesign == 3 ? v.Period : null
                },
                (key, values) =>
                {
                    var section = new PkDataSection
                    {
                        Cohort = key.Cohort,
                        Period = key.Period,
                        Analyte = key.Analyte,
                        Specimen = key.Specimen,
                        TreatmentOrGroup = key.TreatmentOrGroup,
                        SubSections = values.GroupBy(v => new { v.Arm, v.Period },
                        (key2, values2) => new PkDataSubSection
                        {
                            Arm = key2.Arm,
                            Period = key2.Period,
                            Individual = values2.GroupBy(v => v.Subject)
                                .Select(g => new IndividualPk
                                {
                                    Subject = g.Key,
                                    PkValues = g.Select(v => new PkValuePair
                                    {
                                        Parameter = v.Parameter,
                                        Value = v.Result
                                    }).ToList()
                                }).ToList()
                        }).ToList()
                    };
                    section.FindPkParameters();
                    return section;
                }).ToList();
        }

        /// <summary>
        /// Store the concentration data from the dataset
        /// </summary>
        /// <param name="sasResults"></param>
        private void storeConcentrationData(DataSet sasResults)
        {
            // Determine which optional columns are included
            bool hasOriginalTime = sasResults.Tables["IndividualConcentration"].Columns.Contains("OriginalTime");
            bool hasPeriods = sasResults.Tables["IndividualConcentration"].Columns.Contains("Period");
            bool hasSpecimen = sasResults.Tables["IndividualConcentration"].Columns.Contains("Specimen");

            // Get concentration table            
            var rawConcentation = sasResults.Tables["IndividualConcentration"].AsEnumerable();
            var concentrationValues = rawConcentation.Select(row => new
            {
                Subject = row["Subject"].ToString(),
                Cohort = row["Cohort"].ToString(),
                Arm = row["Arm"].ToString(),
                Analyte = row["Analyte"].ToString(),
                TreatmentOrGroup = row["Treatment"].ToString(),
                Time = this.objectToNullableDouble(row["NominalTime"]),
                Result = this.objectToNullableDouble(row["Result"]),

                OriginalTime = hasOriginalTime ? row["OriginalTime"].ToString() : null,
                Period = hasPeriods ? row["Period"].ToString() : null,
                Specimen = hasSpecimen ? row["Specimen"].ToString() : null
            }).Distinct();

            this.Concentration = new ConcentrationData();

            // Get the table of normalized time points and their original values
            var timeNormalizationRows = concentrationValues.Where(row => row.OriginalTime != null);
            if (timeNormalizationRows.Any())
            {
                this.Concentration.NormalizedTimePoints = timeNormalizationRows
                    .Select(v => new { v.OriginalTime, v.Time })
                    .Distinct()
                    .Select(v => new NormalizedTimePoint
                    {
                        RawTime = v.OriginalTime,
                        NormalizedTime = v.Time
                    }).ToList();
            }
            else this.Concentration.NormalizedTimePoints = null;

            // Get the mean concentration curves
            this.Concentration.Sections = concentrationValues
                .GroupBy(v => new
                {
                    v.Cohort, v.Analyte, v.Specimen, v.TreatmentOrGroup,
                    Period = this.StudyDesign == 3 ? v.Period : null
                },
                (key, values) =>
                {
                    var section = new ConcentrationDataSection
                    {
                        Cohort = key.Cohort,
                        Period = key.Period,
                        Analyte = key.Analyte,
                        Specimen = key.Specimen,
                        TreatmentOrGroup = key.TreatmentOrGroup,
                        SubSections = values.GroupBy(v => new { v.Arm, v.Period },
                        (key2, values2) => new ConcentrationDataSubSection
                        {
                            Arm = key2.Arm,
                            Period = key2.Period,
                            Individual = values2.GroupBy(v => v.Subject)
                                .Select(g => new IndividualConcentration
                                {
                                    Subject = g.Key,
                                    Concentration = g.Select(p => new ConcentrationPoint
                                    {
                                        NominalTime = p.Time,
                                        RawTime = p.OriginalTime,
                                        Value = p.Result
                                    }).OrderBy(p => p.NominalTime).ToList()
                                }).ToList()
                        }).ToList()
                    };
                    section.CalculateMean();
                    return section;
                }).ToList();
        }

        /// <summary>
        ///  Convert a raw object from a DataSet to a double number.
        ///  DBNull will be converted to null.
        /// </summary>
        /// <param name="value">the value to convert</param>
        private double? objectToNullableDouble(object value) {
            if (Convert.IsDBNull(value)) return null;
            if (value == "") return null;
            return (double)Convert.ChangeType(value, typeof(double));
        }

        /// <summary>
        ///  Convert a raw object from a DataSet to a double number.
        ///  DBNull will be converted to zero.
        /// </summary>
        /// <param name="value">the value to convert</param>
        private double objectToDouble(object value)
        {
            return objectToNullableDouble(value).GetValueOrDefault(0);
        }

        /// <summary>
        ///  Convert a raw object from a DataSet to an int number.
        ///  DBNull will be converted to null.
        /// </summary>
        /// <param name="value">the value to convert</param>
        private int? objectToNullableInt(object value)
        {
            if (Convert.IsDBNull(value)) return null;
            return (int)Convert.ChangeType(value, typeof(int));
        }

        /// <summary>
        ///  Convert a raw object from a DataSet to an int number.
        ///  DBNull will be converted to zero.
        /// </summary>
        /// <param name="value">the value to convert</param>
        private int objectToInt(object value)
        {
            return objectToNullableInt(value).GetValueOrDefault(0);
        }
    }
}