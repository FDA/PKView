define('tools/ogdTool/components/main/main', [
        'knockout',
        'tools/ogdTool/models',
        'ocpkmlib/net',


        'shared/components/dataDialog/viewmodels/dataDialog',
        'shared/components/errorDialog/viewmodels/errorDialog',        
        'ocpkmlib/txt',
        'durandal/app',
        'plugins/dialog',
        'shared/api/pkAnalysis/mapping',
        'tools/pkView/lib/pkViewSubmissionProfile'],
function (ko, models, net, dataDialog, errorDialog, txt, app, dialog, mapping, profile) {

    // This is the main view viewmodel prototype
    var ctor = function () {
        var self = this;

        self.shellData = null; // Data shared betwen this and other sibling views by the shell
        self.project = ko.observable(null); // Root of the project structure
        self.activeComparison = ko.observable(0); // Currently active comparison Tab

        self.goToHome = function () {
            self.shellData.viewSelector.goToView('home');
        };

        // Activate a tab
        self.setActiveComparison = function (idx) {
            //self.enableSettingsEvents = false;
            self.activeComparison(idx);
        };

        // Initialize project object, creating a new one or loading from server
        self.initializeProject = function (projectSettings) {
            var dfd = $.Deferred();

            if (projectSettings.mode == 'create') {
                var newProject = new models.project(projectSettings);
                newProject.findAndCreateComparisons()
                    .then(function () {
                        self.project(newProject);
                        dfd.resolve();
                    });    
            }

            if (projectSettings.mode == 'load') {
                $.get('api/ogdtool/loadproject?submission='
                + projectSettings.submission + "&project=" + projectSettings.name)
                .done(function (project) {
                    var newProject = new models.project(project);
                    self.project(newProject);
                    dfd.resolve();
                });
            }
            return dfd;
        };

        // generate and download the script
        self.download = function () {
            var currentComparison = self.project().comparisons()[self.activeComparison()];
            var comparisonData = currentComparison.prepareForSubmission();

            var submission = self.project().submissionType + self.project().submissionNumber;

            $.post('/api/ogdtool/createscript?projectName='
                + self.project().name
                + '&submissionId='
                + submission, comparisonData)
                .done(function () {
                    net.download("/api/download/OgdTool/"
                        + self.project().name + ".zip"
                        + "?subfolder=" + submission);
                });
        };

        // Save the project
        self.save = function () {
            var myProject = self.project();
            var project = {
                ProjectName: myProject.name,
                SubmissionType: myProject.submissionType,
                SubmissionNumber: myProject.submissionNumber,
                AllFiles: myProject.allFiles,
                Comparisons: myProject.comparisons().map(function (comparison) {
                    return comparison.prepareForSubmission();
                })
            };
            $.post('/api/ogdtool/saveproject', project);
        };

        /* Mapping screen variables */
        self.activeSupplement = ko.observable(""); // Supplement number of the currently active study
        //Code changed to remove ‘basic’ data  mapping mode
        //changed on 08/14/2017      
        self.mappingMode = ko.observable("advanced"); // Mapping screen mode
        self.StudyDesignTypes = mapping.studyDesignTypes; // Study Design Types
        self.domainDescriptions = mapping.domainDescriptions; // Domain descriptions
        self.sdtmVariables = mapping.sdtmVariables; // Sdtm variables description and importance
        self.isOptionalVariable = mapping.isOptionalVariable; // Api function to determine if a variable is optional  
        self.enableSettingsEvents = false; // masks settings re-computation on interface refresh

        // Title for dropdown tab, used to display tab name on really small screens
        self.resizeMonitor = ko.observable();
        self.dropdownTitle = ko.computed(function () {
            self.resizeMonitor();
            if ($("#studyTabs > li.studyTab:visible").length == 0)
                return $("#studyTabs > li.dropdown > ul > li.active > a > span:last").text();
            else return "More";
        });

        /********************************************************/
        /* User Interface functions and callbacks               */
        /********************************************************/

        // Split a mappings array in two columns
        self.splitInTwoColumns = function (mappingsArray) {
            var result = [mappingsArray.slice(0, mappingsArray.length / 2),
                mappingsArray.slice(mappingsArray.length / 2)];
            return result;
        };

        // Organize tab bar
        self.organizeTabs = function (element, index, data) {
            var regularTabs = $("#studyTabs > li");
            var dropdownTabs = $("#studyTabs > li.dropdown > ul > li");
            var dropdownMenu = $("#studyTabs > li.dropdown");

            // Reset tabs
            dropdownTabs.hide();
            regularTabs.show();
            self.resizeMonitor.notifySubscribers();

            // Check if we got here when interface was not created/destroyed
            var firstTab = $("#studyTabs > li.studyTab").first();
            if (firstTab.length == 0) return;

            var barTop = firstTab.position().top;

            // if there is no need for dropdown hide it           
            if ($("#studyTabs > li.studyTab").last().position().top == barTop) {
                dropdownMenu.hide();
                return;
            }

            // Move tabs to dropdown until everything fits in one line
            var index = regularTabs.length - 2;
            while (dropdownMenu.position().top > barTop && index > -1) {
                $(regularTabs[index]).hide();
                $(dropdownTabs[index]).show();
                index--;
            }

            // Special case when screen is so small that all tabs are hidden
            if (index == -1)
                dropdownMenu.show();

            // Update dropdown title
            self.resizeMonitor.notifySubscribers();
        };

        // Try to resize tabs when they become visible
        self.tryResizeTabs = function () {
            if ($("#studyTabs:visible").length > 0)
                self.organizeTabs();
            else setTimeout(self.tryResizeTabs, 200);
        };

        // Resize tabs if basic mode is activated
        self.mappingMode.subscribe(function (mode) {
            if (mode != "basic")
                setTimeout(self.tryResizeTabs, 200);
        });
       
        // Select the supplement(s) we want to work on
        self.selectSupplement = function (supplementNumber) {
            self.SelectedSupplement(supplementNumber);

            // Set the first study as active
            if (self.studies().length > 0) {
                self.activeStudy(self.studies()[0].StudyCode);
                self.activeSupplement(self.studies()[0].SupplementNumber);
            }

            // Update tabs
            self.organizeTabs();
        };

        // View domain data
        self.viewData = function (domain) {
            dialog.show(new dataDialog(domain.FileId, self.domainDescriptions[domain.Type] + " File Data"));
        };

        // Change the quality value of the mapping to good when the user edits the value
        self.changeQuality = function (item) {
            item.MappingQuality(1);
        };

        /********************************************************/
        /* Data preparation for the mapping interface           */
        /********************************************************/

        // Perform data initialization for each study
        self.prepareData = function (supplements) {
            $.each(supplements, function (supplementNumber, supplement) {
                $.each(supplement.studies, function (i, study) {
                    self.prepareStudyData(study);
                });
            });
        };

        // Prepare data for display in mapping interface by adding
        // observables and computed observables as needed
        self.prepareStudyData = function (study) {

            // list of unmapped variables
            study.Unmapped = [];

            // Timeout used for reference update when parameters are changed
            study.referenceTimeout = null;

            // flag to monitor reference update 
            study.ComputingReferences = ko.observable(false);
            study.ComputingStudyDesign = ko.observable(false);

            // Build a computed observable for mapping quality in each domain in the study
            $.each(study.StudyMappings, function (j, domain) {

                // Make mapping qualities observable, compute optionality and gather a list of unmapped variables                
                $.each(domain.DomainMappings, function (k, varMap) {
                    if (varMap.MappingQuality == 2) {
                        var item = {
                            domain: domain,
                            mapping: varMap
                        };
                        study.Unmapped.push(item);
                    }

                    varMap.MappingQuality = ko.observable(varMap.MappingQuality);
                    varMap.Optional = ko.observable(true);
                    self.maybeComputeOptional(varMap, domain);

                    // Update reference on mapping change
                    varMap.FileVariable = ko.observable(varMap.FileVariable);
                    varMap.FileVariable.subscribe(function () { self.updateStudyDesign(study); });
                });

                // Mapping quality computed from the mappings in the domain
                domain.QualityCount = ko.computed(function () {
                    var qualities = [0, 0, 0, 0];
                    $.each(domain.DomainMappings, function (k, varMap) {
                        var quality = varMap.MappingQuality();

                        // Special case for optional unmapped variables                          
                        if (quality == 2 && varMap.Optional())
                            quality = 3;

                        qualities[quality]++;
                    });
                    var qualityCount = {
                        excelent: qualities[0],
                        good: qualities[1],
                        unmapped: qualities[2],
                        unmappedOptional: qualities[3]
                    };
                    return qualityCount;
                });

                // Add blank entry to the list
                domain.UIFileVariables = [{ Text: "", Value: "" }].concat(domain.FileVariables);

            });

            // Update reference with study design too
            study.StudyDesign = ko.observable(study.StudyDesign);
            study.StudyDesign.subscribe(function () { self.updateReference(study); });

            // Update reference and study design with the Use checkboxes            
            study.UseDm = ko.observable(!(study.UseEx || false));
            study.UseSuppdm = ko.observable(study.UseSuppdm || false);
            study.UseExRef = ko.observable(study.UseExRef || false);
            study.UseDm.subscribe(function () { self.updateStudyDesign(study); });
            study.UseSuppdm.subscribe(function () { self.updateStudyDesign(study); });
            study.UseExRef.subscribe(function () { self.updateStudyDesign(study); });

            // Use a computed observable to invert UseDm -> UseEx
            study.UseEx = ko.computed({
                read: function () { return !study.UseDm(); },
                write: function (value) { study.UseDm(!value); }
            });

            // Format and add observables to the cohort references
            var references = $.map(study.References, function (cohort) {
                return self.formatReference(cohort.References, cohort.Cohort, cohort.Reference);
            });
            study.References = ko.observableArray(references);

            // Mapping quality computed from the mapping quality of the domains
            study.QualityCount = ko.computed(function () {
                var qualityCount = { excelent: 0, good: 0, unmapped: 0, unmappedOptional: 0 };
                $.each(study.StudyMappings, function (k, domain) {
                    qualityCount.excelent += domain.QualityCount().excelent;
                    qualityCount.good += domain.QualityCount().good;
                    qualityCount.unmapped += domain.QualityCount().unmapped;
                    qualityCount.unmappedOptional += domain.QualityCount().unmappedOptional;
                });
                return qualityCount;
            });
        };

        // for now dont compute if the variable is set, this will speed up the interface considerably
        self.currentlyComputing = 0;
        self.maybeComputeOptional = function (varMap, domain) {
            if (ko.utils.unwrapObservable(varMap.FileVariable) == "") {
                self.currentlyComputing++;
                mapping.isOptionalVariable(domain, self.splash, varMap).then(function (optional) {
                    varMap.Optional(optional);
                    self.currentlyComputing--;
                    // varMap.MappingQuality.valueHasMutated();
                });
            }
        }

        /********************************************************/
        /* UI initialization after data is received and prepared*/
        /********************************************************/

        // Ensure we do not show the interface until all the optionalities have been computed
        self.showInterface = function(supplements) {
            setTimeout(function () {
                if (!self.cancelRequests) {
                    if (self.currentlyComputing == 0) {
                        // Once we created the knockout observables, push the studies array to the viewmodel
                        self.supplements(supplements);
                        self.enableSettingsEvents = true;

                        // Set the first supplement as active
                        var supplementNumbers = Object.keys(supplements);
                        if (supplementNumbers.length > 0)
                            self.SelectedSupplement(supplementNumbers[0]);

                        // Set the first study as active
                        if (self.studies().length > 0) {
                            self.activeStudy(self.studies()[0].StudyCode);
                            self.activeSupplement(self.studies()[0].SupplementNumber);
                        }

                        // Setup tab events
                        $(window).on("resize.pkViewMappings", self.organizeTabs);
                        //Code changed to remove ‘basic’ data  mapping mode
                        //self.mappingMode("basic");
                        //changed on 08/14/2017
                        self.mappingMode("advanced");
                        self.splash.visible(false);
                        self.allowedSteps([0, 2]);
                    }
                    else self.showInterface(supplements);
                }
            }, 500);
        };

        /********************************************************/
        /* Data Update Actions                                  */
        /********************************************************/

        // Update reference after a preset timeout
        self.updateReference = function (study) {

            if (!self.enableSettingsEvents) return;

            // Clear references
            study.References([]);

            // Reset and dont compute reference if study design is not set
            if (study.StudyDesign() == null || study.StudyDesign() < 2)
            {
                study.ComputingReferences(false);
                return;
            }

            study.ComputingReferences(true);
            clearTimeout(study.referenceTimeout);
            study.referenceTimeout = setTimeout(function () {
                study.ComputingReferences(true);
                profile.updateReference(study, self.formatReference)
                    .always(function () {
                        study.ComputingReferences(false);
                    });
            }, 2000);
        };

        // Update study design after a preset timeout
        self.updateStudyDesign = function (study) {

            if (!self.enableSettingsEvents) return;

            study.ComputingStudyDesign(true);
            study.ComputingReferences(true); // We will compute the reference eventually
            clearTimeout(study.referenceTimeout);
            study.referenceTimeout = setTimeout(function () {
                study.ComputingStudyDesign(true);
                profile.updateStudyDesign(study)
                    .always(function () {
                        study.ComputingStudyDesign(false);
                        study.ComputingReferences(true);
                        study.References([]);
                        return profile.updateReference(study, self.formatReference);
                    }).always(function () {
                        study.ComputingReferences(false);
                    });
            }, 2000);
        };

        // This will format a reference list to be used on the interface's selectize
        self.formatReference = function (list, cohort, selectedReference) {
            var referenceList = null;
            if (list != null && list.length > 0)
                referenceList = $.map(list, function (reference, idx) {
                    return { text: reference, value: reference };
                });
            var cohortReferences = {
                Cohort: cohort,
                Reference: ko.observable(selectedReference),
                References: list,
                ReferenceList: ko.observableArray(referenceList)
            };
            return cohortReferences;
            
        };

        /********************************************************/
        /* UI Actions                                           */
        /********************************************************/

        // Function to ask for optional mappings
        var askForOptional = function () {
            // If optional variables are unmapped
            if (self.validMappings.unmappedOptional().length > 0) {
                app.showMessage('Some optional variables were not mapped, the analysis code can ' +
                    'run but setting correct values for these mappings can potentially improve ' +
                    'accuracy or enable additional results. Are you sure you want to continue?',
                    'Warning', ['Yes', 'No, let me set additional mappings'])
                .then(function (answer) { if (answer == 'Yes') self.done(); });
                return;
            }

            self.done();
        };

        // Check the user for confirmation and run the analysis
        self.runAnalysis = function () {

            // If no analysis has correct mappings it makes no sense to continue
            if (self.validMappings.excellent().length == 0
                && self.validMappings.good().length == 0
                && self.validMappings.unmappedOptional().length == 0) {
                app.showMessage('No studies can be analyzed, please review the settings by making use of the advanced' +
                    ' interface before attempting to continue.', 'Error');
                return;             
            }

            // If required variables are unmapped for some studies
            if (self.validMappings.unmapped().length > 0) {
                app.showMessage('Some studies have unmapped required variables, if you continue those ' +
                    'studies will not be analyzed. Are you sure you want to continue?',
                    'Warning', ['Yes', 'No, let me set additional mappings'])
                .then(function (answer) { if (answer == 'Yes') askForOptional(); });
                return;
            }

            askForOptional();
        };

        // Run the current study
        self.runSingleStudy = function () {
            
            var study = null; var index = 0;
            var currentSupplement = self.supplements()[self.activeSupplement()];
            $.each(currentSupplement.studies, function (i, currentStudy) {
                if (currentStudy.StudyCode == self.activeStudy())
                {
                    study = currentStudy;
                    index = i;
                }
            });

            // If required variables are unmapped 
            if (study.QualityCount().unmapped > 0)
            {
                app.showMessage('The study has unmapped required variables and cannot be analyzed, please set ' +
                    'correct values for these variables.', 'Error');
                return;
            }

            // If references list is empty
            if (study.References().length == 0) {
                app.showMessage('The study treatments/groups could not be determined. The analysis cannot ' +
                    'run until this issue is solved by changing the analysis settings.', 'Error');
                return;
            }

            // Select only the current study for analysis
            var doRunSingleStudy = function () {

                // If we are dealing with a rolling NDA, deselect all studies from other supplements
                if (self.SelectedSupplement() == "") {
                    $.each(self.supplements(), function (supplementNumber, supplement) {
                        if (supplementNumber != self.activeSupplement()) {
                            supplement.notSelected = supplement.studies;
                            supplement.studies = [];
                        }
                    });
                }

                currentSupplement.notSelected = currentSupplement.studies;
                currentSupplement.studies = currentSupplement.notSelected.splice(index, 1);
                self.supplements.notifySubscribers();
                self.done();
            };

            // If optional variables are unmapped
            if (study.QualityCount().unmappedOptional > 0) {
                app.showMessage('Some optional variables were not mapped, the analysis code can ' +
                    'run but setting correct values for these mappings can potentially improve ' +
                    'accuracy or enable additional results. Are you sure you want to continue?',
                    'Warning', ['Yes', 'No, let me set additional mappings'])
                .then(function (answer) { if (answer == 'Yes') doRunSingleStudy(); });
                return;
            }

            doRunSingleStudy();
        };
    };

    /********************************************************/
    /* Viewmodel activation and attachment                  */
    /********************************************************/

    // Load data from previous step and create computed observables as needed
    ctor.prototype.activate = function (shellData) {
        var dfd = $.Deferred();
        var self = this;
        
        self.shellData = shellData;
        self.initializeProject(shellData.currentProject)
            .then(function () {
                dfd.resolve();
            });

        return dfd;
    };

    // After viewmodel has been attached to view, get the nda profile
    ctor.prototype.attached = function (view) {
        var self = this;
    };

    // Clean up
    ctor.prototype.detached = function () {
        var self = this;
    };

    return ctor;
});