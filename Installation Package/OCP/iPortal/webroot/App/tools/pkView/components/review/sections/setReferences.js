define('tools/pkview/components/review/sections/setReferences', [
    'knockout',
    'durandal/app',
    'plugins/dialog',
    'ocpkmlib/net',
    'ocpkmlib/txt'],
function (ko, app, dialog, net, txt) {
    var ctor = function () {
        var self = this;
        self.loading = ko.observable(true);

        self.study = null; 
        self.arms = null;

        // Add one treatment or group
        self.addTreatment = function () {
            for (var i = 0; i < self.arms.length; i++)
                self.addSingleTreatment(self.arms[i]);
        };

        // remove last treatment or group
        self.removeTreatment = function () {
            for (var i = 0; i < self.arms.length; i++)
                if (!self.removeSingleTreatment(self.arms[i])) return;
        };

        // Add one treatment or group
        self.addSingleTreatment = function (arm) {
                arm.treatments.push(ko.observable());
        };

        // remove last treatment or group
        self.removeSingleTreatment = function (arm) {
            if (arm.treatments().length == 1) {
                app.showMessage('Arms must contain at least one treatment or group');
                return false;
            }
            arm.treatments.pop();
            return true;
        };
        
        // Save changes and close the dialog
        self.save = function () {
            self.close(self.arms);
        };
       
        // Reload treatments from dm
        self.reload = function () {
            self.loading(true);
            var rawArms = self.arms.map(function (arm) { return arm.oldArm; });
            self.calculateArmTreatments(rawArms)
                .then(function () {
                    self.loading(false);
                    setTimeout(self.reposition, 500);
                });
        };

        // request the server to calculate the arm treatments
        self.calculateArmTreatments = function (rawArms) {
            var dfd = $.Deferred();
            
            $.post("/api/pkview/armsToTreatments", { '': rawArms })
                .then(function (arms) {
                    self.arms = arms.map(function (arm) {
                        // make sure theres at least one treatment if not set
                        if (arm.Treatments == null || arm.Treatments.length == 0)
                            arm.Treatments = [""];
                        return {
                            oldArm: arm.OldArm,
                            treatments: ko.observableArray(arm.Treatments.map(function (trt) {
                                return ko.observable(trt);
                            }))
                        };
                    });
                    dfd.resolve();
                });

            return dfd;
        };
    };    

    // Activate the view
    ctor.prototype.activate = function (settings) {
        var self = this;

        self.study = settings.study;
        self.close = settings.close;
        self.reposition = settings.reposition;

        // Attempt to load custom arms
        if (self.study.ArmMappings && self.study.ArmMappings.length > 0) {
            self.arms = self.study.ArmMappings.map(function (arm) {
                return {
                    oldArm: arm.OldArm,
                    treatments: ko.observableArray(arm.Treatments.map(function (trt) {
                        return ko.observable(trt);
                    }))
                }
            });
            self.loading(false);
            setTimeout(self.reposition, 500);
        }
        else { // Calculate a new treatments array from the ARM variable
            var dmDomain = $.grep(settings.study.StudyMappings, function (domain) {
                return domain.Type == "DM";
            })[0];

            var dmFile = dmDomain.FileId;
            var armVarName = $.grep(dmDomain.DomainMappings, function (mapping) {
                return mapping.SdtmVariable == "ARM";
            })[0].FileVariable();

            // request the list of arms in the selected arm variable
            $.post("/api/data/clinical/fromfile/columns/"
                    + armVarName + '/unique', { '': dmFile })
                .then(function (rawArms) {
                    self.calculateArmTreatments(rawArms)
                        .then(function () {
                            self.loading(false);
                            setTimeout(self.reposition, 500);
                        });
                });
        }
    };

    // Clean up
    ctor.prototype.detached = function () {
        var self = this;
    };

    return ctor;
});