define(['durandal/app','jquery'], function(app,$) { 
    ctor = function(settings) {
        self = this;
        
        self.settings = settings;
        
        // Triger main widget saving function
        self.save= function() { 
            app.trigger(self.settings.eventNamespace + ':save');
        };
    };
    
    ctor.prototype.attached = function()
    {
        $('.globalSaveButton').hide();
    };
    
    return ctor;
});