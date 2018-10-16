requirejs.config({
    baseUrl: "/",

    paths: {
        // Base libraries for durandal
        'text':        'Lib/text/text',             
        'durandal':    'Lib/durandal/js',
        'plugins':     'Lib/durandal/js/plugins',
        'transitions': 'Lib/durandal/js/transitions',

        // External core libraries
        'knockout':     'Lib/knockout/knockout-3.3.0',
        'bootstrap':    'Lib/bootstrap/js/bootstrap.min',
        'jquery':       'Lib/jquery-2.1.0',

        // External auxiliary libraries
        datatables:          'Lib/dataTables/media/js/jquery.dataTables',
        datatablesBootstrap: 'Lib/dataTables/bootstrap/dataTables.bootstrap',
        floatThead:          'Lib/floatThead/jquery.floatThead.min',
        selectize:           'Lib/selectize/js/selectize.min',
        koSelectize:         'Lib/selectize/js/ko_selectize',
        knockstrap:          'Lib/knockstrap/knockstrap.min',
        jqueryUiSortable:    'Lib/jquery-ui.sortable/jquery-ui.min',
        flot:                'Lib/flot/jquery.flot.min',
        flot_errorbars:      'Lib/flot/jquery.flot.errorbars.min',
        flot_selection:      'Lib/flot/jquery.flot.selection.min',

        // Application components
        'ocpkmlib': 'Lib/ocpkmlib/js',                   // Utility library for OCPKM apps

        'iPortal':            'App/iPortal',             // Iportal infrastructure and apps        
        'shared':             'App/shared',
        'tools':              'App/tools',

        'viewmodels':         'App/viewmodels',          // Default durandal folder routing
        'views':              'App/views'
    },

    // Dependencies for non AMD libraries
    shim: {
        'bootstrap': ['jquery'],
        'knockstrap': ['bootstrap'],
        'datatablesBootstrap': ['datatables'],
        'flot_errorbars': ['flot']
    }
});

// For outdated modules that call jquery with uppercase Q
define('jQuery', ["jquery"], function ($) { return $; });

define('main', ['durandal/app', 'durandal/viewLocator', 'durandal/system', 'plugins/router', 'knockstrap', 'ocpkmlib/core'],
    function(app, viewLocator, system, router, knockstrap, core) {
        //>>excludeStart("build", true);
        system.debug(true);
        //>>excludeEnd("build");
       
        //specify which plugins to install and their configuration
        app.configurePlugins({
            router: true,
            dialog: true,
            http: true,
            widget: {
                kinds: ['expander']
            }
        });

        // Initialize OCP KM library
        core.init();
        
        app.title = 'iPortal';
        app.start().then(function() {
            //Replace 'viewmodels' in the moduleId with 'views' to locate the view.
            //Look for partial views in a 'views' folder in the root.
            viewLocator.useConvention();          

            //Show the app by setting the root view model for our application with a transition.
            app.setRoot('iPortal/viewmodels/shell', 'entrance');
        });
    });