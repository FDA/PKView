********************************************************************;
********************************************************************;
***************Meta Analysis- Forest Plot***************************;
**********************Meng Xu 11/28/2016****************************;
********************************************************************;
********************************************************************;

%macro PkViewMetaAnalysisForestPlot();

%SmReadMappingsFromDataSet();

/* Read report settings from websvc input dataset (provided by C#) */
%SmReadReportSettingsForest();

%let Nda_Number=&SubmissionId.;
%let OutputFolder = &SasSpPath.\Output Files\PKView\&UserName.\&ProfileName.\&nda_number.\&SupplementNum;

%global  SequenceVar PeriodPcVar PeriodPpVar AnalytePcVar AnalytePpVar 
ResultPcVar ResultPpVar TimeVar ParameterVar ExTrtVar ExDateVar ExPeriodVar
AnalyteVar ParameterVar ;

/*Assign the macro variable back because of different naming*/
%let SequenceVar = &ArmVar.;
%let ExDateVar = &ExStdtcVar.;
%let PeriodExVar = &ExVisitVar.;

%let PeriodPcVar= &PcVisitVar.;
%let ResultPcVar = &PcStresnVar.;
%let AnalytePcVar = &PcTestVar.;
%let TimeVar = &PctptnumVar.;

%let PeriodPpVar= &PpVisitVar.;
%let ResultPpVar = &PpStresnVar.;
%let AnalytePpVar = &PpCatVar.;
%let ParameterVar = &PpTestcdVar.;

/*assign macro variable of analyte and parameter from PP datasets for excel and forest plots generation*/
%let AnalyteVar=&AnalytePpVar.;
%let ParameterVar=&PpTestcdVar.;
%put AnalyteVar=&AnalyteVar;
%put ParameterVar=&ParameterVar;


/*Step1: Read in UI outputs and combine all of selected study outputs*/
proc sql noprint;
select distinct STUDYCODE into: studycodelist separated by "$" from study;
quit;
%put studycodelist=&studycodelist;

%do i=1 %to %sysfunc(countw(%nrquote(&studycodelist),$));
%let current_study=%scan(%nrquote(&studycodelist),&i,$);
%put current_study=&current_study;
libname mylib "&OutputFolder\&current_study\estimates";

data current&i (rename=(&analyteppvar=analytepp &parametervar=parameterpp));
length study cohortDescription &analyteppvar &parametervar esttype combination $200;
set mylib.estminmax;
STUDY="&current_study";
R="Ratio";
lower="Lower";
upper="Upper";
ObsID=_n_;
Par="Parameter";
ParCat="Para_Category";
comp="Comparison";
Est="Estimate";
run;

%put analyte:&analyteppvar; 
%put analyte parametervar;
%end;

%let max=%sysfunc(countw(%nrquote(&studycodelist),$));

data combine;
set 
%do j=1 %to &max;
    current&j.
%end;
;
lcl=round(lcl,0.001);
ucl=round(ucl,0.001);
run;


data combine; 
set combine;
if ratio eq . then delete;
run;

proc sort data=combine out=combine1;
by study combination analytepp  parameterpp;
run;

/*step 2: import user selections from UI*/

/*add method to metareference as metaref_method*/
data metareferences;
set websvc.metareferences;
run;

data method;
set websvc.method;
run;

data analyte;
set websvc.analyte;
run;

data parameter;
set websvc.parameter;
run;

proc sort data=metareferences out=metareferences1;
by studycode;
run;

proc sort data=method out=method1;
by studycode;
run;

data metaref_method(drop=number testcohorts reference);
length studycode cohort method combination $200;
merge metareferences1 method1;
by studycode;
if TESTCOHORTS=REFERENCE then delete;
combination=trim(TESTCOHORTS)||" ~vs~ "||trim(reference);
run;

/*add analyte to metaref_method_anal*/
data studycohort;
set metaref_method;
keep studycode cohort;
run;

proc sort data=studycohort nodupkey;
by studycode cohort;
run;


proc sort data=studycohort ;
by studycode;
run;

proc sort data=analyte;
by studycode;
run;

data analytenew;
length analyte $200;
merge studycohort analyte ;
by studycode;
run;

proc sort data=analytenew;
by studycode cohort;
run;
proc sort data=metaref_method;
by studycode cohort;
run;

data metaref_method_anal;
merge analytenew metaref_method;
by studycode cohort;
run;


/*add parameter to mmetaref_method_anal as userfull*/
proc sort data=parameter out=parameter1;
by studycode;
run;

data parameter1;
set parameter1;
by studycode;
if first.studycode then order+1;
run;

proc sql noprint;
select distinct studycode into: study separated by "$" from parameter1;
quit;
%put studycode=&study;

%let maxi=%sysfunc(countw(%nrquote(&study)));
%put study maxi=&maxi;
%do i=1 %to &maxi;

    data subset&i.;
    set parameter1;
    where order=&i;
    run;

    proc sql noprint;
    select distinct parameter into: parameter separated by "$" from subset&i;
    quit;
    %put parameter=&parameter in subset&i;

    %let maxj=%sysfunc(countw(&parameter));
    %put parmeter maxj=&maxj; 
 
    %do j=1 %to &maxj;
    data study&i.para&j. (where=(parameter ne "    "));
    length parameter $200;
    set metaref_method_anal;
    if studycode="%scan(%nrquote(&study),&i,$)" then parameter="%scan(%nrquote(&parameter),&j,$)";
    run;

    %end;


data user_study&i.;
retain studycode cohort analyte parameter method combination;  
set 
%do j=1 %to &maxj;
study&i.para&j
%end;
;
run;
%put i=&i j=&j maxi=&maxi maxj=&maxj;


%end;

data userfull;
retain studycode cohort analyte parameter method combination;  
set 
%do i=1 %to &maxi;
user_study&i.
%end;
;
run;
%put i=&i maxi=&maxi;

/*inner join to get all user selected results*/
proc sql;
create table MengForest as
select*
from userfull inner join combine1 
on userfull.studycode=combine1.study and
userfull.cohort=combine1.cohortdescription and
userfull.analyte=combine1.analytepp and
userfull.parameter=combine1.parameterpp and
userfull.method=combine1.EstType and
userfull.combination=combine1.combination;
quit;


/*help to remove UI redunant information*/
data metaformat;
set websvc.metaformat( obs=1);
if ANALYSISMETHOD="Maximum and Minimum" then ANALYSISMETHOD="MM";
if ANALYSISMETHOD="90% Confidence Interval(CI)" then ANALYSISMETHOD="CI";
run;

data metaformat;
set metaformat;
call symput("lower",LOWERBOUND);
call symput ("upper",UPPERBOUND); 
call symput("labelanalyte",PLOTANALYSIS );
call symput ("SelectedAnal",ANALYSISMETHOD);
run;
%put lower=&lower upper=&upper;
%put labelanalyte=&labelanalyte || ANALYSISMETHOD=&SelectedAnal ;

/*generate gorest plot based on UI study sorting order*/
data sortstudy;
set metareferences;
id=_N_;
keep studycode id; 
run;

proc sort data=sortstudy nodupkey;
by studycode;

proc sort data=mengforest;
by studycode;

data mengforest_id;
merge mengforest(in=a) sortstudy(in=b);
by studycode;
if a;
run;

proc sort data=mengforest_id;
by id studycode cohort combination analyte parameter;

data Mengforest1;
set mengforest_id;
obsID=_N_;
minlabel="Minimum";
maxlabel="Maximum";
run;

proc template;
            define statgraph ForestPlot ;
            begingraph / designwidth=1200px designheight=1000;
            entrytitle "Forest Plot" / textattrs = (size = 12pt weight = bold) pad = (bottom = 5px);
            layout lattice / columns = 4 columnweights=(0.3 0.2 0.3 0.2);

                layout overlay /    walldisplay = none 
                xaxisopts = (display = none offsetmin = 0.2 offsetmax = 0.2 tickvalueattrs = (size = 8)) 
                yaxisopts = (reverse = true display = none tickvalueattrs = (weight = bold) offsetmin = 0);
                scatterplot y = obsid x = comp  /   markercharacter  =combination  markercharacterattrs=(family='Lucida Console' size=7 weight=bold  );
                endlayout;

                
                layout overlay /    walldisplay = none
                xaxisopts = (display = none offsetmin = 0.3 offsetmax = 0.2 tickvalueattrs = (size = 8))
                yaxisopts = (reverse = true display = none tickvalueattrs = (weight = bold) offsetmin = 0);

                /*plot analyte if clicking label analyte from UI*/
                %if &labelanalyte=true %then %do; 
                %put get labelanalyte;
                scatterplot y = obsid x = parcat  /   markercharacter  =analytepp   markerattrs = (size = 1);
                %end;

                scatterplot y = obsid x = par      /   markercharacter  =parameterpp markerattrs = (size = 0);
                endlayout;

                
                layout  overlay /   walldisplay = none
                yaxisopts = (reverse = true display = none offsetmin = 0) 
                xaxisopts = (tickvalueattrs = (size = 7pt) labelattrs = (size = 7pt)  
                            label = "Ratio of Geometric Means from Test against Reference and 90% CI");
                scatterplot y = obsid x = ratio  / xerrorlower = lcl xerrorupper = ucl markerattrs = (size = 1.2pct symbol = diamondfilled size=6);
                referenceline x = 1 /LINEATTRS=(COLOR=black thickness=1);
                referenceline x = &lower/LINEATTRS=(COLOR=gray PATTERN=2 thickness=1);
                referenceline x = &upper/LINEATTRS=(COLOR=gray PATTERN=2 thickness=1);
                endlayout;

/*                layout overlay    /   walldisplay = none*/
/*                x2axisopts = (display = (tickvalues) offsetmin = 0.25 offsetmax = 0.25)*/
/*                yaxisopts  = (reverse = true display = none);*/
/*                scatterplot y = obsid x = r /   markercharacter = ratio*/
/*                markercharacterattrs = graphvaluetext xaxis = x2;*/
/*                scatterplot y = obsid x = lower   /   markercharacter = lcl*/
/*                markercharacterattrs = graphvaluetext xaxis = x2;*/
/*                scatterplot y = obsid x = upper   /   markercharacter = ucl*/
/*                markercharacterattrs = graphvaluetext xaxis = x2;*/
/*                endlayout;     */
                
                %if &SelectedAnal=CI %then %do; 
                %put get %90CI;
                layout overlay    /   walldisplay = none
                x2axisopts = (display = (tickvalues) offsetmin = 0.25 offsetmax = 0.25)
                yaxisopts  = (reverse = true display = none);
                scatterplot y = obsid x = r /   markercharacter = ratio
                markercharacterattrs = graphvaluetext xaxis = x2;
                scatterplot y = obsid x = lower   /   markercharacter = lcl
                markercharacterattrs = graphvaluetext xaxis = x2;
                scatterplot y = obsid x = upper   /   markercharacter = ucl
                markercharacterattrs = graphvaluetext xaxis = x2;
                endlayout;     
                %end;

                %if &SelectedAnal=MM %then %do; 
                %put get maxmin;
                layout overlay    /   walldisplay = none
                x2axisopts = (display = (tickvalues) offsetmin = 0.25 offsetmax = 0.25)
                yaxisopts  = (reverse = true display = none);
                scatterplot y = obsid x = minlabel  /   markercharacter = min
                markercharacterattrs = graphvaluetext xaxis = x2;
                scatterplot y = obsid x = maxlabel   /   markercharacter = max
                markercharacterattrs = graphvaluetext xaxis = x2;
                endlayout; 
                %end;

            endlayout;
            endgraph;
            end;
            run;

%SmCheckAndCreateFolder(
        BasePath = &OutputFolder.,
        FolderName =Meta
        );

        options nodate nonumber;
        ods listing gpath = "&OutputFolder.\Meta" style=statistical sge=on;
        ods graphics on / noborder imagefmt = png imagename = "&SubmissionId.Meta" width = 1000px height = 1200;

        proc sgrender data=MengForest1  template=ForestPlot;
        run;

        ods listing sge=off;
        ods graphics off;
ods csv file="&OutputFolder.\Meta\userselection.csv";
proc print data=userfull;run;
ods csv close;

ods csv file="&OutputFolder.\Meta\available PE estimates.csv";
proc print data=combine1;
var study cohortdescription analytepp parameterpp esttype combination ratio lcl ucl;
run;
ods csv close;








/****************Prepare input data for user to download*********************************/

data usermetainput;
retain NDA study cohortDescription analyte parameter esttype combination ratio lcl ucl max min obsID par parcat comp est r lower upper minlabel maxlabel lowerbound upperbound;
set mengforest1;
NDA="&SubmissionId.";
lowerbound=&lower.;
upperbound=&upper.;
keep NDA study cohortDescription  analyte   parameter sttype combination ratio lcl ucl  MAX MIN  ObsID R lower upper Par ParCat comp Est minlabel maxlabel lowerbound upperbound;
run;


%SmCheckAndCreateFolder(
        BasePath = &OutputFolder.\Meta,
        FolderName =Package
);

ods csv file="&OutputFolder.\Meta\Package\Meta_Input.csv"  style=statistical;
proc print data=usermetainput noobs;
run;
ods csv close;

%mend PkViewMetaAnalysisForestPlot;  
