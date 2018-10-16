using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Web;

namespace iPortal.Models.Shared.System
{
    public static class ZipArchiveDirectoryExtensions
    {
        /// <summary>
        /// Archives a folder recursively by compressing it and adding it to the Zip file
        /// </summary>
        /// <param name="archive">archive to add the files to</param>
        /// <param name="sourceDirectory">folder to be compressed</param>
        /// <param name="entriesPrefix">relative path to prepend to the archived folder</param>
        /// <param name="compressionLevel">compression level</param>
        /// <returns>a collection of created compressed file entries in the archive</returns>
        public static IReadOnlyCollection<ZipArchiveEntry> CreateEntriesFromDirectory(this ZipArchive archive, string sourceDirectory, string entriesPrefix = "", CompressionLevel compressionLevel = CompressionLevel.Fastest) 
        {
            var collection = new List<ZipArchiveEntry>();
            var rootFolder = new DirectoryInfo(sourceDirectory);
            foreach (var file in rootFolder.EnumerateFiles("*", SearchOption.AllDirectories))
            {
                if (file.Name != "Thumbs.db") 
                { 
                String relativePath = file.FullName.Substring(sourceDirectory.Length);
                String entryPath = Path.Combine(entriesPrefix, relativePath).TrimStart(new[] { '/', '\\' });
                ZipArchiveEntry entry = archive.CreateEntryFromFile(file.FullName, entryPath);
                collection.Add(entry);
                }
            }
            return collection;
        }
    }
}