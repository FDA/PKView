define('tools/pkview/components/review/sections/metaVariabilityFormat', [
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
        self.showdistributionornot = ko.observable();
        self.metareportGenerated = ko.observable(true);
        self.metacomputingReport = ko.observable(false);
        self.selectedStudies1 = ko.observableArray([]);

        // Save changes and close the dialog
        self.save = function () {
            var showdistributionornot = "saveandgenerate";
            self.metaformat.showdistributionornot = showdistributionornot;
            self.close({ showdistributionornot: showdistributionornot });
        };
        self.showdistribution = function () {
            var showdistributionornot = "showdistribution";
            self.metaformat.showdistributionornot = showdistributionornot;
            self.generateMetaAnalysis();
        };

        self.generateMetaAnalysis = function () {

            var dfd = $.Deferred();
            self.metareportGenerated(false);
            self.metacomputingReport(true);

            self.selectedStudies1().splice(0, self.selectedStudies1().length);

            for (i = 0 ; i < self.selectedStudies().length; i++) {
                for (j = 0 ; j < self.analyzableStudies().length; j++) {

                    if (self.selectedStudies()[i] == self.analyzableStudies()[j].StudyCode && self.analyzableStudies()[j].Reports().length > 0) {

                        self.selectedStudies1.push(self.analyzableStudies()[j]);
                    }
                }
            }

            if (self.selectedStudies1().length == 0) {
                app.showMessage("You must select studies order after click Generate Meta Analysis", 'PkView', ['OK']);
                self.metareportGenerated(true);
                self.metacomputingReport(false);
                return;
            }

            if (self.selectedStudies1().length != 0) {
                for (i = 0; i < self.selectedStudies1().length; i++) {
                    self.selectedStudies1()[i].PlotType = self.metaformat().PlotType;
                    self.selectedStudies1()[i].NormalizedType = self.metaformat().NormalizedType;
                    self.selectedStudies1()[i].Cutoffupperbound = self.metaformat().Cutoffupperbound;
                    self.selectedStudies1()[i].Cutofflowerbound = self.metaformat().Cutofflowerbound;
                    self.selectedStudies1()[i].showdistributionornot = self.metaformat.showdistributionornot;
                }
            }



            net.ajax({
                url: "/api/pkview/VariabilityMetaAnalysis?reportId=" + "0",
                data: ko.toJSON(self.selectedStudies1),
                type: "POST",
                successCallback: function (date) {
                    if (date == null) {
                        //self.computingReport(false);
                        app.showMessage('An error occurred', 'PkView', ['OK']);
                        dfd.resolve(false);
                        return;
                    }
                    //app.showMessage('Distributiuon finished', 'PkView', ['OK']);

                    //report.CreationDate(new Date(date));
                    self.metareportGenerated(true);
                    self.metacomputingReport(false);
                    //self.computingReport(false);
                    self.downloaddistribution(self.study().NDAName, self.study().ProfileName, self.study().SupplementNumber);
                    dfd.resolve(true);
                },
                errorCallback: function () {
                    //self.computingReport(false);
                    app.showMessage('An error occurred', 'PkView', ['OK']);
                    dfd.resolve(false);
                }
            });
            return dfd;
        };
        
        self.downloaddistribution = function (NDAName, ProfileName, activeSupplement) {
            if (ProfileName == null) ProfileName = "";
            //net.download("/api/download/PkView/" + NDAName + "Meta" + ".png?subfolder=" + ProfileName + "/" + NDAName + "/" + activeSupplement + "/" + "Meta" + "/");
            net.download("/api/download/PkView/" + NDAName + "_" + "Distribution" + ".png?subfolder=" + ProfileName + "/" + NDAName + "/" + activeSupplement + "/" + "MetaVariability" + "/");

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

        
      
        self.NormalizedType = [
    { text: "Dose", value: "Dose" },
    { text: "Mean", value: "Mean" },
    { text: "Medium", value: "Medium" },
        ];

        self.PlotType = [
{ text: "ScatterPlot", value: "ScatterPlot" },
{ text: "BoxPlot", value: "BoxPlot" },
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