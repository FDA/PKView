define(['durandal/composition','jquery','knockout'], function(composition, $, ko) {
    var ctor = function(){
        this.collapsed = ko.observable(false);
    };
     
    ctor.prototype.activate = function(settings) {        
        this.settings = settings;        
    };
    
    ctor.prototype.attached = function(view) {       
        var self = this;
        
        var parts = composition.getParts(view);
        var $collapseContainer = $(parts.collapseContainer);
        var $tipNote = $(parts.tipNote);
         
        $(parts.headerContainer).bind('click', function() {
            self.collapsed($collapseContainer.css('display') != 'none');
            $collapseContainer.toggle('fast');       
        });
        
        $tipNote.hide();
        
        $(parts.headerContainer).bind('mouseover', function() {
            $tipNote.show();
        });
        $(parts.headerContainer).bind('mouseout', function() {
            $tipNote.hide();
        });
    };
     
    return ctor;
});