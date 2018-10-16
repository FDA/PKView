define('tools/ogdTool/models', [
    'knockout',
],
function (ko) {

    var self = {};

    var DataFile = function (data) {
        this.path = data.Path;
        this.name = data.Path.split(/[\\\/]/).pop();
    };

    var Comparison = function (data) {
        this.title = data.Title;

        this.level = ko.observable(data.Level || null);
        this.dose  = ko.observable(data.Dose || null);
        this.drug  = ko.observable(data.Drug || null);
        this.studyType = ko.observable(data.StudyType || null);

        this.aucUnits = ko.observable(data.AucUnits || null);
        this.cmaxUnits = ko.observable(data.CmaxUnits || null);
        this.timeUnits = ko.observable(data.TimeUnits || null);

        this.concentrationFile = ko.observable(null);
        this.pkFile = ko.observable(null);
        this.timeFile = ko.observable(null);
        this.keFile = ko.observable(null);

        if (data.ConcentrationFile)
            this.concentrationFile(new DataFile(data.ConcentrationFile));        
        if (data.PkFile)
            this.pkFile(new DataFile(data.PkFile));
        if (data.TimeFile)
            this.timeFile(new DataFile(data.TimeFile));
        if (data.KeFile)
            this.keFile(new DataFile(data.KeFile));

        this.useTimeFile = ko.observable(data.UseTimeFile || false);
        this.useKeFile = ko.observable(data.UseKeFile || false);
        this.studyDesign = ko.observable(4); // set crossover for now
    };

    // Prepare a comparison data structure for submission to the server
    Comparison.prototype.prepareForSubmission = function () {
        var comparisonData = {
            Title: this.title,
            Level: this.level(),
            Drug: this.drug(),
            Dose: this.dose(),
            StudyType: this.studyType(),
            AucUnits: this.aucUnits(),
            CmaxUnits: this.cmaxUnits(),
            TimeUnits: this.timeUnits()
        };

        if (this.concentrationFile() != null)
            comparisonData["ConcentrationFile"] = {
                Path: this.concentrationFile().path
            };
        if (this.pkFile() != null)
            comparisonData["PkFile"] = {
                Path: this.pkFile().path
            };
        if (this.useKeFile && this.keFile() != null) {
            comparisonData["KeFile"] = {
                Path: this.keFile().path
            };
            comparisonData["UseKeFile"] = true;
        }
        if (this.useTimeFile && this.timeFile() != null) {
            comparisonData["TimeFile"] = {
                Path: this.timeFile().path
            };
            comparisonData["UseTimeFile"] = true;
        }
        return comparisonData;
    };

    var Project = function (data) {
        this.name = data.name || data.ProjectName;
        this.submissionType = data.submissionType || data.SubmissionType;
        this.submissionNumber = data.submissionNumber || data.SubmissionNumber;
        this.comparisons = ko.observableArray();
        if (data.Comparisons)
        {
            var importedComparisons = data.Comparisons.map(function (comparisonData) {
                return new Comparison(comparisonData);
            });
            this.comparisons(importedComparisons);
        }
        this.allFiles = data.AllFiles || [];
    };

    Project.prototype.findAndCreateComparisons = function () {
        var dfd = $.Deferred();
        var self = this;

        $.get('/api/ogdtool/submissions/'
            + this.submissionType
            + this.submissionNumber
            + '/findComparisons').then(function (project) {
                var comparisons = project.Comparisons.map(function (comparison) {
                    return new Comparison(comparison);
                });
                self.comparisons(comparisons);
                self.allFiles = project.AllFiles;
                dfd.resolve();
            });
        
        return dfd;
    };

    // Module interface
    var pkViewAnalysis = {
        project: Project,
        comparison: Comparison,
        dataFile: DataFile
    };

    return pkViewAnalysis;
});