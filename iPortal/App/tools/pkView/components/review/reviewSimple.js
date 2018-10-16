define('tools/pkView/components/review/reviewSimple', [
        'knockout',
        'shared/components/dataDialog/viewmodels/dataDialog',
        'shared/components/errorDialog/viewmodels/errorDialog',
        'ocpkmlib/net',
        'ocpkmlib/txt',
        'durandal/app',
        'plugins/dialog',
        'shared/api/pkAnalysis/mapping'],
function (ko, dataDialog, errorDialog, net, txt, app, dialog, mapping) {

    // This is the mainWindow viewmodel prototype
    var ctor = function () {
        var self = this;

        /* Mapping screen variables */
        self.StudyDesignTypes = mapping.studyDesignTypes; // Study Design Types
        self.domainDescriptions = mapping.domainDescriptions; // Domain descriptions
        self.sdtmVariables = mapping.sdtmVariables; // Sdtm variables description and importance
        self.isOptionalVariable = mapping.isOptionalVariable; // Api function to determine if a variable is optional 

        /* Study arrays */
        self.studies = ko.observableArray([]);  // Array of study mapping settings 
        self.unmappable = ko.observableArray([]); // Array of study names for studies that cannot be mapped
        self.totalStudies = ko.computed(function () {
            return self.studies().concat(self.unmappable());
        });

        // View domain data
        self.viewData = function (domain) {
            dialog.show(new dataDialog(domain.FileId, self.domainDescriptions[domain.Type] + " File Data"));
        };

        // Change the quality value of the mapping to good when the user edits the value
        self.changeQuality = function (item) {
            item.mapping.MappingQuality(1);
        };                              
    };

    // Load variables from the main mapping view
    ctor.prototype.activate = function (settings) {
        var self = this;
        self.NDAName = settings.data.NDAName;
        self.ProfileName = settings.data.ProfileName;
        self.studies = settings.data.studies;
        self.unmappable = settings.data.unmappable;
        self.unselected = settings.data.unselected;
        self.validMappings = settings.data.validMappings;

        self.splash = settings.data.splash;
        self.error = settings.data.error;

        //// Compute list of unmapped compulsory and optional variables
        //self.unmapped = [];
        //$.each(self.studies(), function (i, study) {
        //    $.each(study.Unmapped, function (i, mapping) {
        //        self.unmapped.push(mapping);
        //    });
        //});
    };

    ctor.prototype.attached = function (view) {
        var self = this;
    };

    return ctor;
});