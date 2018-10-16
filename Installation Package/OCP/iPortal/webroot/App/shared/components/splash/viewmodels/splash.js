define('shared/components/splash/viewmodels/splash',
    ['jquery', 'knockout'],
    function ($, ko) {
        var ctor = function () {

        var self = this;
        self.counter = ko.observable(null);

        self.displayCounter = ko.computed(function () {
            return
                self.settings.displayCounter() &&
                self.counter() != null &&
                self.settings != null &&
                self.settings.feedback() != null &&
                self.settings.feedback() != "";
        });

        self.formFactors = {
            normal: {
                columnClasses: 'col-sm-4 col-sm-offset-4',
                globalClass: ''
            },
            small: {
                columnClasses: 'col-sm-12',
                globalClass: 'splash-tiny'
            },
            slim: {
                columnClasses: 'col-sm-12',
                globalClass: 'splash-tiny'
            }
        };
    };

    ctor.prototype.activate = function (settings) {
        var self = this;
        self.settings = settings;

        // Form factor
        self.settings.formFactor = settings.formFactor || "normal";

        // Force progress to be observable
        if (!$.isFunction(self.settings.progress))
            self.settings.progress = ko.observable(self.settings.progress);

        // Update counter each time feedback is changed
        self.settings.feedback.subscribe( function() {
            if (self.counter() == null) self.counter(1);
            else self.counter(self.counter() + 1);
        });
    };

    return ctor;
});