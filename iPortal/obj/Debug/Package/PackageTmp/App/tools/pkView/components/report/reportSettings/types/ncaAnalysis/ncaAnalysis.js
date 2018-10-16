define('tools/pkView/components/report/reportSettings/types/ncaAnalysis/ncaAnalysis', [
    'knockout',
    'ocpkmlib/net',
    'ocpkmlib/txt',
    'durandal/app',
    'plugins/dialog',
    'shared/components/modal/viewmodels/modal',
], function (ko, net, txt, app, dialog, modal) {

    // This is the createReportSummary viewmodel prototype
    var ctor = function () {
        var self = this;

        self.subscriptions = []; // Array to keep track of subscriptions
        self.ready = ko.observable(false); // UI flag to determine when data is ready to be displayed
        self.invalid = ko.observable(false); // UI flag to indicate input data is not valid

        self.study = null; // Study this report belongs to

        self.cohorts = []; // Study cohort list
        self.periods = {}; // Study period lists by cohort
        self.pcAnalytes = {}; // Study analytes from PC domain by cohort and period
        self.pcSpecimens = {}; // Specimen from PC domain by cohort/period/analyte

        self.ppAnalytes = {}; // Study analytes from PP domain  by cohort and period
        self.ppSpecimens = {}; // Study specimens from PP domain by cohort/period/analyte
        self.ppParameters = {}; // Study pk parameters from PP domain by cohort/period/analyte/specimen

        self.enablePeriod = ko.observable(true); // Enable period dropdown
        self.enablePcAnalyte = ko.observable(true); // Enable Pc Analyte dropdown
        self.enablePcSpecimen = ko.observable(true); // Enable Pc Specimen dropdown

        self.enablePpAnalyte = ko.observable(true); // Enable Pp Analyte dropdown
        self.enablePpSpecimen = ko.observable(true); // Enable pp specimen dropdown
        self.enablePpParameters = ko.observable(true); // Enable pk parameter dropdowns

        self.plots = {}; // plots for each treatment organized by cohort/period/analyte/specimen
        self.plotEvents = {}; // Event structure for the plot objects, applied to every plot     

        // Select a range in the plot in response to simple selection event
        self.selectRange = function (from, to) {
            self.report.Settings.StartTime(from);
            self.report.Settings.EndTime(to);
        };
        self.plotEvents.plotselectedsimple = self.selectRange;

        // Concentration data loading function
        self.loadConcentration = function () {

            var plots = {};
            for (var i = 0; i < self.study.Concentration.Sections.length; i++) {
                var section = self.study.Concentration.Sections[i];

                // Add cohort if missing
                if (!plots[section.Cohort]) {
                    plots[section.Cohort] = {};
                    self.cohorts.push({ text: section.Cohort, value: section.Cohort });
                    self.periods[section.Cohort] = [];
                    self.pcAnalytes[section.Cohort] = {};
                    self.pcSpecimens[section.Cohort] = {};
                }

                // Add Period if missing  or set default
                var period = section.Period || "noPeriod";
                if (!plots[section.Cohort][period]) {
                    plots[section.Cohort][period] = {}
                    self.periods[section.Cohort].push({ text: section.Period || "(default)", value: period });
                    self.pcAnalytes[section.Cohort][period] = [];
                    self.pcSpecimens[section.Cohort][period] = {};
                }

                // Add Analyte if missing
                if (!plots[section.Cohort][period][section.Analyte]) {
                    plots[section.Cohort][period][section.Analyte] = {};
                    self.pcAnalytes[section.Cohort][period].push({ text: section.Analyte, value: section.Analyte });
                    self.pcSpecimens[section.Cohort][period][section.Analyte] = [];
                }

                // Add Specimen if missing or set default
                var specimen = section.Specimen || "noSpecimen";
                if (!plots[section.Cohort][period][section.Analyte][specimen]) {
                    plots[section.Cohort][period][section.Analyte][specimen] = { data: [], events: self.plotEvents };
                    self.pcSpecimens[section.Cohort][period][section.Analyte].push({ text: section.Specimen || "(default)", value: specimen });
                }

                var plot = plots[section.Cohort][period][section.Analyte][specimen];
                plot.data.push({
                    label: section.TreatmentOrGroup,
                    data: section.Mean.map(function (point) {
                        var dataPoint = [];
                        dataPoint.push(point.NominalTime);
                        dataPoint.push(point.Value);
                        dataPoint.push(point.StandardDeviation);
                        return dataPoint;
                    })
                });                
            }
            self.plots = plots;
        };

        // Pk data loading function
        self.loadPk = function () {

            var periodMap = {};
            for (var i = 0; i < self.study.Pharmacokinetics.Sections.length; i++) {
                var section = self.study.Pharmacokinetics.Sections[i];

                // Simple error checking, verify cohorts match between domains
                if (!self.plots[section.Cohort]) {
                    app.showMessage('Cohorts do not match between PC and PP domains', 'Error', ['Ok']);
                    self.invalid(true);
                    return;
                }

                // Map the period to a pc period 
                var period = section.Period || "noPeriod";
                if (!periodMap[period]) {

                    // If period is not present in pc attempt best matching as possible 
                    if (!self.plots[section.Cohort][period]) {

                        // Warn the user this period doesnt match the first time it is found
                        var periodList = self.periods[section.Cohort].map(function (p) { return p.value; });
                        var periodListText = periodList.join(', ');
                        app.showMessage('Periods do not match between PC and PP domains. ' +
                        'Period "' + period + '" from PP domain not found in PC (periods in PC: ' +
                        periodListText + ').', 'Warning', ['Ok']);

                        var mappedCount = Object.keys(periodMap).length;
                        if (mappedCount < periodList.length) {
                            periodMap[period] = periodList[mappedCount];
                        } else periodMap[period] = "unused";

                    // Map the period to the same name period in pc
                    } else periodMap[period] = period;
                } 
                period = periodMap[period];   

                // Initialize array of periods in cohort
                if (!self.ppAnalytes[section.Cohort]) {
                    self.ppAnalytes[section.Cohort] = {};
                    self.ppSpecimens[section.Cohort] = {};
                    self.ppParameters[section.Cohort] = {};
                }

                // Initialize array of analytes in period
                if (!self.ppAnalytes[section.Cohort][period]) {
                    self.ppAnalytes[section.Cohort][period] = [];
                    self.ppSpecimens[section.Cohort][period] = {};
                    self.ppParameters[section.Cohort][period] = {};
                }

                // Add Analyte if missing
                if (!self.ppSpecimens[section.Cohort][period][section.Analyte]) {
                    self.ppAnalytes[section.Cohort][period].push({ text: section.Analyte, value: section.Analyte });
                    self.ppSpecimens[section.Cohort][period][section.Analyte] = [];
                    self.ppParameters[section.Cohort][period][section.Analyte] = {};
                }

                // Add Specimen if missing or set default
                var specimen = section.Specimen || "noSpecimen";
                if (!self.ppParameters[section.Cohort][period][section.Analyte][specimen]) {
                    self.ppSpecimens[section.Cohort][period][section.Analyte].push({ text: section.Specimen || "(default)", value: specimen });
                    self.ppParameters[section.Cohort][period][section.Analyte][specimen] = {};
                }

                // Add parameters to the list
                for (var j = 0; j < section.Parameters.length; j++) {
                    var parameter = section.Parameters[j];
                    self.ppParameters[section.Cohort][period][section.Analyte][specimen][parameter] = 1;
                }
            }

            // Convert pk parameter list to dropdown objects
            for (var cohort in self.ppParameters) {
                var cohortParams = self.ppParameters[cohort];
                for (var period in cohortParams) {
                    var periodParams = cohortParams[period];
                    for (var analyte in periodParams) {
                        var analyteParams = periodParams[analyte];
                        for (var specimen in analyteParams) {
                            var parameters = Object.keys(analyteParams[specimen]).sort().map(function (p) { return { text: p, value: p }; });
                            parameters.unshift({ text: "", value: "" });
                            self.ppParameters[cohort][period][analyte][specimen] = parameters;
                        }
                    }
                }
            }
        };

        // Create and intitialize observables for the settings
        self.createObservables = function () {

            var settings = self.report.Settings;

            var c = settings.SelectedCohort || self.cohorts[0].value;
            var p = settings.SelectedPeriod || self.periods[c][0].value;
            var pcA = settings.SelectedPcAnalyte || self.pcAnalytes[c][p][0].value;
            var pcS = settings.SelectedPcSpecimen || self.pcSpecimens[c][p][pcA][0].value;

            settings.SelectedCohort = ko.observable(c);
            settings.SelectedPeriod = ko.observable(p);
            settings.SelectedPcAnalyte = ko.observable(pcA);
            settings.SelectedPcSpecimen = ko.observable(pcS);

            var ppA = settings.SelectedPpAnalyte;
            var ppS = settings.SelectedPpSpecimen;
            var ppAuct = settings.SelectedAuct || "";
            var ppAucInf = settings.SelectedAucInfinity || "";
            var ppCmax = settings.SelectedCmax || "";
            var ppThalf = settings.SelectedThalf || "";
            var ppTmax = settings.SelectedTmax || "";

            if (!ppA || !ppS) {
                if (self.ppAnalytes[c] && self.ppAnalytes[c][p]) {
                    ppA = self.ppAnalytes[c][p][0].value;
                    ppS = self.ppSpecimens[c][p][ppA][0].value;
                } else {
                    self.enablePpAnalyte(false);
                    self.enablePpSpecimen(false);
                    self.enablePpParameters(false);
                }
            }

            settings.SelectedPpAnalyte = ko.observable(ppA);
            settings.SelectedPpSpecimen = ko.observable(ppS);
            settings.SelectedAuct = ko.observable(ppAuct);
            settings.SelectedAucInfinity = ko.observable(ppAucInf);
            settings.SelectedCmax = ko.observable(ppCmax);
            settings.SelectedThalf = ko.observable(ppThalf);
            settings.SelectedTmax = ko.observable(ppTmax);

            settings.StartTime = ko.observable(settings.StartTime || null);
            settings.EndTime = ko.observable(settings.EndTime || null);

            self.subscriptions.push(settings.SelectedCohort.subscribe(function (c) {
                self.enablePeriod(false);
                settings.SelectedPeriod(self.periods[c][0].value);
                self.enablePeriod(true);
                settings.SelectedPeriod.valueHasMutated();
            }));
            self.subscriptions.push(settings.SelectedPeriod.subscribe(function (p) {
                var c = settings.SelectedCohort();
                self.enablePcAnalyte(false);                
                settings.SelectedPcAnalyte(self.pcAnalytes[c][p][0].value);
                self.enablePcAnalyte(true);
                settings.SelectedPcAnalyte.valueHasMutated();
                self.enablePpAnalyte(false);
                if (self.ppAnalytes[c] && self.ppAnalytes[c][p]) {
                    settings.SelectedPpAnalyte(self.ppAnalytes[c][p][0].value);
                    self.enablePpAnalyte(true);                    
                }
                settings.SelectedPpAnalyte.valueHasMutated();
            }));
            self.subscriptions.push(settings.SelectedPcAnalyte.subscribe(function (pcA) {
                var c = settings.SelectedCohort();
                var p = settings.SelectedPeriod();
                self.enablePcSpecimen(false);
                settings.SelectedPcSpecimen(self.pcSpecimens[c][p][pcA][0].value);
                self.enablePcSpecimen(true);
                settings.SelectedPcSpecimen.valueHasMutated();
            }));
            self.subscriptions.push(settings.SelectedPpAnalyte.subscribe(function (ppA) {
                var c = settings.SelectedCohort();
                var p = settings.SelectedPeriod();
                self.enablePpSpecimen(false);
                if (self.ppSpecimens[c] && self.ppSpecimens[c][p]) {
                    settings.SelectedPpSpecimen(self.ppSpecimens[c][p][ppA][0].value);
                    self.enablePpSpecimen(true);
                }
                settings.SelectedPcSpecimen.valueHasMutated();
            }));
            self.subscriptions.push(settings.SelectedPpSpecimen.subscribe(function (ppS) {
                var c = settings.SelectedCohort();
                var p = settings.SelectedPeriod();
                self.enablePpParameters(false);
                settings.SelectedAuct("");
                settings.SelectedAucInfinity("");
                settings.SelectedCmax("");
                settings.SelectedThalf("");
                settings.SelectedTmax("");
                if (self.ppParameters[c] && self.ppParameters[c][p])
                    self.enablePpParameters(true);                
            }));
        };
    };

    // Initialize the view
    ctor.prototype.activate = function (activationData) {
        var self = this;

        self.study = activationData.study;
        self.reportId = activationData.reportId;
        self.report = self.study.Reports()[self.reportId];

        // Load concentration data
        self.loadConcentration();
        self.loadPk();
        if (self.invalid()) return; // If concentration does not match pk do not continue

        // Import variables and functions from main view model
        self.parentModel = activationData.parentModel;
        self.createReportModel = self.parentModel.parentModel;
        self.computingReport = self.createReportModel.computingReport;
        self.generateReport = self.createReportModel.generateReport;

        // Create and initialize observables for the settings if needed
        if (!self.report.Settings.SelectedCohort ||
            !ko.isObservable(self.report.Settings.SelectedCohort)) {
            self.createObservables();
        }

        // Computed observable to display the currently selected time interval
        self.currentInterval = ko.computed(function () {
            if (self.report.Settings.StartTime() != null)
                return "[" + self.report.Settings.StartTime() + "," +
                    self.report.Settings.EndTime() + "]";
            else return "(no selection - plot everything)";
        });

        self.ready(true);             
    };

    // After view is attached
    ctor.prototype.attached = function (view) {
        var self = this;
        self.idx = self.study.StudyCode + self.reportId;
    };

    // Clean up
    ctor.prototype.detached = function (view) {
        var self = this;
        if (self.currentInterval) self.currentInterval.dispose();
        for (var i = 0; i < self.subscriptions; i++)
            self.subscriptions[i].dispose();
    };

    return ctor;
});