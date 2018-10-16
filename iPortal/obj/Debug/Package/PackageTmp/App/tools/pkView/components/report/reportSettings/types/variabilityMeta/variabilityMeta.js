define('tools/pkView/components/report/reportSettings/types/variabilityMeta/variabilityMeta', [
    'knockout',
    'ocpkmlib/net',
    'jqueryUiSortable',
    'shared/api/pkAnalysis/analysis',
    'durandal/app',
    'ocpkmlib/txt'],
function (ko, net, sortable, analysis, app, txt) {

    // This is the createReportSummary viewmodel prototype
    var ctor = function () {
        var self = this;

        self.analytes = []; // Array of study analytes
        self.parameters = []; // Array of study pk parameters
        self.References = ko.observableArray();
        //self.References: ko.observable(true);
        self.MetaCohorts = Array([]);
        // Import list of statistical methods from analysis library
        //self.Does = Array([]);
        self.Doses = ko.observableArray();

        self.statisticalMethods = analysis.statisticalMethods;

        // convert a list of treatments into something usable by the selectize dropdown
        self.getCohortDropdown = function (treatments) {
            return treatments.map(function (treatment) {
                return { text: treatment, value: treatment };
            });
        };

        self.getCohorts = function (References) {
            return References;
        };

        
        self.getCohorts1 = function (References) {
            return References.map(function (Reference) {
                return Reference;
            });
        };

        self.getCohorts2 = function (References) {
            return References.map(function (Reference) {
                return { value: ko.observable(null), MetaCohort: ko.observable(Reference) };
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
                if (analytes().length > 1)
                    analytes.splice(idx, 1);
                else app.showMessage("At least one analyte must remain selected.");
            }
        }

        // Toggle on/off the selected parameter
        self.toggleParameter = function (parameter) {
            var parameters = self.report.Settings.Parameters;
            var idx = parameters.indexOf(parameter);
            if (idx == -1) {
                parameters.push(parameter);
            }
            else {
                parameters.splice(idx, 1);
            }
        };

        // Toggle on/off the selected references
        //self.togglemetatreatmentList = function (metaCohort,index1) {
        //    var MetaCohorts = self.report.Settings.References[index1].MetaCohorts;
        //    var idx = MetaCohorts.indexOf(metaCohort);
        //    if (idx == -1) {
        //        MetaCohorts.push(metaCohort);
        //    }
        //    else {
        //        MetaCohorts.splice(idx, 1);
        //    }
        //};
        self.toggleMetaCohorts = function (metaCohort, index1) {
            var metaCohorts = self.report.Settings.References()[index1].MetaCohorts;
            //var metaCohorts = self.study.Cohorts()[index1].References();

            var idx = metaCohorts.indexOf(metaCohort);
            if (idx == -1) {
                metaCohorts.push(metaCohort);
            }
            else {
                metaCohorts.splice(idx, 1);
                
                
            }
            //alert("self.metaCohorts:" + self.metaCohorts[index1]);

            //alert("metaCohorts:" + metaCohorts);
            //alert("metaCohorts  is ko:" + ko.isObservable(self.report.Settings.References()[index1].MetaCohorts));

            //alert("selfCohorts:" + self.study.Cohorts()[index1].References());
            //alert("MetaCohorts:" + self.References[index1].MetaCohorts());
            //alert(self.References.isObservable);
            //alert(self.References[index1].MetaCohorts.isObservable());
        };
    };

    // Initialize the view
    ctor.prototype.activate = function (activationData) {
        var self = this;

        self.study = activationData.study;

        self.reportId = activationData.reportId;
        self.report = self.study.Reports()[self.reportId];

        self.MetaCohorts = self.study.MetaCohorts;
        //Dosesmappings = self.Doses;
        //self.Doses = self.study.Doses;

        // initialize dropdown arrays if needed
        var cohorts = self.study.Cohorts();
        if (cohorts && cohorts.length > 0 && !self.MetaCohorts[0])
            for (i = 0; i < cohorts.length; i++) {
                self.MetaCohorts[i] = self.getCohorts1(cohorts[i].References());
            }

        if (cohorts && cohorts.length > 0 && !ko.isObservable(self.Doses))
            for (i = 0; i < cohorts.length; i++) {
                self.Doses[i] = self.getCohorts2(cohorts[i].References());
                self.report.Settings.References[i].Doses = ko.observableArray(self.Doses[i]);
                self.study.Doses[i] = self.Doses[i]
            }

        else if (cohorts && cohorts.length > 0 && !ko.isObservable(self.report.Settings.References))
        {
            if (self.report.Settings.References[0].Doses == null || self.report.Settings.References[0].Doses.length == 0)
            {
                for (i = 0; i < cohorts.length; i++) {
                    self.Doses[i] = self.getCohorts2(cohorts[i].References());
                    self.report.Settings.References[i].Doses = ko.observableArray(self.Doses[i]);
                    //self.study.Doses[i] = self.Doses[i];
                }
            }

            else {
            for (i = 0; i < cohorts.length; i++) 
                {
                    self.Doses[i] = self.report.Settings.References[i].Doses;
                    self.report.Settings.References[i].Doses = ko.observableArray(self.Doses[i]);
                    //self.study.Doses[i] = self.Doses[i];
                }
            }
        }
        else if (cohorts && cohorts.length > 0 && ko.isObservable(self.report.Settings.References))
            for (i = 0; i < cohorts.length; i++) {
                self.Doses[i] = self.report.Settings.References()[i].Doses();
            }


        if (cohorts && cohorts.length > 0 && !ko.isObservable(self.report.Settings.References) && self.report.Settings.References[0].MetaCohorts == null) {
            for (i = 0; i < cohorts.length; i++) {

                self.report.Settings.References[i].MetaCohorts = cohorts[i].References;

                //self.report.Settings.References[i].MetaCohortsAndDoses.MetaCohort = cohorts[i].References;
                //self.report.Settings.References[i].Doses = cohorts[i].References;
            }

            //self.report.Settings.References[i] = self.getCohorts1(cohorts[i].References());
        }
        else
            for (i = 0; i < self.report.Settings.References.length; i++) {
                self.report.Settings.References[i].MetaCohorts = ko.observableArray(self.report.Settings.References[i].MetaCohorts);

                //self.report.Settings.References[i].MetaCohortsAndDoses.MetaCohort = ko.observableArray(self.report.Settings.References[i].MetaCohortsAndDoses.MetaCohorts);
                //self.report.Settings.References[i].Doses = ko.observableArray(self.report.Settings.References[i].MetaCohorts);
            }

        if (cohorts && cohorts.length > 0 && !cohorts[0].treatmentList)
            for (i = 0; i < cohorts.length; i++)
                cohorts[i].treatmentList = self.getCohortDropdown(cohorts[i].References());

        // Import variables and functions from main view model
        self.parentModel = activationData.parentModel;
        self.createReportModel = self.parentModel.parentModel;
        self.computingReport = self.createReportModel.computingReport;
        self.generateReport = self.createReportModel.generateReport;
        self.generateMetaAnalysis = self.createReportModel.generateMetaAnalysis;

        // FIXME: compatibility with legacy reports
        if (!self.study.Pharmacokinetics) {
            var a = self.study.Analytes || ko.unwrap(self.report.Settings.Analytes);
            var p = self.study.Parameters || ko.unwrap(self.report.Settings.Parameters);
            self.study.Pharmacokinetics = { Sections: [] };
            self.study.Pharmacokinetics.Sections = a.map(function (a1) {
                return { Analyte: a1, Parameters: p };
            });
        }

        // initialize analytes and parameters
        analytes = []; parameters = [];
        for (var i = 0; i < self.study.Pharmacokinetics.Sections.length; i++) {
            var section = self.study.Pharmacokinetics.Sections[i];

            // Add analyte to the list if missing
            if (analytes.indexOf(section.Analyte) == -1)
                analytes.push(section.Analyte);

            // Add parameters to the list if missing, only add CMAX and AUC
            for (var j = 0; j < section.Parameters.length; j++) {
                var parameter = section.Parameters[j];
                if (parameters.indexOf(parameter) == -1
                    && /.*(AC|AUC|CMAX).*/i.test(parameter))
                    parameters.push(parameter);
            }


        }

        self.analytes = analytes;
        self.parameters = parameters;


        self.analytesForvariability = [];
        for (var j = 0; j < self.analytes.length; j++) {

            self.analytesForvariability.push({ text: self.analytes[j], value: self.analytes[j] });
        };
        self.parametersForvariability = [];
        for (var j = 0; j < self.parameters.length; j++) {

            self.parametersForvariability.push({ text: self.parameters[j], value: self.parameters[j] });
        };

        var References =  self.report.Settings.References;
        //for (var i = 0; i < self.report.Settings.References.length; i++) {
        //    var cohorts1 = self.report.Settings.References[i].MetaCohorts;
        //    for (var j = 0; j < cohorts1.length; j++) {
        //        var metaCohort = cohorts1[j];
        //        metaCohorts[i].push(cohorts1[j]);
        //    }
        //}
        self.References = References;


        // Convert into observables as needed (we just check one of the variables)


        var settings = self.report.Settings;
        if (!ko.isObservable(settings.Analytes)) {

            var a = settings.Analytes || self.analytes.slice(0);
            var p = settings.Parameters || self.parameters.slice(0);
            var u = settings.References || self.References.slice(0);
            var q = self.study.Doses;

            //auu = Array([]);
            //for (i = 1; i < settings.References.length;i++)
            //    auu[i] =  settings.References[i].MetaCohorts;
            settings.References = ko.observableArray(u);
            settings.Analytes = ko.observableArray(a);
            settings.Parameters = ko.observableArray(p);
            self.study.Doses  = ko.observableArray(q);
            for (i = 1; i < settings.References.length;i++)
            //    settings.References[i]=ko.observableArray(u[i]);
            settings.Method = ko.observable(settings.Method);
            settings.Sorting.Folders = ko.observableArray(settings.Sorting.Folders);
            settings.Sorting.Files = ko.observableArray(settings.Sorting.Files);
            settings.Sorting.Columns = ko.observableArray(settings.Sorting.Columns);
        }

        // Available sorting options
        self.SortingOptions = [
            { text: "Analyte", value: "analyte" },
            { text: "Parameter", value: "parameter" },
            { text: "Treatment Comparison", value: "comparison" },
            { text: "Cohort", value: "cohort" },
        ];

        // FIX: Due to a limitation on how the default multiselect browser control works 
        // We need to resort the list of options to make the selected options display the way we want them
        // this fix is also applied to the update functions below
        var fixMultiselectSort = function (itemList, selectedItems) {
            var selected = new Array(), unselected = new Array();
            $.each(itemList, function (id, item) {
                var position = selectedItems.indexOf(item.value);
                if (position != -1) selected[position] = item;
                else unselected.push(item);
            });
            var filteredSelections = $.grep(selected, function (item, id) {
                return typeof (item) != 'undefined';
            });
            return filteredSelections.concat(unselected);
        };

        // Make sure we load file sorting options list in the correct order
        self.folderSortingOptions = ko.observableArray(
            fixMultiselectSort(self.SortingOptions, settings.Sorting.Folders()));

        // Update file options to contain entries that were not selected for folder sorting
        self.fileSortingOptions = ko.observableArray([]);
        var updateFileSortingOptions = function (values) {
            var items = $.grep(self.folderSortingOptions(), function (item, id) {
                // Temporary constraint: only allow "cohort" option (FIX when SAS code allows more flexibility)
                return values.indexOf(item.value) == -1 && item.value == "cohort";
            });
            self.fileSortingOptions(fixMultiselectSort(items, settings.Sorting.Files()));
        };
        updateFileSortingOptions(settings.Sorting.Folders());
        settings.Sorting.Folders.subscribe(updateFileSortingOptions);


        // Update column sorting options to contain entries that were not selected either for 
        // file or folder sorting
        self.columnSortingOptions = ko.observableArray([]);
        var updateColumnSortingOptions = function (values) {
            // TEMP FIX: User folder sorting options as source to bypass cohort option filtering
            // TEMP FIX 2: Forbid cohort selection as option
            /*var items = $.grep(self.fileSortingOptions(), function (item, id) {*/
            var items = $.grep(self.folderSortingOptions(), function (item, id) {
                return values.indexOf(item.value) == -1 && item.value != "cohort";
            });
            self.columnSortingOptions(fixMultiselectSort(items, settings.Sorting.Columns()));
        };
        updateColumnSortingOptions(settings.Sorting.Files());
        settings.Sorting.Files.subscribe(updateColumnSortingOptions);
    };

    // After view is attached
    ctor.prototype.attached = function () {
        var self = this;
        self.idx = self.study.StudyCode + self.reportId;
    };

    return ctor;
});