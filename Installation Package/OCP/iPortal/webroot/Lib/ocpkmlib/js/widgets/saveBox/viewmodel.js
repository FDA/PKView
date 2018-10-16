define(['durandal/app', 'jquery', 'knockout', './saveButtonAddon'], function (app, $, ko, saveButton) {

    var ctor = function () {

        var self = this;

        // Filename with no extension
        self.filename = ko.observable();

        self.tooltipText = 'Enter the name of the file where the study design information will be saved. '
            + 'It should contain the extension ".xml".  If you do not enter the extension ".xml", '
            + 'the system will append it.  Only letters, numbers, spaces and the characters -(dash) '
            + ',(comma) _(underscore) and .(dot) are allowed.';

        // status flag
        self.saving = ko.observable(false);
        self.modified = ko.observable(false);

        // Set namespace as modified
        self.setModified = function () {
            app.trigger(self.settings.eventNamespace + ':modified', true);
            return true;
        }

        // Store form data
        self.saveForm = function () {
            app.trigger(self.settings.eventNamespace + ':modified', false);
            self.saving(true);

            if ($.isFunction(self.settings.postData))
                self.settings.postData.notifySubscribers();
            var data = ko.unwrap(self.settings.postData);

            // Run post function or post to url
            if ($.isFunction(self.settings.postAction))
                self.settings.postAction(ko.toJS(self.settings.postData),
                    function () { self.saving(false); });
            else {
                // Add filename extension as needed
                var filename = ko.unwrap(self.filename);
                filename += filename
                    .indexOf(".xml", filename.length - 4) == -1 ? '.xml' : '';

                $.post(self.settings.postAction,
                    {
                        data: data,
                        filename: filename
                    })
                    .done()
                    .fail(function (response) {
                        if ($.isFunction(self.settings.errorCallback))
                            self.settings.errorCallback(response);
                        app.trigger(self.settings.eventNamespace + ':modified', true);
                    })
                    .always(function () { self.saving(false); });
            }
        };

        self.getBoxClass = function () {
            return self.settings.eventNamespace + 'saveBox';
        }
    };

    ctor.prototype.activate = function (settings) {

        var self = this;

        self.settings = settings;

        // Set namespace to settings, app default or 'default'
        if (!self.settings.eventNamespace)
            self.settings.eventNamespace = $(window).data('eventNamespace') || 'default';

        // Bind filename
        if (typeof (settings.filename) != 'undefined') self.filename = settings.filename;

        // Add save button to addon bar
        app.trigger('navbar:newAddon', new saveButton({ eventNamespace: self.settings.eventNamespace }));

        // Add disabled flag
        self.disabled = ko.computed(function () {
            return ko.unwrap(self.settings.disabled) ? 'disabled' : null;
        });

        // Hide the savebox, show the addon only
        self.hideBox = self.settings.hideBox || false;
    };

    ctor.prototype.compositionComplete = function () {
        var self = this;

        if (!self.hideBox) {
            $box = $('.' + self.settings.eventNamespace + 'saveBox');
            $box.appear();

            $box.on('disappear', function (event, $all_disappeared_elements) {
                if (self.modified()) $('.globalSaveButton').show(300);
            });

            $box.on('appear', function (event, $all_disappeared_elements) {
                $('.globalSaveButton').hide(300);
            });
        }

        // Grey out save button on modified form
        app.on(self.settings.eventNamespace + ':modified')
            .then(function (modified) {
                if (modified && (self.hideBox || !$box.is(':appeared')))
                    $('.globalSaveButton').show(300);
                else $('.globalSaveButton').hide(300);
                self.modified(modified);
            });

        // Trigger form saving externally
        app.on(self.settings.eventNamespace + ':save').then(
            function () {
                self.saveForm();
            });

    };

    return ctor;
});