define('tools/ogdTool/shell', [
        'knockout',
        'koSelectize',
        'ocpkmlib/net',
        'durandal/app',
        'plugins/dialog'],
function (ko, koSelectize, net, app, dialog)
{

    // OGD Tool main view. This will load sub-views and components as needed
    var main = function ()
    {
        var self = this;                                          

        // Id of the sub-view currently active
        self.activeViewId = ko.observable(0);

        /* sub-view definitions */
        self.views = [
            { name: 'home', model: 'tools/ogdTool/components/home/home' },
            { name: 'main', model: 'tools/ogdTool/components/main/main' }
        ];

        //Whenever the main screen becomes the active step, reset all data
        self.activateView = function (target) {
            self.activeViewId(target);
        };
        
        // Data to be passed between child views
        self.shellData = {
            viewSelector: {
                goToView: function (viewName) {
                    self.views.map(function (view, index) {
                        if (view.name == viewName)
                            self.activateView(index);
                    });
                }
            },
            currentProject: null
        };

    };

    // Executed when the veiw is activated
    //main.prototype.activate = function () { }

    // This function will be executed after the viewmodel is bound to the view
    main.prototype.attached = function (view)
    {
        var self = this;
    };

    return main;
});