define(['durandal/composition', 'durandal/app', 'jquery', 'knockout', 'selectize'], function (composition, app, $, ko, selectize) {

    var ctor = function () { };

    ctor.prototype.activate = function (settings) {
        var self = this;
        self.settings = settings;
    };

    ctor.prototype.compositionComplete = function (view, parent) {
        var self = this;

        var $selectField = $(view).find("select.form-control")

        // Selectize plugin configuration
        var selectizeConfig = {
            create: typeof (self.settings.create) != 'undefined' ? self.settings.create : false,
            preload: typeof (self.settings.preload) != 'undefined' ?
                self.settings.preload : true,
            options: []
        };
        
        // We load from remote
        var firstLoad = true;
        if (self.settings.remote == true && $.isFunction(self.settings.options)) {
            selectizeConfig.load = function (query, callback) {
                //var existingSelection;
                //if ($selectField[0].selectize.items.length > 0)[0];
                //$selectField[0].selectize.clearOptions();
                if (firstLoad) callback();
                else self.settings.options(query, callback);
                updateFromObservable(self.settings.value());
                if (firstLoad) { firstLoad = false; app.trigger(self.settings.eventNamespace + ':modified', false); }
            };
        }

        // We load a fixed list
        if (self.settings.remote != true && !$.isFunction(self.settings.options)) {
            selectizeConfig.load = function (query, callback) {
                callback(self.settings.options);
                updateFromObservable(self.settings.value());
            };
            selectizeConfig.preload = true;
        }

        // Field configuration
        selectizeConfig.valueField = typeof (self.settings.valueField) != 'undefined' ? self.settings.valueField : 'value';
        selectizeConfig.labelField = typeof (self.settings.labelField) != 'undefined' ? self.settings.labelField : 'text';
        selectizeConfig.searchField = typeof (self.settings.searchField) != 'undefined' ? self.settings.searchField : 'value';
        selectizeConfig.render = typeof (self.settings.render) != 'undefined' ? self.settings.render : {
            option: function (item, escape) {
                return '<div>' +
                    '<span>' + item[selectizeConfig.labelField] + '</span>' +
                '</div>';
            }
        };

        // Add option groups
        if (typeof (self.settings.groups) != 'undefined')
            selectizeConfig.optgroups = self.settings.groups;

        // Render optiongroups in columns
        if (typeof (self.settings.columns) != 'undefined')
            selectizeConfig.plugins = ['optgroup_columns'];

        // Add onchange function
        var updateMasked = false;
        //if (typeof (self.settings.onChange) != 'undefined')
        //    selectizeConfig.onChange = function (option) {
        //        updateMasked = true;
        //        var item = $selectField[0].selectize.options[option];
        //        if (item) self.settings.value($selectField[0].selectize.options[option][self.settings.outputField]);
        //        else self.settings.value(item);
        //        updateMasked = false;
        //        self.settings.onChange($selectField[0].selectize.options[option], $selectField);
        //    };
	   selectizeConfig.onChange = function (option) {
            updateMasked = true;
            var item = $selectField[0].selectize.options[option];
            if (item) self.settings.value($selectField[0].selectize.options[option][self.settings.outputField || 'value']);
            else self.settings.value(item);
            updateMasked = false;
            if ($.isFunction(self.settings.onChange))
                self.settings.onChange($selectField[0].selectize.options[option], $selectField);
        };

        // Add selectize plugin to select field
        var $selectizeField = $selectField.selectize(selectizeConfig);

        // bind observable to selectize
        var updateFromObservable = function (newValue) {
            if (updateMasked) return;
            if ($.isFunction(self.settings.options)) {
                var option = {};
                option[selectizeConfig.labelField] = newValue;
                option[selectizeConfig.valueField] = newValue;
                $selectizeField[0].selectize.clearOptions();
                $selectizeField[0].selectize.addOption(option);
                $selectizeField[0].selectize.addItem(newValue);
            }
            else $selectizeField[0].selectize.addItem(newValue);
        };
        if (ko.isObservable(self.settings.value)) {
            self.settings.value.subscribe(updateFromObservable);
        }

        // bind event to update list
        if (self.settings.remote != true && $.isFunction(self.settings.options)) {
            var updateFunction = function () {
                self.settings.options("", function (list) {
                    // Update to force list refresh
                    $.each(list, function (index, item) {
                        if (typeof ($selectizeField[0].selectize.options[item.value]) != 'undefined') {
                            $selectizeField[0].selectize.updateOption(item.value, item);
                        }
                    });
                    // Clear to remove duplicates
                    $selectizeField[0].selectize.clearOptions();
                    // Reload list
                    $.each(list, function (index, item) {
                        $selectizeField[0].selectize.addOption(item);
                    });
                });
            };
            $selectizeField[0].selectize.on("dropdown_open", updateFunction);
            //$selectizeField.parent().find('.selectize-input > input').on('focus', updateFunction);
            $selectizeField[0].selectize.on("type", updateFunction);
            $selectizeField.parent().find(".selectize-input").on("click", function () {
                $selectizeField[0].selectize.refreshOptions(true);
            });
        }
    
    };

    return ctor;
});
