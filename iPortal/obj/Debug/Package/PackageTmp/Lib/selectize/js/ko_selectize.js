/*!
 * Knockout binding to integrate Selectize wih Knockout 3.0+. Supports multiple select.
 * Version: 0.1
 * License: MIT
 * Author: Eduard Porta
 * https://
 */

(function () {
    var DEBUG = true;
    (function (undefined) {
        // (0, eval)('this') is a robust way of getting a reference to the global object
        // For details, see http://stackoverflow.com/questions/14119988/return-this-0-evalthis/14120023#14120023
        var window = this || (0, eval)('this'),
            document = window['document'],
            navigator = window['navigator'],
            $ = window["jQuery"],
            ko = window["ko"],
            selectize = window["selectize"];
        (function (factory) {
            // Support three module loading scenarios
            if (typeof define === 'function' && define['amd']) {
                // [1] AMD anonymous module
                define(['jquery', 'knockout', 'selectize'], factory);
            } else if (typeof require === 'function' && typeof exports === 'object' && typeof module === 'object') {
                // [2] CommonJS/Node.js
                module.exports = factory(require('jQuery'), require('knockout'), require('selectize')); 
            } else {
                // [3] No module loader (plain <script> tag) - put directly in global namespace
                factory($, ko, selectize);
            }
        }(function ($, ko, selectize) {

            // Helper function to inject missing bindings
            var inject_binding = function (allBindings, key, value) {
                //https://github.com/knockout/knockout/pull/932#issuecomment-26547528
                return {
                    has: function (bindingKey) {
                        return (bindingKey == key) || allBindings.has(bindingKey);
                    },
                    get: function (bindingKey) {
                        var binding = allBindings.get(bindingKey);
                        if (bindingKey == key) {
                            binding = binding ? [].concat(binding, value) : value;
                        }
                        return binding;
                    }
                };
            }

            // Define the ko binding handler
            ko.bindingHandlers.selectize = {
                init: function (element, bindingValue, bindings, vm, context) {                    
                    
                    // FIXME: Selectize will typically not work well with plain text arrays (needs an object with valuefield/labelfield)
                    //   For now we will throw an exception if optionsText/optionsValue is not defined
                    if (!bindings.has('optionsText') || !bindings.has('optionsValue'))
                        throw new Error("Selectize Knockout binding needs both optionsText and optionsValue to be defined.");

                    // Throw exception if this binding is defined over an element other than a select (no input/text support tested yet)
                    var $element = $(element);
                    if (!$element.is('select'))
                        throw new Error("Selectize Knockout binding is currently only valid on <select> elements. (text input may be supported in a future release)");

                    // Throw exception if element is multiselect and no selectedOptions binding is present
                    var isMultiselect = $element.is('[multiple]');
                    if (isMultiselect && !bindings.has('selectedOptions'))
                        throw new Error("Multi-select lists in Knockout must use the selectedOptions binding instead of value. Check http://knockoutjs.com/documentation/selectedOptions-binding.html .");

                    // Retrieve options, value/s and selectize parameters                    
                    var options = bindings.get('options');
                    var value = bindings.get(isMultiselect ? 'selectedOptions' : 'value');
                    var bindingValue = bindingValue();
                    var params = ko.unwrap(bindingValue);

                    // As we are taking advantage of the core options binding, we prioritize its definitions of options text/value fields
                    params.valueField = bindings.get('optionsValue');
                    params.labelField = bindings.get('optionsText');
                    params.searchField = bindings.get('optionsText');                    
                    
                    // Initialize selectize on the element
                    $element.selectize(params);
                    var selectize = element.selectize;
                                  
                    //If the options are observable, synchronise add/remove events between selectize and knockout
                    var optionsSubscription = false;
                    if (ko.isObservable(options)) {
                        var changing = false;

                        //Whenever an option is added/removed, copy to the observable.
                        selectize.on('option_add', function (item, data) { if (!changing) options.push(item); });
                        selectize.on('option_remove', function (item) { if (!changing) options.remove(item); });

                        //Whenever the observable has an element added/removed, copy to the options
                        optionsSubscription = options.subscribe(function (changes) {
                            changing = true;
                            changes.forEach(function (change) {
                                if (change.status === 'added') {
                                    selectize.addOption(change.value);                                    
                                } else if (change.status === 'deleted') {
                                    selectize.removeOption(change.value[params.valueField]);
                                }
                            });
                            selectize.refreshOptions(false);
                            changing = false;
                        }, null, 'arrayChange');
                    }

                    //If the value is observable, synchronize
                    var valueSubscription = false;
                    if (ko.isObservable(value)) {

                        //Whenever the observable changes, update the value
                        // Use a different update function for single select/multiselect
                        if (isMultiselect) {
                            valueSubscription = value.subscribe(function (changes) {
                                //updating = true;
                                changes.forEach(function (change) {
                                    if (change.status === 'added') {
                                        selectize.addItem(change.value);
                                    } else if (change.status === 'deleted') {
                                        selectize.removeItem(change.value[params.valueField]);
                                    }
                                });
                                selectize.refreshItems();
                            }, null, 'arrayChange');
                        }
                        else {
                            valueSubscription = value.subscribe(function (change) {                       
                                // If the observable value doesn't match the element value, update the element;                        
                                if (change !== selectize.getValue()) {
                                    selectize.setValue(change);
                                }
                            });
                        }
                    }

                    //Selectize bug; doesn't disable the control input if the parent is disabled, even at startup. Fix. (after startup, handled by the observer ahead)
                    if (selectize.$input.is(':disabled')) selectize.$control_input.prop('disabled', true);

                    //For knockout bindings to work, we need to observe when the attributes of the <select> element are changed - `required`, `disabled`.
                    //This is to update the selectize control to match the <select> element
                    //(NOTE: `visible` should not be bound directly to <select>. Bind `visible` to an enclosing <div> or similar.)
                    var observer = new MutationObserver(function (mutations) {
                        var disabled = selectize.$input.is(':disabled'),
                        required = selectize.$input.is(':required');

                        //Check disabled
                        //(The mutation may fire multiple times, so fence against loops)
                        if (disabled !== selectize.isDisabled) {
                            //Disable/enable selectize to match the real select element
                            selectize[disabled ? 'disable' : 'enable']();
                            //When the real element is disabled, disable the control input too.
                            //This is a selectize bug - #307
                            selectize.$control_input.prop('disabled', disabled);
                        }

                        //Check required
                        //(The mutation may fire multiple times, so fence against loops)
                        if (required !== selectize.isRequired) {
                            selectize.isRequired = required;
                            selectize.refreshState();
                        }
                    });
                    observer.observe(element, { attributes: true });

                    //When the dom node is removed, ensure that the selectize node is too, as well as the mutation observer
                    ko.utils.domNodeDisposal.addDisposeCallback(element, function () {
                        selectize.destroy();
                        observer.disconnect();
                        if (optionsSubscription) optionsSubscription.dispose();
                        if (valueSubscription) valueSubscription.dispose();
                    });
                }
            };
        }));
    }());
})();