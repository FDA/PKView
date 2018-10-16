define('tools/ogdTool/components/main/sections/units/units', [
        'knockout',
        'shared/api/pkAnalysis/mapping'],
function (ko, sharedModels) {

    // This is the mainWindow viewmodel prototype
    var ctor = function () {
        var self = this;

        self.comparison = null; // Form data for the current comparison
        self.project = null; // project containing the current comparison
    };

    // Load data from previous step and create computed observables as needed
    ctor.prototype.activate = function (settings) {
        var self = this;
        self.comparison = settings.comparison;
        self.project = settings.project;

        // Initialize default units
        self.comparison.aucUnits("ng hr/mL");
        self.comparison.cmaxUnits("ng/mL");
        self.comparison.timeUnits("hr");
    };

    return ctor;
});