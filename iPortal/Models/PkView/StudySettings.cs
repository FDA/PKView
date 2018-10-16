using iPortal.Models.PkView.Reports;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Web;

namespace iPortal.Models.PkView
{

    public class StudySettings
    {
        public DataTable excludedatatable;
        public String[] ExcludeIndex;

        public int RevisionId { get; set; }

        public string NDAName = "";
        public string SupplementNumber = "";
        public string StudyCode = "";
        public string ProfileName = "";

        public int StudyError = 0;

        //code changes to set default value for the following options to 'uncheked'
        //  1. Subject C_T Correlation in report 
        //  2. Demographic table in report
        //  3. Cumulative in report 
        //  4. Scatter Plot in report 
        // changed on 08/03/2017

        public bool Cumulative = false;
        public bool SubjectCTCorrelation = false;
        public bool ScatterPlot = false;
        public bool Demographictable = false;       

        public bool plotAnalysis = false;    

        public String AnalysisMethod = "";    
        public float upperbound = 0;    
        public float lowerbound = 0;     


        public String PlotType = "";    
        public String NormalizedType = "";    
        public float Cutoffupperbound = 0;    
        public float Cutofflowerbound = 0;     
        public String showdistributionornot = "";     
        




        public bool UseEx = true; // Use EX to determine study design by default
        public bool UseExRef = false; // Use Ex to compute the reference
        public bool UseSuppdm = false;
        public bool DisablePcCleanup = false;

        public bool UseCustomArms = false;
        public bool UseCustomPcVisit = false;
        public bool UseCustomPcPctptnum = false;
        public bool UseCustomPpVisit = false;
        public List<MetaCohort> MetaCohorts;
        public List<Dose1> Doses;
        public List<Cohort> Cohorts;
        public List<Domain> StudyMappings;
        public List<ArmMapping> ArmMappings;
        public List<ValueMapping> PcVisitMappings;
        public List<ValueMapping> PcPctptnumMappings;
        public List<ValueMapping> PpVisitMappings;
        
        public List<string> Arms;
        public List<string> PpVisit;
        public List<string> PcVisit;
               
        public List<string> Analytes;
        public List<string> Parameters;

        /// <summary> Concentration data of this study </summary>
        public ConcentrationData Concentration;

        /// <summary> Pk data of this study </summary>
        public PkData Pharmacokinetics;

        /// <summary> User generated reports in this study </summary>
        public List<Report> Reports;        

        // Deprecated
        public List<CohortReferences> References;
        public int StudyDesign = 0;
        public int StudyType = 0; // Intrinsic or Extrinsic

        /// <summary>
        /// Create mapping datasets to use in the sas scripts
        /// </summary>
        /// <param name="noCache"> If true send a timestamp to avoid caching by the server</param>
        /// <returns></returns>
        public DataSet ToMappingDataSet(bool noCache = false)
        {
            var data = new DataSet();


            // Study information
            var studyInfo = new DataTable("study");
            studyInfo.Columns.Add("Submission", typeof(string));
            studyInfo.Columns.Add("Supplement", typeof(string));
            studyInfo.Columns.Add("StudyCode", typeof(string));
            studyInfo.Columns.Add("Type", typeof(int));
            studyInfo.Columns.Add("Design", typeof(int));
            studyInfo.Columns.Add("Cumulative", typeof(int));
            studyInfo.Columns.Add("SubjectCTCorrelation", typeof(int));
            studyInfo.Columns.Add("ScatterPlot", typeof(int));
            studyInfo.Columns.Add("Demographictable", typeof(int));
            studyInfo.Columns.Add("UseEx", typeof(int));            
            studyInfo.Columns.Add("UseSuppdm", typeof(int));
            studyInfo.Columns.Add("DisablePcCleanup", typeof(int));
            studyInfo.Columns.Add("UseCustomArms", typeof(int));
            studyInfo.Columns.Add("UseCustomPcVisit", typeof(int));
            studyInfo.Columns.Add("UseCustomPcPctptnum", typeof(int));
            studyInfo.Columns.Add("UseCustomPpVisit", typeof(int));
            studyInfo.Rows.Add(
                this.NDAName, 
                this.quote(this.SupplementNumber),
                this.StudyCode, 
                this.StudyType, 
                this.StudyDesign,
                this.Cumulative ? 1 : 0,
                this.SubjectCTCorrelation ? 1 : 0,
                this.ScatterPlot ? 1 : 0,
                this.Demographictable ? 1 : 0,
                this.UseEx ? 1:0,
                this.UseSuppdm ? 1:0,
                this.DisablePcCleanup ? 1:0,
                this.UseCustomArms ? 1:0,
                this.UseCustomPcVisit ? 1:0,
                this.UseCustomPcPctptnum ? 1:0,
                this.UseCustomPpVisit ? 1:0);

            // Study mappings
            var studyMapping = new DataTable("mapping");
            studyMapping.Columns.Add("StudyCode", typeof(string));
            studyMapping.Columns.Add("Domain", typeof(string));
            studyMapping.Columns.Add("StdmVar", typeof(string));
            studyMapping.Columns.Add("FileVar", typeof(string));

            foreach (var domain in this.StudyMappings)
            {
                // Skip EX if UseEx is not checked
                if (!UseEx && domain.Type.ToUpper() == "EX") continue;

                // Skip Suppdm if Usesuppdm is not checked
                if (!UseSuppdm && domain.Type.ToUpper() == "SUPPDM") continue;

                // Copy each variable mapping to the table
                foreach (var mapping in domain.DomainMappings)
                {
                    studyMapping.Rows.Add(
                        this.StudyCode,
                        domain.Type,
                        mapping.SdtmVariable,
                        mapping.FileVariable);
                }
            }

            // Arm mappings
            if (this.UseCustomArms)
            {
                var armMapping = new DataTable("customDmArms");
                armMapping.Columns.Add("OldArm", typeof(string));
                armMapping.Columns.Add("NewArm", typeof(string));
                if (this.ArmMappings != null)
                    foreach (var arm in this.ArmMappings)
                        armMapping.Rows.Add(arm.OldArm, arm.NewArm);
                data.Tables.Add(armMapping);
            }

            // PC Visit Mapping
            if (this.UseCustomPcVisit)
            {
                var pcVisitMapping = new DataTable("customPcVisit");
                pcVisitMapping.Columns.Add("OldValue", typeof(string));
                pcVisitMapping.Columns.Add("NewValue", typeof(string));
                if (this.PcVisitMappings != null)
                    foreach (var mapping in this.PcVisitMappings)
                        pcVisitMapping.Rows.Add(mapping.Original, mapping.New);
                data.Tables.Add(pcVisitMapping);
            }

            // PC Tptnum Mapping
            if (this.UseCustomPcPctptnum)
            {
                var pcTptnumMapping = new DataTable("customPcPctptnum");
                pcTptnumMapping.Columns.Add("OldValue", typeof(string));
                pcTptnumMapping.Columns.Add("NewValue", typeof(string));
                if (this.PcPctptnumMappings != null)
                    foreach (var mapping in this.PcPctptnumMappings)
                        pcTptnumMapping.Rows.Add(mapping.Original, mapping.New);
                data.Tables.Add(pcTptnumMapping);
            }

            // PP Visit Mapping
            if (this.UseCustomPpVisit)
            {
                var ppVisitMapping = new DataTable("customPpVisit");
                ppVisitMapping.Columns.Add("OldValue", typeof(string));
                ppVisitMapping.Columns.Add("NewValue", typeof(string));
                if (this.PpVisitMappings != null)
                    foreach (var mapping in this.PpVisitMappings)
                        ppVisitMapping.Rows.Add(mapping.Original, mapping.New);
                data.Tables.Add(ppVisitMapping);
            }

            // Study references
            var references = new DataTable("references");
            references.Columns.Add("Cohort", typeof(string));
            references.Columns.Add("Number", typeof(int));
            references.Columns.Add("Reference", typeof(string));
            if (this.Cohorts != null)
                foreach (var cohort in this.Cohorts)
                    references.Rows.Add(
                        cohort.Name,
                        cohort.Number,
                        cohort.Reference);

            // User settings
            var userName = HttpContext.Current.User.Identity.Name ?? "DEFAULT";
            userName = userName.Substring(userName.LastIndexOfAny(new[] { '/', '\\' }) + 1);
            var userConfig = new DataTable("userConfig");
            userConfig.Columns.Add("Name", typeof(string));
            userConfig.Columns.Add("Value", typeof(string));
            userConfig.Rows.Add("ProfileName", this.quote(this.ProfileName));
            userConfig.Rows.Add("Username", this.quote(userName));
            if (noCache) // If caching is not allowed, send timestamp, otherwise send study settings Hash
                userConfig.Rows.Add("Timestamp", this.quote(DateTime.Now.Ticks.ToString()));
            else userConfig.Rows.Add("Hash", this.quote(NDAHash.GetStudyHash(this.NDAName, this.StudyCode).ToString()));

            data.Tables.Add(studyInfo);
            data.Tables.Add(studyMapping);
            data.Tables.Add(references);
            data.Tables.Add(userConfig);

            return data;
        }


        /// <summary>
        /// Create Meta mapping datasets to use in the sas scripts
        /// </summary>
        /// <param name="noCache"> If true send a timestamp to avoid caching by the server</param>
        /// <returns></returns>
        public DataSet ToMetaMappingDataSet(bool noCache = false)
        {
            var data = new DataSet();
            // meta analysis format information
            var metaformat = new DataTable("metaformat");
            metaformat.Columns.Add("plotAnalysis", typeof(bool));
            metaformat.Columns.Add("AnalysisMethod", typeof(String));
            metaformat.Columns.Add("upperbound", typeof(float));
            metaformat.Columns.Add("lowerbound", typeof(float));
            metaformat.Rows.Add(
                this.plotAnalysis,
                this.AnalysisMethod,
                this.upperbound,
                this.lowerbound);

            // Study information
            var studyInfo = new DataTable("study");
             for (int i = 1; i <= 1; i++)
            {
                studyInfo.Columns.Add("Submission", typeof(string));
            studyInfo.Columns.Add("Supplement", typeof(string));
            studyInfo.Columns.Add("StudyCode", typeof(string));
            studyInfo.Columns.Add("Type", typeof(int));
            studyInfo.Columns.Add("Design", typeof(int));
            studyInfo.Columns.Add("Cumulative", typeof(int));
            studyInfo.Columns.Add("SubjectCTCorrelation", typeof(int));
            studyInfo.Columns.Add("ScatterPlot", typeof(int));
            studyInfo.Columns.Add("Demographictable", typeof(int));
            studyInfo.Columns.Add("UseEx", typeof(int));
            studyInfo.Columns.Add("UseSuppdm", typeof(int));
            studyInfo.Columns.Add("DisablePcCleanup", typeof(int));
            studyInfo.Columns.Add("UseCustomArms", typeof(int));
            studyInfo.Columns.Add("UseCustomPcVisit", typeof(int));
            studyInfo.Columns.Add("UseCustomPcPctptnum", typeof(int));
            studyInfo.Columns.Add("UseCustomPpVisit", typeof(int));
            studyInfo.Rows.Add(
                this.NDAName,
                this.quote(this.SupplementNumber),
                this.StudyCode,
                this.StudyType,
                this.StudyDesign,
                this.Cumulative ? 1 : 0,
                this.SubjectCTCorrelation ? 1 : 0,
                this.ScatterPlot ? 1 : 0,
                this.Demographictable ? 1 : 0,
                this.UseEx ? 1 : 0,
                this.UseSuppdm ? 1 : 0,
                this.DisablePcCleanup ? 1 : 0,
                this.UseCustomArms ? 1 : 0,
                this.UseCustomPcVisit ? 1 : 0,
                this.UseCustomPcPctptnum ? 1 : 0,
                this.UseCustomPpVisit ? 1 : 0);
            }
            
            
            
            // Study mappings
             var studyMapping = new DataTable("mapping");
            studyMapping.Columns.Add("StudyCode", typeof(string));
            studyMapping.Columns.Add("Domain", typeof(string));
            studyMapping.Columns.Add("StdmVar", typeof(string));
            studyMapping.Columns.Add("FileVar", typeof(string));

            foreach (var domain in this.StudyMappings)
            {
                // Skip EX if UseEx is not checked
                if (!UseEx && domain.Type.ToUpper() == "EX") continue;

                // Skip Suppdm if Usesuppdm is not checked
                if (!UseSuppdm && domain.Type.ToUpper() == "SUPPDM") continue;

                // Copy each variable mapping to the table
                foreach (var mapping in domain.DomainMappings)
                {
                    studyMapping.Rows.Add(
                        this.StudyCode,
                        domain.Type,
                        mapping.SdtmVariable,
                        mapping.FileVariable);
                }
            }

            // Arm mappings
            if (this.UseCustomArms)
            {
                var armMapping = new DataTable("customDmArms");
                armMapping.Columns.Add("OldArm", typeof(string));
                armMapping.Columns.Add("NewArm", typeof(string));
                armMapping.Columns.Add("StudyCode", typeof(string));

                if (this.ArmMappings != null)
                    foreach (var arm in this.ArmMappings) {
                        armMapping.Rows.Add(arm.OldArm, arm.NewArm, this.StudyCode);
                    }
                        
                data.Tables.Add(armMapping);
            }

            // PC Visit Mapping
            if (this.UseCustomPcVisit)
            {
                var pcVisitMapping = new DataTable("customPcVisit");
                pcVisitMapping.Columns.Add("OldValue", typeof(string));
                pcVisitMapping.Columns.Add("NewValue", typeof(string));
                pcVisitMapping.Columns.Add("StudyCode", typeof(string));

                if (this.PcVisitMappings != null)
                    foreach (var mapping in this.PcVisitMappings)
                    {
                        pcVisitMapping.Rows.Add(mapping.Original, mapping.New, this.StudyCode);

                    } 

                data.Tables.Add(pcVisitMapping);
            }

            // PC Tptnum Mapping
            if (this.UseCustomPcPctptnum)
            {
                var pcTptnumMapping = new DataTable("customPcPctptnum");
                pcTptnumMapping.Columns.Add("OldValue", typeof(string));
                pcTptnumMapping.Columns.Add("NewValue", typeof(string));
                pcTptnumMapping.Columns.Add("StudyCode", typeof(string));

                if (this.PcPctptnumMappings != null)
                    foreach (var mapping in this.PcPctptnumMappings)
                    {
                        pcTptnumMapping.Rows.Add(mapping.Original, mapping.New, this.StudyCode);
                    }
                data.Tables.Add(pcTptnumMapping);
            }

            // PP Visit Mapping
            if (this.UseCustomPpVisit)
            {
                var ppVisitMapping = new DataTable("customPpVisit");
                ppVisitMapping.Columns.Add("OldValue", typeof(string));
                ppVisitMapping.Columns.Add("NewValue", typeof(string));
                ppVisitMapping.Columns.Add("StudyCode", typeof(string));

                if (this.PpVisitMappings != null)
                    foreach (var mapping in this.PpVisitMappings)
                    {
                        ppVisitMapping.Rows.Add(mapping.Original, mapping.New, this.StudyCode);
                    }
                data.Tables.Add(ppVisitMapping);
            }

            // Study references
            var references = new DataTable("references");
            references.Columns.Add("Cohort", typeof(string));
            references.Columns.Add("Number", typeof(int));
            references.Columns.Add("Reference", typeof(string));
            references.Columns.Add("StudyCode", typeof(string));

            if (this.Cohorts != null)
                foreach (var cohort in this.Cohorts)
                    references.Rows.Add(
                        cohort.Name,
                        cohort.Number,
                        cohort.Reference,
                        this.StudyCode);

            // Merge with study cohorts list to obtain the cohort number

            // Study meta references
            var metareferences = new DataTable("metareferences");
            metareferences.Columns.Add("Cohort", typeof(string));
            metareferences.Columns.Add("Number", typeof(int));
            metareferences.Columns.Add("Reference", typeof(string));
            metareferences.Columns.Add("StudyCode", typeof(string));
            metareferences.Columns.Add("TestCohorts", typeof(string));

            if (this.Cohorts != null)
                    for (int i = 0; i < this.Cohorts.Count; i++) { 
                        //var MetaReferences = this.Cohorts[i].References;
                        var MetaReferences = this.Reports[0].Settings.References[i].MetaCohorts;

                        foreach (var Reference in MetaReferences)
                        metareferences.Rows.Add(
                            this.Cohorts[i].Name,
                            this.Cohorts[i].Number,
                            this.Reports[0].Settings.References[i].Reference,
                            this.StudyCode,
                            Reference);
                    }
                        
            // User settings
            var userName = HttpContext.Current.User.Identity.Name ?? "DEFAULT";
            userName = userName.Substring(userName.LastIndexOfAny(new[] { '/', '\\' }) + 1);
            var userConfig = new DataTable("userConfig");
            userConfig.Columns.Add("Name", typeof(string));
            userConfig.Columns.Add("Value", typeof(string));
            userConfig.Columns.Add("StudyCode", typeof(string));
            userConfig.Rows.Add("ProfileName", this.quote(this.ProfileName),this.StudyCode);
            userConfig.Rows.Add("Username", this.quote(userName),this.StudyCode);
            

            if (noCache) // If caching is not allowed, send timestamp, otherwise send study settings Hash
                userConfig.Rows.Add("Timestamp", this.quote(DateTime.Now.Ticks.ToString()), this.StudyCode);
            else userConfig.Rows.Add("Hash", this.quote(NDAHash.GetStudyHash(this.NDAName, this.StudyCode).ToString()), this.StudyCode);

            data.Tables.Add(studyInfo);
            data.Tables.Add(studyMapping);
            data.Tables.Add(references);
            data.Tables.Add(metareferences);
            data.Tables.Add(userConfig);
            data.Tables.Add(metaformat);

            return data;
        }

        /// <summary>
        /// Create Variability Meta mapping datasets to use in the sas scripts
        /// </summary>
        /// <param name="noCache"> If true send a timestamp to avoid caching by the server</param>
        /// <returns></returns>
        public DataSet ToVariabilityMetaMappingDataSet(bool noCache = false)
        {
            var data = new DataSet();
            // meta analysis format information
            var metaVariabilityformat = new DataTable("metaVariabilityformat");
            metaVariabilityformat.Columns.Add("PlotType", typeof(String));
            metaVariabilityformat.Columns.Add("NormalizedType", typeof(String));
            metaVariabilityformat.Columns.Add("upperbound", typeof(float));
            metaVariabilityformat.Columns.Add("lowerbound", typeof(float));
            metaVariabilityformat.Columns.Add("showdistributionornot", typeof(String));
            metaVariabilityformat.Rows.Add(
                this.PlotType,
                this.NormalizedType,
                this.Cutoffupperbound,
                this.Cutofflowerbound,
                this.showdistributionornot);

            // Study information
            var studyInfo = new DataTable("study");
            for (int i = 1; i <= 1; i++)
            {
                studyInfo.Columns.Add("Submission", typeof(string));
                studyInfo.Columns.Add("Supplement", typeof(string));
                studyInfo.Columns.Add("StudyCode", typeof(string));
                studyInfo.Columns.Add("Type", typeof(int));
                studyInfo.Columns.Add("Design", typeof(int));
                studyInfo.Columns.Add("Cumulative", typeof(int));
                studyInfo.Columns.Add("SubjectCTCorrelation", typeof(int));
                studyInfo.Columns.Add("ScatterPlot", typeof(int));
                studyInfo.Columns.Add("Demographictable", typeof(int));
                studyInfo.Columns.Add("UseEx", typeof(int));
                studyInfo.Columns.Add("UseSuppdm", typeof(int));
                studyInfo.Columns.Add("DisablePcCleanup", typeof(int));
                studyInfo.Columns.Add("UseCustomArms", typeof(int));
                studyInfo.Columns.Add("UseCustomPcVisit", typeof(int));
                studyInfo.Columns.Add("UseCustomPcPctptnum", typeof(int));
                studyInfo.Columns.Add("UseCustomPpVisit", typeof(int));
                studyInfo.Rows.Add(
                    this.NDAName,
                    this.quote(this.SupplementNumber),
                    this.StudyCode,
                    this.StudyType,
                    this.StudyDesign,
                    this.Cumulative ? 1 : 0,
                    this.SubjectCTCorrelation ? 1 : 0,
                    this.ScatterPlot ? 1 : 0,
                    this.Demographictable ? 1 : 0,
                    this.UseEx ? 1 : 0,
                    this.UseSuppdm ? 1 : 0,
                    this.DisablePcCleanup ? 1 : 0,
                    this.UseCustomArms ? 1 : 0,
                    this.UseCustomPcVisit ? 1 : 0,
                    this.UseCustomPcPctptnum ? 1 : 0,
                    this.UseCustomPpVisit ? 1 : 0);
            }



            // Study mappings
            var studyMapping = new DataTable("mapping");
            studyMapping.Columns.Add("StudyCode", typeof(string));
            studyMapping.Columns.Add("Domain", typeof(string));
            studyMapping.Columns.Add("StdmVar", typeof(string));
            studyMapping.Columns.Add("FileVar", typeof(string));

            foreach (var domain in this.StudyMappings)
            {
                // Skip EX if UseEx is not checked
                if (!UseEx && domain.Type.ToUpper() == "EX") continue;

                // Skip Suppdm if Usesuppdm is not checked
                if (!UseSuppdm && domain.Type.ToUpper() == "SUPPDM") continue;

                // Copy each variable mapping to the table
                foreach (var mapping in domain.DomainMappings)
                {
                    studyMapping.Rows.Add(
                        this.StudyCode,
                        domain.Type,
                        mapping.SdtmVariable,
                        mapping.FileVariable);
                }
            }

            // Arm mappings
            if (this.UseCustomArms)
            {
                var armMapping = new DataTable("customDmArms");
                armMapping.Columns.Add("OldArm", typeof(string));
                armMapping.Columns.Add("NewArm", typeof(string));
                armMapping.Columns.Add("StudyCode", typeof(string));

                if (this.ArmMappings != null)
                    foreach (var arm in this.ArmMappings)
                    {
                        armMapping.Rows.Add(arm.OldArm, arm.NewArm, this.StudyCode);
                    }

                data.Tables.Add(armMapping);
            }

            // PC Visit Mapping
            if (this.UseCustomPcVisit)
            {
                var pcVisitMapping = new DataTable("customPcVisit");
                pcVisitMapping.Columns.Add("OldValue", typeof(string));
                pcVisitMapping.Columns.Add("NewValue", typeof(string));
                pcVisitMapping.Columns.Add("StudyCode", typeof(string));

                if (this.PcVisitMappings != null)
                    foreach (var mapping in this.PcVisitMappings)
                    {
                        pcVisitMapping.Rows.Add(mapping.Original, mapping.New, this.StudyCode);

                    }

                data.Tables.Add(pcVisitMapping);
            }

            // PC Tptnum Mapping
            if (this.UseCustomPcPctptnum)
            {
                var pcTptnumMapping = new DataTable("customPcPctptnum");
                pcTptnumMapping.Columns.Add("OldValue", typeof(string));
                pcTptnumMapping.Columns.Add("NewValue", typeof(string));
                pcTptnumMapping.Columns.Add("StudyCode", typeof(string));

                if (this.PcPctptnumMappings != null)
                    foreach (var mapping in this.PcPctptnumMappings)
                    {
                        pcTptnumMapping.Rows.Add(mapping.Original, mapping.New, this.StudyCode);
                    }
                data.Tables.Add(pcTptnumMapping);
            }

            // PP Visit Mapping
            if (this.UseCustomPpVisit)
            {
                var ppVisitMapping = new DataTable("customPpVisit");
                ppVisitMapping.Columns.Add("OldValue", typeof(string));
                ppVisitMapping.Columns.Add("NewValue", typeof(string));
                ppVisitMapping.Columns.Add("StudyCode", typeof(string));

                if (this.PpVisitMappings != null)
                    foreach (var mapping in this.PpVisitMappings)
                    {
                        ppVisitMapping.Rows.Add(mapping.Original, mapping.New, this.StudyCode);
                    }
                data.Tables.Add(ppVisitMapping);
            }

            // Study references
            var references = new DataTable("cohort");
            references.Columns.Add("StudyCode", typeof(string));
            references.Columns.Add("Number", typeof(int));
            references.Columns.Add("Cohort", typeof(string));

            if (this.Cohorts != null)
                foreach (var cohort in this.Cohorts)
                    references.Rows.Add(
                        this.StudyCode,
                        cohort.Number,
                        cohort.Name);

            // Merge with study cohorts list to obtain the cohort number

            // Study meta references
            var metareferences = new DataTable("trtdose");
            metareferences.Columns.Add("StudyCode", typeof(string));
            metareferences.Columns.Add("TrtGrp", typeof(string));
            metareferences.Columns.Add("Dose", typeof(string));
            metareferences.Columns.Add("SelectedCohort", typeof(string));
            metareferences.Columns.Add("Number", typeof(int));
            

            if (this.Cohorts != null)
                for (int i = 0; i < this.Cohorts.Count; i++)
                {
                    var MetaReferences = this.Reports[0].Settings.References[i].MetaCohorts; 
                    var Dose = this.Reports[0].Settings.References[i].Doses;
                    //var Dose1 = this.Reports[0].Settings.References[i].MetaCohortsAndDoses[0].Dose;
                    //var Dose555 = this.Doses[i];
                    foreach (var Reference in MetaReferences) {
                        foreach (var Dosevalue in Dose)
                        {
                            if (Dosevalue.MetaCohort == Reference)
                            {
                                metareferences.Rows.Add(
                                            this.StudyCode,
                                            Dosevalue.MetaCohort,
                                            Dosevalue.value,
                                            this.Cohorts[i].Name,
                                            this.Cohorts[i].Number
                                    );
                            }
                        }
                    }

                        
                }

            // User settings
            var userName = HttpContext.Current.User.Identity.Name ?? "DEFAULT";
            userName = userName.Substring(userName.LastIndexOfAny(new[] { '/', '\\' }) + 1);
            var userConfig = new DataTable("userConfig");
            userConfig.Columns.Add("Name", typeof(string));
            userConfig.Columns.Add("Value", typeof(string));
            userConfig.Columns.Add("StudyCode", typeof(string));
            userConfig.Rows.Add("ProfileName", this.quote(this.ProfileName), this.StudyCode);
            userConfig.Rows.Add("Username", this.quote(userName), this.StudyCode);


            if (noCache) // If caching is not allowed, send timestamp, otherwise send study settings Hash
                userConfig.Rows.Add("Timestamp", this.quote(DateTime.Now.Ticks.ToString()), this.StudyCode);
            else userConfig.Rows.Add("Hash", this.quote(NDAHash.GetStudyHash(this.NDAName, this.StudyCode).ToString()), this.StudyCode);

            data.Tables.Add(studyInfo);
            data.Tables.Add(studyMapping);
            data.Tables.Add(references);
            data.Tables.Add(metareferences);
            data.Tables.Add(userConfig);
            data.Tables.Add(metaVariabilityformat);

            return data;
        }
        /// <summary>
        /// Create datasets to use in the sas scripts for report generation
        /// </summary>
        /// <returns></returns>
        public DataSet ToReportGenerationDataSet(int reportId)
        {
            var data = this.ToMappingDataSet(noCache: true);
            
            // Add the report settings to the dataset
            this.Reports[reportId].AddSettingsToDataset(data, this);
            
            return data;
        }

        /// <summary>
        /// Create datasets to use in the sas scripts for excluded report generation
        /// </summary>
        /// <returns></returns>
        public DataSet ToExcludedReportGenerationDataSet(int reportId)
        {
            var data = this.ToMappingDataSet(noCache: true);

            // Add the report settings to the dataset
            this.Reports[reportId].AddSettingsToDataset(data, this);
            this.Reports[reportId].AddExcludedataToDataset(data, this);

            return data;
        }

        /// <summary>
        /// Create datasets to use in the sas scripts for report generation
        /// </summary>
        /// <returns></returns>
        public DataSet ToMetaAnalysisGenerationDataSet(int reportId)
        {
            
            
            if (this.Reports.Count> 0)
            {
                var data2 = this.ToMetaMappingDataSet(noCache: true);
            // Add the report settings to the dataset
            this.Reports[reportId].AddMetaSettingsToDataset(data2, this,this.StudyCode);

            return data2;
                }
            else return null;
        }

        /// <summary>
        /// Create datasets to use in the sas scripts for report generation
        /// </summary>
        /// <returns></returns>
        public DataSet ToVariabilityMetaAnalysisGenerationDataSet(int reportId)
        {


            if (this.Reports.Count > 0)
            {
                var data2 = this.ToVariabilityMetaMappingDataSet(noCache: true);
                // Add the report settings to the dataset
                this.Reports[reportId].AddVariabilityMetaSettingsToDataset(data2, this, this.StudyCode);

                return data2;
            }
            else return null;
        }

        /// <summary>
        /// Get the hash of the study files stored in disk
        /// </summary>
        /// <param name="path"></param>
        /// <returns></returns>
        public static int GetFilesHash(string path)
        {
            var dir = new System.IO.DirectoryInfo(path);
            return GetClinicalFilesTimestampSignature(dir).GetHashCode();
        }

        private static string GetClinicalFilesTimestampSignature(System.IO.DirectoryInfo folder)
        {
            var clinicalFiles = folder.GetFiles("*.xpt", System.IO.SearchOption.AllDirectories).OrderBy(f => f.FullName);
            var signature = clinicalFiles.Aggregate("", (s, f) => s += f.LastWriteTime.ToString("yyyyMMddHHmmssffff"));
            return signature;
        }

        /// <summary>
        /// Add double quotes to prevent a bug in sas which causes strings to be interpreted as numeric
        /// </summary>
        /// <param name="s"></param>
        /// <returns></returns>
        private string quote(string s) {
            return '\"' + s + '\"';
        }


        /// <summary>
        /// Returns true when the settings of the other study will produce the same output.
        /// This function assumes the other settings refer to the same clinical study
        /// </summary>
        /// <param name="other"></param>
        /// <returns></returns>
        internal bool IsCompatible(StudySettings other)
        {
            if (other == null) return false;

            return this.Cumulative == other.Cumulative
                && this.SubjectCTCorrelation == other.SubjectCTCorrelation
                && this.ScatterPlot == other.ScatterPlot
                && this.Demographictable == other.ScatterPlot
                && this.UseEx == other.UseEx
                && this.UseExRef == other.UseExRef
                && this.UseSuppdm == other.UseSuppdm
                && this.DisablePcCleanup == other.DisablePcCleanup
                && this.UseCustomArms == other.UseCustomArms
                && this.UseCustomPcPctptnum == other.UseCustomPcPctptnum
                && this.UseCustomPcVisit == other.UseCustomPcVisit
                && this.UseCustomPpVisit == other.UseCustomPpVisit
                && this.ArmsCompatible(this.ArmMappings, other.ArmMappings)
                && this.ValuesCompatible(this.PcVisitMappings, other.PcVisitMappings)
                && this.ValuesCompatible(this.PpVisitMappings, other.PpVisitMappings)
                && this.ValuesCompatible(this.PcPctptnumMappings, other.PcPctptnumMappings)
                && this.DomainsCompatible(this.StudyMappings, other.StudyMappings)
                && this.CohortsCompatible(this.Cohorts, other.Cohorts);   
        }

        private bool ArmsCompatible(List<ArmMapping> list1, List<ArmMapping> list2)
        {
            if (list1 == null && list2 == null) return true;
            if (list1 == null || list2 == null) return false;
            if (list1.Count != list2.Count) return false;
            bool mismatch = list1
                .Join(list2, m1 => m1.OldArm, m2 => m2.OldArm, (m1,m2) => new { m1, m2})
                .Any(match => match.m1.NewArm != match.m2.NewArm);
            return !mismatch;
        }

        private bool ValuesCompatible(List<ValueMapping> list1, List<ValueMapping> list2)
        {
            if (list1 == null && list2 == null) return true;
            if (list1 == null || list2 == null) return false;
            if (list1.Count != list2.Count) return false;
            return list1.Select(m => m.Original + m.New).OrderBy(m => m)
                .SequenceEqual(list2.Select(m => m.Original + m.New).OrderBy(m => m));
        }

        private bool DomainMappingsCompatible(List<Mapping> list1, List<Mapping> list2)
        {
            if (list1 == null && list2 == null) return true;
            if (list1 == null || list2 == null) return false;
            if (list1.Count != list2.Count) return false;
            return list1.Select(m => m.SdtmVariable + m.FileVariable).OrderBy(m => m)
                .SequenceEqual(list2.Select(m => m.SdtmVariable + m.FileVariable).OrderBy(m => m));
        }

        private bool DomainsCompatible(List<Domain> list1, List<Domain> list2)
        {
            if (list1 == null && list2 == null) return true;
            if (list1 == null || list2 == null) return false;
            if (list1.Count != list2.Count) return false;
            var matchedDomains = from domain1 in list1
                                 join domain2 in list2
                                 on domain1.Type equals domain2.Type
                                 select new { domain1, domain2 };
            foreach (var m in matchedDomains)
            {
                if (!DomainMappingsCompatible(m.domain1.DomainMappings, m.domain2.DomainMappings))
                    return false;
            }
            return true;

        }
        private bool CohortsCompatible(List<Cohort> list1, List<Cohort> list2)
        {
            if (list1 == null && list2 == null) return true;
            if (list1 == null || list2 == null) return false;
            if (list1.Count != list2.Count) return false;
            return list1.Select(c => c.Name + c.Number + c.StudyDesign + c.Reference).OrderBy(c => c)
                .SequenceEqual(list2.Select(c => c.Name + c.Number + c.StudyDesign + c.Reference).OrderBy(c => c));
        }
    }

    public class list<StudySettings>
    { }
    public class Domain
    {
        public string Type = "";
        public List<Mapping> DomainMappings;
        public List<FileVariable> FileVariables;
        public string FileId;
    }

    public class Mapping
    {
        public string SdtmVariable = "";
        public string FileVariable = "";
        public int MappingQuality;
    }

    public class FileVariable
    {
        public string Name;
        public string Description;
        public string Label;
    }

    // deprecated (still used for ReportSettings)
    public class CohortReferences
    {
        public string Cohort;
        public string Reference;
        public List<string> References;
        public List<Dosevalue> Doses;
        public List<string> MetaCohorts;

    }

    public class Cohort
    {
        public int StudyDesign;
        public int Number;
        public string Name;
        public string Reference;
        public List<string> References;
    }

    public class MetaCohort
    {
        public List<string> References;
    }

    public class Dose1
    {

        public string MetaCohort { get; set; }
        public string value { get; set; }
       
    }

    public class Dosevalue
    {
        public string MetaCohort { get; set; }
        public string value { get; set; }
       
    }

    public class ArmMapping 
    {
        public string OldArm { get; set; }
        public List<string> Treatments { get; set; }
        public string NewArm { get {
            return String.Join("-", this.Treatments.Select(t => (t ?? "").Replace('-', '_')));
        } }
    }

    public class ValueMapping
    {
        public string Original { get; set; }
        public string New { get; set; }
    }
}
