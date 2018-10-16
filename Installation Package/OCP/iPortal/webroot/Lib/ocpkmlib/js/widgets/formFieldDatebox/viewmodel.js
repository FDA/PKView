define(['durandal/composition','durandal/app','jquery','knockout','datetimepicker'], function(composition, app, $, ko, datepicker) {
    
    var ctor = function() {};
     
    ctor.prototype.activate = function(settings) {         
        var self = this;        
        self.settings = settings;
        self.settings.placeholder = self.settings.placeholder || 'YYYY-MM-DD hh:mm';
    };
     
    ctor.prototype.compositionComplete = function(view, parent)
    {
        var self = this; 

        var $addonButton = $(view).find(".input-group-addon");
        var $dateInner = $(view).find(".form-control")
           
        var config = {
            pickTime: true,
            
            //startDate:1/1/1970,      // set a minimum date
            //endDate: (today +50 years) // set a maximum date
        };
        
        $dateInner.datetimepicker(config);
        var picker = $dateInner.data('DateTimePicker');
        
        // Activate when button is clicked too
        $addonButton.click(function(e){ $dateInner.focus(); });
        
        // Set field as modified when date is picked
        // Set time to 00:00 AM the first time date is picked (if not manually chosen)
        var firstEntry = true;
        var setModified = function (e) {
                //if (firstEntry)
                //{
                //    firstEntry = false;
                //    if (new moment().format('HHmm') === e.date.format('HHmm'))
                //    {
                //        e.date.hours(0);
                //        e.date.minutes(0);
                //        picker.setDate(e.date.toDate());
                //        return;
                //    }                           
                //}
                app.trigger(self.settings.eventNamespace + ':modified',true);
                //self.settings.value($dateInner.val());
        }        

        // callback to properly format dates when loaded by code
        var reformatDate = function ()
        {
            var raw = ko.unwrap(self.settings.value);
            if (raw == "" || /\d{4}\-\d{2}\-\d{2} \d{2}\:\d{2}/.test(raw)) return;

            // Add support for dash-less iso 8601 strings
            if (/^\d{8,14}$/.test(raw))
                raw = raw.match(/(\d{4})(\d{2})(\d{2})/).splice(1, 3).join("-") +
                    ((raw.length >= 12) ? " " + raw[8] + raw[9] + ":" + raw[10] + raw[11] : "") +
                    ((raw.length == 14) ? ":" + raw[12] + raw[13] : "");
            picker.setDate(moment(raw));
        };
        if (ko.isObservable(self.settings.value))
            self.settings.value.subscribe(reformatDate);
        reformatDate();

        $dateInner.on("change.dp", setModified);
    };
    
    return ctor;
});