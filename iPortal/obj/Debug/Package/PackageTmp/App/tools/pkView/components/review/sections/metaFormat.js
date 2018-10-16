define('tools/pkview/components/review/sections/metaFormat', [
    'knockout',
    'durandal/app',
    'plugins/dialog',
    'ocpkmlib/net',
    'ocpkmlib/txt'],
function (ko, app, dialog, net, txt) {
    var ctor = function () {
        var self = this;
        self.loading = ko.observable(true);
        self.selectedStudies = ko.observableArray([]); // selected studies
        self.metaformat = ko.observableArray([]);
        self.domain = "";
        self.varName = "";
        self.customize = ko.observable(false);
        self.study = null;
        self.valueMappings = null;
        self.startMetaanalysis = ko.observable(true);

        // Save changes and close the dialog
        self.save = function () {
            var startMetaanalysis = self.startMetaanalysis();
            self.close({ startMetaanalysis: startMetaanalysis });
        };
        


    };    

    // Activate the view
    ctor.prototype.activate = function (settings) {
        var self = this;
        self.analyzableStudies = settings.data.analyzableStudies;
        self.selectedStudies = settings.data.selectedStudies;
        self.metaformat = settings.data.metaformat;
        self.study = settings.study;
        self.domain = settings.domain;
        self.varName = settings.varName;
        self.close = settings.close;
        self.reposition = settings.reposition;
      
        self.AnalysisMethod = [
    { text: "Maximum and Minimum ", value: "Maximum and Minimum " },
    { text: "90% Confidence Interval(CI)", value: "90% Confidence Interval(CI)" },
    ];

        // Attempt to load custom value mappings
        var mappings = settings.mappings;
        if (mappings && mappings.length > 0) {
            self.valueMappings = mappings.map(function (mapping) {
                return {
                    oldValue: mapping.Original,
                    newValue: ko.observable(mapping.New)
                }
            });
            self.customize(true);
        }

        // Subscribe to checkbox toggle
        self.customizeSubscription = self.customize.subscribe(self.customizeToggle);

        self.loading(false);
        setTimeout(self.reposition, 500);
    };

    // Clean up
    ctor.prototype.detached = function () {
        var self = this;
        self.customizeSubscription.dispose();
    };



    return ctor;
});