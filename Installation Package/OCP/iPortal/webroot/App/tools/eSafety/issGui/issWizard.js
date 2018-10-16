define(function (require)
{
    var system = require('durandal/system');

    // Viewmodel constructor
    var IssWizard = function (wizardArray)
    {
        // Make the object accessible in the private members
        var self = this;

        // Wizard commands list
        self.wizards = {};
        self.wizards.logisticRegression =
        [{
            command: 'set',
            key: 'title',
            value: 'Logistic Regression'
        }, {
            command: 'set',
            key: 'parentSelector',
            value: 'div.projectWorkflows:visible'
        },
        {
            command: 'show',
            target: 'li.workflowTab.active',
            text: '<p class="justified">When you start a project, a workflow is created by default.</p>' +
                '<p class="justified">A workflow consists of a series of related steps, such as data input, ' +
                'summaries and analyses. A project can hold multiple workflows where ' +
                'different decision paths are taken.</p>'
        },
        {
            command: 'show',
            target: '.stepsBreadcrumb .active:visible',
            text: '<p class="justified">Usually the first step in the workflow will be the selection of ' +
                'data input files, so this step is also always created by default.</p>'
        },
        {
            command: 'show',
            target: '.inputMenu .blockHeader:visible',
            text: '<p class="justified">To add files to the current workflow just click the <b>add</b> button.</p>'
        }];
        self.wizardArray = self.wizards.logisticRegression;

        // Wizard options
        self.options =
        {
            currentStep: 0,
            title: "Title",
            parentSelector: ""
        };

        // This function will run the wizard
        self.runWizard = function ()
        {
            var currentStep = self.options.currentStep;

            // if there are no more steps to run, close the dialog
            if (currentStep == self.wizardArray.length)
                self.modal.close();

            // Get step information
            var step = self.wizardArray[currentStep];

            // We take different actions depending on the command
            switch (step.command)
            {
                // Set a wizard option and call the next step      
                case 'set':
                    self.options[step.key] = step.value;
                    self.options.currentStep++;
                    return self.runWizard();
                    // Show a popover    
                case 'show':
                    // Get the target element
                    var target = $(self.options.parentSelector + " " + step.target);
                    // Set the text in the button depending on the step index
                    var buttonText = (currentStep == self.wizardArray.length - 1) ? "Done" : "Next";
                    // Create the popover
                    target.popover
                    ({
                        title: self.options.title,
                        content: '<div>' + step.text + '</div>' +
                             '<button id="wizardNext" class="btn btn-primary">' + buttonText + '</button>',
                        trigger: "manual",
                        html: true
                    });
                    // Show it
                    target.popover('show');
                    // Highlight the target element over the dimmed background
                    target.addClass('wizardHighlight');
                    // Add the click event to the button
                    $('#wizardNext').click(function ()
                    {
                        target.popover('destroy');
                        target.removeClass('wizardHighlight');
                        self.options.currentStep++;
                        self.runWizard();
                    });
            }
        };
    };

    IssWizard.prototype.viewAttached = function ()
    {
        var self = this;
        self.runWizard();
    };

    return IssWizard;
})