define('tools/pkview/components/home/shareProject/shareProject', [
    'knockout',
    'durandal/app',
    'plugins/dialog',
    'ocpkmlib/net',
    'ocpkmlib/txt'],
function (ko, app, dialog, net, txt) {
    var ctor = function () {
        self = this;
               
        self.submissions = []; // list of submissions with projects for the current user
        self.projects = {}; // lists of projects by submission
        self.studies = ko.observable(); // list of studies in the selected project
        self.users = []; // list of pkview users

        self.selectedSubmission = ko.observable(""); // currently selected submission
        self.selectedProject = ko.observable(""); // currently selected project
        self.selectedStudies = ko.observableArray(); // selected studies
        self.selectedUser = ko.observable(""); // Selected target user  
        self.selectedEmail = ko.observable(""); // User email if target selected by email

        self.waitingForData = ko.observable(true); // Flag to show a spinner while loading
        self.enableProjects = ko.observable(true); // Flag to enable/disable the projects dropdown
        self.enableStudies = ko.observable(true); // Flag to enable/disable the studies dropdown
        self.sharing = ko.observable(false); // flag to indicate we are importing a user profile

        // Get the list of projects for the current user 
        self.getProjects = function () {
            var dfd = $.Deferred();
            $.get('/api/pkview/listmyprojects')
            .done(function (projectList) {
                self.submissions = projectList;
                for (var i = 0; i < self.submissions.length; i++) {
                    var submission = self.submissions[i];
                    self.projects[submission.Submission] = submission.Projects;                   
                }
                self.selectedSubmission(self.submissions[0].Submission);
                dfd.resolve();
            });
            return dfd.promise();
        };

        // Retrieve the list of pkview users
        self.getUsers = function (submission) {
            var dfd = $.Deferred();
            $.get('/api/pkview/users')
            .done(function (users) {
                self.users = users;
                users.unshift({
                    UserName: "$EMAIL$",
                    DisplayName: "(Select by FDA e-mail)" 
                });
                self.selectedUser(self.users[1].UserName);
                dfd.resolve();
            });
            return dfd.promise();
        };
         
        // Select the first available project when the selected submission changes
        self.submissionSelected = function (submission) {
            self.enableProjects(false);
            if (txt.isNullOrEmpty(self.selectedSubmission())) {
                self.selectedProject("");
                return;
            }
            self.selectedProject(self.projects[self.selectedSubmission()][0].Name);
            self.enableProjects(true);
        };

        // Get the list of studies for the currently selected project
        self.getStudies = function (project) {
            self.enableStudies(false);

            // Do not request the list of studies if submission or project not selected
            if (txt.isNullOrEmpty(self.selectedSubmission())
                || txt.isNullOrEmpty(self.selectedProject())) {
                self.selectedStudies([]);
                return;
            }

            $.get('api/pkview/projects?metadataOnly=true'
                + "&submissionId=" + self.selectedSubmission()
                + "&projectName=" + self.selectedProject())
            .done(function (project) {
                self.studies(project.Studies);
                self.selectedStudies(project.Studies.map(function (study) {
                    return study.StudyCode;
                }));
                self.enableStudies(true);
            });
        }

        // Import settings file to the current user's profile
        self.share = function () {

            // If sharing by email, verify a correct address has been entered
            var user = self.selectedUser();
            if (user == "$EMAIL$") {
                if (self.selectedEmail().indexOf('@') == -1) {
                    app.showMessage("Please enter a valid e-mail address");
                    return;
                }
                user = self.selectedEmail();
            }

            // Check at least one study is selected
            if (self.selectedStudies().length == 0) {
                app.showMessage("Please select at least one study to share");
                return;
            }

            self.sharing(true);
            $.post("api/pkview/shareproject?"
                + "submission=" + self.selectedSubmission()
                + "&project=" + self.selectedProject()
                + "&user=" + user,
                { '': self.selectedStudies() })
            .done(function (success) {
                if (success) {
                    self.sharing(false);
                    app.showMessage("The project has been shared successfully")
                        .then(self.done);
                } else app.showMessage("An error ocurred, the project could not be shared");
            });                    
        };
    };

    // Activate the view
    ctor.prototype.activate = function (settings) {
        var self = this;
        self.subscriptions = [];
        self.subscriptions.push(self.selectedSubmission.subscribe(self.submissionSelected));
        self.subscriptions.push(self.selectedProject.subscribe(self.getStudies));

        self.reposition = settings.reposition;
        self.done = settings.done;
    };

    // After view is attached
    ctor.prototype.attached = function (view) {
        var self = this;
        self.waitingForData(true);
        self.getProjects()
            .then(self.getUsers)
            .then(function () {
                self.waitingForData(false);
                setTimeout(self.reposition, 5000);
            });
    };

    // Clean up
    ctor.prototype.detached = function () {
        var self = this;

        // dispose subscriptions
        for (var i = 0; i < self.subscriptions.length; i++)
            self.subscriptions[i].dispose();
    };

    return ctor;
});