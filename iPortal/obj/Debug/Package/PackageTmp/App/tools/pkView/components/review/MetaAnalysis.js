define('tools/pkView/components/review/MetaAnalysis', [
        'knockout',
        'koSelectize',
        'shared/components/dataDialog/viewmodels/dataDialog',
        'shared/components/errorDialog/viewmodels/errorDialog',
        'ocpkmlib/net',
        'ocpkmlib/txt',
        'durandal/app',
        'plugins/dialog',
        'shared/components/modal/viewmodels/modal',
        'shared/api/pkAnalysis/mapping',
        'tools/pkView/lib/pkViewSubmissionProfile',
        'shared/api/pkAnalysis/analysis',
        'tools/pkView/lib/pkViewAnalysis',
        'tools/pkView/lib/pkViewProjects'],
function (ko, koSelectize, dataDialog, errorDialog, net, txt, app, dialog, modal, mapping, profile, analysis, pkViewAnalysis, pkViewProjects) {

    // This is the mainWindow viewmodel prototype
    var ctor = function () {
        var self = this;

        self.studies = ko.observableArray([]); // how many were selected to run
        self.unselected = ko.observableArray([]); // how many were not selected to run
        self.unmappable = ko.observableArray([]); // how many had missing files
        self.selectedStudies = ko.observableArray([]); // selected studies
        self.unRunnableStudies = ko.observableArray([]); // From studies: how many had invalid mappings
        self.failedStudies = ko.observableArray([]); // From studies: how many failed
        self.successStudies = ko.observableArray([]); // From studies: how many succeeded
        self.activeStudy = ko.observable(""); // Currently visible study settings (if applicable)
        self.activeSupplement = ko.observable(""); // Supplement number of the currently active study
        self.activeReportId = ko.observable(null); // Currently visible report settings Id
        self.orderStudies = ko.observableArray([]);
        self.uiMode = ko.observable("summary"); // user interface mode       
        self.computingReport = ko.observable(false); // Flag to indicate we are currently generating a report
        self.downloading = ko.observable(false); // Flag to indicate we are downloading the results package
        self.downloadingStudy = ko.observable(false); // Flag to indicate we are downloading the study package
        self.selectedStudies1 = ko.observableArray([]);
        self.metaformat = ko.observableArray([]);
        self.excludeReport = ko.observable(false); // Flag to indicate we are currently exclude a report   
        self.metareportGenerated = ko.observable(true);
        self.metacomputingReport = ko.observable(false);
        self.columns = [];
        self.excludedatatable = ko.observableArray([]);
        self.excludedatatable1 = ko.observableArray([]);

        // Update interface progress callback
        self.updateProgress = function (response) {
            self.splash.feedback(response.FeedbackMessage);
            self.splash.progress(response.PercentComplete);

            if (response.results != null) {
                self.successStudies(response.results.successStudies);
                self.failedStudies(response.results.failedStudies);
                self.unRunnableStudies(response.results.unRunnableStudies);
            }
        };

        // Select the supplement(s) we want to work on
        self.selectSupplement = function (supplementNumber) {
            self.SelectedSupplement(supplementNumber);

            // Set the first study as active
            if (self.studies().length > 0) {
                self.activeStudy(self.studies()[0].StudyCode);
                self.activeSupplement(self.studies()[0].SupplementNumber);
            }
        };

        // Download the Study package
        self.downloadStudyPackage = function () {

            // Do nothing if download function is already in progress
            if (self.downloadingStudy()) return false;

            self.downloadingStudy(true);

            // Create and download results package
            analysis.createStudyPackage({
                NDAName: self.NDAName,
                activeStudy: self.activeStudy,
                activeSupplement: self.activeSupplement,
                ProfileName: self.ProfileName,
                packageErrorCallback: function () { self.downloadingStudy(false); },
                packageInvalidResponseCallback: function () { self.downloadingStudy(false); },
                packageAbortedCallback: function () { self.downloadingStudy(false); },
                packageUpdateCallback: function () { },
                successCallback: function () {
                    self.downloadingStudy(false);
                    analysis.downloadStudyPackage(self.NDAName(), self.ProfileName(), self.activeStudy(), self.activeSupplement());
                }
            });
        };

        // Create a new report
        self.createForestPlotReport = function () {
            var newReportDialog = new modal({
                title: "New Forest Plot",
                model: "tools/pkView/components/report/newReport/newForestPlotReport",
                activationData: {
                    studies: self.validStudies,
                    supplements: self.supplements,
                    selectedSupplement: self.SelectedSupplement(),
                    defaultSupplement: self.activeSupplement(),
                    defaultStudy: self.activeStudy(),
                    done: function (newForestPlotReport) {
                        newReportDialog.close();
                        self.activeStudy(newForestPlotReport.study.StudyCode);
                        self.activeSupplement(newForestPlotReport.study.SupplementNumber);
                        self.activeReportId(newForestPlotReport.reportId);
                    }
                },
                width: 0.6
            });
            dialog.show(newReportDialog);
        };

        // Generate the statistical table/s
        self.generateReport = function () {

            var dfd = $.Deferred();

            // DO nothing if we are already computing
            if (self.computingReport()) {
                dfd.resolve(false);
                return dfd;
            }

            // get currently visible report
            var report = self.study().Reports()[self.activeReportId()];

            // Report exists flag, computing report flag
            report.Generated(false);
            self.computingReport(true);

            // Ajax request to generate report
            net.ajax({
                url: "/api/pkview/generateReport?reportId=" + self.activeReportId(),
                data: ko.toJSON(self.study()),
                type: "POST",
                successCallback: function (date) {
                    if (date == null) {
                        self.computingReport(false);
                        app.showMessage('An error occurred', 'PkView', ['OK']);
                        dfd.resolve(false);
                        return;
                    }

                    report.CreationDate(new Date(date));
                    report.Generated(true);
                    self.computingReport(false);
                    dfd.resolve(true);
                },
                errorCallback: function () {
                    self.computingReport(false);
                    app.showMessage('An error occurred', 'PkView', ['OK']);
                    dfd.resolve(false);
                }
            });

            return dfd;
        };

        self.generateMetaAnalysis = function () {

            var dfd = $.Deferred();
            self.metareportGenerated(false);
            self.metacomputingReport(true);

            self.selectedStudies1().splice(0, self.selectedStudies1().length);

             for (i = 0 ; i < self.selectedStudies().length; i++)
            {
                 for (j = 0 ; j < self.analyzableStudies().length; j++)
                 {
                     
                     if (self.selectedStudies()[i] == self.analyzableStudies()[j].StudyCode && self.analyzableStudies()[j].Reports().length > 0)
                     {
                         
                             self.selectedStudies1.push(self.analyzableStudies()[j]);
                     }
                }
             }

             if (self.selectedStudies1().length == 0){
                 app.showMessage("You must select studies order after click Generate Meta Analysis", 'PkView', ['OK']);
                 self.metareportGenerated(true);
                 self.metacomputingReport(false);
                 return;
             }

             if (self.selectedStudies1().length != 0) {
                 for (i = 0; i < self.selectedStudies1().length;i++){
                 self.selectedStudies1()[i].plotAnalysis = self.metaformat().plotAnalysis;
                 self.selectedStudies1()[i].AnalysisMethod = self.metaformat().AnalysisMethod;
                 self.selectedStudies1()[i].upperbound = self.metaformat().upperbound;
                 self.selectedStudies1()[i].lowerbound = self.metaformat().lowerbound;
             }
             }



            net.ajax({
                url: "/api/pkview/generateMetaAnalysis?reportId=" + "0",
                data: ko.toJSON(self.selectedStudies1),

                type: "POST",
                successCallback: function (date) {
                    if (date == null) {
                        //self.computingReport(false);
                        app.showMessage('An error occurred', 'PkView', ['OK']);
                        dfd.resolve(false);
                        return;
                    }
                    app.showMessage('Meta analysis finished', 'PkView', ['OK']);

                    //report.CreationDate(new Date(date));
                    self.metareportGenerated(true);
                    self.metacomputingReport(false);
                    //self.computingReport(false);
                    dfd.resolve(true);
                },
                errorCallback: function () {
                    //self.computingReport(false);
                    app.showMessage('An error occurred', 'PkView', ['OK']);
                    dfd.resolve(false);
                }
            });
            return dfd;
        };

        // Edit the list of treatments/groups manually
        self.setMetaFormat = function (study, data) {

            var dfd = $.Deferred();

 

            var setMetaFormatDialog = new modal({
                title: "Set Meta Analysis Report Format",
                model: "tools/pkview/components/review/sections/metaFormat",
                activationData: {
                    study: study,
                    data: data
                    
                },
                width: 0.9
            });
            dialog.show(setMetaFormatDialog)
                .then(function (result) {
                    if (result) {
                        if (result.startMetaanalysis) {
                            self.generateMetaAnalysis();
                        } else return;
                    }
                    dfd.resolve();
                    
                });

            return dfd;

        };

        // Generate and download a report
        self.downloadMetaPackage = function () {

            // Do nothing if download function is already in progress
            if (self.metacomputingReport()) return false;
            self.metacomputingReport(true);
            // Create and download results package
            analysis.createMetaPackage({
                NDAName: self.NDAName,
                activeSupplement: self.activeSupplement,
                ProfileName: self.ProfileName,
                metacomputingReport:self.metacomputingReport,
                packageErrorCallback: function () { self.metacomputingReport(false); },
                packageInvalidResponseCallback: function () { self.metacomputingReport(false); },
                packageAbortedCallback: function () { self.metacomputingReport(false); },
                packageUpdateCallback: function () { },
                successCallback: function () {
                    self.metacomputingReport(false);
                    //analysis.downloadCurrentreportPackage(self.NDAName(), self.ProfileName(), self.activeStudy(), self.activeSupplement(), self.study().Reports()[self.activeReportId()].Name);
                }
            });
        };

        // Ask for confirmation and delete the report
        self.deleteReport = function () {
            app.showMessage('Are you sure you want to delete the current report? ' +
                'This action cannot be undone.', 'PkView', ['Yes', 'No'])
                .then(function (answer) { if (answer == 'Yes') self.reallyDeleteReport(); });
        };

        // Delete the report
        self.reallyDeleteReport = function () {

            // get currently visible study
            var study = self.study();

            // Only send ajax request if report has creation date
            if (study.Reports()[self.activeReportId()].CreationDate() != null) {
                // computing report flag            
                self.computingReport(true);

                // Ajax request to generate report
                net.ajax({
                    url: "/api/pkview/deleteReport?reportId=" + self.activeReportId(),
                    data: ko.toJSON(study),
                    type: "POST",
                    successCallback: function (result) {
                        var idx = self.activeReportId();
                        self.activeReportId(study.Reports().length > 1 ? 0 : null);
                        study.Reports.splice(idx, 1);
                        self.computingReport(false);
                    },
                    errorCallback: function () {
                        self.computingReport(false);
                        app.showMessage('An error occurred', 'PkView', ['OK'])
                    }
                });
            }
            else {
                var idx = self.activeReportId();
                self.activeReportId(study.Reports().length > 1 ? 0 : null);
                study.Reports.splice(idx, 1);
            }
        };
    };

    // After view is activated
    ctor.prototype.activate = function (settings) {
        var self = this;
        self.NDAName = settings.data.name;
        self.studies = settings.data.studies;
        self.allStudies = settings.data.allStudies;
        self.SelectedSupplement = settings.data.supplement;
        self.ProfileName = settings.data.profile;
        self.supplements = settings.data.supplements;
        self.error = settings.error;
        self.splash = settings.splash;
        self.allowedSteps = settings.allowedSteps;
        self.analyze = settings.inputData();

        // do not allow to switch to review until analysis has been completed
        self.allowedSteps([0]);

        // Array with all valid studies
        self.validStudies = ko.computed(function () {
            return self.studies().concat(self.unselected());
        });

        // Array with analyzable studies
        self.analyzableChanged = ko.observable();
        self.analyzableStudies = ko.computed(function () {
            var dummy = self.analyzableChanged();
            return $.grep(self.validStudies(), function (study, i) {
                return study.Analyzable;
            });
        });

        self.selectedStudies1(self.analyzableStudies().slice());
        self.metaformat({ plotAnalysis: false, Confidence90: false, AnalysisMethod: "", upperbound: 0, lowerbound: 0 });
        //self.selectedStudies1().splice(0, self.selectedStudies1().length);


        // Array with all studies
        self.totalStudies = ko.computed(function () {
            return self.validStudies().concat(self.unmappable());
        });

        // Computed observable for easy access to the currently active study
        self.study = ko.computed(function () {
            return $.grep(self.validStudies(), function (study, i) {
                return study.StudyCode == self.activeStudy()
                    && study.SupplementNumber == self.activeSupplement();
            })[0];
        });

        // UI flags
        self.enableSaveDelete = ko.computed(function () {
            return self.activeReportId() != null;
        });
        self.enableDownload = ko.computed(function () {
            if (!self.study()) return false;
            var reportId = self.activeReportId();
            if (reportId == null) return false;
            var reports = ko.unwrap(self.study().Reports);
            if (reports == null || reports.length < reportId + 1) return false;
            return ko.unwrap(reports[reportId].Generated);
        });

        // We want to run the analysis after configuring the analysis profile
        if (self.analyze) {
            self.unmappable(settings.data.unmappable());
            self.unselected(settings.data.notSelected());

            // Store which supplement was selected during analysis
            self.supplementAnalyzed = self.SelectedSupplement();

            //// Set the first study as active
            //if (self.studies().length > 0)
            //    self.activeStudy(self.studies()[0].StudyCode);
        }
        else {
            // We came directly to the reporting screen and we want to use previous analysis results
            var promise = pkViewProjects.get(self.NDAName(), self.ProfileName());
            promise.then(function (project) {

                // FIXME: convert project to old format for now until we have
                // time to refactor the UI to work with the new project format
                var supplements = {};
                $.each(project.Studies, function (i, study) {
                    if (!supplements[study.SupplementNumber])
                        supplements[study.SupplementNumber] = {
                            studies: new Array(),
                            unmappable: new Array(),
                            notSelected: new Array()
                        };
                    // FIXME: migration from legacy references format to cohorts
                    if (!study.Cohorts || study.Cohorts.length == 0) study.Cohorts = study.References;

                    // Convert cohorts to observable format and add cohort numbers if needed
                    var i = 1;
                    study.Cohorts = study.Cohorts.map(function (cohort) {
                        return {
                            Name: ko.observable(cohort.Name || cohort.Cohort),
                            Number: ko.observable(cohort.Number > 0 ? cohort.Number : i++),
                            Reference: ko.observable(cohort.Reference),
                            References: ko.observableArray(cohort.References)
                        };
                    });

                    if (study.StudyError > 0)
                        supplements[study.SupplementNumber].unmappable.push(study);
                    else supplements[study.SupplementNumber].studies.push(study);
                });

                self.supplements(supplements);

                // Format and add observables to the cohort references
                $.each(self.supplements(), function (supplementNumber, supplement) {
                    $.each(supplement.studies, function (i, study) {
                        // FIXME: transition code from references to cohorts, remove OR below when done
                        if (!study.Cohorts || study.Cohorts.length == 0) study.Cohorts = study.References;
                        study.Cohorts = ko.observableArray(study.Cohorts || null);
                    });
                });

                // Set the first supplement as active
                var supplementNumbers = Object.keys(supplements);
                if (supplementNumbers.length > 0)
                    self.SelectedSupplement(supplementNumbers[0]);

                // Let the user go back to review after studies are loaded
                self.allowedSteps([0,1,2]);

                self.splash.visible(false);
                self.uiMode("settings");
            });
            promise.fail(self.error);
        }

        settings.ready();
    };

    // After view is attached
    ctor.prototype.attached = function (view) {
        var self = this;
        $('[data-toggle="tooltip"]').tooltip({ container: 'body' });

        // We want to run the analysis after configuring the analysis profile
        if (self.analyze)
            pkViewAnalysis.run(self);
    };

    return ctor;
});