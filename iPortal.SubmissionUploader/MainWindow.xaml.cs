using Microsoft.Win32;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.IO;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Navigation;
using System.Windows.Shapes;

namespace iPortal.SubmissionUploader
{
    /// <summary>
    /// Interaction logic for MainWindow.xaml
    /// </summary>
    public partial class MainWindow : Window, ISubmissionUploaderWindow
    {        
        /// <summary>
        /// The uploader object that will be used
        /// </summary>
        private SubmissionUploader uploader = null;
        private CancellationTokenSource cancelSerialFetch;
        private CancellationTokenSource cancelUpload;

        /// <summary>
        /// List of submision repositories
        /// </summary>
        public IEnumerable<string> RepositoryList
        {
            get { return uploader.GetRepositories(); }
        }

        /// <summary>
        /// Currently selected submission repository
        /// </summary>
        public string SelectedRepository
        {
            get { return uploader.SelectedRepository; }
            set 
            { 
                uploader.SelectedRepository = value;
                updateSubmissionList();
                OnPropertyChanged("SelectedRepository");
            }
        }

        /// <summary>
        /// Path to a custom submission repository
        /// </summary>
        public string CustomRepositoryUri
        {
            get { return uploader.CustomRepositoryUri; }
            set
            {
                uploader.CustomRepositoryUri = value.Trim();
                updateSubmissionList();
            }
        }

        /// <summary> True when the UI is loading the list of submissions</summary>
        public Boolean LoadingSubmissionFolderList {
            get { return loadingSubmissionFolderList; }
            set { 
                loadingSubmissionFolderList = value;
                OnPropertyChanged("LoadingSubmissionFolderList");
            } 
        }
        private bool loadingSubmissionFolderList = false;

        /// <summary>
        /// List of submission folders in the repository
        /// </summary>
        public IEnumerable<string> SubmissionFolderList {
            get { return submissionFolderList; }
            set { 
                submissionFolderList = value;
                OnPropertyChanged("SubmissionFolderList");
            }
        }
        private IEnumerable<string> submissionFolderList = null;

        /// <summary> 
        /// Currently selected submission folder 
        /// </summary>
        public string SelectedSubmissionFolder
        {
            get { return uploader.SelectedSubmissionFolder; }
            set
            {
                uploader.SelectedSubmissionFolder = value;
                if (value == null) return;                
                updateSerialFolderList();
                OnPropertyChanged("SelectedSubmissionFolder");
            }
        }

        /// <summary> 
        /// Determines wether a single serial folder or all of them will be uploaded
        /// </summary>
        public bool UploadSingleSerialFolder
        {
            get {  return uploader.UploadMode == UploadModes.SingleSerial; }
            set { 
                uploader.UploadMode = value ? UploadModes.SingleSerial : UploadModes.All;
                OnPropertyChanged("UploadSingleSerialFolder");
            }
        }

        /// <summary> True when the UI is loading the list of serials </summary>
        public Boolean LoadingSerialFolderList {
            get { return loadingSerialFolderList; }
            set {
                loadingSerialFolderList = value;

                // If loading hide the serial folder dropdown
                if (loadingSerialFolderList == false)
                { 
                    ShowSerialFolderList = (SerialFolderList != null && SerialFolderList.Any());
                    if (SelectedSerialFolder == null) ShowSerialFoldersNotFound = true;
                }
                else {
                    ShowSerialFolderList = false;
                    ShowSerialFoldersNotFound = false;
                }

                // Show/hide the progress bar
                ShowProgressBar = value;

                OnPropertyChanged("LoadingSerialFolderList");
            }
        }
        private bool loadingSerialFolderList = false;

        /// <summary> True when the serial folder list should be shown </summary>
        public Boolean ShowSerialFolderList {
            get { return showSerialFolderList; }
            set {
                showSerialFolderList = value;
                OnPropertyChanged("ShowSerialFolderList");
            }
        }
        private bool showSerialFolderList = false;

        /// <summary> True when the loaded submission does not contain data </summary>
        public Boolean ShowSerialFoldersNotFound
        {
            get { return showSerialFoldersNotFound; }
            set
            {
                showSerialFoldersNotFound = value;
                OnPropertyChanged("ShowSerialFoldersNotFound");
            }
        }
        private bool showSerialFoldersNotFound = false;

        /// <summary> 
        /// List of serial number folders in the submission
        /// </summary>
        public IEnumerable<string> SerialFolderList {
            get { return serialFolderList; }
            set {
                serialFolderList = value;
                OnPropertyChanged("SerialFolderList");
            }
        }
        private IEnumerable<string> serialFolderList = null;

        /// <summary> Currently selected serial folder</summary>
        public string SelectedSerialFolder
        {
            get { return uploader.SelectedSerialFolder; }
            set
            {
                uploader.SelectedSerialFolder = value;
                OnPropertyChanged("SelectedSerialFolder");
            }
        }

        /// <summary> True when the UI is uploading the submission </summary>
        public Boolean Uploading
        {
            get { return uploading; }
            set
            {
                uploading = value;

                // Show/hide the progress bar
                ShowProgressBar = value;

                OnPropertyChanged("Uploading");
                OnPropertyChanged("NotUploading");
            }
        }
        private bool uploading = false;

        /// <summary>
        /// Returns true when the UI is not uploading, used to enable/disable the UI
        /// </summary>
        public Boolean NotUploading { get { return !uploading; } }

        /// <summary>
        /// True when progressbar should be shown in the UI
        /// </summary>
        public bool ShowProgressBar 
        {
            get { return showProgressBar; }
            set {
                if (Equals(showProgressBar, value)) return;
                showProgressBar = value;
                OnPropertyChanged("ShowProgressBar");
            }
        }
        private bool showProgressBar = false;

        /// <summary>
        /// Progressbar value for the UI
        /// </summary>
        public Feedback TaskProgress { get; set; }

        /// <summary>
        /// Event handler used to notify when a window property has changed and update UI
        /// </summary>
        public event PropertyChangedEventHandler PropertyChanged;

        /// <summary>
        /// Main window constructor
        /// </summary>
        public MainWindow()
        {
            uploader = new SubmissionUploader();

            InitializeComponent();
            DataContext = this;
            SubmissionsList.DataContext = this;
        }

        /// <summary>
        /// Trigger a propertyChanged event to update the UI
        /// </summary>
        /// <param name="propertyName">Property that changed</param>
        protected virtual void OnPropertyChanged([CallerMemberName] string propertyName = null)
        {
            if (PropertyChanged != null)
                PropertyChanged(this, new PropertyChangedEventArgs(propertyName));
        }

        /// <summary>
        /// Update submission folder list from the updater, select first submission and trigger UI update
        /// </summary>
        private void updateSubmissionList()
        {
            ShowSerialFolderList = false;
            ShowSerialFoldersNotFound = false;
            SubmissionFolderList = uploader.GetSubmissionFolders();            
            if (SubmissionFolderList == null || !SubmissionFolderList.Any())
                SelectedSubmissionFolder = null;
            else SelectedSubmissionFolder = SubmissionFolderList.First();            
        }

        /// <summary>
        /// Update serial folder list from the updater, select first serial and trigger UI update
        /// </summary>
        private void updateSerialFolderList()
        {
            LoadingSerialFolderList = true;

            IProgress<Feedback> progressIndicator = new Progress<Feedback>(updateProgress);
            if (cancelSerialFetch != null) cancelSerialFetch.Cancel();
            cancelSerialFetch = new CancellationTokenSource();
            Task.Run(() =>
            {
                var task = uploader.GetSerialFoldersAsync(progressIndicator, cancelSerialFetch.Token);
                try
                {                    
                    task.Wait();
                    SelectedSerialFolder = null;
                    UploadSingleSerialFolder = false;
                    SerialFolderList = task.Result;
                    if (serialFolderList != null && serialFolderList.Any())
                        SelectedSerialFolder = serialFolderList.First(); 
                    LoadingSerialFolderList = false; 
                }
                catch (AggregateException) { 
                    /* Dont do anything when operation was cancelled */
                    if (!task.IsCanceled) throw;
                }                
            });
        }

        /// <summary>
        /// Trigger a progress update event
        /// </summary>
        /// <param name="value">progress percentage</param>
        private void updateProgress(Feedback progress)
        {
            TaskProgress = progress;
            OnPropertyChanged("TaskProgress");
        }

        /// <summary>
        /// Browse for a submission repository
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void BrowseRepositories_Click(object sender, RoutedEventArgs e)
        {

        }

        /// <summary>
        /// Upload the selected serial folders in the currently selected submission to our server
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void Upload_Click(object sender, RoutedEventArgs e)
        {
            Uploading = true;

            // Progress indicator for verification with a delegate that scales progress feedback to 20% of overall process
            IProgress<Feedback> verificationProgressIndicator = new Progress<Feedback>(
                (p) => updateProgress(new Feedback { Message = p.Message, Value = p.Value * 20 / 100 }));

            // Progress indicator for upload with a delegate that scales progress feedback to the next 75%  of overall process
            IProgress<Feedback> uploadProgressIndicator = new Progress<Feedback>(
                (p) => updateProgress(new Feedback { Message = p.Message, Value = 20 + (p.Value * 75 / 100) }));

            // Cancellation token
            cancelUpload = new CancellationTokenSource();

            // Run the verification of the serials to upload
            Task.Run(() =>
            {
                Task<IEnumerable<String>> verificationTask = uploader.VerifySerialFoldersAsync(verificationProgressIndicator, cancelUpload.Token);
                Task uploadTask = null;
                try
                {
                    // Get the list of serial folders that will not be uploaded
                    var ignoredSerialFolders = verificationTask.Result;

                    // If the number of folders to ignore equals the number of folders to upload, cancel the whole process and notify the user
                    if ((uploader.UploadMode.Equals(UploadModes.SingleSerial) && ignoredSerialFolders.Any()) ||
                        (uploader.UploadMode.Equals(UploadModes.All) && ignoredSerialFolders.Count().Equals(serialFolderList.Count())))
                    {
                        System.Windows.MessageBox.Show("The selected serial folders already exist in iPortal. The upload will not be performed." +
                            " If you believe an update of these files is necessary, please contact our team at CDER-OCPKM@fda.hhs.gov.");
                        Uploading = false;
                        return;
                    }

                    // If we upload some folders and ignore others, warn the user and let him choose if he wants to proceed
                    if (ignoredSerialFolders.Any())
                    {
                        var response = System.Windows.MessageBox.Show(String.Format("Some of the serial folders ({0}) " +
                            "already exist in iPortal and will not be uploaded. If you believe an update of these files is necessary," +
                            " please contact our team at CDER-OCPKM@fda.hhs.gov. Do you want to continue uploading the remaining " + 
                            "serial folders?", ignoredSerialFolders.Aggregate((l,i) => l + ", " + i)), "iPortal Uploader", MessageBoxButton.YesNo);
                        if (response == MessageBoxResult.No)
                        {
                            Uploading = false;
                            return;
                        }
                    }

                    // Proceed with the upload
                    uploadTask = uploader.UploadAsync(uploadProgressIndicator, cancelUpload.Token);
                    uploadTask.Wait();

                    Uploading = false;
                    System.Windows.MessageBox.Show(String.Format("Submission {0} was correctly uploaded into iPortal.",
                        SelectedSubmissionFolder));
                }
                catch (AggregateException)
                {
                    Uploading = false;
                    if (!verificationTask.IsCanceled && (uploadTask == null || !uploadTask.IsCanceled)) throw;
                }
            });
        }

        /// <summary>
        /// Cancel the submission upload process
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void Cancel_Click(object sender, RoutedEventArgs e)
        {
            cancelUpload.Cancel();
        }

        /// <summary>
        /// Window close event
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void Window_Closing(object sender, CancelEventArgs e)
        {
            if (Uploading)
            {
                var response = System.Windows.MessageBox.Show(
                    "A submission is being uploaded, if you exit now the process will be canceled.",
                    "iPortal Uploader", MessageBoxButton.OKCancel);
                if (response == MessageBoxResult.Cancel)
                    e.Cancel = true;
            }

        }
    }
}
