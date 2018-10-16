define(function (require)
{
    var issData = require('issData/issData');
    var issGui = require('issGui/issGui');
    var system = require('durandal/system');

    // This is the datainput viewmodel prototype
    var dataInput = function ()
    {
        var self = this;

        // List of input file types
        self.fileTypes = ko.observableArray
        ([
           { id: "demographic", name: "Demographic" },
           { id: "adverseEvents", name: "Adverse Events" },
           { id: "exposure", name: "Exposure" }
        ]);

        // list of input files
        self.files = ko.observableArray([]);
        self.files.push(
        {
            id: "dm",
            name: "dm.xpt",
            type: "demographic",
            variables:
            [
                { description: "", id: "" },
                { description: "ADJTRT -- Adj Trt for primary diag of melanoma", id: "ADJTRT" },
                { description: "ADJTYPE1 -- Type of Adjuvant Treatment", id: "ADJTYPE1" },
                { description: "ADJTYPE2 -- Type of Adjuvant Treatment", id: "ADJTYPE2" },
                { description: "ADJTYPE3 -- Type of Adjuvant Treatment", id: "ADJTYPE3" },
                { description: "AGE -- Age (years) at randomisation", id: "AGE" },
                { description: "AGECAT -- Age Group (<=40)", id: "AGECAT" },
                { description: "AGEGRP -- Age Group (<65yrs)", id: "AGEGRP" },
                { description: "AGELS65 -- Age LT 65 flag", id: "AGELS65" },
                { description: "AGETRT -- Age and Treatment Group", id: "AGETRT" },
                { description: "ALLTRT -- All treated population", id: "ALLTRT" },
                { description: "BASESTG -- Metastatic Melanoma Stg at Base./Random.", id: "BASESTG" },
//                { description: "BIRTHDC -- Birth date", id: "BIRTHDC" },
//                { description: "BIRTHDT -- Birth SAS datetime", id: "BIRTHDT" },
//                { description: "BONE -- Metastatic site: Bone", id: "BONE" },
//                { description: "BRAIN -- Metastatic site: Brain", id: "BRAIN" },
//                { description: "BSTAGIV -- Met. Melan. Stage from IVRS(site entry)", id: "BSTAGIV" },
//                { description: "BSTAGIVR -- Met. Melan. Stage from IVRS", id: "BSTAGIVR" },
//                { description: "CHPDDC -- Date of Primary Diagnosis", id: "CHPDDC" },
//                { description: "COLON -- Metastatic site: Colon/Large intestine", id: "COLON" },
//                { description: "CONSNTDC -- Date of informed consent", id: "CONSNTDC" },
//                { description: "CRTN -- Clinical Research Task #", id: "CRTN" },
//                { description: "CSITESP1 -- Primary cancer site - specify text", id: "CSITESP1" },
//                { description: "CSITESP2 -- Primary cancer site - specify text", id: "CSITESP2" },
//                { description: "CSITESP3 -- Primary cancer site - specify text", id: "CSITESP3" },
//                { description: "CSITESP4 -- Primary cancer site - specify text", id: "CSITESP4" },
//                { description: "CSITESP5 -- Primary cancer site - specify text", id: "CSITESP5" },
//                { description: "CSITESP6 -- Primary cancer site - specify text", id: "CSITESP6" },
//                { description: "CSITESP7 -- Primary cancer site - specify text", id: "CSITESP7" },
//                { description: "CTCNUM -- Site Number", id: "CTCNUM" },
//                { description: "CTDS -- Cutoff SAS Date", id: "CTDS" },
//                { description: "CTYPEC -- Primary Diagnosis", id: "CTYPEC" },
//                { description: "DERMHIS1 -- History of Sorafenib", id: "DERMHIS1" },
//                { description: "DERMHIS3 -- History of other skin lesions", id: "DERMHIS3" },
//                { description: "DERMHIS4 -- History of chronic sun exposure", id: "DERMHIS4" },
//                { description: "DERMHIS5 -- History of tanning beds", id: "DERMHIS5" },
//                { description: "DERMHIS6 -- History of immunosuppression", id: "DERMHIS6" },
//                { description: "DERMHIS7 -- History of prior actinic keratosis", id: "DERMHIS7" },
//                { description: "DERMHIS9 -- History of prior SCC", id: "DERMHIS9" },
//                { description: "DERMPAT2 -- Carcinoma in-situ", id: "DERMPAT2" },
//                { description: "DERMPAT5 -- Actinic Keratosis", id: "DERMPAT5" },
//                { description: "DERMPAT6 -- Basal Cell Carcinoma", id: "DERMPAT6" },
//                { description: "DERMPAT7 -- Other pathological examination", id: "DERMPAT7" },
//                { description: "DISTMETA -- Distant Metastasis", id: "DISTMETA" },
//                { description: "DMECOG -- Coded ECOG rating", id: "DMECOG" },
//                { description: "DMLDH -- DMLDH", id: "DMLDH" },
//                { description: "DMLDHDES -- Decode of DMLDH", id: "DMLDHDES" },
//                { description: "DMMETA -- Coded Metastatic Classification Value", id: "DMMETA" },
//                { description: "DMPAGE -- CRF page identifier", id: "DMPAGE" },
//                { description: "DMREGDE -- Decode of DMREGID", id: "DMREGDE" },
//                { description: "DMREGID -- Coded Regions", id: "DMREGID" },
//                { description: "ECGFL -- ECG-evaluable population", id: "ECGFL" },
//                { description: "ECOGBL -- BL ECOG perfomance status", id: "ECOGBL" },
//                { description: "ECOGIVRS -- ECOG Performance Status from IVRS", id: "ECOGIVRS" },
//                { description: "EVALBORC -- Evaluable for BORR confirmed", id: "EVALBORC" },
//                { description: "EVALOSI -- Evaluable for OS at Interim Analysis", id: "EVALOSI" },
//                { description: "EVALPFS -- Evaluable for PFS (YES)", id: "EVALPFS" },
//                { description: "HEIGHTBL -- BL Height in cm", id: "HEIGHTBL" },
//                { description: "HISTOTHR -- Histological subtypes (other)", id: "HISTOTHR" },
//                { description: "HISTSUBT -- Histological Subtypes", id: "HISTSUBT" },
//                { description: "HISTYPE -- Histological Subtype Grouping", id: "HISTYPE" },
//                { description: "HSLDHVAL -- Historic LDH Value", id: "HSLDHVAL" },
//                { description: "INDLDHBL -- Indicator for elevated LDH at baseline", id: "INDLDHBL" },
//                { description: "INDTXT -- Pat. study indication: investigator text", id: "INDTXT" },
//                { description: "ITT -- ITT population flag", id: "ITT" },
//                { description: "IVRSGRID -- Randomized treatment Arm from IVRS", id: "IVRSGRID" },
//                { description: "IVRSGRP -- Randomized treatment group from IVRS", id: "IVRSGRP" },
//                { description: "KIDNEY -- Metastatic site: Kidney", id: "KIDNEY" },
//                { description: "LASTRTDC -- Date of the last dose", id: "LASTRTDC" },
//                { description: "LASTRTDS -- SAS date of the last dose", id: "LASTRTDS" },
//                { description: "LDH3CAT -- BL 3 category LDH Indicator", id: "LDH3CAT" },
//                { description: "LDHBL -- BL LDH", id: "LDHBL" },
//                { description: "LDHIVR -- LDH Value from IVRS(site entry)", id: "LDHIVR" },
//                { description: "LDHIVRS -- LDH Value from IVRS", id: "LDHIVRS" },
//                { description: "LIVER -- Metastatic site: Liver", id: "LIVER" },
//                { description: "LUNG -- Metastatic site: Lung", id: "LUNG" },
//                { description: "LYMPH -- Metastatic site: Lymph", id: "LYMPH" },
//                { description: "MELANSTG -- Stage (Melanoma)", id: "MELANSTG" },
//                { description: "METACODE -- Decode of DMMETA", id: "METACODE" },
//                { description: "METMELDC -- Date of metastatic melonoma diagnosis", id: "METMELDC" },
//                { description: "METSTLS3 -- Flag of BL metastatis sites LT 3 flag", id: "METSTLS3" },
//                { description: "METSTTOT -- Count of BL metastatis sites", id: "METSTTOT" },
//                { description: "NBPRTHER -- Number of prior therapies ", id: "NBPRTHER" },
//                { description: "NONV600E -- Non-V600E BRAF Mutation by Sanger Seq ", id: "NONV600E" },
//                { description: "N_V600E -- BRAF Non-V600E mutation population", id: "N_V600E" },
//                { description: "OTHERMTS -- Metastatic site: Others", id: "OTHERMTS" },
//                { description: "PDM -- Major protocol deviation (YES/NO)", id: "PDM" },
//                { description: "PDMELG -- Any major eligibility prot dev (YES/NO)", id: "PDMELG" },
//                { description: "PDMELG1 -- Maj prot dev - not V600 positive", id: "PDMELG1" },
//                { description: "PDMELG2 -- Maj prot dev - not elig disease stage", id: "PDMELG2" },
//                { description: "PDMELG3 -- Maj prot dev - ineligible prior therapy", id: "PDMELG3" },
//                { description: "PDMELG4 -- Maj prot dev - no meas disease", id: "PDMELG4" },
//                { description: "PDMELG5 -- Maj prot dev - ECOG PS >1 (IVRS)", id: "PDMELG5" },
//                { description: "PDMELG6 -- Maj prot dev - no informed consent", id: "PDMELG6" },
//                { description: "PDMONS -- Any major on-study prot dev (YES/NO)", id: "PDMONS" },
//                { description: "PDMONS1 -- Maj prot dev - incorrect treatment", id: "PDMONS1" },
//                { description: "PDMONS2 -- Maj prot dev-nonprot anticancer tx w/oPD", id: "PDMONS2" },
//                { description: "PP -- Per-Protocol population flag", id: "PP" },
//                { description: "PRIL2 -- Previous IL-2", id: "PRIL2" },
//                { description: "PRIMPKFL -- Primary PK Population Flag", id: "PRIMPKFL" },
//                { description: "PRIMTUMR -- Primary Tumor", id: "PRIMTUMR" },
//                { description: "PRIPTREM -- Previous Ipilimumab or Tremelimumab", id: "PRIPTREM" },
//                { description: "PROSTATE -- Metastatic site: Prostate", id: "PROSTATE" },
                { description: "PROTO -- Protocol (in upper case)", id: "PROTO" },
//                { description: "PT -- Patient # PT90 -- Flag for 1st 90 patients", id: "PT" },
//                { description: "RACE -- Race", id: "RACE" },
//                { description: "RACEG -- Race Group (White)", id: "RACEG" },
//                { description: "REGIVR -- Region from IVRS", id: "REGIVR" },
//                { description: "REGLMPND -- Regional Lymph Nodes", id: "REGLMPND" },
//                { description: "REPSTAT -- Female reproductive status", id: "REPSTAT" },
//                { description: "RND -- Randomized treatment", id: "RND" },
//                { description: "RNDDC -- Date of dosing group assignment", id: "RNDDC" },
//                { description: "RNDDT -- Randomization SAS datetime", id: "RNDDT" },
//                { description: "RNDGRP -- Randomized Tx Received by Patient (CRF)", id: "RNDGRP" },
//                { description: "RNDIGLDC -- Global IVRS Randomization Date", id: "RNDIGLDC" },
//                { description: "RNDIGLDT -- Global IVRS Randomization SAS Date", id: "RNDIGLDT" },
//                { description: "RNDIGLTC -- Global IVRS Randomization Time", id: "RNDIGLTC" },
//                { description: "RNDIVR -- Randomized treatment Arm from IVRS(A)", id: "RNDIVR" },
//                { description: "RNDIVRDC -- Local IVRS Randomization Date", id: "RNDIVRDC" },
//                { description: "RNDIVRDT -- Local IVRS Randomization SAS Date", id: "RNDIVRDT" },
//                { description: "RNDIVRGR -- Randomized treatment group from IVRS", id: "RNDIVRGR" },
//                { description: "RNDIVRN -- Randomized treatment Arm from IVRS(0)", id: "RNDIVRN" },
//                { description: "RNDIVRTC -- Randomization time", id: "RNDIVRTC" },
//                { description: "RNDLCLDC -- Date of Randomization", id: "RNDLCLDC" },
//                { description: "RNDLCLTC -- Time of Randomization", id: "RNDLCLTC" },
//                { description: "RNDYN -- Was the patient randomized", id: "RNDYN" },
//                { description: "SAFETY -- SAFETY population flag", id: "SAFETY" },
//                { description: "SCRNUM -- Screening Number", id: "SCRNUM" },
//                { description: "SECPKFL -- Secondary PK Population Flag", id: "SECPKFL" },
//                { description: "SEX -- Sex", id: "SEX" },
//                { description: "SEXTRT -- Sex and Treatment Group", id: "SEXTRT" },
//                { description: "SKIN -- Metastatic site: Skin", id: "SKIN" },
//                { description: "STAGE -- Stage (Primary)", id: "STAGE" },
//                { description: "STAGFL -- M-Stage Flag", id: "STAGFL" },
//                { description: "SUBJID -- Subject ID within protocol", id: "SUBJID" },
//                { description: "SUBJINIT -- Subject initials", id: "SUBJINIT" },
//                { description: "SUBJSTAT -- Subject status", id: "SUBJSTAT" },
//                { description: "S_PROTO -- Source protocol from which data derived", id: "S_PROTO" },
//                { description: "TARSLDBL -- Sum of diameters of BL target lesions", id: "TARSLDBL" },
//                { description: "TIMMTDGF -- Time since metast. diagn. LT 6 months", id: "TIMMTDGF" },
//                { description: "TIMMTDGM -- Time since metastatic diagnosis(months)", id: "TIMMTDGM" },
//                { description: "TIMMTDIG -- Time since metastatic diagnosis(days)", id: "TIMMTDIG" },
//                { description: "TMOPBIDC -- Date of consent to Tumor Biopsy", id: "TMOPBIDC" },
//                { description: "TMRCNSDC -- Date of consent to Tumor Biopsy", id: "TMRCNSDC" },
                { description: "TRT1 -- First trial medication", id: "TRT1" },
                { description: "TRT1DC -- First trial medication begin date", id: "TRT1DC" },
                { description: "TRT1DCO -- Original values for TRT1DC", id: "TRT1DCO" },
                { description: "TRT1DS -- SAS date of the first treatment", id: "TRT1DS" },
                { description: "TRT1DT -- First trial med. begin SAS datetime", id: "TRT1DT" },
                { description: "TRT1DTO -- Original values for TRT1DT", id: "TRT1DTO" },
                { description: "TRT1GRP -- First trial medication group", id: "TRT1GRP" },
                { description: "TRT1TC -- First trial medication begin time", id: "TRT1TC" },
                { description: "TRT1TCO -- Original values for TRT1TC", id: "TRT1TCO" },
                { description: "TUMORCNS -- Did Patient consent to Tumor Biopsy", id: "TUMORCNS" },
                { description: "USUBJID -- Unique subject ID within submission ", id: "USUBJID" },
                { description: "V600E -- BRAF V600E-positive population ", id: "V600E" },
                { description: "V600ETRT -- V600E Mutation and Treatment Group", id: "V600ETRT" },
                { description: "WEIGHTBL -- BL Weight in kg", id: "WEIGHTBL" },
                { description: "WITHSCC -- With SCC flag", id: "WITHSCC" }
            ],
            view: ko.observable(),
            config: ko.observable({})
        });
        self.files.push({ id: "ae", name: "ae.xpt", type: "adverseEvents", variables: [], view: ko.observable(), config: ko.observable({}) });
        self.files.push({ id: "exp", name: "exp.xpt", type: "exposure", variables: [], view: ko.observable(), config: ko.observable({}) });

        // Get an instance of the child view
        system.acquire('viewmodels/modules/dataInput/' + self.files()[0].type).then(function (viewModule)
        {
            self.files()[0].view(new viewModule(self.files()[0]));
        });
        
        // Active file
        self.activeFile = ko.observable();
        self.activeOrFirstFile = ko.computed(function ()
        {
            // If there already is an active file, return it
            if (self.activeFile() != undefined)
                return self.activeFile();
            // Otherwise return the first project, if any
            else
            {
                if (self.files().length > 0)
                    return self.files()[0].id;
                else return undefined;
            }
        });

        // Change the currently Active workflow
        self.activateFile = function (file)
        {
            self.activeFile(file.id);
        };

    };

    dataInput.prototype.viewAttached = function ()
    {
    };

    return dataInput;
});