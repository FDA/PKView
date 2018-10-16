define('tools/ogdTool/components/main/sections/dataFiles/selectFiles', [
    'knockout',
    'durandal/app',
    'plugins/dialog',    
    'ocpkmlib/txt',
    'shared/components/dataDialog/viewmodels/dataDialog',
    'tools/ogdTool/models'],
function (ko, app, dialog, txt, dataDialog, models) {
    var ctor = function () {
        var self = this;

        self.comparison = null; // Form data for the current comparison
        self.project = null; // project containing the current comparison
        self.fileList = null;

        self.concentrationPath = ko.observable();
        self.pkPath = ko.observable();
        self.timePath = ko.observable();
        self.kePath = ko.observable();

        self.useTime = ko.observable(false);
        self.useKe = ko.observable(false);

        // View domain data
        self.viewData = function (path) {
            dialog.show(new dataDialog(path, path.substring(path.lastIndexOf('\\') + 1)));
        };
    };

    // Activate the view
    ctor.prototype.activate = function (settings) {
        var self = this;
        self.comparison = settings.comparison;
        self.project = settings.project;
        self.fileList = self.project.allFiles.map(function (path) {
            return {
                path: path,
                relative: path.split(/[\\\/]/).slice(5).join('\\')
            };
        }); 
        if (self.comparison.concentrationFile())
            self.concentrationPath(self.comparison.concentrationFile().path);
        if (self.comparison.pkFile())
            self.pkPath(self.comparison.pkFile().path);
        if (self.comparison.timeFile())
            self.timePath(self.comparison.timeFile().path);
        if (self.comparison.keFile())
            self.kePath(self.comparison.keFile().path);

        self.concentrationPath.subscribe(function (path) {
            self.comparison.concentrationFile(new models.dataFile({Path: path}));
        });
        self.pkPath.subscribe(function (path) {
            self.comparison.pkFile(new models.dataFile({Path: path}));
        });
        self.timePath.subscribe(function (path) {
            self.comparison.timeFile(new models.dataFile({ Path: path }));
        });
        self.timePath.subscribe(function (path) {
            self.comparison.timeFile(new models.dataFile({ Path: path }));
        });

        //self.done = settings.done;
    };

    // After view is attached
    ctor.prototype.attached = function (view) {
        var self = this;
        // get the list of NDAS with ajax
        //net.ajax({
        //    url: "/api/pkview/ndaUserProfiles",
        //    data: { NDAName: self.NDAName },
        //    successCallback: function (data) {
        //        data = $.map(data, function (item, idx) {                  
        //            return { text: item.DisplayName, id: idx, data: item };});
        //        self.UserList(data);
        //        self.responseReady(true);
        //    }
        //});
    };

    return ctor;
});