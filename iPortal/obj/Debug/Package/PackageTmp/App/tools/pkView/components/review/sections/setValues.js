define('tools/pkview/components/review/sections/setValues', [
    'knockout',
    'durandal/app',
    'plugins/dialog',
    'ocpkmlib/net',
    'ocpkmlib/txt'],
function (ko, app, dialog, net, txt) {
    var ctor = function () {
        var self = this;
        self.loading = ko.observable(true);

        self.domain = "";
        self.varName = "";
        self.customize = ko.observable(false);
        self.study = null;
        self.valueMappings = null;

        // Save changes and close the dialog
        self.save = function () {
            var customize = self.customize();
            var mappings = customize ? self.valueMappings : null;
            self.close({ customize: customize, mappings: mappings });
        };
       
        // Reload mappings from original domain
        self.reload = function () {
            self.loading(true);
            var oldValues = self.valueMappings.map(function (v) { return v.oldValue; });
            self.calculateValueMappings(oldValues)
                .then(function () {
                    self.loading(false);
                    setTimeout(self.reposition, 500);
                });
        };

        // request the server to calculate the arm treatments
        self.calculateValueMappings = function (oldValues) {
            var dfd = $.Deferred();
            
            $.post("/api/pkview/mapValues/" + self.domain + '/' + self.varName, { '': oldValues })
                .then(function (valueMappings) {
                    self.valueMappings = valueMappings.map(function (mapping) {                        
                        return {
                            oldValue: mapping.Original,
                            newValue: ko.observable(mapping.New)
                        };
                    });
                    dfd.resolve();
                });

            return dfd;
        };

        // toggle custom values on and off
        self.customizeToggle = function (checked) {

            if (checked) {
                if (self.valueMappings == null) {
                    self.loading(true);

                    // Calculate a new set of values from the original variable
                    var domainData = $.grep(self.study.StudyMappings, function (domain) {
                        return domain.Type == self.domain.toUpperCase();
                    })[0];

                    var domainFile = domainData.FileId;
                    var varName = $.grep(domainData.DomainMappings, function (mapping) {
                        return mapping.SdtmVariable == self.varName.toUpperCase();
                    })[0].FileVariable();

                    // request the list of values in the selected domain variable
                    $.post("/api/data/clinical/fromfile/columns/"
                            + varName + '/unique', { '': domainFile })
                        .then(function (rawValues) {
                            self.calculateValueMappings(rawValues)
                                .then(function () {
                                    self.loading(false);
                                    setTimeout(self.reposition, 500);
                                });
                        });
                } else self.reload();
            }           
        }
    };    

    // Activate the view
    ctor.prototype.activate = function (settings) {
        var self = this;

        self.study = settings.study;
        self.domain = settings.domain;
        self.varName = settings.varName;
        self.close = settings.close;
        self.reposition = settings.reposition;
      
        // Attempt to load custom value mappings
        var mappings = settings.mappings;
        if (mappings && mappings.length > 0) {
            self.valueMappings = mappings.map(function (mapping) {
                return {
                    oldValue: mapping.Original,
                    newValue: ko.observable(mapping.New)
                }
            });
            self.customize(true);
        }

        // Subscribe to checkbox toggle
        self.customizeSubscription = self.customize.subscribe(self.customizeToggle);

        self.loading(false);
        setTimeout(self.reposition, 500);
    };

    // Clean up
    ctor.prototype.detached = function () {
        var self = this;
        self.customizeSubscription.dispose();
    };

    return ctor;
});