define(['durandal/composition','jquery'], function(composition, $) {
    var ctor = function() {};

    ctor.prototype.activate = function(settings) {
        var self = this;
        self.settings = settings;      
        self.items = settings.items;
        
        // Add item function
        self.addItem = function(){
            self.items.push(new settings.itemPrototype());
        };
        
        // Remove an item function
        self.removeItem = function(selectedItem){
            self.items.remove(selectedItem);
        };
    };

    return ctor;
});