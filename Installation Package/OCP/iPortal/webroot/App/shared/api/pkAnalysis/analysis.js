define('shared/api/pkAnalysis/analysis', [
    'knockout',
    'durandal/system',
    'ocpkmlib/net',
    'durandal/app',
],
function (ko, system, net, app) {

    var self = {};

    // Run the PK analysis script for a single study stored in the server
    self.runStudy = function (data) {
        self.revisedMappings = data.revisedMappings;
        self.invalidInputCallback = data.invalidInputCallback;
        self.analysisErrorCallback = function (response) {
            system.log("Study " + self.revisedMappings.StudyCode + " failed: " +
                (response.responseText || "SAS Error, see server log for details."));
            data.analysisErrorCallback;
        };
        self.analysisInvalidResponseCallback = data.analysisInvalidResponseCallback;
        self.analysisAbortedCallback = data.analysisAbortedCallback;
        self.analysisUpdateCallback = data.analysisUpdateCallback;
        self.analysisSuccessCallback = data.analysisSuccessCallback;
        self.doRunStudy();
    };

    // Auxiliary function to start the script
    self.doRunStudy = function () {

        // If input data is invalid run the invalidInput callback instead of running the analysis
        if (self.revisedMappings.QualityCount == null ||
            ko.unwrap(self.revisedMappings.QualityCount).unmapped > 0 ||
            self.revisedMappings.Cohorts == null ||
            self.revisedMappings.Cohorts().length == 0)
        {
            self.invalidInputCallback();
            return;
        }

        // run the analysis
        net.ajax({
            url: "/api/pkview/analysis/run",
            data: ko.toJSON(self.revisedMappings),
            type: "POST",
            successCallback: function (jobId) {
                self.timer = setTimeout(function () { self.checkForResults(jobId); }, 1000);
            },
            errorCallback: function (response) {
                // make sure we dont keep an old list of analytes/parameters
                self.revisedMappings.Concentration = null;
                self.revisedMappings.Pharmacokinetics = null;
                self.analysisErrorCallback(response);
            }
        });
    };

    // Auxiliary function to poll the server for script results
    self.checkForResults = function (jobId) {
        net.ajax({
            url: "/api/pkview/analysis/tryGet",
            data: { jobId: jobId },
            successCallback: function (response) {
                switch (response.Status) {
                    case 0: // Undefined
                        // make sure we dont keep an old list of analytes/parameters
                        self.revisedMappings.Concentration = null;
                        self.revisedMappings.Pharmacokinetics = null;
                        self.analysisInvalidResponseCallback();
                        return;
                    case 1: // Running: update progress and reset callback 
                        // Do not run update function if feedback message comes empty
                        if (response.FeedbackMessage != null && $.trim(response.FeedbackMessage).length > 0);
                            self.analysisUpdateCallback(response);
                        self.timer = setTimeout(function () { self.checkForResults(jobId); }, 1000);
                        return;
                    case 2: // Done: Continue to the next step
                        // Retrieve list of Analytes and Parameters
                        if (response.Data != null) {
                            self.revisedMappings.Concentration = response.Data.Concentration;
                            self.revisedMappings.Pharmacokinetics = response.Data.Pharmacokinetics;
                        }
                        self.analysisSuccessCallback(response.Data);
                        return;
                    case 3: // Aborted: We inform the user that the process has been aborted
                        // make sure we dont keep an old list of analytes/parameters
                        self.revisedMappings.Concentration = null;
                        self.revisedMappings.Pharmacokinetics = null;
                        self.analysisAbortedCallback(response);
                        return;
                }
            },
            errorCallback: function (response) {
                // make sure we dont keep an old list of analytes/parameters
                self.revisedMappings.Concentration = null;
                self.revisedMappings.Pharmacokinetics = null;
                self.analysisErrorCallback(response);
            }
        });
    };

    // Skip the current study on analysis error
    self.analysisError = function (response, callback) {
        self.results.failedStudies.push(self.revisedMappings);
        if (self.abortOnStudyError) callback(response);
        else {
            self.studyAnalysisFinishedCallback({
                FeedbackMessage: "Study " + self.revisedMappings.StudyCode + " caused a runtime error. Skipping",
                PercentComplete: Math.floor((self.studyIdx * 90) / self.studies.length),
                results: self.results
            });
            self.doRunNda();
        }
    };

    // Create a zip package for a specific NDA that has been previously analyzed
    self.createPackage = function (data) {
        self.NDAName = data.NDAName;
        self.ProfileName = data.ProfileName;
        self.packageErrorCallback = data.packageErrorCallback;
        self.packageInvalidResponseCallback = data.packageInvalidResponseCallback;
        self.packageAbortedCallback = data.packageAbortedCallback;
        self.packageUpdateCallback = data.packageUpdateCallback;
        self.packageSuccessCallback = data.successCallback;
        self.doCreatePackage();
    };

    self.doCreatePackage = function() {
        // ajax call to run the sas code that reads the variable mappings
        net.ajax({
            url: "/api/pkview/createPackage",
            data: { ndaFolderName: self.NDAName, ProfileName: self.ProfileName },
            successCallback: function (jobId) {
                self.timer = setTimeout(function () { self.waitForPackage(jobId); }, 1000);
            },
            errorCallback: self.packageErrorCallback
        });
    };


    self.createMetaPackage = function (data) {
        self.NDAName = data.NDAName;
        self.ProfileName = data.ProfileName;
        self.activeSupplement = data.activeSupplement;
        self.packageErrorCallback = data.packageErrorCallback;
        self.metacomputingReport = data.metacomputingReport;
        self.packageInvalidResponseCallback = data.packageInvalidResponseCallback;
        self.packageAbortedCallback = data.packageAbortedCallback;
        self.packageUpdateCallback = data.packageUpdateCallback;
        self.packageSuccessCallback = data.successCallback;
        self.docreateMetaPackage();
    };

    self.createVariabilityMetaPackage = function (data) {
        self.NDAName = data.NDAName;
        self.ProfileName = data.ProfileName;
        self.activeSupplement = data.activeSupplement;
        self.packageErrorCallback = data.packageErrorCallback;
        self.metacomputingReport = data.metacomputingReport;
        self.packageInvalidResponseCallback = data.packageInvalidResponseCallback;
        self.packageAbortedCallback = data.packageAbortedCallback;
        self.packageUpdateCallback = data.packageUpdateCallback;
        self.packageSuccessCallback = data.successCallback;
        self.docreateVariabilityMetaPackage();
    };
    self.docreateMetaPackage = function () {
        net.ajax({
            url: "/api/pkview/DownloadMetaReport",
            data: { foldername: "Meta", submission: self.NDAName, project: self.ProfileName, supplement: self.activeSupplement },
            successCallback: function (result) {
                if (result == "yes") {
                    self.metacomputingReport(false);
                    self.downloadMetaPackage(self.NDAName(), self.ProfileName(), self.activeSupplement());
                }
                else {
                    self.metacomputingReport(false);
                    app.showMessage(result, 'PkView', ['OK']);
                }
            },
            errorCallback: function () {
                app.showMessage('An error occurred when Zip Meta analysis report package', 'PkView', ['OK']);
            },
        });

    };

    self.docreateVariabilityMetaPackage = function () {
        net.ajax({
            url: "/api/pkview/DownloadMetaReport",
            data: { foldername: "Metavariability", submission: self.NDAName, project: self.ProfileName, supplement: self.activeSupplement },
            successCallback: function (result) {
                if (result == "yes") {
                    self.metacomputingReport(false);
                    self.downloadVariabilityMetaPackage(self.NDAName(), self.ProfileName(), self.activeSupplement());
                }
                else {
                    self.metacomputingReport(false);
                    app.showMessage(result, 'PkView', ['OK']);
                }
            },
            errorCallback: function () {
                app.showMessage('An error occurred when Zip Variability Meta analysis report package', 'PkView', ['OK']);
            },
        });

    };
    // Create a zip package for current study that has been previously analyzed
    self.createStudyPackage = function (data) {
        self.NDAName = data.NDAName;
        self.activeStudy = data.activeStudy;
        self.activeSupplement = data.activeSupplement;
        self.ProfileName = data.ProfileName;
        self.packageErrorCallback = data.packageErrorCallback;
        self.packageInvalidResponseCallback = data.packageInvalidResponseCallback;
        self.packageAbortedCallback = data.packageAbortedCallback;
        self.packageUpdateCallback = data.packageUpdateCallback;
        self.packageSuccessCallback = data.successCallback;
        self.docreateStudyPackage();
    };

    self.docreateStudyPackage = function () {
        // ajax call to run the sas code that reads the variable mappings
        net.ajax({
            url: "/api/pkview/createStudyPackage",
            data: { ndaFolderName: self.NDAName, ProfileName: self.ProfileName, activeStudy: self.activeStudy, activeSupplement: self.activeSupplement,xxxx:0},
            successCallback: function (jobId) {
                self.timer = setTimeout(function () { self.waitForPackage(jobId); }, 1000);
            },
            errorCallback: self.packageErrorCallback
        });
    };

    self.createCurrentreportPackage = function (data) {
        self.NDAName = data.NDAName;
        self.activeStudy = data.activeStudy;
        self.activeSupplement = data.activeSupplement;
        self.ProfileName = data.ProfileName;
        self.ReportName = data.ReportName;
        self.downloadingReport = data.downloadingReport;
        self.packageErrorCallback = data.packageErrorCallback;
        self.packageInvalidResponseCallback = data.packageInvalidResponseCallback;
        self.packageAbortedCallback = data.packageAbortedCallback;
        self.packageUpdateCallback = data.packageUpdateCallback;
        self.packageSuccessCallback = data.successCallback;
        //self.deletereportpackage();
        self.docreateCurrentreportPackage();
    };
    //self.deletereportpackage() = function () {
    //    net.ajax({
    //        url: "/api/pkview/DeleteReportPackage",
    //        data: { project: self.ProfileName, submission: self.NDAName, supplement: self.activeSupplement, study: self.activeStudy, report: self.ReportName },
    //        successCallback: function () { },
    //        errorCallback: function () {
    //            app.showMessage('An error occurred when delete the old zip package', 'PkView', ['OK']);
    //        },
    //    });
    //};


    self.docreateCurrentreportPackage = function () {
        net.ajax({
            url: "/api/pkview/DownloadReport",
            data: { project: self.ProfileName, submission: self.NDAName, supplement: self.activeSupplement, study: self.activeStudy, report: self.ReportName },
            successCallback: function (result) {
                //if (result == "yes") app.showMessage('An error occurred', 'PkView', ['OK']);
                if (result == "yes")
                    {
                    self.downloadingReport(false);
                    self.downloadCurrentreportPackage(self.NDAName(), self.ProfileName(), self.activeStudy(), self.activeSupplement(), self.ReportName);
                    }
                else {
                    self.downloadingReport(false);
                    app.showMessage(result, 'PkView', ['OK']);
                }
                  },
            errorCallback: function () {
                app.showMessage('An error occurred when Zip current report package', 'PkView', ['OK']);
                },
        });
    };

    self.waitForPackage = function (jobId) {
        // ajax call to run the sas code that reads the variable mappings
        net.ajax({
            url: "/api/pkview/waitForPackage",
            data: { jobId: jobId },
            successCallback: function (response) {
                switch (response.Status) {
                    case 0: // Undefined
                        self.packageInvalidResponseCallback();
                        return;
                    case 1: // Running: update progress and reset callback
                        self.packageUpdateCallback(response);
                        self.timer = setTimeout(function () { self.waitForPackage(jobId); }, 1000);
                        return;
                    case 2: // Done: Continue to the next step
                        self.packageSuccessCallback(response);
                        return;
                    case 3: // Aborted: We inform the user that the process has been aborted
                        self.packageAbortedCallback(response);
                        return;
                }
            },
            errorCallback: self.packageErrorCallback
        });
    };

    // Download a results package
    self.downloadPackage = function (NDAName, ProfileName) {
        if (ProfileName == null) ProfileName = "";
        net.download("/api/download/PkView/" + NDAName + ".zip?subfolder=" + ProfileName);
    };

    self.downloadMetaPackage = function (NDAName, ProfileName, activeSupplement) {
        if (ProfileName == null) ProfileName = "";
        //net.download("/api/download/PkView/" + NDAName + "Meta" + ".png?subfolder=" + ProfileName + "/" + NDAName + "/" + activeSupplement + "/" + "Meta" + "/");
        net.download("/api/download/PkView/"  + "Meta" + ".zip?subfolder=" + ProfileName + "/" + NDAName + "/" + activeSupplement + "/");

    };

    self.downloadVariabilityMetaPackage = function (NDAName, ProfileName, activeSupplement) {
        if (ProfileName == null) ProfileName = "";
        //net.download("/api/download/PkView/" + NDAName + "Meta" + ".png?subfolder=" + ProfileName + "/" + NDAName + "/" + activeSupplement + "/" + "Meta" + "/");
        net.download("/api/download/PkView/" + "Metavariability" + ".zip?subfolder=" + ProfileName + "/" + NDAName + "/" + activeSupplement + "/");

    };



    self.downloadCurrentreportPackage = function (NDAName, ProfileName, activeStudy, activeSupplement, ReportName) {
        if (ProfileName == null) ProfileName = "";
        //net.download("/api/download/PkView/" + NDAName + "Meta" + ".png?subfolder=" + ProfileName + "/" + NDAName + "/" + activeSupplement + "/" + "Meta" + "/");
        net.download("/api/download/PkView/" + ReportName + ".zip?subfolder=" + ProfileName + "/" + NDAName + "/" + activeSupplement + "/" + activeStudy + "/");

    };

    // Download a study package

    self.downloadStudyPackage = function (NDAName, ProfileName, activeStudy, activeSupplement) {
        if (ProfileName == null) ProfileName = "";
        net.download("/api/download/PkView/" + activeStudy + ".zip?subfolder=" + ProfileName + "/" + NDAName + "/" + activeSupplement + "/");
    };

    // List of available statistical methods
    self.statisticalMethods = [
        { text: "Paired", value: "paired" },
        { text: "Unpaired", value: "unpaired" }
    ];

    // Module interface
    var analysis = {

        // Lists
        statisticalMethods: self.statisticalMethods,

        // Api functions
        runStudy: self.runStudy,
        createPackage: self.createPackage,
        createStudyPackage: self.createStudyPackage,
        downloadPackage: self.downloadPackage,
        downloadStudyPackage: self.downloadStudyPackage,
        createMetaPackage: self.createMetaPackage,
        downloadMetaPackage: self.downloadMetaPackage,
        downloadCurrentreportPackage: self.downloadCurrentreportPackage,
        createCurrentreportPackage: self.createCurrentreportPackage,
        createVariabilityMetaPackage: self.createVariabilityMetaPackage,
        downloadVariabilityMetaPackage: self.downloadVariabilityMetaPackage,

    };

    return analysis;
});