define('tools/pkView/components/home/home', [
    'knockout',
    'koSelectize',
    'durandal/app',
    'plugins/dialog',
    'ocpkmlib/net',
    'shared/components/modal/viewmodels/modal',
    'tools/ogdTool/shared/filter/filter'],
function (ko, koSelectize, app, dialog, net, modal, filter) {

    // This is the mainWindow viewmodel prototype
    var ctor = function () {
        var self = this;

        self.submission = null; // Selected submission
        self.projectName = null; // Selected project name

        self.responseReady = ko.observable(false); // server response flag          
        self.projectList = ko.observableArray(); // list of projects for the current user
        self.filterValue = ko.observable(""); // filter for the list of projects
        self.focusFilter = ko.observable(true); // Used to set focus on the filter on load

        // Computed for the filtered list of projects
        self.filteredProjectList = ko.computed(function () {
            var filterValue = self.filterValue().trim();
            if (!filterValue) return self.projectList();

            var filteredList = self.projectList().map(function (group) {
                // If filter applies to submission name
                var found = filter.markIfFound(group.Submission.Name, filterValue);
                if (found != null) {
                    var highlightedGroup = {
                        Submission: { Name: group.Submission.Name, Label: found },
                        Projects: group.Projects.map(function (project) {
                            var found2 = filter.markIfFound(project.Name, filterValue);
                            if (found2 == null) return project;
                            return { Name: project.Name, Label: found2, HasPackage: project.HasPackage };
                        })
                    };
                    return highlightedGroup;
                }

                // return filtered group
                var filteredGroup = {
                    Submission: group.Submission,
                    Projects: group.Projects.map(function (project) {
                        var found = filter.markIfFound(project.Name, filterValue);
                        if (found == null) return null;
                        return { Name: project.Name, Label: found, HasPackage: project.HasPackage };
                    }).filter(function(project) {
                        return project != null;
                    })
                };
                return filteredGroup;
            }).filter(function (group) {
                return group != null && group.Projects.length > 0;
            });
            return filteredList;
        });

        // Get Project list 
        self.getProjectList = function () {
            $.get('/api/pkview/listmyprojects')
            .done(function (projectList) {
                self.projectList(projectList.map(function (group) {
                    group.Submission = { Name: group.Submission, Label: group.Submission };
                    group.Projects = group.Projects.map(function (project) {
                        project.Label = project.Name;
                        return project;
                    });
                    return group;
                }));
                self.responseReady(true);
                self.focusFilter(true);
            });
        };

        // Create a new analysis project
        self.newProject = function () {
            var newProjectDialog = new modal({
                title: "New project",
                model: "tools/pkview/components/home/newProject/newProject",
                activationData: {                    
                    done: function (projectSettings) {

                        var submission = projectSettings.submissionType + projectSettings.submissionNumber;
                        var projectName = projectSettings.name;

                        // Make sure a project does not already exist with the same name
                        var myProjects = self.projectList();
                        for (var i = 0; i < myProjects.length; i++) {
                            // Submission found, look for a matching project name
                            if (myProjects[i].Submission.Name == submission) {
                                var submissionProjects = myProjects[i].Projects;
                                for (var j = 0; j < submissionProjects.length; j++) {
                                    if (submissionProjects[j].Name == projectName) {
                                        app.showMessage("A project already exists with this name, please specify a different project name");
                                        return;
                                    }
                                }

                            }
                        }

                        
                        self.projectName(projectName);
                        self.submission(submission);

                        newProjectDialog.close();
                        self.responseReady(false);
                        self.done(1);
                    }
                },
                width: 0.6                
            });
            dialog.show(newProjectDialog);   
        };        

        // Load an analysis project
        self.load = function (submission, project) {
            var profileName = project;
            self.projectName(profileName);
            self.submission(submission);
            self.done(2);               
        };

        // Make a Meta analysis
        self.MetaAnalysis = function (submission, project) {
            var profileName = project;
            self.projectName(profileName);
            self.submission(submission);
            self.done(3);
        };

        // Load an analysis project and go to data management
        self.dataManagement = function (submission, project) {
            app.showMessage('This is considered an advanced option and may affect the analysis' +
                ' results, are you sure you want to continue?', 'Confirm', ['Yes', 'No'])
            .then(function (answer) {
                if (answer != "Yes") return;
                self.projectName(project);
                self.submission(submission);
                self.done(1);
            });
        };

        // Delete a project
        self.delete = function (submission, project) {
            app.showMessage('Are you sure you want to delete "' +
                submission + ' - ' + project + '"?', 'Confirm deletion', ['Yes', 'No'])
            .then(function (answer) {
                if (answer == 'Yes')
                {
                    $.get("/api/pkview/deleteproject?"
                        + "submission=" + submission
                        + "&project=" + project)
                        .then(function () {
                            self.filterValue("");
                            self.getProjectList();
                        });
                }
            });
            
        };

        // Download project results
        self.download = function (submission, project) {
            net.download("/api/download/PkView/"
                + submission + ".zip"
                + "?subfolder=" + project);      
        };

        // Share project to another user
        self.shareProject = function () {
            var shareDialog = new modal({
                title: "Share Project",
                model: "tools/pkview/components/home/shareProject/shareProject",
                activationData: {
                    done: function () {
                        self.filterValue("");
                        self.getProjectList();
                        shareDialog.close();
                    }
                },
                width: 0.7
            });
            dialog.show(shareDialog);
        };

        // Import configuration from another user
        self.importProject = function () {
            var importDialog = new modal({
                title: "Import Project",
                model: "tools/pkview/components/home/importProject/importProject",
                activationData: {
                    done: function () {
                        self.filterValue("");
                        self.getProjectList();
                        importDialog.close();
                    }
                },
                width: 0.6
            });
            dialog.show(importDialog);
        };
    };

    // Activate the view
    ctor.prototype.activate = function (settings) {
        var self = this;
        self.submission = settings.data.name;
        self.projectName = settings.data.profile;

        // Reset data and hide progress bar
        settings.data.supplement("");
        settings.data.supplements({});
        settings.splash.visible(false);
        settings.allowedSteps([]);

        self.done = settings.done;
        settings.ready();
    };

    // After view is attached
    ctor.prototype.attached = function (view) {
        var self = this;
        self.getProjectList();
    };

    // Clean up
    ctor.prototype.detached = function () {
        var self = this;
        self.filteredProjectList.dispose();
    };

    return ctor;
});