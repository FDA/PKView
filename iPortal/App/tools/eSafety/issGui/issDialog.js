define(function (require)
{
    var system = require('durandal/system');
    var dialog;
    var self;

    // Viewmodel constructor
    var IssDialog = function (childView)
    {
        // Make the object accessible in the private members
        self = this;

        // This observable will hold the child view inside the dialog
        self.childView = ko.observable('');

        // Extra parameters object for the child view module
        self.arguments = undefined;

        // Dialog initialization function    
        self.initializeDialog = function (viewModule)
        {
            dialog = require('plugins/dialog');

            // Store previous viewAttached function in case the child view had one
            var oldViewAttached = viewModule.prototype.viewAttached;

            // Initialize the kendo window after the view is attached
            viewModule.prototype.attached = function ()
            {       
                // Run the child view's viewAttach function
                if ($.isFunction(oldViewAttached)) oldViewAttached();
            };

            // Close function for the child view
            viewModule.prototype.close = function ()
            {
                dialog.close(self);
            };

            self.childView(new viewModule(self.arguments));
        };

        // if the input is a string, it is the path to the module
        if (typeof childView == 'string')
        {
            // Get an instance of the child view
            system.acquire(childView).then(self.initializeDialog);
        }
        // if the input is an object extract the path
        else if ((typeof childView == "object") && (childView.hasOwnProperty('path')))
        {
            self.arguments = childView.arguments;
            childView = childView.path;
            system.acquire(childView).then(self.initializeDialog);
        } 
        // treat the object as a module
        else self.initializeDialog(childView);

    };

    return IssDialog;
});