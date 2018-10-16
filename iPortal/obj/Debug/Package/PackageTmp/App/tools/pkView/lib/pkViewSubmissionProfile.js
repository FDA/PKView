define('tools/pkView/lib/pkViewSubmissionProfile', [
    'knockout',
    'durandal/app',
    'shared/components/errorDialog/viewmodels/errorDialog',
    'shared/api/pkAnalysis/mapping',
    'shared/api/pkAnalysis/analysis'
],
function (ko, app, errorDialog, mapping, analysis) {

    var self = {};

    // Get the mappings from the server
    self.get = function(viewmodel) {
        var dfd = $.Deferred();
        var promise = self.retrieveData(viewmodel);
        promise.then(self.initializeData)
            .then(function (supplements) {
                dfd.resolve(supplements);
            });
        promise.fail(dfd.reject);
        return dfd.promise();
    };

    // Retrieve newly computed or stored nda profile
    self.retrieveData = function (viewmodel) {

        // Promise initialization
        var dfd = $.Deferred();

        // Initialize study arrays
        viewmodel.supplements({});

        // Show progress
        viewmodel.splash.progress(0);
        viewmodel.splash.feedback("Waiting for server response");
        viewmodel.splash.visible(true);
        
        // api call to run the sas code that reads the variable mappings
        mapping.get({
            NDAName: viewmodel.NDAName(),
            ProfileName: viewmodel.ProfileName(),
            mappingErrorCallback: function (response) {
                errorDialog.show(response.responseText, true)
                    .then(function () { viewmodel.splash.visible(false); dfd.reject(); });
            },
            mappingInvalidResponseCallback: function () {
                app.showMessage('Error: Execution reached an invalid state', 'PkView', ['OK'])
                    .then(function () { viewmodel.splash.visible(false); dfd.reject(); });
            },
            mappingEmptyResponseCallback: function () {
                app.showMessage('Error: Empty response from the server', 'PkView', ['OK'])
                    .then(function () { viewmodel.splash.visible(false); dfd.reject(); });
            },
            mappingAbortedCallback: function (response) {
                app.showMessage('The process has been aborted.' + response.FeedbackMessage).then(
                    function () { viewmodel.splash.visible(false); dfd.reject(); });
            },
            mappingUpdateCallback: function (response) {
                viewmodel.splash.progress(Math.floor(response.PercentComplete / 2));
                viewmodel.splash.feedback(response.FeedbackMessage);
            },
            mappingSuccessCallback: function (response) {
                dfd.resolve(viewmodel, response);
            }
        });

        return dfd.promise();
    };


    // Perform data checks, transformations and retrieve additional data
    self.initializeData = function (viewmodel, mappings) {

        // Promise initialization
        var dfd = $.Deferred();

        // If No mappings were returned show an error
        if (mappings == null || $.isEmptyObject(mappings)) {
            app.showMessage('Sorry, no studies could be analyzed for the selected NDA.', 'PkView', ['OK'])
                .then(function () { viewmodel.splash.visible(false); dfd.reject(); });
            return;
        }

        // Separate failed study profiles within the supplements
        var supplements = new Object();
        self.validStudies = 0;
        $.each(mappings, function (supplementNumber, studies) {
            supplements[supplementNumber] = {
                studies: new Array(),
                unmappable: new Array(),
                notSelected: new Array()
            };
            $.each(studies, function (i, study) {
                if (study.StudyError > 0)
                    supplements[supplementNumber].unmappable.push(study);
                else {
                    self.validStudies++;
                    supplements[supplementNumber].studies.push(study);
                }
            });
        });

        // If all studies are unmappable return error
        if (self.validStudies == 0) {
            app.showMessage('Sorry, no studies could be analyzed for the selected NDA.', 'PkView', ['OK'])
                .then(function () { viewmodel.splash.visible(false); dfd.reject(); });
            return;
        }

        // Update progress
        viewmodel.splash.progress(51);
        viewmodel.splash.feedback("Formatting data");

        // Perform data initialization for each study
        var priorStudyPromise = null;
        $.each(supplements, function (supplementNumber, supplement) {
            $.each(supplement.studies, function (i, study) {
                if (priorStudyPromise != null) {
                    priorStudyPromise = priorStudyPromise
                        .then(function () { return self.initializeStudyData(viewmodel, study) });
                }
                else priorStudyPromise = self.initializeStudyData(viewmodel, study);
            });
        });

        // resolve when all studies are done
        if (priorStudyPromise != null) priorStudyPromise.then(function () {
            dfd.resolve(supplements);
        });

        return dfd.promise();
    };

    // Format current study data as observables and retrieve initial reference
    self.initializeStudyData = function (viewmodel, study) {

        var dfd = $.Deferred();

        // Fix nda name issues with old configuration files
        if (study.NDAName.length == 0)
            study.NDAName = viewmodel.NDAName();

        // Determine if there is a need to compute reference or study design
        // FIXME: migration to cohorts
        if (!study.Cohorts || study.Cohorts.length == 0) study.Cohorts = study.References;
        var computeStudyDesign = (study.StudyDesign == 0);
        var computeReference = (study.Cohorts == null);

        viewmodel.splash.progress(Math.floor(viewmodel.splash.progress() + (50 / self.validStudies / 2)));
        viewmodel.splash.feedback("Computing study design of " + study.StudyCode);

        // Obtain study design if needed
        var promise = computeStudyDesign ?
            self.updateStudyDesign(study) : $.when();

        // Obtain reference if needed
        if (computeStudyDesign || computeReference)
            promise.always(function (study) {
                viewmodel.splash.progress(Math.floor(viewmodel.splash.progress() + (50 / self.validStudies / 2)));
                viewmodel.splash.feedback("Computing reference treatments for study " + study.StudyCode);
                study.Cohorts = [];
                self.getCohorts(study)
                    .then(function (references) {
                        study.Cohorts = references;
                        dfd.resolve();
                    });
            });
        else promise.always(function () {        
            var i = 1;
            study.Cohorts = study.Cohorts.map(function (cohort) {
                return {
                    Name: ko.observable(cohort.Name || cohort.Cohort),
                    Number: ko.observable(cohort.Number > 0 ? cohort.Number: i++),
                    Reference: ko.observable(cohort.Reference),
                    References: ko.observableArray(cohort.References)
                };
            });
            dfd.resolve();
        });
            
        return dfd.promise();
    };

    // Obtain the study design for a particular study
    self.updateStudyDesign = function (study) {

        var dfd = $.Deferred();

        // get the study design
        mapping.getStudyDesign(study)
            .done(function (studyDesign) {
                if (ko.isObservable(study.StudyDesign))
                    study.StudyDesign(studyDesign);
                else study.StudyDesign = studyDesign;
            }).always(function () { dfd.resolve(study); });

        return dfd.promise();
    };

    // Compute the reference treatments/groups for the current study
    self.getCohorts = function (study) {

        var dfd = $.Deferred();

        // Prevent unnecesary fetching if study design is not defined or unknown
        // 0: undefined, 1: unknown
        if (ko.unwrap(study.StudyDesign) < 2) {
            var promise = dfd.resolve([]).promise();
            promise.abort = function () { };
            return promise;
        }

        // get the reference treatment/group list
        var mapRequest = mapping.getReference(study)
            .done(function (references) {

                // Map the references from the returned dictionary
                if (references != null && Object.keys(references).length > 0) {
                    var i = 1;
                    references = $.map(references, function (list, cohort) {
                        return {
                            Name: ko.observable(cohort),
                            Number: ko.observable(i++), 
                            Reference: ko.observable(""),
                            References: ko.observableArray(list)
                        };
                    });
                }
                dfd.resolve(references || []);
                
            }).fail(function () { dfd.resolve([]); });
        
        // append abort callback to our promise
        var promise = dfd.promise();
        promise.abort = function () {
            dfd.reject();
            mapRequest.abort;
        };

        return promise;
    };

    // Module interface
    var pkViewSubmissionProfile = {
        get: self.get,
        updateStudyDesign: self.updateStudyDesign,
        getCohorts: self.getCohorts
    };

    return pkViewSubmissionProfile;
});