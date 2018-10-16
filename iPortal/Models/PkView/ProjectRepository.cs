using iPortal.Models.PkView.Reports;
using iPortal.Models.Shared;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using System.Web;

namespace iPortal.Models.PkView
{
    /// <summary>
    /// This enum is used to specify the flags for project data retrieval
    /// </summary>
    public enum ProjectRetrievalFlags
    {
        Default = 0,
        MeanDataOnly = 1,
        MetaDataOnly = 2
    };

    /// <summary>
    /// Defines a project repository
    /// </summary>
    public class ProjectRepository
    {
        /// <summary>
        /// Find a project in the repository
        /// </summary>
        /// <param name="submissionId">Parent submission for the project</param>
        /// <param name="projectName">Project name</param>
        /// <param name="userName">user the project belongs to, defaults to current user</param>
        /// <returns></returns>
        public Project Find(string submissionId, string projectName, string userName = null, ProjectRetrievalFlags flags = 0) 
        {
            string xmlFilename = String.Format("{0}_{1}", submissionId, projectName ?? "");
            if (XmlUserData.Exists(xmlFilename, "PkView", userName))
            {
                Project project;
                try
                {
                    project = XmlUserData.Load<Project>(xmlFilename, "PkView", userName);
                }
                catch
                { // Load legacy format
                    project = new Project();
                    project.Studies = XmlUserData.Load<List<StudySettings>>(xmlFilename, "PkView", userName);
                    if (project.Studies == null || project.Studies.Count == 0) return null;
                    project.SubmissionId = submissionId;
                    project.ProjectName = projectName;
                    userName = userName ?? Users.GetCurrentUserName();

                    // Initialize revision history
                    project.RevisionHistory = new List<ProjectRevision>();
                    var revision = new ProjectRevision
                    {
                        RevisionId = 1,
                        Name = projectName,
                        Owner = userName,
                        Date = DateTime.Now,
                        Action = ActionTypes.Create
                    };
                    project.RevisionHistory.Add(revision);
                    project.Studies.ForEach(s => s.RevisionId = 1);
                    XmlUserData.Save<Project>(project, xmlFilename, "PkView", userName);
                }

                // Return if project is empty or null
                if (project == null || project.Studies == null || !project.Studies.Any())
                    return project;

                // Trim data based on project retrieval flags
                switch (flags)
                {
                    // Clear mean data
                    case ProjectRetrievalFlags.MeanDataOnly:  
                        foreach(var study in project.Studies)
                        {
                            if (study.Concentration != null && study.Concentration.Sections != null)
                                study.Concentration.Sections.ForEach(s => s.SubSections = null);
                            if (study.Pharmacokinetics != null && study.Pharmacokinetics.Sections != null)
                                study.Pharmacokinetics.Sections.ForEach(s => s.SubSections = null);
                        }
                        break;
                    // Clear everything but metadata
                    case ProjectRetrievalFlags.MetaDataOnly:
                        foreach (var study in project.Studies)
                        {
                            study.StudyMappings = null;
                            study.ArmMappings = null;
                            study.Concentration = null;
                            study.Pharmacokinetics = null;
                            study.Analytes = null;
                            study.Parameters = null;
                            study.Reports = null;                          
                        }
                        break;
                }

                return project;
            }
            return null;
        }

        /// <summary>
        /// Return a list of projects for the specified user and submission
        /// </summary>
        /// <param name="submissionId">Submission id</param>
        /// <param name="userName">optional, project owner</param>
        /// <returns></returns>
        public IEnumerable<string> List(string submissionId, string userName = null)
        {
            var projects = XmlUserData.FindFiles(submissionId + "_*", "PkView", userName)
                .OrderBy(f => f.LastWriteTime).Reverse()
                .Select(f => f.Name.Substring(f.Name.IndexOf("_") + 1,
                    f.Name.LastIndexOf('.') - f.Name.IndexOf("_") - 1));
            return projects;
        }

        /// <summary>
        /// Create a project in the repository
        /// </summary>
        /// <param name="project">project to add to the repository</param>
        /// <param name="userName">project owner, defaults to current user</param>
        public bool CreateOrUpdate(Project project, string userName = null) 
        {
            string xmlFilename = String.Format("{0}_{1}", project.SubmissionId, project.ProjectName ?? "");
            XmlUserData.Save<Project>(project, xmlFilename, "PkView", userName);
            return true;
        }

        /// <summary>
        /// Remove a project from the repository
        /// </summary>
        /// <param name="submissionId">Parent submission for the project</param>
        /// <param name="projectName">Project name</param>
        /// <param name="userName">user the project belongs to, defaults to current user</param>        
        /// <returns></returns>
        public bool Remove(string submissionId, string projectName, string userName = null) 
        {
            // Use current user if not specified
            userName = userName ?? Users.GetCurrentUserName();

            // Delete output files
            var outputPath = string.Format(@"\\{0}\Output Files\PkView\{1}\{2}\{3}",
                iPortalApp.AppServerName, userName, projectName, submissionId);
            if (Directory.Exists(outputPath))
                Directory.Delete(outputPath, true);

            // Delete output package if present
            if (File.Exists(outputPath + ".zip"))
                File.Delete(outputPath + ".zip");

            string xmlFilename = String.Format("{0}_{1}", submissionId, projectName ?? "");
            return XmlUserData.Delete(xmlFilename, "PkView", userName);
        }

        /// <summary>
        /// Import a project from the source user
        /// </summary>
        /// <param name="submissionId">Parent submission for the project</param>
        /// <param name="projectName">Project name</param>
        /// <param name="sourceUserName">user the project belongs to</param>
        /// <returns></returns>
        public bool Import(string submissionId, string projectName, string sourceUserName) 
        {
            // Find the source project
            var project = this.Find(submissionId, projectName, sourceUserName);
            if (project == null) return false;

            // destination username
            var targetUserName = Users.GetCurrentUserName();

            // Create share revision
            var revision = new ProjectRevision
            {
                RevisionId = project.RevisionHistory.Last().RevisionId + 1,
                Name = projectName,
                Date = DateTime.Now,
                Owner = sourceUserName,
                Action = ActionTypes.Import
            };
            project.RevisionHistory.Add(revision);

            // Fix name collisions
            var targetProjectName = projectName;
            string xmlFilename = String.Format("{0}_{1}", submissionId, projectName ?? "");
            if (XmlUserData.Exists(xmlFilename, "PkView", targetUserName))
            {
                // Add a project rename entry by the destination user
                var renameRevision = new ProjectRevision
                {
                    RevisionId = project.RevisionHistory.Last().RevisionId + 1,
                    Date = DateTime.Now,
                    Owner = targetUserName,
                    Action = ActionTypes.Rename
                };
                project.RevisionHistory.Add(renameRevision);

                // Add an incremental numeric suffix while a collision is found
                int i = 1;
                do
                {
                    renameRevision.Name = string.Format("{0} ({1})", projectName, i++);
                    xmlFilename = String.Format("{0}_{1}", submissionId, renameRevision.Name ?? "");
                } while (XmlUserData.Exists(xmlFilename, "PkView", targetUserName));
                targetProjectName = renameRevision.Name;
                project.ProjectName = targetProjectName;

                // also change the project name of individual studies
                project.Studies.ForEach(s => { s.ProfileName = targetProjectName; });
            }

            // Save the project for the target user
            this.CreateOrUpdate(project, targetUserName);

            // Copy output folder
            var sourcePath = string.Format(@"\\{0}\Output Files\PkView\{1}\{2}\{3}",
                iPortalApp.AppServerName, sourceUserName, projectName, submissionId);
            var destPath = string.Format(@"\\{0}\Output Files\PkView\{1}\{2}\{3}",
                iPortalApp.AppServerName, targetUserName, targetProjectName, submissionId);
            if (Directory.Exists(sourcePath))
                DirectoryTools.DirectoryCopy(sourcePath, destPath, true, true);

            // Copy ouptut package if it exists
            FileInfo pkgFile = new FileInfo(sourcePath + ".zip");
            if (pkgFile.Exists)
                pkgFile.CopyTo(destPath + ".zip", true);

            return true;
        }

        /// <summary>
        /// Share a project with the target user
        /// </summary>
        /// <param name="submissionId">Parent submission for the project</param>
        /// <param name="projectName">Project name</param>
        /// <param name="sourceUserName">user the project belongs to</param>
        /// <returns></returns>
        public bool Share(string submissionId, string projectName, string targetUserName, List<string> selectedStudies = null)
        {
            // source username
            var sourceUserName = Users.GetCurrentUserName();

            // Find the source project
            var sourceProject = this.Find(submissionId, projectName, sourceUserName);
            if (sourceProject == null) return false;

            // Leave only selected studies in the source project
            if (selectedStudies != null && selectedStudies.Count != sourceProject.Studies.Count)
            {
                var sourceStudies = from study in sourceProject.Studies 
                                    join studyId in selectedStudies
                                    on study.StudyCode equals studyId
                                    select study;

                sourceProject.Studies = sourceStudies.ToList();
            }

            // Locate matching projects by submission
            var targetProjectNames = this.List(submissionId, targetUserName);
            var targetProjects = targetProjectNames
                .Select(name => this.Find(submissionId, name, targetUserName)).ToList();
            
            // Filter the list leaving only entries with matching creation date and shared by the source user
            var sourceCreation = sourceProject.RevisionHistory.Single(h => h.RevisionId == 1);
            var targetProjectsWithDate = Enumerable.Empty<object>()
                .Select(o => new { p = new Project(), d = new DateTime() }).ToList();
            foreach (var tp in targetProjects)
            {
                // Ensure revision history is sorted
                tp.RevisionHistory.OrderBy(h => h.RevisionId);

                // If creation entry does not match, remove it from the list
                if (tp.RevisionHistory.First().Equals(sourceCreation))
                {
                    // Find the last share or import entry in the history
                    var lastShareOrImport = tp.RevisionHistory
                        .Last(h => h.Action == ActionTypes.Share || h.Action == ActionTypes.Import);

                    // If it is a share by the source user, add the project to the list of target projects with the share date
                    if (lastShareOrImport.Action == ActionTypes.Share && lastShareOrImport.Owner == sourceUserName)
                        targetProjectsWithDate.Add(new { p = tp, d = lastShareOrImport.Date });
                }
            }
            targetProjectsWithDate.OrderByDescending(tpd => tpd.d);

            // If no previously shared projects were found, just copy the project to the target user
            if (targetProjectsWithDate.Count == 0)
                return copyProject(sourceProject, sourceUserName, targetUserName);

            // Find the most recently shared project with compatible settings
            Project targetProject = null;
            List<Tuple<StudySettings, StudySettings>> matchedStudies = null;
            foreach (var tpd in targetProjectsWithDate)
            {
                // Match the studies being shared from the source project to the studies in the target project
                matchedStudies = (from sourceStudy in sourceProject.Studies
                                  join targetStudy in tpd.p.Studies
                                  on sourceStudy.StudyCode equals targetStudy.StudyCode into matched
                                  from match in matched.DefaultIfEmpty()
                                  select new Tuple<StudySettings, StudySettings> (sourceStudy, match )).ToList();

                // Check for study compatibility
                bool compatible = true;
                foreach (var match in matchedStudies)
                {
                    // If study has results in the target, check for settings compatibility
                    if (match.Item2 != null && match.Item2.Pharmacokinetics != null)
                    { 
                        // If revision id of the two studies is identical no additional check is needed
                        if (match.Item1.RevisionId != match.Item2.RevisionId)
                        {
                            compatible = match.Item1.IsCompatible(match.Item2);
                            if (!compatible) break;
                        }
                    }
                }

                // if the project is compatible stop looking
                if (compatible)
                {
                    targetProject = tpd.p;
                    break;
                }
            }
               
            // if no compatible project was found, just create a new copy of the project
            if (targetProject == null)
                return copyProject(sourceProject, sourceUserName, targetUserName);

            // Create shared revision in the target project
            var shareRevisionId = targetProject.RevisionHistory.Max(h => h.RevisionId) + 1;
            var revision = new ProjectRevision
            {
                RevisionId = shareRevisionId,
                Name = projectName,
                Date = DateTime.Now,
                Owner = sourceUserName,
                Action = ActionTypes.Share
            };
            targetProject.RevisionHistory.Add(revision);

            var sourcePath = string.Format(@"\\{0}\Output Files\PkView\{1}\{2}\{3}",
                iPortalApp.AppServerName, sourceUserName, projectName, submissionId);
            var targetPath = string.Format(@"\\{0}\Output Files\PkView\{1}\{2}\{3}",
                iPortalApp.AppServerName, targetUserName, targetProject.ProjectName, submissionId);

            // Copy each study to the target
            foreach (var match in matchedStudies)
            {
                // if matching study exist but has no results
                bool removed = false;
                if (match.Item2 != null && match.Item2.Pharmacokinetics == null)
                {
                    // If revisionId is identical ignore this entry otherwise delete the entry for re-copy
                    if (match.Item1.RevisionId == match.Item2.RevisionId) continue;
                    else
                    {
                        targetProject.Studies.Remove(match.Item2);
                        removed = true;
                    }
                }

                // If target study does not exist or was removed
                if (match.Item2 == null || removed)
                {
                    match.Item1.ProfileName = targetProject.ProjectName;
                    match.Item1.RevisionId = shareRevisionId;
                    targetProject.Studies.Add(match.Item1);

                    // if results exist, copy output files
                    if (match.Item1.Pharmacokinetics != null)
                    {
                        var supplementNumber = match.Item1.SupplementNumber;
                        var studyCode = match.Item1.StudyCode;
                        var sourceStudyPath = Path.Combine(sourcePath, supplementNumber, studyCode);
                        var targetStudyPath = Path.Combine(targetPath, supplementNumber, studyCode);
                     
                        // Copy output files
                        if (Directory.Exists(sourceStudyPath))
                            DirectoryTools.DirectoryCopy(sourceStudyPath, targetStudyPath, true, true);
                    }                    
                }
                else // If the study does exist and has results, copy the missing reports from the source
                {
                    // if the study doesnt have reports, there is nothing else to do for this study
                    if (match.Item1.Reports == null || match.Item1.Reports.Count == 0) continue;

                    // if the target study does not have reports copy everything over
                    if (match.Item2.Reports == null || match.Item2.Reports.Count == 0)
                    {
                        match.Item2.Reports = match.Item1.Reports;
                        continue;
                    }

                    // Copy each report
                    var potentialMatches = match.Item2.Reports.ToDictionary(r => r.Name);
                    foreach (var sharedReport in match.Item1.Reports)
                    {                  
                        // while a report is found but the settings are different, look at the next incremental name
                        String reportBaseName = sharedReport.Name; int i = 1;
                        while (potentialMatches.ContainsKey(sharedReport.Name) &&
                            !sharedReport.Equals(potentialMatches[sharedReport.Name])) 
                        {
                            // assign a report name with an incremental suffix
                            sharedReport.Name = string.Format("{0} ({1})", reportBaseName, i++);                             
                        }
                            
                        // if no report was found with the current name and identical settings, copy the source report
                        if (!potentialMatches.ContainsKey(sharedReport.Name))
                        {
                            match.Item2.Reports.Add(sharedReport);
                            
                            var supplementNumber = match.Item1.SupplementNumber;
                            var studyCode = match.Item1.StudyCode;
                            var sourceReportPath = Path.Combine(sourcePath, supplementNumber, studyCode, reportBaseName);
                            var targetReportPath = Path.Combine(targetPath, supplementNumber, studyCode, sharedReport.Name);

                            // Copy report files
                            if (Directory.Exists(sourceReportPath))
                                DirectoryTools.DirectoryCopy(sourceReportPath, targetReportPath, true, true);                                
                        }                     
                    }
                }  
            }

            // Save the project for the target user
            this.CreateOrUpdate(targetProject, targetUserName);
            return true;
        }

        /// <summary>
        /// Copy the project to the target user and set it as shared by the source user
        /// </summary>
        /// <param name="project"></param>
        /// <param name="sourceUserName"></param>
        /// <param name="targetUserName"></param>
        /// <returns></returns>
        private bool copyProject(Project project, string sourceUserName, string targetUserName) 
        {
            string sourceProjectName = project.ProjectName;
            string submissionId = project.SubmissionId;

            // Create share revision
            var revision = new ProjectRevision
            {
                RevisionId = project.RevisionHistory.Last().RevisionId + 1,
                Name = sourceProjectName,
                Date = DateTime.Now,
                Owner = sourceUserName,
                Action = ActionTypes.Share
            };
            project.RevisionHistory.Add(revision);

            // Fix name collisions
            var targetProjectName = sourceProjectName;
            string xmlFilename = String.Format("{0}_{1}", submissionId, sourceProjectName ?? "");
            if (XmlUserData.Exists(xmlFilename, "PkView", targetUserName))
            {
                // Add a project rename entry by the destination user
                var renameRevision = new ProjectRevision
                {
                    RevisionId = project.RevisionHistory.Last().RevisionId + 1,
                    Date = DateTime.Now,
                    Owner = targetUserName,
                    Action = ActionTypes.Rename
                };
                project.RevisionHistory.Add(renameRevision);

                // Add an incremental numeric suffix while a collision is found
                int i = 1;
                do
                {
                    renameRevision.Name = string.Format("{0} ({1})", sourceProjectName, i++);
                    xmlFilename = String.Format("{0}_{1}", submissionId, renameRevision.Name ?? "");
                } while (XmlUserData.Exists(xmlFilename, "PkView", targetUserName));
                targetProjectName = renameRevision.Name;
                project.ProjectName = targetProjectName;

                // also change the project name of individual studies
                project.Studies.ForEach(s => { s.ProfileName = targetProjectName; });
            }           

            // Save the project for the target user
            this.CreateOrUpdate(project, targetUserName);

            // Output paths
            var sourcePath = string.Format(@"\\{0}\Output Files\PkView\{1}\{2}\{3}",
                iPortalApp.AppServerName, sourceUserName, sourceProjectName, submissionId);
            var targetPath = string.Format(@"\\{0}\Output Files\PkView\{1}\{2}\{3}",
                iPortalApp.AppServerName, targetUserName, targetProjectName, submissionId);

            // Copy each study 
            foreach (var study in project.Studies)
            {
                var sourceStudyPath = Path.Combine(sourcePath, study.SupplementNumber, study.StudyCode);
                var targetStudyPath = Path.Combine(targetPath, study.SupplementNumber, study.StudyCode);

                if (Directory.Exists(sourceStudyPath))
                    DirectoryTools.DirectoryCopy(sourceStudyPath, targetStudyPath, true, true);
            }

            return true;

        }
    }
}