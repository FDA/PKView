define('tools/pkView/lib/pkViewAnalysis', [
    'knockout',
    'durandal/app',
    'shared/api/pkAnalysis/mapping',
    'shared/api/pkAnalysis/analysis',
    'shared/api/reports/demographicSummary'
],
function (ko, app, mapping, analysis, demographicSummary) {

    var self = {};

    // Run a pk analysis for the selected studies
    // while providing feedback and updating the viewmodel
    self.run = function (viewmodel) {

        var dfd = $.Deferred();

        // Show progress
        viewmodel.splash.progress(0);
        viewmodel.splash.feedback("Saving analysis profile");
        viewmodel.splash.visible(true);

        // Save mappings
        self.saveMappings(viewmodel)
            .then(function () {
                return self.doRunAnalysis(viewmodel);
            })
            .then(function () {
                return self.afterAnalysis(viewmodel);
            })
            .then(function () {
                dfd.resolve();
            });
            
        return dfd.promise();
    };

    self.saveMappings = function (viewmodel) {
        var dfd = $.Deferred();

        // Save mappings
        mapping.save({
            ProfileName: viewmodel.ProfileName(),
            revisedMappings: viewmodel.allStudies(),
            successCallback: function (savedProfile) {
                viewmodel.ProfileName(savedProfile);

                // Add settings id to the studies (server code requirement)
                $.each(viewmodel.totalStudies(), function (i, study) {
                    study.ProfileName = savedProfile;
                });

                dfd.resolve();
            },
            errorCallback: function () {
                app.showMessage('User data could not be saved, the process will continue but' +
                    ' the changes made to the mappings will not be available when the tool is accessed again.',
                    'PkView', ['OK']).then(function () { dfd.resolve(); });
            }
        });

        return dfd.promise();
    };

    // Run specifically the analysis
    self.doRunAnalysis = function (viewmodel) {

        var dfd = $.Deferred();

        // Show progress
        viewmodel.splash.progress(2);
        viewmodel.splash.feedback("Running. This could take several minutes ");
        viewmodel.splash.visible(true);

        // Initialize variables
        viewmodel.failedStudies([]);
        viewmodel.successStudies([]);
        viewmodel.unRunnableStudies([]);

        // Perform analysis for each study
        var priorStudyPromise = null;
        $.each(viewmodel.studies(), function (i, study) {
            if (priorStudyPromise != null) {
                priorStudyPromise = priorStudyPromise
                    .then(function () { return self.runStudyAnalysis(viewmodel, study, i) })
                    .then(function () {
                        viewmodel.updateProgress({
                            FeedbackMessage: "Generating demographic summary for study " + study.StudyCode,
                            PercentComplete: Math.floor(((i + 1) * 90) / viewmodel.studies().length)
                        });
                        return demographicSummary.generate(study);
                    });
            }
            else priorStudyPromise = self.runStudyAnalysis(viewmodel, study, i)
                .then(function () {
                    viewmodel.updateProgress({
                        FeedbackMessage: "Generating demographic summary for study " + study.StudyCode,
                        PercentComplete: Math.floor(((i + 1) * 90) / viewmodel.studies().length)
                    });
                    return demographicSummary.generate(study);
                });
        });

        // resolve when all studies are done
        if (priorStudyPromise != null) priorStudyPromise.then(function () {
            dfd.resolve();
        });

        return dfd.promise();
    };

    self.runStudyAnalysis = function (viewmodel, study, i) {

        var dfd = $.Deferred();

        study.Reports = [];

        // Report start of analysis
        viewmodel.updateProgress({
            FeedbackMessage: "Sending analysis request for study " + study.StudyCode,
            PercentComplete: Math.floor((i * 90) / viewmodel.studies().length)
        });

        // Run the study analysis
        analysis.runStudy({
            revisedMappings: study,
            analysisSuccessCallback: function (response) {
                viewmodel.updateProgress({
                    FeedbackMessage: "Analysis of study " + study.StudyCode + " complete",
                    PercentComplete: Math.floor(((i + 1) * 90) / viewmodel.studies().length)
                });
                viewmodel.successStudies.push(study);
                dfd.resolve();
            },
            analysisUpdateCallback: function (response) {
                viewmodel.updateProgress({
                    FeedbackMessage: response.FeedbackMessage,
                    PercentComplete: Math.floor(((response.PercentComplete + (i * 100)) / viewmodel.studies().length) * 0.9)
                });
            },
            invalidInputCallback: function () {
                viewmodel.updateProgress({
                    FeedbackMessage: "Skipping study " + study.StudyCode,
                    PercentComplete: Math.floor((i * 90) / viewmodel.studies().length)
                });
                viewmodel.unRunnableStudies.push(study);
                dfd.resolve();
            },
            analysisErrorCallback: function () {
                self.analysisError(viewmodel, study, i).then(function () { dfd.resolve(); });
            },
            analysisAbortedCallback: function () {
                self.analysisError(viewmodel, study, i).then(function () { dfd.resolve(); });
            },
            analysisInvalidResponseCallback: function () {
                self.analysisError(viewmodel, study, i).then(function () { dfd.resolve(); });
            }
        });

        return dfd.promise();
    };

    // Callback to be used when there is analysis error
    self.analysisError = function (viewmodel, study, i) {
        viewmodel.updateProgress({
            FeedbackMessage: "Study " + study.StudyCode + " caused a runtime error. Skipping",
            PercentComplete: Math.floor((i * 90) / viewmodel.studies().length)
        });

        viewmodel.failedStudies.push(study);
        return $.when();
    };

    // Wrap up after all selected studies have been analyzed
    self.afterAnalysis = function (viewmodel) {
        var dfd = $.Deferred();

        analysis.createPackage({
            NDAName: viewmodel.studies()[0].NDAName,
            ProfileName: viewmodel.studies()[0].ProfileName,
            packageErrorCallback: function () {
                app.showMessage(response.responseText, 'PkView', ['OK'])
                    .then(function () { viewmodel.splash.visible(false); dfd.resolve(); viewmodel.error(); });
            },
            packageInvalidResponseCallback: function () {
                app.showMessage('Error: Execution reached an invalid state', 'PkView', ['OK'])
                    .then(function () { viewmodel.splash.visible(false); dfd.resolve(); viewmodel.error(); });
            },
            packageAbortedCallback: function (response) {
                app.showMessage('The process has been aborted.' + response.FeedbackMessage)
                    .then(function () { viewmodel.splash.visible(false); dfd.resolve(); viewmodel.error(); });
            },
            packageUpdateCallback: function (response) {
                viewmodel.updateProgress({
                    FeedbackMessage: response.FeedbackMessage,
                    PercentComplete: 90 + response.PercentComplete * 0.1
                });
            },
            successCallback: function () {
                viewmodel.splash.visible(false);

                // set selection and mapping as allowed steps
                viewmodel.allowedSteps([0, 1, 3]);

                dfd.resolve();
            }
        });

        return dfd.promise();
    };                                                                    
    
    // Module interface
    var pkViewAnalysis = {
        run: self.run
    };

    return pkViewAnalysis;
});