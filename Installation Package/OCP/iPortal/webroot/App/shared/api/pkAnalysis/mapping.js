define('shared/api/pkAnalysis/mapping', [
    'knockout',
    'ocpkmlib/txt',
    'ocpkmlib/net'
],
function (ko, txt, net) {

    var self = {};

    // Run the script to get the variable mappings 
    // for PK analysis for an NDA stored in the server
    self.get = function (data) {
        self.studyProfiles = {};
        self.SubmissionId = data.NDAName;
        self.ProfileName = data.ProfileName;
        self.mappingErrorCallback = data.mappingErrorCallback;
        self.mappingInvalidResponseCallback = data.mappingInvalidResponseCallback;
        self.mappingEmptyResponseCallback = data.mappingEmptyResponseCallback;
        self.mappingAbortedCallback = data.mappingAbortedCallback;
        self.mappingUpdateCallback = data.mappingUpdateCallback;
        self.mappingSuccessCallback = data.mappingSuccessCallback;

        // retrieve the studies in this submission
        self.getListOfStudies()
            .done(function (studies) {
                // retrieve data for each study
                var priorStudyPromise = null;
                $.each(studies, function (i, study) {
                    if (priorStudyPromise != null) {
                        priorStudyPromise = priorStudyPromise
                            .then(function () {
                                return self.getStudyMappings(study)
                            });
                    }
                    else priorStudyPromise = self.getStudyMappings(study);
                });

                // resolve when all studies are done
                if (priorStudyPromise != null) priorStudyPromise
                    .then(function () { self.mappingSuccessCallback(self.studyProfiles) });
            })
            .fail(self.mappingErrorCallback);  
    };

    // Request the list of studies in this submission
    self.getListOfStudies = function () {
        return net.ajax({ url: "api/pkview/submissions/" + self.SubmissionId + "/studies" });
    };

    // Retrieve mappings for a single study
    self.getStudyMappings = function (study) {
        
        var dfd = $.Deferred();

        // Attempt to load saved mappings
        self.loadStudyMappings(study)
            .done(function (studyProfile) {
                // If found, store and resolve this function
                if (studyProfile != null) {
                    self.copyToOutput(studyProfile);
                    dfd.resolve();
                } // If not found, compute the mappings
                else {
                    self.initializeStudyMappings(study)
                        .done(function (jobId) {
                            self.timer = setTimeout(function () { 
                                self.getInitializationResult(study, jobId)
                                    .done(function (studyProfile) {
                                        self.copyToOutput(studyProfile);
                                        dfd.resolve();
                                    })
                                    .fail(self.mappingErrorCallback);
                            }, 1000);
                        })
                        .fail(self.mappingErrorCallback);
                }
            })
            .fail(self.mappingErrorCallback);

        
        return dfd.promise(); 
    };

    // Attempt to load saved mappings for the current study
    self.loadStudyMappings = function (study) {
        // If profile name is empty return a resolved promise
        return (txt.isNullOrEmpty(self.ProfileName)) ? $.when() :
            net.ajax({
                url: "api/pkview/submissions/" + self.SubmissionId
                    + "/profiles/" + self.ProfileName
                    + "/supplements/" + study.SerialNumber
                    + "/studies/" + study.StudyId
            });
    };

    // Copy a study profile to the output structure
    self.copyToOutput = function(studyProfile)
    {
        var supplementNumber = studyProfile.SupplementNumber;
        if (typeof (self.studyProfiles[supplementNumber]) == "undefined")
            self.studyProfiles[supplementNumber] = [];
        self.studyProfiles[supplementNumber].push(studyProfile);
    }

    // Request the initialization of mappings for the current study
    self.initializeStudyMappings = function (study) {   
        return net.ajax({
            url: "api/pkview/submissions/" + self.SubmissionId
                + "/supplements/" + study.SerialNumber
                + "/studies/" + study.StudyId
                + "/initialize"
        });
    };

    // Auxiliary function to poll the server for script results
    self.getInitializationResult = function (study, jobId) {

        var dfd = $.Deferred();

        // ajax call to run the sas code that reads the variable mappings
        net.ajax({
            url: "api/pkview/submissions/"  + self.SubmissionId
                + "/supplements/" + study.SerialNumber
                + "/studies/" + study.StudyId
                + "/initialization/result"
                + "?jobId=" + jobId
        }).done(function (response) {
            switch (response.Status) {
                case 0: // Undefined
                    self.mappingInvalidResponseCallback();
                    return;
                case 1: // Running: update progress and reset callback
                    // If feedback is null there is a great chance 
                    // that something went wrong in the server, run error callback
                    if (response.FeedbackMessage == null) {
                        self.mappingEmptyResponseCallback();
                        return;
                    }
                    self.mappingUpdateCallback(response);
                    self.timer = setTimeout(function () {
                        self.getInitializationResult(study, jobId)
                            .done(function (studyProfile) {
                                dfd.resolve(studyProfile);
                            })
                            .fail(self.mappingErrorCallback);
                    }, 1000);
                    return;
                case 2: // Done: Resolve the call and return the study data
                    dfd.resolve(response.Data);
                    return;
                case 3: // Aborted: We inform the user that the process has been aborted
                    self.mappingAbortedCallback(response);
                    return;
            }
        }).fail(self.mappingErrorCallback);

        return dfd.promise();
    };

    // Save user mappings
    self.save = function (data) {
        net.ajax({
            url: "/api/pkview/saveMappings?ProjectName=" + data.ProfileName,
            data: ko.toJSON(data.revisedMappings),
            type: "POST",
            successCallback: data.successCallback,
            errorCallback: data.errorCallback
        });
    };

    // Get the study design
    self.getStudyDesign = function (study) {
        return net.post("/api/pkview/determineStudyDesign", ko.toJSON(study));
    };

    // Get the reference treatment or group
    self.getReference = function (study) {
        return net.post("/api/pkview/getReference", ko.toJSON(study));
    };

    // Study Design Types
    self.studyDesignTypes =
    [
        { Type: 0, Name: "" },
        { Type: 1, Name: "Unknown" },
        { Type: 2, Name: "Sequential" },
        { Type: 3, Name: "Parallel" },
        { Type: 4, Name: "Crossover" }
    ];

    // Study Types
    self.studyTypes =
    [
        { Type: 1, Name: "Intrinsic", Abbreviation: "INT" },
        { Type: 2, Name: "Extrinsic", Abbreviation: "EX" },
        { Type: 3, Name: "Biopharmaceutics-Food Effect", Abbreviation: "BFE" },
        { Type: 4, Name: "Renal Impairment", Abbreviation: "RI" },
        { Type: 5, Name: "Hepatic Impairment", Abbreviation: "HI" },
        { Type: 6, Name: "popPK", Abbreviation: "PPK" },
        { Type: 7, Name: "Genomics", Abbreviation: "GEN" },
        { Type: 8, Name: "Biopharmaceutics-Absolute Bioavailability", Abbreviation: "BAB" },
        { Type: 9, Name: "Drug-Drug Interactions", Abbreviation: "DDI" }
    ];

    // Domain descriptions
    self.domainDescriptions =
    {
        DM: "Demographics",
        PC: "Concentration",
        PP: "PK Parameters",
        EX: "Exposure",
        SUPPDM: "Demographics (Supplemental Qualifiers)",
        SC: "Subject Characteristics",
        //LB: "LAB DATA"
    };

    // STDM Variable descriptions and importance
    // Importance specification:
    // * 0: Variable is mandatory.
    // * 1: Variable is optional.
    // * {DM: 0, PC: ...} : Specifies importance independently for each domain.
    // * Function(domain): custom importance specification
    self.sdtmVariables =
    {
        USUBJID: {
            description: "Subject Id",
            longDescription: "Unique Subject Id: Identifier used to uniquely identify a " +
                "subject across all studies for all applications or " +
                "submissions involving the product.",
            importance: 0
        },
        ARM: {
            description: "Arm",
            longDescription: "Planned Arm: Name of the Arm to which the subject was assigned.",
            importance: 0
        },
        AGE: {
            description: "Age",
            longDescription: "Age: Age expressed in AGEU.",
            importance: 1 // Optional because its not used by the tool right now
        },                
        SEX: {
            description: "Sex",
            longDescription: "Sex: Sex of the subject.",
            importance: 1 // Optional because its not used by the tool right now
        },                
        RACE: {
            description: "Race",
            longDescription: "Race: Race of the subject.",
            importance: 1 // Optional because its not used by the tool right now
        },         
        COUNTRY: {
            description: "Country",
            longDescription: "Country: Country of the investigational site at which the " +
                "subject participated in the trial in ISO 3166 three-character format.",
            importance: 1 // Optional because its not used by the tool right now
        },
        ETHNIC: {
            description: "Ethnicity",
            longDescription: "Ethnicity: The ethnicity of the subject.",
            importance: 1 // Optional because its not used by the tool right now
        },
        EXTRT: {
            description: "Treatment",
            longDescription: "The topic for the intervention observation, usually the " +
                "verbatim name of the treatment, drug, medicine, or therapy given " +
                "during the dosing interval for the observation.",
            importance: 1 // Optional because EX will be dropped if not mapped
        },                     
        EXSTDTC: {
            description: "Date",
            longDescription: "Start Date/Time of Observation: Start date/time of an " +
                "observation represented in IS0 8601 character format.",
            importance: 1 // Optional because EX will be dropped if not mapped
        },           
        VISIT: {
            description: "Visit",
            longDescription: "Visit Name: Protocol-defined description of clinical " +
                "encounter or description of unplanned visit. May be used in addition " +
                "to VISITNUM and/or VISITDY as a text description of the clinical encounter..",
            importance: {
                EX: 1, // Optional because EX will be dropped if not mapped
                PP: function (domain, progress, callback) { // Optional if only one sample per subject
                    // ajax call to run the sas code that reads the data file
                    var filepath = domain.FileId;
                    oldProgress = progress.feedback();
                    progress.feedback("Determining if PP Visit is optional");
                    net.ajax({
                        url: "/api/readxpt/",
                        type: "POST",
                        data: JSON.stringify(filepath),
                        successCallback: function (dataTable) {
                            var optional = dataTable.length > 0 &&
                                dataTable[0].USUBJID &&
                                dataTable[0].PPTESTCD &&
                                ($.grep(dataTable.slice(1), function (item) {
                                    return item.USUBJID == dataTable[0].USUBJID &&
                                        item.PPTESTCD == dataTable[0].PPTESTCD;
                                }).length == 0);
                            progress.feedback(oldProgress);
                            callback(optional);
                        }
                    });
                }, def: 0
            }
        },
        PCTEST: {
            //code changed to rename description of PCTEST from 'Test' to 'Analyte'
            // changed on 08/03/2017
            description: "Analyte",
            longDescription: "Name of Measurement, Test or Examination. " +
                "Examples: Platelet, Systolic Blood " +
                "Pressure, Summary (Min) RR Duration, Eye Examination.",
            importance: 0
        },
        PCSTRESN: {
            description: "Result",
            longDescription: "Numeric Result/Finding in Standard Units: Used " +
                "for continuous or numeric results or findings in standard " +
                "format; copied in numeric format from PCSTRESC. PCSTRESN " +
                "should store all numeric test results or findings.",
            importance: 0
        },
        PCTPTNUM: {
            description: "Planned Tp.",
            longDescription: "Planned Time Point Number: Numeric version of " +
                "time when a measurement or observation should be taken as " +
                "defined in the protocol. This may be represented as an " +
                "elapsed time relative to a fixed reference point, such " +
                "as time of last dose.",
            importance: 0
        },
        PPCAT: {
            //code changed to rename description of PPCAT from 'Test' to 'Analyte'
            // changed on 08/03/2017
            description: "Analyte",
            longDescription: "Category: Used to define a category of topic-variable values.",
            importance: 0
        },
        PPSTRESN: {
            description: "Result",
            longDescription: "Numeric Result/Finding in Standard Units: Used " +
                "for continuous or numeric results or findings in standard " +
                "format; copied in numeric format from PPSTRESC. PPSTRESN " +
                "should store all numeric test results or findings.",
            importance: 0
        },
        PPTESTCD: {
            //code changed to rename description of PPTESTCD from 'Test' to 'Parameter'
            // changed on 08/03/2017
            description: "Parameter",
            longDescription: "Name of Measurement, Test or Examination. " +
                "Examples: Platelet, Systolic Blood " +
                "Pressure, Summary (Min) RR Duration, Eye Examination.",
            importance: 0
        }
    };

    // Returns true if the variable is optional for the specific domain
    /* FIXME: old and bad implementation of promise, switch to $.deferred */
    var pDomain;
    var pProgress;
    var pVariable;
    var promise = {
        then: function (callback) {

            var importance = self.sdtmVariables[pVariable.SdtmVariable].importance;

            // Importance as number or function
            if (typeof importance === 'number')
                callback(importance == 1);
            else
            {
                // Per domain importance
                if (typeof importance.def != 'undefined')
                    importance = importance[pDomain.Type] || importance['def'];

                // Importance as number or function
                if (typeof importance==='number')
                    callback(importance == 1);
                else {
                    importance(pDomain, pProgress, callback);
                }               
            }
        }
    };

    self.isOptionalVariable = function (domain, progress, variable) {
        pDomain = domain;
        pProgress = progress;
        pVariable = variable;
        return promise;
    };

    // Module interface
    var mapping = {

        // Lists
        studyDesignTypes: self.studyDesignTypes,
        studyTypes: self.studyTypes,
        domainDescriptions: self.domainDescriptions,
        sdtmVariables: self.sdtmVariables,

        // Api functions
        get: self.get,
        save: self.save,
        getStudyDesign: self.getStudyDesign,
        getReference: self.getReference,
        isOptionalVariable: self.isOptionalVariable
    };

    return mapping;
});