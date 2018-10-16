define(function (require)
{
    var issData = require('issData/issData');
    var issGui = require('issGui/issGui');

    // This is the newDialog viewmodel prototype
    var NewProjectDialog = function ()
    {
        var self = this;

        // Settings for the dialog window
        self.title = "New Project";
        self.width = 400;

        // Menu data
        self.projectTypes = ko.observableArray
        ([
            { displayText: 'Empty Project', icon: 'fa-inbox', value: 'basic' },
            { displayText: 'Easy Start Wizard', icon: 'fa-magic', value: 'wizard' }
        ]);

        // Workflow template list
        self.workflowTemplates = ko.observableArray
        ([
            { displayText: '', value: undefined },
            { displayText: 'Study Data Summary Report', value: 'summary' },
            { displayText: 'Logistic Regression Analysis', value: 'logistic' },
            { displayText: 'Survival Analysis', value: 'survival' }
        ]);

        // Project settings
        self.projectMode = ko.observable("basic");
        self.selectedTemplate = ko.observable();
        self.projectName = ko.observable('');

        // Change the selected menu item
        self.switchProjectType = function (selected)
        {
            self.projectMode(selected.value);
        };

        // Create new project structure and do the necessary initializations
        self.startProject = function ()
        {
            // Create the project
            issData.createProject({ name: self.projectName() })
            // If the project is successfully created
            .then(function (project)
            {
                // Create a default workflow
                project.newWorkflow({ name: 'Workflow 1' })
                .then(function (workflow)
                {
                    // Create the data input module for the first workflow
                    // var step = issData.addStepToWorkflow(project.PROJECT_ID(), workflow.id(), { name: "Data Input", module: "dataInput" });
                    // Show the wizard if needed
                    if (self.projectMode() == 'wizard')
                        issGui.showIssWizard();
                    // Close the dialog         
                    self.close();
                });
            });
        };

    };

    NewProjectDialog.prototype.viewAttached = function ()
    {
        $("#selectTemplate").kendoComboBox({ filter: 'contains', suggests: true });
    };

    return NewProjectDialog;
});