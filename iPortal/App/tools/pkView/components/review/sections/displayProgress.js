define('tools/pkview/components/review/sections/displayProgress', [
    'knockout',
    'durandal/app',
    'plugins/dialog',
    'ocpkmlib/net',
    'ocpkmlib/txt'],
    function (ko, app, dialog, net, txt) {
        var ctor = function () {
            var self = this;
            self.complete = ko.observable(false);
            var startTime = new Date();
            var endTime;
            self.timeElapsed = ko.observable("0");
            self.timeRemaining = ko.observable("0");
            self.timeCalculated = ko.observable(false);
            var oldPercent = 0;
            var totalTime = 0;

            self.checkForResults = function (jobId) {
                self.complete(false);
                net.ajax({
                    url: "/api/pkview/IssMappings/tryGet",
                    data: { jobId: jobId },
                    successCallback: function (response) {
                        switch (response.Status) {
                            case 0:
                                app.showMessage("SAS error", 'PkView', ['OK']);
                                self.close({ complete: self.complete() });
                                self.splash.visible(false);
                                return;
                            case 1:
                                self.splash.feedback(response.FeedbackMessage);
                                self.splash.progress(response.PercentComplete);
                                self.checkTime(response.PercentComplete, response.FeedbackMessage);
                                self.timer = setTimeout(function () { self.checkForResults(jobId); }, 1000);
                                return;
                            case 2:
                                self.complete(true);
                                self.splash.visible(false);
                                self.close({ complete: self.complete() });
                                return;
                            case 3:
                                app.showMessage("SAS error", 'PkView', ['OK']);
                                self.close({ complete: self.complete() });
                                self.splash.visible(false);
                                return;
                        }
                    },
                    errorCallback: function (response) {
                        app.showMessage('Analysis failed', 'PkView', ['OK']);
                        self.displaySpinner(false);
                    }
                });
            };

            self.checkTime = function (PercentComplete, FeedbackMessage) {
                endTime = new Date();
                var timeDone = endTime - startTime;
                if (FeedbackMessage != "Starting Job on server") {
                    if (PercentComplete != oldPercent) {
                        self.timeCalculated(true);
                        totalTime = (timeDone * 100) / PercentComplete;
                        oldPercent = PercentComplete;
                    }
                }
                var newTime = totalTime - timeDone;
                timeDone /= 1000;
                var date = new Date(null);
                date.setSeconds(timeDone);
                self.timeElapsed(date.toISOString().substr(11, 8));
                newTime /= 1000;
                if (newTime > 0) {
                    date = new Date(null);
                    date.setSeconds(newTime);
                    self.timeRemaining(date.toISOString().substr(11, 8));
                }
            };

        }

        // Activate the view
        ctor.prototype.activate = function (settings) {
            var self = this;
            self.jobId = settings.jobId;
            self.splash = settings.splash;
            self.close = settings.close;
            self.splash.visible(true);
            self.splash.feedback("Starting job on server");
            self.splash.progress("0");
            //self.timeEstimate("Determining estimated time required...");
            self.timer = setTimeout(function () { self.checkForResults(self.jobId); }, 1000);
        };

        // Clean up
        ctor.prototype.detached = function () {
            var self = this;
        };

        return ctor;
    });