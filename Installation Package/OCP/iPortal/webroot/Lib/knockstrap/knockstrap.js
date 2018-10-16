/*! knockstrap 1.1.0 | (c) 2014 Artem Stepanyuk |  http://www.opensource.org/licenses/mit-license */

(function (moduleName, factory) {
    'use strict';

    if (typeof require === 'function' && typeof exports === 'object' && typeof module === 'object') {
        // CommonJS/Node.js
        factory(require('knockout'), require('jquery'));
    } else if (typeof define === 'function' && define.amd) {
        // AMD
        define(moduleName, ['knockout', 'jQuery'], factory);
    } else {
        factory(ko, $);
    }

})('knockstrap', function (ko, $) {
    'use strict';
    
    ko.utils.uniqueId = (function () {
    
        var prefixesCounts = {
            'ks-unique-': 0
        };
    
        return function (prefix) {
            prefix = prefix || 'ks-unique-';
    
            if (!prefixesCounts[prefix]) {
                prefixesCounts[prefix] = 0;
            }
    
            return prefix + prefixesCounts[prefix]++;
        };
    })();
    ko.utils.unwrapProperties = function (wrappedProperies) {
    
        if (wrappedProperies === null || typeof wrappedProperies !== 'object') {
            return wrappedProperies;
        }
    
        var options = {};
    
        ko.utils.objectForEach(wrappedProperies, function (propertyName, propertyValue) {
            options[propertyName] = ko.unwrap(propertyValue);
        });
    
        return options;
    };

    // inspired by http://www.knockmeout.net/2011/10/ko-13-preview-part-3-template-sources.html
    (function () {
        // storage of string templates for all instances of stringTemplateEngine
        var templates = {};
    
        templates.alert="<div class=\"alert fade in\" data-bind=\"css: type, template: innerTemplate\"> </div>";
        templates.alertInner="<button class=\"close\" data-dismiss=\"alert\" aria-hidden=\"true\">&times;</button> <p data-bind=\"text: message\"></p>";
        templates.carousel="<!-- ko template: indicatorsTemplate --> <!-- /ko --> <div class=\"carousel-inner\"> <!-- ko foreach: items --> <div class=\"item\" data-bind=\"with: $parent.converter($data), css: { active: $index() == 0 }\"> <img data-bind=\"attr: { src: src, alt: alt }\"> <div class=\"container\"> <div class=\"carousel-caption\"> <!-- ko template: { name: $parents[1].itemTemplateName, data: $data, templateEngine: $parents[1].templateEngine, afterRender: $parents[1].afterRender, afterAdd: $parents[1].afterAdd, beforeRemove: $parents[1].beforeRemove } --> <!-- /ko --> </div> </div> </div> <!-- /ko --> </div> <!-- ko template: controlsTemplate --> <!-- /ko --> ";
        templates.carouselContent="<div data-bind=\"text: content\"></div>";
        templates.carouselControls="<a class=\"left carousel-control\" data-bind=\"attr: { href: id }\" data-slide=\"prev\"> <span class=\"icon-prev\"></span> </a> <a class=\"right carousel-control\" data-bind=\"attr: { href: id }\" data-slide=\"next\"> <span class=\"icon-next\"></span> </a>";
        templates.carouselIndicators="<ol class=\"carousel-indicators\" data-bind=\"foreach: items\"> <li data-bind=\"attr: { 'data-target': $parent.id, 'data-slide-to': $index }\"></li> </ol> ";
        templates.modal="<div class=\"modal-dialog\"> <div class=\"modal-content\"> <div class=\"modal-header\" data-bind=\"template: headerTemplate\"> </div> <div class=\"modal-body\" data-bind=\"template: bodyTemplate\"> </div> <!-- ko if: footerTemplate --> <div class=\"modal-footer\" data-bind=\"template: footerTemplate\"> </div> <!-- /ko --> </div> </div>";
        templates.modalBody="<div data-bind=\"html: content\"> </div>";
        templates.modalFooter="<!-- ko if: $data.action --> <a href=\"#\" class=\"btn btn-primary\" data-bind=\"click: action, html: primaryLabel\"></a> <!-- /ko --> <a href=\"#\" class=\"btn btn-default\" data-bind=\"html: closeLabel\" data-dismiss=\"modal\"></a>";
        templates.modalHeader="<button type=\"button\" class=\"close\" data-dismiss=\"modal\" aria-hidden=\"true\">&times;</button> <h3 data-bind=\"text: label\"></h3> ";
        templates.progress="<div class=\"progress-bar\" role=\"progressbar\" aria-valuemin=\"0\" aria-valuemax=\"100\" data-bind=\"style: { width: barWidth }, attr: { 'aria-valuenow': value }, css: innerCss\"> <span data-bind=\"css: { 'sr-only': textHidden }\"> <span data-bind=\"text: value\"></span>% <span data-bind=\"text: text\"></span> </span> </div> ";
        
    
        // create new template source to provide storing string templates in storage
        ko.templateSources.stringTemplate = function (template) {
            this.templateName = template;
    
            this.data = function (key, value) {
                templates.data = templates.data || {};
                templates.data[this.templateName] = templates.data[this.templateName] || {};
    
                if (arguments.length === 1) {
                    return templates.data[this.templateName][key];
                }
    
                templates.data[this.templateName][key] = value;
            };
    
            this.text = function (value) {
                if (arguments.length === 0) {
                    return templates[this.templateName];
                }
    
                templates[this.templateName] = value;
            };
        };
    
        // create modified template engine, which uses new string template source
        ko.stringTemplateEngine = function () {
            this.allowTemplateRewriting = false;
        };
    
        ko.stringTemplateEngine.prototype = new ko.nativeTemplateEngine();
        ko.stringTemplateEngine.prototype.constructor = ko.stringTemplateEngine;
        
        ko.stringTemplateEngine.prototype.makeTemplateSource = function (template) {
            return new ko.templateSources.stringTemplate(template);
        };
    
        ko.stringTemplateEngine.prototype.getTemplate = function (name) {
            return templates[name];
        };
    
        ko.stringTemplateEngine.prototype.addTemplate = function (name, template) {
            if (arguments.length < 2) {
                throw new Error('template is not provided');
            }
            
            templates[name] = template;
        };
        
        ko.stringTemplateEngine.prototype.removeTemplate = function (name) {
            if (!name) {
                throw new Error('template name is not provided');
            }
    
            delete templates[name];
        };
        
        ko.stringTemplateEngine.prototype.isTemplateExist = function (name) {
            return !!templates[name];
        };
        
        ko.stringTemplateEngine.instance = new ko.stringTemplateEngine();
    })();
    

    ko.bindingHandlers.alert = {
        init: function () {
            return { controlsDescendantBindings: true };
        },
    
        update: function (element, valueAccessor, allBindingsAccessor, viewModel, bindingContext) {
            var $element = $(element),
                value = valueAccessor(),
                usedTemplateEngine = !value.template ? ko.stringTemplateEngine.instance : null,
                userTemplate = ko.unwrap(value.template) || 'alertInner',
                template, data;
    
            // for compatibility with ie8, use '1' and '8' values for node types
            if (element.nodeType === (Node.ELEMENT_NODE || 1)) {
                template = userTemplate;
                data = value.data || { message: value.message };
    
                $element.addClass('alert fade in').addClass('alert-' + (ko.unwrap(value.type) || 'info'));
            } else if (element.nodeType === (Node.COMMENT_NODE || 8)) {
                template = 'alert';
                data = {
                    innerTemplate: {
                        name: userTemplate ,
                        data: value.data || { message: value.message },
                        templateEngine: usedTemplateEngine
                    },
                    type: 'alert-' + (ko.unwrap(value.type) || 'info')
                };
            } else {
                throw new Error('alert binding should be used with dom elements or ko virtual elements');
            }
    
            ko.renderTemplate(template, bindingContext.createChildContext(data), ko.utils.extend({ templateEngine: usedTemplateEngine }, value.templateOptions), element);
        }
    };
    
    ko.virtualElements.allowedBindings.alert = true;
    ko.bindingHandlers.carousel = {
    
        defaults: {
            css: 'carousel slide',
    
            controlsTemplate: {
                name: 'carouselControls',
                templateEngine: ko.stringTemplateEngine.instance,
                dataConverter: function(value) {
                    return {
                        id: ko.computed(function() {
                            return '#' + ko.unwrap(value.id);
                        })
                    };
                }
            },
            
            indicatorsTemplate: {
                name: 'carouselIndicators',
                templateEngine: ko.stringTemplateEngine.instance,
                dataConverter: function(value) {
                    return {
                        id: ko.computed(function() {
                            return '#' + ko.unwrap(value.id);
                        }),
                        
                        items: value.content.data
                    };
                }
            }, 
            
            itemTemplate: {
                name: 'carouselContent',
                templateEngine: ko.stringTemplateEngine.instance,
    
                converter: function (item) {
                    return item;
                }
            }
        },
    
        init: function (element, valueAccessor, allBindingsAccessor, viewModel, bindingContext) {
            var $element = $(element),
                value = valueAccessor(),
                defaults = ko.bindingHandlers.carousel.defaults,
                extendDefaults = function(defs, type) {
                    var extended = {
                        name: defs.name,
                        data: (value[type] && (value[type].data || value[type].dataConverter && value[type].dataConverter(value))) || defs.dataConverter(value),
                    };
    
                    extended = $.extend(true, {}, extended, value[type]);
                    if (!value[type] || !value[type].name) {
                        extended.templateEngine = defs.templateEngine;
                    }
    
                    return extended;
                };
    
            if (!value.content) {
                throw new Error('content option is required for carousel binding');
            }
    
            // get carousel id from 'id' attribute, or from binding options, or generate it
            if (element.id) {
                value.id = element.id;
            } else if (value.id) {
                element.id = ko.unwrap(value.id);
            } else {
                element.id = value.id = ko.utils.uniqueId('ks-carousel-');
            }
    
            var model = {
                id: value.id,
                controlsTemplate: extendDefaults(defaults.controlsTemplate, 'controls'),
                indicatorsTemplate: extendDefaults(defaults.indicatorsTemplate, 'indicators'),
    
                items: value.content.data,
                converter: value.content.converter || defaults.itemTemplate.converter,
                itemTemplateName: value.content.name || defaults.itemTemplate.name,
                templateEngine: !value.content.name ? defaults.itemTemplate.templateEngine : null,
                afterRender: value.content.afterRender,
                afterAdd: value.content.afterAdd,
                beforeRemove: value.content.beforeRemove
            };
    
            ko.renderTemplate('carousel', bindingContext.createChildContext(model), { templateEngine: ko.stringTemplateEngine.instance }, element);
    
            $element.addClass(defaults.css);
    
            return { controlsDescendantBindings: true };
        },
    
        update: function (element, valueAccessor) {
            var value = valueAccessor(),
                options = ko.unwrap(value.options);
    
            $(element).carousel(options);
        }
    };
    // Knockout checked binding doesn't work with Bootstrap checkboxes
    ko.bindingHandlers.checkbox = {
        init: function (element, valueAccessor) {
            var $element = $(element),
                handler = function (e) {
                // we need to handle change event after bootsrap will handle its event
                // to prevent incorrect changing of checkbox state
                setTimeout(function() {
                    var $checkbox = $(e.target),
                        value = valueAccessor(),
                        data = $checkbox.val(),
                        isChecked = $checkbox.parent().hasClass('active');
    
                    if (ko.unwrap(value) instanceof Array) {
                        var index = ko.unwrap(value).indexOf(data);
    
                        if (isChecked && (index === -1)) {
                            value.push(data);
                        } else if (!isChecked && (index !== -1)) {
                            value.splice(index, 1);
                        }
                    } else {
                        value(isChecked);
                    }
                }, 0);
            };
    
            if ($element.attr('data-toggle') === 'buttons' && $element.find('input:checkbox').length) {
    
                if (!(ko.unwrap(valueAccessor()) instanceof Array)) {
                    throw new Error('checkbox binding should be used only with array or observableArray values in this case');
                }
    
                $element.on('change', 'input:checkbox', handler);
            } else if ($element.attr('type') === 'checkbox') {
    
                if (!ko.isObservable(valueAccessor())) {
                    throw new Error('checkbox binding should be used only with observable values in this case');
                }
    
                $element.on('change', handler);
            } else {
                throw new Error('checkbox binding should be used only with bootstrap checkboxes');
            }
        },
    
        update: function (element, valueAccessor) {
            var $element = $(element),
                value = ko.unwrap(valueAccessor()),
                isChecked;
    
            if (value instanceof Array) {
                if ($element.attr('data-toggle') === 'buttons') {
                    $element.find('input:checkbox').each(function (index, el) {
                        isChecked = value.indexOf(el.value) !== -1;
                        $(el).parent().toggleClass('active', isChecked);
                        el.checked = isChecked;
                    });
                } else {
                    isChecked = value.indexOf($element.val()) !== -1;
                    $element.toggleClass('active', isChecked);
                    $element.find('input').prop('checked', isChecked);
                }
            } else {
                isChecked = !!value;
                $element.prop('checked', isChecked);
                $element.parent().toggleClass('active', isChecked);
            }
        }
    };
    ko.bindingHandlers.modal = {
        defaults: {
            css: 'modal fade',
            attributes: {
                role: 'dialog'  
            },
    
            headerTemplate: {
                name: 'modalHeader',
                templateEngine: ko.stringTemplateEngine.instance
            },
    
            bodyTemplate: {
                name: 'modalBody',
                templateEngine: ko.stringTemplateEngine.instance
            },
    
            footerTemplate: {
                name: 'modalFooter',
                templateEngine: ko.stringTemplateEngine.instance,
                data: {
                    closeLabel: 'Close',
                    primaryLabel: 'Ok'
                }
            }
        },
    
        init: function (element, valueAccessor, allBindingsAccessor, viewModel, bindingContext) {
            var $element = $(element),
                value = valueAccessor(),
                defaults = ko.bindingHandlers.modal.defaults,
                options = ko.utils.extend({ show: $element.data().show || false }, ko.utils.unwrapProperties(value.options)),
                extendDefaults = function (defs, val) {
                    var extended = {
                        name: defs.name,
                        data: defs.data,
                    };
    
                    // reassign to not overwrite default content of data property
                    extended = $.extend(true, {}, extended, val);
                    if (!val || !val.name) {
                        extended.templateEngine = defs.templateEngine;
                    }
    
                    return extended;
                };
    
            if (!value.header || !value.body) {
                throw new Error('header and body options are required for modal binding.');
            }
    
            // fix for not working escape button
            if (options.keyboard || typeof options.keyboard === 'undefined') {
                $element.attr('tabindex', -1);
            }
    
            var model = {
                headerTemplate: extendDefaults(defaults.headerTemplate, ko.unwrap(value.header)),
                bodyTemplate: extendDefaults(defaults.bodyTemplate, ko.unwrap(value.body)),
                footerTemplate: value.footer ? extendDefaults(defaults.footerTemplate, ko.unwrap(value.footer)) : null
            };
    
            ko.renderTemplate('modal', bindingContext.createChildContext(model), { templateEngine: ko.stringTemplateEngine.instance }, element);
    
            $element.addClass(defaults.css).attr(defaults.attributes);
            $element.modal(options);
    
            $element.on('shown.bs.modal', function () {
                if (typeof value.visible !== 'undefined') {
                    value.visible(true);
                }
    
                $(this).find("[autofocus]:first").focus();
            });
    
            if (typeof value.visible !== 'undefined') {
                $element.on('hidden.bs.modal', function() {
                    value.visible(false);
                });
    
                // if we need to show modal after initialization, we need also set visible property to true
                if (options.show) {
                    value.visible(true);
                }
            }
    
            return { controlsDescendantBindings: true };
        },
    
        update: function (element, valueAccessor) {
            var value = valueAccessor();
    
            if (typeof value.visible !== 'undefined') {
                $(element).modal(!ko.unwrap(value.visible) ? 'hide' : 'show');
            }
        }
    };
    var popoverDomDataTemplateKey = '__popoverTemplateKey__';
    
    ko.bindingHandlers.popover = {
    
        init: function (element) {
            var $element = $(element);
    
            ko.utils.domNodeDisposal.addDisposeCallback(element, function () {
                if ($element.data('bs.popover')) {
                    $element.popover('destroy');
                }
            });
        },
    
        update: function (element, valueAccessor, allBindingsAccessor, viewModel, bindingContext) {
            var $element = $(element),
                value = ko.unwrap(valueAccessor()),
                options = (!value.options && !value.template ? ko.utils.unwrapProperties(value) : ko.utils.unwrapProperties(value.options)) || {};
    
            if (value.template) {
                // use unwrap to track dependency from template, if it is observable
                ko.unwrap(value.template);
    
                var id = ko.utils.domData.get(element, popoverDomDataTemplateKey),
                    data = ko.unwrap(value.data);
                    
                var renderPopoverTemplate = function () {
                    // use unwrap again to get correct template value instead of old value from closure
                    // this works for observable template property
                    ko.renderTemplate(ko.unwrap(value.template), bindingContext.createChildContext(data), value.templateOptions, document.getElementById(id));
    
                    // bootstrap's popover calculates position before template renders,
                    // so we recalculate position, using bootstrap methods
                    var $popover = $('#' + id).parents('.popover'),
                        popoverMethods = $element.data('bs.popover'),
                        offset = popoverMethods.getCalculatedOffset(options.placement || 'right', popoverMethods.getPosition(), $popover.outerWidth(), $popover.outerHeight());
    
                    popoverMethods.applyPlacement(offset, options.placement || 'right');
                };
                
                // if there is no generated id - popover executes first time for this element
                if (!id) {
                    id = ko.utils.uniqueId('ks-popover-');
                    ko.utils.domData.set(element, popoverDomDataTemplateKey, id);
                    
                    // place template rendering after popover is shown, because we don't have root element for template before that
                    $element.on('shown.bs.popover', renderPopoverTemplate);
                }
    
                options.content = '<div id="' + id + '" ></div>';
                options.html = true;
                
                // support rerendering of template, if observable changes, when popover is opened
                if ($('#' + id).is(':visible')) {
                    renderPopoverTemplate();
                }
            }
    
            var popoverData = $element.data('bs.popover');
    
            if (!popoverData) {
                $element.popover(options);
    
                $element.on('shown.bs.popover', function () {
                    (options.container ? $(options.container) : $element.parent()).one('click', '[data-dismiss="popover"]', function () {
                        $element.popover('hide');
                    });
                });
            } else {
                ko.utils.extend(popoverData.options, options);
            }
        }
    };
    ko.bindingHandlers.progress = {
        defaults: {
            css: 'progress',
            text: '',
            textHidden: true,
            striped: false,
            type: '',
            animated: false
        },
    
        init: function (element, valueAccessor) {
            var $element = $(element),
                value = valueAccessor(),
                unwrappedValue = ko.unwrap(value),
                defs = ko.bindingHandlers.progress.defaults,
                model = $.extend({}, defs, unwrappedValue);
    
            if (typeof unwrappedValue === 'number') {
                model.value = value;
    
                model.barWidth = ko.computed(function() {
                    return ko.unwrap(value) + '%';
                });
            } else if (typeof ko.unwrap(unwrappedValue.value) === 'number') {
                model.barWidth = ko.computed(function() {
                    return ko.unwrap(unwrappedValue.value) + '%';
                });
            } else {
                throw new Error('progress binding can accept only numbers or objects with "value" number propertie');
            }
    
            model.innerCss = ko.computed(function () {
                var values = ko.utils.unwrapProperties(unwrappedValue),
                    css = '';
    
                if (values.animated) {
                    css += 'active ';
                }
    
                if (values.striped) {
                    css += 'progress-bar-striped ';
                }
    
                if (values.type) {
                    css += 'progress-bar-' + values.type;
                }
    
                return css;
            });
    
            ko.renderTemplate('progress', model, { templateEngine: ko.stringTemplateEngine.instance }, element);
    
            $element.addClass(defs.css);
    
            return { controlsDescendantBindings: true };
        },
    };
    
    // Knockout checked binding doesn't work with Bootstrap radio-buttons
    ko.bindingHandlers.radio = {
        init: function (element, valueAccessor) {
    
            if (!ko.isObservable(valueAccessor())) {
                throw new Error('radio binding should be used only with observable values');
            }
    
            $(element).on('change', 'input:radio', function (e) {
                // we need to handle change event after bootsrap will handle its event
                // to prevent incorrect changing of radio button styles
                setTimeout(function() {
                    var radio = $(e.target),
                        value = valueAccessor(),
                        newValue = radio.val();
    
                    value(newValue);
                }, 0);
            });
        },
    
        update: function (element, valueAccessor) {
            var $radioButton = $(element).find('input[value="' + ko.unwrap(valueAccessor()) + '"]'),
                $radioButtonWrapper;
    
            if ($radioButton.length) {
                $radioButtonWrapper = $radioButton.parent();
    
                $radioButtonWrapper.siblings().removeClass('active');
                $radioButtonWrapper.addClass('active');
    
                $radioButton.prop('checked', true);
            } else {
                $radioButtonWrapper = $(element).find('.active');
                $radioButtonWrapper.removeClass('active');
                $radioButtonWrapper.find('input').prop('checked', false);
            }
        }
    };
    ko.bindingHandlers.toggle = {
        init: function (element, valueAccessor) {
            var value = valueAccessor();
    
            if (!ko.isObservable(value)) {
                throw new Error('toggle binding should be used only with observable values');
            }
    
            $(element).on('click', function () {
                var previousValue = ko.unwrap(value);
                value(!previousValue);
            });
        },
        
        update: function (element, valueAccessor) {
            ko.utils.toggleDomNodeCssClass(element, 'active', ko.unwrap(valueAccessor()));
        }
    };
    
    ko.bindingHandlers.tooltip = {
        init: function (element) {
            var $element = $(element);
    
            ko.utils.domNodeDisposal.addDisposeCallback(element, function () {
                if ($element.data('bs.tooltip')) {
                    $element.tooltip('destroy');
                }
            });
        },
    
        update: function (element, valueAccessor) {
            var $element = $(element),
                value = ko.unwrap(valueAccessor()),
                options = ko.utils.unwrapProperties(value);
    
            var tooltipData = $element.data('bs.tooltip');
    
            if (!tooltipData) {
                $element.tooltip(options);
            } else {
                ko.utils.extend(tooltipData.options, options);
            }
        }
    };
    
});