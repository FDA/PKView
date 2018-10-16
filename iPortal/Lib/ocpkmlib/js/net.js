/**
 * The net module from the iPortal library contains utility functions for network communication.
 * @module net
 * @requires durandal/app
 */
define('ocpkmlib/net',['durandal/app'], function (app)
{
    var self = this;

    /* Sends an ajax request.
     * @method ajax
     * @param {input} Structure of input parameters where the following can be set:
     * . url: The URL to send the request to.
     * . data: Data to send.
     * . type (optional): Type of request. default: "GET".    
     * . [deprecated] successCallback (optional): Function to run in case the request suceeds, this function will be executed with
     *   a single argument containing the data received from the server.
     * . [deprecated] errorCallback (optional): Function to run in case the request fails, this function takes no arguments.
     * @returns an abortable promise
     */
    this.ajax = function(input)
    {
        var request = {
            url:  input.url,
            data: input.data,
            type: input.type || "GET",
            contentType: "application/json;charset=utf-8"
        };

        // add statusCode if we are not using promises (deprecated)
        if (typeof input.successCallback !== "undefined" && $.isFunction(input.successCallback))
        {
            request.statusCode = {
                200: input.successCallback,
                201: input.successCallback,
                404: function()
                {
                    app.showMessage('Not Found!', 'iPortal', ['OK']);
                },
                500: function (response) {
                    if ((typeof input.errorCallback === "undefined") || !$.isFunction(input.errorCallback))
                        app.showMessage(response.responseText, 'Internal Server Error', ['OK']);
                    else input.errorCallback(response);
                }
            }
        }

        // Add any additional options for jquery, this option is
        // advanced and left undocumented in the function header
        if (typeof input.options !== "undefined")
            $.extend(request, input.options);

        return $.ajax(request);
    };

    /* Sends a http get request.
     * @method get
     * @param {url} URL to get
     * @returns an abortable promise
     */
    self.get = function(url)
    {
        return self.ajax({ url: url })
    };

    /* Sends a http post request.
     * @method post
     * @param {url} URL to post to
     * @param {data} data to send in the post request
     * @returns an abortable promise
     */
    self.post = function(url, data)
    {
        return self.ajax({ url: url, data: data, type: "POST" })
    };

    /* Sends an ajax request to upload a file.
     * @method ajaxUpload
     * @param {input} Structure of input parameters where the following can be set:
     * . url: The URL to send the request to.
     * . data: structure of data to be sent which must have at least a field called fileInputId that will
     *   contain the id of the file field from which the files are to be submitted. Example: { fileInputId: "myFile" }.
     * . successCallback (optional): Function to run in case the request suceeds, this function will be executed with
     *   a single argument containing the data received from the server.
     * . errorCallback (optional): Function to run in case the request fails, this function takes no arguments.
     */
    self.ajaxUpload = function (input)
    {            
        var files = $("#" + input.data.fileInputId).get(0).files;
        if (files.length > 0)
        {
            if (window.FormData != undefined)
            {
                var data = new FormData();
                for (i = 0; i < files.length; i++)
                {
                    data.append("file" + i, files[i]);
                }
                $.each(input.data, function (key, value) { data.append(key, value); });
                    
                return self.ajax({
                    url: input.url,
                    data: data,
                    type: "POST",
                    options : { contentType: false, processData: false }
                });
            }
        }
    };

    /* Download a file from the server.
     * @method download
     * @param {url} Path to the file.
     */
    self.download = function (url)
    {
        // Add a unique value to the request to avoid caching
        var requestUrl = url + (url.indexOf("?") == -1 ? "?" : "&") +
            "hxk=" + (new Date).getTime() + "_" + (Math.random()*100);

        // open url in the current window (we dont want a blank popup)
        window.open(requestUrl, "_self");
    }

    var ocpkmlibNet = {
        ajax: self.ajax,
        get: self.get,
        post: self.post,
        ajaxUpload: self.ajaxUpload,
        download: self.download
    };

    return ocpkmlibNet;
});