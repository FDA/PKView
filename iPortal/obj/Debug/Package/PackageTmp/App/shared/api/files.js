define('shared/api/files', [
    'ocpkmlib/net',
],
function (net) {

    // Return a list of NDAs in the server's share
    var getNdaList = function (successCallback) {
        net.ajax({
            url: "/api/submissions/",
            data: {},
            successCallback: successCallback
        });
    };

    // Module interface
    var files = {
        getNdaList: getNdaList
    };

    return files;
});