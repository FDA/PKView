using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

//class definitions for ISS study variables

namespace iPortal.Models.PkView
{
    public class IssSubmission
    {
        public List<Analysis> Analyses;
    }

    public class IssMappingSettings
    {
        public string IssNDAName = "";
        public string IssStudyCode = "";
        public string IssSupplementNumber = "";
        public string IssProfileName = "";
        public List<IssDomain> IssStudyMappings;
        public List<IssTRTP> IssTRTPs;
        public List<TRTxxP> TRTxxPs;
        public string AnalysisType;
        public string AeCutoffRate;
        public string RandomNumber;
        public string ClinicalDose;
        public List<CDomain> CDomains;
        public bool displayOptions;
        public bool AnalysisComplete;
        public bool CumulativeAePooled;
        public bool CumulativeAeIndividual;
        public bool DoseResponse;
        public bool DosingRecord;
        public bool PkSafetyDdi;
        public string MaxDayCumulative;
        public List<AesevValue> AesevValues;
        public List<AesevValue> AsevValues;
        public bool displayML;
    }

    public class AesevValue
    {
        public string UniqueValue;
        public string order;
    }

    public class Analysis
    {
        public string AnalysisName;
        public string AnalysisCreationDate;
        public IssMappingSettings IssStudy;
        public string[] MLStudy;
        public bool AnalysisSaved;
    }

    public class CDomain
    {
        public string CDomainName;
        public List<CVariable> CVariables;
        public List<selectedVar> Inclusions;
        public List<selectedVar> Exclusions;
    }

    public class CVariable
    {
        public string CVariableName;
    }

    public class selectedVar
    {
        public string InEx;
        public string selectedVariable;
        public string relation;
        public List<CountValue> CountValues;
        public string ValueType;
        public string selVarDomain;
        public string FileLocation;
        public List<string> Relations;
        public bool display;
    }

    public class CountValue
    {
        public string UniqueValue;
        public bool SelectValue;
    }

    public class TRTxxP
    {
        public bool Selection;
        public string TRTXXP;
    }

    public class IssDomain
    {
        public string IssDomainType = "";
        public List<IssMapping> IssDomainMappings;
        public List<IssFileVariable> IssFileVariables;
        public string IssFileId;
    }

    public class IssTRTP
    {
        public bool IncludeStudy;
        public string StudyId;
        public string TRTP;
        public string RevisedTRTP;
        public string order;
        public string ARM;
        public string StudyDuration;
        public double sortKey;
        public string NumberOfSubjects;
        public double NumericDose;
    }

    public class IssMapping
    {
        public string IssVariable = "";
        public string IssFileVariable = "";
        public int IssMappingQuality;
    }

    public class IssFileVariable
    {
        public string IssName;
        public string IssDescription;
        public string IssLabel;
    }
}