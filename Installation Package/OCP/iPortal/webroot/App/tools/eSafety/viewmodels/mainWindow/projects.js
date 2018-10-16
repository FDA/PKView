define(function (require)
{
    // This is the mainWindow viewmodel prototype
    var projects = function ()
    {
        var self = this;

        // Active project
        self.activeProject = ko.observable();
        self.activeOrFirstProject = ko.computed(function ()
        {
            // If there already is an active project, return it
            if (self.activeProject() != undefined)
                return self.activeProject();
            // Otherwise return the first project, if any
            else
            {
                if (window.iss.projects().length > 0)
                    return window.iss.projects()[0].PROJECT_ID();
                else return undefined;
            }
        });

        // Change the currently Active project
        self.activateProject = function (project)
        {
            self.activeProject(project.PROJECT_ID());
        };

        // Whenever a new project is added, select it as the currently active
        window.iss.projects.subscribe(function (newProjects)
        {
            self.activeProject(newProjects[newProjects.length - 1].PROJECT_ID());
        });

    };

    return projects;
});