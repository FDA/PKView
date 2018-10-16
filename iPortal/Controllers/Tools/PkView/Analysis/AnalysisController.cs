using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Web.Http;
using iPortal.Models.PkView;
using SasJobs.ClientLibrary;
using SasJobs.Messages;
using System.Web;
using System.IO;
using iPortal.Models.PkView.Reports;
using iPortal.Models;
using iPortal.Models.Shared;

namespace iPortal.Controllers.PkView
{
    /// <summary>
    /// Analysis service  controller
    /// </summary>    
    public class AnalysisController : ApiController
    {
        private ProjectRepository projectRepository;

        /// <summary>
        /// Mapping controller constructor
        /// </summary>
        public AnalysisController() 
        {
            this.projectRepository = new ProjectRepository();
        }

        /// <summary>
        /// The run function runs the whole NDA analysis
        /// </summary>
        /// <returns>null if evertything ok or the error code</returns>
        [HttpPost, Route("api/pkview/analysis/run")]
        public string Run([FromBody] StudySettings revisedMappings)
        {
            // Apply Ex setting used for reference computation
            revisedMappings.UseEx = revisedMappings.UseExRef;

            DataSet data = revisedMappings.ToMappingDataSet(true);

            // Delete old analysis results
            DeleteAnalysisResults(revisedMappings);

            // Run the analysis code
            return SasClientObject.NewJob(data, "RunStudyAnalysis").ToString();           
        }

        /// <summary>
        /// Main Get function
        /// </summary>
        /// <returns>The analysis status</returns>
        [HttpGet, Route("api/pkview/analysis/tryGet")]
        public JobResponse<AnalysisResults> Get(Guid jobId)
        {
            var response = SasClientObject.Getjob(jobId);

            // If no data was received the process is still running, return an empty list
            if (response.Status != SasJobs.Messages.StatusCode.Done)
                return new JobResponse<AnalysisResults>(response, null);

            // no data was returned
            if (response.Data.Tables.Count == 0)
                return new JobResponse<AnalysisResults>(response, null);

            // Save analysis results 
            var resultData = new AnalysisResults(response.Data);
            Project project = this.projectRepository.Find(resultData.SubmissionId, resultData.Profile ?? "");
            if (project != null) 
            { 
                var study = project.Studies.FirstOrDefault(s =>
                    s.SupplementNumber.Equals(resultData.SupplementId, StringComparison.InvariantCultureIgnoreCase) &&
                    s.StudyCode.Equals(resultData.StudyId, StringComparison.InvariantCultureIgnoreCase));
                if (study != null)
                {
                    var revision = new ProjectRevision
                    {
                        RevisionId = project.RevisionHistory.Last().RevisionId + 1,
                        Name = project.ProjectName,
                        Date = DateTime.Now,
                        Owner = Users.GetCurrentUserName(),
                        Action = ActionTypes.Save
                    };
                    project.RevisionHistory.Add(revision);

                    study.RevisionId = revision.RevisionId;
                    study.Concentration = resultData.Concentration;
                    study.Pharmacokinetics = resultData.Pharmacokinetics;
                    study.Analytes = null; // deprecated
                    study.Parameters = null; // deprecated

                    this.projectRepository.CreateOrUpdate(project);
                }
            }

            // Clear individual data before sending the response back
            if (resultData.Concentration != null && resultData.Concentration.Sections != null)
                resultData.Concentration.Sections.ForEach(s => s.SubSections = null);
            if (resultData.Pharmacokinetics != null && resultData.Pharmacokinetics.Sections != null)
                resultData.Pharmacokinetics.Sections.ForEach(s => s.SubSections = null);

            return new JobResponse<AnalysisResults>(response, resultData);
        }

        private void DeleteAnalysisResults(StudySettings studyMetadata)
        {
            // Delete report settings
            var study = new MappingController().LoadStudy(studyMetadata.NDAName, studyMetadata.ProfileName,
                studyMetadata.SupplementNumber, studyMetadata.StudyCode);     

            // Delete reports
            study.Reports = new List<Report>();
            study.Analytes = null;
            study.Parameters = null;
            study.Concentration = null;
            study.Pharmacokinetics = null;
            new MappingController().SaveStudy(study, study.NDAName, study.ProfileName, study.SupplementNumber, study.StudyCode);

            // Delete the output files
            var userName = Users.GetCurrentUserName();
            var studyPath = string.Format(@"\\{0}\Output Files\PKView\{1}\{2}\{3}\{4}\{5}",
                iPortalApp.AppServerName, userName, study.ProfileName, study.NDAName, study.SupplementNumber, study.StudyCode);
            var studyFolder = new DirectoryInfo(studyPath);
            if (studyFolder.Exists)
                studyFolder.Delete(true);
        }
    }
}
