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
    public class MetaBuilder
    { 
        /// <summary> Template used to generate the Meta script</summary>
        private TemplateEngine template;

        /// <summary> Path where Meta template and auxiliary scripts are stored</summary>
        private string templateFolder;

        /// <summary> Output path where Meta scripts and data will be placed</summary>
        private string outputFolder;

        public MetaBuilder(StudySettings study, Report report)
        {
            this.template = new TemplateEngine();

            // Location of the template
            this.templateFolder = HostingEnvironment.MapPath(@"~\Content\templates\PkView");
            this.template.TemplatePath = Path.Combine(this.templateFolder, "MetaForestPlot.sas");

            // Location where the script will be created
            this.outputFolder = string.Format(
                @"\\{0}\Output Files\PKView\{1}\{2}\{3}\{4}\{5}\{6}",
                iPortalApp.AppServerName, 
                Users.GetCurrentUserName(), 
                study.ProfileName, 
                study.NDAName, 
                study.SupplementNumber,
                "Meta",
                "Package");
            string scriptName = String.Format("MetaForestPlot.sas");
            this.template.OutputPath = Path.Combine(this.outputFolder, scriptName);
          
        }

        /// <summary>
        /// Create the script in the output folder
        /// </summary>
        public void Create()
        {
            if (File.Exists(this.template.OutputPath)) File.Delete(this.template.OutputPath);
            File.Copy(this.template.TemplatePath, this.template.OutputPath);

        }
    }
}