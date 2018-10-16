define('tools/ogdTool/components/main/sections/dataFiles/dataFiles', [
        'knockout',
        'plugins/dialog',
        'shared/components/modal/viewmodels/modal',
        'shared/api/pkAnalysis/mapping'],
function (ko, dialog, modal, sharedModels) {

    // This is the mainWindow viewmodel prototype
    var ctor = function () {
        var self = this;
       
        self.sharedModels = sharedModels;

        self.comparison = null; // Form data for the current comparison
        self.project = null; // project containing the current comparison

        self.fileSelectionSummary = ko.observable();

        // Open the dialog for data file selection and mapping
        self.selectDataFiles = function () {
            var fileSelectionDialog = new modal({
                title: "Select and load concentration data",
                model: "tools/ogdTool/components/main/sections/dataFiles/fileSelectionDialog",
                activationData: {
                    comparison: self.comparison,
                    project: self.project,
                    done: function () {
                        /// do stuff
                        self.composeFileSelectionSummary();
                        fileSelectionDialog.close();
                    }
                },
                width: 0.9
            });
            dialog.show(fileSelectionDialog);
        };

        // Compose file selections summary
        self.composeFileSelectionSummary = function () {
            var summary = "";
            if (self.comparison.concentrationFile())
                summary += self.comparison.concentrationFile().name;
            if (self.comparison.pkFile())
                summary += ', ' + self.comparison.pkFile().name;
            if (self.comparison.timeFile())
                summary += ', ' + self.comparison.timeFile().name;
            if (self.comparison.keFile())
                summary += ', ' + self.comparison.keFile().name;
            self.fileSelectionSummary(summary);
        };
    };

    // Load data from previous step and create computed observables as needed
    ctor.prototype.activate = function (settings) {
        var self = this;
        self.comparison = settings.comparison;
        self.project = settings.project;
        self.composeFileSelectionSummary();
    }

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