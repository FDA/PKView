using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Web;
using iPortal.Models.Shared;
using System.Text.RegularExpressions;
using System.Web.Hosting;

namespace iPortal.Models.PkView.Reports
{
    public class NcaBuilder
    { 
        /// <summary> Template used to generate the NCA script</summary>
        private TemplateEngine template;

        /// <summary> Path where NCA template and auxiliary scripts are stored</summary>
        private string templateFolder;

        /// <summary> Output path where NCA scripts and data will be placed</summary>
        private string outputFolder;

        public NcaBuilder(StudySettings study, Report report)
        {
            this.template = new TemplateEngine();

            // Location of the template
            this.templateFolder = HostingEnvironment.MapPath(@"~\Content\templates\PkView");
            this.template.TemplatePath = Path.Combine(this.templateFolder, "NcaAnalysisTemplate.sas.tpl");

            // Location where the script will be created
            this.outputFolder = string.Format(
                @"\\{0}\Output Files\PKView\{1}\{2}\{3}\{4}\{5}\{6}",
                iPortalApp.AppServerName, 
                Users.GetCurrentUserName(), 
                study.ProfileName, 
                study.NDAName, 
                study.SupplementNumber, 
                study.StudyCode,
                report.Name);
            string scriptName = String.Format("ncaRun_{0}_{1}.sas",
                report.Settings.SelectedPcSpecimen ?? report.Settings.SelectedPpSpecimen ?? "BLOOD",
                report.Settings.SelectedPcAnalyte);
            this.template.OutputPath = Path.Combine(this.outputFolder, scriptName);
            
            // Parameters for the template to customize the script
            this.template.LoadParameters(new 
            {
                SCRIPT_NAME = scriptName,
                GENERATION_DATE = DateTime.Now.ToShortDateString(),
                SUBMISSION = study.NDAName,
                STUDY = study.StudyCode,
                LEVEL = report.Settings.SelectedPcAnalyte,
            });

            // Load pk parameters adding a suffix when they are repeated
            var pkct = new Dictionary<string, int>();
            this.template.LoadParameter("FIRMAUCI", report.Settings.SelectedAucInfinity);
            pkct[report.Settings.SelectedAucInfinity] = 1;
            var pkMap = new Dictionary<string, string> 
            {
               { "FIRMAUCT", report.Settings.SelectedAuct },
               { "FIRMCMAX", report.Settings.SelectedCmax },
               { "FIRMTHALF", report.Settings.SelectedThalf },
               { "FIRMTMAX", report.Settings.SelectedTmax }
            };

            // Load each parameter
            foreach (var mapping in pkMap)
            {
                string firmPk = mapping.Value;
                if (!String.IsNullOrWhiteSpace(firmPk) && pkct.ContainsKey(firmPk)) 
                    firmPk += "__" + pkct[firmPk]++;
                else pkct[firmPk] = 1;
                this.template.LoadParameter(mapping.Key, firmPk);
            }
        }

        /// <summary>
        /// Create the script in the output folder
        /// </summary>
        public void Create()
        {
            this.template.Generate();

            // Create libraries folder
            var libraryFolder = Path.Combine(this.outputFolder, "libraries");
            Directory.CreateDirectory(libraryFolder);

            // Copy macro library
            var macrolibFile = Path.Combine(this.templateFolder, "macrolib.sas");
            var outputMacrolibFile = Path.Combine(libraryFolder, "macrolib.sas");
            if (File.Exists(outputMacrolibFile)) File.Delete(outputMacrolibFile);
            File.Copy(macrolibFile, outputMacrolibFile);
        }
    }
}