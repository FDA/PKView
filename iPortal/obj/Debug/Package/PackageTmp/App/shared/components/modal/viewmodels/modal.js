define('shared/components/modal/viewmodels/modal', [
    'knockout',
    'ocpkmlib/net',
    'plugins/dialog'],
function (ko, net, dialog) {

    var modal = function (settings) {
        var self = this;

        // Normalize percentage based size
        var normalize = function (size, defValue) {
            size = parseFloat(size);
            if (size > 1) size = size % 1;
            if (size == 0) size = defValue;
            if (isNaN(size)) size = defValue;
            return size;
        };

        // Set dialog title
        self.title = settings.title || "Modal Dialog";
        self.childModel = settings.model;
        self.childActivationData = settings.activationData || {};        
        self.width = normalize(settings.width, 0.8);
        self.height = normalize(settings.height, 0.9);
        self.loading = ko.observable(true);
    };

    // Add the close and reposition callbacks to the child activation data 
    // when the modal is activated
    modal.prototype.activate = function () {
        var self = this;
        self.childActivationData.close = function (result) {
            self.close.apply(self, [result]);
        };
        self.childActivationData.reposition = function (result) {
            self.reposition.apply(self, [result]);
        };
    };

    // Resize modal when view is attached
    modal.prototype.attached = function (view, parent) {
        var self = this;
        self.view = view;
        self.reposition();
    };

    // relocate modal footer if the child view has one, fixes issues with scroll
    modal.prototype.compositionComplete = function (view, parent) {
        var $view = $(view);
        var $modalBody = $view.find(".modal-body")[0];
        var $modalFooter = $view.find(".modal-footer");
        if ($modalFooter.length > 0)
            $($modalFooter[0]).insertAfter($modalBody);

        this.loading(false);
    }

    modal.prototype.close = function (result) {
        dialog.close(this, result);
    };

    modal.prototype.reposition = function () {
        var self = this;
        var $view = $(self.view);
        if (self.width != null) $view.css("min-width", ($(window).width() * self.width) + 'px');
        if (self.height != null) $view.css("min-height", ($(window).height() * self.height) + 'px');
    };

    return modal;
});