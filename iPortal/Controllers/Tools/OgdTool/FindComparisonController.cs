using System.Collections.Generic;
using System.Linq;
using System.Web.Http;
using iPortal.Config;
using iPortal.Models.OgdTool;
using System.IO;
using System;
using iPortal.Models.Shared;
using System.Text.RegularExpressions;
using System.Data;

namespace iPortal.Controllers.OgdTool
{
    /// <summary>
    /// Comparison finder controller
    /// </summary>
    /// 
    public class FindComparisonController : ApiController
    {
        private static List<string> cdiscSdtmDomainsBlacklist;
        private static List<string> nonMeaningfulFolderNames = new List<string> 
            { "tabulations", "legacy", "datasets", "analysis", "listings", "sdtm", "misc" };

        /// <summary>
        /// Initialize CDISC SDTM blacklist
        /// </summary>
        static FindComparisonController()
        {
            var blacklist = new List<string> { 
                "DM", "CO", "SE", "SV", "CM", "EX", "SU", "AE", "DS", "MH",
                "DV", "CE", "EG", "LB", "PE", "QS", "SC", "VS", "DA", "MB",
                "MS", "PC", "PP", "FA", "IE", "TA", "TE", "TV", "TI", "TS"
            };

            blacklist.AddRange(
                blacklist.Select(d => "SUPP" + d).ToList());

            blacklist.Add("SUPPQUAL");
            blacklist.Add("RELREC");

            cdiscSdtmDomainsBlacklist = blacklist;
        }

        /// <summary>
        /// Main Get function
        /// </summary>
        /// <returns>A list of results</returns>
        [Route("api/ogdtool/submissions/{submissionId}/findComparisons")]
        public Project Get(string submissionId)
        {
            var project = new Project();
            project.Comparisons = new List<TreatmentComparison>();

            var rootDir = new System.IO.DirectoryInfo(PkViewConfig.NdaRootFolder + submissionId);

            project.AllFiles = rootDir.EnumerateFiles("*.xpt", SearchOption.AllDirectories)
                .Select(d => d.FullName.Substring(OgdToolConfig.NdaRootFolder.Length)).ToList();

            // Exclude blacklisted files
            var potentialFiles = this.excludeBlacklistedFiles(project.AllFiles);

            // Group files by containing folder
            var groupedByPath = potentialFiles.GroupBy(f => Path.GetDirectoryName(f),
                (path, files) => new { Path = path, Files = files });

            // For each file group, pair the files into comparisons
            foreach (var dataFolder in groupedByPath)            
                project.Comparisons.AddRange(
                    this.findComparisonFileSets(dataFolder.Path, dataFolder.Files));            

            // Map file columns and data
            var comparisonMapper = new MapDataController();
            for (var i = 0; i < project.Comparisons.Count(); i++)
                project.Comparisons[i].Mappings = comparisonMapper.MapComparison(project.Comparisons[i]);            

            // Edge case where path is not meaningful enough to assign a title
            for (var i = 0; i < project.Comparisons.Count(); i++)
                project.Comparisons[i].Title =
                    project.Comparisons[i].Title ?? submissionId + (i > 0 ? "-" + i : "");

            return project;
        }

        /// <summary>
        /// Return a subset of the original file list without the files
        /// blacklisted. Blacklisted files are in most cases files belonging
        /// to the CDISC SDTM standard which will not be useful for our current purpose
        /// </summary>
        /// <param name="files"></param>
        /// <returns></returns>
        private List<string> excludeBlacklistedFiles(List<string> files)
        {
            return files.Where(f => !cdiscSdtmDomainsBlacklist.Contains(
                Path.GetFileNameWithoutExtension(f).ToUpper())).ToList();
        }

        /// <summary>
        /// Filter and group data files in the directory to obtain 
        /// pk, concentration and their auxiliary datasets like time or ke
        /// </summary>
        /// <param name="path">directory path</param>
        /// <param name="files">list of files in the directory</param>
        /// <returns>lists of files grouped by comparison</returns>
        private IEnumerable<TreatmentComparison> findComparisonFileSets(string path, IEnumerable<string> files)
        {
            //Locate pk files
            List<string> pkFiles = this.extractPotentialPkFiles(files);
            var remainingFiles = files.Except(pkFiles);

            // Initialize list of treatment comparisons
            var comparisons = pkFiles.Select(f => new TreatmentComparison { 
                PkFile = new DataFile { Path = f }
            }).ToList();
            
            //Locate concentration files
            List<string> concFiles = this.extractPotentialConcFilesGood(remainingFiles);            
            if (pkFiles.Count > concFiles.Count)
            { 
                concFiles.AddRange(this.extractPotentialConcFilesBad(remainingFiles.Except(concFiles)));
                if (pkFiles.Count > concFiles.Count)
                {
                    concFiles.AddRange(this.extractPotentialConcFilesUgly(remainingFiles.Except(concFiles)));
                }            
            }

            // Pair concentration with pk
            if (concFiles.Any())
            {
                comparisons = this.pairConcentration(comparisons, concFiles);
                remainingFiles = remainingFiles.Except(
                    comparisons.Select(c => c.ConcentrationFile != null ? c.ConcentrationFile.Path : null));
            }

            //Comparison title is based on folder if only one
            if (comparisons.Count() == 1)            
               comparisons[0].Title = this.getTitleFromPath(comparisons[0]);            

            // Comparison titles are based on file name if more than one
            if (comparisons.Count() > 1)
            {
                foreach (var comparison in comparisons)
                {
                    var tempName = Path.GetFileNameWithoutExtension(comparison.PkFile.Path);
                    tempName = Regex.Replace(tempName,
                        "pk(param(eters?)?)?|pharmacokinetic|data",
                        "", RegexOptions.IgnoreCase);
                    tempName = Regex.Replace(tempName, "([^a-zA-Z0-9]){2,}", "$0");
                    tempName = tempName.Trim(new[] { ' ', '\t', '_', '-' });
                    comparison.Title = tempName;

                    // Fallback to folder based title
                    if (String.IsNullOrEmpty(tempName))
                        comparison.Title = this.getTitleFromPath(comparison); 
                }
            }

            // Find auxiliary time files
            if (!remainingFiles.Any()) return comparisons;
            List<string> timeFiles = this.extractPotentialTimeFiles(remainingFiles);
            if (timeFiles.Any())
            {
                comparisons = this.pairTime(comparisons, timeFiles);
                remainingFiles = remainingFiles.Except(
                    comparisons.Select(c => c.TimeFile != null ? c.TimeFile.Path : null));
            }

           // Find auxiliary ke files
            if (!remainingFiles.Any()) return comparisons;
            List<string> keFiles = this.extractPotentialKeFiles(remainingFiles);
            if (keFiles.Any())
                comparisons = this.pairKe(comparisons, keFiles);                   

            return comparisons;
        }

        /// <summary>
        /// Extract a list of potential pk files
        /// </summary>
        /// <param name="files"></param>
        /// <returns></returns>
        private List<string> extractPotentialPkFiles(IEnumerable<string> files)
        {
            return files.Where(f => new [] {"pk", "pharmacok"}
                .Any(pattern => Path.GetFileNameWithoutExtension(f)
                    .ToLower().IndexOf(pattern) > -1)).ToList();
        }

        /// <summary>
        /// Extract a list of potential concentration files (good format)
        /// </summary>
        /// <param name="remainingFiles"></param>
        /// <returns></returns>
        private List<string> extractPotentialConcFilesGood(IEnumerable<string> files)
        {
            return files.Where(f => Path.GetFileNameWithoutExtension(f)
                .ToLower().IndexOf("conc") > -1).ToList();
        }

        /// <summary>
        /// Extract a list of potential concentration files (bad format)
        /// </summary>
        /// <param name="enumerable"></param>
        /// <returns></returns>
        private List<string> extractPotentialConcFilesBad(IEnumerable<string> files)
        {
            return files.Where(f => new[] {"con", "cc", "cn", "dt", "dat", "raw"}
                .Any(pattern => Path.GetFileNameWithoutExtension(f)
                    .ToLower().IndexOf(pattern) > -1)).ToList();
        }

        /// <summary>
        /// /// Extract a list of potential concentration files (ugly format, use caution)
        /// </summary>
        /// <param name="enumerable"></param>
        /// <returns></returns>
        private IEnumerable<string> extractPotentialConcFilesUgly(IEnumerable<string> files)
        {
            return files.Where(f =>
            {
                var fname = Path.GetFileNameWithoutExtension(f);
                return char.ToLower(fname[0]) == 'c' && !char.IsLetter(fname[1]);
            }).ToList();
        }

        private List<string> extractPotentialTimeFiles(IEnumerable<string> files)
        {
            return files.Where(f => Path.GetFileNameWithoutExtension(f)
                .ToLower().IndexOf("time") > -1).ToList();
        }

        private List<string> extractPotentialKeFiles(IEnumerable<string> files)
        {
            return files.Where(f => Path.GetFileNameWithoutExtension(f)
                .ToLower().IndexOf("ke") > -1).ToList();
        }

        private List<TreatmentComparison> pairConcentration(List<TreatmentComparison> comparisons, List<string> concFiles)
        {
            List<string> pairedFiles = this.pairWithPk(comparisons, concFiles);
            return comparisons.Zip(pairedFiles, (c, f) =>
            {
                if (!string.IsNullOrEmpty(f))
                    c.ConcentrationFile = new DataFile { Path = f };
                return c;
            }).ToList();
        }

        private List<TreatmentComparison> pairTime(List<TreatmentComparison> comparisons, List<string> timeFiles)
        {
            List<string> pairedFiles = this.pairWithPk(comparisons, timeFiles);
            return comparisons.Zip(pairedFiles, (c, f) =>
            {
                if (!string.IsNullOrEmpty(f))
                {
                    c.TimeFile = new DataFile { Path = f };
                    c.UseTimeFile = true;
                }
                else c.UseTimeFile = false;
                return c;
            }).ToList();
        }

        private List<TreatmentComparison> pairKe(List<TreatmentComparison> comparisons, List<string> keFiles)
        {
            List<string> pairedFiles = this.pairWithPk(comparisons, keFiles);
            return comparisons.Zip(pairedFiles, (c, f) =>
            {
                if (!string.IsNullOrEmpty(f))
                {
                    c.KeFile = new DataFile { Path = f };
                    c.UseKeFile = true;
                }
                else c.UseKeFile = false;
                return c;
            }).ToList();
        }

        /// <summary>
        /// 
        /// </summary>
        /// <param name="comparisons"></param>
        /// <param name="concFiles"></param>
        /// <returns></returns>
        private List<string> pairWithPk(IEnumerable<TreatmentComparison> comparisons, List<string> files)
        {
            var pairedFiles = Enumerable.Repeat<string>(null, comparisons.Count()).ToList();
            var distance = new DamerauLevenshteinDistance();

            // Initialize scores array
            var scoresArray = comparisons.Select((c,i) => new {c,i})
                .ToDictionary(row => row.i, row =>
                {
                    var pkFilename = Path.GetFileNameWithoutExtension(row.c.PkFile.Path).ToLower();
                    return files.Select((f, j) => new {f,j})
                        .ToDictionary(col => col.j, col =>
                            distance.Calculate(
                                Path.GetFileNameWithoutExtension(col.f).ToLower(), pkFilename)
                        );
                });

            // Iteratively extract the best matches
            while (scoresArray.Any() && scoresArray.Count * scoresArray.First().Value.Count > 1)
            {
                // find the current best match
                int currentScore = int.MaxValue, pkId = -1, fId = -1;
                foreach (var row in scoresArray)
                {
                    int rowScore = int.MaxValue, rowfId = -1;
                    foreach (var col in row.Value)
                    {
                        if (col.Value < rowScore)
                        {                    
                            rowfId = col.Key;
                            rowScore = col.Value;
                        }
                    }
                    if (rowScore < currentScore)
                    {                        
                        pkId = row.Key;
                        fId = rowfId;
                        currentScore = rowScore;
                    }
                }

                // Save selected match
                pairedFiles[pkId] = files[fId];

                // Clean scores array for next iteration
                scoresArray.Remove(pkId);
                foreach (var row in scoresArray) row.Value.Remove(fId);
            } 
                    
            // if one match remaining
            if (scoresArray.Any())
                pairedFiles[scoresArray.First().Key] = 
                   files[scoresArray.First().Value.First().Key];          

            return pairedFiles;
        }

        string getTitleFromPath(TreatmentComparison comparison)
        {
            var trimmedPath = comparison.PkFile.Path;
            trimmedPath.Substring(trimmedPath.IndexOf(@"\m5\") + 4);
            var title = "";
            do
            {
                trimmedPath = Path.GetDirectoryName(trimmedPath);
                title = Path.GetFileName(trimmedPath);
            } while (title != null && nonMeaningfulFolderNames.Contains(title.ToLower()));
            return title;
        }      

        /// <summary>
        /// Find the datasets directory recursively, but fully explore each level before going deeper into the tree (faster)
        /// </summary>
        /// <param name="root"></param>
        /// <returns></returns>
        private static DirectoryInfo findDatasetsDir(DirectoryInfo root)
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
