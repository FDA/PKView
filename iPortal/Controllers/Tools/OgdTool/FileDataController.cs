using System.Collections.Generic;
using System.Linq;
using System.Web.Http;
using iPortal.Config;
using iPortal.Models.OgdTool;
using System.IO;
using System;
using iPortal.Models.Shared;
using System.Text.RegularExpressions;
using System.Data;

namespace iPortal.Controllers.OgdTool
{
    /// <summary>
    /// This controller retieves data from study files
    /// </summary>
    /// 
    public class FileDataController : ApiController
    {

        /// <summary>
        /// Main Get function
        /// </summary>
        /// <returns>A list of results</returns>
        [Route("api/ogdtool/getNominalTimes"), HttpPost]
        public IEnumerable<VariableValue> GetNominalTime([FromBody]ArrayVariable variable)
        {
            // Retrieve time data from file
            var fileReader = new ClinicalDataController();
            var data = fileReader.GetFile(variable.File);

            // Identify time columns using the variable's pattern
            var timeVarRegex = new Regex(variable.Pattern.Replace("%NUM%", "[0-9]+"));
            IEnumerable<DataColumn> timeVariables = from DataColumn c in data.Columns
                where timeVarRegex.IsMatch(c.ColumnName) select c;

            // Initialize dictionary of potential nominal times modes by col index
            IEnumerable<DataRow> timeData = data.AsEnumerable();

            // Calculate nominal time for each time variable
            var nominalTimes = new List<VariableValue>();
            foreach (var timeVariable in timeVariables)
            {
                // Get a list of unique values and their frecquency
                var columnPotentialTimes = timeData
                    .Where(row => row[timeVariable.Ordinal] != DBNull.Value)
                    .Select(row => (double)row[timeVariable.Ordinal])
                    .GroupBy(val => val, (value, grp) => new { value, count = grp.Count()});
                
                // Determine the nominal time by getting the value with highest mode
                int maxCount = 0; double nominalTime = 0.0;
                foreach (var potentialTime in columnPotentialTimes)
                {
                    if (potentialTime.count > maxCount)
                    {
                        maxCount = potentialTime.count;
                        nominalTime = potentialTime.value;
                    }
                }
                nominalTimes.Add(new VariableValue {
                    Variable = timeVariable.ColumnName,
                    Value = nominalTime
                });
            }

            return nominalTimes;
        }
    }
}
