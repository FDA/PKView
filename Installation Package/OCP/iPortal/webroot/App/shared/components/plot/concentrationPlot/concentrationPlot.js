define('shared/components/plot/concentrationPlot/concentrationPlot', [
    'knockout',
    'flot',
    'flot_errorbars'
], function (ko, flot, flot_errorbars) {

    // This is the createReportSummary viewmodel prototype
    var ctor = function () {
        var self = this;
        self.plot = {};

        // set default options
        self.plot.options = {
            series: {
                lines: {
                    show: true
                },
                points: {
                    show: true,
                    errorbars: "y",
                    yerr: {
                        show: true,
                        upperCap: "-",
                        lowerCap: "-"
                    }
                }
            },
            legend: {
                noColumns: 1
            },
            xaxis: {
                tickLength: 5,
                tickColor: '#000000'
            },
            yaxis: {
                tickLength: 5,
                tickColor: '#000000'
            },
            selection: {
                mode: "x"
            },
            grid: {
                markings: [],
                color: '#000000'
            }
        };

        // Get x axis ticks
        self.getXticks = function (axis) {
            var ticks = [0];
            for (var i = 0; i < self.plot.data.length; i++) {
                var seriesTicks = self.plot.data[i].data;
                for(var j = 0; j < seriesTicks.length; j++) {
                    var tick = seriesTicks[j][0];
                    if (ticks.indexOf(tick) == -1)
                        ticks.push(tick);
                }                    
            }
            ticks.sort(function (a, b) { return a - b; });
            return ticks;
        };
        self.plot.options.xaxis.ticks = self.getXticks;

        // Tick formatter function
        self.tickFormatter = function (val, axis) {
            return (Math.round(val * 100) / 100) + '';
        };
        self.plot.options.xaxis.tickFormatter = self.tickFormatter;

        // Select a range in the plot
        self.plotSelected = function (event, ranges) {
            var ticks = self.getXticks();
            var from = ranges.xaxis.from;
            var to = ranges.xaxis.to;

            // Find the nominal points within the interval
            var i = 0;
            while (i < ticks.length && ticks[i] < from) i++;
            if (i < ticks.length) from = ticks[i];
            while (i < ticks.length && ticks[i] <= to) i++;
            if (i > 0) to = ticks[i - 1];

            self.plot.events.plotselectedsimple(from, to);
        };
    };

    // Initialize the view
    ctor.prototype.activate = function (settings) {
        var self = this;
        self.plot.data = settings.data;
        self.plot.events = settings.events;
        
        // Calculate y axis min and max 
        ymin = 0; ymax = 0;
        for (var i = 0; i < self.plot.data.length; i++) {
            var series = self.plot.data[i];
            for (var j = 0; j < series.data.length; j++) {
                var point = series.data[j];
                var stdHalf = point[2];
                var top = point[1] + stdHalf;
                var bottom = point[1] - stdHalf;
                if (top > ymax) ymax = top;
                if (bottom < ymin) ymin = bottom;
            }
        }
        var margin = (ymax - ymin) * 0.02;
        self.plot.options.yaxis.min = ymin - margin;
        self.plot.options.yaxis.max = ymax + margin;

        // setup simplified events
        if (self.plot.events)
        {
            if (self.plot.events.plotselectedsimple) 
                self.plot.events.plotselected = self.plotSelected;            
        }
    };

    // After view is attached
    ctor.prototype.attached = function (view) {
        self = this;
    }

    return ctor;
});