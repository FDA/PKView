define(['durandal/system', 'durandal/app', 'durandal/viewEngine', 'plugins/dialog', 'jquery', 'knockout'], function (system, app, viewEngine, dialog, $, ko) {
    var contexts = {},
        dialogCount = 0,
        dialog;

    /**
     * Models a message box's message, title, footMessage and options.
     * @class FrameBox
     */
    var FrameBox = function(url, title, footMessage) {
        this.url = url;
        this.title = title || FrameBox.defaultTitle;
        this.footMessage = footMessage || "";
    };

    FrameBox.prototype.close = function () {
        dialog.close(this);
    };

    /**
     * Provides the view to the composition system.
     * @method getView
     * @return {DOMElement} The view of the message box.
     */
    FrameBox.prototype.getView = function(){
        return viewEngine.processMarkup(FrameBox.defaultViewMarkup);
    };

    FrameBox.prototype.attached = function (view, parent) {
        var self = this;
        var $view = $(view);
        $view.width($(window).width() * 0.9);

        var height = (document.compatMode === "CSS1Compat") ?
        document.documentElement.clientHeight :
        document.body.clientHeight;
        height *= 0.9;
        $view.height(height);

        height -= 120;
        $view.find(".modal-body").height(height);
        $view.find("iframe").height(height);
    };

    /**
     * Configures a custom view to use when displaying message boxes.
     * @method setViewUrl
     * @param {string} viewUrl The view url relative to the base url which the view locator will use to find the message box's view.
     * @static
     */
    FrameBox.setViewUrl = function(viewUrl){
        delete FrameBox.prototype.getView;
        FrameBox.prototype.viewUrl = viewUrl;
    };

    /**
     * The title to be used for the message box if one is not provided.
     * @property {string} defaultTitle
     * @default Application
     * @static
     */
    FrameBox.defaultTitle = app.title || 'Application';

    /**
     * The options to display in the message box of none are specified.
     * @property {string[]} defaultOptions
     * @default ['Ok']
     * @static
     */
    FrameBox.defaultOptions = ['Ok'];

    /**
     * The markup for the message box's view.
     * @property {string} defaultViewMarkup
     * @static
     */
    FrameBox.defaultViewMarkup = [
        '<div data-view="plugins/FrameBox" class="FrameBox modal-dialog">',
            '<div class="modal-content">',
                '<div class="modal-header">',
                    '<button type="button" class="close" aria-hidden="true" data-bind="click: close">&times;</button>',
                    '<h4 data-bind="text: title" style="margin: 0"></h4>',
                '</div>',
                '<div class="modal-body" style="padding: 0">',
                    '<iframe name="orcid" sandbox="allow-same-origin allow-top-navigation allow-scripts allow-forms allow-pointer-lock allow-popups" ' +
                    'data-bind="attr: {src: url}" style="border: 0; width: 100%"></iframe>',
                '</div>',
                '<div class="modal-footer" style="margin: 0; padding: 10px"><small data-bind="text: footMessage"></small></div>',
            '</div>',
        '</div>'
    ].join('\n');


    /**
     * @class DialogModule
     * @static
     */
    frameDialog = {
        /**
         * The constructor function used to create message boxes.
         * @property {FrameBox} FrameBox
         */
        FrameBox:FrameBox,
        /**
         * Shows a message box.
         * @method showMessage
         * @param {string} message The message to display in the dialog.
         * @param {string} [title] The title message.
         * @param {string[]} [options] The options to provide to the user.
         * @return {Promise} A promise that resolves when the message box is closed and returns the selected option.
         */
        showFrame:function(url, title, footMessage){
            if(system.isString(this.FrameBox)){
                return app.showDialog(this.FrameBox, [
                    url,
                    title || FrameBox.defaultTitle,
                    footMessage || ""
                ]);
            }

            return app.showDialog(new this.FrameBox(url, title, footMessage));
        },
        /**
         * Installs this module into Durandal; called by the framework. Adds `app.showDialog` and `app.showMessage` convenience methods.
         * @method install
         * @param {object} [config] Add a `FrameBox` property to supply a custom message box constructor. Add a `FrameBoxView` property to supply custom view markup for the built-in message box.
         */
        install:function(config){
            app.showFrame = function(url, title, footMessage) {
                return frameDialog.showFrame(url, title, footMessage);
            };
        }
    };

    
    return frameDialog;
});
