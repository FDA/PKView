define('tools/ogdTool/components/home/importProject/importProject', [
    'knockout',
    'durandal/app',
    'plugins/dialog',
    'ocpkmlib/net',
    'ocpkmlib/txt'],
function (ko, app, dialog, net, txt) {
    var ctor = function () {
        self = this;
               
        self.submissions = ko.observableArray([]); // list of submissions
        self.selectedSubmission = ko.observable(""); // currently selected nda
        self.projects = ko.observableArray([]); // List of projects for the current submission
        self.selectedUser = ko.observable(""); // Selected user
        self.userProjects = ko.observableArray(); // user projects list
        self.selectedProject = ko.observable("");

        self.waitingForData = ko.observable(false); // Flag to show that we are loading nda data
        self.importing = ko.observable(false); // flag to indicate we are importing a user profile

        // Refresh the list of submissions  (only current way to monitor if a new one was uploaded)
        self.refreshSubmissions = function () {
            var $selectize = this;
            $selectize.close();
            self.submissions([]);
            self.waitingForData(true);

            // get the list of NDAS with ajax
            $.get('/api/submissions?filter=ANDA').then(function (submissions) {
                // map the list for the selectize binding
                submissions = $.map(submissions, function (item, id) { return { text: item, value: item } });
                self.submissions(submissions);
                $selectize.off('dropdown_open', self.refreshSubmissions);
                $selectize.open();
                $selectize.on('dropdown_open', self.refreshSubmissions);
                self.waitingForData(false);
            });
        };

        // Retrieve the list of user projects for the currently selected submission
        self.getUserProjects = function (submission) {
            self.projects([]);
            self.selectedUser();

            // filter blank
            if (txt.isNullOrEmpty(submission)) return;

            // Retrieve the list of projects
            self.waitingForData(true);
            $.get('/api/ogdtool/listsubmissionprojects?submission=' + submission)
                .then(function (projects) {
                    projects.forEach(function (item, i) {
                        item.Index = i;
                    });
                    self.projects(projects);
                    self.waitingForData(false);
                });
        };

        // Update the list of projects for the current user
        self.updateProjectList = function (idx) {
            if (idx == null || (typeof idx === 'undefined')) return;

            self.userProjects([]);
            self.selectedProject("");
            var projects = self.projects()[idx].Projects.map(function (project) {
                return { label: project, value: project };
            });
            self.userProjects(projects);            
        };
        
        // Import settings file to the current user's profile
        self.doImport = function () {

            if (self.importing()) return;
            self.importing(true);

            $.get("/api/ogdtool/importproject?"
                + "submission=" + self.selectedSubmission()
                + "&user=" + self.projects()[self.selectedUser()].User
                + "&project=" + self.selectedProject())
                .then(function () {
                    self.importing(false);
                    self.done();
                });            
        };
    };

    // Activate the view
    ctor.prototype.activate = function (settings) {
        var self = this;
        self.selectedSubmission.subscribe(self.getUserProjects);
        self.selectedUser.subscribe(self.updateProjectList);
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
            self.waitingForData(false);
        });
    };

    return ctor;
});