define('tools/ogdTool/components/home/home', [
    'knockout',    
    'durandal/app',
    'plugins/dialog',
    'ocpkmlib/net',
    'shared/components/modal/viewmodels/modal',
    'tools/ogdTool/shared/filter/filter'],
function (ko, app, dialog, net, modal, filter) {

    // This is the mainWindow viewmodel prototype
    var ctor = function () {
        var self = this;

        self.shellData = null; // Data shared betwen this and other sibling views by the shell

        self.responseReady = ko.observable(false); // server response flag          
        self.projectList = ko.observableArray(); // list of projects for the current user
        self.filterValue = ko.observable(""); // filter for the list of projects

        // Computed for the filtered list of projects
        self.filteredProjectList = ko.computed(function () {
            var filterValue = self.filterValue().trim();
            if (!filterValue) return self.projectList();

            var filteredList = self.projectList().map(function (group) {
                // If filter applies to submission name
                var found = filter.markIfFound(group.Submission, filterValue);
                if (found != null) {
                    var highlightedGroup = {
                        Submission: found,
                        Projects: group.Projects.map(function (project) {
                            var found2 = filter.markIfFound(project.Name, filterValue);
                            if (found2 == null) return project;
                            return { Name: found2, HasPackage: project.HasPackage };
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
                        return { Name: found, HasPackage: project.HasPackage };
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
            $.get('/api/ogdtool/listmyprojects')
            .done(function (projectList) {
                self.projectList(projectList);
                self.responseReady(true);
            });
        };

        // Create a new analysis project
        self.newProject = function () {
            var newProjectDialog = new modal({
                title: "New project",
                model: "tools/ogdTool/components/home/newProject/newProject",
                activationData: {                    
                    done: function (projectSettings) {

                        self.shellData.currentProject = {};
                        self.shellData.currentProject.mode = 'create';
                        self.shellData.currentProject.name = projectSettings.name;
                        self.shellData.currentProject.submissionType = projectSettings.submissionType;
                        self.shellData.currentProject.submissionNumber = projectSettings.submissionNumber;

                        newProjectDialog.close();
                        self.shellData.viewSelector.goToView('main');
                    }
                },
                width: 0.6                
            });
            dialog.show(newProjectDialog);   
        };        

        // Load an analysis project
        self.load = function (submission, project) {
            self.shellData.currentProject = {};
            self.shellData.currentProject.mode = 'load';
            self.shellData.currentProject.name = project;
            self.shellData.currentProject.submission = submission;
                   
            self.shellData.viewSelector.goToView('main');               
        };

        // Delete a project
        self.delete = function (submission, project) {
            app.showMessage('Are you sure you want to delete "' +
                submission + ' - ' + project + '"?', 'Confirm deletion', ['Yes', 'No'])
            .then(function (answer) {
                if (answer == 'Yes')
                {
                    $.get("/api/ogdtool/deleteproject?"
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
            net.download("/api/download/OgdTool/"
                + project + ".zip"
                + "?subfolder=" + submission);      
        };

        // Import configuration from another user
        self.importProject = function () {
            var importDialog = new modal({
                title: "Import Project",
                model: "tools/ogdTool/components/home/importProject/importProject",
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

        // Updates the packagePresent flag
        self.updatePackageFlag = function (id) {
            if (id == null || id == '' || typeof id === 'undefined') {
                self.packagePresent(false);
                return;
            }
            if (self.configurationFiles != null && self.configurationFiles().length > 0)
            self.packagePresent(self.configurationFiles()[id].data.PackagePresent);
        };

        self.downloadPackage = function () {
            self.ProfileName(self.configurationFiles()[self.NDAProfileIdx()].data.ProfileName);
            analysis.downloadPackage(self.NDAName(), self.ProfileName());
        };       
    };

    // Activate the view
    ctor.prototype.activate = function (shellData) {
        var self = this;
        self.shellData = shellData;
    };

    // After view is attached
    ctor.prototype.attached = function (view) {
        var self = this;
        self.getProjectList();
    };

    return ctor;
});