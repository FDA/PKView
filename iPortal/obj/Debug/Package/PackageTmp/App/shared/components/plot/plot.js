define('shared/components/plot/plot', [
    'knockout',
    'flot',
    'flot_errorbars',
    'flot_selection'
], function (ko, flot, flot_errorbars) {

    // This is the createReportSummary viewmodel prototype
    var ctor = function () {
        var self = this;
        self.data = {};
        self.options = {};
        self.events = {};
    };

    // Initialize the view
    ctor.prototype.activate = function (settings) {
        var self = this;
        if (settings.data) self.data = settings.data;
        if (settings.options) self.options = settings.options;
        if (settings.events) self.events = settings.events;
    };

    // After view is attached
    ctor.prototype.attached = function (view) {
        self = this;
        $view = $(view);
        $plot = $view.find('.plot');
        
        // Bind events
        $.each(self.events, function (eventName, callback) {
            $plot.bind(eventName, callback);
        });

        // Initialize flot
        self.plot = $.plot($plot, self.data, self.options);
    }

    return ctor;
});