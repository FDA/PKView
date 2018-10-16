define('tools/ogdTool/components/main/sections/dataFiles/mapFiles', [
    'knockout',
    'durandal/app',
    'plugins/dialog',
    'shared/components/modal/viewmodels/modal',
    'ocpkmlib/net',
    'ocpkmlib/txt'],
function (ko, app, dialog, modal, net, txt) {
    var ctor = function () {
        var self = this;

        self.comparison = null; // Form data for the current comparison
        self.project = null; // project containing the current comparison

        self.varList = [
            { name: 'SUBJ' },
            { name: 'PER' },
            { name: 'SEQ' },
            { name: 'TRT' },
        ];

        self.arrayVarList = [
            { name: 'C1...C24' },
            { name: 'T1...T24' }
        ];

        self.subject = ko.observable("SUBJ");
        self.period = ko.observable("PER");
        self.sequence = ko.observable("SEQ");
        self.treatment = ko.observable("TRT");
        self.group = ko.observable("");
        self.hasGroup = ko.observable(false);

        self.concentration = ko.observable("C1...C24");
        self.time = ko.observable("T1...T24");

        // Edit the nominal time manually
        self.editTime = function () {
            var timeSettingDialog = new modal({
                title: "Edit time points",
                model: "tools/ogdTool/components/main/sections/dataFiles/setTime",
                activationData: {
                    comparison: self.comparison,
                    project: self.project,
                    done: function () {
                        /// do stuff
                        timeSettingDialog.close();
                    }
                },
                width: 0.9
            });
            dialog.show(timeSettingDialog);

        };
    };

    // Activate the view
    ctor.prototype.activate = function (settings) {
        var self = this;
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