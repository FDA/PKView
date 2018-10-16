using System;
using System.Collections.Generic;
using System.Data;
using System.IO;
using System.Linq;
using System.Web;
using iPortal.Config;
using SasJobs.ClientLibrary;
using SasJobs.Messages;
using System.Globalization;

namespace iPortal.Models.PkView
{
    public class StudyDataManager 
    {
        /// <summary> Ordinal dictionary used for parsing, there's probably no need for more than seven </summary>
        string[] ordinalDictionary = { "first", "second", "third", "fourth", "fifth", "sixth", "seventh" }; 

        /// <summary>
        /// Start initialization of a study in the backend and return the job id
        /// </summary>
        /// <param name="submissionId"></param>
        /// <param name="supplementNumber"></param>
        /// <param name="studyCode"></param>
        /// <returns></returns>
        public string Initialize(string submissionId, string supplementNumber, string studyCode)
        {
            string studyFolder = getStudyFolder(submissionId, supplementNumber, studyCode).FullName;
            int hash = StudySettings.GetFilesHash(studyFolder);

            // Run the 'RunMappings' stored procedure in the SAS server. This procedure will extract
            // The variables and make the initial mappings for the user to review.
            return SasClientObject.NewJob("RunStudyMappings", new { StudyFolder = studyFolder, NdaHash = hash }).ToString();
        }

        /// <summary>
        /// Poll the server for the results of a study initialization
        /// </summary>
        /// <param name="submissionId"></param>
        /// <param name="supplementNumber"></param>
        /// <param name="studyCode"></param>
        /// <param name="jobId"></param>
        /// <returns></returns>
        public JobResponse<StudySettings> GetInitializationResult(string submissionId, string supplementNumber, string studyCode, string jobId)
        {
            var response = SasClientObject.Getjob(new Guid(jobId));

            // If no data was received the process is still running, return an empty list
            if (response.Status != SasJobs.Messages.StatusCode.Done)
            {
                var noDataResponse = new JobResponse<StudySettings>(response, null);

                // Give a better response when the process is stuck at 1%
                if (response.PercentComplete == 1)
                    noDataResponse.FeedbackMessage =
                        String.Format(@"Determining file structure and study design for study {0}", studyCode);

                return noDataResponse;
            }
            
            // If no data was returned
            if (response.Data.Tables.Count == 0)
                return new JobResponse<StudySettings>(response, null);

            // Check if an error code was received
            var errorTable = response.Data.Tables["errorstudy"];
            int errorCode = (errorTable != null && errorTable.Rows.Count > 0) ?
                Convert.ToInt32(errorTable.Rows[0]["error_code"]) : 0;
                
            // Retrieve datasets
            var rawStudies = response.Data.Tables["design"].AsEnumerable();
            var mappings = response.Data.Tables["mapping"].AsEnumerable();
            var arms = response.Data.Tables["arms"].AsEnumerable();
            var ppvisit = response.Data.Tables["ppvisit"].AsEnumerable();
            var pcvisit = response.Data.Tables["pcvisit"].AsEnumerable();
            var fileVariables = response.Data.Tables["out"].AsEnumerable();
                        
            // Initialize study profile
            var study = new StudySettings
            {
                NDAName = submissionId,
                SupplementNumber = supplementNumber,
                StudyCode = studyCode,
                StudyError = errorCode
            };

            // Retrieve study mapping information (FIXME simplify sas-C# interface)
            var studyRow = rawStudies.FirstOrDefault();
            if (studyRow != null)
            {
                // study type
                study.StudyType = Convert.ToInt32(studyRow["Study_Type"]);

                // Arms
                study.Arms = arms.Where(arow => arow["Study_Code"].ToString().Equals(study.StudyCode))
                    .Select(arow => arow["arm"].ToString()).ToList();

                // PP:Visit
                study.PpVisit = ppvisit.Where(pprow => pprow["Study_Code"].ToString().Equals(study.StudyCode))
                    .Select(pprow => pprow["visit"].ToString()).ToList();

                // PC:Visit
                study.PcVisit = pcvisit.Where(pcrow => pcrow["Study_Code"].ToString().Equals(study.StudyCode))
                    .Select(pcrow => pcrow["visit"].ToString()).ToList();

                // Mappings
                study.StudyMappings = mappings
                    .Where(mrow => mrow["Study_Code"].ToString().Equals(study.StudyCode))
                    .GroupBy(mrow => mrow["Source"]).Select(mrows => new Domain
                    {
                        Type = mrows.First()["Source"].ToString(),
                        DomainMappings = mrows.Select(mrow => new Mapping
                        {
                            FileVariable = mrow["File_Variable"].ToString(),
                            SdtmVariable = mrow["SDTM_Variable"].ToString(),
                            MappingQuality = Convert.ToInt32(mrow["Mapping_Quality"])
                        }).Where(m => m.MappingQuality >= 0).ToList(), // Filter out mappings with quality -1 (dummy mappings)

                        // The way sas returns the data, the variables will be listed in the first table of the dataset.
                        FileVariables = fileVariables.Where(frow =>
                            frow["study"].ToString().Equals(study.StudyCode) &&
                            frow["source"].Equals(mrows.First()["Source"]))
                            .Select(frow => new FileVariable
                            {
                                Name = frow["variable"].ToString(),
                                Description = frow["variableDescription"].ToString(),
                                Label = String.Format("{0} - {1}", frow["variable"].ToString(), frow["variableDescription"].ToString())
                            }).ToList(),
                        FileId = mrows.First()["Path"].ToString()
                    }).ToList();

            }


            // If no studies have been retrieved return null  
            return new JobResponse<StudySettings>(response, study);           
        }

        /// <summary>
        /// Determine the list of treatments in each arm
        /// </summary>
        /// <param name="arms">A list of string representations of each arm</param>
        /// <returns></returns>
        public IEnumerable<ArmMapping> DetermineArmTreatments(IEnumerable<string> arms)
        { 
            IEnumerable<ArmMapping> armMappings = arms.Select(a => 
                new ArmMapping { OldArm = a.Trim(), Treatments = new List<string>() }).ToList();

            // Attempt to determine arm treatments by enclosing characters
            armMappings = determineTreatmentsByEnclosingChars(armMappings);

            // Attempt to determine arm treatments by guessing separa
            armMappings = determineTreatmentsByArmPermutations(armMappings);

            // Attempt to determine arm treatments by guessing separa
            armMappings = determineTreatmentsByArmCorrelations(armMappings);

            // Default, set arms to parallel
            foreach (var arm in armMappings)
                if (arm.Treatments.Count == 0) 
                    arm.Treatments.Add(cleanTreatmentSpecialChars(arm.OldArm));

            return armMappings;
        }

        /// <summary>
        /// Maps the values of visit to a standarized sequential value
        /// </summary>
        /// <param name="visits">The original list of visit values</param>
        /// <returns>a standarized list of visit mappings</returns>
        public IEnumerable<ValueMapping> DetermineVisits(IEnumerable<string> visits)
        {
            double dummy;
            bool isNumeric = visits.All(v => double.TryParse(v, out dummy));
            return this.decodeTimeVariable(visits).OrderBy(pair => pair.Value)
                .Select((pair, i) => new ValueMapping
                {
                    Original = pair.Key,
                    New = (isNumeric ? "" : "DAY ") + (i + 1).ToString("D2")
                });
        }

        /// <summary>
        /// Maps the values of time points to a standarized sequential value
        /// </summary>
        /// <param name="visits">The original list of tpt values</param>
        /// <returns>a standarized list of tpt mappings</returns>
        public IEnumerable<ValueMapping> DetermineTpts(IEnumerable<string> times)
        {
            return this.decodeTimeVariable(times).OrderBy(pair => pair.Value)
                .Select((pair, i) => new ValueMapping
                {
                    Original = pair.Key,
                    New = pair.Key
                });
        }

        /// <summary>
        /// Group arms into permutations of crossover arms by textual similarity and
        /// then determine how to separate the treatments fro each group
        /// </summary>
        /// <param name="armMappings"></param>
        /// <returns></returns>
        private IEnumerable<ArmMapping> determineTreatmentsByArmPermutations(IEnumerable<ArmMapping> mappings)
        {
            // If we sort the characters of two permutations of the same 
            // crossover cohort they should yield the same set of characters
            // look only for those arms whose treatments have not been determined
            var crossoverGroups = mappings.Where(m => m.Treatments.Count == 0)
                .GroupBy(m => new string(m.OldArm.OrderBy(c => c).ToArray()))
                .Where(g => g.Count() > 1).ToList();

            // iterate over the groups we found
            foreach (var group in crossoverGroups)
            {
                // find treatments by separator
                findTreatmentsInPermutationBySeparator(group);
                
                // find treatments by looking for an alphabetical sequence (typical of ARMCD)
                if (group.First().Treatments.Count == 0)
                    findTreatmentsInPermutationByAlphabeticalSequence(group);
            }
            return mappings;
        }

        /// <summary>
        /// Attempts to determine the treatments by searching for an alphabetical or
        /// single digit numerical sequence
        /// </summary>
        /// <param name="permutationGroup"></param>
        private void findTreatmentsInPermutationByAlphabeticalSequence(IGrouping<string, ArmMapping> permutationGroup)
        {
            string permutationString = permutationGroup.Key;

            // Check the permutation group is only composed by letters
            if (!(permutationString.All(c => char.IsLetter(c)) || 
                    permutationString.All(c => char.IsDigit(c)))) return;

            // Skip letter threshold is based on the number of arms 
            int threshold = permutationGroup.Count() - 1;

            // first letter to check
            char currentLetter = char.ToLower(permutationString[0]);
            
            // Determine if the arm is really an alphabetical sequence
            foreach (char letter in permutationString.ToLower().Skip(1))
            { 
                currentLetter++;
                // is the letter an increment of 1 from last letter?
                if (letter != currentLetter)
                {
                    // calculate the letter difference
                    int diff = Math.Abs(letter - currentLetter);

                    // decrease the threshold by the difference
                    threshold -= diff;

                    // if we have already exhausted the threshold, return
                    if (threshold < 0) return;

                    // update the current letter
                    currentLetter = letter;
                }
            }

            // if the candidate alphabetical arm passed the test, save the treatments
            foreach (var arm in permutationGroup)
            {
                arm.Treatments.AddRange(arm.OldArm.Select(c => new string(c, 1)));
            }
        }

        /// <summary>
        /// Find the list of treatments in a group of arms consisting of permutations
        /// of the same list of treatments by locating a separator and verifying if that
        /// separator yields the same list of treatments for all grouped arms
        /// </summary>
        /// <param name="permutationGroup"></param>
        private void findTreatmentsInPermutationBySeparator(IGrouping<string, ArmMapping> permutationGroup)
        {
            var firstArm = permutationGroup.First().OldArm;
            char separator = ' '; int skip = 1; bool found = false;

            while (!found && skip < firstArm.Length)
            {
                // We do not expect letters or digits to be separator characters
                do
                {
                    separator = firstArm[skip++];
                } while ((char.IsLetterOrDigit(separator)
                    || char.IsWhiteSpace(separator)) && skip < firstArm.Length);

                // if we did find a potential separator character
                if (skip < firstArm.Length)
                {
                    // split the first two arms using the selected separator
                    // and compare the resulting lists, if separator is correct
                    // they will yield the same list of treatments
                    var secondArm = permutationGroup.ElementAt(1).OldArm;
                    var firstArmTrts = firstArm.Split(separator).Select(t => t.Trim());
                    var secondArmTrts = secondArm.Split(separator).Select(t => t.Trim());
                    if (firstArmTrts.OrderBy(t => t)
                        .SequenceEqual(secondArmTrts.OrderBy(t => t)))
                    {
                        // Store the treatment lists
                        found = true;
                        permutationGroup.First().Treatments.AddRange(firstArmTrts
                            .Select(t => cleanTreatmentSpecialChars(t)));
                        permutationGroup.ElementAt(1).Treatments = secondArmTrts
                            .Select(t => cleanTreatmentSpecialChars(t)).ToList();
                        if (permutationGroup.Count() > 2)
                        {
                            foreach (var arm in permutationGroup.Skip(2))
                                arm.Treatments = arm.OldArm.Split(separator)
                                    .Select(t => cleanTreatmentSpecialChars(t.Trim())).ToList();
                        }
                    }
                }
            }    
        }

        /// <summary>
        /// Look for potential separators and use them to correlate treatments to other arms.
        /// This is useful for crossover designs with placebos or where some treatments are only
        /// present in one arm.
        /// </summary>
        /// <param name="armMappings"></param>
        /// <returns></returns>
        private IEnumerable<ArmMapping> determineTreatmentsByArmCorrelations(IEnumerable<ArmMapping> mappings)
        {
            // Select the arms where no treatments have been determined yet
            var arms = mappings.Where(m => m.Treatments.Count == 0).ToList();

            // For each arm, check for a separator and then correlate with other arms
            for (int i = 0; i < arms.Count - 1; i++)
            {
                string armName = arms[i].OldArm;
                char separator = ' '; int skip = 1;

                while (arms[i].Treatments.Count == 0 && skip < armName.Length)
                {
                    // We do not expect letters or digits to be separator characters
                    do
                    {
                        separator = armName[skip++];
                    } while ((char.IsLetterOrDigit(separator)
                        || char.IsWhiteSpace(separator)) && skip < armName.Length);

                    // if we did find a potential separator character
                    if (skip < armName.Length)
                    {
                        // Separate the arm into treatments
                        var armTrts = armName.Split(separator).Select(t => t.Trim());

                        // For each other arm
                        foreach (var otherArm in arms.Skip(i + 1).ToList())
                        {
                            // if arm treatments are unassigned
                            if (otherArm.Treatments.Count == 0 && otherArm.OldArm.Contains(separator))
                            {
                                // Separate the arm into treatments
                                var otherArmTrts = otherArm.OldArm
                                    .Split(separator).Select(t => t.Trim());

                                // If any of the treatments in the inspected arm matches
                                if (armTrts.Any(trt => otherArmTrts.Contains(trt)))
                                {
                                    if (arms[i].Treatments.Count == 0)
                                        arms[i].Treatments.AddRange(armTrts
                                            .Select(t => cleanTreatmentSpecialChars(t)));
                                    otherArm.Treatments.AddRange(otherArmTrts
                                        .Select(t => cleanTreatmentSpecialChars(t)));
                                }
                            }
                        }                       
                    }
                }
            }
            return mappings;
        }


        /// <summary>
        /// Determine if arm treatments/groups are surrounded in any kind 
        /// of enclosing characters and if so, extract them
        /// </summary>
        /// <param name="mappings"></param>
        /// <returns></returns>
        private IEnumerable<ArmMapping> determineTreatmentsByEnclosingChars(IEnumerable<ArmMapping> mappings)
        {            
            foreach (var mapping in mappings)
            {
                if (mapping.OldArm == null) continue;

                // Check starting char for symbols
                var initialChar = mapping.OldArm.First();
                if (!char.IsLetterOrDigit(initialChar))
                {
                    // 6 char min: 4 enclosing characters + 2 trt characters, i.e. (A)(B)
                    // String must contain more than one enclosing character
                    if (mapping.OldArm.Length < 6 || !mapping.OldArm
                        .Substring(1, mapping.OldArm.Length - 2).Contains(initialChar))
                        continue;

                    var lastChar = mapping.OldArm.Last();
                    var initialCharType = Char.GetUnicodeCategory(initialChar);
                    var lastCharType = Char.GetUnicodeCategory(lastChar);

                    // Check for opening/closing symbols
                    if ((initialCharType == UnicodeCategory.OpenPunctuation
                            && lastCharType == UnicodeCategory.ClosePunctuation)
                        || (initialCharType == UnicodeCategory.InitialQuotePunctuation
                            && lastCharType == UnicodeCategory.FinalQuotePunctuation)
                        || (initialChar == '<' && lastChar == '>'))
                    {
                        // Extract treatments accounting for possible nesting
                        int start = 0, level = 0;
                        for (int i = 0; i < mapping.OldArm.Length; i++)
                        {
                            if (mapping.OldArm[i] == initialChar)
                            {
                                if (level == 0) start = i + 1;
                                level++;
                            }
                            if (mapping.OldArm[i] == lastChar)
                            {
                                level--;
                                if (level == 0)
                                    mapping.Treatments.Add(cleanTreatmentSpecialChars(
                                        mapping.OldArm.Substring(start, i - start).Trim()));
                            }
                        }
                    }
                    // We cant account for nesting if no opening/closing
                    // characters are used, do our best
                    else
                    {
                        int start = 0; bool inside = false;
                        for (int i = 0; i < mapping.OldArm.Length; i++)
                        {
                            if (mapping.OldArm[i] == initialChar)
                            {
                                if (inside)
                                    mapping.Treatments.Add(cleanTreatmentSpecialChars(
                                        mapping.OldArm.Substring(start, i - start).Trim()));
                                else start = i + 1;
                                inside = !inside;
                            }
                        }

                    }

                }
            }
            return mappings;
        }

        /// <summary>
        /// Decodes the time values to a long number
        /// </summary>
        /// <param name="times">The original list of time values</param>
        /// <returns>a dictionary of numerical times for the original values</returns>
        public Dictionary<string, long> decodeTimeVariable(IEnumerable<string> times)
        {
            var decodedTimes = new Dictionary<string, long>();

            // For each visit value find the numeric equivalent
            foreach (string oldTime in times)
            {
                long number = 0; int? foundNumber; string raw = oldTime;

                // Replace character ordinals
                for (var i = 0; i < ordinalDictionary.Length; i++)
                    raw.Replace(ordinalDictionary[i], String.Format("{0}", i + 1));

                // Get numbers without overflowing long.Max
                var c = 0;
                do
                {
                    foundNumber = findNumber(raw, out raw);
                    if (foundNumber != null)
                    {
                        number = number * 1000 + foundNumber.Value;
                        c++;
                    }
                } while (foundNumber != null && c < 7 && raw.Length > 0);

                decodedTimes.Add(oldTime, number);
            }

            return decodedTimes;
        }

        /// <summary>
        /// Replace the special characters that cause SAS errors
        /// </summary>
        /// <param name="treatment"></param>
        /// <returns></returns>
        private string cleanTreatmentSpecialChars(string treatment)
        {
            treatment = treatment.Replace('-', '_');
            treatment = treatment.Replace('+', '&');
            return treatment;
        }

        /// <summary>
        /// Find an integer in the string, return the rest of the unparsed string
        /// </summary>
        /// <param name="s">string to be parsed</param>
        /// <param name="rest">unparsed remaining string</param>
        /// <returns>the first integer found or null</returns>
        private int? findNumber(string s, out string rest)
        {
            // skip non-numeric characters
            string digits = null; rest = "";
            for (var i = 0; i < s.Length; i++)
            {
                if (char.IsDigit(s[i]))
                {
                    if (i > 0 && s[i-1] == '-') i--;
                    digits = s.Substring(i);
                    break;
                }
            }

            // no digits found, return null
            if (digits == null) return null;            

            // take only digits
            rest = digits;
            if (digits.Length > 1)
                digits = new string(digits.Skip(1).TakeWhile(c => char.IsDigit(c)).ToArray());
            else digits = "";
            digits = rest.Substring(0, 1) + digits;
            rest = rest.Substring(digits.Length);

            // if '-' is used as number separator, remove it so we don't
            // misinterpret it for a minus sign
            if (rest.Length > 0 && rest[0] == '-')
                rest = rest.Substring(1);

            // Parse the numeric value
            int numberFound;
            if (int.TryParse(new string(digits.ToArray()), out numberFound)) 
                return numberFound;
            else return null;
        }

        /// <summary>
        /// Get the root folder of a particular study
        /// </summary>
        /// <param name="submissionId"></param>
        /// <param name="supplementNumber"></param>
        /// <param name="studyCode"></param>
        /// <returns></returns>
        private DirectoryInfo getStudyFolder(string submissionId, string supplementNumber, string studyCode)
        {
            var supplementPath = PkViewConfig.NdaRootFolder + submissionId + '/' + supplementNumber;
            var supplementDir = new DirectoryInfo(supplementPath);
            DirectoryInfo dataDir = findDatasetsDir(supplementDir);
            return dataDir.EnumerateDirectories().FirstOrDefault(d => 
                d.Name.Equals(studyCode, StringComparison.InvariantCultureIgnoreCase));
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