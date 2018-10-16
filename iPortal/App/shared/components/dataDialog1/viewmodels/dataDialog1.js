define('shared/components/dataDialog1/viewmodels/dataDialog1', ['knockout', 'koSelectize', 'ocpkmlib/net', 'plugins/dialog', 'tools/pkView/components/report/report'], function (ko, koSelectize, net, dialog, report) {

    var dataDialog1 = function (data, reportid) {
        self = this;

        // Set dialog title
        self.title = "Data display";
       
        self.columns = ko.observableArray();
        self.tableData = ko.observableArray();
        self.data = data;
        self.reportid = reportid;

       
        self.loading = ko.observable(true);
        //self.fileId = fileId;


    };

    // module activation
    dataDialog1.prototype.activate = function () {
        var self = this;

        net.ajax({
            url: "/api/pkview/GenerateExclude?reportId=" + self.reportid,
            data: self.data,
            type: "POST",
            successCallback: function (dataTable) {

                
                for (var key in dataTable[0])
                    self.columns.push(key);
                self.tableData(dataTable);


            }
            
        });
        self.loading(false);
        


    };

    // Resize modal when view is attached
    dataDialog1.prototype.attached = function (view, parent) {
        var self = this;
        self.view = view;
        self.reposition();        
    };

    dataDialog1.prototype.close = function () {
        dialog.close(this);
    };

    
    var tableReposition = function (view) {
        var self = this;
        var $table = view.find("table");
        //var table = $table.datatable();
        if ($table.length > 0) {
            var $body = view.find(".modal-body");
            $body.css("max-height", ($(window).height() * 0.9) - 60 + 'px');
            $table.css("max-height", ($(window).height() * 0.9) - 220 + 'px');
        } else setTimeout(function () { tableReposition.apply(self, [view]); }, 500);
    };

    dataDialog1.prototype.reposition = function () {
        var self = this;
        var $view = $(self.view);       

        $view.css("min-width", ($(window).width() * 0.9) + 'px');
        $view.css("min-height", ($(window).height() * 0.9) + 'px');

        tableReposition($view);
    };

   

    

    return dataDialog1;
});