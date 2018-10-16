define('tools/pkView/components/review/sections/studyVariabilityMeta', [
    'knockout'],
function (ko) {

    // This is the createReportSummary viewmodel prototype
    var ctor = function () {
        var self = this;

        // Load or create study report settings
        self.loadOrCreateStudySettings = function () {

            // For each study
            $.each(self.allStudies(), function (i, study) {

                // If study does not contain valid reference/analytes/parameters 
                // we consider it not analyzed and thus not able to generate reports
                study.Analyzable = (
                    study.StudyError == 0
                    && ((typeof (study.Cohorts) != 'undefined' // legacy
                        && study.Cohorts().length > 0
                        && typeof (study.Analytes) != 'undefined'
                        && study.Analytes != null
                        && study.Analytes.length > 0
                        && typeof (study.Parameters) != 'undefined'
                        && study.Parameters != null
                        && study.Parameters.length > 0)
                    ) || (
                        typeof (study.Pharmacokinetics) != 'undefined' // new data structures
                        && study.Pharmacokinetics != null
                        && study.Pharmacokinetics.Sections.length > 0
                    ));

                // Load reports only if study can be analyzed
                if (study.Analyzable) {
                    // Set as active study if none is set
                    if (self.activeStudy() == "") {
                        self.activeStudy(study.StudyCode);
                        self.activeSupplement(study.SupplementNumber);
                    }

                    // Load Existing Reports
                    if (study.Reports != null && study.Reports.length > 0) {
                        // Convert creation dates into real Date type objects as needed
                        $.each(study.Reports, function (j, report) {
                            if (!ko.isObservable(report.CreationDate)) {
                                if (report.CreationDate != null)
                                    report.CreationDate = new Date(report.CreationDate);
                                report.CreationDate = ko.observable(report.CreationDate);
                                report.Generated = ko.observable(report.Generated);
                            }
                        });
                        // Set this study and its first report as active if there is not active report                       
                        if (self.activeReportId() == null) {
                            self.activeStudy(study.StudyCode);
                            self.activeSupplement(study.SupplementNumber);
                            self.activeReportId(0);
                        }
                    }
                }
                if (!ko.isObservable(study.Reports))
                    study.Reports = ko.observableArray(study.Reports || []);
            });

            self.analyzableChanged.notifySubscribers();
        };

        // Activate a report
        self.activateReport = function (study, reportId) {
            self.activeStudy(study.StudyCode);
            self.activeSupplement(study.SupplementNumber);
            if (reportId < study.Reports().length)
                self.activeReportId(reportId);
        };

        

    };

    // Load variables from the main view
    ctor.prototype.activate = function (settings) {
        var self = this;
        self.NDAName = settings.data.NDAName;
        self.SelectedSupplement = settings.data.SelectedSupplement;
        self.studies = settings.data.studies;
        self.validStudies = settings.data.validStudies;
        self.analyzableChanged = settings.data.analyzableChanged;
        self.analyzableStudies = settings.data.analyzableStudies;
        self.allStudies = settings.data.allStudies;
        self.totalStudies = settings.data.totalStudies;
        self.unMappableStudies = settings.data.unmappable;
        self.unselectedStudies = settings.data.unselected;
        self.successStudies = settings.data.successStudies;
        self.unRunnableStudies = settings.data.unRunnableStudies;
        self.failedStudies = settings.data.failedStudies;

        self.activeStudy = settings.data.activeStudy;
        self.activeSupplement = settings.data.activeSupplement;
        self.activeReportId = settings.data.activeReportId;
        self.study = settings.data.study;

        self.parentModel = settings.data;



        for (i = 0; i < self.validStudies().length;i++)
        {
            for (j = 0; j < self.validStudies()[i].Reports.length; j++)
            {
                var z=self.validStudies()[i].Reports.length;
                if (self.validStudies()[i].Reports[j].Type == 6)
                    self.validStudies()[i].Reports.splice(0, 0, self.validStudies()[i].Reports.splice(j, 1)[0]);
            }
        }

        // Computed observable to set the viewmodel according to the report type
        self.reportSettingsView = ko.computed(function () {

            // In some instances this may be called when a study is not selected, prevent error (FIXME)
            var currentStudy = self.parentModel.study();

            // If report id is set null load an empty model
            if (self.activeReportId() == null
                || typeof (currentStudy) == 'undefined'
                || ko.unwrap(currentStudy.Reports).length == 0
                || (self.activeReportId() < 0)
                || (self.activeReportId() > ko.unwrap(currentStudy.Reports).length - 1))
                return {
                    model: 'tools/pkView/components/report/reportSettings/types/empty/empty',
                    data: self.analyzableStudies().length > 0
                };

            // Select the target viewModel for the current report
            var currentReport = ko.unwrap(currentStudy.Reports)[self.activeReportId()];
            var model = "tools/pkView/components/report/reportSettings/types/variabilityMeta/variabilityMeta";
            

            // Return the viewmodel and the data
            return {
                model: model,
                data: {
                    parentModel: self,
                    study: self.study(),
                    reportId: self.activeReportId()
                }
            };
        });

        self.loadOrCreateStudySettings();
    };

    // Clean up
    ctor.prototype.detached = function () {
        var self = this;

        // dispose computed observables
        self.reportSettingsView.dispose();
    };

    return ctor;
});