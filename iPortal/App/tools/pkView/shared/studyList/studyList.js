define('tools/pkView/shared/studyList/studyList', ['knockout'],
function (ko) {
    var ctor = function () {
        var self = this;

        // icon classes for the bullet
        self.iconClasses = {
            info:    "info-circle",
            success: "check-circle",
            warning: "exclamation-circle",
            danger:  "times-circle"
        };

        // Tooltip customization
        self.tooltipTemplate = '<div class="tooltip @1" role="tooltip">' +
            '<div class="tooltip-arrow"></div>' +
            '<div class="tooltip-inner"></div></div>';

        // toggle list
        self.showList = ko.observable(false);
        self.toggleList = function () {
            self.showList(!self.showList());
        }
    };

    ctor.prototype.activate = function (activationData) {
        var self = this;
        self.list = activationData.list;
        if (!ko.isObservable(self.list))
            self.list = ko.observable(self.list);
        self.contextClass = activationData.contextClass || "info";
        self.what = activationData.what;
        self.suffix = activationData.suffix;
    };
    return ctor;
});