define(function (require)
{
    var app = require('durandal/app');
    var IssDialog = require('../issGui/issDialog');
    var IssWizard = require('../issGui/issWizard');

    // module prototype
    var issGui =
    {
        // returns a modal dialog with a Kendo UI window
        showIssDialog: function (childView)
        {
            // Create the modal, then convert view to kendo window
            return app.showDialog(new IssDialog(childView));
        },

        // returns a wizard
        showIssWizard: function (wizardArray)
        {
            // Create the modal, then convert view to kendo window
            return app.showDialog(new IssWizard(wizardArray));
        },

        // returns a table preview dialog
        showIssTable: function (tableData)
        {
            return this.showIssDialog({ path: 'tools/eSafety/issGui/issTable', arguments: tableData });
        }
    };

    return issGui;
});