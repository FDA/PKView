using SasJobs.ClientLibrary;
using SasJobs.Messages;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Web;
using System.Threading;

namespace iPortal.Models.Shared
{
    /// <summary>
    /// Abstracts a clinical data file from the server
    /// </summary>
    public class ClinicalDataFile
    {
        /// <summary> Get the data from the clinical data file</summary>
        public DataTable Data { get { return data; } }

        /// <summary> Data in the clinical data file </summary>
        private DataTable data { get; set; }

        /// <summary>
        /// Create a new Clinical Data File object loading the data from the server
        /// </summary>
        /// <param name="path"></param>
        public ClinicalDataFile(string path)
        {
            // Start a new sas job to retrieve the file
            var id = SasClientObject.NewJob("RunDatasetTransfer", new
            {
                filepath = path,
                timestamp = DateTime.Now.ToString("yyyyMMddHHmmssffff")
            }); // Timestamp added to avoid caching in the backend

            // Poll the server until we get a response other than 'running'
            JobResponse response;
            do
            {
                Thread.Sleep(500);
                response = SasClientObject.Getjob(id);
            } while (response.Status == SasJobs.Messages.StatusCode.Running);

            // Store the data on success, otherwise throw an exception
            if (response.Status == SasJobs.Messages.StatusCode.Done)
                    this.data = response.Data.Tables[0];
            else throw new Exception("The system was unable to read the specified xpt file.");            
        }


        /// <summary>
        /// Get all the values in a single column
        /// </summary>
        /// <typeparam name="T"></typeparam>
        /// <param name="columnName"></param>
        /// <returns></returns>
        public IEnumerable<T> GetColumn<T>(string columnName)
        { 
            var column = new List<T>(data.Rows.Count);
            int colid = data.Columns[columnName].Ordinal; // faster access

            foreach(var row in this.data.AsEnumerable())   
                column.Add((T)Convert.ChangeType(row[colid], typeof(T)));
         
            return column;    
        }


    }
}