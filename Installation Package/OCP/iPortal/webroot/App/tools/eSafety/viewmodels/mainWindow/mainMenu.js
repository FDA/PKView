define(function (require)
{
    var issGui = require('issGui/issGui');

    // This is the mainMenu viewmodel prototype
    var mainMenu = function ()
    {
        var self = this;
        
        // Toggle maximized state
        self.maximizeToggle = function ()
        {
            var maximizeFunction = $('#mainWindow').data('maximizeToggle');
            maximizeFunction();
        };

        // Menu events
        this.onMenuSelect = function (event)
        {
            // Open the new project dialog
            switch ($(event.item).children(".k-link").text())
            {
                case 'New Project': issGui.showIssDialog('viewmodels/mainWindow/newProjectDialog');
            }
        };
    };

    // This function will be executed after the viewmodel is bound to the view
    mainMenu.prototype.viewAttached = function (view)
    {
        // Create a kendo menu in the menu element
        $("#menuList").kendoMenu({ select: this.onMenuSelect });
    };

    return mainMenu;
});