using System;
using System.IO;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web;
using System.Web.Http;
using iPortal.App_Data;
using System.Net.Http.Headers;
using System.Threading.Tasks;
using System.Diagnostics;
using System.Data;
using System.Data.SqlClient;
using System.Data.OleDb;
using iPortal.Models.ForestPlot;
using iPortal.Config;
using iPortal.Models;
using System.Text;
using Excel;
using System.Text.RegularExpressions;

namespace iPortal.Controllers.ForestPlot
{ 
    /// <summary>
    /// This class holds an 
    /// </summary>
    public static class excelReaderExtension {

        /// <summary> Column types </summary>
        public enum ColumnTypes {
            UNKNOWN = 0,
            CATEGORY = 1,
            SUBCATEGORY = 2,
            PARAMETER = 3,
            RATIO = 4,
            LOWERCI = 5,
            UPPERCI = 6,
            COMMENT =7
        };

        /// <summary> Dictionary of aliases to look up </summary>
        private static IDictionary<ColumnTypes,List<string>> aliases = new Dictionary<ColumnTypes,List<string>> {
            { ColumnTypes.UNKNOWN, new List<string>() },
            { ColumnTypes.CATEGORY, new List<string> {"category","factor"} },
            { ColumnTypes.SUBCATEGORY, new List<string> {"subcategory","sub-category","type"} },
            { ColumnTypes.PARAMETER, new List<string> {"parameter","pk"} },
            { ColumnTypes.RATIO, new List<string> {"ratio"} },
            { ColumnTypes.LOWERCI, new List<string> {"lowerci","lower_ci","lratio","l_ratio"} },
            { ColumnTypes.UPPERCI, new List<string> {"upperci","upper_ci","uratio","u_ratio"} },
            { ColumnTypes.COMMENT, new List<string> {"comment","comments"} },
        };

        /// <summary>
        /// Extension method to get the cell value for the specified column, 
        /// falling back to the fallback position if the column is not found by name
        /// </summary>
        /// <param name="reader"></param>
        /// <param name="column"></param>
        /// <returns></returns>
        public static string GetColumnValue(this DataRow row, ColumnTypes column)
        {
            // Try to get column value by name
            foreach(var name in aliases[column])
                if (row.Table.Columns.Contains(name))
                    return row[name].ToString();

            // If we did not succeed, get it by fallback position, this will only work if 
            // The fields are in proper order
            return row[((int)column) - 1].ToString();
        }
    }

    public class UploadFileController : ApiController
    {
        [HttpPost, Route("api/forestplot/uploadfile")]
        public async Task<HttpResponseMessage> Post()
        {
            int? projectId = null;

            // check if the request contains multipart / form-data.
            if (!Request.Content.IsMimeMultipartContent())
                throw new HttpResponseException(HttpStatusCode.UnsupportedMediaType);

            var provider = new InMemoryMultipartFormDataStreamProvider();                         

            // Read the form data and return an async task.
            await Request.Content.ReadAsMultipartAsync(provider);

            // Throw exception if the project name is null 
            var projectName = provider.FormData["projectName"];  
            if ( string.IsNullOrWhiteSpace(projectName) || projectName == "null" ) throw new Exception();

            // Read file name and stream
            string filename = provider.Contents.FirstOrDefault().Headers.ContentDisposition.FileName.Trim('\"');
            var fileStream = new MemoryStream();
            provider.Contents.FirstOrDefault().ReadAsStreamAsync().Result.CopyTo(fileStream);

            //  Using LINQ to SQL to insert excel data into database
            using (var fpContext = new OCPSQLEntities())
            {
                if (fpContext.SYSTEM_USER.Any(u => u.USER_NAME == User.Identity.Name))
                {
                    var user = fpContext.SYSTEM_USER.SingleOrDefault(u => u.USER_NAME == User.Identity.Name);
                    //  Insert new project data into database
                    var newProject = new FPTOOLS_PROJECT()
                    {
                        USER_ID = user.USER_ID,
                        FILE_NAME = filename,
                        PROJECT_NAME = projectName ?? "",
                    };

                    //  Initialize new Plot data into database
                    var newPlot = new IPORTAL_FP
                    {
                        TITLE = "",
                        SCALE_ID = 1,
                        FOOTNOTE = "",
                        XLABEL = "",
                        FP_STYLE_ID = 1,
                        RANGE_BOTTOM = 0,
                        RANGE_TOP = 5,
                        RANGE_STEP = 0.1,
                    };

                    IExcelDataReader excelReader; 
                    // Reading from a binary Excel file ('97-2003 format; *.xls)
                    if (filename.Split('.').Last().Equals("xls"))                        
                        excelReader = ExcelReaderFactory.CreateBinaryReader(fileStream);
                    else  // Reading from a OpenXml Excel file (2007 format; *.xlsx)
                        excelReader = ExcelReaderFactory.CreateOpenXmlReader(fileStream);
                    excelReader.IsFirstRowAsColumnNames = true;
                    var excelDataset = excelReader.AsDataSet();

                    string category = null, subcategory = null;
                    foreach (DataRow row in excelDataset.Tables[0].Rows)
                    {
                        // regex to match an alphanumeric character
                        var re = new Regex(@"\w");

                        // Update category if present
                        var rowCategory = row.GetColumnValue(excelReaderExtension.ColumnTypes.CATEGORY);
                        if (rowCategory != null && re.IsMatch(rowCategory))
                            category = rowCategory;

                        // Update subcategory if present
                        var rowSubcategory = row.GetColumnValue(excelReaderExtension.ColumnTypes.SUBCATEGORY);
                        if (rowSubcategory != null && re.IsMatch(rowSubcategory))
                            subcategory = rowSubcategory;

                        // Determine if a parameter is present in the row
                        var rowParameter = row.GetColumnValue(excelReaderExtension.ColumnTypes.PARAMETER);
                        if (rowParameter != null && re.IsMatch(rowParameter))
                        {
                            // Determine if row values can be parsed as double
                            double ratio, lowerCI, higherCI;
                            if (double.TryParse(row.GetColumnValue(excelReaderExtension.ColumnTypes.RATIO), out ratio)
                                && double.TryParse(row.GetColumnValue(excelReaderExtension.ColumnTypes.LOWERCI), out lowerCI)
                                && double.TryParse(row.GetColumnValue(excelReaderExtension.ColumnTypes.UPPERCI), out higherCI))
                            {
                                // Create a new row entity
                                IPORTAL_FP_ROW FP_RowTable = new IPORTAL_FP_ROW();

                                FP_RowTable.CATEGORY = category;
                                FP_RowTable.SUBCATEGORY = subcategory;
                                FP_RowTable.PARAMETER = rowParameter;
                                FP_RowTable.RATIO = ratio;
                                FP_RowTable.LOWER_CI = lowerCI;
                                FP_RowTable.UPPER_CI = higherCI;

                                // Save comment only if it contains alphanumeric info
                                var comment = row.GetColumnValue(excelReaderExtension.ColumnTypes.COMMENT);
                                FP_RowTable.COMMENT = (comment != null && re.IsMatch(comment)) ? comment : "";

                                FP_RowTable.FP_ID = newPlot.FP_ID;
                                newPlot.IPORTAL_FP_ROW.Add(FP_RowTable);
                            }
                        }
                    }
                        
                    newProject.IPORTAL_FP.Add(newPlot);
                    fpContext.FPTOOLS_PROJECT.Add(newProject);
                    fpContext.SaveChanges();

                    // Retrieve the id of the submitted project
                    projectId = newProject.PROJECT_ID;
                }
                else // TODO: error check for no login user
                {
                    throw new HttpResponseException(HttpStatusCode.InternalServerError);
                };
            }

            // return projectId 
            return Request.CreateResponse(HttpStatusCode.OK, projectId);
            
        }               
    }
}