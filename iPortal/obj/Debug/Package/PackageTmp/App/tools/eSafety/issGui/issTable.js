define(function (require)
{
    var issGui = require('../issGui/issGui');

    // This is the newDialog viewmodel prototype
    var issTable = function (tableData)
    {
        var self = this;

        // Settings for the dialog window
        self.title = tableData.title;
        self.width = "90%";
        self.height = "80%";

        self.dataCells = tableData.dataCells;
    };

    issTable.prototype.attached = function ()
    {
        $("select.chosenClass").chosen({ width: '100%' });
    };

    return issTable;
});