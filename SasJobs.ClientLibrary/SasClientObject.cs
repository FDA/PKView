using System;
using System.Collections.Generic;
using System.Data;
using System.Net.Http;
using System.Net.Http.Headers;
using SasJobs.Messages;

namespace SasJobs.ClientLibrary
{
    public static class SasClientObject
    {
        /// <summary> Default table name for input datasets passed to SAS</summary>
        private const string defaultTableName = "SasData";

        /// <summary>Url of the SAS Api</summary>
        private static string ApiUrl { get; set; }

        /// <summary>
        /// Initialization method
        /// </summary>
        /// <param name="url">Api service Url</param>
        public static void Init(string url)
        {
            ApiUrl = url;        
        }

        /// <summary>
        /// Start a new asynchronous job
        /// </summary>
        /// <param name="procedureName">Stored procedure to run</param>
        /// <returns>The unique job id</returns>
        public static Guid NewJob(string procedureName)
        {
            return DoNewJob(procedureName, null);
        }

        /// <summary>
        /// Start a new asynchronous job
        /// </summary>
        /// <typeparam name="T">Type of the input variable</typeparam>
        /// <param name="procedureName">Stored procedure to run</param>
        /// <param name="inputValue">Input variable</param>
        /// <param name="inputKey">Column name for the input</param>
        /// <param name="tableName">Optional table name for the input</param>
        /// <returns>The unique job id</returns>
        public static Guid NewJob<T>(string procedureName, T inputRecord, string tableName = defaultTableName) where T: class 
        {
            return DoNewJob(procedureName, ToDataSet(new List<T> { inputRecord }, tableName));
        }

        /// <summary>
        /// Start a new asynchronous job
        /// </summary>
        /// <typeparam name="T">Type of the input variable</typeparam>
        /// <param name="procedureName">Stored procedure to run</param>
        /// <param name="inputData">List if input values</param>
        /// <param name="tableName">Optional table name for the list of input values</param>
        /// <returns>The unique job id</returns>
        public static Guid NewJob<T>(string procedureName, IList<T> inputData, string tableName = defaultTableName) where T: class
        {
            return DoNewJob(procedureName, ToDataSet<T>(inputData, tableName)); 
        }

        /// <summary>
        /// Start a new asynchronous job
        /// </summary>
        /// <param name="inputDataSet">Input data</param>
        /// <param name="procedureName">Stored procedure to run</param>
        /// <returns>The unique job id</returns>
        public static Guid NewJob(DataSet inputDataSet, string procedureName) 
        {
            return DoNewJob(procedureName, inputDataSet);
        }

        /// <summary>
        /// Start a new asynchronous job
        /// </summary>
        /// <param name="procedureName">Stored procedure to run</param>
        /// <returns>A response object with the result of executing the job</returns>
        public static JobResponse RunJob(string procedureName)
        {
            return RunNewJob(procedureName, null);
        }

        /// <summary>
        /// Start a new asynchronous job
        /// </summary>
        /// <typeparam name="T">Type of the input variable</typeparam>
        /// <param name="procedureName">Stored procedure to run</param>
        /// <param name="inputValue">Input variable</param>
        /// <param name="inputKey">Column name for the input</param>
        /// <param name="tableName">Optional table name for the input</param>
        /// <returns>A response object with the result of executing the job</returns>
        public static JobResponse RunJob<T>(string procedureName, T inputRecord, string tableName = defaultTableName) where T : class
        {
            return RunNewJob(procedureName, ToDataSet(new List<T> { inputRecord }, tableName));
        }

        /// <summary>
        /// Start a new asynchronous job
        /// </summary>
        /// <typeparam name="T">Type of the input variable</typeparam>
        /// <param name="procedureName">Stored procedure to run</param>
        /// <param name="inputData">List if input values</param>
        /// <param name="tableName">Optional table name for the list of input values</param>
        /// <returns>A response object with the result of executing the job</returns>
        public static JobResponse RunJob<T>(string procedureName, IList<T> inputData, string tableName = defaultTableName) where T : class
        {
            return RunNewJob(procedureName, ToDataSet<T>(inputData, tableName));
        }

        /// <summary>
        /// Start a new asynchronous job
        /// </summary>
        /// <param name="inputDataSet">Input data</param>
        /// <param name="procedureName">Stored procedure to run</param>
        /// <returns>A response object with the result of executing the job</returns>
        public static JobResponse RunJob(DataSet inputDataSet, string procedureName)
        {
            return RunNewJob(procedureName, inputDataSet);
        }

        /// <summary>
        /// Run a new job
        /// </summary>
        /// <param name="procedureName">Stored procedure to run</param>
        /// <param name="inputDataSet">Input dataset</param>
        /// <returns>A job info message with job status and/or ouptut data</returns>
        private static Guid DoNewJob(string procedureName, DataSet inputDataSet)
        {
            using (var client = new HttpClient())
            {
                // Setup Http Client
                client.BaseAddress = new Uri(ApiUrl);
                client.DefaultRequestHeaders.Accept.Clear();
                client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/xml"));

                // Create request
                var message = new JobRequest(procedureName, inputDataSet);

                // Send request
                HttpResponseMessage response = client.PostAsXmlAsync<JobRequest>("api/jobs", message).Result;

                // Process response
                if (response.IsSuccessStatusCode)
                {
                    var jobInfo = response.Content.ReadAsAsync<JobResponse>().Result;                    
                    return jobInfo.CorrelationId;
                }
                else
                {
                    throw new Exception(response.Content.ReadAsStringAsync().Result);
                }
            }
        }

        /// <summary>
        /// Run a sas job synchronously
        /// </summary>
        /// <param name="procedureName">Stored procedure to run</param>
        /// <param name="inputDataSet">Input dataset</param>
        /// <returns>A response object with the result of executing the job</returns>
        private static JobResponse RunNewJob(string procedureName, DataSet inputDataSet)
        {
            JobResponse response;
            Guid id = DoNewJob(procedureName, inputDataSet);

            do
            {
                System.Threading.Thread.Sleep(500);
                response = Getjob(id);
            } while (response.Status == SasJobs.Messages.StatusCode.Running);

            return response;
        }

        /// <summary>
        /// Retrieve job information such as status code, message and output data
        /// </summary>
        /// <param name="jobId">Unique job identifier</param>
        /// <returns></returns>
        public static JobResponse<T> Getjob<T>(Guid jobId)
        {
            return new JobResponse<T>(Getjob(jobId));
        }

        public static JobResponse Getjob(Guid jobId)
        {
            using (var client = new HttpClient())
            {
                // Setup Http Client
                client.BaseAddress = new Uri(ApiUrl);
                client.DefaultRequestHeaders.Accept.Clear();
                client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/xml"));

                // Send request
                HttpResponseMessage response = client.GetAsync("api/jobs/" + jobId).Result;

                // Process response
                if (response.IsSuccessStatusCode)
                {
                    var jobInfo = response.Content.ReadAsAsync<JobResponse>().Result;
                    return jobInfo;
                }
                else
                {
                    throw new Exception(response.Content.ReadAsStringAsync().Result);
                }
            }
        }

        /// <summary>
        /// Wrap a variable with a dataset
        /// </summary>
        /// <typeparam name="T">Variable type</typeparam>
        /// <param name="value">Variable value</param>
        /// <param name="key">Column name</param>
        /// <param name="tableName">Optional table name</param>
        /// <returns>A dataset that wraps the variable</returns>
        private static DataSet ToDataSet<T>(string key, T value, string tableName = defaultTableName)
        {
            Type elementType = typeof(T);
            var inputDataSet = new DataSet();
            DataTable t = new DataTable(tableName);
            inputDataSet.Tables.Add(t);
            t.Columns.Add(key, elementType);
            DataRow row = t.NewRow();
            row[key] = value;
            t.Rows.Add(row);
            return inputDataSet;
        }

        /// <summary>
        /// Convert a list of POCO objects to a dataset
        /// </summary>
        /// <typeparam name="T">Object type</typeparam>
        /// <param name="list">List of POCO objects</param>
        /// <param name="tableName">Name for the data table, if not specified the object type will be used</param>
        /// <returns>A dataset with the POCO fields and properties as columns and the specified table name</returns>
        private static DataSet ToDataSet<T>(IList<T> list, string tableName = null)
        {
            Type elementType = typeof(T);
            var ds = new DataSet();
            var t = new DataTable(tableName ?? elementType.Name);
            ds.Tables.Add(t);

            //add a column to table for each public property on T
            foreach (var propInfo in elementType.GetProperties())
                t.Columns.Add(propInfo.Name, propInfo.PropertyType);
            foreach (var fieldInfo in elementType.GetFields())
                t.Columns.Add(fieldInfo.Name, fieldInfo.FieldType);

            //go through each property on T and add each value to the table
            foreach (T item in list)
            {
                DataRow row = t.NewRow();

                foreach (var propInfo in elementType.GetProperties())
                    row[propInfo.Name] = propInfo.GetValue(item, null);
                foreach (var fieldInfo in elementType.GetFields())
                    row[fieldInfo.Name] = fieldInfo.GetValue(item);

                //This line was missing:
                t.Rows.Add(row);
            }

            return ds;
        }
    }
}
