define('tools/ogdTool/shared/filter/filter', [],
function () {

    // Returns the filter marked on the string if found or null otherwise
    var markIfFound = function (str, filter, caseSensitive) {
        var index;
        if (caseSensitive) index = str.indexOf(filter);
        else index = str.toLowerCase().indexOf(filter.toLowerCase());

        if (index > -1) {
            var index2 = index + filter.length;
            var highlightedString = str.substring(0, index)
                    + '<mark>' + str.substring(index, index2) + '</mark>'
                    + str.substring(index2);
            return highlightedString;
        }
        return null;
    };

    var filterModule = {
        markIfFound: markIfFound
    };

    return filterModule;
});
