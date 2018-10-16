using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows;

namespace iPortal.SubmissionUploader
{
    /// <summary>
    /// Describes a submission uploader window
    /// </summary>
    interface ISubmissionUploaderWindow: INotifyPropertyChanged
    {
        /// <summary> List of submission repositories </summary>
        IEnumerable<String> RepositoryList { get; }
        /// <summary> Currently selected submission repository </summary>
        String SelectedRepository { get; }
        /// <summary> Custom repository Uri</summary>
        String CustomRepositoryUri { get; }
        /// <summary> True when the UI is loading the list of submissions</summary>
        Boolean LoadingSubmissionFolderList { get; }
        /// <summary> List of Submission Folders in the repository</summary>
        IEnumerable<String> SubmissionFolderList { get; }
        /// <summary> Currently selected submission folder </summary>
        String SelectedSubmissionFolder { get; }
        /// <summary> Determines whether a single serial folder or all of them will be uploaded</summary>
        Boolean UploadSingleSerialFolder { get; }
        /// <summary> True when the UI is loading the list of serials </summary>
        Boolean LoadingSerialFolderList { get; }
        /// <summary> True when the serial folder list should be shown </summary>
        Boolean ShowSerialFolderList { get; }
        /// <summary> List of serial number folders in the submission</summary>
        IEnumerable<String> SerialFolderList { get; }
        /// <summary> Currently selected serial folder</summary>
        String SelectedSerialFolder { get; }
        /// <summary> Used to notify the UI when the submission is uploading</summary>
        Boolean Uploading { get; }
        /// <summary> True when progressbar should be shown in the UI </summary>
        Boolean ShowProgressBar { get; }
        /// <summary> Progress value for the UI </summary>
        Feedback TaskProgress { get; }
    }
}
