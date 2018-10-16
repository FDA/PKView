define('tools/pkView/components/review/review', [
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
        'tools/pkView/lib/pkViewSubmissionProfile'],
function (ko, koSelectize, dataDialog, errorDialog, net, txt, app, dialog, modal, mapping, profile) {

    // This is the mainWindow viewmodel prototype
    var ctor = function () {
        var self = this;
        self.subscriptions = [];

        /* Mapping screen variables */
        self.activeStudy = ko.observable(""); // Currently active study tab
        self.activeSupplement = ko.observable(""); // Supplement number of the currently active study
        //Code changed to remove ‘basic’ data  mapping mode
        //changed on 08/14/2017
        //self.mappingMode = ko.observable("basic"); // Mapping screen mode
        self.mappingMode = ko.observable("advanced"); // Mapping screen mode
        self.domainDescriptions = mapping.domainDescriptions; // Domain descriptions
        self.sdtmVariables = mapping.sdtmVariables; // Sdtm variables description and importance
        self.isOptionalVariable = mapping.isOptionalVariable; // Api function to determine if a variable is optional  
        self.editingValues = false; // Flag to mask value mapping reset while editing value mappings

        // Allow custom value mappings
        self.allowValueMapping = { PC: { VISIT: 1, PCTPTNUM: 1 }, PP: { VISIT: 1 } };

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
            var result = [];
            //code changed to remove "AGE", "SEX", "RACE", "COUNTRY", "ETHNIC" from display
            //code changed on 08/04/2017
            var j = 0;
            for (var i = 0; i < mappingsArray.length; i++) {
                if (mappingsArray[i].SdtmVariable != "AGE" &&
                    mappingsArray[i].SdtmVariable != "SEX" &&
                    mappingsArray[i].SdtmVariable != "RACE" &&
                    mappingsArray[i].SdtmVariable != "COUNTRY" &&
                    mappingsArray[i].SdtmVariable != "ETHNIC") {
                    if (j % 2 == 0)
                        result.push([mappingsArray[i]]);
                    else
                        result[result.length - 1].push(mappingsArray[i]);
                    j++;
                }
            }
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
        self.subscriptions.push(self.mappingMode.subscribe(function (mode) {
            if (mode != "basic")
                setTimeout(self.tryResizeTabs, 200);
        }));

        // Activate a tab
        self.setActiveStudy = function (study) {
            self.activeStudy(study.StudyCode);
            self.activeSupplement(study.SupplementNumber);

            // Update dropdown title
            self.resizeMonitor.notifySubscribers();
        };

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

        // Edit the list of treatments/groups manually
        self.editValueMapping = function (study, domain, variable) {

            var dfd = $.Deferred();

            varName = variable.SdtmVariable;
            var listName = domain[0].toUpperCase() + domain.substr(1).toLowerCase();
            listName += varName[0].toUpperCase() + varName.substr(1).toLowerCase();
            var flagName = "UseCustom" + listName;
            listName += "Mappings";

            var valueEditDialog = new modal({
                title: "Edit " + domain + ":" + varName + " (" + variable.FileVariable() + ")",
                model: "tools/pkview/components/review/sections/setValues",
                activationData: {
                    study: study,
                    domain: domain,
                    varName: varName,
                    mappings: study[listName] || null
                },
                width: 0.9
            });
            dialog.show(valueEditDialog)
                .then(function (result) {

                    if (result) {
                        if (result.customize) {
                            study[listName] = result.mappings.map(function (mapping) {
                                return {
                                    Original: mapping.oldValue,
                                    New: ko.unwrap(mapping.newValue)
                                };
                            });
                        } else study[listName] = null;
                        study[flagName] = result.customize;
                        self.editingValues = true;
                        variable.FileVariable.valueHasMutated();
                        self.editingValues = false;
                    }

                    dfd.resolve();
                });

            return dfd;
        };

        // Reset the customized values
        self.resetValueMapping = function (study, domain, variable) {
            if (self.editingValues) return;
            varName = variable.SdtmVariable;
            var listName = domain[0].toUpperCase() + domain.substr(1).toLowerCase();
            listName += varName[0].toUpperCase() + varName.substr(1).toLowerCase();
            var flagName = "UseCustom" + listName;
            listName += "Mappings";
            study[flagName] = false;
            study[listName] = null;
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

                    // Make file variable selection observable
                    varMap.FileVariable = ko.observable(varMap.FileVariable);

                    // if value editions are allowed, reset value changes if variable was changed
                    if (self.allowValueMapping[domain.Type] &&
                        self.allowValueMapping[domain.Type][varMap.SdtmVariable])
                        self.subscriptions.push(varMap.FileVariable.subscribe(function () {
                            self.resetValueMapping(study, domain.Type, varMap);
                        }));

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

            // Setup observables
            study.StudyDesign = ko.observable(study.StudyDesign);           
            study.UseDm = ko.observable(!(study.UseEx || false));
            study.UseSuppdm = ko.observable(study.UseSuppdm || false);
            study.UseExRef = ko.observable(study.UseExRef || false);
            study.UseCustomArms = ko.observable(study.UseCustomArms || false);
            study.DisablePcSorting = ko.observable(study.DisablePcCleanup || false);

            // Use a computed observable to invert UseDm -> UseEx
            study.UseEx = ko.computed({
                read: function () { return !study.UseDm(); },
                write: function (value) { study.UseDm(!value); }
            });

            // Format and add observables to the cohort references
            // FIXME: transition code from references to cohorts, remove OR below when done
            if (!study.Cohorts || study.Cohorts.length == 0) study.Cohorts = study.References;            
            study.Cohorts = ko.observableArray(study.Cohorts || null);

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
                        //changed on 08/14/2017
                        //self.mappingMode("basic");
                        self.mappingMode("advanced");
                        self.splash.visible(false);
                        self.allowedSteps([0,2,3]);
                    }
                    else self.showInterface(supplements);
                }
            }, 500);
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
            if (study.Cohorts().length == 0) {
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
    ctor.prototype.activate = function (settings) {
        var self = this;
        self.NDAName = settings.data.name;
        self.SelectedSupplement = settings.data.supplement;
        self.ProfileName = settings.data.profile;
        self.supplements = settings.data.supplements;
        self.studies = settings.data.studies;
        self.unmappable = settings.data.unmappable;
        self.unselected = settings.data.notSelected;

        // Reset data in case we dont come from a clean start
        settings.data.supplements({});

        // If previous step was reporting allow to return to it, otherwise just allow
        // to return to selection screen
        //if (settings.previousStep() == 2)
         //   settings.allowedSteps([0, 2]);
        //else settings.allowedSteps([0]);
        self.allowedSteps = settings.allowedSteps;
        self.allowedSteps([0]);

        // Array with all studies
        self.totalStudies = ko.computed(function () {
            return self.studies().concat(self.unmappable());
        });

        self.done = function () { settings.done(true); };
        self.error = settings.error;
        self.splash = settings.splash;

        // This computed observable will determine if the SAS code can be run on the studies
        self.validMappings = {
            excellent: ko.observableArray([]),
            good: ko.observableArray([]),
            unmapped: ko.observableArray([]),
            unmappedOptional: ko.observableArray([]),
            noReference: ko.observableArray([])
        };
        self.refreshMappingQuality = ko.computed(function () {
            var excellent = [];
            var good = [];
            var unmapped = [];
            var unmappedOptional = [];
            var noReference = [];
            $.each(self.studies(), function (i, study) {

                if (study.QualityCount().unmapped == 0) {
                    if (study.Cohorts().length > 0)
                        if (study.QualityCount().unmappedOptional == 0) {
                            if (study.QualityCount().good == 0)
                                excellent.push(study);
                            else good.push(study);
                        }
                        else unmappedOptional.push(study);
                    else noReference.push(study);
                }
                else unmapped.push(study);
            });
            self.validMappings.excellent(excellent);
            self.validMappings.good(good);
            self.validMappings.unmapped(unmapped);
            self.validMappings.unmappedOptional(unmappedOptional);
            self.validMappings.noReference(noReference);
        });

        settings.ready();
    };

    // After viewmodel has been attached to view, get the nda profile
    ctor.prototype.attached = function (view) {
        var self = this;
        var promise = profile.get(self);
        promise.then(function (supplements) {
            self.prepareData(supplements);
            self.showInterface(supplements);
        });
        promise.fail(self.error);
    };

    // Clean up
    ctor.prototype.detached = function () {
        var self = this;

        // Disable resize event as we are not using tabs anymore
        $(window).off("resize.pkViewMappings");

        // Dispose subscriptions
        for (var i = 0; i < self.subscriptions.length; i++)
            self.subscriptions[i].dispose();

        // dispose computed observables
        self.refreshMappingQuality.dispose();
        self.totalStudies.dispose();
        self.dropdownTitle.dispose();

        self.cancelRequests = true;
    };

    return ctor;
});