define('tools/pkview/components/review/sections/OrderSeverity', [
    'knockout',
    'durandal/app',
    'plugins/dialog',
    'ocpkmlib/net',
    'ocpkmlib/txt'],
    function (ko, app, dialog, net, txt) {
        var ctor = function () {
            var self = this;
            self.loading = ko.observable(true);
            var errorCount = 0;
            self.SaveAndClose = function () {
                errorCount = 0;
                ko.utils.arrayForEach(self.SeverityValues, function (SeverityValue) {
                    if (isNaN(SeverityValue.order)) {
                        errorCount++;
                    }
                })
                if (errorCount == 0) {
                    self.close({ SeverityValues: self.SeverityValues });
                }
                else {
                    app.showMessage("invalid order", 'PkView', ['OK']);
                    return;
                }
            };
        }

        // Activate the view
        ctor.prototype.activate = function (settings) {
            var self = this;
            self.SeverityValues = settings.SeverityValues;
            self.close = settings.close;
            self.loading(false);
        };

        // Clean up
        ctor.prototype.detached = function () {
            var self = this;
        };

        return ctor;
    });