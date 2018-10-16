using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;
using SasJobs.ClientLibrary;
using SasJobs.Messages;
using iPortal.Models.PkView;
using System.Data;
using System.IO;
using iPortal.Config;
using iPortal.Models.Shared;
using System.Windows;
using System.Net.Http.Headers;
using System.Web;
using System.Web.Hosting;
using System.Text.RegularExpressions;
using System.Xml;
using System.Text;
using iPortal.Models.PkView.Reports;

namespace iPortal.Controllers.Tools.PkView
{
    public class SafetyAnalysisController : ApiController
    {
        /// Retrieve the mappings for study 'ISS' in the submission
        [HttpGet, Route("api/pkview/submissions/IssMapping")]
        public JobResponse<IssMappingSettings> GetIssMapping(string ProfileName, string NDAName, string SupplementNumber)
        {
            JobResponse response = new JobResponse();
            var studyCode = "iss";
            string studyFolder = "";

            DirectoryInfo tempDir = getStudyFolder(NDAName, SupplementNumber, studyCode);
            //if iss folder not found, return study = null
            if (tempDir == null)
            {
                return new JobResponse<IssMappingSettings>(response, null);
            }
            else
            {
                studyFolder = tempDir.FullName;
            }
            int hash = StudySettings.GetFilesHash(studyFolder);

            var id = SasClientObject.NewJob("RunIssMapping", new { StudyFolder = studyFolder, NdaHash = hash });
            do
            {
                System.Threading.Thread.Sleep(50);
                response = SasClientObject.Getjob(id);
            } while (response.Status == SasJobs.Messages.StatusCode.Running);

            //if iss data not found, return null
            if (response.Data.Tables.Count == 0)
            {
                return new JobResponse<IssMappingSettings>(response, null);
            }

            var IssMapping_temp = response.Data.Tables["IssMappingSAS"].AsEnumerable();
            var IssFileVariables_temp = response.Data.Tables["IssVariables"].AsEnumerable();
            var TRTxxP_temp = response.Data.Tables["TRTXXP"].AsEnumerable();

            var study = new IssMappingSettings
            {
                IssNDAName = NDAName,
                IssStudyCode = "ISS",
                IssSupplementNumber = SupplementNumber,
                IssProfileName = ProfileName,
                displayOptions = false,
                AnalysisComplete = false,
                CumulativeAePooled = true,
                CumulativeAeIndividual = true,
                DoseResponse = true,
                DosingRecord = true,
                ClinicalDose = "",
                PkSafetyDdi = true,
                MaxDayCumulative = "",
                RandomNumber = "0",
                AeCutoffRate = "0",
                AnalysisType = "ITT",
                displayML = false
            };

            study.TRTxxPs = TRTxxP_temp.Select(trows => new TRTxxP
            {
                Selection = Convert.ToBoolean(trows["Selection"]),
                TRTXXP = trows["TRTXXP"].ToString()
            }).ToList();

            study.IssStudyMappings = IssMapping_temp
                   .Where(mrow => mrow["Study_Code"].ToString().Equals(study.IssStudyCode))
                   .GroupBy(mrow => mrow["Source"]).Select(mrows => new IssDomain
                   {
                       IssDomainType = mrows.First()["Source"].ToString(),
                       IssDomainMappings = mrows.Select(mrow => new IssMapping
                       {
                           IssFileVariable = mrow["File_Variable"].ToString(),
                           IssVariable = mrow["ISS_Variable"].ToString(),
                           IssMappingQuality = Convert.ToInt32(mrow["Mapping_Quality"])
                       }).Where(m => m.IssMappingQuality >= 0).ToList(), // Filter out mappings with quality -1 (dummy mappings)

                       IssFileVariables = IssFileVariables_temp.Where(frow =>
                          frow["study"].ToString().Equals(study.IssStudyCode) &&
                          frow["source"].Equals(mrows.First()["Source"]))
                           .Select(frow => new IssFileVariable
                           {
                               IssName = frow["variable"].ToString(),
                               IssDescription = frow["variableDescription"].ToString(),
                               IssLabel = String.Format("{0} - {1}", frow["variable"].ToString(), frow["variableDescription"].ToString())
                           }).ToList(),
                       IssFileId = mrows.First()["Path"].ToString()
                   }).ToList();

            //return study;
            return new JobResponse<IssMappingSettings>(response, study);
        }

        [HttpPost, Route("api/pkview/submissions/Domain/getValues")]
        public JobResponse<IssMappingSettings> GetValues([FromBody] selectedVar selVar)
        {
            JobResponse response = new JobResponse();
            DataSet data = ToGetValues(selVar.FileLocation, selVar.selVarDomain, selVar.selectedVariable);

            var id = SasClientObject.NewJob(data, "RunIssInOutStep2");
            do
            {
                System.Threading.Thread.Sleep(50);
                response = SasClientObject.Getjob(id);
            } while (response.Status == SasJobs.Messages.StatusCode.Running);

            //if data not found, return null
            if (response.Data.Tables.Count == 0)
            {
                return new JobResponse<IssMappingSettings>(response, null);
            }

            var Count_Values = response.Data.Tables["IssInOutStep2"].AsEnumerable();

            var study = new IssMappingSettings
            {
                IssStudyCode = "ISS"
            };

            study.CDomains = Count_Values
                .GroupBy(mrow => mrow["Domain"]).Select(mrows => new CDomain
                {
                    CDomainName = mrows.First()["Domain"].ToString(),
                    Inclusions = mrows.Select(mrow => new selectedVar
                    {
                        selectedVariable = mrow["variable"].ToString(),
                        ValueType = mrow["type"].ToString(),
                        InEx = "IN",
                        CountValues = mrows.Select(trow => new CountValue
                        {
                            UniqueValue = trow["value"].ToString()
                        }).ToList()
                    }).ToList(),
                    Exclusions = mrows.Select(mrow => new selectedVar
                    {
                        selectedVariable = mrow["variable"].ToString(),
                        ValueType = mrow["type"].ToString(),
                        InEx = "EX",
                        CountValues = mrows.Select(trow => new CountValue
                        {
                            UniqueValue = trow["value"].ToString()
                        }).ToList()
                    }).ToList()
                }).ToList();

            return new JobResponse<IssMappingSettings>(response, study);
        }

        //call to SAS to fetch treatment values
        [HttpPost, Route("api/pkview/submissions/IssMappings/getOptions")]
        public JobResponse<IssMappingSettings> GetOptions([FromBody] List<IssDomain> IssStudyMappings)
        {
            JobResponse response = new JobResponse();
            DataSet data = ToIssMappingDataSet(IssStudyMappings);

            var id = SasClientObject.NewJob(data, "GetOptions");
            do
            {
                System.Threading.Thread.Sleep(50);
                response = SasClientObject.Getjob(id);
            } while (response.Status == SasJobs.Messages.StatusCode.Running);

            //if treatment data not found, return null
            if (response.Data.Tables.Count == 0)
            {
                return new JobResponse<IssMappingSettings>(response, null);
            }

            var TRTP_temp = response.Data.Tables["TRTPs"].AsEnumerable();

            var study = new IssMappingSettings
            {
                IssStudyCode = "ISS"
            };

            List<IssTRTP> TempIssTRTPs = new List<IssTRTP>();

            TempIssTRTPs = TRTP_temp
                .Select(trow => new IssTRTP
                {
                    StudyId = trow["STUDYID"].ToString(),
                    TRTP = trow["TRTP"].ToString(),
                    order = "0",
                    IncludeStudy = true,
                    RevisedTRTP = trow["TRTP"].ToString(),
                    StudyDuration = trow["DURATION"].ToString(),
                    ARM = trow["ARM"].ToString(),
                    NumericDose = 0.0
                }).ToList();

            study.IssTRTPs = sortTRTP(TempIssTRTPs);
            study.MaxDayCumulative = TRTP_temp.First()["MaxDayCumulative"].ToString();

            //return study
            return new JobResponse<IssMappingSettings>(response, study);
        }

        [HttpGet, Route("api/pkview/submissions/{SubmissionId}/supplement/{supplementNumber}/getCounts")]
        public JobResponse<IssMappingSettings> GetCounts(string SubmissionId, string supplementNumber)
        {
            string studyFolder = "";
            var studyCode = "iss";

            JobResponse response = new JobResponse();
            DirectoryInfo tempDir = getStudyFolder(SubmissionId, supplementNumber, studyCode);
            //if iss folder not found, return study = null
            if (tempDir == null)
            {
                return new JobResponse<IssMappingSettings>(response, null);
            }
            else
            {
                studyFolder = tempDir.FullName;
            }
            int hash = StudySettings.GetFilesHash(studyFolder);

            var id = SasClientObject.NewJob("GetCounts", new { StudyFolder = studyFolder, NdaHash = hash });
            do
            {
                System.Threading.Thread.Sleep(50);
                response = SasClientObject.Getjob(id);
            } while (response.Status == SasJobs.Messages.StatusCode.Running);

            //if treatment data not found, return null
            if (response.Data.Tables.Count == 0)
            {
                return new JobResponse<IssMappingSettings>(response, null);
            }

            var Domain_counts = response.Data.Tables["IssInOutclusion"].AsEnumerable();
            var study = new IssMappingSettings
            {
                IssStudyCode = "ISS"
            };

            string[] tempSelVars = new string[] { "", "", "", "" };
            var EnumtempSelVars = tempSelVars.AsEnumerable();
            List<CountValue> CountValues = new List<CountValue>();
            List<string> Relations = new List<string>();

            study.CDomains = Domain_counts
                    .GroupBy(mrow => mrow["Domain"]).Select(mrows => new CDomain
                    {
                        CDomainName = mrows.First()["Domain"].ToString(),
                        CVariables = mrows.Select(trow => new CVariable
                        {
                            CVariableName = trow["variable"].ToString()
                        }).ToList(),
                        Inclusions = EnumtempSelVars.Select(grow => new selectedVar
                        {
                            selectedVariable = "",
                            InEx = "IN",
                            relation = "",
                            CountValues = CountValues,
                            ValueType = "",
                            selVarDomain = "",
                            FileLocation = "",
                            Relations = Relations,
                            display = false
                        }).ToList(),
                        Exclusions = EnumtempSelVars.Select(grow => new selectedVar
                        {
                            selectedVariable = "",
                            InEx = "EX",
                            relation = "",
                            CountValues = CountValues,
                            ValueType = "",
                            selVarDomain = "",
                            FileLocation = "",
                            Relations = Relations,
                            display = false
                        }).ToList()
                    }).ToList();

            return new JobResponse<IssMappingSettings>(response, study);
        }

        [HttpGet, Route("api/pkview/deleteAnalysis")]
        public string deleteAnalysis(string ProfileName, string NDAName, string SupplementNumber, string AnalysisName)
        {
            int index = AnalysisName.IndexOf(".xml");
            string folderName = AnalysisName.Substring(0, index);
            var userName = Users.GetCurrentUserName();
            var reportPath = string.Format(@"\\{0}\\Output Files\\PKView\\{1}\\{2}\\{3}\\{4}\\ISS\\{5}",
                iPortalApp.AppServerName, userName, ProfileName, NDAName, SupplementNumber, folderName);
            try
            {
                Directory.Delete(reportPath, true);
            }
            catch
            {
                return "error deleting analysis";
            }
            return "yes";
        }

        [HttpGet, Route("api/pkview/renameAnalysis")]
        public string renameAnalysis(string ProfileName, string NDAName, string SupplementNumber, string AnalysisName, string NewName)
        {
            int index = AnalysisName.IndexOf(".xml");
            string folderName = AnalysisName.Substring(0, index);
            var userName = Users.GetCurrentUserName();
            var reportPath = string.Format(@"\\{0}\\Output Files\\PKView\\{1}\\{2}\\{3}\\{4}\\ISS",
                 iPortalApp.AppServerName, userName, ProfileName, NDAName, SupplementNumber);
            var reportFolder = new DirectoryInfo(reportPath);

            DirectoryInfo[] files = reportFolder.GetDirectories();

            DirectoryInfo oldFolder = new DirectoryInfo(reportPath + "\\" + folderName);
            FileInfo oldFile = new FileInfo(reportPath + "\\" + folderName + "\\" + folderName + ".xml");

            var nameCollision = false;
            do
            {
                nameCollision = false;
                foreach (DirectoryInfo file in files)
                {
                    if (file.Name == NewName)
                    {
                        nameCollision = true;
                        return "This file already exists. Please select another name.";
                    }
                }
            } while (nameCollision);

            oldFile.MoveTo(reportPath + "\\" + folderName + "\\" + NewName + ".xml");
            oldFolder.MoveTo(reportPath + "\\" + NewName);
            return "yes";
        }

        [HttpGet, Route("api/pkview/fetchAnalyses")]
        public List<Analysis> fetchAnalyses(string ProfileName, string NDAName, string SupplementNumber)
        {
            var userName = Users.GetCurrentUserName();
            var reportPath = string.Format(@"\\{0}\Output Files\PKView\{1}\{2}\{3}\{4}\ISS",
                iPortalApp.AppServerName, userName, ProfileName, NDAName, SupplementNumber);

            var reportFolder = new DirectoryInfo(reportPath);
            var Analyses = new List<Analysis> { };
            if (reportFolder.Exists)
            {
                string[] folders = Directory.GetDirectories(reportPath);
                foreach (string folder in folders)
                {
                    int index = folder.IndexOf("ISS\\");
                    string files = folder.Substring(index + 4);
                    string FilePath = folder + "\\" + files + ".xml";
                    FileInfo fi = new FileInfo(FilePath);
                    var analysis = ReadXmlData(fi.FullName);
                    Analysis temp = new Analysis();
                    temp.AnalysisName = fi.Name;
                    temp.AnalysisCreationDate = fi.LastWriteTime.ToString();
                    temp.IssStudy = analysis.IssStudy;
                    temp.MLStudy = analysis.MLStudy;
                    Analyses.Add(temp);
                }
            }
            else
            {
                reportFolder.Create();
            }
            return Analyses;
        }

        [HttpGet, Route("api/pkview/ReadXML")]
        public JobResponse<Analysis> ReadXML(string analysisName, string project, string submission, string supplement)
        {
            JobResponse response = new JobResponse();
            int index = analysisName.IndexOf(".xml");
            string folderName = analysisName.Substring(0, index);

            var userName = Users.GetCurrentUserName();
            var reportPath = string.Format(@"\\{0}\\Output Files\\PKView\\{1}\\{2}\\{3}\\{4}\\ISS\\{5}\\{6}",
                iPortalApp.AppServerName, userName, project, submission, supplement, folderName, analysisName);

            var analysis = ReadXmlData(reportPath);

            var newAnalysis = new Analysis
            {
                AnalysisName = analysisName,
                IssStudy = analysis.IssStudy,
                MLStudy = analysis.MLStudy
            };

            return new JobResponse<Analysis>(response, newAnalysis);
        }

        [HttpPost, Route("api/pkview/saveAnalysis")]
        public string saveAnalysis([FromBody] Analysis newAnalysis)
        {
            IssMappingSettings IssStudy = newAnalysis.IssStudy;
            string[] MLStudy = newAnalysis.MLStudy;
            string AnalysisName = newAnalysis.AnalysisName;
            int index = AnalysisName.IndexOf(".xml");
            string folderName = AnalysisName.Substring(0, index);
            var userName = Users.GetCurrentUserName();
            var reportPath = string.Format(@"\\{0}\\Output Files\\PKView\\{1}\\{2}\\{3}\\{4}\\ISS\\{5}\\{6}",
                iPortalApp.AppServerName, userName, IssStudy.IssProfileName, IssStudy.IssNDAName, IssStudy.IssSupplementNumber, folderName, AnalysisName);

            WriteToXML(reportPath, IssStudy, MLStudy);
            var newFile = new FileInfo(reportPath);

            return newFile.LastWriteTime.ToString();
        }

        [HttpPost, Route("api/pkview/createNewAnalysis")]
        public Analysis createNewAnalysis(IssMappingSettings IssStudy)
        {
            var userName = Users.GetCurrentUserName();
            var reportPath = string.Format(@"\\{0}\Output Files\PKView\{1}\{2}\{3}\{4}\ISS",
                iPortalApp.AppServerName, userName, IssStudy.IssProfileName, IssStudy.IssNDAName, IssStudy.IssSupplementNumber);
            string[] folders = Directory.GetDirectories(reportPath);

            var nameId = 1;
            var newName = "Analysis " + "(" + nameId + ").xml";
            string folderName = "Analysis " + "(" + nameId + ")";

            var nameCollision = false;
            do
            {
                nameCollision = false;
                foreach (string folder in folders)
                {
                    string Fi = folder + ".xml";
                    string FilePath = reportPath + Fi;
                    FileInfo file = new FileInfo(FilePath);
                    if (file.Name == newName)
                    {
                        newName = "Analysis " + "(" + nameId + ").xml";
                        folderName = "Analysis " + "(" + nameId + ")";
                        nameId++;
                        nameCollision = true;
                    }
                }
            } while (nameCollision);

            var folderPath = reportPath + "\\" + folderName;
            var reportFolder = new DirectoryInfo(folderPath);

            if (!reportFolder.Exists)
            {
                reportFolder.Create();
            }
            string newLocation = string.Format(@"\\{0}\{1}\{2}", reportPath, folderName, newName);

            WriteToXML(newLocation, IssStudy, null);

            var newFile = new FileInfo(newLocation);
            var newAnalysis = new Analysis
            {
                AnalysisCreationDate = newFile.LastWriteTime.ToString(),
                AnalysisName = newFile.Name,
                IssStudy = IssStudy,
                AnalysisSaved = false
            };

            return newAnalysis;
        }

        //call SAS to run analysis with ISS study data
        [HttpPost, Route("api/pkview/submissions/IssMappings/runAnalysis")]
        public string RunAnalysis([FromBody] Analysis newAnalysis)
        {
            IssMappingSettings IssStudy = newAnalysis.IssStudy;
            string AnalysisName = newAnalysis.AnalysisName;
            JobResponse response = new JobResponse();

            DataSet data = ToIssTRTPDataSet(IssStudy, AnalysisName);

            return SasClientObject.NewJob(data, "RunIssAnalysis").ToString();
        }

        [HttpGet, Route("api/pkview/IssMappings/tryGet")]
        public JobResponse<AnalysisResults> Get(Guid jobId)
        {
            var response = SasClientObject.Getjob(jobId);

            return new JobResponse<AnalysisResults>(response, null);
        }

        [HttpPost, Route("api/pkview/IssMappings/CopySasCode")]
        public string CopySasCode([FromBody] Analysis newAnalysis)
        {
            var scriptBuilder = new SafetyBuilder(newAnalysis);
            scriptBuilder.Create();

            return "yes";
        }

        /// Get the root folder of a particular study
        private DirectoryInfo getStudyFolder(string submissionId, string supplementNumber, string studyCode)
        {
            var submissionPath = PkViewConfig.NdaRootFolder + submissionId + '/' + supplementNumber;
            var submissionDir = new DirectoryInfo(submissionPath);
            DirectoryInfo dataDir = findDatasetsDir(submissionDir);
            if (dataDir == null)
                return null;
            else
                return dataDir;
        }

        /// Find the datasets directory recursively, but fully explore each level before going deeper into the tree (faster)
        private DirectoryInfo findDatasetsDir(DirectoryInfo root)
        {
            var subdirectories = root.GetDirectories();
            foreach (var dir in subdirectories)
            {
                if (dir.Name.Equals("iss", StringComparison.CurrentCultureIgnoreCase))
                    return dir;
            }
            foreach (var dir in subdirectories)
            {
                var foundDir = findDatasetsDir(dir);
                if (foundDir != null)
                    return foundDir;
            }
            return null;
        }

        //convert iss mapping data to a data table 
        private DataSet ToIssMappingDataSet(List<IssDomain> IssStudyMappings)
        {
            var data = new DataSet();

            // mapping information
            var studyInfo = new DataTable("IssMappingSAS");
            studyInfo.Columns.Add("Study_Code", typeof(string));
            studyInfo.Columns.Add("Source", typeof(string));
            studyInfo.Columns.Add("Path", typeof(string));
            studyInfo.Columns.Add("File_Variable", typeof(string));
            studyInfo.Columns.Add("ISS_Variable", typeof(string));
            studyInfo.Columns.Add("Mapping_Quality", typeof(int));

            foreach (var IssStudyMapping in IssStudyMappings)
            {
                foreach (var issMapping in IssStudyMapping.IssDomainMappings)
                {
                    studyInfo.Rows.Add(
                        "ISS",
                        IssStudyMapping.IssDomainType,
                        IssStudyMapping.IssFileId,
                        issMapping.IssFileVariable,
                        issMapping.IssVariable,
                        issMapping.IssMappingQuality);
                }
            }
            data.Tables.Add(studyInfo);
            return data;
        }

        private DataSet ToGetValues(string FileLocation, string CDomainName, string selectedVariable)
        {
            var data = new DataSet();

            var valueInfo = new DataTable("IssInOutclusion");
            valueInfo.Columns.Add("FileLocation", typeof(string));
            valueInfo.Columns.Add("Domain", typeof(string));
            valueInfo.Columns.Add("Variable", typeof(string));

            valueInfo.Rows.Add(
                FileLocation,
                CDomainName,
                selectedVariable);

            data.Tables.Add(valueInfo);
            return data;
        }

        //convert iss study data to a data table
        private DataSet ToIssTRTPDataSet(IssMappingSettings IssStudy, string AnalysisName)
        {
            bool dataFound = false;
            var data = new DataSet();

            var tempAesev = new DataTable("AesevOrder");
            tempAesev.Columns.Add("Value", typeof(string));
            tempAesev.Columns.Add("Order", typeof(string));

            foreach (var AesevValue in IssStudy.AesevValues)
            {
                dataFound = true;
                tempAesev.Rows.Add(AesevValue.UniqueValue,
                    AesevValue.order);

            }
            if (!dataFound)
            {
                tempAesev.Rows.Add(
                        "no data",
                        "no data");
            }
            data.Tables.Add(tempAesev);

            dataFound = false;
            var tempAsev = new DataTable("AsevOrder");
            tempAsev.Columns.Add("Value", typeof(string));
            tempAsev.Columns.Add("Order", typeof(string));

            foreach (var AsevValue in IssStudy.AsevValues)
            {
                dataFound = true;
                tempAsev.Rows.Add(AsevValue.UniqueValue,
                    AsevValue.order);

            }
            if (!dataFound)
            {
                tempAsev.Rows.Add(
                        "no data",
                        "no data");
            }
            data.Tables.Add(tempAsev);

            dataFound = false;

            // mapping information
            var tempMapping = new DataTable("IssMappingSAS");
            tempMapping.Columns.Add("Study_Code", typeof(string));
            tempMapping.Columns.Add("Source", typeof(string));
            tempMapping.Columns.Add("Path", typeof(string));
            tempMapping.Columns.Add("File_Variable", typeof(string));
            tempMapping.Columns.Add("ISS_Variable", typeof(string));
            tempMapping.Columns.Add("Mapping_Quality", typeof(int));

            foreach (var IssStudyMapping in IssStudy.IssStudyMappings)
            {
                foreach (var issMapping in IssStudyMapping.IssDomainMappings)
                {
                    tempMapping.Rows.Add(
                        "ISS",
                        IssStudyMapping.IssDomainType,
                        IssStudyMapping.IssFileId,
                        issMapping.IssFileVariable,
                        issMapping.IssVariable,
                        issMapping.IssMappingQuality);
                }
            }
            data.Tables.Add(tempMapping);

            // treatment information
            var tempTRTPtable = new DataTable("TRTPs");
            tempTRTPtable.Columns.Add("StudyId", typeof(string));
            tempTRTPtable.Columns.Add("NumberOfSubjects", typeof(string));
            tempTRTPtable.Columns.Add("TRTP", typeof(string));
            tempTRTPtable.Columns.Add("order", typeof(string));
            tempTRTPtable.Columns.Add("RevisedTRTP", typeof(string));
            tempTRTPtable.Columns.Add("IncludeStudy", typeof(bool));
            tempTRTPtable.Columns.Add("ARM", typeof(string));
            tempTRTPtable.Columns.Add("StudyDuration", typeof(string));
            tempTRTPtable.Columns.Add("NumericDose", typeof(string));
            string tempTRTP = "";
            string tempOrder = "";
            double tempNumericDose = 0.0;
            string tempRevisedTRTP = "";

            foreach (var IssTRTP in IssStudy.IssTRTPs)
            {
                if (IssTRTP.TRTP == "")
                {
                    IssTRTP.TRTP = tempTRTP;
                    IssTRTP.order = tempOrder;
                    IssTRTP.NumericDose = tempNumericDose;
                    IssTRTP.RevisedTRTP = tempRevisedTRTP;
                }
                else
                {
                    tempTRTP = IssTRTP.TRTP;
                    tempOrder = IssTRTP.order;
                    tempNumericDose = IssTRTP.NumericDose;
                    tempRevisedTRTP = IssTRTP.RevisedTRTP;
                }
                if (IssTRTP.IncludeStudy)
                {
                    dataFound = true;
                    tempTRTPtable.Rows.Add(
                        IssTRTP.StudyId,
                        IssTRTP.NumberOfSubjects,
                        IssTRTP.TRTP,
                        IssTRTP.order,
                        IssTRTP.RevisedTRTP,
                        IssTRTP.IncludeStudy,
                        IssTRTP.ARM,
                        IssTRTP.StudyDuration,
                        IssTRTP.NumericDose);
                }
            }
            if (!dataFound)
            {
                tempTRTPtable.Rows.Add(
                        "no data",
                        "no data",
                        "no data",
                        "no data",
                        "no data",
                        false,
                        "no data",
                        "no data",
                        "no data");
            }
            data.Tables.Add(tempTRTPtable);

            //TRTxxP information
            var tempTRTxxP = new DataTable("TRTXXP");
            tempTRTxxP.Columns.Add("Selection", typeof(string));
            tempTRTxxP.Columns.Add("TRTXXP", typeof(string));

            foreach (var TRTxxP in IssStudy.TRTxxPs)
            {
                string selection = Convert.ToString(TRTxxP.Selection).ToUpper();
                tempTRTxxP.Rows.Add(
                        selection,
                        TRTxxP.TRTXXP);
            }
            data.Tables.Add(tempTRTxxP);

            // user information
            var userName = HttpContext.Current.User.Identity.Name ?? "DEFAULT";
            userName = userName.Substring(userName.LastIndexOfAny(new[] { '/', '\\' }) + 1);
            var userConfig = new DataTable("userConfig");
            userConfig.Columns.Add("Name", typeof(string));
            userConfig.Columns.Add("Value", typeof(string));
            userConfig.Rows.Add("ProfileName", IssStudy.IssProfileName);
            userConfig.Rows.Add("Username", userName);
            data.Tables.Add(userConfig);

            int index = AnalysisName.IndexOf(".xml");
            string folderName = AnalysisName.Substring(0, index);

            // study information
            var studyInfo = new DataTable("study");
            studyInfo.Columns.Add("Submission", typeof(string));
            studyInfo.Columns.Add("Supplement", typeof(string));
            studyInfo.Columns.Add("StudyCode", typeof(string));
            studyInfo.Columns.Add("AnalysisType", typeof(string));
            studyInfo.Columns.Add("random number", typeof(string));
            studyInfo.Columns.Add("AeCutoffRate", typeof(string));
            studyInfo.Columns.Add("folderName", typeof(string));
            studyInfo.Columns.Add("CumulativeAePooled", typeof(bool));
            studyInfo.Columns.Add("CumulativeAeIndividual", typeof(bool));
            studyInfo.Columns.Add("DoseResponse", typeof(bool));
            studyInfo.Columns.Add("DosingRecord", typeof(bool));
            studyInfo.Columns.Add("PkSafetyDdi", typeof(bool));
            studyInfo.Columns.Add("ClinicalDose", typeof(string));
            studyInfo.Columns.Add("MaxDayCumulative", typeof(string));
            studyInfo.Rows.Add(
                IssStudy.IssNDAName,
                IssStudy.IssSupplementNumber,
                "ISS",
                IssStudy.AnalysisType,
                IssStudy.RandomNumber,
                IssStudy.AeCutoffRate,
                folderName,
                IssStudy.CumulativeAePooled,
                IssStudy.CumulativeAeIndividual,
                IssStudy.DoseResponse,
                IssStudy.DosingRecord,
                IssStudy.PkSafetyDdi,
                IssStudy.ClinicalDose,
                IssStudy.MaxDayCumulative);
            data.Tables.Add(studyInfo);

            dataFound = false;
            var tempCounts = new DataTable("IssInOutStep2");
            tempCounts.Columns.Add("Domain", typeof(string));
            tempCounts.Columns.Add("variable", typeof(string));
            tempCounts.Columns.Add("inex", typeof(string));
            tempCounts.Columns.Add("relation", typeof(string));
            tempCounts.Columns.Add("value", typeof(string));
            tempCounts.Columns.Add("type", typeof(string));

            foreach (var CDomain in IssStudy.CDomains)
            {
                foreach (var Inclusion in CDomain.Inclusions)
                {
                    foreach (var CountValue in Inclusion.CountValues)
                    {
                        if (CountValue.SelectValue)
                        {
                            dataFound = true;
                            tempCounts.Rows.Add(
                                CDomain.CDomainName,
                                Inclusion.selectedVariable,
                                "IN",
                                Inclusion.relation,
                                CountValue.UniqueValue,
                                Inclusion.ValueType);
                        }
                    }
                }
                foreach (var Exclusion in CDomain.Exclusions)
                {
                    foreach (var CountValue in Exclusion.CountValues)
                    {
                        if (CountValue.SelectValue)
                        {
                            dataFound = true;
                            tempCounts.Rows.Add(
                                CDomain.CDomainName,
                                Exclusion.selectedVariable,
                                "EX",
                                Exclusion.relation,
                                CountValue.UniqueValue,
                                Exclusion.ValueType);
                        }
                    }
                }
            }
            if (!dataFound)
            {
                tempCounts.Rows.Add(
                        "no data",
                        "no data",
                        "no data",
                        "no data",
                        "no data",
                        "no data");
            }
            data.Tables.Add(tempCounts);

            return data;
        }

        private List<IssTRTP> sortTRTP(List<IssTRTP> orgTRTPs)
        {
            foreach (IssTRTP orgTRTP in orgTRTPs)
            {
                int index = orgTRTP.TRTP.IndexOf("mg", StringComparison.OrdinalIgnoreCase);
                if (index >= 0)
                {
                    string str2 = orgTRTP.TRTP.Substring(0, index);
                    if (str2 == "")
                    {
                        orgTRTP.sortKey = Double.MaxValue / 100000;
                    }
                    else
                    {
                        string[] str1 = str2.Split(' ');
                        string str3 = str1[str1.Length - 1];
                        if (str3 == "")
                            str3 = str1[str1.Length - 2];
                        double j = 0;
                        string[] doubleArray = Regex.Split(str3, @"[^0-9\.]+")
                            .Where(c => c != "." && c.Trim() != "").ToArray();

                        if (doubleArray.Length == 0)
                        {
                            string str4 = orgTRTP.TRTP.Substring(index + 2);
                            int index1 = str4.IndexOf("mg", StringComparison.OrdinalIgnoreCase);

                            if (index1 >= 0)
                            {
                                string str5 = str4.Substring(0, index1);
                                if (str5 == "")
                                {
                                    orgTRTP.sortKey = Double.MaxValue;
                                }
                                else
                                {
                                    string[] str6 = str5.Split(' ');
                                    string str7 = str6[str6.Length - 1];
                                    if (str7 == "")
                                        str7 = str6[str6.Length - 2];
                                    doubleArray = Regex.Split(str7, @"[^0-9\.]+")
                                        .Where(c => c != "." && c.Trim() != "").ToArray();
                                    if (doubleArray.Length == 0)
                                        orgTRTP.sortKey = Double.MaxValue;
                                }
                            }
                        }

                        bool result = double.TryParse(doubleArray[0], out j);
                        orgTRTP.NumericDose = j;
                        if (orgTRTP.TRTP.IndexOf("<") != -1)
                        {
                            orgTRTP.sortKey = j - 0.1;
                        }
                        else
                        {
                            if (orgTRTP.TRTP.IndexOf(">") != -1)
                            {
                                orgTRTP.sortKey = j + 0.1;
                            }
                            else
                            {
                                orgTRTP.sortKey = j;
                            }
                        }
                    }
                }
                else
                {
                    if (orgTRTP.TRTP.IndexOf("placebo", StringComparison.OrdinalIgnoreCase) >= 0)
                    {
                        orgTRTP.sortKey = -1;
                    }
                    else
                    {
                        orgTRTP.sortKey = Double.MaxValue / 100000;
                    }
                }
            }

            List<IssTRTP> sortedTRTP = new List<IssTRTP>();
            sortedTRTP = orgTRTPs.OrderBy(O => O.sortKey).ToList();
            return sortedTRTP;
        }

        private void WriteToXML(string newLocation, IssMappingSettings IssStudy, string[] MLStudy)
        {
            XmlTextWriter xWriter = new XmlTextWriter(newLocation, Encoding.UTF8);
            xWriter.Formatting = Formatting.Indented;
            xWriter.WriteStartElement("IssMappingSettings");
            xWriter.WriteStartElement("NdaName");
            xWriter.WriteString(IssStudy.IssNDAName);
            xWriter.WriteEndElement();
            xWriter.WriteStartElement("StudyCode");
            xWriter.WriteString(IssStudy.IssStudyCode);
            xWriter.WriteEndElement();
            xWriter.WriteStartElement("ProfileName");
            xWriter.WriteString(IssStudy.IssProfileName);
            xWriter.WriteEndElement();
            xWriter.WriteStartElement("SupplementNumber");
            xWriter.WriteString(IssStudy.IssSupplementNumber);
            xWriter.WriteEndElement();
            xWriter.WriteStartElement("displayOptions");
            xWriter.WriteString(IssStudy.displayOptions.ToString());
            xWriter.WriteEndElement();
            xWriter.WriteStartElement("AnalysisComplete");
            xWriter.WriteString(IssStudy.AnalysisComplete.ToString());
            xWriter.WriteEndElement();
            xWriter.WriteStartElement("displayML");
            xWriter.WriteString(IssStudy.displayML.ToString());
            xWriter.WriteEndElement();

            foreach (var IssDomain in IssStudy.IssStudyMappings)
            {
                xWriter.WriteStartElement("IssStudyMappings");
                xWriter.WriteStartElement("DomainName");
                xWriter.WriteString(IssDomain.IssDomainType);
                xWriter.WriteEndElement();
                xWriter.WriteStartElement("FileLocation");
                xWriter.WriteString(IssDomain.IssFileId);
                xWriter.WriteEndElement();
                foreach (var IssMapping in IssDomain.IssDomainMappings)
                {
                    xWriter.WriteStartElement("IssDomainMappings");
                    xWriter.WriteStartElement("Variable");
                    xWriter.WriteString(IssMapping.IssVariable);
                    xWriter.WriteEndElement();
                    xWriter.WriteStartElement("FileVariable");
                    xWriter.WriteString(IssMapping.IssFileVariable);
                    xWriter.WriteEndElement();
                    xWriter.WriteStartElement("MappingQuality");
                    xWriter.WriteValue(IssMapping.IssMappingQuality);
                    xWriter.WriteEndElement();
                    xWriter.WriteEndElement();
                }
                foreach (var IssFileVariable in IssDomain.IssFileVariables)
                {
                    xWriter.WriteStartElement("IssFileVariables");
                    xWriter.WriteStartElement("IssName");
                    xWriter.WriteString(IssFileVariable.IssName);
                    xWriter.WriteEndElement();
                    xWriter.WriteStartElement("IssDescription");
                    xWriter.WriteString(IssFileVariable.IssDescription);
                    xWriter.WriteEndElement();
                    xWriter.WriteStartElement("IssLabel");
                    xWriter.WriteValue(IssFileVariable.IssLabel);
                    xWriter.WriteEndElement();
                    xWriter.WriteEndElement();
                }
                xWriter.WriteEndElement();
            }

            if (IssStudy.AesevValues != null)
            {
                foreach (var AesevValue in IssStudy.AesevValues)
                {
                    xWriter.WriteStartElement("AesevValues");
                    xWriter.WriteStartElement("UniqueValue");
                    xWriter.WriteString(AesevValue.UniqueValue);
                    xWriter.WriteEndElement();
                    xWriter.WriteStartElement("order");
                    xWriter.WriteString(AesevValue.order);
                    xWriter.WriteEndElement();
                    xWriter.WriteEndElement();
                }
            }

            if (IssStudy.AsevValues != null)
            {
                foreach (var AsevValue in IssStudy.AsevValues)
                {
                    xWriter.WriteStartElement("AsevValues");
                    xWriter.WriteStartElement("UniqueValue");
                    xWriter.WriteString(AsevValue.UniqueValue);
                    xWriter.WriteEndElement();
                    xWriter.WriteStartElement("order");
                    xWriter.WriteString(AsevValue.order);
                    xWriter.WriteEndElement();
                    xWriter.WriteEndElement();
                }
            }

            foreach (var TRTxxP in IssStudy.TRTxxPs)
            {
                xWriter.WriteStartElement("TRTxxPs");
                xWriter.WriteStartElement("TRTXXP");
                xWriter.WriteString(TRTxxP.TRTXXP);
                xWriter.WriteEndElement();
                xWriter.WriteStartElement("Selection");
                xWriter.WriteString(TRTxxP.Selection.ToString());
                xWriter.WriteEndElement();
                xWriter.WriteEndElement();
            }

            if (IssStudy.IssTRTPs != null)
            {
                foreach (var IssTRTP in IssStudy.IssTRTPs)
                {
                    xWriter.WriteStartElement("IssTRTPs");
                    xWriter.WriteStartElement("IncludeStudy");
                    xWriter.WriteString(IssTRTP.IncludeStudy.ToString());
                    xWriter.WriteEndElement();
                    xWriter.WriteStartElement("StudyId");
                    xWriter.WriteString(IssTRTP.StudyId);
                    xWriter.WriteEndElement();
                    xWriter.WriteStartElement("TRTP");
                    xWriter.WriteString(IssTRTP.TRTP);
                    xWriter.WriteEndElement();
                    xWriter.WriteStartElement("RevisedTRTP");
                    xWriter.WriteString(IssTRTP.RevisedTRTP);
                    xWriter.WriteEndElement();
                    xWriter.WriteStartElement("Order");
                    xWriter.WriteString(IssTRTP.order);
                    xWriter.WriteEndElement();
                    xWriter.WriteStartElement("NumericDose");
                    xWriter.WriteString(IssTRTP.NumericDose.ToString());
                    xWriter.WriteEndElement();
                    xWriter.WriteStartElement("ARM");
                    xWriter.WriteString(IssTRTP.ARM);
                    xWriter.WriteEndElement();
                    xWriter.WriteStartElement("StudyDuration");
                    xWriter.WriteString(IssTRTP.StudyDuration);
                    xWriter.WriteEndElement();
                    xWriter.WriteStartElement("NumberOfSubjects");
                    xWriter.WriteString(IssTRTP.NumberOfSubjects);
                    xWriter.WriteEndElement();
                    xWriter.WriteStartElement("sortKey");
                    xWriter.WriteString(IssTRTP.sortKey.ToString());
                    xWriter.WriteEndElement();
                    xWriter.WriteEndElement();
                }
            }
            if (IssStudy.CDomains != null)
            {
                foreach (var CDomain in IssStudy.CDomains)
                {
                    xWriter.WriteStartElement("CDomains");
                    xWriter.WriteStartElement("CDomainName");
                    xWriter.WriteString(CDomain.CDomainName);
                    xWriter.WriteEndElement();
                    foreach (var CVariable in CDomain.CVariables)
                    {
                        xWriter.WriteStartElement("CVariables");
                        xWriter.WriteStartElement("CVariableName");
                        xWriter.WriteString(CVariable.CVariableName);
                        xWriter.WriteEndElement();
                        xWriter.WriteEndElement();
                    }
                    foreach (var Inclusion in CDomain.Inclusions)
                    {
                        xWriter.WriteStartElement("Inclusions");
                        xWriter.WriteStartElement("SelectedVariable");
                        xWriter.WriteString(Inclusion.selectedVariable);
                        xWriter.WriteEndElement();
                        xWriter.WriteStartElement("InEx");
                        xWriter.WriteString(Inclusion.InEx);
                        xWriter.WriteEndElement();
                        xWriter.WriteStartElement("relation");
                        xWriter.WriteString(Inclusion.relation);
                        xWriter.WriteEndElement();
                        xWriter.WriteStartElement("ValueType");
                        xWriter.WriteString(Inclusion.ValueType);
                        xWriter.WriteEndElement();
                        xWriter.WriteStartElement("selVarDomain");
                        xWriter.WriteString(Inclusion.selVarDomain);
                        xWriter.WriteEndElement();
                        xWriter.WriteStartElement("FileLocation");
                        xWriter.WriteString(Inclusion.FileLocation);
                        xWriter.WriteEndElement();
                        xWriter.WriteStartElement("display");
                        xWriter.WriteString(Inclusion.display.ToString());
                        xWriter.WriteEndElement();

                        foreach (var CountValue in Inclusion.CountValues)
                        {
                            xWriter.WriteStartElement("CountValues");
                            xWriter.WriteStartElement("SelectValue");
                            xWriter.WriteString(CountValue.SelectValue.ToString());
                            xWriter.WriteEndElement();
                            xWriter.WriteStartElement("UniqueValue");
                            xWriter.WriteString(CountValue.UniqueValue);
                            xWriter.WriteEndElement();
                            xWriter.WriteEndElement();
                        }
                        xWriter.WriteEndElement();
                    }

                    foreach (var Exclusion in CDomain.Exclusions)
                    {
                        xWriter.WriteStartElement("Exclusions");
                        xWriter.WriteStartElement("SelectedVariable");
                        xWriter.WriteString(Exclusion.selectedVariable);
                        xWriter.WriteEndElement();
                        xWriter.WriteStartElement("InEx");
                        xWriter.WriteString(Exclusion.InEx);
                        xWriter.WriteEndElement();
                        xWriter.WriteStartElement("relation");
                        xWriter.WriteString(Exclusion.relation);
                        xWriter.WriteEndElement();
                        xWriter.WriteStartElement("ValueType");
                        xWriter.WriteString(Exclusion.ValueType);
                        xWriter.WriteEndElement();
                        xWriter.WriteStartElement("selVarDomain");
                        xWriter.WriteString(Exclusion.selVarDomain);
                        xWriter.WriteEndElement();
                        xWriter.WriteStartElement("FileLocation");
                        xWriter.WriteString(Exclusion.FileLocation);
                        xWriter.WriteEndElement();
                        xWriter.WriteStartElement("display");
                        xWriter.WriteString(Exclusion.display.ToString());
                        xWriter.WriteEndElement();

                        foreach (var CountValue in Exclusion.CountValues)
                        {
                            xWriter.WriteStartElement("CountValues");
                            xWriter.WriteStartElement("SelectValue");
                            xWriter.WriteString(CountValue.SelectValue.ToString());
                            xWriter.WriteEndElement();
                            xWriter.WriteStartElement("UniqueValue");
                            xWriter.WriteString(CountValue.UniqueValue);
                            xWriter.WriteEndElement();
                            xWriter.WriteEndElement();
                        }
                        xWriter.WriteEndElement();
                    }
                    xWriter.WriteEndElement();
                }
            }
            if (IssStudy.AeCutoffRate != null)
            {
                xWriter.WriteStartElement("AeCutoffRate");
                xWriter.WriteString(IssStudy.AeCutoffRate);
                xWriter.WriteEndElement();
            }
            if (IssStudy.AnalysisType != null)
            {
                xWriter.WriteStartElement("AnalysisType");
                xWriter.WriteString(IssStudy.AnalysisType);
                xWriter.WriteEndElement();
            }
            xWriter.WriteStartElement("CumulativeAePooled");
            xWriter.WriteString(IssStudy.CumulativeAePooled.ToString());
            xWriter.WriteEndElement();
            xWriter.WriteStartElement("CumulativeAeIndividual");
            xWriter.WriteString(IssStudy.CumulativeAeIndividual.ToString());
            xWriter.WriteEndElement();
            xWriter.WriteStartElement("DoseResponse");
            xWriter.WriteString(IssStudy.DoseResponse.ToString());
            xWriter.WriteEndElement();
            xWriter.WriteStartElement("DosingRecord");
            xWriter.WriteString(IssStudy.DosingRecord.ToString());
            xWriter.WriteEndElement();
            xWriter.WriteStartElement("MaxDayCumulative");
            xWriter.WriteString(IssStudy.MaxDayCumulative);
            xWriter.WriteEndElement();
            xWriter.WriteStartElement("PkSafetyDdi");
            xWriter.WriteString(IssStudy.PkSafetyDdi.ToString());
            xWriter.WriteEndElement();
            xWriter.WriteStartElement("ClinicalDose");
            xWriter.WriteString(IssStudy.ClinicalDose);
            xWriter.WriteEndElement();
            xWriter.WriteEndElement();
            xWriter.Close();
        }

        private Analysis ReadXmlData(string reportPath)
        {
            XmlDocument xDoc = new XmlDocument();
            xDoc.Load(reportPath);

            IssMappingSettings IssStudy = new IssMappingSettings();
            var MLStudy = new string[1];

            IssStudy.IssNDAName = xDoc.SelectSingleNode("IssMappingSettings/NdaName").InnerText;
            IssStudy.IssStudyCode = xDoc.SelectSingleNode("IssMappingSettings/StudyCode").InnerText;
            IssStudy.IssSupplementNumber = xDoc.SelectSingleNode("IssMappingSettings/SupplementNumber").InnerText;
            IssStudy.IssProfileName = xDoc.SelectSingleNode("IssMappingSettings/ProfileName").InnerText;
            IssStudy.displayOptions = Convert.ToBoolean(xDoc.SelectSingleNode("IssMappingSettings/displayOptions").InnerText);
            IssStudy.AnalysisComplete = Convert.ToBoolean(xDoc.SelectSingleNode("IssMappingSettings/AnalysisComplete").InnerText);
            if ((xDoc.SelectSingleNode("IssMappingSettings/displayML")) != null)
                IssStudy.displayML = Convert.ToBoolean(xDoc.SelectSingleNode("IssMappingSettings/displayML").InnerText);
            else
                IssStudy.displayML = false;
            IssStudy.IssStudyMappings = new List<IssDomain>();
            IssStudy.IssTRTPs = new List<IssTRTP>();
            IssStudy.TRTxxPs = new List<TRTxxP>();
            IssStudy.CDomains = new List<CDomain>();
            IssStudy.AesevValues = new List<AesevValue>();
            IssStudy.AsevValues = new List<AesevValue>();

            foreach (XmlNode node1 in xDoc.SelectNodes("IssMappingSettings/IssStudyMappings"))
            {
                var newDomain = new IssDomain();
                newDomain.IssDomainType = node1.SelectSingleNode("DomainName").InnerText;
                newDomain.IssFileId = node1.SelectSingleNode("FileLocation").InnerText;
                newDomain.IssDomainMappings = new List<IssMapping>();
                newDomain.IssFileVariables = new List<IssFileVariable>();
                foreach (XmlNode node2 in node1.SelectNodes("IssDomainMappings"))
                {
                    IssMapping item = new IssMapping();
                    item.IssVariable = node2.SelectSingleNode("Variable").InnerText;
                    item.IssMappingQuality = Convert.ToInt32(node2.SelectSingleNode("MappingQuality").InnerText);
                    item.IssFileVariable = node2.SelectSingleNode("FileVariable").InnerText;
                    newDomain.IssDomainMappings.Add(item);
                }
                foreach (XmlNode node2 in node1.SelectNodes("IssFileVariables"))
                {
                    IssFileVariable item = new IssFileVariable();
                    item.IssName = node2.SelectSingleNode("IssName").InnerText;
                    item.IssDescription = node2.SelectSingleNode("IssDescription").InnerText;
                    item.IssLabel = node2.SelectSingleNode("IssLabel").InnerText;
                    newDomain.IssFileVariables.Add(item);
                }
                IssStudy.IssStudyMappings.Add(newDomain);
            }

            foreach (XmlNode node1 in xDoc.SelectNodes("IssMappingSettings/AesevValues"))
            {
                var newAesevValue = new AesevValue();

                newAesevValue.UniqueValue = node1.SelectSingleNode("UniqueValue").InnerText;
                newAesevValue.order = node1.SelectSingleNode("order").InnerText;

                IssStudy.AesevValues.Add(newAesevValue);
            }

            foreach (XmlNode node1 in xDoc.SelectNodes("IssMappingSettings/AsevValues"))
            {
                var newAsevValue = new AesevValue();

                newAsevValue.UniqueValue = node1.SelectSingleNode("UniqueValue").InnerText;
                newAsevValue.order = node1.SelectSingleNode("order").InnerText;

                IssStudy.AsevValues.Add(newAsevValue);
            }

            foreach (XmlNode node1 in xDoc.SelectNodes("IssMappingSettings/TRTxxPs"))
            {
                var newTRTxxP = new TRTxxP();

                newTRTxxP.TRTXXP = node1.SelectSingleNode("TRTXXP").InnerText;
                newTRTxxP.Selection = Convert.ToBoolean(node1.SelectSingleNode("Selection").InnerText);

                IssStudy.TRTxxPs.Add(newTRTxxP);
            }
            if (IssStudy.displayOptions)
            {
                if (xDoc.SelectSingleNode("IssMappingSettings/AnalysisType") != null)
                    IssStudy.AnalysisType = xDoc.SelectSingleNode("IssMappingSettings/AnalysisType").InnerText;
                if (xDoc.SelectSingleNode("IssMappingSettings/AeCutoffRate") != null)
                    IssStudy.AeCutoffRate = xDoc.SelectSingleNode("IssMappingSettings/AeCutoffRate").InnerText;
                IssStudy.CumulativeAePooled = Convert.ToBoolean(xDoc.SelectSingleNode("IssMappingSettings/CumulativeAePooled").InnerText);
                IssStudy.CumulativeAeIndividual = Convert.ToBoolean(xDoc.SelectSingleNode("IssMappingSettings/CumulativeAeIndividual").InnerText);
                IssStudy.DoseResponse = Convert.ToBoolean(xDoc.SelectSingleNode("IssMappingSettings/DoseResponse").InnerText);
                IssStudy.DosingRecord = Convert.ToBoolean(xDoc.SelectSingleNode("IssMappingSettings/DosingRecord").InnerText);
                if (xDoc.SelectSingleNode("IssMappingSettings/MaxDayCumulative") != null)
                    IssStudy.MaxDayCumulative = xDoc.SelectSingleNode("IssMappingSettings/MaxDayCumulative").InnerText;
                IssStudy.ClinicalDose = xDoc.SelectSingleNode("IssMappingSettings/ClinicalDose").InnerText;
                IssStudy.PkSafetyDdi = Convert.ToBoolean(xDoc.SelectSingleNode("IssMappingSettings/PkSafetyDdi").InnerText);
                foreach (XmlNode node1 in xDoc.SelectNodes("IssMappingSettings/IssTRTPs"))
                {
                    IssTRTP newTRTP = new IssTRTP();

                    newTRTP.IncludeStudy = Convert.ToBoolean(node1.SelectSingleNode("IncludeStudy").InnerText);
                    newTRTP.StudyId = node1.SelectSingleNode("StudyId").InnerText;
                    newTRTP.TRTP = node1.SelectSingleNode("TRTP").InnerText;
                    newTRTP.RevisedTRTP = node1.SelectSingleNode("RevisedTRTP").InnerText;
                    if (node1.SelectSingleNode("NumericDose") != null)
                        newTRTP.NumericDose = Convert.ToDouble(node1.SelectSingleNode("NumericDose").InnerText);
                    newTRTP.order = node1.SelectSingleNode("Order").InnerText;
                    newTRTP.ARM = node1.SelectSingleNode("ARM").InnerText;
                    newTRTP.StudyDuration = node1.SelectSingleNode("StudyDuration").InnerText;
                    newTRTP.NumberOfSubjects = node1.SelectSingleNode("NumberOfSubjects").InnerText;
                    newTRTP.sortKey = Convert.ToDouble(node1.SelectSingleNode("sortKey").InnerText);

                    IssStudy.IssTRTPs.Add(newTRTP);
                }

                foreach (XmlNode node1 in xDoc.SelectNodes("IssMappingSettings/CDomains"))
                {
                    var newCDomain = new CDomain();

                    newCDomain.CDomainName = node1.SelectSingleNode("CDomainName").InnerText;
                    newCDomain.CVariables = new List<CVariable>();
                    newCDomain.Exclusions = new List<selectedVar>();
                    newCDomain.Inclusions = new List<selectedVar>();
                    foreach (XmlNode node2 in node1.SelectNodes("CVariables"))
                    {
                        CVariable item = new CVariable();
                        item.CVariableName = node2.SelectSingleNode("CVariableName").InnerText;
                        newCDomain.CVariables.Add(item);
                    }
                    foreach (XmlNode node2 in node1.SelectNodes("Inclusions"))
                    {
                        selectedVar item1 = new selectedVar();
                        item1.InEx = node2.SelectSingleNode("InEx").InnerText;
                        item1.selectedVariable = node2.SelectSingleNode("SelectedVariable").InnerText;
                        item1.relation = node2.SelectSingleNode("relation").InnerText;
                        item1.ValueType = node2.SelectSingleNode("ValueType").InnerText;
                        item1.selVarDomain = node2.SelectSingleNode("selVarDomain").InnerText;
                        item1.FileLocation = node2.SelectSingleNode("FileLocation").InnerText;
                        item1.display = Convert.ToBoolean(node2.SelectSingleNode("display").InnerText);
                        item1.CountValues = new List<CountValue>();
                        foreach (XmlNode node3 in node2.SelectNodes("CountValues"))
                        {
                            CountValue item2 = new CountValue();
                            item2.SelectValue = Convert.ToBoolean(node3.SelectSingleNode("SelectValue").InnerText);
                            item2.UniqueValue = node3.SelectSingleNode("UniqueValue").InnerText;
                            item1.CountValues.Add(item2);
                        }
                        newCDomain.Inclusions.Add(item1);
                    }

                    foreach (XmlNode node2 in node1.SelectNodes("Exclusions"))
                    {
                        selectedVar item1 = new selectedVar();
                        item1.InEx = node2.SelectSingleNode("InEx").InnerText;
                        item1.selectedVariable = node2.SelectSingleNode("SelectedVariable").InnerText;
                        item1.relation = node2.SelectSingleNode("relation").InnerText;
                        item1.ValueType = node2.SelectSingleNode("ValueType").InnerText;
                        item1.selVarDomain = node2.SelectSingleNode("selVarDomain").InnerText;
                        item1.FileLocation = node2.SelectSingleNode("FileLocation").InnerText;
                        item1.display = Convert.ToBoolean(node2.SelectSingleNode("display").InnerText);
                        item1.CountValues = new List<CountValue>();
                        foreach (XmlNode node3 in node2.SelectNodes("CountValues"))
                        {
                            CountValue item2 = new CountValue();
                            item2.SelectValue = Convert.ToBoolean(node3.SelectSingleNode("SelectValue").InnerText);
                            item2.UniqueValue = node3.SelectSingleNode("UniqueValue").InnerText;
                            item1.CountValues.Add(item2);
                        }
                        newCDomain.Exclusions.Add(item1);
                    }
                    IssStudy.CDomains.Add(newCDomain);
                }
            }

            var analysis = new Analysis();
            analysis.IssStudy = IssStudy;
            analysis.MLStudy = MLStudy;

            return analysis;
        }
    }
}