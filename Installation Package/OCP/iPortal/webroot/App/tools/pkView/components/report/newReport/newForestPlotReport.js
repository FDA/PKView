define('tools/pkView/components/report/newReport/newForestPlotReport', [
    'knockout',
    'durandal/app',
    'plugins/dialog',
    'ocpkmlib/net',
    'ocpkmlib/txt'],
function (ko, app, dialog, net, txt) {
    var ctor = function () {
        self = this;
        
        self.responseReady = ko.observable(false); // server response flag 
        self.selectedStudyIdx = ko.observable(); // study where a new report is going to be created
        self.selectedReportType = ko.observable("1"); // type of report we are going to generate 
        self.reportName = ko.observable(); // Unique name to identify the report

        // Types of report
        self.reportTypes = [
             //{ text: "Statistical Table", id: 1 },
            { text: "Forest Plot", id: 1 },            
            //{ text: "Non Compartmental Analysis", id: 3 }            
            //{ text: "Concentration-Time Profile", id: 4 },
        ];

        // Filter out invalid keystrokes
        self.characterBlacklist = [',','^','&','\'','=','.','/','\\','?'];
        self.filterKeys = function (data, event) {
            var char = String.fromCharCode(event.which);
            return self.characterBlacklist.indexOf(char) == -1;                         
        }

        // Choose a unique name for the new report
        self.chooseName = function () {
            var nameBase = self.reportTypes[self.selectedReportType() - 1].text;
            var newName = "Custom " + nameBase;
            var nameId = 1;
            var nameCollision = false;
            do {
                nameCollision = false;
                $.each(self.selectedStudy().Reports(), function (i, report) {
                    if (report.Name == newName) {
                        newName = "Custom " + nameBase + ' (' + nameId + ')';
                        nameId++;
                        nameCollision = true;
                    }
                });
            } while (nameCollision);
            return newName;
        };

        self.createNew = function () {
            var study = self.selectedStudy();
            
            if (study.Reports().length > 0) {
                app.showMessage('You already have 1 forest plot', 'PkView', ['OK'])
            .then(function (answer) { if (answer == 'OK') self.close(); });
                return;
            }
            //// Only allow nca analysis on studies with concentration data
            //if (reportNames.indexOf(newReportName) != -1) {
            //    app.showMessage('A report already exists with this name, please select a different name for your new report.', 'PkView', ['OK']);
            //    return;
            //}

            //Verify the report name is unique
            var newReportName = $.trim(self.reportName());
            var reportNames = $.map(study.Reports(), function (report, i) {
                return report.Name;
            });
            if (reportNames.indexOf(newReportName) != -1) {
                app.showMessage('A report already exists with this name, please select a different name for your new report.', 'PkView', ['OK']);
                return;
            }

            // Copy the list of cohort reference selections
            var references = $.map(study.Cohorts(), function (cohort, i) {
                return { Cohort: cohort.Name, Reference: ko.observable(ko.unwrap(cohort.Reference)), MetaCohorts: null };
            });

            // Columns defaults for forest plot and statistical table are different
            var sortColumns = ["analyte", "comparison", "parameter"];
            //if (self.selectedReportType() == "1") sortColumns.push("cohort");
            //if(study.Reports().length > 0)
            //study.Reports.splice(0, 1);
            // Add the report to the study
            study.Reports.push({
                Name: newReportName,
                Type: parseInt(self.selectedReportType()),
                Generated: ko.observable(false),
                CreationDate: ko.observable(null),
                Settings: {
                    References: references,
                    Method: "paired",
                    Sorting: {
                        Folders: [],
                        Files: [],
                        Columns: sortColumns
                    }
                }
            });

            self.done({ study: study, reportId: 0 });
        };
    };

    // Activate the view
    ctor.prototype.activate = function (settings) {
        var self = this;
  
        self.studies = settings.studies;
        self.done = settings.done;

        // Add index to study list
        self.studyList = $.map(settings.studies(), function (study, idx) {
            var listItem = { idx: idx, studyName: study.StudyCode };
            if (settings.SelectedSupplement == '')
                listItem.studyName = listItem.studyName + " (" + study.SupplementNumber + ")";
            return listItem;
        });

        // Compute index of selected study
        for (var i = 0, len = self.studies().length; i < len; i++) {
            var study = self.studies()[i];
            if (study.StudyCode == settings.defaultStudy &&
                study.SupplementNumber == settings.defaultSupplement)
                self.selectedStudyIdx(i);
        }

        // computed observable to get the actual selected study object
        self.selectedStudy = ko.computed(function () {
            return self.studies()[self.selectedStudyIdx()];
        });

        // Select a new name for the report
        self.reportName(self.chooseName());
        self.reportTypeSubscription = self.selectedReportType.subscribe(function () {
            self.reportName(self.chooseName());
        });
    };

    // After view is attached
    ctor.prototype.attached = function (view) {
        var self = this;     
    };

    // Before view is detached, clean up
    ctor.prototype.detached = function () {
        var self = this;
        self.reportTypeSubscription.dispose();
        self.selectedStudy.dispose();
    };

    ctor.prototype.close = function () {
        var self = this;

        self.close();
    };

    return ctor;
});