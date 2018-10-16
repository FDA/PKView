define(function (require)
{
    var ko = require('knockout');
    var issGui = require('../issGui/issGui');

    // Class to represent a step in the project tree
    var Step = function (data)
    {
        var self = this;
        self.Name = data.Name;
        self.Type = data.Type;
        self.Children = ko.observableArray([]);
        self.Parent = data.Parent;

        // Method to add a step as child of the current one
        self.addStep = function (data2)
        {
            data2.Parent = self;
            self.Children.push(new Step(data2));
        };
    };

    // This is the mainWindow viewmodel prototype
    var mainWindow = function ()
    {
        var self = this;

        // Project tree of steps
        self.project = ko.observableArray([]);
        self.project.push(new Step({ Name: "Data Input", Type: "dataInput", Parent: null }));
        //self.project()[0].addStep(new Step({ Name: "Subset (AE)", Type: "subset" }));
        //self.project()[0].addStep(new Step({ Name: "Subset (AE/Age)", Type: "subset" }));
        //self.project()[0].addStep(new Step({ Name: "Subset (AE/Sex)", Type: "subset" }));
        //self.project()[0].Children()[0].addStep(new Step({ Name: "Logistic Regression", Type: "logistic" }));
        //self.project()[0].Children()[0].addStep(new Step({ Name: "Survival Analysis", Type: "survival" }));
        //self.project()[0].Children()[1].addStep(new Step({ Name: "Logistic Regression", Type: "logistic" }));
        //self.project()[0].Children()[2].addStep(new Step({ Name: "Survival Analysis", Type: "survival" }));

        self.test = { name: "foobar" };
        self.activeNode = ko.observable(self.project()[0]);
        self.activateNode = function(node)
        {
            self.activeNode(node);
        };

        self.nextStepChildrenOptions = ko.computed(function () {
            if (self.activeNode().Children().length > 0)
                return self.activeNode().Children();
            else {
                return [];
            }
        });

        self.nextStepNewOptions = ko.computed(function () {
            switch (self.activeNode().Type) {
                case "dataInput":
                    return [{ Name: "Subset", Type: "subset" }];
                case "subset":
                    return [{ Name: "Logistic Regression", Type: "logistic" },
                    { Name: "Survival Analysis", Type: "survival" }];
                default: return [];
            }
        });

        self.nextStep = function (step) {
            if (self.activeNode().Children().length > 0)
                self.activeNode(step);            
        };

        self.newStep = function (step) {
            var id = self.activeNode().Children().length;
            self.activeNode().addStep(new Step(step));
            self.activeNode(self.activeNode().Children()[id]);
        };

        self.previousStep = function () {
            if (self.activeNode().Parent != null)
                self.activeNode(self.activeNode().Parent);
        };

        // List of input file types
        self.fileTypes = ko.observableArray
        ([
           { id: "demographic", name: "Demographic" },
           { id: "adverseEvents", name: "Adverse Events" },
           { id: "exposure", name: "Exposure" }
        ]);

        // list of input files
        self.files = ko.observableArray([]);
        self.files.push(
        {
            id: "dm",
            name: "dm.xpt",
            type: "demographic",
            variables:
            [
                { description: "", id: "" },
                { description: "ADJTRT -- Adj Trt for primary diag of melanoma", id: "ADJTRT" },
                { description: "ADJTYPE1 -- Type of Adjuvant Treatment", id: "ADJTYPE1" },
                { description: "ADJTYPE2 -- Type of Adjuvant Treatment", id: "ADJTYPE2" },
                { description: "ADJTYPE3 -- Type of Adjuvant Treatment", id: "ADJTYPE3" },
                { description: "AGE -- Age (years) at randomisation", id: "AGE" },
                { description: "AGECAT -- Age Group (<=40)", id: "AGECAT" },
                { description: "AGEGRP -- Age Group (<65yrs)", id: "AGEGRP" },
                { description: "AGELS65 -- Age LT 65 flag", id: "AGELS65" },
                { description: "AGETRT -- Age and Treatment Group", id: "AGETRT" },
                { description: "ALLTRT -- All treated population", id: "ALLTRT" },
                { description: "BASESTG -- Metastatic Melanoma Stg at Base./Random.", id: "BASESTG" },
                { description: "PROTO -- Protocol (in upper case)", id: "PROTO" },
                { description: "TRT1 -- First trial medication", id: "TRT1" },
                { description: "TRT1DC -- First trial medication begin date", id: "TRT1DC" },
                { description: "TRT1DCO -- Original values for TRT1DC", id: "TRT1DCO" },
                { description: "TRT1DS -- SAS date of the first treatment", id: "TRT1DS" },
                { description: "TRT1DT -- First trial med. begin SAS datetime", id: "TRT1DT" },
                { description: "TRT1DTO -- Original values for TRT1DT", id: "TRT1DTO" },
                { description: "TRT1GRP -- First trial medication group", id: "TRT1GRP" },
                { description: "TRT1TC -- First trial medication begin time", id: "TRT1TC" },
                { description: "TRT1TCO -- Original values for TRT1TC", id: "TRT1TCO" },
                { description: "TUMORCNS -- Did Patient consent to Tumor Biopsy", id: "TUMORCNS" },
                { description: "USUBJID -- Unique subject ID within submission ", id: "USUBJID" },
                { description: "V600E -- BRAF V600E-positive population ", id: "V600E" },
                { description: "V600ETRT -- V600E Mutation and Treatment Group", id: "V600ETRT" },
                { description: "WEIGHTBL -- BL Weight in kg", id: "WEIGHTBL" },
                { description: "WITHSCC -- With SCC flag", id: "WITHSCC" }
            ],
            config: ko.observable({})
        });
        self.files.push({ id: "ae", name: "ae.xpt", type: "adverseEvents", variables: [],  config: ko.observable({}) });
        self.files.push({ id: "exp", name: "exp.xpt", type: "exposure", variables: [], config: ko.observable({}) });

        // Active file
        self.activeFile = ko.observable();
        self.activeOrFirstFile = ko.computed(function ()
        {
            // If there already is an active file, return it
            if (self.activeFile() != undefined)
                return self.activeFile();
            // Otherwise return the first project, if any
            else
            {
                if (self.files().length > 0)
                    return self.files()[0].id;
                else return undefined;
            }
        });

        // Change the currently Active workflow
        self.activateFile = function (file)
        {
            self.activeFile(file.id);
        };

        self.file = { config: ko.observable()};
        self.file.config({
            studyId: ko.observable('PROTO'),
            subjectId: ko.observable('USUBJID'),
            treatmentGroup: ko.observable('TRT1')
        });

        self.file.demographicTable = ko.observableArray([
            ["", "A", "", "B", "", "DRUG X", "", "DRUG Y", ""],

["", "n", "(%)", "n", "(%)", "n", "(%)", "n", "(%)"],
["Number of Subjects", 336, "", 282, "", 32, "", 132, ""],
["", "", "", "", "", "", "", "", ""],
["Sex", "", "", "", "", "", "", "", ""],
["Female", 137, "(40.7)", 123, "(43.6)", 14, "(43.7)", 51, "(38.6)"],
["Male", 199, "(59.2)", 159, "(56.3)", 18, "(56.2)", 81, "(61.3)"],
["", "", "", "", "", "", "", "", ""]
["Race", "", "", "", "", "", "", "", ""],
["Asian", 0, "", 0, "", 1, "(3.1)", 0, ""],
["Caucasian", 0, "", 1, "(0.3)", 0, "", 0, ""],
["Hispanic", 2, "(0.5)", 0, "", 2, "(6.2)", 2, "(1.5)"],
["Non-Hispanic", 1, "(0.2)", 0, "", 0, "", 0, ""],
["Syrian", 1, "(0.2)", 0, "", 0, "", 0, ""],
["White", 332, "(98.8)", 281, "(99.6)", 29, "(90.6)", 130, "(98.4)"],
["", "", "", "", "", "", "", "", ""],
["Ldh At Baseline Category", "", "", "", "", "", "", "", ""],
["{0} Normal", 0, "", 0, "", 17, "(53.1)", 67, "(50.7)"],
["{1} Normal To 1.5*normal", 0, "", 0, "", 5, "(15.6)", 19, "(14.3)"],
["{2} >1.5*normal", 0, "", 0, "", 8, "(25.0)", 46, "(34.8)"],
["{3} Missing", 0, "", 0, "", 2, "(6.2)", 0, ""],
["", "", "", "", "", "", "", "", ""],
["Age Group (<65, >=65)", "", "", "", "", "", "", "", ""],
["<65", 242, "(72.0)", 224, "(79.4)", 28, "(87.5)", 107, "(81.0)"],
[">=65", 94, "(27.9)", 58, "(20.5)", 4, "(12.5)", 25, "(18.9)"],
["", "", "", "", "", "", "", "", ""],
["Bl Ecog Performance Status Code", "", "", "", "", "", "", "", ""],
[0, 0, "", 0, "", 14, "(43.7)", 61, "(46.2)"],
[1, 0, "", 0, "", 18, "(56.2)", 71, "(53.7)"],
["", "", "", "", "", "", "", "", ""],
["Height In Cm", "", "", "", "", "", "", "", ""],
["n", 0, "", 0, "", 32, "", 130, ""],
["Mean", "", "", "", "", 171.9, "", 172.2, ""],
["STD", "", "", "", "", 11.7, "", 9.6, ""],
["Min", "", "", "", "", 154, "", 137.2, ""],
["Max", "", "", "", "", 200.7, "", 195.6, ""],
["Median", "", "", "", "", 170.6, "", 172.1, ""],
["", "", "", "", "", "", "", "", ""],
["Age (Years) At Randomisation", "", "", "", "", "", "", "", ""],
["n", 336, "", 282, "", 32, "", 132, ""],
["Mean", 55.4, "", 52.8, "", 50.4, "", 50.3, ""],
["STD", 13.8, "", 13.7, "", 13.5, "", 14.7, ""],
["Min", 21, "", 17, "", 22, "", 17, ""],
["Max", 86, "", 86, "", 83, "", 82, ""],
["Median", 56, "", 53, "", 52, "", 51.5, ""],
["", "", "", "", "", "", "", "", ""],
["Weight In Kg", "", "", "", "", "", "", "", ""],
["n", 0, "", 0, "", 32, "", 132, ""],
["Mean", "", "", "", "", 78.1, "", 78.7, ""],
["STD", "", "", "", "", 16.2, "", 18.8, ""],
["Min", "", "", "", "", 49.6, "", 45.4, ""],
["Max", "", "", "", "", 108, "", 140.6, ""],
["Median", "", "", "", "", 74.2, "", 75.8, ""],
["", "", "", "", "", "", "", "", ""]]);


        self.riskFactors = ko.observableArray(["", "Sex", "Age", "Baseline Weight", "Baseline BMI"]);
        self.selectedRiskFactors = ko.observableArray([]);
        self.riskFactorSelection = ko.observable("");        

        // show demographic table
        self.viewDemographicTable = function ()
        {
            issGui.showIssTable
            ({
                title: "Demographic Information Summary Table",
                dataCells: self.file.demographicTable
            });
        };

        // Settings
        self.settings =
        {
            responseType: ko.observable("AE"),
            placebo: ko.observable(""),
            model: ko.observable()
        };

        // Dropdown options
        self.selections = ko.observableArray
        ([
            {
                section: "Demographic (dm.xpt)",
                pairs:
                [
                    { key: "Risk Factors", value: "Baseline weight,…" },
                    { key: "Filtering", value: "SAFYN = 'Y' AND, AGE < 65 AND, BL BMI > 20" }
                ]
            },
            {
                section: "Exposure (pcon.xpt)",
                pairs:
                [
                    { key: "Processed Method", value: "Average" },
                    { key: "Filtering", value: "VISIT = 'Cycle 1 Day 1' AND PCANALYT = 'AA'" },
                ]
            }
        ]);

        // Show settings page
        self.showSettings = ko.observable(true);

        // Run analysis
        self.runAnalysis = function ()
        {
            self.showSettings(false);
        };

        // Open the settings panel
        self.openSettings = function ()
        {
            self.showSettings(true);
        };

    };

    // This function will be executed after the viewmodel is bound to the view
    mainWindow.prototype.attached = function (view)
    {
        var self = this;

        //$("select.chosenClass").chosen({ width: '100%' });
    };

    //Workaround until durandal properly supports templating
    if ($("#treeNode").length == 0)
    {
        $("body").append(
            '<script type="text/html" id="treeNode">' +
            '   <li data-bind="css: {active: $data == $root.activeNode() }">' +
            '       <a href="#" data-bind="text: Name, click: $root.activateNode"></a>' +
            '       <ul class="nav nav-pills nav-stacked nav-inner">' +
            '           <!-- ko template: { name: \'treeNode\', foreach: Children } --><!-- /ko -->' +
            '       </ul>' +
            '   </li>' +
            '</script>' +
            '<script type="text/html" id="breadcrumb">' +
            '   <!-- ko if: Parent != null --><!-- ko template: { name: \'breadcrumb\', data: Parent } --><!-- /ko --><!-- /ko -->' +
            '   <!-- ko if: $data == $root.activeNode() --><li class="active"><span data-bind="text: Name"></li><!-- /ko -->' +
            '   <!-- ko if: $data != $root.activeNode() --><li><a href="#" data-bind="text: Name, click: $root.activateNode"></a></li><!-- /ko -->' +
            '</script>');
    } 

    return mainWindow;
});