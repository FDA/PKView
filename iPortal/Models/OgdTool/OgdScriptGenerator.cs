using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Web;
using iPortal.Models.Shared;
using System.Text.RegularExpressions;
using System.Web.Hosting;

namespace iPortal.Models.OgdTool
{
    public class OgdScriptGenerator
    { 
        /// <summary>
        /// Project name
        /// </summary>
        private string projectName;

        /// <summary>
        /// SubmissionId
        /// </summary>
        private string submissionId;

        /// <summary>
        /// Output folder
        /// </summary>
        private DirectoryInfo outputFolder;

        /// <summary>
        /// Analysis inputs for this treatment comparison
        /// </summary>
        private TreatmentComparison comparison;

        /// <summary>
        /// Dictionary of script parameters
        /// </summary>
        private Dictionary<string,string> parameterDictionary = new Dictionary<string, string>();

        /// <summary>
        /// Template folder
        /// </summary>
        private static string templateFolder = HostingEnvironment.MapPath(@"~\Content\templates\OgdTool");

        /// <summary>
        /// Output folder where the script will be stored
        /// </summary>
        public string OutputFolder { get { return outputFolder.FullName;  } }

        /// <summary>
        /// Creates a new Ogd script generator
        /// </summary>
        /// <param name="submissionId">submission Id</param>
        /// <param name="projectName">project name</param>
        /// <param name="comparison">analysis inputs for the comparison</param>
        public OgdScriptGenerator(string submissionId, string projectName, TreatmentComparison comparison)
        {
            this.submissionId = submissionId;
            this.projectName = projectName;
            this.comparison = comparison;

            // Set some default parameter values
            this.parameterDictionary["MACROLIB_LOCATION"] = @".\MACROLIB.SAS";
            this.parameterDictionary["OUTPUT_LOCATION"] = @".\output";
            this.parameterDictionary["KE_SCRIPT_LOCATION"] = @".\CALCKE.SAS";
            this.parameterDictionary["DATALOADLIB_LOCATION"] = @".\DATALOADLIB.SAS";
        }

        /// <summary>
        /// Create the script in the output folder
        /// </summary>
        public void Create()
        {
            // Get or create output folder
            this.outputFolder = getOrCreateOutputDir();

            // FIXME: trtgroup flag
            this.parameterDictionary["TRT_GRP_FLAG"] = "";
            
            // Submission id and plot labels
            this.parameterDictionary["ANDA"] = this.submissionId;
            this.parameterDictionary["LEVEL"] = this.comparison.Level;
            this.parameterDictionary["DRUG"] = this.comparison.Drug;
            this.parameterDictionary["DOSE"] = this.comparison.Dose;
            this.parameterDictionary["STUDY_TYPE"] = this.comparison.StudyType;
            this.parameterDictionary["AUC_UNITS"] = this.comparison.AucUnits;
            this.parameterDictionary["CMAX_UNITS"] = this.comparison.CmaxUnits;
            this.parameterDictionary["TIME_UNITS"] = this.comparison.TimeUnits;

            setConcentrationFileParameters();
            setPkFileParameters();

            writeScriptFromTemplate();
            copyDependencies();
            copyDatasets();           

            //Create output folder
            outputFolder.CreateSubdirectory("output");
        }

        /// <summary>
        /// Gets or creates the output folder for the tool output
        /// </summary>
        /// <returns>the output folder</returns>
        private DirectoryInfo getOrCreateOutputDir()
        {
            var userNameDest = HttpContext.Current.User.Identity.Name ?? "DEFAULT";
            userNameDest = userNameDest.Substring(userNameDest.LastIndexOfAny(new[] { '/', '\\' }) + 1);

            var outputPath = string.Format(@"\\{0}\Output Files\OgdTool\{1}\{2}\{3}",
               iPortalApp.AppServerName, Users.GetCurrentUserName(), submissionId, projectName);

            var outputFolder = new DirectoryInfo(outputPath);
            if (!outputFolder.Exists)
                outputFolder.Create();

            return outputFolder;
        }

        /// <summary>
        /// Setup parameters related to the loading of the concentration file
        /// </summary>
        private void setConcentrationFileParameters()
        {
            if (this.comparison.ConcentrationFile != null)
            {
                var filename = Path.GetFileName(comparison.ConcentrationFile.Path);
                this.parameterDictionary["CONCENTRATION_FILENAME"] = filename;
            }          

            // FIXME based on mappings
            this.parameterDictionary["CONCENTRATION_SET_PARAMS"] =
                @"(rename=(subj=sub trt=treat seq=sequ))";

            // FIXME based on subjects with missing data
            this.parameterDictionary["CONCENTRATION_SUBJECT_EXCLUSION"] =
                @"if sub=6 then delete;";

            // FIXME based on column contents
            this.parameterDictionary["CONCENTRATION_DATA_TRANSFORMATIONS"] = 
                @"if treat = ""A"" then trt=1;" + Environment.NewLine +
                @"      else trt=2;" + Environment.NewLine + Environment.NewLine +
                @"   if sequ = ""AB"" then seq=1;" + Environment.NewLine +
                @"      else seq=2;" + Environment.NewLine + Environment.NewLine +
                @"   grp=1;";

            // FIXME based on columns
            this.parameterDictionary["CONCENTRATION_SAMPLE_ARRAY"] =
                @"C1, C2, C3, C4, C5, C6, C7, C8, C9, C10, C11, C12, C13, C14, C15, C16, C17, C18, C19, C20, C21, C22, C23, C24, C25";

            this.parameterDictionary["CONCENTRATION_NOMINAL_TIMES"] =
                @"T1=0; T2=0.33; T3=0.66; T4=1.0; T5=1.33;
T6=1.66; T7=2.0; T8=2.25; T9=2.5; T10=2.75; T11=3.00; T12=3.25;
T13=3.5; T14=3.75; T15=4.00; T16=5.00; T17=6.00; T18=8.00; T19=12.00;
T20=16.0; T21=24.0; T22=36.00; T23=48.00; T24=60.00; T25=72.00";

            this.parameterDictionary["TOTAL_SAMPLES"] = "25";
        }

        /// <summary>
        /// Setup parameters related to the loading of the pk file
        /// </summary>
        private void setPkFileParameters()
        {
            if (this.comparison.PkFile != null)
            {
                var filename = Path.GetFileName(comparison.PkFile.Path);
                this.parameterDictionary["PK_FILENAME"] = filename;
            }

            // FIXME based on mappings
            this.parameterDictionary["PK_SET_PARAMS"] =
                @"(rename=(subj=sub trt=treat seq=sequ))";

            // FIXME based on subjects with missing data
            this.parameterDictionary["PK_SUBJECT_EXCLUSION"] =
                @"if sub=6 then delete;";

            // FIXME based on column contents
            this.parameterDictionary["PK_DATA_TRANSFORMATIONS"] =
                @"if treat = ""A"" then trt=1;" + Environment.NewLine +
                @"      else trt=2;" + Environment.NewLine + Environment.NewLine +
                @"   if sequ = ""AB"" then seq=1;" + Environment.NewLine +
                @"      else seq=2;" + Environment.NewLine + Environment.NewLine +
                @"   grp=1;";
        }

        /// <summary>
        /// Write the script using a template
        /// </summary>
        private void writeScriptFromTemplate()
        {
            var templatePath = Path.Combine(OgdScriptGenerator.templateFolder, "twowaycalcke.sas.tpl");
            var scriptPath = Path.Combine(this.outputFolder.FullName, "script.sas");
            var tokenRegex = new Regex(@"@@([^@]*)@@");
            string line;

            using (var template = new System.IO.StreamReader(templatePath))
            {
                using (var script = new System.IO.StreamWriter(scriptPath))
                {
                    while ((line = template.ReadLine()) != null)
                    {
                        line = tokenRegex.Replace(line, m => {
                            if (parameterDictionary.ContainsKey(m.Groups[1].Value))
                                return parameterDictionary[m.Groups[1].Value];
                            else return "#PARAMETER NOT SET#";
                        });

                        script.WriteLine(line);
                    }
                }
            }
        }

        /// <summary>
        /// Copy script dependencies to output folder
        /// </summary>
        private void copyDependencies()
        {
            // List of file dependencies
            var dependencies = new List<string> {
                "CALCKE.SAS", 
                "DATALOADLIB.SAS", 
                "MACROLIB.SAS"
            };

            // Copy each dependency to the output folder
            foreach(string dependency in dependencies)
            {
                var source = Path.Combine(OgdScriptGenerator.templateFolder, dependency);
                var dest = Path.Combine(outputFolder.FullName, dependency);
                File.Copy(source, dest, true);
            }
        }

        private void copyDatasets() 
        {
            // Gather the list of source data sets
            var datasets = new List<string>();
            if (comparison.ConcentrationFile != null) 
                datasets.Add(comparison.ConcentrationFile.Path);
            if (comparison.PkFile != null) 
                datasets.Add(comparison.PkFile.Path);
            if (comparison.UseKeFile && comparison.KeFile != null) 
                datasets.Add(comparison.KeFile.Path);
            if (comparison.UseTimeFile && comparison.TimeFile != null) 
                datasets.Add(comparison.TimeFile.Path);

            // Copy the datasets to the output folder
            foreach (string dataset in datasets)
            {
                if (string.IsNullOrWhiteSpace(dataset)) continue;

                var filename = Path.GetFileName(dataset);
                var dest = Path.Combine(outputFolder.FullName, filename);
                File.Copy(dataset, dest, true);
            }
        }
    }
}