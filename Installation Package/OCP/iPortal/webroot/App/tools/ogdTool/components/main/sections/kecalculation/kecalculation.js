define('tools/ogdTool/components/main/sections/kecalculation/kecalculation', [
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
    };

    return ctor;
});