define('shared/components/dataDialog/viewmodels/dataDialog', ['knockout', 'ocpkmlib/net','plugins/dialog'], function (ko, net, dialog) {

    var dataDialog = function (fileId, title) {
        self = this;

        // Set dialog title
        self.title = title || "Data display";
        self.columns = ko.observableArray();
        self.tableData = ko.observableArray();
        self.loading = ko.observable(true);
        self.fileId = fileId;        
    };

    // module activation
    dataDialog.prototype.activate = function () {
        var self = this;

        // Use a file id or a path
        var fileId = self.fileId;
        var url = "/api/readxpt/";
        var type, data = null;
        if (fileId === parseInt(fileId)) {
            url += fileId;
            type = "GET";
        }
        else {
            type = "POST";
            var filepath = fileId;
            data = JSON.stringify(filepath);
        }

        // ajax call to run the sas code that reads the variable mappings
        net.ajax({ url: url, type: type, data: data })
            .then(function (dataTable) {

                // If table is empty return
                if (dataTable == null || dataTable.length == 0) return;

                // Extract table columns
                for (var key in dataTable[0])
                    self.columns.push(key);

                self.tableData(dataTable);
                self.loading(false);
            });
    };

    // Resize modal when view is attached
    dataDialog.prototype.attached = function (view, parent) {
        var self = this;
        self.view = view;
        self.reposition();        
    };

    dataDialog.prototype.close = function () {
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

    dataDialog.prototype.reposition = function () {
        var self = this;
        var $view = $(self.view);       

        $view.css("min-width", ($(window).width() * 0.9) + 'px');
        $view.css("min-height", ($(window).height() * 0.9) + 'px');

        tableReposition($view);
    };

    return dataDialog;
});