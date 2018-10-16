define('tools/pkView/components/report/reportSettings/types/empty/empty', ['knockout'],
function (ko) {

    // This is the createReportSummary viewmodel prototype
    var ctor = function () {
        var self = this;
        self.info = "";
    };

    // Initialize the view
    ctor.prototype.activate = function (hasStudies) {
        var self = this;
        if (hasStudies)
            self.info = "A report has not been created yet for this study, use " +
             "the 'New' option in the toolbar above to create one.";
        else self.info = "No studies have been analyzed yet.";
    };

    return ctor;
});