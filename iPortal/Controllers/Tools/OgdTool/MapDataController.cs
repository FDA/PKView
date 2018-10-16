using System.Collections.Generic;
using System.Linq;
using System.Web.Http;
using iPortal.Config;
using iPortal.Models.OgdTool;
using System.IO;
using System;
using System.Text.RegularExpressions;
using System.Data;

namespace iPortal.Controllers.OgdTool
{
    /// <summary>
    /// Comparison finder controller
    /// </summary>
    public class MapDataController : ApiController
    {
        private ClinicalDataController fileReader = new ClinicalDataController();

        /// <summary>
        /// Main Get function
        /// </summary>
        /// <returns>A list of results</returns>
        [Route("api/ogdtool/mapComparison"), HttpPost]
        public VariableMappings MapComparison([FromBody]TreatmentComparison comparison)
        {
            return this.mapFiles(comparison);
        }

        /// <summary>
        /// Expand each data file in the comparison into the variable mapping
        /// and lists of variables and array variables
        /// </summary>
        /// <param name="comparison"></param>
        private VariableMappings mapFiles(TreatmentComparison comparison)
        {
            // There is no point in mapping if no concentration file was found
            if (comparison.ConcentrationFile == null) return null;

            // Extract variables for concentration           
            var extendedConc = this.extractVariables(comparison.ConcentrationFile);

            // If no array variables were found in concentration data is useless, return
            if (!extendedConc.ArrayVariables.Any()) return null;

            // Extract variables for pk and time
            var extendedPk = this.extractVariables(comparison.PkFile);
            var extendedTime = comparison.UseTimeFile ? 
                this.extractVariables(comparison.TimeFile) : null;           
                       
            // Compute the list of common variables
            var commonVarNames = extendedPk.Variables.Intersect(extendedConc.Variables);
            var commonVars = commonVarNames.Select(v => new Variable
            {
                Name = v,
                Values = extendedConc.Data.AsEnumerable()
                    .Select(r => r[v].ToString()).Distinct().ToList()
            });
            var mappings = new VariableMappings { CommonVariables = commonVars.ToList() };

            // Add the array variables
            mappings.ArrayVariables = extendedConc.ArrayVariables;
            mappings.ArrayVariables.ForEach(v => v.File = "CONC");
            if (comparison.UseTimeFile)
            {
                extendedTime.ArrayVariables.ForEach(v => v.File = "TIME");
                mappings.ArrayVariables.AddRange(extendedTime.ArrayVariables);
            }
            
            // Map common variables
            mappings.CommonVariableMappings = this.mapCommonVariables(mappings);

            // Map array variables
            mappings.ArrayVariableMappings = this.mapConcentrationVariables(mappings.ArrayVariables);

            return mappings;
        }



        /// <summary>
        /// Retrieve the file data and extract the variables and array variables
        /// </summary>
        /// <param name="extendedFile"></param>
        private ExtendedDataFile extractVariables(DataFile file)
        {
            var extendedFile = new ExtendedDataFile { Path = file.Path };

            // Retrieve file data
            extendedFile.Data = this.fileReader.GetFile(extendedFile.Path);

            // Extract all column names
            var allFileVariables = from DataColumn c in extendedFile.Data.Columns select c.ColumnName;

            // All columns without numbers in the name are definitely non array variables
            var nonArrayVariables = allFileVariables.Where(v => !v.Any(c => char.IsDigit(c))).ToList();
            allFileVariables = allFileVariables.Except(nonArrayVariables);

            // Group variables with numbers by name pattern
            var potentialArrayVariables = allFileVariables.Select(v =>
            {
                var matchedNumber = Regex.Match(v, "[0-9]+");
                var matchIndex = matchedNumber.Index;
                var matchLength = matchedNumber.Length;
                return new
                {
                    pattern = v.Remove(matchIndex, matchLength).Insert(matchIndex, "%NUM%"),
                    number = int.Parse(matchedNumber.Value),
                    original = v
                };
            }).GroupBy(v => v.pattern);
            var arrayVariables = new List<ArrayVariable>();

            // Loop over the potential groups
            foreach (var group in potentialArrayVariables)
            {
                // if the group contains more than one variable, store as array variable   
                if (group.Count() > 1)
                {
                    arrayVariables.Add(new ArrayVariable
                    {
                        Pattern = group.First().pattern,
                        Min = group.Min(v => v.number),
                        Max = group.Max(v => v.number)
                    });
                }
                // Groups with a single variable will be considered non-array variables
                else nonArrayVariables.Add(group.First().original);
            }

            extendedFile.Variables = nonArrayVariables;
            extendedFile.ArrayVariables = arrayVariables;
            return extendedFile;
        }

        /// <summary>
        /// Map the common variables from the names they have in the files
        /// to the names used by the analysis script
        /// </summary>
        /// <param name="mappings"></param>
        /// <returns></returns>
        List<VariableMapping> mapCommonVariables(VariableMappings mappings)
        {
            var mappedVariables = new List<VariableMapping>();
            mappedVariables.Add(new VariableMapping
            {
                TargetVariable = "SUB",
                FileVariable = mapSubjectVariable(mappings.CommonVariables)
            });
            mappedVariables.Add(new VariableMapping
            {
                TargetVariable = "PER",
                FileVariable = mapPeriodVariable(mappings.CommonVariables)
            });
            mappedVariables.Add(new VariableMapping
            {
                TargetVariable = "TRT",
                FileVariable = mapTreatmentVariable(mappings.CommonVariables)
            });
            mappedVariables.Add(new VariableMapping
            {
                TargetVariable = "SEQ",
                FileVariable = mapSequenceVariable(mappings.CommonVariables)
            });

            //Determine if we want to map group
            var groupVar = mapGroupVariable(mappings.CommonVariables);
            if (groupVar != null)
            {
                mappedVariables.Add(new VariableMapping
                {
                    TargetVariable = "SEQ",
                    FileVariable = groupVar
                });
            }

            return mappedVariables;
        }

        private string mapSubjectVariable(List<Variable> variables)
        {
            var found = variables.SingleOrDefault(v => 
                v.Name.StartsWith("SU", StringComparison.CurrentCultureIgnoreCase));
            return found != null ? found.Name : null;
        }
        private string mapPeriodVariable(List<Variable> variables)
        {
            var found = variables.SingleOrDefault(v => 
                v.Name.StartsWith("PER", StringComparison.CurrentCultureIgnoreCase));
            return found != null ? found.Name : null;
        }
        private string mapTreatmentVariable(List<Variable> variables)
        {
            var found = variables.SingleOrDefault(v => 
                v.Name.StartsWith("TR", StringComparison.CurrentCultureIgnoreCase)) ??
                variables.SingleOrDefault(v => 
                    v.Name.StartsWith("PRO", StringComparison.CurrentCultureIgnoreCase)) ??
                variables.SingleOrDefault(v =>
                    v.Name.StartsWith("FOR", StringComparison.CurrentCultureIgnoreCase));
            return found != null ? found.Name : null;
        }
        private string mapSequenceVariable(List<Variable> variables)
        {
            var found = variables.SingleOrDefault(v => 
                v.Name.StartsWith("SEQ", StringComparison.CurrentCultureIgnoreCase));
            return found != null ? found.Name : null;
        }
        private string mapGroupVariable(List<Variable> variables)
        {
            var found = variables.SingleOrDefault(v => 
                v.Name.StartsWith("GR", StringComparison.CurrentCultureIgnoreCase));
            return found != null ? found.Name : null;
        }

        List<VariableMapping> mapConcentrationVariables(List<ArrayVariable> variables)
        {
            var variableMappings = new List<VariableMapping>();
            variableMappings.Add(new VariableMapping
            {
                TargetVariable = "C",
                FileVariable = this.mapConcentrationArrayVariable(variables)
            });
            variableMappings.Add(new VariableMapping
            {
                TargetVariable = "T",
                FileVariable = this.mapTimeArrayVariable(variables)
            });
            return variableMappings;
        }

        private string mapConcentrationArrayVariable(List<ArrayVariable> variables)
        {
            var found = variables.Where(v =>
                v.Pattern.StartsWith("C", StringComparison.CurrentCultureIgnoreCase));
            return found.Any() ? found.First().Pattern : null;
        }

        private string mapTimeArrayVariable(List<ArrayVariable> variables)
        {
            var found = variables.Where(v => 
                v.Pattern.StartsWith("T", StringComparison.CurrentCultureIgnoreCase));
            return found.Any() ? found.First().Pattern : null;
        }
        
    }
}
