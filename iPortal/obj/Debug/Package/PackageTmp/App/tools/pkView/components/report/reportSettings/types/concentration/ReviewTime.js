define('tools/pkView/components/report/reportSettings/types/concentration/reviewTime', [
    'knockout',
    'durandal/app',
    'plugins/dialog',
    'ocpkmlib/net',
    'ocpkmlib/txt'],
function (ko, app, dialog, net, txt) {
    var ctor = function () {
        var self = this;
        self.loading = ko.observable(true);
        self.timeMappings = null;

        // Save changes and close the dialog
        self.save = function () {
            self.close(self.timeMappings);
        };      
    };    

    // Activate the view
    ctor.prototype.activate = function (settings) {
        var self = this;

        self.close = settings.close;
        self.reposition = settings.reposition;
      
        // Attempt to load time mappings
        var mappings = settings.timeMappings;
        if (mappings && mappings.length > 0) {
            self.timeMappings = mappings.map(function (mapping) {
                return {
                    raw: mapping.RawTime,
                    normalized: ko.observable(mapping.NormalizedTime)
                }
            });
        }

        self.loading(false);
        setTimeout(self.reposition, 500);
    };

    // Clean up
    ctor.prototype.detached = function () {
        var self = this;
    };

    return ctor;
});