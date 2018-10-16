define('tools/pkview/components/review/sections/editExcludeSubject', [
    'knockout',
    'durandal/app',
    'jqueryUiSortable',
    'plugins/dialog',
    'ocpkmlib/net',
    'ocpkmlib/txt',
    'shared/api/pkAnalysis/analysis'],
function (ko, app, sortable,dialog, net, txt, analysis) {
    var ctor = function () {
        var self = this;
        self.loading = ko.observable(true);
        self.columns = [];
        self.excludedatatable = ko.observableArray([]);

        self.excludecolumns = ko.observableArray([]);
        self.ExcludeIndex = ko.observableArray([]);
        self.reportGenerated = ko.observable(true);
        self.computingReport = ko.observable(false);
        self.downloadingReport = ko.observable(false); // Flag to indicate we are downloading the report package


        // Save changes and close the dialog
        self.save = function () {
            //var self = this;
            self.generateExcludedReport();
            //app.showMessage('Excluded Report Finished', 'PkView', ['OK'])
            //self.close();
        };

        self.generateExcludedReport = function () {

            var dfd = $.Deferred();

            // DO nothing if we are already computing
            //if (self.computingReport()) {
            //    dfd.resolve(false);
            //    return dfd;
            //}

            // get currently visible report
            //var report = self.study().Reports()[self.activeReportId()];

            // Report exists flag, computing report flag
            //report.Generated(false);
            //self.computingReport(true);
            self.reportGenerated(false);
            self.computingReport(true);
            var finaldata = JSON.parse(self.data);
            finaldata.excludedatatable = self.excludedatatable();
            finaldata.ExcludeIndex = self.ExcludeIndex();
            
            net.ajax({
                url: "/api/pkview/GenerateExcludedReport?reportId=" + self.reportid,
                //+ "&excludedatatable=" + ko.toJSON(self.excludedatatable)
                //+ "&ExcludeIndex=" + ExcludeIndex),
                data: ko.toJSON(finaldata),
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
                    self.reportGenerated(true);
                    self.computingReport(false);
                    //self.computingReport(false);
                    //self.downloaddistribution(self.study().NDAName, self.study().ProfileName, self.study().SupplementNumber);
                    app.showMessage('Excluded Report Finished', 'PkView', ['OK'])
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

        self.print = function () {
            console.log(self.excludedatatable());
            alert(JSON.stringify(self.excludedatatable()));
        };

        
    };    

    // Activate the view
    //ctor.prototype.activate = function (activationData) {
    //    var self = this;
    //    self.close = activationData.close;
    //    self.excludedatatable = ko.observableArray([]);
    //    self.excludecolumns = ko.observableArray([]);
    //    self.excludecolumns = activationData.columns.map(function (mapping) {
    //        return {
    //            text: mapping,
    //        }
    //    });
    //    self.excludedatatable(activationData.excludedatatable);
    //    self.loading(false);
        
    ctor.prototype.activate = function (activationData) {
        var self = this;
        self.reportid = activationData.reportid;
        self.data = activationData.data;
        self.close = activationData.close;
        net.ajax({
            url: "/api/pkview/GenerateExclude?reportId=" + self.reportid,
            data: self.data,
            type: "POST",
            successCallback: function (dataTable) {
                if ( dataTable == null ) {
                    app.showMessage('No excluded data', 'PkView', ['OK'])
                .then(function (answer) { if (answer == 'OK') self.close(); });
                    return;
                }
                if ( dataTable.length == 0 ) {
                    app.showMessage('No excluded data', 'PkView', ['OK'])
                 .then(function (answer) { if (answer == 'OK') self.close(); });
                    return;
                }
                            self.columns = [];
                            for (var key in dataTable[0])
                                self.columns.push(key);
                             var excludecolumns = self.columns.map(function (mapping) {
                                return {
                                    text: mapping,
                                }
                             });
                             self.excludecolumns(excludecolumns);
                             self.IndexofExclude = [];
                             for (i = 0; i < dataTable.length; i++)
                                 self.IndexofExclude.push(false);
                             //var ExcludeIndex1 = self.IndexofExclude.map(function (mapping) {
                             //    return {
                             //        text: mapping,
                             //    }
                             //});
                             self.ExcludeIndex(self.IndexofExclude);
                             //dataTable.in.push("Exclude");

                             self.excludedatatable(dataTable);

                self.loading(false);
            },
            errorCallback: function () {
                app.showMessage('An error occurred', 'PkView', ['OK'])
                .then(function (answer) { if (answer == 'OK') self.close(); });
                self.close;

            }
        });
            //self.close = activationData.close;
            
        setTimeout(self.reposition, 500);
    };

     //Clean up
ctor.prototype.detached = function () {
        var self = this;
        //self.customizeSubscription.dispose();
    };


    return ctor;
});