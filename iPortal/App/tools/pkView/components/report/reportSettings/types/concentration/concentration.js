define('tools/pkView/components/report/reportSettings/types/concentration/concentration', [
    'knockout',
    'durandal/app',
    'plugins/dialog',
    'shared/components/modal/viewmodels/modal',
], function (ko, app, dialog, modal) {

    // This is the createReportSummary viewmodel prototype
    var ctor = function () {
        var self = this;
        self.study = null; // Study this report belongs to
        self.analytes = []; // Array of analytes in the concentration data
        self.plots = []; // 2 dim array of plots by analyte by cohort
        self.plotEvents = {}; // Event structure for the plot objects
        self.multiCohort = false; // UI flag, true if #cohorts > 1
        self.currentCohort = ko.observable(0); // Currently selected tab cohort
        self.currentAnalyte = ko.observable(0); // Currently selected tab analyte
        
        // convert a list of treatments into something usable by the selectize dropdown
        self.getCohortDropdown = function (treatments) {
            return treatments.map(function (treatment) {
                return { text: treatment, value: treatment };
            });
        };

        // Toggle on/off the selected analyte
        self.toggleAnalyte = function (analyte) {
            var analytes = self.report.Settings.Analytes;
            var idx = analytes.indexOf(analyte);
            if (idx == -1) {
                analytes.push(analyte);
            }
            else {
                if (analytes().length > 1) {
                    analytes.splice(idx, 1);
                    
                    // find out if a new tab must be selected and select it
                    if (self.plots[self.currentCohort()].plots[self.currentAnalyte()].analyte == analyte) {
                        var found = false;
                        for (i = 0; i < self.plots.length; i++) {
                            for (j = 0; j < self.plots[i].plots.length; j++) {
                                if (analytes.indexOf(self.plots[i].plots[j].analyte) != -1) {
                                    found = true;
                                    self.currentAnalyte(0);
                                    self.currentCohort(i);
                                    self.currentAnalyte(j);
                                    break;
                                }
                            }
                            if (found) break;
                        }
                    }                    
                } else app.showMessage("At least one analyte must remain selected.");
            }
        };

        // Activate a plot tab
        self.activateTab = function (cohortIdx, analyteIdx) {
            self.currentAnalyte(0); // reset analyte idx so we dont render a missing plot
            self.currentCohort(cohortIdx);
            self.currentAnalyte(analyteIdx);
        };

        // Select a range in the plot
        self.selectRange = function (from, to) {
            var idx = 0;
            for (var i = 0; i < self.currentCohort() ; i++)
                idx += self.plots[i].length;
            var timeInterval = self.report.Settings.TimeSelections[idx + self.currentAnalyte()];
            timeInterval.Start(from);
            timeInterval.End(to);
        };
        self.plotEvents.plotselectedsimple = self.selectRange;

        // Review the mapping of the time points
        self.reviewTimePoints = function () {

            var dfd = $.Deferred();

            var reviewTimeDialog = new modal({
                title: "Review time point mapping",
                model: "tools/pkView/components/report/reportSettings/types/concentration/reviewTime",
                activationData: {
                    timeMappings: self.study.Concentration.NormalizedTimePoints,                    
                },
                width: 0.9
            });
            dialog.show(reviewTimeDialog)
                .then(function (result) {
                    debugger;
                    if (result) {

                        self.study.Concentration.NormalizedTimePoints = result.map(function (mapping) {
                            return {
                                RawTime: mapping.raw,
                                NormalizedTime: mapping.normalized(),
                            };
                        });

                        for (var i = 0; i < self.plots.length; i++) {
                            var cohortPlots = self.plots[i].plots;
                            for (var j = 0; j < cohortPlots.length; j++) {
                                analyteCurves = cohortPlots[j].plots.data;
                                for (var k = 0; k < analyteCurves.length; k++) {
                                    debugger;
                                }
                            }
                        }
                    //    if (result.customize) {
                    //        study[listName] = result.mappings.map(function (mapping) {
                    //            return {
                    //                Original: mapping.oldValue,
                    //                New: ko.unwrap(mapping.newValue)
                    //            };
                    //        });
                    //    } else study[listName] = null;
                    //    study[flagName] = result.customize;
                    //    self.editingValues = true;
                    //    variable.FileVariable.valueHasMutated();
                    //    self.editingValues = false;
                    }

                    dfd.resolve();
                });

            return dfd;
        };
    };

    // Initialize the view
    ctor.prototype.activate = function (activationData) {
        var self = this;
        
        self.study = activationData.study;
        self.reportId = activationData.reportId;
       // Convert concentration curves to flot format
        var plots = {};

        for (var i = 0; i < self.study.Concentration.Means.length; i++) {
            var curve = self.study.Concentration.Means[i];
            
            // Add cohort if missing
            if (!plots[curve.Cohort])
                plots[curve.Cohort] = {};

            // Add Analyte if missing
            if (!plots[curve.Cohort][curve.Analyte]) {
                plots[curve.Cohort][curve.Analyte] = { data: [], events: self.plotEvents };
            }

            // Add plot data 
            plots[curve.Cohort][curve.Analyte].data.push({
                label: curve.TreatmentOrGroup,
                data: curve.Points.map(function (point) {
                    var dataPoint = [];
                    dataPoint.push(point.NominalTime);
                    dataPoint.push(point.Mean);
                    dataPoint.push(point.StandardDeviation);
                    return dataPoint;
                })
            });
            
        }
        // convert the object hierarchy into array
        self.plots = $.map(plots, function (analytes, cohort) {
            return {
                cohort: cohort,
                plots: $.map(analytes, function (treatments, analyte) {
                    return {
                        analyte: analyte,
                        plots: treatments
                    };
                })
            };
        });
        self.multiCohort = self.plots.length > 1;

        // initialize dropdown arrays if needed
        var cohorts = self.study.Cohorts();
        if (cohorts && cohorts.length > 0 && !cohorts[0].treatmentList)
            for (i = 0; i < cohorts.length; i++)
                cohorts[i].treatmentList = self.getCohortDropdown(cohorts[i].References());      

        // Import variables and functions from main view model
        self.parentModel = activationData.parentModel;
        self.createReportModel = self.parentModel.parentModel;
        self.computingReport = self.createReportModel.computingReport;
        self.generateReport = self.createReportModel.generateReport;

        self.report = self.study.Reports()[self.reportId];

        // initialize the analyte array
        for (var i = 0; i < self.plots.length; i++) {
            for (var j = 0; j < self.plots[i].plots.length; j++) {
                var analyte = self.plots[i].plots[j].analyte;
                if (self.analytes.indexOf(analyte) == -1)
                    self.analytes.push(analyte);
            }
        }
        if (!self.report.Settings.Analytes)
            self.report.Settings.Analytes = self.analytes.slice(0);

        // Create time selection array if not present
        if (!self.report.Settings.TimeSelections) {
            self.report.Settings.TimeSelections = [];
            for (var i = 0; i < self.plots.length; i++)
                for (var j = 0; j < self.plots[i].plots.length; j++)
                    self.report.Settings.TimeSelections.push({
                        Cohort: self.plots[i].cohort,
                        Analyte: self.plots[i].plots[j].analyte,
                        Start: ko.observable(null),
                        End: ko.observable(null)
                    });
        } else { // Otherwise just initialize observables
            var ts = self.report.Settings.TimeSelections;
            for (var i = 0; i < ts.length; i++) {
                ts[i].Start = ko.observable(ko.unwrap(ts[i].Start));
                ts[i].End = ko.observable(ko.unwrap(ts[i].End));
            }
        }

        // Observable to display the currently selected time interval
        self.currentInterval = ko.computed(function () {
            var idx = 0;
            for (var i = 0; i < self.currentCohort(); i++)
                idx += self.plots[i].length;
            var timeInterval = self.report.Settings.TimeSelections[idx +self.currentAnalyte()];
            if (timeInterval.Start() != null)
                return "[" + timeInterval.Start() + "," + timeInterval.End() + "]";
            else return "(no selection - plot everything)";
        });

        // Convert into observables as needed (we just check one of the variables)
        var settings = self.report.Settings;
        if (!ko.isObservable(settings.Analytes)) {
            settings.Analytes = ko.observableArray(settings.Analytes);
            settings.Parameters = ko.observableArray(settings.Parameters);
            settings.Method = ko.observable(settings.Method);
            settings.Sorting.Folders = ko.observableArray(settings.Sorting.Folders);
            settings.Sorting.Files = ko.observableArray(settings.Sorting.Files);
            settings.Sorting.Columns = ko.observableArray(settings.Sorting.Columns);

            settings.from = ko.observable();
            settings.to = ko.observable();
        }
    };

    // After view is attached
    ctor.prototype.attached = function (view) {
        var self = this;
        self.idx = self.study.StudyCode + self.reportId;
    };

    // Clean up
    ctor.prototype.detached = function (view) {
        var self = this;
        self.currentInterval.dispose();6
    };

    return ctor;
});