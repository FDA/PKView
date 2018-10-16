define('tools/ogdTool/components/home/newProject/newProject', [
    'knockout',
    'koSelectize',
    'durandal/app',
    'plugins/dialog',
    'ocpkmlib/net',
    'ocpkmlib/txt',  
    'shared/api/files',
    'shared/components/modal/viewmodels/modal',
    'shared/api/pkAnalysis/analysis'],
function (ko, koSelectize, app, dialog, net, txt, files, modal, analysis) {

    // This is the mainWindow viewmodel prototype
    var ctor = function () {
        var self = this;

        self.submissions = ko.observableArray([]); // List of submissions
        self.selectedSubmission = ko.observable(""); // Selected submission
        self.projectName = ko.observable("Analysis 1"); // New project name

        self.responseReady = ko.observable(false); // server response flag   
        self.waitingForData = ko.observable(false); // Flag to show that we are loading nda data

        // Refresh the list of submissions  (only current way to monitor if a new one was uploaded)
        self.refreshSubmissions = function () {

            var $selectize = this;
            $selectize.close();
            self.submissions([]);
            self.waitingForData(true);

            // get the list of NDAS with ajax
            $.get('/api/submissions?filter=ANDA').then(function (submissions) {
                // map the list for the selectize binding
                submissions = $.map(submissions, function (item, id) { return { text: item, value: item }});
                self.submissions(submissions);
                $selectize.off('dropdown_open', self.refreshSubmissions);
                $selectize.open();
                $selectize.on('dropdown_open', self.refreshSubmissions);
                self.waitingForData(false);
            });
        };

        // Check if selection is valid
        self.createProject = function () {

            if ($.trim(self.selectedSubmission()).length == 0) {
                app.showMessage('Please select a submission from the list', 'OGD Tool');
                return;
            }

            if ($.trim(self.projectName()).length == 0) {
                app.showMessage('Project name cannot be empty', 'OGD Tool');
                return;
            }

            var submissionType = self.selectedSubmission().split(/[0-9]/)[0];
            var submissionNumber = self.selectedSubmission().substring(submissionType.length);

            // Get the filename of the nda settings file
            self.done({
                name: self.projectName(),
                submissionType: submissionType,
                submissionNumber: submissionNumber
            });
        };        
    };

    // Activate the view
    ctor.prototype.activate = function (settings) {
        var self = this;
        self.done = settings.done;        
    };

    // After view is attached
    ctor.prototype.attached = function (view) {
        var self = this;
        // get the list of NDAS with ajax
        $.get('/api/submissions?filter=ANDA').then(function (submissions) {
            // map the list for the selectize binding
            submissions = $.map(submissions, function (item, id) { return { text: item, value: item } });
            self.submissions(submissions);
            self.responseReady(true);
        });
    };

    return ctor;
});