define(function (require)
{
    var issData = require('issData/issData');
    var issGui = require('issGui/issGui');
    var system = require('durandal/system');

    // This is the logisticRegression viewmodel prototype
    var logisticRegression = function ()
    {
        var self = this;

        // Settings
        self.settings =
        {
            responseType: ko.observable("AE"),
            placebo: ko.observable(""),
            model: ko.observable()
        }

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
                    { key: "Filtering", value: "VISIT = 'Cycle 1 Day 1' AND PCANALYT = 'AA21004'" },
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

    logisticRegression.prototype.viewAttached = function ()
    {

        $("select.logisticSelect").kendoComboBox({ filter: 'contains', suggests: true });
        $("input.binSlider").kendoSlider
        ({
            min: 0,
            max: 30,
            smallStep: 1,
            largeStep: 10,
            showButtons: false
        });
    };

    return logisticRegression;
});