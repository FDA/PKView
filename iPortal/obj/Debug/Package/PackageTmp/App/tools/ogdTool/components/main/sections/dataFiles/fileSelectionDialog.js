define('tools/ogdTool/components/main/sections/dataFiles/fileSelectionDialog', [
    'knockout',
    'durandal/app',
    'plugins/dialog',
    'ocpkmlib/net',
    'ocpkmlib/txt'],
function (ko, app, dialog, net, txt) {
    var ctor = function () {
        var self = this;

        self.comparison = null; // Form data for the current comparison
        self.project = null; // project containing the current comparison
        
        self.step = ko.observable('select');

        // Afer selecting the files to load, go to the mapping step
        self.next = function () {
            self.step('map');
        };

        // Option to go back to file selection
        self.back = function () {
            self.step('select');
        };

        // Save selections and close dialog
        self.save = function () {
            self.done();
        };
    };

    // Activate the view
    ctor.prototype.activate = function (settings) {
        var self = this;
        self.comparison = settings.comparison;
        self.project = settings.project;
        self.done = settings.done;
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