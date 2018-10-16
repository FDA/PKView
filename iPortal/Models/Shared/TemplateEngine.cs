using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Web;
using System.Text.RegularExpressions;
using System.Web.Hosting;
using System.Reflection;

namespace iPortal.Models.Shared
{
    public class TemplateEngine
    { 
        /// <summary>
        /// Template folder
        /// </summary>
        public string TemplatePath { get; set; }

        /// <summary>
        /// Output script path
        /// </summary>
        public string OutputPath { get; set; }

        /// <summary>
        /// Dictionary of script parameters
        /// </summary>
        private Dictionary<string,string> parameterDictionary = new Dictionary<string, string>();

        /// <summary>
        /// Creates a new template engine
        /// </summary>
        /// <param name="submissionId">submission Id</param>
        /// <param name="projectName">project name</param>
        /// <param name="comparison">analysis inputs for the comparison</param>
        public TemplateEngine() { }

        /// <summary>
        /// Load object fields as script parameters
        /// </summary>
        /// <param name="data"></param>
        public void LoadParameters(object data)
        {
            foreach(FieldInfo x in data.GetType().GetFields())
                this.LoadParameter(x.Name, x.GetValue(data));
            foreach (PropertyInfo x in data.GetType().GetProperties())
                this.LoadParameter(x.Name, x.GetValue(data));
        }

        public void LoadParameter(string key, object value) {
            this.parameterDictionary.Add(key, (value ?? (object)"").ToString());
        }

        /// <summary>
        /// Create the script in the output folder
        /// </summary>
        public void Generate()
        {
            var tokenRegex = new Regex(@"\{@([^@{}]*)@\}");
            string line;

            using (var template = new StreamReader(this.TemplatePath))
            {
                using (var script = new StreamWriter(this.OutputPath))
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
    }
}