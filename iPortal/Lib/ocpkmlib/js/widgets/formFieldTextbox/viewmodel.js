define(['jquery', 'knockout', 'durandal/app', 'durandal/composition'], function ($, ko, app, composition) {
    var ctor = function () {
        var self = this;

        self.boxSizes = {
            compact: { label: '', control: '' }, 
            medium: { label: 'col-xs-5', control: 'col-lg-6 col-xs-7' },
            mediumWide: { label: 'col-xs-5', control: 'col-xs-7' },
            large: { label: 'col-xs-4 col-sm-2', control: 'col-xs-8' },
            fill: { label: 'pull-left padright', control: 'no-overflow' },
            normal: { label: 'col-xs-4', control: 'col-lg-6 col-xs-8' },
            normalWide: { label: 'col-xs-4', control: 'col-xs-8' },
            nolabel: { label: 'hidden', control: 'col-lg-12' },
        };

        // status flag
        self.modified = ko.observable(false);

        // Set namespace as modified
        self.setModified = function () {
            app.trigger(self.settings.eventNamespace + ':modified', true);
            return true;
        };

        self.getPlaceholder = function () {
            return typeof (self.settings.placeholder) == 'undefined' ?
                self.settings.label : self.settings.placeholder;
        };

        self.getLabelClass = function () {
            var boxClasses = self.boxSizes[self.settings.style];
            if (typeof (boxClasses) == 'undefined')
                return self.boxSizes['normal'].label;
            return boxClasses.label;
        };

        self.getBoxClass = function () {
            var boxClasses = self.boxSizes[self.settings.style];
            if (typeof (boxClasses) == 'undefined')
                return self.boxSizes['normal'].control;
            return boxClasses.control;
        };

        // This method returns a property of the object, useful when 
        // implementing derived widgets
        self.fromTextbox = function (prop) {
            if (typeof (self[prop]) != 'undefined')
                return self[prop];
        };
    };

    ctor.prototype.activate = function (settings) {
        var self = this;
        self.settings = settings;

        // Set namespace to settings, app default or 'default'
        if (!self.settings.eventNamespace)
            self.settings.eventNamespace = $(window).data('eventNamespace') || 'default';

        // If tooltip not specified try to retrieve it from the default tooltip library
        self.settings.tooltip = self.settings.tooltip ||
             $.data(document.body, 'tooltips') ?
                ((self.settings.label ? $.data(document.body, 'tooltips')[self.settings.label] : undefined) ||
                (self.settings.placeholder ? $.data(document.body, 'tooltips')[self.settings.placeholder] : undefined)) : undefined;

        // Set required flag
        self.settings.required = self.settings.required || false;

        // Grey out save button on modified form
        app.on(self.settings.eventNamespace + ':modified').then(function (modified) {
            self.modified(modified);
        });

        // Addon settings
        self.addonsOnLeft = ko.observable(false);
        self.addonsOnRight = ko.observable(false);
        self.leftAddons = ko.observableArray([]);
        self.rightAddons = ko.observableArray([]);
    };

    ctor.prototype.attached = function (view) {
        var self = this;

        var parts = composition.getParts(view);
        var $controlBox = $(parts.controlBox);

        $controlBox.attr('class', self.getBoxClass() + (self.settings.buttonAddons ? ' input-group' : ''));
    };

    ctor.prototype.compositionComplete = function (view, parent) {
        var self = this;

        var parts = composition.getParts(view);
        var $tooltipLabel = $(parts.controlLabel);
        var $tooltipIcon = $tooltipLabel.find('i');
        $tooltipIcon.hover(function () { $tooltipLabel.tooltip('show'); },
            function () { $tooltipLabel.tooltip('hide'); });

        if (self.settings.buttonAddons) {
            var addons = self.settings.buttonAddons;
            var $controlBox = $(parts.controlBox);
            for (var i = 0; i < addons.length; i ++)
            {
                // find or create the input group
                var $inputGroup = undefined;
                if (addons[i].position == 'left') {
                    self.leftAddons.push(addons[i]);
                    self.addonsOnLeft(true);
                }
                else {
                    self.rightAddons.push(addons[i]);
                    self.addonsOnRight(true);
                }
            }
        }
    }

    return ctor;
});