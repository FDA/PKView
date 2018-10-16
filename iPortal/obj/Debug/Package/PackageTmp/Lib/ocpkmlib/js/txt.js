/**
 * The net module from the iPortal library contains utility functions for network communication.
 * @module net
 * @requires durandal/app
 */
define('ocpkmlib/txt',[], function ()
{    
    var ocpkmlibTxt =
    {
        /* Return true if the specified string is null or empty.
         * @method isNullOrEmpty
         * @param {text} A string.
         */
        isNullOrEmpty: function(text)
        {
            return text == null || $.trim(text) === '';
        },
    };

    return ocpkmlibTxt;
});