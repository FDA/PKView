using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace iPortal.SubmissionUploader
{
    interface ISubmissionDepot
    {
        /// <summary>
        /// Crawl serial folders to extract the ones with useful data files
        /// </summary>
        bool OnlySerialFoldersWithData { get; } 

        /// <summary>
        /// List of serial number folders in this submission folder
        /// </summary>
        IEnumerable<DirectoryInfo> SerialFolders { get; }

        /// <summary>
        /// Submision folder's physical directory reference
        /// </summary>
        DirectoryInfo Directory { get; }

        /// <summary>
        /// Fetch the list of serial folders from the directory
        /// </summary>
        /// <param name="progressIndicator">Used to notify folder fetch progress</param>
        Task<IEnumerable<DirectoryInfo>> FetchSerialFoldersAsync(IProgress<Feedback> progressIndicator, CancellationToken ct);

        /// <summary>
        /// Fetch the list of data files in a particular serial folder of the submission
        /// </summary>
        /// <param name="serialFolder">Serial number folder in which to search for data files</param>
        /// <param name="progressIndicator">Used to notify folder fetch progress</param>
        /// <param name="ct">Used to cancel the process</param>
        Task<IEnumerable<IEnumerable<FileInfo>>> FetchDataFilesAsync(DirectoryInfo serialFolder, IProgress<Feedback> progressIndicator, CancellationToken ct);        

    }
}
