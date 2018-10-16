define('tools/pkView/lib/pkViewProjects', [
    'ocpkmlib/net'
],
function (net) {

    var self = {};

    // Request the list of studies in this submission
    self.get = function (submissionId, projectName) {
        return net.get("api/pkview/projects?"
            + "submissionId=" + submissionId
            + "&projectName=" + projectName);
    };

    // Module interface
    var pkViewProjects = {
        get: self.get,
    };

    return pkViewProjects;
});