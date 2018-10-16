using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Web.Http;
using iPortal;
using iPortal.App_Data;
using iPortal.Models.PkView;
using iPortal.Config;
using iPortal.Models;
using SasJobs.ClientLibrary;
using SasJobs.Messages;
using System.IO;
using System.Web;
using iPortal.Models.Shared.ClinicalData;
using iPortal.Models.Shared;

namespace iPortal.Controllers.PkView
{
    /// <summary>
    /// Mapping controller
    /// </summary>
    public class MappingController : ApiController
    {
        private ProjectRepository projectRepository;

        /// <summary>
        /// Mapping controller constructor
        /// </summary>
        public MappingController()
        {
            this.projectRepository = new ProjectRepository();
        }

        /// <summary>
        /// Load a study from a saved profile
        /// </summary>
        /// <returns>A job id</returns>
        [HttpGet, Route("api/pkview/submissions/{submissionId}/profiles/{profileName}/supplements/{serialNumber}/studies/{studyCode}/")]
        public StudySettings LoadStudy(string submissionId, string profileName, string serialNumber, string studyCode, string userName = null, bool details = false)
        {
            Project project = this.projectRepository.Find(submissionId, profileName, userName,
                details ? ProjectRetrievalFlags.Default : ProjectRetrievalFlags.MeanDataOnly);

            // Return null if project not found
            if (project == null) return null;

            var study = project.Studies.FirstOrDefault(s =>
                s.SupplementNumber.Equals(serialNumber, StringComparison.InvariantCultureIgnoreCase) &&
                s.StudyCode.Equals(studyCode, StringComparison.InvariantCultureIgnoreCase));

            return study;
        }

        /// <summary>
        /// Run the mapping procedure
        /// </summary>
        /// <returns>A job id</returns>
        [HttpGet, Route("api/pkview/submissions/{submissionId}/supplements/{supplementNumber}/studies/{studyCode}/initialize")]
        public string InitializeStudy(string submissionId, string supplementNumber, string studyCode)
        {
            var manager = new StudyDataManager();
            return manager.Initialize(submissionId, supplementNumber, studyCode);
        }

        /// <summary>
        /// Main Get function
        /// </summary>
        /// <returns>A list of results</returns>
        [HttpGet, Route("api/pkview/submissions/{submissionId}/supplements/{supplementNumber}/studies/{studyCode}/initialization/result")]
        public JobResponse<StudySettings> GetStudyInitializationResult(string submissionId, string supplementNumber, string studyCode, string jobId)
        {
            var manager = new StudyDataManager();
            return manager.GetInitializationResult(submissionId, supplementNumber, studyCode, jobId);
        }

        /// <summary>
        /// Save the mapping configurations for a single study
        /// </summary>
        /// <returns>0 or an error code</returns>
        [HttpPost, Route("api/pkview/submissions/{submissionId}/profiles/{profileName}/supplements/{supplementNumber}/studies/{studyCode}/save")]
        public string SaveStudy([FromBody] StudySettings revisedMappings, string SubmissionId, string profileName, string SupplementNumber, string StudyCode)
        {
            return this.Save(new List<StudySettings> { revisedMappings }, profileName);
        }

        /// <summary>
        /// Save the Safety Analysis Project settings
        /// </summary>
        /// <returns>0 or an error code</returns>
        [HttpGet, Route("api/pkview/saveSafetyProject")]
        public string SaveSafetyProject(string submissionId, string projectName)
        {
            string userName = Users.GetCurrentUserName();
            Project project;

            if (projectName == null)
            {
                var currentDate = DateTime.Now.ToString("yyyy-MM-dd-HHmmss");
                projectName = String.Format("{0}_{1}", userName, currentDate);
            }
            project = new Project
            {
                ProjectName = projectName,
                SubmissionId = submissionId,
                Studies = null,
                RevisionHistory = new List<ProjectRevision>()
            };
            var revision = new ProjectRevision
            {
                RevisionId = 1,
                Name = projectName,
                Owner = userName,
                Date = DateTime.Now,
                Action = ActionTypes.Create
            };
            project.RevisionHistory.Add(revision);

            project.Studies = new List<StudySettings>();

            StudySettings SafetyStudy = new StudySettings();
            SafetyStudy.NDAName = submissionId;
            SafetyStudy.StudyCode = "ISS";
            SafetyStudy.ProfileName = projectName;

            project.Studies.Add(SafetyStudy);

            this.projectRepository.CreateOrUpdate(project);
            return projectName;
        }

        /// <summary>
        /// Save the mapping configurations for an nda
        /// </summary>
        /// <returns>0 or an error code</returns>
        [HttpPost, Route("api/pkview/saveMappings")]
        public string Save([FromBody] List<StudySettings> revisedMappingsList, string projectName = null)
        {
            if (revisedMappingsList != null && revisedMappingsList.Any())
            {
                string submissionId = revisedMappingsList[0].NDAName;
                string userName = Users.GetCurrentUserName();
                Project project;

                // Generate a new configuration name from user and date
                if (projectName == null)
                {
                    var currentDate = DateTime.Now.ToString("yyyy-MM-dd-HHmmss");
                    projectName = String.Format("{0}_{1}", userName, currentDate);
                }
                else // Attempt to load the project and save the studies into it
                {
                    project = this.projectRepository.Find(submissionId, projectName);

                    // If existing config file found and it contains studies
                    if (project != null && project.Studies.Any())
                    {
                        // Create a saved revision
                        var savedRevision = new ProjectRevision
                        {
                            RevisionId = project.RevisionHistory.Last().RevisionId + 1,
                            Name = projectName,
                            Date = DateTime.Now,
                            Owner = userName,
                            Action = ActionTypes.Save
                        };
                        project.RevisionHistory.Add(savedRevision);

                        // For each study we want to save
                        foreach (var updatedStudy in revisedMappingsList)
                        {
                            // Find the study if existing
                            var oldStudy = project.Studies.FirstOrDefault(
                                s => s.StudyCode == updatedStudy.StudyCode &&
                                    s.SupplementNumber == updatedStudy.SupplementNumber);

                            // if it does exist, update it
                            if (oldStudy != null)
                            {
                                oldStudy.RevisionId = savedRevision.RevisionId;

                                oldStudy.StudyDesign = updatedStudy.StudyDesign;
                                oldStudy.StudyError = updatedStudy.StudyError;
                                oldStudy.Cumulative = updatedStudy.Cumulative;
                                oldStudy.SubjectCTCorrelation = updatedStudy.SubjectCTCorrelation;
                                oldStudy.ScatterPlot = updatedStudy.ScatterPlot;
                                oldStudy.Demographictable = updatedStudy.Demographictable;
                                oldStudy.UseEx = updatedStudy.UseEx;
                                oldStudy.UseExRef = updatedStudy.UseExRef;
                                oldStudy.UseSuppdm = updatedStudy.UseSuppdm;
                                oldStudy.DisablePcCleanup = updatedStudy.DisablePcCleanup;
                                oldStudy.UseCustomArms = updatedStudy.UseCustomArms;
                                oldStudy.UseCustomPcVisit = updatedStudy.UseCustomPcVisit;
                                oldStudy.UseCustomPcPctptnum = updatedStudy.UseCustomPcPctptnum;
                                oldStudy.UseCustomPpVisit = updatedStudy.UseCustomPpVisit;

                                oldStudy.Cohorts = updatedStudy.Cohorts;
                                oldStudy.StudyMappings = updatedStudy.StudyMappings;
                                oldStudy.ArmMappings = updatedStudy.ArmMappings;
                                oldStudy.PcVisitMappings = updatedStudy.PcVisitMappings;
                                oldStudy.PcPctptnumMappings = updatedStudy.PcPctptnumMappings;
                                oldStudy.PpVisitMappings = updatedStudy.PpVisitMappings;

                                oldStudy.Reports = updatedStudy.Reports;
                            }
                            else // Study not found, store it directly
                            {
                                updatedStudy.ProfileName = projectName;
                                project.Studies.Add(updatedStudy);
                            }
                        }
                        this.projectRepository.CreateOrUpdate(project);
                        return projectName;
                    }
                }

                // project not found, store the whole list                                    
                revisedMappingsList.ForEach(s =>
                { s.ProfileName = projectName; s.RevisionId = 1; });
                project = new Project
                {
                    ProjectName = projectName,
                    SubmissionId = submissionId,
                    Studies = revisedMappingsList,
                    RevisionHistory = new List<ProjectRevision>()
                };
                var revision = new ProjectRevision
                {
                    RevisionId = 1,
                    Name = projectName,
                    Owner = userName,
                    Date = DateTime.Now,
                    Action = ActionTypes.Create
                };
                project.RevisionHistory.Add(revision);

                // Save user mappings
                this.projectRepository.CreateOrUpdate(project);
                return projectName;
            }

            return null;
        }

        /// <summary>
        /// Obtain the list of potential references
        /// </summary>
        /// <returns>0 or an error code</returns>
        [HttpPost, Route("api/pkview/getReference")]
        public IDictionary<string, IEnumerable<string>> GetReference([FromBody] StudySettings revisedMappings)
        {
            // Apply Ex setting for reference computation
            revisedMappings.UseEx = revisedMappings.UseExRef;

            DataSet data = revisedMappings.ToMappingDataSet();
            JobResponse response;

            var id = SasClientObject.NewJob(data, "ListReferences");
            do
            {
                System.Threading.Thread.Sleep(500);
                response = SasClientObject.Getjob(id);
            } while (response.Status == SasJobs.Messages.StatusCode.Running);

            // return the potential references
            if (response.Status == SasJobs.Messages.StatusCode.Done)
            {
                var resultsTable = response.Data.Tables[0];
                if (resultsTable.Rows.Count > 0)
                {
                    var referenceTable = new Dictionary<string, IEnumerable<string>>();
                    foreach (var row in resultsTable.AsEnumerable())
                    {
                        var cohort = row["CohortDescription"].ToString();

                        if (!referenceTable.ContainsKey(cohort))
                            referenceTable.Add(cohort, new List<string>());

                        var reference = row["Reference"].ToString().Trim();
                        if (!String.IsNullOrWhiteSpace(reference))
                            ((List<string>)referenceTable[cohort])
                                .Add(reference);
                    }
                    return referenceTable;
                }
            }

            return null;
        }

        /// <summary>
        /// Obtain the list of potential references
        /// </summary>
        /// <returns>0 or an error code</returns>
        [HttpPost, Route("api/pkview/determineStudyDesign")]
        public int? DetermineStudyDesign([FromBody] StudySettings revisedMappings)
        {
            DataSet data = revisedMappings.ToMappingDataSet();
            JobResponse response;

            var id = SasClientObject.NewJob(data, "DetermineStudyDesign");
            //var id = SasClientObject.NewJob(data, "variabilitytest4");
            do
            {
                System.Threading.Thread.Sleep(500);
                response = SasClientObject.Getjob(id);
            } while (response.Status == SasJobs.Messages.StatusCode.Running);

            // return the potential references
            if (response.Status == SasJobs.Messages.StatusCode.Done)
            {
                var resultsTable = response.Data.Tables[0];
                if (resultsTable.Rows.Count > 0)
                {
                    var studyDesign = resultsTable.AsEnumerable().First()["StudyDesign"].ToString();
                    switch (studyDesign.ToLower())
                    {
                        case "unknown": return 1;
                        case "sequential": return 2;
                        case "parallel": return 3;
                        case "crossover": return 4;
                        default: return 0;
                    }
                }

            }

            return null;
        }

        /// <summary>
        /// Retrieve the list of studies in the submission
        /// </summary>
        /// <param name="ndaFolderName"></param>
        /// <returns></returns>
        [HttpGet, Route("api/pkview/submissions/{submissionId}/studies")]
        public List<Study> GetStudies(string submissionId)
        {
            var repository = new ClinicalDataRepository();
            return repository.GetStudies(submissionId);
        }

        /// <summary>
        /// Retrieve the list of serial numbers in the submission
        /// </summary>
        /// <param name="ndaFolderName"></param>
        /// <returns></returns>
        [HttpGet, Route("api/pkview/submissions/{submissionId}/SerialNumbers")]
        public List<string> GetSerialNumbers(string submissionId)
        {
            var repository = new ClinicalDataRepository();
            return repository.GetSerialNumbers(submissionId);
        }

    }
}
