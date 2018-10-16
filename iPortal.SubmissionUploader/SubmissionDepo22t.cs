using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace iPortal.SubmissionUploader
{
    class SubmissionDepot: ISubmissionDepot
    {
        /// <summary>
        /// List of domain files (other than DM) that pkview will process if they are available
        /// </summary>
        private static string[] domainsOfInterest = { "SDTM\\PP.XPT", "SDTM\\PC.XPT", "SDTM\\EX.XPT", "SDTM\\SUPPDM.XPT", "SDTM\\SC.XPT", "SDTM\\LB.XPT", "SDTM\\LB1.XPT", "SDTM\\LB2.XPT", "SDTM\\LB3.XPT", "SDTM\\AE.XPT", "SDTM\\EG.XPT" };
        
        /// <summary>
        /// Root of the directory where submission files are stored
        /// </summary>
        private DirectoryInfo submissionDirectory = null;

        /// <summary>
        /// Cached list of serial folders in the submission
        /// </summary>
        private IEnumerable<DirectoryInfo> serialFolders = null;

        /// <summary>
        /// Class constructor
        /// </summary>
        /// <param name="rootDirectory">Root of the directory where submission files are stored</param>
        public SubmissionDepot(DirectoryInfo rootDirectory)
        {
            this.submissionDirectory = rootDirectory;
            this.OnlySerialFoldersWithData = true;
        }

        /// <summary>
        /// Crawl serial folders to extract the ones with useful data files
        /// </summary>
        public bool OnlySerialFoldersWithData { get; set; } 

        /// <summary>
        /// List of serial number folders in this submission folder.
        /// This will only contain a list after executing FetchSerialFolders
        /// </summary>
        public IEnumerable<DirectoryInfo> SerialFolders {
            get { return this.serialFolders; }
        }

        /// <summary>
        /// Submision folder's physical directory reference
        /// </summary>
        public DirectoryInfo Directory { 
            get { return submissionDirectory; } 
        }

        /// <summary>
        /// Fetch the list of serial folders from the directory
        /// </summary>
        /// <param name="progressIndicator">Used to notify folder fetch progress</param>
        public async Task<IEnumerable<DirectoryInfo>> FetchSerialFoldersAsync(IProgress<Feedback> progressIndicator, CancellationToken ct)
        {
                return await Task.Run(() => {
                    if (this.serialFolders == null)
                        this.serialFolders = this.findSerialFolders(progressIndicator, ct);
                    return this.serialFolders;
                }, ct);                
        }

        /// <summary>
        /// Fetch the list of data files in a particular serial folder of the submission
        /// </summary>
        /// <param name="serialFolder">Serial number folder in which to search for data files</param>
        /// <param name="progressIndicator">Used to notify folder fetch progress</param>
        /// <param name="ct">Used to cancel the process</param>
        public async Task<IEnumerable<IEnumerable<FileInfo>>> FetchDataFilesAsync(DirectoryInfo serialFolder, IProgress<Feedback> progressIndicator, CancellationToken ct)
        {
            return await Task.Run(() =>
            {
                var dataFiles = new List<IEnumerable<FileInfo>>();

                // If ANDA return all files
                if (this.submissionDirectory.Name.StartsWith("ANDA"))
                {
                    var datasetsFolder = new DirectoryInfo(Path.Combine(serialFolder.FullName, "m5"));
                    if (datasetsFolder.Exists)
                    {
                        dataFiles.AddRange(datasetsFolder.GetFiles("*.xpt", SearchOption.AllDirectories)
                            .Select(f => new List<FileInfo> { f }));
                    }                    
                }
                else // For other types of submission locate the DM file and the related files of interest
                {
                    var dataFolders = findStudyDataFolders(serialFolder, progressIndicator, ct);
                    foreach (DirectoryInfo dataFolder in dataFolders)
                    {
                        // if folder was selected it means at least dm domain is present
                        var filesInDataFolder = new List<FileInfo> { new FileInfo(dataFolder.FullName + "\\SDTM\\DM.XPT") };

                       
                        // Add other domains found
                        filesInDataFolder.AddRange(findDatasetsOfInterest(dataFolder));

                        dataFiles.Add(filesInDataFolder);
                    }
                }                
                return dataFiles;
            }, ct);
        }

        /// <summary>
        /// Run a separate thread to fetch the serial fonders that contain data
        /// </summary>
        private IEnumerable<DirectoryInfo> findSerialFolders(IProgress<Feedback> progressIndicator, CancellationToken ct)
        {
            ct.ThrowIfCancellationRequested();

            var serialFolders = submissionDirectory.EnumerateDirectories();
            if (OnlySerialFoldersWithData)
            {
                var serialFoldersWithData = new List<DirectoryInfo>();

                // Report progress
                int total = serialFolders.Count(), i = 0;
                foreach (var serialFolder in serialFolders)
                {
                    progressIndicator.Report(new Feedback
                    {
                        Message = String.Format("Examining serial folder {0}/{1}", i+1, total),
                        Value = 90 / total * i++
                    });
                    ct.ThrowIfCancellationRequested();

                    // If we are processing an ANDA we will copy all the xpt data
                    // this is done because legacy files are commonly used in ANDAs and
                    // filtering at this point may result in missing files
                    var dataFolder = new DirectoryInfo(serialFolder.FullName + "\\m5");
                    if (this.submissionDirectory.Name.StartsWith("ANDA"))
                    {
                        if (serialFolder.EnumerateFiles("*.xpt", SearchOption.AllDirectories).Any())
                            serialFoldersWithData.Add(serialFolder);
                    }
                    else
                    {
                        // Check for m5 folder and at least a dm.xpt file                    
                        if (dataFolder.Exists)
                        {
                            if (findDemographicDomain(dataFolder, ct) != null)
                                serialFoldersWithData.Add(serialFolder);
                        }
                    }
                }
                serialFolders = serialFoldersWithData;
            }
            return serialFolders;              
        }

        /// <summary>
        /// Find the folders that contain data inside this serial number folder
        /// </summary>
        /// <param name="serialFolder">THe serial number folder</param>
        /// <param name="progressIndicator">Used to report back progress</param>
        /// <param name="ct">Used to cancel</param>
        /// <returns>A list of folders with clinical data</returns>
        private IEnumerable<DirectoryInfo> findStudyDataFolders(DirectoryInfo serialFolder, IProgress<Feedback> progressIndicator, CancellationToken ct)
        {
            ct.ThrowIfCancellationRequested();

            var studyFolders = new DirectoryInfo(serialFolder.FullName + "\\m5\\datasets").EnumerateDirectories();
            var studyDataFolders = new List<DirectoryInfo>();
            
            // Determine for each study folder if at least one dm file exists
            int total = studyFolders.Count(), i = 0;
            foreach (var studyFolder in studyFolders)
            {
                progressIndicator.Report(new Feedback
                {
                    Message = String.Format("Examining study folder {0}/{1}", i + 1, total),
                    Value = 90 / total * i++
                });
                ct.ThrowIfCancellationRequested();

                // Find a folder that contains dm data
                var dataFolder = findDemographicDomain(studyFolder, ct);
                    

                if (dataFolder != null)
                    studyDataFolders.Add(dataFolder);
                else 
                {
                    System.Windows.MessageBox.Show(String.Format("the study ({0})" + "is not exist SDTM folder, please contact our team at CDER-OCPKM@fda.hhs.gov.", studyFolder));
                    //System.Windows.MessageBox.Show("is not exist SDTM folder, please contact our team at CDER-OCPKM@fda.hhs.gov.");

                }    
            }
            return studyDataFolders;
        }

        /// <summary>
        /// Search this folder or a subfolder for the demographic domain and return the resulting folder
        /// </summary>
        /// <returns>The folder that contains the demographic domain</returns>
        private DirectoryInfo findDemographicDomain(DirectoryInfo folder, CancellationToken ct)
        {
            return findDemographicDomain(new List<DirectoryInfo> { folder }, ct);
        }

        /// <summary>
        /// Search this folders or a subfolder for the demographic domain and return the resulting folder
        /// </summary>
        /// <returns>The folder that contains the demographic domain</returns>
        private DirectoryInfo findDemographicDomain(IEnumerable<DirectoryInfo> folders, CancellationToken ct)
        {
            // Search in every folder
            foreach (var folder in folders)
            {
                ct.ThrowIfCancellationRequested();
                if (File.Exists(folder.FullName + "\\SDTM\\DM.XPT"))
                    return folder;
            }

            //Search in subfolders
            var subFolders = new List<DirectoryInfo>();
            foreach (var folder in folders)
            {
                ct.ThrowIfCancellationRequested();
                subFolders.AddRange(folder.EnumerateDirectories());
            }
            if (subFolders.Any())
                return findDemographicDomain(subFolders, ct);

            return null;
        }

        /// <summary>
        /// Look for each dataset of interest in the folder
        /// </summary>
        /// <param name="folder">folder in which datasets are being sarched for</param>
        /// <returns>the list of datasets of interest that exist in the folder</returns>
        private IEnumerable<FileInfo> findDatasetsOfInterest(DirectoryInfo folder)
        {
            var dataFiles = new List<FileInfo>();
            foreach (string domainFilename in domainsOfInterest)
            {
                var dataFile = new FileInfo(folder.FullName + "\\" + domainFilename);
                if (dataFile.Exists)
                    dataFiles.Add(dataFile); 
            }

            return dataFiles;
        }
    }
}
