define(function (require)
{
    // This is the workflows viewmodel prototype
    var workflows = function (project)
    {
        var self = this;

        // Project this view refers to
        self.project = project;

        // Active workflow
        self.activeWorkflow = ko.observable();
        self.activeOrFirstWorkflow = ko.computed(function ()
        {
            // If there already is an active project, return it
            if (self.activeWorkflow() != undefined)
                return self.activeWorkflow();
            // Otherwise return the first project, if any
            else
            {
                if (project.workflows().length > 0)
                    return project.workflows()[0].id();
                else return undefined;
            }
        });

        // Change the currently Active workflow
        self.activateWorkflow = function (workflow)
        {
            self.activeWorkflow(workflow.id());
        };

    };

    workflows.prototype.viewAttached = function ()
    {
    };

    return workflows;
});