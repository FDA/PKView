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
    public class SafetyBuilder
    {
        /// <summary> Template used to generate the Safety script</summary>
        private TemplateEngine template;

        /// <summary> Path where Safety template and auxiliary scripts are stored</summary>
        private string templateFolder;

        /// <summary> Output path where Safety scripts and data will be placed</summary>
        private string outputFolder;

        public SafetyBuilder(Analysis IssAnalysis)
        {
            this.template = new TemplateEngine();
            IssMappingSettings IssStudy = IssAnalysis.IssStudy;

            // Location of the template
            this.templateFolder = HostingEnvironment.MapPath(@"~\Content\templates\PkView");
            this.template.TemplatePath = Path.Combine(this.templateFolder, "SafetySummaryPlot.sas");

            int index = IssAnalysis.AnalysisName.IndexOf(".xml");
            string folderName = IssAnalysis.AnalysisName.Substring(0, index);

            // Location where the script will be created
            this.outputFolder = string.Format(
                @"\\{0}\Output Files\PKView\{1}\{2}\{3}\{4}\{5}\{6}\{7}\{8}\{9}",
                iPortalApp.AppServerName,
                Users.GetCurrentUserName(),
                IssStudy.IssProfileName,
                IssStudy.IssNDAName,
                IssStudy.IssSupplementNumber,
                "ISS",
                folderName,
                "Safety Analysis",
                "Summary3Plot",
                "data");
            string scriptName = String.Format("SafetySummaryPlot.sas");
            this.template.OutputPath = Path.Combine(this.outputFolder, scriptName);

        }

        /// <summary>
        /// Create the script in the output folder
        /// </summary>
        public void Create()
        {
            if (Directory.Exists(this.outputFolder))
            {
                if (File.Exists(this.template.OutputPath))
                    File.Delete(this.template.OutputPath);
                File.Copy(this.template.TemplatePath, this.template.OutputPath);
            }

        }
    }
}