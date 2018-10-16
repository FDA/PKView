define('tools/ogdTool/components/main/sections/dataFiles/setTime', [
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

        self.timeArray = null;
    };

    // Activate the view
    ctor.prototype.activate = function (settings) {
        var self = this;

        self.timeArray = [];
        for (var i = 0; i < 24; i++)
        {
            self.timeArray.push({
                variable: "T" + i + 1,
                value: ko.observable()
            });
        }
        //self.comparison = settings.comparison;
        //self.project = settings.project;
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