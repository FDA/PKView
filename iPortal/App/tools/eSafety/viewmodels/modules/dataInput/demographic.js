define(function (require)
{
    var issData = require('issData/issData');
    var issGui = require('issGui/issGui');

    // This is the datainput viewmodel prototype
    var demographic = function (file)
    {
        var self = this;

        self.file = file;
        self.file.config({
            studyId: ko.observable('PROTO'),
            subjectId: ko.observable('USUBJID'),
            treatmentGroup: ko.observable('TRT1')
        });

        self.file.demographicTable = ko.observableArray([
            ["", "A","" , "B","", "Drug X","", "Drug Y",""],
 
["","n","(%)","n","(%)","n","(%)","n","(%)"],
["Number of Subjects",336,"",282,"",32,"",132,""],
["","","","","","","","",""],
["Sex","","","","","","","",""],
["Female",137,"(40.7)",123,"(43.6)",14,"(43.7)",51,"(38.6)"],
["Male",199,"(59.2)",159,"(56.3)",18,"(56.2)",81,"(61.3)"],
["","","","","","","","",""]
["Race","","","","","","","",""],
["Asian",0,"",0,"",1,"(3.1)",0,""],
["Caucasian",0,"",1,"(0.3)",0,"",0,""],
["Hispanic",2,"(0.5)",0,"",2,"(6.2)",2,"(1.5)"],
["Non-Hispanic",1,"(0.2)",0,"",0,"",0,""],
["Syrian",1,"(0.2)",0,"",0,"",0,""],
["White",332,"(98.8)",281,"(99.6)",29,"(90.6)",130,"(98.4)"],
["","","","","","","","",""],
["Ldh At Baseline Category","","","","","","","",""],
["{0} Normal",0,"",0,"",17,"(53.1)",67,"(50.7)"],
["{1} Normal To 1.5*normal",0,"",0,"",5,"(15.6)",19,"(14.3)"],
["{2} >1.5*normal",0,"",0,"",8,"(25.0)",46,"(34.8)"],
["{3} Missing",0,"",0,"",2,"(6.2)",0,""],
["","","","","","","","",""],
["Age Group (<65, >=65)","","","","","","","",""],
["<65",242,"(72.0)",224,"(79.4)",28,"(87.5)",107,"(81.0)"],
[">=65",94,"(27.9)",58,"(20.5)",4,"(12.5)",25,"(18.9)"],
["","","","","","","","",""],
["Bl Ecog Performance Status Code","","","","","","","",""],
[0,0,"",0,"",14,"(43.7)",61,"(46.2)"],
[1,0,"",0,"",18,"(56.2)",71,"(53.7)"],
["","","","","","","","",""],
["Height In Cm","","","","","","","",""],
["n",0,"",0,"",32,"",130,""],
["Mean","","","","",171.9,"",172.2,""],
["STD","","","","",11.7,"",9.6,""],
["Min","","","","",154,"",137.2,""],
["Max","","","","",200.7,"",195.6,""],
["Median","","","","",170.6,"",172.1,""],
["","","","","","","","",""],
["Age (Years) At Randomisation","","","","","","","",""],
["n",336,"",282,"",32,"",132,""],
["Mean",55.4,"",52.8,"",50.4,"",50.3,""],
["STD",13.8,"",13.7,"",13.5,"",14.7,""],
["Min",21,"",17,"",22,"",17,""],
["Max",86,"",86,"",83,"",82,""],
["Median",56,"",53,"",52,"",51.5,""],
["","","","","","","","",""],
["Weight In Kg","","","","","","","",""],
["n",0,"",0,"",32,"",132,""],
["Mean","","","","",78.1,"",78.7,""],
["STD","","","","",16.2,"",18.8,""],
["Min","","","","",49.6,"",45.4,""],
["Max","","","","",108,"",140.6,""],
["Median","","","","",74.2,"",75.8,""],
["","","","","","","","",""]]);


        self.riskFactors = ko.observableArray(["", "Sex", "Age", "Baseline Weight", "Baseline BMI"]);
        self.selectedRiskFactors = ko.observableArray([]);
        self.riskFactorSelection = ko.observable("");
        self.riskFactorSelection.subscribe(function (newValue)
        {
            if (newValue != "" && self.selectedRiskFactors().indexOf(newValue) == -1)
            {
                self.selectedRiskFactors.push(newValue);
            }
        });

        // show demographic table
        self.viewDemographicTable = function ()
        {
            issGui.showIssTable
            ({
                title: "Demographic Information Summary Table",
                dataCells: self.file.demographicTable
            });
        };
    };

    demographic.prototype.viewAttached = function ()
    {
        var self = this;

        $("select.demographicSelect").kendoComboBox({ filter: 'contains', suggests: true });
        $("select.firstRiskSelect").kendoComboBox({ filter: 'contains', suggests: true, close: function ()
        {
            $("select.riskSelect").kendoComboBox({ filter: 'contains', suggests: true });
            $("input.firstRiskSelect:visible").val("");
            self.riskFactorSelection("");
        }
        });
    };

    return demographic;
});