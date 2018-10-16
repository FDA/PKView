define('tools/pkView/components/report/reportSummary/reportSummary',
    ['knockout',
    'ocpkmlib/txt'],
function (ko, txt) {

    // This is the createReportSummary viewmodel prototype
    var ctor = function () {
        var self = this;               
    };

    // Load variables from the main view
    ctor.prototype.activate = function (settings) {
        var self = this;
        
        self.NDAName = settings.data.NDAName;
        self.supplements = settings.data.supplements;
        self.supplementNumbers = ko.computed(function () {
            return Object.keys(self.supplements());
        });
        self.analyze = settings.data.analyze;
        self.supplementAnalyzed = settings.data.supplementAnalyzed;
        
        self.unselectedStudies = [];
        if (txt.isNullOrEmpty(self.supplementAnalyzed)) {
            $.each(self.supplements(), function (supplementNumber, supplement) {
                self.unselectedStudies = self.unselectedStudies.concat(supplement.notSelected);
            });
        } else self.unselectedStudies = self.supplements()[self.supplementAnalyzed].notSelected;

        self.successStudies = settings.data.successStudies;
        self.unRunnableStudies = settings.data.unRunnableStudies;
        self.failedStudies = settings.data.failedStudies;
    };

    return ctor;
});