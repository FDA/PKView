define('shared/components/dataDialogExclude/viewmodels/dataDialogExclude', ['knockout', 'ocpkmlib/net', 'plugins/dialog', 'durandal/app'], function (ko, net, dialog,app) {

    var dataDialogExclude = function (data, reportid) {
        self = this;
        self.loading = ko.observable(true);
        // Set dialog title
        self.title = "Show excluded data";
        self.columns = ko.observableArray();
        self.tableData = ko.observableArray();
        self.data = data;
        self.reportid = reportid;
        
      

    };

    // module activation
    dataDialogExclude.prototype.activate = function () {
        var self = this;

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
                
                

                for (var key in dataTable[0])
                    self.columns.push(key);

                self.tableData(dataTable);
                self.loading(false);
            },
            errorCallback: function () {
                app.showMessage('An error occurred', 'PkView', ['OK'])
                .then(function (answer) { if (answer == 'OK') self.close(); });
                self.close;

            }
        });

        

    };
   
    //dataDialogExclude.prototype.activate = function () {
    //    var self = this;

    //    net.ajax({
    //        url: "/api/pkview/GenerateExclude?reportId=" + self.reportid,
    //        data: self.data,
    //        type: "POST"}).then(function (dataTable) {

    //            // If table is empty return
    //            if (dataTable == null || dataTable.length == 0) return;

    //            // Extract table columns
    //            for (var key in dataTable[0])
    //                self.columns.push(key);

    //            self.tableData(dataTable);
    //            self.loading(false);
    //        });

    //};

    // Resize modal when view is attached
    dataDialogExclude.prototype.attached = function (view, parent) {
        var self = this;
        self.view = view;
        self.reposition();        
    };

    dataDialogExclude.prototype.close = function () {
        dialog.close(this);
    };

    
    var tableReposition = function (view) {
        var self = this;
        var $table = view.find("table");
        if ($table.length > 0) {
            var $body = view.find(".modal-body");
            $body.css("max-height", ($(window).height() * 0.9) - 60 + 'px');
            $table.css("max-height", ($(window).height() * 0.9) - 220 + 'px');
        } else setTimeout(function () { tableReposition.apply(self, [view]); }, 500);
    };

    dataDialogExclude.prototype.reposition = function () {
        var self = this;
        self.loading(true);

        var $view = $(self.view);       

        $view.css("min-width", ($(window).width() * 0.9) + 'px');
        $view.css("min-height", ($(window).height() * 0.9) + 'px');

        tableReposition($view);
    };

    return dataDialogExclude;
});