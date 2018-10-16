using System.Data;
using System.Web.Http;
using iPortal.App_Data;
using iPortal.Models;
using SasJobs.ClientLibrary;
using SasJobs.Messages;
using System;
using iPortal.Config;
using System.IO;
using iPortal.Models.Shared;
using System.Collections.Generic;
using System.Linq;

namespace iPortal.Controllers
{
    public class ClinicalDataController : ApiController
    {
        /// <summary>
        /// 
        /// </summary>
        /// <param name="fileId">Id of the file in the database</param>
        /// <returns></returns>
        [HttpGet, Route("api/readxpt/{fileId}")]
        public DataTable Get(int fileId)
        {
            var filepath = "";
            using (var db = new OCPSQLEntities())
            {
                filepath = db.IPORTAL_FILE.Find(fileId).SERVER_PATH;
            }

            return GetFile(filepath);
        }

        /// <summary>
        /// 
        /// </summary>
        /// <param name="fileId">Path of the file in the clinical folder of the server</param>
        /// <returns></returns>
        [HttpPost, Route("api/readxpt")]
        public DataTable GetFile([FromBody] string filepath)
        {
            var completePath = Path.Combine(PkViewConfig.NdaRootFolder,
                filepath.TrimStart(new[] { '\\', '/' }));
            return new ClinicalDataFile(completePath).Data;
        }

        /// <summary>
        /// 
        /// </summary>
        /// <param name="fileId">Path of the file in the clinical folder of the server</param>
        /// <returns></returns>
        [HttpPost, Route("api/data/clinical/fromfile/columns/{colName}/{option}")]
        public IEnumerable<string> GetColumn([FromBody] string filepath, string colName, string option = "default")
        {
            var completePath = Path.Combine(PkViewConfig.NdaRootFolder,
                filepath.TrimStart(new[] { '\\', '/' }));

            var columnData = new ClinicalDataFile(completePath).GetColumn<string>(colName);
            switch (option)
            {
                case "unique": return columnData.Distinct();
                default: return columnData;
            }
        }
    }
}