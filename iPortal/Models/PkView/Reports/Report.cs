using iPortal.Controllers.PkView;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Web;

namespace iPortal.Models.PkView.Reports
{
    /// <summary>
    /// Represents a report of outputs
    /// </summary>
    public class Report : IEquatable<Report>
    {
        /// <summary> Report name </summary>
        public string Name;
        /// <summary> Report type </summary>
        public int Type;
        /// <summary> True if the actual report has been generated </summary>
        public bool Generated;
        /// <summary> Time of report generation </summary>
        public float BigthanExcludeSD = 0;    
        public float SmallthanExcludeSD = 0;    
        public string ExcludeParameters1 = "";            
        public string ExcludeParameters2 = "";           
        public string ParametersForvariability = "";            
        public string AnalytesForvariability = "";           

        public int percent = 0;          
        
        public DataTable excludedatatable;
        

        public DateTime? CreationDate;
        /// <summary> Report settings specific to this type of report</summary>
        public ReportSettings Settings;

        /// <summary>
        /// Add report settings to the dataset to be sent to SAS
        /// </summary>
        /// <param name="data">dataset where the tables will be added</param>
        /// <param name="study">study this repor relates to</param>
        internal void AddSettingsToDataset(DataSet data, StudySettings study)
        {
            // Report name
            var reportConfig = new DataTable("reportConfig");
            reportConfig.Columns.Add("Name", typeof(string));
            reportConfig.Columns.Add("Value", typeof(string));
            reportConfig.Rows.Add("Name", this.Name);
            data.Tables.Add(reportConfig);

            // exclude subject information   
            var excludesubjectinfo = new DataTable("excludesubject");
            excludesubjectinfo.Columns.Add("BigthanExcludeSD", typeof(float));
            excludesubjectinfo.Columns.Add("SmallthanExcludeSD", typeof(float));
            excludesubjectinfo.Columns.Add("ExcludeParameters1", typeof(string));
            excludesubjectinfo.Columns.Add("ExcludeParameters2", typeof(string));
            excludesubjectinfo.Columns.Add("percent", typeof(int));
            excludesubjectinfo.Rows.Add(
                this.BigthanExcludeSD,
                this.SmallthanExcludeSD,
                this.ExcludeParameters1,
                this.ExcludeParameters2,
                this.percent);
            data.Tables.Add(excludesubjectinfo);

            // exclude edited subject data   
            //this.excludedatatable = null;
            //data.Tables.Add(this.excludedatatable);

            // Add different data tables depending on the type of report
            switch (this.Type)
            {
                case 1: // Pk tables                    
                    addReferencesToDataset(data, study);
                    addAnalytesToDataset(data);
                    addParametersToDataset(data);
                    addStatisticalMethodToDataset(data);
                    addPkSortingOptionsToDataset(data);
                    break;
                case 2: // Forest plots
                    addReferencesToDataset(data, study);
                    addAnalytesToDataset(data);
                    addParametersToDataset(data);
                    addStatisticalMethodToDataset(data);
                    addPkSortingOptionsToDataset(data);
                    break;
                case 3: // NCA Analysis
                    addConcentrationToDataset(data, study);
                    addPharmacokineticsToDataset(data, study);
                    break;
            }
        }

        /// <summary>
        /// Add Excluded data to the dataset to be sent to SAS
        /// </summary>
        /// <param name="data">dataset where the tables will be added</param>
        /// <param name="study">study this repor relates to</param>
        internal void AddExcludedataToDataset(DataSet data, StudySettings study)
        {
            

            // exclude data   

            var excludedata = new DataTable("Excludedata");
            excludedata = study.excludedatatable;
            excludedata.TableName = "Excludedata";


            for (int i = excludedata.Rows.Count - 1; i >= 0; i--)
            {
                DataRow dr = excludedata.Rows[i];
                if (study.ExcludeIndex[i] == "False")
                    dr.Delete();
            }
            excludedata.AcceptChanges();

            data.Tables.Add(excludedata);
        }

        /// <summary>
        /// Add report settings to the dataset to be sent to SAS
        /// </summary>
        /// <param name="data">dataset where the tables will be added</param>
        /// <param name="study">study this repor relates to</param>

 

        internal void AddMetaSettingsToDataset(DataSet data, StudySettings study,string StudyCode)
        {
            // Report name
            var reportConfig = new DataTable("reportConfig");
            reportConfig.Columns.Add("Name", typeof(string));
            reportConfig.Columns.Add("Value", typeof(string));
            reportConfig.Columns.Add("StudyCode", typeof(string));
            reportConfig.Rows.Add("Name", this.Name, StudyCode);
            data.Tables.Add(reportConfig);

            // exclude subject information   
            var excludesubjectinfo = new DataTable("excludesubject");
            excludesubjectinfo.Columns.Add("BigthanExcludeSD", typeof(float));
            excludesubjectinfo.Columns.Add("SmallthanExcludeSD", typeof(float));
            excludesubjectinfo.Columns.Add("ExcludeParameters1", typeof(string));
            excludesubjectinfo.Columns.Add("ExcludeParameters2", typeof(string));
            excludesubjectinfo.Columns.Add("percent", typeof(int));
            excludesubjectinfo.Rows.Add(
                this.BigthanExcludeSD,
                this.SmallthanExcludeSD,
                this.ExcludeParameters1,
                this.ExcludeParameters2,
                this.percent);
            data.Tables.Add(excludesubjectinfo);

            // exclude edited subject data   
            //this.excludedatatable = null;
            //data.Tables.Add(this.excludedatatable);

            // Add different data tables depending on the type of report
            this.Type = 2;
            switch (this.Type)
            {
                case 1: // Pk tables                    
                    addReferencesToDataset(data, study);
                    addAnalytesToDataset(data);
                    addParametersToDataset(data);
                    addStatisticalMethodToDataset(data);
                    addPkSortingOptionsToDataset(data);
                    break;
                case 2: // Forest plots
                    addMetaReferencesToDataset(data, study, StudyCode);
                    addMetaAnalytesToDataset(data, StudyCode);
                    addMetaParametersToDataset(data, StudyCode);
                    addMetaStatisticalMethodToDataset(data, StudyCode);
                    addMetaPkSortingOptionsToDataset(data, StudyCode);
                    break;
                case 3: // NCA Analysis
                    addConcentrationToDataset(data, study);
                    addPharmacokineticsToDataset(data, study);
                    break;
            }
        }



        /// <summary>
        /// Add report settings to the dataset to be sent to SAS
        /// </summary>
        /// <param name="data">dataset where the tables will be added</param>
        /// <param name="study">study this repor relates to</param>



        internal void AddVariabilityMetaSettingsToDataset(DataSet data, StudySettings study, string StudyCode)
        {
            // Report name
            var reportConfig = new DataTable("reportConfig");
            reportConfig.Columns.Add("Name", typeof(string));
            reportConfig.Columns.Add("Value", typeof(string));
            reportConfig.Columns.Add("StudyCode", typeof(string));
            reportConfig.Rows.Add("Name", this.Name, StudyCode);
            data.Tables.Add(reportConfig);

            // exclude subject information   
            var excludesubjectinfo = new DataTable("excludesubject");
            excludesubjectinfo.Columns.Add("BigthanExcludeSD", typeof(float));
            excludesubjectinfo.Columns.Add("SmallthanExcludeSD", typeof(float));
            excludesubjectinfo.Columns.Add("ExcludeParameters1", typeof(string));
            excludesubjectinfo.Columns.Add("ExcludeParameters2", typeof(string));
            excludesubjectinfo.Columns.Add("percent", typeof(int));
            excludesubjectinfo.Rows.Add(
                this.BigthanExcludeSD,
                this.SmallthanExcludeSD,
                this.ExcludeParameters1,
                this.ExcludeParameters2,
                this.percent);
            data.Tables.Add(excludesubjectinfo);

            // Add different data tables depending on the type of report
            this.Type = 2;
            switch (this.Type)
            {
                case 1: // Pk tables                    
                    addReferencesToDataset(data, study);
                    addAnalytesToDataset(data);
                    addParametersToDataset(data);
                    addStatisticalMethodToDataset(data);
                    addPkSortingOptionsToDataset(data);
                    break;
                case 2: // Forest plots
                    addMetaReferencesToDataset(data, study, StudyCode);
                    addVariabilityMetaAnalytesToDataset(data, StudyCode);
                    addVariabilityMetaParametersToDataset(data, StudyCode);
                    addMetaStatisticalMethodToDataset(data, StudyCode);
                    addMetaPkSortingOptionsToDataset(data, StudyCode);
                    break;
                case 3: // NCA Analysis
                    addConcentrationToDataset(data, study);
                    addPharmacokineticsToDataset(data, study);
                    break;
            }
        }
        private void addReferencesToDataset(DataSet data, StudySettings study)
        {
            if (this.Settings.References == null || study.Cohorts == null) return;

            var references = new DataTable("references");
            references.Columns.Add("Cohort", typeof(string));
            references.Columns.Add("Number", typeof(int));
            references.Columns.Add("Reference", typeof(string));

            // Merge with study cohorts list to obtain the cohort number
            var cohortReferences = this.Settings.References.Join(study.Cohorts, c1 => c1.Cohort, c2 => c2.Name,
                (c1, c2) => new Cohort { Name = c2.Name, Number = c2.Number, Reference = c1.Reference });

            foreach (var cohort in cohortReferences)
                references.Rows.Add(
                    cohort.Name,
                    cohort.Number,
                    cohort.Reference);

            if (data.Tables.Contains("references"))
                data.Tables.Remove("references");
            data.Tables.Add(references);
        }
        private void addMetaReferencesToDataset(DataSet data, StudySettings study,string StudyCode)
        {
            if (this.Settings.References == null || study.Cohorts == null) return;

            var references = new DataTable("references");
            references.Columns.Add("Cohort", typeof(string));
            references.Columns.Add("Number", typeof(int));
            references.Columns.Add("Reference", typeof(string));
            references.Columns.Add("StudyCode", typeof(string));

            // Merge with study cohorts list to obtain the cohort number
            var cohortReferences = this.Settings.References.Join(study.Cohorts, c1 => c1.Cohort, c2 => c2.Name,
                (c1, c2) => new Cohort { Name = c2.Name, Number = c2.Number, Reference = c1.Reference });

            foreach (var cohort in cohortReferences)
                references.Rows.Add(
                    cohort.Name,
                    cohort.Number,
                    cohort.Reference,
                    StudyCode);


            if (data.Tables.Contains("references"))
                data.Tables.Remove("references");
            data.Tables.Add(references);


        }
        private void addParametersToDataset(DataSet data)
        {
            // Selected pk parameters
            var selectedParameters = new DataTable("parameter");
            selectedParameters.Columns.Add("parameter", typeof(string));
            if (this.Settings.Parameters != null)
                foreach (var parameter in this.Settings.Parameters)
                    selectedParameters.Rows.Add(parameter);
            data.Tables.Add(selectedParameters);
        }
       
        private void addMetaParametersToDataset(DataSet data,String StudyCode)
        {
            // Selected pk parameters
            var selectedParameters = new DataTable("parameter");
            selectedParameters.Columns.Add("parameter", typeof(string));
            selectedParameters.Columns.Add("StudyCode", typeof(string));

            if (this.Settings.Parameters != null)
                foreach (var parameter in this.Settings.Parameters)
                    selectedParameters.Rows.Add(parameter, StudyCode);
            data.Tables.Add(selectedParameters);
        }


        private void addVariabilityMetaParametersToDataset(DataSet data, String StudyCode)
        {
            // Selected pk parameters
            var selectedParameters = new DataTable("parameter");
            selectedParameters.Columns.Add("parameter", typeof(string));
            selectedParameters.Columns.Add("StudyCode", typeof(string));

            if (ParametersForvariability != null)
                selectedParameters.Rows.Add(ParametersForvariability, StudyCode);

            data.Tables.Add(selectedParameters);
        }
        private void addAnalytesToDataset(DataSet data)
        {
            // Selected analytes
            var selectedAnalytes = new DataTable("analyte");
            selectedAnalytes.Columns.Add("analyte", typeof(string));
            if (this.Settings.Analytes != null)
                foreach (var analyte in this.Settings.Analytes)
                    selectedAnalytes.Rows.Add(analyte);
            data.Tables.Add(selectedAnalytes);
        }
        private void addMetaAnalytesToDataset(DataSet data,string StudyCode)
        {
            // Selected analytes
            var selectedAnalytes = new DataTable("analyte");
            selectedAnalytes.Columns.Add("analyte", typeof(string));
            selectedAnalytes.Columns.Add("StudyCode", typeof(string));

            if (this.Settings.Analytes != null)
                foreach (var analyte in this.Settings.Analytes)
                    selectedAnalytes.Rows.Add(analyte, StudyCode);
            data.Tables.Add(selectedAnalytes);
        }
        private void addVariabilityMetaAnalytesToDataset(DataSet data, string StudyCode)
        {
            // Selected analytes
            var selectedAnalytes = new DataTable("analyte");
            selectedAnalytes.Columns.Add("analyte", typeof(string));
            selectedAnalytes.Columns.Add("StudyCode", typeof(string));
            if (AnalytesForvariability != null)
            selectedAnalytes.Rows.Add(AnalytesForvariability, StudyCode);
            data.Tables.Add(selectedAnalytes);
        }
        private void addStatisticalMethodToDataset(DataSet data)
        {
            // Selected statistical method
            var statisticalMethod = new DataTable("method");
            statisticalMethod.Columns.Add("method", typeof(string));
            statisticalMethod.Rows.Add(this.Settings.Method);
            data.Tables.Add(statisticalMethod);
        }

        private void addMetaStatisticalMethodToDataset(DataSet data, String StudyCode)
        {
            // Selected statistical method
            var statisticalMethod = new DataTable("method");
            statisticalMethod.Columns.Add("method", typeof(string));
            statisticalMethod.Columns.Add("StudyCode", typeof(string));
            statisticalMethod.Rows.Add(this.Settings.Method, StudyCode);
            data.Tables.Add(statisticalMethod);
        }
        

        private void addPkSortingOptionsToDataset(DataSet data)
        {
            // Selected analytes
            var sortingOptions = new DataTable("sort");
            sortingOptions.Columns.Add("level", typeof(string));
            sortingOptions.Columns.Add("sortOrder", typeof(string));
            var sortSettings = this.Settings.Sorting;
            if (this.Settings.Sorting.Files != null)
                sortingOptions.Rows.Add("files",
                    sortSettings.Files.Count < 1 ? "" :
                        sortSettings.Files.Aggregate((a, s) => a + ',' + s));
            if (this.Settings.Sorting.Folders != null)
                sortingOptions.Rows.Add("folders",
                    sortSettings.Folders.Count < 1 ? "" :
                        sortSettings.Folders.Aggregate((a, s) => a + ',' + s));
            if (this.Settings.Sorting.Columns != null)
                sortingOptions.Rows.Add("columns",
                    sortSettings.Columns.Count < 1 ? "" :
                        sortSettings.Columns.Aggregate((a, s) => a + ',' + s));
            data.Tables.Add(sortingOptions);
        }
        private void addMetaPkSortingOptionsToDataset(DataSet data,String StudyCode)
        {
            // Selected analytes
            var sortingOptions = new DataTable("sort");
            sortingOptions.Columns.Add("level", typeof(string));
            sortingOptions.Columns.Add("sortOrder", typeof(string));
            sortingOptions.Columns.Add("StudyCode", typeof(string));

            var sortSettings = this.Settings.Sorting;
            if (this.Settings.Sorting.Files != null)
                sortingOptions.Rows.Add("files",
                    sortSettings.Files.Count < 1 ? "" :
                        sortSettings.Files.Aggregate((a, s) => a + ',' + s), StudyCode);
            if (this.Settings.Sorting.Folders != null)
                sortingOptions.Rows.Add("folders",
                    sortSettings.Folders.Count < 1 ? "" :
                        sortSettings.Folders.Aggregate((a, s) => a + ',' + s), StudyCode);
            if (this.Settings.Sorting.Columns != null)
                sortingOptions.Rows.Add("columns",
                    sortSettings.Columns.Count < 1 ? "" :
                        sortSettings.Columns.Aggregate((a, s) => a + ',' + s), StudyCode);
            data.Tables.Add(sortingOptions);
        }
        /// <summary>
        /// Add the concentration data table to the SAS input, already subset by the UI options
        /// </summary>
        /// <param name="data"></param>
        /// <param name="study"></param>
        private void addConcentrationToDataset(DataSet data, StudySettings study)
        {
            var concentration = new DataTable("concentration");

            concentration.Columns.Add("Result", typeof(double));
            concentration.Columns.Add("NominalTime", typeof(double));
            concentration.Columns.Add("Treatment", typeof(string));
            concentration.Columns.Add("Specimen", typeof(string));
            concentration.Columns.Add("Analyte", typeof(string));
            concentration.Columns.Add("Period", typeof(string));
            concentration.Columns.Add("Arm", typeof(string));
            concentration.Columns.Add("Cohort", typeof(string));
            concentration.Columns.Add("Subject", typeof(string));

            // Load individual concentration from xml file (FIXME)
            var fullStudy = new MappingController().LoadStudy(study.NDAName, study.ProfileName,
                study.SupplementNumber, study.StudyCode, null, true);

            // Find the subset of selected curves
            string period = this.Settings.SelectedPeriod;
            string specimen = this.Settings.SelectedPcSpecimen;
            if (period == "noPeriod") period = null;
            if (specimen == "noSpecimen") specimen = null;
            var selectedSections = fullStudy.Concentration.Sections.Where(s =>
                s.Cohort == this.Settings.SelectedCohort &&
                s.Analyte == this.Settings.SelectedPcAnalyte &&
                s.Period == period && s.Specimen == specimen);

            // Add the concentration curves to the table 
            foreach (ConcentrationDataSection section in selectedSections)
            {
                foreach (ConcentrationDataSubSection subsection in section.SubSections)
                {
                    foreach (IndividualConcentration individual in subsection.Individual)
                    {
                        var curvePoints = individual.Concentration;

                        // trim the curve to the selected range if a range is found
                        if (this.Settings.StartTime.HasValue && this.Settings.EndTime.HasValue)
                            curvePoints = curvePoints.Where(p =>
                                p.NominalTime >= this.Settings.StartTime.Value &&
                                 p.NominalTime <= this.Settings.EndTime.Value).ToList();

                        // Add each point in the curve to the dataset
                        foreach (var point in curvePoints)
                        {
                            concentration.Rows.Add(
                                point.Value.HasValue ? (object)point.Value.Value : DBNull.Value,
                                point.NominalTime.HasValue ? (object)point.NominalTime.Value : DBNull.Value,
                                section.TreatmentOrGroup,
                                section.Specimen ?? "",
                                section.Analyte,
                                subsection.Period ?? section.Period ?? "",
                                subsection.Arm ?? "",
                                section.Cohort,
                                individual.Subject);
                        }
                    }
                }
            }

            data.Tables.Add(concentration);
        }

        /// <summary>
        /// Add the pk data to the SAS input, already subset by the UI options
        /// </summary>
        /// <param name="data"></param>
        private void addPharmacokineticsToDataset(DataSet data, StudySettings study)
        {
            var pharmacokinetics = new DataTable("pharmacokinetics");

            pharmacokinetics.Columns.Add("Selected", typeof(string));
            pharmacokinetics.Columns.Add("Result", typeof(double));
            pharmacokinetics.Columns.Add("Parameter", typeof(string));
            pharmacokinetics.Columns.Add("Treatment", typeof(string));
            pharmacokinetics.Columns.Add("Specimen", typeof(string));
            pharmacokinetics.Columns.Add("Analyte", typeof(string));
            pharmacokinetics.Columns.Add("Period", typeof(string));
            pharmacokinetics.Columns.Add("Arm", typeof(string));
            pharmacokinetics.Columns.Add("Cohort", typeof(string));
            pharmacokinetics.Columns.Add("Subject", typeof(string));

            // Load individual concentration from xml file
            var fullStudy = new MappingController().LoadStudy(study.NDAName, study.ProfileName,
                study.SupplementNumber, study.StudyCode, null, true);

            // Find the subset of selected pk
            string period = this.Settings.SelectedPeriod;
            string specimen = this.Settings.SelectedPpSpecimen;
            if (period == "noPeriod") period = null;
            if (specimen == "noSpecimen") specimen = null;
            var selectedSections = fullStudy.Pharmacokinetics.Sections.Where(s =>
                s.Cohort == this.Settings.SelectedCohort &&
                s.Analyte == this.Settings.SelectedPpAnalyte &&
                s.Period == period && s.Specimen == specimen);

            // Create a dictionary of pk parameter mappings
            var pkParameterMappings = new Dictionary<string, List<string>>();
            addParameterSelectionToTable(pkParameterMappings, this.Settings.SelectedAuct, "AUCT");
            addParameterSelectionToTable(pkParameterMappings, this.Settings.SelectedAucInfinity, "AUCI");
            addParameterSelectionToTable(pkParameterMappings, this.Settings.SelectedCmax, "CMAX");
            addParameterSelectionToTable(pkParameterMappings, this.Settings.SelectedThalf, "THALF");
            addParameterSelectionToTable(pkParameterMappings, this.Settings.SelectedTmax, "TMAX");

            // Add the pk data to the table 
            foreach (PkDataSection section in selectedSections)
            {
                foreach (PkDataSubSection subsection in section.SubSections)
                {
                    foreach (IndividualPk individual in subsection.Individual)
                    {
                        // Add each value to the dataset
                        foreach (var pkValue in individual.PkValues)
                        {
                            // Add one row for each selection of the pk parameter or one row with empty selection
                            List<string> selections;
                            if (!pkParameterMappings.TryGetValue(pkValue.Parameter, out selections))
                                selections = new List<string> { "" };
                            string suffix = ""; int i = 1;
                            foreach (var selection in selections)
                            {
                                pharmacokinetics.Rows.Add(
                                    selection,
                                    pkValue.Value.HasValue ? (object)pkValue.Value.Value : DBNull.Value,
                                    pkValue.Parameter + suffix,
                                    section.TreatmentOrGroup,
                                    section.Specimen ?? "",
                                    section.Analyte,
                                    subsection.Period ?? section.Period ?? "",
                                    subsection.Arm ?? "",
                                    section.Cohort,
                                    individual.Subject);

                                suffix = "__" + i++;
                            }
                        }
                    }
                }
            }

            data.Tables.Add(pharmacokinetics);
        }

        public override bool Equals(object obj)
        {
            return this.Equals(obj as Report);
        }

        public bool Equals(Report other)
        {
            if (other == null) return false;

            // Check if report types match first of all
            if (this.Type != other.Type) return false;

            // Since creation date is recorded to the millisecond, it is really unlikely that two 
            // reports with the exact same name and date are actually different
            bool fastEqual = this.Name == other.Name && this.CreationDate == other.CreationDate;

            // only and only if the check above is false, we proceed to check if the settings match
            if (fastEqual) return true;

            // If both null they are equal
            if (this.Settings == null && other.Settings == null) return true;
            // If any of them null, the other is not, so return not equal
            if (this.Settings == null || other.Settings == null) return false;
            // Compare settings
            return this.Settings.Equals(other.Settings);
        }

        public override int GetHashCode()
        {
            int hash;

            unchecked
            {
                hash = this.Settings.GetHashCode();
                hash = hash * 31 + (Name == null ? 0 : Name.GetHashCode());
                hash = hash * 31 + Type;
                hash = hash * 31 + (Generated ? 1 : 0);
                hash = hash * 31 + (CreationDate == null ? 0 : CreationDate.GetHashCode());
            }
            return hash;
        }

        // Horrible implementation (FIXME)
        private void addParameterSelectionToTable(IDictionary<string, List<string>> table, string firmParameter, string fdaParameter)
        {
            if (!table.ContainsKey(firmParameter))
                table[firmParameter] = new List<string> { fdaParameter };
            else table[firmParameter].Add(fdaParameter);
        }
    }
}
