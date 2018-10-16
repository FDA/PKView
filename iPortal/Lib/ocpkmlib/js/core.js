/**
 * The net module from the iPortal library contains utility functions for network communication.
 * @module net
 * @requires durandal/app
 */
define('ocpkmlib/core',['durandal/app'], function (app)
{
    var ocpkmlibCore =
    {
        /* Initialize the ocpkmlib library
         * @method init
         */
        init: function()
        {
            app.configurePlugins({
                kmWidget: {
                    kinds: ['collapsiblePanel',
                            'repeater',
                            'dynamicFrames',
                            'saveBox',
                            'formFieldTextbox',
                            'formFieldDatebox',
                            'formFieldSelect',
                            'tableView'
                    ]
                },
                frameDialog: true,
            }, 'ocpkmlib/plugins/');
        }
    };

    return ocpkmlibCore;
});