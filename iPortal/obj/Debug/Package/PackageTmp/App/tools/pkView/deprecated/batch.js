/// <reference path="runAnalysis.js" />
define('tools/pkView/viewmodels/batch', [
    'knockout',
    'floatThead',
    'shared/api/files',
    'shared/api/pkAnalysis/mapping',
    'shared/api/pkAnalysis/analysis',
],
function (ko, floatThead, files, mapping, analysis) {

    // This is the mainWindow viewmodel prototype
    var ctor = function () {
        var self = this;

        self.responseReady = ko.observable(false); // server response flag       
        self.ndaList = ko.observableArray([]); // List of NDAs   
        self.results = ko.observableArray([]); // Structure to store results
        self.currentIdx = ko.computed(function () { return self.results().length - 1; });

        self.sdtmVariables = mapping.sdtmVariables;
        self.studyDesignTypes = mapping.studyDesignTypes;
        self.isOptionalVariable = mapping.isOptionalVariable;
        
        self.splash = {
            visible: ko.observable(true),
            progress: ko.observable(null),
            message: ko.observable(""),
            feedback: ko.observable(null),
            displayCounter: ko.observable(false),
            formFactor: "small"
        };

        self.popoverFlag = false;
        self.setupPopover = function () {
            if (self.popoverFlag) return;
            self.popoverFlag = true;
            $('[data-toggle="popover"]').popover({
                container: 'body',
                placement: 'top',
                trigger: 'manual',
                html: true,
                content: "<div style=\"width: 250px; height: 150px\"" +
                    " data-bind=\"compose: { model: 'shared/components/splash/viewmodels/splash', activationData: $root.splash }\"></div>"
            });
            $('[data-toggle="popover"]').popover('show');
            $(".popover").css("position", "fixed");
            ko.applyBindingsToDescendants(self, $(".popover-content")[0]);
        };

        // Run the next nda
        self.runNextNda = function () {

            self.$batchTable.floatThead('reflow');
            
            // Add a new empty resultset
            self.results.push({});

            // If we have executed all ndas
            if (self.results().length > self.ndaList().length) {
                $('[data-toggle="popover"]').popover('hide');
                return;
            }

            // Reset splash screen
            self.splash.progress(null);
            self.splash.feedback("");
            self.splash.message("Running Mappings");

            // Launch mapping script
            mapping.get({
                NDAName: self.ndaList()[self.currentIdx()],
                mappingErrorCallback: self.mappingError,
                mappingInvalidResponseCallback: self.appError,
                mappingEmptyResponseCallback: self.appError,
                mappingAbortedCallback: self.mappingError,
                mappingUpdateCallback: function (response) {
                    self.setupPopover();
                    self.splash.progress(response.PercentComplete);
                    self.splash.feedback(response.FeedbackMessage);
                },
                mappingSuccessCallback: self.mappingSuccess 
            });
        };

        // Mapping error happened for the current Nda
        self.mappingError = function () {
            self.setupPopover();
            self.results()[self.currentIdx()].mappings = "error";
            self.runNextNda();
        };

        // Tool error
        self.appError = function () {
            self.setupPopover();
            self.results()[self.currentIdx()].mappings = "toolFailed";
            self.runNextNda();
        };

        // Mapping succeeded
        self.mappingSuccess = function (studies) {

            // No studies were returned
            if (studies == null)
            {
                self.results()[self.currentIdx()].mappings = "missing";
                self.runNextNda();
                return;
            }

            $.each(studies, function (i, study) {

                if (study.StudyMappings == null)
                    return;

                // Build a computed observable for mapping quality in each domain in the study
                $.each(study.StudyMappings, function (j, domain) {

                    // Mapping quality computed from the mappings in the domain
                    var qualities = [0, 0, 0, 0];
                    $.each(domain.DomainMappings, function (k, varMap) {
                        var quality = varMap.MappingQuality;

                        // Special case for optional unmapped variables
                        if (quality == 2 && mapping.isOptionalVariable(domain, self.splash, varMap))
                            quality = 3;

                        qualities[quality]++;
                    });
                    domain.QualityCount = {
                        excelent: qualities[0],
                        good: qualities[1],
                        unmapped: qualities[2],
                        unmappedOptional: qualities[3]
                    };
                });

                // Mapping quality computed from the mapping quality of the domains
                var qualityCount = { excelent: 0, good: 0, unmapped: 0, unmappedOptional: 0 };
                $.each(study.StudyMappings, function (k, domain) {
                    qualityCount.excelent += domain.QualityCount.excelent;
                    qualityCount.good += domain.QualityCount.good;
                    qualityCount.unmapped += domain.QualityCount.unmapped;
                    qualityCount.unmappedOptional += domain.QualityCount.unmappedOptional;
                });
                study.QualityCount = qualityCount;
            });
           
            self.results()[self.currentIdx()].mappings = studies;
            self.results.valueHasMutated();

            // Reset splash screen
            self.splash.progress(null);
            self.splash.feedback("");
            self.splash.message("Running Analysis");

            // Add nda name to the studies (server code requirement)
            $.each(studies, function (i, study) {
                study.NDAName = self.ndaList()[self.currentIdx()];
            });

            // run analysis
            analysis.runNda({
                studyMappings: studies,
                abortOnStudyError: false,
                studyAnalysisStartedCallback: self.updateProgress,
                studyAnalysisSkippedCallback: self.updateProgress,
                studyAnalysisFinishedCallback: self.updateProgress,
                analysisAbortedCallback: self.abortedAnalysis,
                analysisUpdateCallback: self.updateProgress,
                analysisSuccessCallback: function (results) {
                    self.results()[self.currentIdx()].analysis = {
                        success: $.map(results.successStudies, function (s) { return s.StudyCode }),
                        failed: $.map(results.failedStudies, function (s) { return s.StudyCode }),
                        unRunnable: $.map(results.unRunnableStudies, function (s) { return s.StudyCode })
                    };
                    self.runNextNda();
                },
                packageErrorCallback: self.abortedAnalysis,
                packageInvalidResponseCallback: self.abortedAnalysis
            });
        };

        // Update interface progress callback
        self.updateProgress = function (response) {
            self.splash.feedback(response.FeedbackMessage);
            self.splash.progress(response.PercentComplete);
        };

        self.abortedAnalysis = function () {
            self.results()[self.currentIdx()].analysis = "aborted";
            self.runNextNda();
        };
    };    

    // After view is attached
    ctor.prototype.attached = function (view) {
        var self = this;

        // get the list of NDAS with ajax
        files.getNdaList(function (ndaList) {
            //ndaList.reverse();
            self.ndaList(ndaList);
            self.responseReady(true);
            self.runNextNda();
        });      
        self.$batchTable = $("#batchTable");
        self.$batchTable.floatThead({
            scrollingTop: 60
        });
    };

    return ctor;
});
   