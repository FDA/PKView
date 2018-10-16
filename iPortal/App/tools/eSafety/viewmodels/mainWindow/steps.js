define(function (require)
{
    //var issData = require('issData/issData');

    // This is the workflows viewmodel prototype
    var steps = function (workflow)
    {
        var self = this;

        self.workflow = workflow;

        // Currently active step
        self.activeStep = ko.observable();
        self.activeOrFirstStep = ko.computed(function ()
        {
            // If there already is an active step, return it
            if (self.activeStep() != undefined)
                return self.activeStep();
            // Otherwise return the first project, if any
            else
            {
                if (workflow.steps().length > 0)
                    return workflow.steps()[0].id();
                else return undefined;
            }
        });

        // Change the currently Active workflow
        self.activateStep = function (step)
        {
            self.activeStep(step.id());
        };

        // Add a step
        self.addStep = function ()
        {
            var addStepCallback = function (issData)
            {
                issData.addStepToWorkflow(self.workflow.projectId,
                    self.workflow.id(), { name: "Logistic Regression", module: "logisticRegression" });
            };   
            var step = require(['issData/issData'], addStepCallback);
        };

    };

    return steps;
});