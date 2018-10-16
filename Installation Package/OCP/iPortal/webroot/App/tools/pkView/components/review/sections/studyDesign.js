define('tools/pkView/components/review/sections/studyDesign', [
        'knockout',
        'shared/components/dataDialog/viewmodels/dataDialog',
        'shared/components/errorDialog/viewmodels/errorDialog',
        'ocpkmlib/net',
        'ocpkmlib/txt',
        'durandal/app',
        'plugins/dialog',
        'shared/components/modal/viewmodels/modal',
        'shared/api/pkAnalysis/mapping',
        'tools/pkView/lib/pkViewSubmissionProfile'],
function (ko, dataDialog, errorDialog, net, txt, app, dialog, modal, mapping, profile) {

    // This is the mainWindow viewmodel prototype
    var ctor = function () {
        var self = this;

        self.subscriptions = [];
        self.StudyDesignTypes = mapping.studyDesignTypes; 
        self.study = null;

        // UI flags       
        self.ComputingStudyDesign = ko.observable(false);
        self.ComputingReferences = ko.observable(false);
        self.SettingCustomArms = false;
        self.ResettingArms = false;

        // store request handlers so we can cancel requests
        self.requests = {
            referenceRequest: null,
            referenceTimer: null,
            designRequest: null,
            designTimer: null
        };

        // Update study Design after a preset timeout
        self.updateStudyDesign = function () {

            var dfd = new $.Deferred();

            // reset the study design
            self.study.StudyDesign(0);

            // set flag
            self.ComputingStudyDesign(true);            

            // Abort any previous request
            if (self.requests.designTimer != null)
                clearTimeout(self.requests.designTimer);
            if (self.requests.designRequest != null)
                self.requests.designRequest.abort();

            // delay request half a second to allow for rapid UI toggling
            self.requests.designTimer = setTimeout(function () {

                // request the calculation of the list of references
                self.requests.designRequest = mapping.getStudyDesign(self.study);
                self.requests.designRequest.done(function (studyDesign) {
                    if (studyDesign == null) studyDesign = 1;
                    self.study.StudyDesign(studyDesign);
                    self.ComputingStudyDesign(false);
                    dfd.resolve();
                });
            }, 500);

            return dfd;
        };

        // Update reference after a preset timeout
        self.updateReference = function () {

            var dfd = new $.Deferred();

            // Clear the study cohorts
            self.study.Cohorts([]);

            // Reset and dont compute reference if study design is not set
            if (self.study.StudyDesign() == null || self.study.StudyDesign() < 2) {
                return $.when(); // resolved promise
            }

            // set flag
            self.ComputingReferences(true);

            // Abort any previous request
            if (self.requests.referenceTimer != null)
                clearTimeout(self.requests.referenceTimer);
            if (self.requests.referenceRequest != null) 
                self.requests.referenceRequest.abort();            

            // delay request half a second to allow for rapid UI toggling
            self.requests.referenceTimer = setTimeout(function () {

                // request the calculation of the list of references
                self.requests.referenceRequest = profile.getCohorts(self.study);
                self.requests.referenceRequest.done(function (cohorts) {
                    for (i = 0; i < cohorts.length; i++)
                        cohorts[i].treatmentList = self.getCohortDropdown(cohorts[i].References());
                    self.study.Cohorts(cohorts);
                    self.ComputingReferences(false);
                    dfd.resolve();
                });
            }, 500);

            return dfd;            
        };

        // convert a list of treatments into something usable by the selectize dropdown
        self.getCohortDropdown = function (treatments) {
            return treatments.map(function (treatment) {
                return { text: treatment, value: treatment };
            });
        };

        // move the cohort down in the list
        self.moveCohortDown = function (cohort) {
            var number = cohort.Number(); 
            if (number == self.study.Cohorts().length) return;
            self.swapCohorts(number, number + 1);
        };

        // move the cohort up in the list
        self.moveCohortUp = function (cohort) {
            var number = cohort.Number();
            if (number == 1) return;
            self.swapCohorts(number - 1, number);
        };

        // Swap two cohorts in the list
        self.swapCohorts = function (low, high) {
            var cohortArray = self.study.Cohorts();
            cohortArray[low - 1].Number(high);
            cohortArray[high - 1].Number(low);
            var tmp = cohortArray[low - 1];
            cohortArray[low - 1] = cohortArray[high - 1];
            cohortArray[high - 1] = tmp;
            self.study.Cohorts(cohortArray);
        };

        // Edit the list of treatments/groups manually
        self.editReferences = function (cohort) {

            var dfd = $.Deferred();

            var trtEditDialog = new modal({
                title: "Review study design",
                model: "tools/pkview/components/review/sections/setReferences",
                activationData: { study: self.study },
                width: 0.9
            });
            dialog.show(trtEditDialog)
                .then(function (arms) {

                    // if an array of arm treatments was returned
                    if (arms) {

                        self.study.ArmMappings = arms.map(function (arm) {
                            return {
                                OldArm: arm.oldArm,
                                Treatments: arm.treatments().map(function (trt) {
                                    return ko.unwrap(trt);
                                })
                            };
                        });

                        self.updateReference();
                    } 

                    dfd.resolve();
                });

            return dfd;
        };   
       
        // Toggle the custom arms checkbox
        self.toggleCustomArms = function (customizeArms) {

            // do not loop recursively
            if (self.SettingCustomArms) return;

            // if checkbox is checked
            if (customizeArms) {
                self.SettingCustomArms = true;

                // Remove any old customized mappings
                delete self.study.ArmMappings;

                // Open the custom arms UI
                self.editReferences()
                    .then(function () {
                        // if arms found, uncheck every other checkbox
                        if (self.study.ArmMappings) {
                            self.study.UseDm(false);
                            self.study.UseExRef(false);
                            self.study.UseSuppdm(false);
                            self.updateStudyDesign();
                            // if no arms were set, unset the checkbox
                        } else self.study.UseCustomArms(false);

                        self.SettingCustomArms = false;
                    });
            }

            // if checkbox is unchecked recalculate study design and treatments/groups
            if (!customizeArms) self.updateStudyDesign();
        };

        // Wrapper to cancel reference update if the event is triggered by internal logic
        self.triggerStudyDesignUpdate = function () {
            if (!self.SettingCustomArms) self.updateStudyDesign();
        };

        // Wrapper to cancel reference update if the event is triggered by internal logic
        self.triggerReferenceUpdate = function () {
            if (!self.SettingCustomArms) self.updateReference();
        };

        // Wrapper to cancel reference update if the event is triggered by internal logic
        self.triggerReferenceAfterStudyDesign = function (oldStudyDesign, newStudyDesign) {
            if (oldStudyDesign != newStudyDesign)
                setTimeout(self.triggerReferenceUpdate, 0);
        };

        // Reset custom arms when ARM variable is changed
        self.resetCustomArms = function (oldArm, newArm, variableMapping) {

            // If we are currently resetting the arms do not enter a recursive loop
            if (self.ResettingArms) return;

            // If custom arms not in use, update study design as normally
            if (!self.study.UseCustomArms()) self.updateStudyDesign();
            else {
                // If custom arms in use, warn the user that they will be reset to defaults
                app.showMessage("Changing the arm variable will remove any user changes " +
                    "to the study arms and reset study design and treatments/groups to " +
                    "the default determination method.", "Warning", ["Ok", "Cancel"])
                    .then(function (response) {
                        // If the user cancels, restore the value of the ARM muting events
                        if (response == "Cancel") {
                            self.ResettingArms = true;
                            variableMapping.FileVariable(oldArm);
                            self.ResettingArms = false;
                            // If the user does not cancel, uncheck the checkbox, which 
                            // will also trigger the study design update
                        } else self.study.UseCustomArms(false);                        
                    });
            }
        };
        
    };

    /********************************************************/
    /* Viewmodel activation and attachment                  */
    /********************************************************/

    // Load data from previous step and create computed observables as needed
    ctor.prototype.activate = function (settings) {
        var self = this;
        self.study = settings.study;

        // initialize dropdown arrays if needed
        var cohorts = self.study.Cohorts();
        if (cohorts && cohorts.length > 0 && !cohorts[0].treatmentList)
            for (i = 0; i < cohorts.length; i++)
                cohorts[i].treatmentList = self.getCohortDropdown(cohorts[i].References());
      
        // update study design when the related checkbox is toggled
        self.subscriptions.push(self.study.UseDm.subscribe(self.triggerStudyDesignUpdate));

        // update treatments/groups when the related checkboxes are toggled 
        self.subscriptions.push(self.study.UseExRef.subscribe(self.triggerReferenceUpdate));
        self.subscriptions.push(self.study.UseSuppdm.subscribe(self.triggerReferenceUpdate));

        // update treatments/groups when study design changes. A timeout function is
        // used to sync selectize changes with ko-if deletion so we don't get issues
        // by triggering events on non-existing widgets
        var savedOldStudyDesign;
        self.subscriptions.push(self.study.StudyDesign.subscribe(function (oldStudyDesign) {
            savedOldStudyDesign = oldStudyDesign;
        }, null, 'beforeChange'));
        self.subscriptions.push(self.study.StudyDesign.subscribe(function (newStudyDesign) {
            self.triggerReferenceAfterStudyDesign(savedOldStudyDesign, newStudyDesign);
        }));

        // Open study arm customization GUI when the checkbox is clicked
        self.subscriptions.push(self.study.UseCustomArms.subscribe(self.toggleCustomArms));

        // Subscribe all study variable updates
        for (var i = 0; i < self.study.StudyMappings.length; i++) {
            var domain = self.study.StudyMappings[i];
            for (var j = 0; j < domain.DomainMappings.length; j++) {
                var variableMapping = domain.DomainMappings[j];
                if (domain.Type == "DM" && variableMapping.SdtmVariable == "ARM") {
                    var savedArm;
                    var armMapping = variableMapping;
                    self.subscriptions.push(variableMapping.FileVariable
                        .subscribe(function (oldArm) { savedArm = oldArm; }, null, 'beforeChange'));
                    self.subscriptions.push(variableMapping.FileVariable
                        .subscribe(function (newArm) { self.resetCustomArms(savedArm, newArm, armMapping); }));
                } else self.subscriptions.push(variableMapping.FileVariable
                    .subscribe(self.updateStudyDesign));
            }
        }

        // define UI flags to show/hide sections
        self.showBasicStudyDesign = ko.computed(function () {
            return !self.ComputingStudyDesign() && 
                (self.ComputingReferences() || self.study.Cohorts().length == 0);
        });
        self.showCohorts = ko.computed(function () {
            return !self.ComputingStudyDesign() &&
                (!self.ComputingReferences() && self.study.Cohorts().length > 0);
        });
        self.cohortsNotFound = ko.computed(function () {
            return !self.ComputingStudyDesign() &&
                (!self.ComputingReferences() && self.study.Cohorts().length == 0);
        });
    };

    // After viewmodel has been attached to view, get the nda profile
    ctor.prototype.attached = function (view) {
        
    };

    // Clean up
    ctor.prototype.detached = function () {
        var self = this;
        for (i = 0; i < self.subscriptions.length; i++)
            self.subscriptions[i].dispose();
        self.showBasicStudyDesign.dispose();
        self.showCohorts.dispose();
        self.cohortsNotFound.dispose();
    };

    return ctor;
});