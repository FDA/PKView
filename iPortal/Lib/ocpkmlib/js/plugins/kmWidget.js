/**
 * @module kmWidget
 * @requires widget
 */
define('ocpkmlib/plugins/kmWidget',['plugins/widget'], function(widget) {

    /**
        * Converts a kind name to it's module path. Used to conventionally map kinds who aren't explicitly mapped through `mapKind`.
        * @method convertKindToModulePath
        * @param {string} kind The kind name.
        * @return {string} The module path.
        */
    widget.convertKindToModulePath = function(kind) {
        return 'ocpkmlib/widgets/' + kind + '/viewmodel';
    };

    /**
        * Converts a kind name to it's view id. Used to conventionally map kinds who aren't explicitly mapped through `mapKind`.
        * @method convertKindToViewPath
        * @param {string} kind The kind name.
        * @return {string} The view id.
        */
    widget.convertKindToViewPath = function (kind) {
        return 'ocpkmlib/widgets/' + kind + '/view';
    };

    return widget;
});
