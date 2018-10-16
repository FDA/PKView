********************************************************************;
********************************************************************;
***************Meta Variability Analysist***************************;
**********************Meng Xu 2/06/2016*****************************;
********************************************************************;
********************************************************************;

%macro PkViewMetaVariability();
%global cohort_sel anal_sel param_sel method_sel ReportFolder studycode_sel trtgrp_sel DataSetPath Current_study ;

%SmReadMappingsFromDataSet();

/* Read report settings from websvc input dataset (provided by C#) */

data _null_;
set websvc.reportConfig end = eof;
if Name="Name" then 
call symputx("ReportFolder", value, "G");
run;

data &work.study;
set websvc.study;
run;
data &work.cohort;
set websvc.cohort;
run;

data &work.parameter;
set websvc.parameter;
run;

data &work.analyte;
set websvc.analyte;
run;

data trtdose;
set websvc.trtdose;
run;

proc sql noprint;
select distinct cohort into: cohort_sel separated by "$" from &work.cohort;
select distinct analyte into :anal_sel separated by "$" from &work.analyte;
select distinct parameter into :param_sel separated by "$" from &work.parameter;
select distinct STUDYCODE into: studycode_sel separated by "$" from study;
select distinct trtgrp into: trtgrp_sel separated by "$"  from trtdose;
quit;

%put cohort_sel=&cohort_sel;
%put anal_sel=&anal_sel;
%put param_sel=&param_sel;
%put studycode_sel=&studycode_sel;
%put trtgrp_sel=&trtgrp_sel;

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

/*step1:Read in UI outputs and combine all of selected study outputs*/
%do i=1 %to %sysfunc(countw(%nrquote(&studycode_sel ),$));
%let current_study=%scan(%nrquote(&studycode_sel),&i,$);
%put current_study=&current_study;
libname mylib "&OutputFolder\&current_study\estimates";

data current&i;
length study cohortDescription MacroAnalyte MacroParameter combination $200;
set mylib.individualpkstatsMeta;
STUDY="&current_study";
ObsID=_n_;
run;

%end;

%let max=%sysfunc(countw(%nrquote(&studycode_sel),$));

data combine;
set 
%do j=1 %to &max;
    current&j.
%end;
;
OrgMACRORESULT=EXP(MACRORESULT);
keep study cohortDescription MacroAnalyte MacroParameter combination TreatmentInPeriodText USUBJID MACRORESULT OrgMACRORESULT ObsID ;
run;

proc sort data=combine out=combine1;
by study combination MacroAnalyte MacroParameter ;
run;

/*step 2: import user selections from UI*/
data metaformat;
set websvc.metavariabilityformat (obs=1);
call symput("lower",lowerbound);
call symput("upper",upperbound);
run;
%put lower=&lower upper=&upper;


proc sort data=analyte;
by studycode;
proc sort data=parameter;
by studycode;

data analparam;
merge analyte parameter;
by studycode ;
run;
proc sort data=analparam;
by studycode ;

proc sort data=trtdose;
by studycode ;

data userfull;
merge analparam trtdose;
by studycode ;
run;


/*change combine1 study data type from numeric into character*/

data combine1;
set combine1;
letter="a";
studychar=strip(letter)||strip(study);
drop study letter;
rename studychar=study;
run;

data userfull;
set  userfull;
letter1="a";
studycodechar=strip(letter1)||strip(studycode);
drop studycode letter1;
rename studycodechar=studycode;
run;


/*inner join */
proc sql;
create table MengMetaVar as
select*
from userfull inner join combine1 
on userfull.studycode=combine1.study and
userfull.selectedcohort=combine1.cohortdescription and
userfull.analyte=combine1.MacroAnalyte  and
userfull.parameter=combine1.MacroParameter and
userfull.trtgrp=combine1.treatmentinperiodtext;
quit;

data mengmetavar;
retain study  TreatmentInPeriodText USUBJID normalbydose ObsID cohortDescription MacroAnalyte MacroParameter combination MACRORESULT OrgMACRORESULT dose number;
set mengmetavar;
drop STUDYCODE ANALYTE PARAMETER SelectedCohort trtgrp;
normalbydose=orgMACRORESULT/dose;
ObsID=_n_;
parameterlabel="Parameter";
trtlabel="trtgrp";
Studylabel="Study";
run;



data mengmetavar;
set mengmetavar;
if dose eq . then delete;
run;

proc sort data=mengmetavar;
by study MacroAnalyte MacroParameter  cohortdescription treatmentinperiodtext;
run;

data mengmetavar1;
set mengmetavar;
by study  MacroAnalyte MacroParameter cohortdescription treatmentinperiodtext;
if first.treatmentinperiodtext then catlevel+1;
if not first.treatmentinperiodtext then study= .;
  if not first.treatmentinperiodtext then  MacroAnalyte= . ;
if not first.treatmentinperiodtext then  MacroParameter= .;
if not first.treatmentinperiodtext then  treatmentinperiodtext= .;
if not first.treatmentinperiodtext then studylabel= .;
obsid=catlevel;
if not first.treatmentinperiodtext then obsid = .;
run;



/*Meta forestplot variability template*/
proc template;
define statgraph ForestPlotMetaVar ;
begingraph / designwidth=1400px designheight=1000;
entrytitle "&SubmissionId. Forest Plot Meta Variability Analysis" / textattrs = (size = 12pt weight = bold) pad = (bottom = 5px);
layout lattice / columns = 4 columnweights=(0.1 0.13 0.05 0.72);

layout overlay /    walldisplay = none 
xaxisopts = (display = none offsetmin = 0.2 offsetmax = 0.2 tickvalueattrs = (size = 8)) 
yaxisopts = (reverse = true display = none tickvalueattrs = (weight = bold) offsetmin = 0);
/*    referenceline y=ref / lineattrs=(thickness=15 color=_bandcolor);*/
scatterplot y = obsid x =studylabel  /   markercharacter  =study markercharacterattrs=(family='Lucida Console' size=7 weight=bold  );
endlayout;

layout overlay /    walldisplay = none
xaxisopts = (display = none offsetmin = 0.3 offsetmax = 0.2 tickvalueattrs = (size = 8))
yaxisopts = (reverse = true display = none tickvalueattrs = (weight = bold) offsetmin = 0);
scatterplot y = obsid x = trtlabel    /   markercharacter  =treatmentinperiodtext markerattrs = (size = 0);
endlayout;

layout overlay /    walldisplay = none
xaxisopts = (display = none offsetmin = 0.3 offsetmax = 0.2 tickvalueattrs = (size = 8))
yaxisopts = (reverse = true display = none tickvalueattrs = (weight = bold) offsetmin = 0);
scatterplot y = obsid x = parameterlabel      /   markercharacter  =pptestcd markerattrs = (size = 0);
endlayout;

layout overlay / yaxisopts=(reverse=true tickvalueattrs=(size=6pt) display=( tickvalues line) )
xaxisopts=(display=(ticks tickvalues line) tickvalueattrs=(size=6pt));
scatterplot  y=catlevel x=normalbydose/ group=usubjid name="scatter" markerattrs=(size= 8 );
referenceline x=1 / LINEATTRS=(COLOR=gray PATTERN=solid thickness=1); 
referenceline x = &lower/LINEATTRS=(COLOR=gray PATTERN=shortdash thickness=1);
referenceline x = &upper/LINEATTRS=(COLOR=gray PATTERN=shortdash thickness=1);
endlayout;

endlayout;
endgraph;
end;
run;


%SmCheckAndCreateFolder(
BasePath = &OutputFolder.,
FolderName =MetaVariability
);

options nodate nonumber;
ods listing gpath = "&OutputFolder.\MetaVariability" style=statistical;
ods graphics on / noborder imagefmt = png imagename = "&SubmissionId.MetaVariability" width = 1000px height = 1200;

proc sgrender data=mengmetavar1 template=ForestPlotMetaVar;
run;

ods graphics off;
ods listing close;




/*distribution*/
data distributioninput;
set mengmetavar;
drop combination;
run;

proc sort data=distributioninput nodupkey;
by study TreatmentInPeriodText USUBJID normalbydose  cohortDescription MacroAnalyte MacroParameter  OrgMACRORESULT dose;
run;

ods listing gpath = "&OutputFolder.\MetaVariability" style=statistical;
ods graphics on / noborder imagefmt = png imagename = "&SubmissionId._Distribution" width = 1000px height = 1200;


ods graphics on;
proc univariate data=distributioninput noprint;
histogram normalbydose ;
title 'Distribution of PP Results Normalized by Dose';
inset normal(mu sigma) n = 'Number of Observations' / position=ne;
run;

ods graphics off;
ods listing close;

ods csv file="&OutputFolder.\MetaVariability\distributioninput.csv";
proc print data=distributioninput;
run;
ods csv close;


/********************************demographics************************************************/

%do i=1 %to %sysfunc(countw(%nrquote(&studycode_sel ),$));

    %let current_study=%scan(%nrquote(&studycode_sel),&i,$);
    %put current_study=&current_study;

    %let current_studydm=%sysfunc(catx(\,&datasetpath,&current_study,tabulations,sdtm));
    %put &current_studydm;
    %let current_studydmxpt=%sysfunc(catx(\,&current_studydm,dm.xpt));
    %put current_studydmxpt=&current_studydmxpt;

    libname sasfile "&current_studydm";
    libname xptfile xport "&current_studydmxpt" access=readonly;
    proc copy inlib=xptfile outlib=sasfile;
    run; 
     
    data currentdm&i;
    set sasfile.dm;
    STUDY="&current_study";
    ObsID=_n_;
    run;

%end;

%let max=%sysfunc(countw(%nrquote(&studycode_sel),$));

data combinedm;
length study $200;
set 
%do j=1 %to &max;
    currentdm&j.
%end;
;
run;



data metasubjectid;
set mengmetavar;
keep usubjid study normalbydose;
run;

proc sort data=metasubjectid nodupkey;
by study usubjid normalbydose;
run;

proc sort data=metasubjectid;
by usubjid;
run;

proc sort data=combinedm;
by usubjid;
run;

/*dm with user selected subject*/
data metademo;
merge metasubjectid (in=a) combinedm (in=b);
by usubjid;                                     
if a and b; 
run;

proc sort data=metademo;
by study usubjid;
run;




ods csv file="&OutputFolder.\MetaVariability\MetaDemoInput.csv" style=statistical ;
proc print data=metademo;run;
ods csv close;

%macro mengmetademo(subset=, subsetcont=,subsetlong=,subsetcat=) ;




data &subset;
set metademo;
%if &subset=belowlower %then %do;
where normalbydose<&lower;
%end;
%else %if &subset=middle %then %do;
where normalbydose>=&lower and normalbydose<=&upper;
%end;
%else %if &subset=aboveupper %then %do;
where normalbydose>&upper;
%end;
run;

/*continous data*/
%if  &agevar ne  %then %do;
    proc summary data=&subset;
    var &agevar;
    output out = &subsetcont(drop = _type_ _freq_)
    mean = mean n=n std=std min=min max=max; 
    run;

    data &subsetcont;
    set &subsetcont;
    label="&agevar";
    mean=round(mean,0.01);
    std=round(std,0.01);
    n=round(n,1);
    min=round(min,0.01);
    max=round(max,0.01);
    run;

    /*transformation to long format*/
    proc transpose data=&subsetcont out=&subsetlong;
    id label;
    var mean n std min max;
    run;

    data &subsetlong;
    set &subsetlong;
    %if &subsetlong=llong %then %do;
    category="Below Lower";
    %end;
    %if &subsetlong=mlong %then %do;
    category="Middle";
    %end;
    %if &subsetlong=ulong %then %do;
    category="Above Upper";
    %end;
    order1=1;
    order2=_n_;
    run;

    %let subsetlongstr=llong$mlong$ulong;
    %put &subsetlongstr;
  
data meng;
if exist("llong") then l=1;
if exist("mlong") then  m=1;
if exist("ulong") then u=1;
call symput("l",l);
call symput("m",m);
call symput("u",u);
run;

%put l:&l;
%put m:&m;
%put u:&u;

data contall;
    set 
    %if&l=1 %then %do; llong %end;
    %if&m=1 %then %do; mlong %end;
    %if&u=1 %then %do; ulong %end;;
    rename age=value;
    run;
   

%end;


/*categorical data*/
%let catvar=&racevar$&sexvar$&ethnicvar$countryvar;
%put &catvar;

/*below middle upper exist or not*/
data meng1;
if exist("belowlower") then bl=1;
if exist("middle") then  md=1;
if exist("aboveupper") then au=1;
call symput("bl",bl);
call symput("md",md);
call symput("au",au);
run;

%put bl:&bl;
%put md:&md;
%put au:&au;

%if &bl eq 1 and  &md ne 1 and &au ne 1 %then %do;
%let input=belowlower$$;
%let categoryvar= Below Lower$$;
%end;

%if &bl ne 1 and  &md eq 1 and &au ne 1 %then %do;
%let input=$middle$;
%let categoryvar=$Middle$;
%end;

%if &bl ne 1 and  &md ne 1 and &au eq 1 %then %do ;
%let input=$$aboveupper;
%let categoryvar=$$Above Upper;
%end;

%if &bl eq 1 and  &md eq 1 and &au ne 1 %then %do;
%let input=belowlower$middle$;
%let categoryvar= Below Lower$Middle$;
%end;

%if &bl ne 1 and  &md eq 1 and &au eq 1 %then %do;
%let input=$middle$aboveupper;
%let categoryvar= $Middle$Above Upper;
%end;

%if &bl eq 1 and  &md ne 1 and &au eq 1 %then %do;
%let input=belowlower$$aboveupper;
%let categoryvar= Below Lower$$Above Upper;
%end;

%if &bl eq 1 and  &md eq 1 and &au eq 1 %then %do;
%let input=$belowlower$middle$aboveupper;
%let categoryvar=Below Lower$Middle$Above Upper;
%end;

%put input=&input;
%put categoryvar=&categoryvar;



%do i=1 %to %sysfunc(countw(&input,$));
    /*RACE*/
    %if  &racevar ne  %then %do;
  
        proc freq data=%scan(&input,&i,$) noprint;
        tables &racevar/out=&work.race_&i  nocol norow nopercent;
        run;

        data &work.race_&i ;
        set &work.race_&i ;
        category="%scan(&categoryvar,&i,$)";
        order1=2;
     
        rename count=value race=_name_;
        drop PERCENT;
        run;
        
    %end;


    /*SEX*/
    %if  &sexvar ne  %then %do;
        proc freq data=%scan(&input,&i,$) noprint;
        tables &&sexvar/out=&work.sex_&i  nocol norow nopercent;
        run;

        data &work.sex_&i ;
        set &work.sex_&i ;
        category="%scan(&categoryvar,&i,$)";
        order1=3;
     
        rename count=value sex=_name_;
        drop PERCENT;
        run;
    %end;

    /*COUNTRY*/
    %if  &countryvar ne  %then %do;
        proc freq data=%scan(&input,&i,$) noprint;
        tables &countryvar/out=&work.country_&i  nocol norow nopercent;
        run;

        data &work.country_&i ;
        set &work.country_&i ;
        category="%scan(&categoryvar,&i,$)";
        order1=4;
      
        rename count=value country=_name_;
        drop PERCENT;
        run;
    %end;


    /*ETHNIC*/
    %if  &ethnicvar ne  %then %do;
        proc freq data=%scan(&input,&i,$) noprint;
        tables &ethnicvar/out=&work.ethnic_&i  nocol norow nopercent;
        run;

        data &work.ethnic_&i ;
        set &work.ethnic_&i ;
        category="%scan(&categoryvar,&i,$)";
        order1=5;
      
        rename count=value ethnic=_name_;
        drop PERCENT;
        run;
    %end;
%end; 



%if  &racevar ne  %then %do;

data catallrace;
set %do i=1 %to %sysfunc(countw(&input,$)); &work.race_&i %end;;
_label_="race";
run;

proc sql noprint;
select count(*) into : raceobs from catallrace;
quit;
%put raceobs=&raceobs;



%if &raceobs ne 0 %then %do;

proc sql;
select name into :racevlist 
from dictionary.columns
where memname=upcase("catallrace") and varnum=1;
quit;
%put racevlist =&racevlist ;

proc sort data=catallrace;
by &racevlist;
run;

data catallrace;
set catallrace;
by &racevlist;
if first.&racevlist then order2+1;;
run;

%end;

%end;

%if  &sexvar ne  %then %do;

data catallsex;
set %do i=1 %to %sysfunc(countw(&input,$)); &work.sex_&i %end;;
_label_="sex";
run;


proc sql noprint;
select count(*) into : sexobs from catallsex;
quit;
%put sexobs=&sexobs;

%if &sexobs ne 0 %then %do;

proc sql;
select name into :sexvlist 
from dictionary.columns
where memname=upcase("catallsex") and varnum=1;
quit;
%put sexvlist=&sexvlist;

proc sort data=catallsex;
by &sexvlist;
run;

data catallsex;
set  catallsex;
by &sexvlist;
if first.&sexvlist then order2+1;
run;
%end;
%end;

%if  &countryvar ne  %then %do;

data catallcountry;
set %do i=1 %to %sysfunc(countw(&input,$)); &work.country_&i %end;;
_label_="country";
run;

proc sql noprint;
select count(*) into : countryobs from catallcountry;
quit;
%put countryobs=&countryobs;


%if &countryobs ne 0 %then %do;

proc sql;
select name into :countryvlist 
from dictionary.columns
where memname=upcase("catallcountry") and varnum=1;
quit;
%put countryvlist =&countryvlist ;

proc sort data=catallcountry;
by &countryvlist ;
run;

data catallcountry;
set catallcountry;
by &countryvlist ;
if first.&countryvlist  then order2+1;
run;

%end;
%end;

%if  &ethnicvar ne  %then %do;

data catallethnic;
set %do i=1 %to %sysfunc(countw(&input,$)); &work.ethnic_&i %end;;
_label_="ethnic";
run;


proc sql noprint;
select count(*) into : ethnicobs from catallethnic;
quit;
%put ethnicobs=&ethnicobs;


%if &ethnicobs ne 0 %then %do;
proc sql;
select name into :ethnicvlist 
from dictionary.columns
where memname=upcase("catallethnic") and varnum=1;
quit;
%put ethniclist=&ethnicvlist;

proc sort data=catallethnic;
by &ethnicvlist;
run;
data catallethnic;
set catallethnic;
by &ethnicvlist;
if first.&ethnicvlist then order2+1;
run;

%end;


%end;





data meng2;
if exist("catallrace") then cr=1;
if exist("catallsex") then  cs=1;
if exist("catallcountry") then cc=1;
if exist("catallethnic") then ce=1;
call symput("cr",cr);
call symput("cs",cs);
call symput("cc",cc);
call symput("ce",ce);
run;

%put cr:&cr;
%put cs:&cs;
%put cc:&cc;
%put ce:&ce;

data catall;
set
%if&cr=1 %then %do; catallrace %end;
%if&cs=1 %then %do; catallsex %end;
%if&cc=1 %then %do; catallcountry %end;
%if&ce=1 %then %do; catallethnic %end;;
run;


/*unite*/

data meng3;
if exist("catall") then catall=1;
if exist("contall") then  contall=1;
call symput("catall",catall);
call symput("contall",contall);
run;

%put catall:&catall;
%put contall:&contall;


data all;
set
%if&catall=1 %then %do; catall %end;
%if&contall=1 %then %do; contall %end;;
drop _label_;
run;






/*report*/
proc format ; 
value head  
1="Age"
2="Race"
3="Sex"
4="Country"
5="Ethnic";
run ; 


ods rtf file="&OutputFolder.\MetaVariability\Demographic Summary.rtf" style=statistical ;
title "Meta Variability: Demographic Summary ";

proc report data=all split="'"  nowindows 

style(report)={font_face=times font_size=3 bordercolor=black } 
style(column)={just=center font_face=times background=white foreground=black font_size=3 bordercolor=black cellwidth=1in} 
style(header)={just=center font_face=times cellheight=1in font_size=3 foreground=black bordercolor=black cellwidth=1in backgroundcolor=honeydrew}; 
column order1 order2 _name_ category,value; /*summarized underneath every unique value for category*/
define order1 / group noprint order=internal ; 
define order2 / group noprint order=internal ; 
define _name_ / group ' ' ; 
define  category/ across 'Categorized by Input Cutoffs' order = internal  ; 
define value / group ' ';
compute before order1 ; 
 line @1 ' ' ; 
 line @1 order1 head. ; 
endcomp; 
run; 

ods rtf close;




%mend;
%mengmetademo(subset=belowlower, subsetcont=lowercont,subsetlong=llong,subsetcat=lowercat);
%mengmetademo(subset=middle, subsetcont=middlecont,subsetlong=mlong,subsetcat=middlecat);
%mengmetademo(subset=aboveupper, subsetcont=uppercont,subsetlong=ulong,subsetcat=uppercat);




/*boxplot and regression lines for categroical and continous demographics */
%SmCheckAndCreateFolder(
BasePath = &OutputFolder.,
FolderName =MetaVariability\Intrinsic Features
);


/*1. normalized by dose vs dose*/
ods listing gpath = "&OutputFolder.\MetaVariability\Intrinsic Features" style=statistical;
ods graphics on / noborder imagefmt = png imagename = "&SubmissionId._DOSE" width = 1000px height = 1200;

proc sgplot data=mengmetavar;
title "PP Results Normalized by Dose  VS  Dose";
vbox normalbydose/category=dose;
yaxis label="PP Results Normalized by Dose";
run;

ods graphics off;
ods listing close;

/*2. demographics*/



%if  &agevar ne %then %do;

proc sql noprint;
select &agevar into: agemissing from metademo;
quit;
%put &agemissing;

    %if &agemissing ne . %then %do;
    %put  has agevar and agevalue;

    proc reg data=metademo;
    model normalbydose=&agevar;
    ods output ParameterEstimates=PE;
    run;

    data _null_;
    set PE;
    if _n_ = 1 then call symput('Int', put(estimate, BEST6.));    
    else            call symput('Slope', put(estimate, BEST6.));  
    run;
    %put int=&int slop=&slope;

    ods listing gpath = "&OutputFolder.\MetaVariability\Intrinsic Features" style=statistical;
    ods graphics on / noborder imagefmt = png imagename = "&SubmissionId._&agevar" width = 1000px height = 1200;

    proc sgplot data=metademo noautolegend;
    title "Regression Line of PP Results Normalized by Dose VS Age";
    reg y=normalbydose x=&agevar;
    inset "Intercept = &Int" "Slope = &Slope" / border title="Parameter Estimates" position=topleft;
    yaxis label="PP Results Normalized by Dose";
    run;

    ods graphics off;
    ods listing close;
    %end;
%end;


%macro isBlank(param);
%sysevalf(%superq(param)=,boolean)
%mend isBlank;

%if  &racevar ne  %then %do;
proc sql noprint;
select &racevar into: racemissing from metademo;
quit;
%put &racemissing;

   %if %isblank(&racemissing.)=0 %then %do;
    ods listing gpath = "&OutputFolder.\MetaVariability\Intrinsic Features" style=statistical;
    ods graphics on / noborder imagefmt = png imagename = "&SubmissionId._&racevar" width = 1000px height = 1200;

    title "PP Results Normalized by Dose in Race";
    proc sgplot data=metademo;
    vbox normalbydose/category=&racevar;
    yaxis label="PP Results Normalized by Dose";
    run;

    ods graphics off;
    ods listing close;
    %end;
%end;



%if  &sexvar ne  %then %do;
proc sql noprint;
select &sexvar into: sexmissing from metademo;
quit;
%put &sexmissing;

    %if %isblank(&sexmissing)=0 %then %do;
   
    ods listing gpath = "&OutputFolder.\MetaVariability\Intrinsic Features" style=statistical;
    ods graphics on / noborder imagefmt = png imagename = "&SubmissionId._&sexvar" width = 1000px height = 1200;

    title "PP Results Normalized by Dose in Gender";
    proc sgplot data=metademo;
    vbox normalbydose/category=&sexvar;
    yaxis label="PP Results Normalized by Dose";
    run;

    ods graphics off;
    ods listing close;
    %end;

%end;

%if  &countryvar ne  %then %do;
proc sql noprint;
select &countryvar into: countrymissing from metademo;
quit;
%put &countrymissing;

    %if %isblank(&countrymissing)=0 %then %do;
    
    ods listing gpath = "&OutputFolder.\MetaVariability\Intrinsic Features" style=statistical;
    ods graphics on / noborder imagefmt = png imagename = "&SubmissionId._&countryvar" width = 1000px height = 1200;

    title "PP Results Normalized by Dose in Country";
    proc sgplot data=metademo;
    vbox normalbydose/category=&countryvar;
    yaxis label="PP Results Normalized by Dose";
    run;

    ods graphics off;
    ods listing close;
    %end;
%end;


%if  &ethnicvar ne  %then %do;
proc sql noprint;
select &ethnicvar into: ethnicmissing from metademo;
quit;
%put &ethnicmissing;

    %if %isblank(&ethnicmissing)=0 %then %do;

    ods listing gpath = "&OutputFolder.\MetaVariability\Intrinsic Features" style=statistical;
    ods graphics on / noborder imagefmt = png imagename = "&SubmissionId._&ethnicvar" width = 1000px height = 1200;

    title "PP Results Normalized by Dose in Ethnicity";
    proc sgplot data=metademo;
    vbox normalbydose/category=&ethnicvar;
    xaxis label="&ethnicvar";
    yaxis label="PP Results Normalized by Dose";
    run;

    ods graphics off;
    ods listing close;
    %end;
%end;


%macro stats(varlist=);

data metademo1;
set metademo;
log_normalbydose=log(normalbydose);
run;

%do i=1 %to 4;

%if %scan(%nrquote(&varlist),&i,$) ne   %then %do;

proc summary data=metademo1;
class %scan(%nrquote(&varlist),&i,$);
var normalbydose;
output out=stats_&i.
mean=mean n=n std=std median=median;
run;

proc means data=metademo1 noprint;
class %scan(%nrquote(&varlist),&i,$);
var log_normalbydose;
output out=logstats_&i. mean=logmean;
run;

data geomean_&i.;
set logstats_&i.;
geomean = exp(logmean);
run;

proc sort data=stats_&i.;by %scan(%nrquote(&varlist),&i,$);
proc sort data=geomean_&i.;by %scan(%nrquote(&varlist),&i,$);


data statsall_&i.;
merge stats_&i. geomean_&i.;
by %scan(%nrquote(&varlist),&i,$);
if _type_= 0 then delete;
drop _TYPE_ _FREQ_ ;
mean=round(mean,0.01);
std=round(std,0.01);
median=round(median,0.01);
logmean=round(logmean,0.01);
geomean=round(geomean,0.01);
run;

%end;
%end;

ods tagsets.excelxp file="&OutputFolder.\MetaVariability\Intrinsic Features\Descriptive Statistics.xls" STYLE=statistical;

%do i=1 %to 4;
%if %scan(%nrquote(&varlist),&i,$) ne   %then %do;
ods tagsets.excelxp options(SHEET_NAME="%scan(%nrquote(&varlist),&i,$)");
proc print data=statsall_&i. noobs;run;
%end;
%end;

ods tagsets.excelxp close;



%mend;
%stats(varlist=&racevar$&sexvar$&countryvar$&ethnicvar);






%mend PkViewMetaVariability;  

