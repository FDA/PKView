using iPortal.Config;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace iPortal.Models.PkView
{
    public static class NDAHash
    {
        public static int GetNdaHash(string ndaFolderName)
        {
            return GetStudyHash(ndaFolderName, null);
        }

        public static int GetStudyHash(string ndaFolderName, string studyFolderName)
        {
            var rootDir = new System.IO.DirectoryInfo(PkViewConfig.NdaRootFolder + ndaFolderName);
            var supplementDirs = rootDir.GetDirectories();
            var signature = "";
            foreach (var supplementDir in supplementDirs)
            {
                var dir = new System.IO.DirectoryInfo(supplementDir.FullName + @"\m5\datasets\" + studyFolderName);
                if (dir.Exists)
                    signature += GetClinicalFilesTimestampSignature(dir);
            }
            return signature.GetHashCode();
        }

        private static string GetClinicalFilesTimestampSignature(System.IO.DirectoryInfo folder)
        {
            var clinicalFiles = folder.GetFiles("*.xpt", System.IO.SearchOption.AllDirectories).OrderBy(f => f.FullName);
            var signature = clinicalFiles.Aggregate("", (s, f) => s += f.LastWriteTime.ToString("yyyyMMddHHmmssffff"));
            return signature;
        }
    }
}