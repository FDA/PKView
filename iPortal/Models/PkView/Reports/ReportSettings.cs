using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace iPortal.Models.PkView.Reports
{
    public class ReportSettings : IEquatable<ReportSettings>
    {
        public List<CohortReferences> References;
        public List<string> Analytes;
        public List<string> Parameters;
        public string Method;
        public ReportItemsSorting Sorting;
        
        // Concentration specific settings (FIXME)
        public string SelectedCohort;
        public string SelectedPeriod;
        public string SelectedPcAnalyte;
        public string SelectedPcSpecimen;

        public string SelectedPpAnalyte;
        public string SelectedPpSpecimen;
        public string SelectedAuct;
        public string SelectedAucInfinity;
        public string SelectedCmax;
        public string SelectedThalf;
        public string SelectedTmax;

        public double? StartTime;
        public double? EndTime;

        
        public bool Equals(ReportSettings other)
        {
            if (other == null) return false;

            return this.StartTime == other.StartTime
                && this.EndTime == other.EndTime

                && this.Method == other.Method                               
                && this.SelectedCohort == other.SelectedCohort
                && this.SelectedPeriod == other.SelectedPeriod
                && this.SelectedPcAnalyte == other.SelectedPcAnalyte
                && this.SelectedPcSpecimen == other.SelectedPcSpecimen
                && this.SelectedPpAnalyte == other.SelectedPpAnalyte
                && this.SelectedPpSpecimen == other.SelectedPpSpecimen
                && this.SelectedAuct == other.SelectedAuct
                && this.SelectedAucInfinity == other.SelectedAucInfinity
                && this.SelectedCmax == other.SelectedCmax
                && this.SelectedThalf == other.SelectedThalf
                && this.SelectedTmax == other.SelectedTmax 

                // By now the expression has probably evaluated if the report settings 
                // are indeed different, avoiding the evaluation below in most cases
                && this.compareStringList(this.Analytes, other.Analytes)
                && this.compareStringList(this.Parameters, other.Parameters)
                && this.compareStringList(this.Sorting.Columns, other.Sorting.Columns)
                && this.compareStringList(this.Sorting.Folders, other.Sorting.Folders)
                && this.compareStringList(this.Sorting.Files, other.Sorting.Files);
        }
        
        public override bool Equals(object other)
        {
            return this.Equals(other as ReportSettings);
        }

        public override int GetHashCode()
        {
            var hash = 17;

            // We use unchecked here to allow the hashing function to overflow
            unchecked
            {
                hash = hash * 31 + hashStringList(this.Analytes);
                hash = hash * 31 + hashStringList(this.Parameters);
                hash = hash * 31 + hashStringList(this.Sorting.Columns);
                hash = hash * 31 + hashStringList(this.Sorting.Files);
                hash = hash * 31 + hashStringList(this.Sorting.Folders);
                hash = hash * 31 + (Method == null ? 0 : Method.GetHashCode());
                hash = hash * 31 + (SelectedCohort == null ? 0 : SelectedCohort.GetHashCode());
                hash = hash * 31 + (SelectedPeriod == null ? 0 : SelectedPeriod.GetHashCode());
                hash = hash * 31 + (SelectedPcAnalyte == null ? 0 : SelectedPcAnalyte.GetHashCode());
                hash = hash * 31 + (SelectedPcSpecimen == null ? 0 : SelectedPcSpecimen.GetHashCode());
                hash = hash * 31 + (SelectedPpAnalyte == null ? 0 : SelectedPpAnalyte.GetHashCode());
                hash = hash * 31 + (SelectedPpSpecimen == null ? 0 : SelectedPpSpecimen.GetHashCode());
                hash = hash * 31 + (SelectedAuct == null ? 0 : SelectedAuct.GetHashCode());
                hash = hash * 31 + (SelectedAucInfinity == null ? 0 : SelectedAucInfinity.GetHashCode());
                hash = hash * 31 + (SelectedCmax == null ? 0 : SelectedCmax.GetHashCode());
                hash = hash * 31 + (SelectedThalf == null ? 0 : SelectedThalf.GetHashCode());
                hash = hash * 31 + (SelectedTmax == null ? 0 : SelectedTmax.GetHashCode());
                hash = hash * 31 + (StartTime == null ? 0 : StartTime.GetHashCode());
                hash = hash * 31 + (EndTime == null ? 0 : EndTime.GetHashCode());
            }
            return hash;
        }

        private bool compareStringList(List<string> l1, List<string> l2) 
        {
            if (l1 == null && l2 == null) return true;
            if (l1 == null || l2 != null) return false;
            return l1.OrderBy(s => s).SequenceEqual(l2.OrderBy(s => s));
        }

        private int hashStringList(List<string> l)
        {
            int hash = 17;
            if (l == null) return hash;            
            foreach (var s in l) hash = unchecked(hash * 31 + s.GetHashCode());
            return hash;
        }
        
    }

    public class ReportItemsSorting
    {
        public List<string> Folders;
        public List<string> Files;
        public List<string> Columns;
    }
}