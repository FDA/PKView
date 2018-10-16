define(['knockout'], function (ko) {

    // Templates for the data models used in forest plot
    var modelTemplates = {

        // This object represents plot settings
        settingsObject: function (initialData) {
            var self = this;
            self.DrugName = ko.observable("DrugName");
            self.Title = ko.observable("Title");
            self.Scale = ko.observable("linear");
            self.Xlabel = ko.observable("X-Axis Label");
            self.FootNote = ko.observable("FootNote");
            self.Style = ko.observable("Style1");
            
            // initial range for slider           
            self.range = ko.observable("0,10");

            // split range data to bottom & top data 
            self.RangeBottom = ko.computed({

                read: function () {
                    return self.range().split(',')[0];
                },
                write: function (newBottom) {
                    self.range(newBottom + "," + self.RangeTop());
                }
            });
            self.RangeTop = ko.computed(
            {
                read : function() {
                    return self.range().split(',')[1];         
                },
                write : function(newTop) {
                    self.range(self.RangeBottom() + "," + newTop);
                }
            });

            // Step for range
            self.RangeStep = ko.observable("0.1");

            // If initialization data was received, fill
            // the object with it
            if (typeof (initialData) != 'undefined') {
                $.each(initialData, function (id, value) {
                    self[id](initialData[id]);
                });
            }
        },

        // This object computes the url to retrieve a plot 
        plotObject: function (plot) //--> FW : change this to url sent from controller
        {
            return ko.computed(
            {
                read: function () {
                    var path = "api/forestplot/generateplot/run?jsonPlot=";
                    path += encodeURIComponent(JSON.stringify({ Id: plot.Id, Settings: ko.toJS(plot.Settings) }));
                    return path;
                },
                // Empty write function so we dont get an error on the master tab (FIXME)
                write: function (newStep) {}
            }).extend({ throttle: 500 });
        }

    };

    return modelTemplates;
});