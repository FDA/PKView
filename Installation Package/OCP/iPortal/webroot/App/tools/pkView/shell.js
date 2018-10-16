define('tools/pkView/shell', [
        'knockout',
        'ocpkmlib/net',
        'durandal/app',
        'plugins/dialog'],
function (ko, net, app, dialog)
{

    // This is the mainWindow viewmodel prototype
    var mainWindow = function ()
    {
        var self = this;
          
        /* Activation data for the views */
        self.NDAData = {
            name: ko.observable(""), // Nda name 
            supplement: ko.observable(""), // Nda supplement
            profile: ko.observable(""), // Nda settings file
            supplements: ko.observable({}) // Object to store study mappings by supplement
        };

        // Returns the nda study mappings for the selected supplement
        self.NDAData.studies = ko.computed(function () {
            if (self.NDAData.supplement() == "") {
                var allStudies = [];
                $.each(self.NDAData.supplements(), function (supplementNumber, supplement) {
                    allStudies = allStudies.concat(supplement.studies);
                });
                return allStudies;
            }
            else {
                var supplement = self.NDAData.supplements()[self.NDAData.supplement()];
                return (typeof (supplement) == 'undefined') ? [] : supplement.studies;
            }
        }); 
        
        // Returns the list of studies excluded from analysis due to data issues for the selected supplement
        self.NDAData.unmappable = ko.computed(function () {
            if (self.NDAData.supplement() == "") {
                var allStudies = [];
                $.each(self.NDAData.supplements(), function (supplementNumber, supplement) {
                    allStudies = allStudies.concat(supplement.unmappable);
                });
                return allStudies;
            }
            else {
                var supplement = self.NDAData.supplements()[self.NDAData.supplement()];
                return (typeof (supplement) == 'undefined') ? [] : supplement.unmappable;
            }
        });
        
        // Returns the list of studies that were not selected by the user for analysis in the selected supplement
        self.NDAData.notSelected = ko.computed(function () {
            if (self.NDAData.supplement() == "") {
                var allStudies = [];
                $.each(self.NDAData.supplements(), function (supplementNumber, supplement) {
                    allStudies = allStudies.concat(supplement.notSelected);
                });
                return allStudies;
            }
            else {
                var supplement = self.NDAData.supplements()[self.NDAData.supplement()];
                return (typeof (supplement) == 'undefined') ? [] : supplement.notSelected;
            }
        });

        // Returns all studies from all supplements regardless of validity
        self.NDAData.allStudies = ko.computed(function () {
            var allStudies = [];
            $.each(self.NDAData.supplements(), function (supplementNumber, supplement) {
                allStudies = allStudies.concat(supplement.studies, supplement.unmappable, supplement.notSelected);
            });
            return allStudies;
        });

        // Application current step
        self.activeStep = ko.observable(0);

        // Application previous step
        self.previousStep = ko.observable(0);

        // Allowed steps
        self.allowedSteps = ko.observableArray([]);

        // Data passed from one step to another
        self.stepInputData = ko.observable();

        /* Used by subviews to display progress */
        self.splash =
        {
            visible: ko.observable(false),
            progress: ko.observable(null),
            feedback: ko.observable(null),
        };

        /* View activation data */
        self.views = [
            {
                title: 'Submission',
                icon: 'crosshairs',
                model: 'tools/pkView/components/home/home',
                data: {
                    ready: function() { self.uiReady(true); },
                    data: self.NDAData,
                        // User can click continue to proceed to settings review or go to the reporting section
                    done: function (target) { self.uiReady(false); self.activateStep(target); },
                    splash: self.splash,
                    previousStep: self.previousStep,
                    allowedSteps: self.allowedSteps
                }
            },
            {
                title: 'Data Management',
                icon: 'eye',
                model: 'tools/pkView/components/review/review',
                data: {
                    data: self.NDAData,
                    ready: function () { self.uiReady(true); self.stepInputData(null); },
                    done: function (data) { self.uiReady(false); self.stepInputData(data); self.activateStep(2); },
                    error: function () { self.activateStep(0); },
                    splash: self.splash,
                    previousStep: self.previousStep,
                    allowedSteps: self.allowedSteps
                }
            },
            {
                title: 'Analysis / Report',
                icon: 'bar-chart-o',
                model: 'tools/pkView/components/report/report',
                data: {
                    data: self.NDAData,
                    ready: function () { self.uiReady(true); },
                    error: function () { self.activateStep(0); },
                    splash: self.splash,
                    previousStep: self.previousStep,
                    allowedSteps: self.allowedSteps,
                    inputData: self.stepInputData
                }
            },
            {
                title: 'Forest Plot Meta Analysis',
                icon: 'fa-cubes',
                model: 'tools/pkView/components/review/MetaAnalysis',
                data: {
                    data: self.NDAData,
                    inputData: self.stepInputData,
                    ready: function () { self.uiReady(true);},
                    error: function () { self.activateStep(0); },
                    splash: self.splash,
                    previousStep: self.previousStep,
                    allowedSteps: self.allowedSteps
                }
            },
            {
                title: 'Variability Meta Analysis',
                icon: 'fa-building',
                model: 'tools/pkView/components/review/VariabilityMetaAnalysis',
                data: {
                    data: self.NDAData,
                    inputData: self.stepInputData,
                    ready: function () { self.uiReady(true); },
                    error: function () { self.activateStep(0); },
                    splash: self.splash,
                    previousStep: self.previousStep,
                    allowedSteps: self.allowedSteps
                }
            }
        ];

        //Whenever the main screen becomes the active step, reset all data
        self.activateStep = function (target) {
            self.previousStep(self.activeStep());
            self.activeStep(target);
        };

        self.uiReady = ko.observable(false); // Indicates wether ui is ready to display or it should be replaced by loading screen

        // Navigate the breadcrumbs
        self.navigate = function (index) {
            self.stepInputData(null);
            self.activateStep(index);
            return false;
        };
    };

    // Executed when the veiw is activated
    mainWindow.prototype.activate = function ()
    {
        this.splash.visible(false);
    }

    // This function will be executed after the viewmodel is bound to the view
    mainWindow.prototype.attached = function (view)
    {
        var self = this;
    };

    return mainWindow;

    /*
    <!-- ko foreach: views -->
            <li data-bind="css: { active: $index() == $root.activeStep() }">
                <!-- ko if: $root.allowedSteps.indexOf($index()) > -1 -->
                <a href="#" data-bind="click: function () { $root.navigate($index()); }, tooltip: { title: title }" style="display: inline">
                    <span class="badge" data-bind="text: $index() + 1"></span>
                    <span data-bind="text: title"></span>
                </a>
                <!-- /ko -->
                <!-- ko ifnot: $root.allowedSteps.indexOf($index()) > -1 -->
                <span data-bind="tooltip: { title: title }" style="display: inline">
                    <span class="badge" data-bind="text: $index() + 1"></span> 
                    <span data-bind="text: title"></span>
                </span>
                <!-- /ko -->
            </li>
        <!-- /ko -->
    */
});