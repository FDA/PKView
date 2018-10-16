define('shared/api/reports/demographicSummary', [
    'knockout',
    'durandal/system',
    'ocpkmlib/net',
],
function (ko, system, net) {

    var self = {};

    // Generate a demographics summary of the current report. Returns the ajax request's promise
    self.generate = function (study) {

        // Ajax request to generate report
        return net.ajax({
            url: "api/pkview/reports/demographicSummary",
            data: ko.toJSON(study),
            type: "POST"   
        });
    };

    // Module interface
    var demographicSummary = {
        generate: self.generate
    };

    return demographicSummary;
});