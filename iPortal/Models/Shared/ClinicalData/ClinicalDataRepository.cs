using System;
using System.Collections.Generic;
using System.Data;
using System.IO;
using System.Linq;
using System.Web;
using iPortal.Config;
using SasJobs.ClientLibrary;
using SasJobs.Messages;
using iPortal.Models.Shared.ClinicalData;

namespace iPortal.Models.PkView
{
    /// <summary>
    /// Implements a resource to retrieve application data
    /// </summary>
    public class ClinicalDataRepository
    {
        /// <summary>
        /// Get the list of studies in an drug or biological product application 
        /// </summary>
        /// <param name="applicationId"></param>
        /// <returns></returns>
        public List<Study> GetStudies(string applicationId)
        {
            var studies = new List<Study>();

            var rootDir = new System.IO.DirectoryInfo(PkViewConfig.NdaRootFolder + applicationId);

            // For each supplement folder
            foreach (var serialNumberDir in rootDir.GetDirectories())
            {
                var dataDir = findDatasetsDir(serialNumberDir);

                // For each study folder in the datasets folder
                if (dataDir != null)
                {
                    foreach (var studyDir in dataDir.GetDirectories())
                    {
                        // VALIDATION SHOULD HAPPEN HERE

                        var study = new Study
                        {
                            SubmissionId = applicationId.ToUpperInvariant(),
                            StudyId = studyDir.Name.ToUpperInvariant(),
                            SerialNumber = serialNumberDir.Name.ToUpperInvariant()
                        };

                        studies.Add(study);
                    }
                }
            }

            // Sort
            if (studies.Any()) studies = studies.OrderBy(s => s.SerialNumber + s.StudyId).ToList();

            return studies;
        }

        /// <summary>
        /// Get the list of studies in an drug or biological product application 
        /// </summary>
        /// <param name="applicationId"></param>
        /// <returns></returns>
        public List<string> GetSerialNumbers(string applicationId)
        {
            var supplements = new List<string>();

            var rootDir = new System.IO.DirectoryInfo(PkViewConfig.NdaRootFolder + applicationId);

            // For each supplement folder
            foreach (var serialNumberDir in rootDir.GetDirectories())
            {
                supplements.Add(serialNumberDir.Name);
            }

            return supplements;
        }

        /// <summary>
        /// Find the datasets directory recursively, but fully explore each level before going deeper into the tree (faster)
        /// </summary>
        /// <param name="root"></param>
        /// <returns></returns>
        private DirectoryInfo findDatasetsDir(DirectoryInfo root)
        {
            var subdirectories = root.GetDirectories();
            foreach (var dir in subdirectories)
            {
                if (dir.Name.Equals("datasets", StringComparison.CurrentCultureIgnoreCase))
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
    }
}