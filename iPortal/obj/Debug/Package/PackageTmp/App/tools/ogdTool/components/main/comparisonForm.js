define('tools/ogdTool/components/main/comparisonForm', [
        'knockout',
        'shared/components/dataDialog/viewmodels/dataDialog',
        'shared/components/errorDialog/viewmodels/errorDialog',
        'ocpkmlib/net',
        'ocpkmlib/txt',
        'durandal/app',
        'plugins/dialog',
        'shared/api/pkAnalysis/mapping',
        'tools/pkView/lib/pkViewSubmissionProfile'],
function (ko, dataDialog, errorDialog, net, txt, app, dialog, mapping, profile) {

    // This is the mainWindow viewmodel prototype
    var ctor = function () {
        var self = this;
    
        self.comparison = null; // Form data for the current comparison
        self.project = null; // project containing the current comparison

        // Form Sections
        self.subSections = [
            { title: "Data files", model: "tools/ogdTool/components/main/sections/dataFiles/dataFiles" },
            { title: "Plot labels", model: "tools/ogdTool/components/main/sections/labels/labels" },
            { title: "Units", model: "tools/ogdTool/components/main/sections/units/units" },
            { title: "Ke calculation", model: "tools/ogdTool/components/main/sections/kecalculation/kecalculation" }
        ];
    };

    // Load data from previous step and create computed observables as needed
    ctor.prototype.activate = function (settings) {
        var self = this;
        self.comparison = settings.comparison;
        self.project = settings.project;
    }

    // After viewmodel has been attached to view, get the nda profile
    ctor.prototype.attached = function (view) {
        var self = this;
        /*var promise = profile.get(self);
        promise.then(function (supplements) {
            self.prepareData(supplements);
            self.showInterface(supplements);
        });
        promise.fail(self.error);*/
    };

    // Clean up
    ctor.prototype.detached = function () {
        var self = this;

       /* // Disable resize event as we are not using tabs anymore
        $(window).off("resize.pkViewMappings");

        // dispose computed observables
        self.refreshMappingQuality.dispose();
        self.totalStudies.dispose();
        self.dropdownTitle.dispose();

        self.cancelRequests = true;*/
    };

    return ctor;
});