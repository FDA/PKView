define([
    'knockout',
    'ocpkmlib/net',
    './modelTemplates'],
function (ko, net, models)
{
    // This is the mainWindow viewmodel prototype
    var mainWindow = function ()
    {
        var self = this;
 
        // Current active screen on the interface
        self.activeStep = ko.observable("showProjectTable");

        // List all the forest plot projects
        self.plotProjects = ko.observableArray([]);
        
        // This observable holds the name of the new project to be created
        self.newProjectName = ko.observable();

        // This observable holds the current project being displayed
        self.project = ko.observable();

        // Selected tab on the interface
        self.chosenPlot = ko.observable();

        // Lists of options for the interface
        self.scaleOptions = [{ name: "linear", value: 1 }, { name: "log10", value: 2 }, { name: "log2", value: 3 }];
        self.styleOptions = [{ name: "Style1", value: 1 }, { name: "Style2", value: 2 }];
        
        // Master settings         
        self.masterSettings = new models.settingsObject();

        // Object to hold the ajax requests for a new plot
        self.ajaxRequests = {};

        // Flag to show customized settings on the master settings tab
        self.customSettings = {};
        $.each(self.masterSettings, function (id, value) {
            self.masterSettings[id].subscribe(function (newVal) {
                $.each(self.project().Plots(), function (plotId, value) {
                    self.project().Plots()[plotId].Settings[id](newVal);
                });
                self.customSettings[id](false);
            });

            self.customSettings[id] = ko.observable(false);
        });
        self.masterPlotPath = new models.plotObject(self.masterSettings);

        // Load the list of projects
        self.loadProjects = function () {
            self.plotProjects([]);
            // Retrieve list of project from server database
            net.ajax({
                url: '/api/forestplot/projectlist/',
                data: {},
                type: "GET",
                contentType: "application/json;charset=utf-8",
                successCallback: function (response) {
                    self.plotProjects(response);
                }
            });
        }

        // Switch to the new project screen where the user will select an
        // Excel file and set a name for the project
        self.createFromExcel = function () {
            self.newProjectName(null);
            self.activeStep("showProjectNameScreen");
        };

        // Delete Project or File 
        self.removeProject = function (project) {
            var app = require('durandal/app'); 
            app.showMessage('Are you sure you want to delete this project?', 'Warning', ['Yes', 'No']).then(function (dialogResult) {
                if (dialogResult == "Yes") {
                    net.ajax({
                        //url: apiUrl,
                        url: '/api/forestplot/deleteproject/' + project.Id,                      
                        type: "DELETE",
                        successCallback: function (response) {    // Successful DELETE
                            app.showMessage('Project "' + response + '" has been Deleted!');
                            self.loadProjects();
                        }
                    });
                }
                else
                {
                    app.showMessage('You select No');
                    self.activeStep("showProjectTable");
                }
            });

        };

        // Edit Project 
        self.editProject = function (project) {
            // Ajax call to server to request the project data 
            //(FW: by sending "project.Id" to server-using Ajax call, then get back the following self.project)
            net.ajax({
                url: '/api/forestplot/plots/',
                data: { projectId: project.Id },
                type: "GET",
                contentType: "application/json; charset=utf-8",
                successCallback: function (response) {
                    self.extendAndBindProject(response);                  
                    self.activeStep("showMultiplePlotScreen");                 
                }
            });
            self.activeStep("retrieveServer");
        };

        // New Project or From Excel
        self.newProject = function () {
            var app = require('durandal/app');
            if ($("#File1").val() == "") {
                app.showMessage('Please Select Excel File to Upload Data.');
            }
            else if (self.newProjectName() == null || $.trim(self.newProjectName()) === '') {
                app.showMessage('The Project Name is required.');
            }
            else {
                // Upload Excel File to server for handling
                net.ajaxUpload({
                    url: '/api/forestplot/uploadfile/',
                    data: {
                        fileInputId: "File1",
                        projectName: self.newProjectName()
                    },
                    processData: false,
                    successCallback: function (data) {
                        // return projectId to self.editProject
                        self.editProject({ Id: data });
                        self.activeStep("showMultiplePlotScreen");
                    }
                });
                self.activeStep("retrieveServer");
            }
        };


         // Set the plot as selected (switch to that plot's tab) 
        self.goToPlot = function (plot)
        {
            self.chosenPlot(plot.Id);
        };

        // Set the master plot as selected (display the master tab)
        self.goToMaster = function (master)
        {            
            self.chosenPlot('masterPlot');
        };

        // Return to Project Table Screen
        self.returnProjectTable = function () {           
            self.activeStep("showProjectTable");
            self.loadProjects();
        };
        
        // Extend project object with knockout observables and bindings
        self.extendAndBindProject = function (rawProject)
        {            
            rawProject.Plots = ko.observableArray(rawProject.Plots);

            // Add plot object
            $.each(rawProject.Plots(), function (plotId, value)
            {              
                rawProject.Plots()[plotId].Settings = new models.settingsObject(rawProject.Plots()[plotId].Settings);
                rawProject.Plots()[plotId].plotPath = new models.plotObject(rawProject.Plots()[plotId]);
                rawProject.Plots()[plotId].plotImg = ko.observable('');

                // Add trigger to update plot image
                var thisImage = rawProject.Plots()[plotId].plotImg;
                var updatePlot = function (path)
                {
                    // Save the current plot                    
                    var oldImage = thisImage();

                    // Abort any previous request for the same plot id
                    if (typeof (self.ajaxRequests[plotId]) != 'undefined')
                        self.ajaxRequests[plotId].abort();

                    // Request the plot to be generated
                    var requestPlot = function ()
                    {
                        self.ajaxRequests[plotId] = net.ajax({
                            url: path,
                            data: {},
                            type: "GET",
                            contentType: "application/json; charset=utf-8",
                            successCallback: function (rawImageData) {
                                if (rawImageData == null || $.trim(rawImageData) === '') requestPlot();
                                else thisImage(rawImageData);
                            }
                        });
                    }
                    requestPlot();
                    // temporarily set a progress indicator
                    thisImage('');
                }
                // Initial request of the plot
                updatePlot(rawProject.Plots()[plotId].plotPath());
                // Subscribe plot update function to changes in the plot path
                rawProject.Plots()[plotId].plotPath.subscribe(updatePlot);
            });

            self.project(rawProject);

            $('.fpSlider').slider().on('slide', function ()
            {
                $(this).trigger('change');
            });

            // Bind sliders on master tab to the rest of the interface
            $("#rangeMasterSlider").slider().on('slide', function ()
            {
                var newValue = [$(this).val().split(',')[0], $(this).val().split(',')[1]];
                $.each($(".rangeSlider"), function (id, childSlider)
                {
                    $(childSlider).slider('setValue', newValue);

                });
                $(this).trigger('change');
                self.customSettings['range'](false);
                self.customSettings['rangeBottom'](false);
                self.customSettings['rangeTop'](false);
            });
            $("#stepMasterSlider").slider().on('slide', function ()
            {
                var newValue =$(this).val();
                $.each($(".stepSlider"), function (id, childSlider)
                {
                    $(childSlider).slider('setValue', newValue);

                });
                $(this).trigger('change');
                self.customSettings['rangeStep'](false);
            });

            
            self.project().Plots.subscribe(function () {
                // Setup sliders
                $('.fpSlider').slider().on('slide', function ()
                {
                    $(this).trigger('change');
                });             
            }); 
            self.chosenPlot(self.project().Plots()[0].Id);  // retrieve first Plot's plotId
            
            // Flag to show customSetting change on Master Plot
            $.each(self.project().Plots(), function (plotId, value)
            {
                $.each(self.project().Plots()[plotId].Settings, function (id, value)
                {
                    self.project().Plots()[plotId].Settings[id].subscribe(function (newVal)
                    {
                        self.customSettings[id](true);
                    });
                });
            });           
        };       
    };

    // This function will be executed after the viewmodel is bound to the view
    mainWindow.prototype.attached = function (view)
    {
        var self = this;        
        self.loadProjects();      
    };

    return mainWindow;
});