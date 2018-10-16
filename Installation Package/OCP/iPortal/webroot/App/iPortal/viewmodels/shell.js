define('iPortal/viewmodels/shell',['knockout', 'plugins/router', 'durandal/app'], function (ko, router, app) {
    var shell = {
        router: router,
        sections: [
        ],
        query: ko.observable(),
        search: function() {
            router.navigate('askOcp?q=' + shell.query());
        },
        activate: function () {
            router.map([
                //code changed to remove 'Welcome' page and set 'PkView' page as start up page
                //changed on 08/03/2017
                { route: '', moduleId: 'tools/pkView/shell', nav: true, title: 'Home' },
                { route: 'pkView', moduleId: 'tools/pkView/shell', nav: true, title: 'PkView' },
                { route: 'pkView2*details', moduleId: 'tools/pkView2/pkView', nav: false, title: 'PkView 2.0' },
                { route: 'pkView/batch', moduleId: 'tools/pkView/viewmodels/batch', nav: false, title: 'PkViewBatch' },
            ]).buildNavigationModel();

            router.makeRelative({ moduleId: 'viewmodels' });
            router.makeRelative({ moduleId: 'views' });

            return router.activate();       
        },
        userData: window.userData
    };
    return shell;
});