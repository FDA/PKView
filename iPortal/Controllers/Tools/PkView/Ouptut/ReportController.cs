using System;
using System.Collections.Generic;
using System.Data;
using System.IO;
using System.Linq;
using System.Web;
using System.Web.Http;
using iPortal.Models.PkView;
using SasJobs.ClientLibrary;
using SasJobs.Messages;
using iPortal.Models.PkView.Reports;
using iPortal.Models.Shared;
using System.Net.Http;
using System.IO.Compression;
using iPortal.Models.Shared.System;
using System.Net;
using System.Net.Http.Headers;

namespace iPortal.Controllers.PkView
{
    /// <summary>
    /// Report service controller
    /// </summary>    
    public class ReportController : ApiController
    {
        // locks for file compression
        private static NamedLocker zipLocks = new NamedLocker();

        /// <summary>
        /// Generates a report
        /// </summary>
        /// <param name="revisedMappings">The revised study settings including report settings</param>
        /// <param name="reportId">report index to be generated</param>
        /// <returns>The report creation date</returns>
        [HttpPost, Route("api/pkview/generateReport")]
        public DateTime? GenerateReport([FromBody] StudySettings revisedMappings, int reportId)
        {
            // Apply Ex setting for reference computation
            revisedMappings.UseEx = revisedMappings.UseExRef;
            DataSet data = revisedMappings.ToReportGenerationDataSet(reportId);
            Report newReport = revisedMappings.Reports[reportId];            
            JobResponse response;
            Guid id;

            // Clean up old report files first
            DeleteReportFiles(revisedMappings, newReport.Name);

            // Use different SAS Api calls for different types of report
            switch (newReport.Type)
            {
                case 1: id = SasClientObject.NewJob(data, "GenerateReport"); break;
                case 2: id = SasClientObject.NewJob(data, "GenerateForestPlot"); break;
                case 3: id = SasClientObject.NewJob(data, "GenerateNcaAnalysis"); break;
                default: return null;
            }

            // Wait for job response
            do
            {
                System.Threading.Thread.Sleep(500);
                response = SasClientObject.Getjob(id);
            } while (response.Status == SasJobs.Messages.StatusCode.Running);

            // if done save report and return creation date
            if (response.Status == SasJobs.Messages.StatusCode.Done)
            {
                // Set the creation date            
                newReport.CreationDate = DateTime.Now;
                newReport.Generated = true;

                // If success, save the settings and return the creation date
                DoSaveReport(revisedMappings.NDAName, revisedMappings.SupplementNumber,
                    revisedMappings.StudyCode, revisedMappings.ProfileName, newReport);

                // If nca, generate script
                if (newReport.Type == 3)
                {
                    var scriptBuilder = new NcaBuilder(revisedMappings, newReport);
                    scriptBuilder.Create();
                }

                return newReport.CreationDate;
            }
            else return null;
        }

        /// <summary>
        /// Generates a excluded report
        /// </summary>
        /// <param name="revisedMappings">The revised study settings including report settings</param>
        /// <param name="reportId">report index to be generated</param>
        /// <returns>The exclude report creation date</returns>
        [HttpPost, Route("api/pkview/GenerateExcludedReport")]
        public DateTime? GenerateExcludedReport([FromBody] StudySettings revisedMappings, int reportId)
        {
            // Apply Ex setting for reference computation
            revisedMappings.UseEx = revisedMappings.UseExRef;

            DataSet data = revisedMappings.ToExcludedReportGenerationDataSet(reportId);
            Report newReport = revisedMappings.Reports[reportId];
            JobResponse response;
            Guid id;

            // Clean up old report files first
            DeleteReportFiles(revisedMappings, newReport.Name);

            // Use different SAS Api calls for different types of report
            switch (newReport.Type)
            {
                case 1: id = SasClientObject.NewJob(data, "GenerateExcludeData"); break;
                //case 1: id = SasClientObject.NewJob(data, "GenerateReport"); break;
                default: return null;
            }

            // Wait for job response
            do
            {
                System.Threading.Thread.Sleep(500);
                response = SasClientObject.Getjob(id);
            } while (response.Status == SasJobs.Messages.StatusCode.Running);

            // if done save report and return creation date
            if (response.Status == SasJobs.Messages.StatusCode.Done)
            {
                // Set the creation date            
                newReport.CreationDate = DateTime.Now;
                newReport.Generated = true;

                // If success, save the settings and return the creation date
                DoSaveReport(revisedMappings.NDAName, revisedMappings.SupplementNumber,
                    revisedMappings.StudyCode, revisedMappings.ProfileName, newReport);

                // If nca, generate script
                if (newReport.Type == 3)
                {
                    var scriptBuilder = new NcaBuilder(revisedMappings, newReport);
                    scriptBuilder.Create();
                }

                return newReport.CreationDate;
            }
            else return null;
        }

        /// <summary>
        /// Generates a Meta Forest Plot Analysis
        /// </summary>
        /// <param name="revisedMappings">The revised study settings including report settings</param>
        /// <param name="reportId">report index to be generated</param>
        /// <returns>The report creation date</returns>
        [HttpPost, Route("api/pkview/generateMetaAnalysis")]
        public DateTime? generateMetaAnalysis([FromBody] List<StudySettings> revisedMappingsList, int reportId)
        {
            // Apply Ex setting for reference computation
            //revisedMappings.UseEx = revisedMappings.UseExRef;
            Report newReport0 = revisedMappingsList[0].Reports[reportId];
            StudySettings revisedMappings = revisedMappingsList[0];
            DataSet data = new DataSet();
            for (int i = 0; i < revisedMappingsList.Count; i++)
            {
                DataSet data1 = revisedMappingsList[i].ToMetaAnalysisGenerationDataSet(reportId);
                            if (data1 != null) {
                                data.Merge(data1); 
                            }
                            
            }

            JobResponse response;
            Guid id;

            //// Clean up old report files first
            //DeleteReportFiles(revisedMappings, newReport.Name);

            // Use different SAS Api calls for different types of report
            id = SasClientObject.NewJob(data, "GenerateMetaAnalysis");

            // Wait for job response
            do
            {
                System.Threading.Thread.Sleep(500);
                response = SasClientObject.Getjob(id);
            } while (response.Status == SasJobs.Messages.StatusCode.Running);

            // if done save report and return creation date
            if (response.Status == SasJobs.Messages.StatusCode.Done)
            {
                // Set the creation date            


                // If success, save the settings and return the creation date
                for (int i = 0; i < revisedMappingsList.Count; i++)
                {
                    Report newReport = revisedMappingsList[i].Reports[reportId];
                    newReport.CreationDate = DateTime.Now;
                    newReport.Generated = true;
                    DoSaveMetaAnalysisReport(revisedMappingsList[i].NDAName, revisedMappingsList[i].SupplementNumber,
                    revisedMappingsList[i].StudyCode, revisedMappingsList[i].ProfileName, newReport);

                }

                var scriptBuilder = new MetaBuilder(revisedMappings, newReport0);
                scriptBuilder.Create();

                

                return DateTime.Now;
            }
            else return null;
        }


        /// <summary>
        /// Generates a Variability Meta Analysis
        /// </summary>
        /// <param name="revisedMappings">The revised study settings including report settings</param>
        /// <param name="reportId">report index to be generated</param>
        /// <returns>The report creation date</returns>
        [HttpPost, Route("api/pkview/VariabilityMetaAnalysis")]
        public DateTime? VariabilityMetaAnalysis([FromBody] List<StudySettings> revisedMappingsList, int reportId)
        {
            // Apply Ex setting for reference computation
            //revisedMappings.UseEx = revisedMappings.UseExRef;
            Report newReport0 = revisedMappingsList[0].Reports[reportId];
            StudySettings revisedMappings = revisedMappingsList[0];
            DataSet data = new DataSet();
            for (int i = 0; i < revisedMappingsList.Count; i++)
            {
                DataSet data1 = revisedMappingsList[i].ToVariabilityMetaAnalysisGenerationDataSet(reportId);
                if (data1 != null)
                {
                    data.Merge(data1);
                }

            }

            JobResponse response;
            Guid id;

            //// Clean up old report files first
            //DeleteReportFiles(revisedMappings, newReport.Name);

            // Use different SAS Api calls for different types of report
            id = SasClientObject.NewJob(data, "GenerateMetaVariability");
            //id = SasClientObject.NewJob(data, "variabilitytest4");

            // Wait for job response
            do
            {
                System.Threading.Thread.Sleep(500);
                response = SasClientObject.Getjob(id);
            } while (response.Status == SasJobs.Messages.StatusCode.Running);

            // if done save report and return creation date
            if (response.Status == SasJobs.Messages.StatusCode.Done)
            {
                // Set the creation date            


                // If success, save the settings and return the creation date
                for (int i = 0; i < revisedMappingsList.Count; i++)
                {
                    Report newReport = revisedMappingsList[i].Reports[reportId];
                    newReport.CreationDate = DateTime.Now;
                    newReport.Generated = true;
                    DoSaveVariabilityMetaAnalysisReport(revisedMappingsList[i].NDAName, revisedMappingsList[i].SupplementNumber, revisedMappingsList[i].StudyCode, revisedMappingsList[i].ProfileName, newReport);

                }

                //var scriptBuilder = new MetaBuilder(revisedMappings, newReport0);
                //scriptBuilder.Create();



                return DateTime.Now;
            }
            else return null;
        }



        /// <summary>
        /// Generates a Exclude
        /// </summary>
        /// <param name="revisedMappings">The revised study settings including report settings</param>
        /// <param name="reportId">report index to be generated</param>
        /// <returns>The report creation date</returns>
        [HttpPost, Route("api/pkview/generateExclude")]
        public DataTable GenerateExclude([FromBody] StudySettings revisedMappings, int reportId)
        {
            // Apply Ex setting for reference computation
            revisedMappings.UseEx = revisedMappings.UseExRef;

            DataSet data = revisedMappings.ToReportGenerationDataSet(reportId);
            Report newReport = revisedMappings.Reports[reportId];
            JobResponse response;
            Guid id;

            // Clean up old report files first
            //DeleteReportFiles(revisedMappings, newReport.Name);

            // Use different SAS Api calls for different types of report
            switch (newReport.Type)
            {
                case 1: id = SasClientObject.NewJob(data, "GenerateExclude"); break;
                default: return null;
            }

            // Wait for job response
            do
            {
                System.Threading.Thread.Sleep(500);
                response = SasClientObject.Getjob(id);
            } while (response.Status == SasJobs.Messages.StatusCode.Running);

            // if done save report and return datatable
            if (response.Status == SasJobs.Messages.StatusCode.Done)
            {

                var resultsTable = response.Data.Tables[0];
                
                // Set the creation date            
                //newReport.CreationDate = DateTime.Now;
                //newReport.Generated = true;

                // If success, save the settings and return the creation date
                //DoSaveReport(revisedMappings.NDAName, revisedMappings.SupplementNumber,
                //    revisedMappings.StudyCode, revisedMappings.ProfileName, newReport);

                // If nca, generate script
                //if (newReport.Type == 3)
                //{
                //    var scriptBuilder = new NcaBuilder(revisedMappings, newReport);
                //    scriptBuilder.Create();
                //}
                return resultsTable;
                //return newReport.CreationDate;
            }
            else return null;
        }
        /// <summary>
        /// Generates a demographic summary
        /// </summary>
        /// <param name="revisedMappings">The revised study settings</param>
        /// <returns>zero if successful, -1 otherwise</returns>
        [HttpPost, Route("api/pkview/reports/demographicSummary")]
        public int GenerateDemographicSummary([FromBody] StudySettings revisedMappings)
        {
            // Apply Ex setting for reference computation
            revisedMappings.UseEx = revisedMappings.UseExRef;

            DataSet data = revisedMappings.ToMappingDataSet(true);
            JobResponse response;
            Guid id;

            id = SasClientObject.NewJob(data, "Reports_DemographicSummary");

            // Wait for job response
            do
            {
                System.Threading.Thread.Sleep(500);
                response = SasClientObject.Getjob(id);
            } while (response.Status == SasJobs.Messages.StatusCode.Running);

            // Return the completion code
            return response.Status == SasJobs.Messages.StatusCode.Done ? 0 : -1;
        }

        /// <summary>
        /// Save the report settings
        /// </summary>
        [HttpPost, Route("api/pkview/saveReport")]
        public int SaveReport([FromBody] StudySettings revisedMappings, int reportId)
        {
            var newReport = revisedMappings.Reports[reportId];
            newReport.Generated = false;

            // Save report settings into the user study profile (FIXME: Improve profile management)
            DoSaveReport(revisedMappings.NDAName, revisedMappings.SupplementNumber, 
                revisedMappings.StudyCode, revisedMappings.ProfileName, newReport);
            
            return 0;
        }

        /// <summary>
        /// Delete the report settings
        /// </summary>
        [HttpPost, Route("api/pkview/DeleteReport")]
        public int DeleteReport([FromBody] StudySettings revisedMappings, int reportId)
        {
            // Save report settings into the user study profile (FIXME: Improve profile management)
            var study = new MappingController().LoadStudy(revisedMappings.NDAName, revisedMappings.ProfileName,
                revisedMappings.SupplementNumber, revisedMappings.StudyCode, null, true);
            var reportName = revisedMappings.Reports[reportId].Name;

            // Add or replace report
            var reportList = study.Reports.Where(report => report.Name != reportName).ToList();
            study.Reports = reportList;
            new MappingController().SaveStudy(study, study.NDAName, study.ProfileName, study.SupplementNumber, study.StudyCode);

            // Delete report files
            DeleteReportFiles(study, reportName);

            return 0;
        }

        /// <summary>
        /// Delete the report zip package
        /// </summary>
        [HttpPost, Route("api/pkview/DeleteReportPackage")]
        public int DeleteReportPackage(string project, string submission, string supplement, string study, string report)
        {
            DeleteReportZipPackage(project, submission, supplement, study, report);

            return 0;
        }


        [HttpGet, Route("api/pkview/DownloadReport")]
        public string Get(string project, string submission, string supplement, string study, string report)
        {
            DeleteReportZipPackage(project, submission, supplement, study, report);

            var userName = Users.GetCurrentUserName();
            var reportPath = string.Format(@"\\{0}\Output Files\PKView\{1}\{2}\{3}\{4}\{5}\{6}",
                iPortalApp.AppServerName, userName, project, submission, supplement, study, report);

            // If report folder exists, zip the contents and return them
            if (Directory.Exists(reportPath)) {
                lock (zipLocks.GetLock(reportPath))
                {
                    // Create a memory stream for the zip file
                    using (var memoryStream = new MemoryStream())
                    {
                        // Create a zip archive in the memory stream
                        using (var archive = new ZipArchive(memoryStream, ZipArchiveMode.Create, true))
                        {
                            // Add the report folder to the archive
                            archive.CreateEntriesFromDirectory(reportPath);
                        }

                        using (var fileStream = new FileStream(reportPath + ".zip", FileMode.Create))
                        {
                            memoryStream.Seek(0, SeekOrigin.Begin);
                            memoryStream.CopyTo(fileStream);
                        }

                        //// Set the read cursor at the beginning of the memory stream
                        //memoryStream.Seek(0, SeekOrigin.Begin);

                        //// Set the memory stream as the content for the response
                        //var result = new HttpResponseMessage(HttpStatusCode.OK);
                        //result.Content = new ByteArrayContent(memoryStream.GetBuffer());
                        ////result.Content = new StreamContent(memoryStream);

                        ////specify the content type
                        //result.Content.Headers.ContentType = new MediaTypeHeaderValue("application/zip");

                        ////we used attachment to force download
                        //result.Content.Headers.ContentDisposition =
                        //    new ContentDispositionHeaderValue("attachment") { FileName = report + ".zip" };
                        //return result;
                        return "yes"; 
                    }
                }
            }

            return "Report not exist,please generate it.";
        }

        [HttpGet, Route("api/pkview/DownloadSafetyReport")]

        public string DownloadSafetyReport(string project, string submission, string supplement, string AnalysisName)
        {
            int index = AnalysisName.IndexOf(".xml");
            string folderName = AnalysisName.Substring(0, index);
            var userName = Users.GetCurrentUserName();
            var reportPath = string.Format(@"\\{0}\\Output Files\\PKView\\{1}\\{2}\\{3}\\{4}\\ISS\\{5}\\Safety Analysis",
                iPortalApp.AppServerName, userName, project, submission, supplement, folderName);
            var reportFolder = new DirectoryInfo(reportPath);
            var reportPackage = new FileInfo(reportPath + ".zip");
            var zipPath = reportPath + ".zip";

            if (reportPackage.Exists)
                reportPackage.Delete();

            // If report folder exists, zip the contents and return them
            if (Directory.Exists(reportPath))
            {
                ZipFile.CreateFromDirectory(reportPath, zipPath, CompressionLevel.Fastest, false);
                return "yes";
            }
            return "Report not found ,please generate it";
        }

        [HttpGet, Route("api/pkview/DownloadMetaReport")]
        public string Get(string foldername, string project, string submission, string supplement)
        {
            DeleteMetaReportZipPackage(project, submission, supplement, foldername);

            var userName = Users.GetCurrentUserName();
            var reportPath = string.Format(@"\\{0}\Output Files\PKView\{1}\{2}\{3}\{4}\{5}",
                iPortalApp.AppServerName, userName, project, submission, supplement, foldername);

            // If report folder exists, zip the contents and return them
            if (Directory.Exists(reportPath))
            {
                lock (zipLocks.GetLock(reportPath))
                {
                    // Create a memory stream for the zip file
                    using (var memoryStream = new MemoryStream())
                    {
                        // Create a zip archive in the memory stream
                        using (var archive = new ZipArchive(memoryStream, ZipArchiveMode.Create, true))
                        {
                            // Add the report folder to the archive
                            archive.CreateEntriesFromDirectory(reportPath);
                        }
                        using (var fileStream = new FileStream(reportPath + ".zip", FileMode.Create))
                        {
                            memoryStream.Seek(0, SeekOrigin.Begin);
                            memoryStream.CopyTo(fileStream);
                        }
                        return "yes"; 

                       
                    }
                }
            }

            return "Meta analysis report not exist,please generate it.";
        }

        

        private int DoSaveReport(string NDAName, string SupplementNumber, string StudyCode, string ProfileName, Report newReport)
        {
            // Save report settings into the user study profile (FIXME: Improve profile management)
            var study = new MappingController().LoadStudy(NDAName, ProfileName, SupplementNumber, StudyCode, null, true);          

            // Add or replace report
            IEnumerable<Report> reports = null;
            if (study.Reports != null)
                reports = study.Reports.Where(report => report.Name != newReport.Name);
            var reportList = (reports ?? new List<Report>()).ToList();
            reportList.Add(newReport);
            reportList = reportList.OrderBy(r => r.Name).ToList();
            study.Reports = reportList;
            new MappingController().SaveStudy(study, study.NDAName, study.ProfileName, study.SupplementNumber, study.StudyCode);

            return 0;
        }

        private int DoSaveMetaAnalysisReport(string NDAName, string SupplementNumber, string StudyCode, string ProfileName, Report newReport)
        {
            // Save report settings into the user study profile (FIXME: Improve profile management)
            var study = new MappingController().LoadStudy(NDAName, ProfileName, SupplementNumber, StudyCode, null, true);

            // Add or replace report
            newReport.Name = "Forest Plot Meta Analysis Report";
            newReport.Type = 5;
            IEnumerable<Report> reports = null;
            if (study.Reports != null)
                reports = study.Reports.Where(report => report.Name != newReport.Name);
            var reportList = (reports ?? new List<Report>()).ToList();
           
            reportList.Add(newReport);
            reportList = reportList.OrderBy(r => r.Name).ToList();
            study.Reports = reportList;
            new MappingController().SaveStudy(study, study.NDAName, study.ProfileName, study.SupplementNumber, study.StudyCode);

            return 0;
        }

        private int DoSaveVariabilityMetaAnalysisReport(string NDAName, string SupplementNumber, string StudyCode, string ProfileName, Report newReport)
        {
            // Save report settings into the user study profile (FIXME: Improve profile management)
            var study = new MappingController().LoadStudy(NDAName, ProfileName, SupplementNumber, StudyCode, null, true);

            // Add or replace report
            newReport.Name = "Variability Meta Analysis Report";
            newReport.Type = 6;
            IEnumerable<Report> reports = null;
            if (study.Reports != null)
                reports = study.Reports.Where(report => report.Name != newReport.Name);
            var reportList = (reports ?? new List<Report>()).ToList();

            reportList.Add(newReport);
            reportList = reportList.OrderBy(r => r.Name).ToList();
            study.Reports = reportList;
            new MappingController().SaveStudy(study, study.NDAName, study.ProfileName, study.SupplementNumber, study.StudyCode);

            return 0;
        }

        private void DeleteReportFiles(StudySettings study, string reportName)
        {
            var userName = Users.GetCurrentUserName();
            var reportPath = string.Format(@"\\{0}\Output Files\PKView\{1}\{2}\{3}\{4}\{5}\{6}",
                iPortalApp.AppServerName, userName, study.ProfileName, study.NDAName, study.SupplementNumber, study.StudyCode, reportName);
            var reportFolder = new DirectoryInfo(reportPath);
            if (reportFolder.Exists)
                reportFolder.Delete(true);
        }

        private void DeleteReportZipPackage(string project, string submission, string supplement, string study, string report)
        {
            var userName = Users.GetCurrentUserName();
            var reportPath = string.Format(@"\\{0}\Output Files\PKView\{1}\{2}\{3}\{4}\{5}\{6}",
                iPortalApp.AppServerName, userName, project, submission, supplement, study, report);
            var reportFolder = new DirectoryInfo(reportPath);
            var reportPackage = new FileInfo(reportPath+".zip");

            if (reportPackage.Exists)
                reportPackage.Delete();
        }
        private void DeleteMetaReportZipPackage(string project, string submission, string supplement, string report)
        {
            var userName = Users.GetCurrentUserName();
            var reportPath = string.Format(@"\\{0}\Output Files\PKView\{1}\{2}\{3}\{4}\{5}",
                iPortalApp.AppServerName, userName, project, submission, supplement, report);
            var reportFolder = new DirectoryInfo(reportPath);
            var reportPackage = new FileInfo(reportPath + ".zip");

            if (reportPackage.Exists)
                reportPackage.Delete();
        }
    }
}
