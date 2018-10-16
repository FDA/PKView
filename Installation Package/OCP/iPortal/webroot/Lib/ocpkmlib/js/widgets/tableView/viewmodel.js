define(['jquery','knockout','durandal/composition','datatables','datatablesBootstrap'], function($, ko, composition, datatables, dtBoostrap) {
    var ctor = function () {
        var self = this;
    };
     
    ctor.prototype.activate = function(settings) {
        var self = this;
        self.settings = settings;

        // Table data
        self.columns = self.settings.columns;
        self.tableData = self.settings.tableData || [];
        self.columnDefs = self.settings.columnDefs || [];
        self.sorting = self.settings.sorting || [[0, 'asc']];
    };
    
    ctor.prototype.attached = function(view) {

    };

    ctor.prototype.compositionComplete = function (view, parent) {
        var self = this;

        var parts = composition.getParts(view);
        var $table = $(parts.table);

        // Table rendering callback
        var renderTable = function () {

            // Unwrap observables
            var columns = ko.unwrap(self.columns);
            var columnDefs = ko.unwrap(self.columnDefs);
            var tableData = ko.unwrap(self.tableData);

            // Check for data before rendering
            var colnum = (columns ? columns.length : 0) + columnDefs.length;
            var rownum = tableData.length;
            if (colnum > 0 && rownum > 0) {

                // Setup options
                var dtOptions = {
                    aaData: tableData,                    
                    aoColumnDefs:columnDefs,
                    aaSorting: ko.unwrap(self.sorting),
                    bSortClasses: false
                };

                // Setup columns
                if (columns) {
                    dtOptions.aoColumns =
                        $.isArray(ko.unwrap(self.tableData)[0]) ?
                            columns.map(function (val) { return { sTitle: val }; }) :
                            columns.map(function (val) {
                                return $.isPlainObject(val) ?
                                    (val.rowSettings ? $.extend(val.rowSettings, { sTitle: val.title, mData: val.data }) :
                                            { sTitle: val.title, mData: val.data }) :
                                        { sTitle: val, mData: val };
                            });
                }

                // Render the datatable              
                self.dt = $table.dataTable(dtOptions);

                // Some bootstrap customization
                $filterLabel = $(parent).find(".dataTables_filter label");
                $filterBox = $filterLabel.find("input");
                $($filterLabel.contents()[0]).remove();
                $filterBox.addClass("form-control");
                $filterBox.attr("placeholder", "Search");
            }
            else setTimeout(renderTable, 1000);
        };
        setTimeout(renderTable, 1000);
    };

    return ctor;
});