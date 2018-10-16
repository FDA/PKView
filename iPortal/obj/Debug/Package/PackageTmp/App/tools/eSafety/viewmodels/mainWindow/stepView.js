define(function (require)
{
    var system = require('durandal/system');

    // Viewmodel constructor
    var stepView = function (step)
    {
        // Make the object accessible in the private members
        var self = this;

        self.step = step;

        // Get an instance of the child view
        system.acquire("viewmodels/modules/" + step.moduleId() + "/main").then(function (viewModule)
        {
            self.step.moduleView(new viewModule());
        });
    };

    return stepView;
});