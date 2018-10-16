using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace iPortal.SubmissionUploader
{
    /// <summary> Available upload modes </summary>
    public enum UploadModes { All = 0, SingleSerial = 1 }

    /// <summary>
    /// Defines a submission uploader
    /// </summary>
    interface ISubmissionUploader
    {       
        /// <summary> Currently selected submission repository</summary>
        String SelectedRepository { get; }

        /// <summary> Repository Uri to be used when <see cref="SelectedRepository">SelectedRepository</see> is set to 'Custom'</summary>
        String CustomRepositoryUri { get; }

        /// <summary> Selected submission to be uploaded</summary>
        String SelectedSubmissionFolder { get; }

        /// <summary> Submission upload mode</summary>
        UploadModes UploadMode { get; }

        /// <summary> Selected serial number to be uploaded</summary>
        String SelectedSerialFolder { get; }

        /// <summary>
        /// Retrieve the list of available submission repositories
        /// </summary>
        /// <returns>A string list of repository names</returns>
        IEnumerable<String> GetRepositories();

        /// <summary>
        /// Retrieve the list of available submission folders in the repository
        /// </summary>
        /// <returns>A string list of submission folder names</returns>
        IEnumerable<String> GetSubmissionFolders();

        /// <summary>
        /// Retrieve the list of available serial folders in the submission
        /// </summary>
        /// <returns>A string list of serial folder names</returns>
        Task<IEnumerable<String>> GetSerialFoldersAsync(IProgress<Feedback> progressIndicator, CancellationToken ct);

        /// <summary>
        /// Upload the submission
        /// </summary>
        /// <param name="progressIndicator">Used to report back progress</param>
        /// <param name="ct">Used to cancel the upload</param>
        /// <returns>the task object representing the asynchronous operation</returns>
        Task UploadAsync(IProgress<Feedback> progressIndicator, CancellationToken ct);
    }
}
