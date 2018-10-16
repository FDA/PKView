using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;

namespace iPortal.SubmissionUploader
{
    /// <summary>
    /// Implements a submission uploader
    /// </summary>
    class SubmissionUploader: ISubmissionUploader
    {
        #region Private Fields
        private string uploadRoot = "\\\\" + App.AppServerName + "\\clinical";

        private string selectedRepository = null;
        private string customRepositoryUri = null;
        private string selectedSubmission = null;
        private string selectedSerial = null;
        private IDictionary<String, String> repositories = null;
        private IDictionary<String, SubmissionDepot> submissions = null;
        private IDictionary<String, DirectoryInfo> serials = null;
        #endregion Private Fields

        /// <summary>
        /// Class constructor
        /// </summary>
        public SubmissionUploader()
        {
            repositories = new Dictionary<String, String>();
            repositories.Add("Custom", "");
            repositories.Add("EDR", @"\\cdsesub1\evsprod\");           
        }

        #region Public Properties
        /// <summary> Currently selected submission repository</summary>
        public string SelectedRepository
        {
            get { return selectedRepository; }
            set
            {
                if (Equals(value, selectedRepository)) return;
                selectedRepository = value;
                retrieveRepositorySubmissions();
            }
        }

        /// <summary> Repository Uri to be used when <see cref="SelectedRepository">SelectedRepository</see> is set to 'Custom'</summary>
        public string CustomRepositoryUri
        {
            get { return customRepositoryUri; }
            set
            {
                if (Equals(value, customRepositoryUri)) return;
                customRepositoryUri = value;
                retrieveRepositorySubmissions();
            }
        }

        /// <summary> Selected submission to be uploaded</summary>
        public string SelectedSubmissionFolder
        {
            get { return selectedSubmission; }
            set
            {
                if (Equals(value, selectedSubmission)) return;

                // Update the selection with the new value
                selectedSubmission = value;
                if (selectedSubmission == null) return;
            }
        }

        /// <summary> Submission upload mode</summary>
        public UploadModes UploadMode { get; set; }

        /// <summary> Selected serial number to be uploaded</summary>
        public string SelectedSerialFolder
        {
            get { return selectedSerial; }
            set
            {
                if (Equals(value, selectedSerial)) return;
                selectedSerial = value;
            }
        }
        #endregion Public Properties

        #region Private Properties
        /// <summary>
        /// Get the currently selected submission depot
        /// </summary>
        private SubmissionDepot currentSubmission 
        { 
            get { return submissions[selectedSubmission]; } 
        }

        /// <summary>
        /// Path where the submission will be uploaded in the iPortal repository
        /// </summary>
        private String currentSubmissionDestinationPath 
        {
            get { return Path.Combine(uploadRoot, currentSubmission.Directory.Name); } 
            
        }

        /// <summary>
        /// List of data files that will be uploaded grouped by destination folder
        /// </summary>
        private List<IEnumerable<FileInfo>> selectedDataFiles { get; set; }

        #endregion Private Properties

        #region Public Methods
        /// <summary>
        /// Retrieve the list of available submission repositories
        /// </summary>
        /// <returns>A string list of repository names</returns>
        public IEnumerable<string> GetRepositories()
        {
            return repositories.Keys;
        }

        /// <summary>
        /// Retrieve the list of available submission folders in the repository
        /// </summary>
        /// <returns>A string list of submission folder names</returns>
        public IEnumerable<string> GetSubmissionFolders()
        {
            return submissions != null ? submissions.Keys : null;
        }
        

        /// <summary>
        /// Retrieve the list of available serial folders in the submission
        /// </summary>
        /// <returns>A string list of serial folder names</returns>
        public async Task<IEnumerable<string>> GetSerialFoldersAsync(IProgress<Feedback> progressIndicator, CancellationToken ct)
        {
            var task = submissions[selectedSubmission].FetchSerialFoldersAsync(progressIndicator, ct);
            try
            {
                var folders = await task;
                if (folders == null || task.IsCanceled)
                {
                    this.serials = null;
                    throw new OperationCanceledException();
                }
                this.serials = folders.ToDictionary(d => d.Name);
                return serials.Keys;
            }
            catch (OperationCanceledException) {
                this.serials = null;
                throw; 
            }             
        }

        /// <summary>
        /// Verify the list of serial folders to be uploaded by checking if a folder of the same name already exists in the iPortal repository
        /// </summary>
        /// <param name="progressIndicator">Used to report back progress</param>
        /// <param name="ct">Used to cancel the upload</param>
        /// <returns>The list of serial folders that will not be uploaded</returns>
        public async Task<IEnumerable<String>> VerifySerialFoldersAsync(IProgress<Feedback> progressIndicator, CancellationToken ct)
        {
            IEnumerable<DirectoryInfo> selectedSerials;

            // Upload a single serial folder
            if (UploadMode.Equals(UploadModes.SingleSerial))
                selectedSerials = new List<DirectoryInfo> { serials[selectedSerial] };
            else selectedSerials = serials.Values;

            // Progress indicator used to recompute percentage
            int total = selectedSerials.Count(), i = 0;
            IProgress<Feedback> singleSerialDataFetchProgress = new Progress<Feedback>((feedback) =>
            {
                progressIndicator.Report(new Feedback
                {
                    Message = feedback.Message,
                    Value = 95 / total * (i * 100 + feedback.Value) / 100
                });
            });

            // Get the list of data files to upload in the serial folders
            selectedDataFiles = new List<IEnumerable<FileInfo>>();
            var ignoredSerialFolders = new List<String>();
            foreach (DirectoryInfo serialFolder in selectedSerials)
            {
                // If serial folder does not exist in the server fetch the list of data files to upload
                if (!Directory.Exists(Path.Combine(currentSubmissionDestinationPath, serialFolder.Name)))
                {
                    try
                    {
                        selectedDataFiles.AddRange(await currentSubmission.FetchDataFilesAsync(serialFolder, singleSerialDataFetchProgress, ct));
                        i++;
                    }
                    catch (OperationCanceledException) { throw; }
                }
                // If the serial folder already exists, add it to the list of ignored folders
                else ignoredSerialFolders.Add(serialFolder.Name);
            }

            return ignoredSerialFolders;
        }

        /// <summary>
        /// Upload the submission
        /// </summary>
        /// <param name="progressIndicator">Used to report back progress</param>
        /// <param name="ct">Used to cancel the upload</param>
        /// <returns>the task object representing the asynchronous operation</returns>
        public async Task UploadAsync(IProgress<Feedback> progressIndicator, CancellationToken ct)
        {
            await Task.Run(() =>
            {
                // Generate a temporary directory name so we can rollback 
                var tempSubmissionPath = String.Format("{0}.tmp.{1}",
                    currentSubmissionDestinationPath, new Random().Next(100000));

                // Loop over each dataset list belonging to a data folder 
                var sw = Stopwatch.StartNew();
                Timer updateTimeDisplayTimer = null;
                long timePerFile = new TimeSpan(0, 1, 0).Ticks;
                int total = selectedDataFiles.Aggregate(0, (c, f) => c + f.Count()), i = 0;
                TimeSpan estimate = new TimeSpan(0, total, 0);
                try
                {
                    foreach (IEnumerable<FileInfo> dataFilesInFolder in selectedDataFiles)
                    {
                        // Generate the destination folder path
                        string sourceFolder = dataFilesInFolder.First().Directory.FullName;
                        string subPath = sourceFolder.Substring(currentSubmission.Directory.FullName.Length + 1);
                        string destFolder = Path.Combine(tempSubmissionPath, subPath);

                        // Create the destination folder if it does not exist
                        if (!Directory.Exists(destFolder))
                            Directory.CreateDirectory(destFolder);

                        // Copy each data file
                        foreach (FileInfo dataFile in dataFilesInFolder)
                        {
                            ct.ThrowIfCancellationRequested();

                            // Cancel any previous timer
                            if (updateTimeDisplayTimer != null)
                                updateTimeDisplayTimer.Change(Timeout.Infinite, Timeout.Infinite);

                            // Set a timer to update progress estimates while the system is copying
                            var estimateOffset = timePerFile;
                            updateTimeDisplayTimer = new Timer((state) =>
                            {
                                estimateOffset -= estimateOffset / 2;
                                var tempEstimate = estimate.Subtract(new TimeSpan(estimateOffset));
                                progressIndicator.Report(new Feedback
                                {
                                    Message = String.Format("Copying data file {0}\\{1} {2}/{3}" + Environment.NewLine + "({4} remaining)",
                                        subPath, dataFile.Name.ToLower(), i + 1, total, tempEstimate.ToString(@"hh\:mm\:ss")),
                                    Value = 95 / total * i
                                });
                            }, null, new TimeSpan(0, 0, 0), new TimeSpan(0, 0, 10));

                            dataFile.CopyTo(Path.Combine(destFolder, dataFile.Name.ToLower()), overwrite: true);

                            // Estimate time remaining
                            timePerFile = sw.ElapsedTicks / ++i;
                            estimate = new TimeSpan(timePerFile * (total - i));
                        }
                    }
                }
                catch (Exception)
                {
                    // Cancel progress update timer
                    if (updateTimeDisplayTimer != null)
                        updateTimeDisplayTimer.Change(Timeout.Infinite, Timeout.Infinite);

                    // Report cancelation
                    progressIndicator.Report(new Feedback
                    {
                        Message = "Cleaning up...",
                        Value = 80
                    });

                    // Delete the temporary folde if operation is canceled
                    if (Directory.Exists(tempSubmissionPath))
                        Directory.Delete(tempSubmissionPath, true);
                    throw;
                }

                // If the nda folder does not exist, create it
                if (!Directory.Exists(currentSubmissionDestinationPath))
                    Directory.CreateDirectory(currentSubmissionDestinationPath);

                // Copy everything from the temporary upload directory to the submission directory
                DirectoryInfo tempSubmissionDirectory = new DirectoryInfo(tempSubmissionPath);
                foreach (var serialFolder in tempSubmissionDirectory.EnumerateDirectories())
                    serialFolder.MoveTo(Path.Combine(currentSubmissionDestinationPath, serialFolder.Name));

                // Delete the temporary directory
                tempSubmissionDirectory.Delete();
            });
        }
        #endregion Public Methods

        #region Private Methods
        /// <summary>
        /// Retrieve the list of submissions in the selected repository
        /// </summary>
        private void retrieveRepositorySubmissions()
        {
            string repositoryUri;
            if (selectedRepository != "Custom")
            {
                if (repositories.ContainsKey(selectedRepository))
                    repositoryUri = repositories[selectedRepository];
                else
                {
                    submissions = null;
                    return;
                }
            }
            else repositoryUri = customRepositoryUri;

            // Return if empty
            if (String.IsNullOrWhiteSpace(repositoryUri))
            {
                submissions = null;
                return;
            }
 
            // If the directory exists and can be accessed
            try 
            { 
                var repositoryDirectory = new DirectoryInfo(repositoryUri);
                if (!repositoryDirectory.Exists)
                {
                    submissions = null;
                    return;
                }

                // Obtain the list of submission folders and take only the ones that start with a known submission prefix
                var submissionDirectories = repositoryDirectory.EnumerateDirectories()
                    .Where(d => {
                        var dirName = d.Name;
                        if (dirName.StartsWith("ANDA", StringComparison.InvariantCultureIgnoreCase)) return true;
                        if (dirName.StartsWith("BLA", StringComparison.InvariantCultureIgnoreCase)) return true;
                        if (dirName.StartsWith("NDA", StringComparison.InvariantCultureIgnoreCase)) return true;
                        if (dirName.StartsWith("EUA", StringComparison.InvariantCultureIgnoreCase)) return true;
                        if (dirName.StartsWith("IND", StringComparison.InvariantCultureIgnoreCase)) return true;
                        if (dirName.StartsWith("MF", StringComparison.InvariantCultureIgnoreCase)) return true;
                        if (dirName.StartsWith("SAFETY", StringComparison.InvariantCultureIgnoreCase)) return true;
                        return false;
                    })
                    .ToList();
                
                submissions = submissionDirectories
                    .Select(d => new SubmissionDepot(d))
                    .ToDictionary(d => d.Directory.Name.ToUpper());   
            }
            catch (Exception) 
            {
                MessageBox.Show("The repository path is incorrect or cannot be accessed.");
                submissions = null;
                return;
            }
        }
        #endregion Private Methods
    }
}
