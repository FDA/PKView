define('shared/components/errorDialog/viewmodels/errorDialog', [
    'knockout',
    'durandal/app',
    'plugins/dialog',
    'ocpkmlib/net'
],
function (ko, app, dialog, net) {

    var userFriendly = true;


    var errorDialog = {
        // Display an error message
        show: function (error, report) {
            var buttons = ['OK'];

            // Display report button
            if (report)
                buttons.push('Report to our team');

            // Show the dialog
            return app.showMessage(error, 'PkView', buttons, false, {})
                .then(function (button) {
                    if (!report || (button != 'Report to our team')) return;

                    var mailSubject = encodeURIComponent('PkView Error Report');
                    var currentdate = new Date();
                    var thisTime = currentdate.getDate() + "/"
                                + (currentdate.getMonth() + 1) + "/"
                                + currentdate.getFullYear() + " @ "
                                + currentdate.getHours() + ":"
                                + currentdate.getMinutes() + ":"
                                + currentdate.getSeconds();
                    var mailBody = encodeURIComponent('Report timestamp: ' + thisTime) +
                        '%0D%0A%0D%0A' +
                        encodeURIComponent(error);
                    window.location.href = "mailto:CDER-OCPKM@fda.hhs.gov?" +
                        "subject=" + mailSubject
                        "body=" + mailBody;
                });
        }
    };

    return errorDialog;
});