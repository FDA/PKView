%*****************************************************************************************;
%**                                                                                     **;
%** Run script to generate OGD format data from the user settings                       **;
%**                                                                                     **;
%** Created by Meng Xu and Eduard Porta                                                 **;
%** Coded by Meng Xu                                                                    **;
%*****************************************************************************************;


%macro PKViewReportNcaAnalysis();

%SmReadMappingsFromDataSet();

/* Read report settings from websvc input dataset (provided by C#) */
%SmReadReportSettingsNca();

/* SAVE SAMPLE DATA FOR DEBUGGING PURPOSES */



/* Retrieve NDA Id */
%let Nda_Number=&SubmissionId.;
%put Nda_number=&Nda_Number.;
%put StudyId=&StudyId.;

/* Generate output path based on NDA Id, User Id and settings Id */
%let OutputFolder = &SasSpPath.\Output Files\PKView\&UserName.\&ProfileName.\&nda_number.\&SupplementNum;

%global  SequenceVar PeriodPcVar PeriodPpVar AnalytePcVar AnalytePpVar 
ResultPcVar ResultPpVar TimeVar ParameterVar ExTrtVar ExDateVar ExPeriodVar
AnalyteVar ParameterVar StudyDesign;

/*Assign the macro variable back because of different naming*/
%put studyDesign=&studyDesign;
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



***************************************************************************
***************************************************************************
*****Macros OGDPC and OGDPP Generate OGD required inputs and formats*******
*************************Meng Xu created on 05/2016 ***********************
***************************************************************************
***************************************************************************;
%macro OGDPCPP;

data &work.concentration;
set &work.concentration;
subjectback=substr(subject,2,length(subject)-1);
drop subject;
rename subjectback=subject;
run;

data &work.OGDPC;
set &work.concentration;
ARM=UPCASE(ARM);
TREATMENT=UPCASE(TREATMENT);

if NOMINALTIME=. then delete;
if RESULT=. then delete;
run;



/*create macro variable for selected cohort, analyte and specimen*/
proc sql noprint;
select distinct cohort into: cohosel from &work.OGDPC;
select distinct analyte into: analsel from &work.OGDPC;
select distinct specimen into: specsel from &work.OGDPC;
quit;

data &work.TrimOgdPC;
set &work.OGDPC;
keep SUBJECT ARM PERIOD TREATMENT NOMINALTIME RESULT ;
run;

/*sort and transpose PC data set from long format to wide format: result merged to time*/
proc sort data=&work.TrimOgdPC out=&work.longPC nodup;
by SUBJECT ARM PERIOD TREATMENT NOMINALTIME descending RESULT;
run;

proc transpose data=&work.LongPC out=&work.ResultWidePC prefix=C;
by  SUBJECT ARM PERIOD TREATMENT;
var RESULT;
run;

/*generate last concentration, ke_first and ke_last--bugs*/
data &work.KeResultWidePC;
set &work.ResultWidePC;
array stat {*} _NUMERIC_;

    do i =1 to dim(stat);
        Cend=compress("C"||i);
        if stat{i} ne . then do ;
        Cvalue=stat{i};
       
        Ke_Last=i;
        /*to fix*/
        Ke_first=Ke_Last-2;
    end;
  
end;
run;

proc transpose data=&work.LongPC out=&work.TimeWidePC prefix=T;
by SUBJECT ARM PERIOD TREATMENT;
var NOMINALTIME;
run;

/*generate last time*/
data &work.timewidepc;
set &work.timewidepc;
array Tn (*) _NUMERIC_;
    do i =1 to dim(Tn);
    tend=compress("T"||i);
    end;
run;

proc sql noprint;
select distinct cend into: cend from &work.KeResultWidePC;
select distinct tend into: tend from &work.timewidepc;
quit;
%put cend is &Cend, tend is &tend;

proc sort data=&work.TimeWidePC;
by SUBJECT ARM PERIOD TREATMENT ;
run;

proc sort data=&work.KeResultWidePC;
by SUBJECT ARM PERIOD TREATMENT ;
run;

data &work.WidePC;
merge &work.TimeWidePC(drop=_NAME_ tend i )  &work.KeResultWidePC(drop=_NAME_ i Cvalue cend );
run;

/*delete mising records*/
data &work.NoMissWidePC;
set &work.WidePC; 
run;


/*get the list of sequence, period and treatmentinperiodtext mixed with pp together*/

%global cosel ansel spsel pasel  trvar uniqueperiod paramper subvar;

data &work.OGDPP;
set websvc.pharmacokinetics;
run;

data &work.OGDPP;
set &work.OGDPP;
subjectback=substr(subject,2,length(subject)-1);
drop subject;
rename subjectback=subject;
run;


data &work.OGDPP;
length selected $ 100;
format selected $ 100.;
set &work.OGDPP;

ARM=UPCASE(ARM);
TREATMENT=UPCASE(TREATMENT);

origresult=exp(RESULT);
drop RESULT;
rename origresult= RESULT;
if selected=. then selected =parameter;
if RESULT=. then delete;
run;

proc sql noprint;
select distinct COHORT into: cosel from &work.OGDPP;
select distinct ANALYTE into: ansel from &work.OGDPP;
select distinct SPECIMEN into: spsel from &work.OGDPP;
select distinct SELECTED into: pasel separated by "$" from &work.OGDPP;
quit;



data &work.trimOGDPP;
set &work.OGDPP;
keep SUBJECT ARM PERIOD TREATMENT PARAMETER RESULT SELECTED ;
run;

proc sql noprint;
select distinct PERIOD into: uniqueperiod separated by "$" from &work.trimOGDPP;
quit;


%do a= 1 %to %sysfunc(countw(%quote(&uniqueperiod.),$));
    data &work.trimOGDPP_&a.;
    set &work.trimOGDPP;
    where period="%Scan(%quote(&uniqueperiod),&a,$)";
    run;

    proc sql noprint;
    select distinct selected into:paramper separated  by "$" from &work.trimOGDPP_&a.;
    quit;



    /*remove duplicates*/
    proc sort data=&work.trimOGDPP_&a.  out=&work.LongPP_&a.  nodup ;
    by SUBJECT ARM PERIOD TREATMENT;
    run;


    proc transpose data=&work.LongPP_&a.  out=&work.WidePP_&a. LET ;
    by SUBJECT ARM PERIOD TREATMENT;
    var RESULT;
    id PARAMETER;
    run;



    /*delete mising records*/ 
    data &work.NoMissPPResultWidePP_&a.;
    set  &work.WidePP_&a. ;
    if ARM= "                 " or PERIOD= "                 " or TREATMENT= "                 " then delete;
    run;
%end;

data &work.NoMissPPResultWidePP;
set %do a= 1 %to %sysfunc(countw(%quote(&uniqueperiod.),$));&work.NoMissPPResultWidePP_&a. %end;;
run;



/*change subject, period , sequence and treatment into numeric sub, per, seq and trt and let PC and PP Subjects match with each other*/

/*treat pc and pp together*/
proc sql noprint;
    create table &work.unionboth as
    select distinct(SUBJECT ),ARM, PERIOD, TREATMENT
    from &work.nomisswidepc
    union 
    select distinct(SUBJECT), ARM ,PERIOD, TREATMENT
    from &work.nomissppresultwidepp;

    select distinct SUBJECT into: subvar separated by "$" from &work.unionboth;
    select distinct ARM into: seqvar separated by "$" from &work.unionboth;
    select distinct PERIOD into: pervar separated by "$" from &work.unionboth;
    select distinct TREATMENT into: trtvar separated by "$" from &work.unionboth;
quit;



data &work.unionboth;
set &work.unionboth;
    %do w=1 %to %sysfunc(countw(%quote(&subvar.),$));
        if SUBJECT= "%scan(%quote(&subvar.),&w.,$)" then sub=&w.;
    %end;
    %do x=1 %to %sysfunc(countw(%quote(&seqvar.),$));
        if ARM= "%scan(%quote(&seqvar.),&x.,$)" then seq=&x.;
    %end;

    %do y=1 %to %sysfunc(countw(%quote(&pervar.),$));
        if PERIOD= "%scan(%quote(&pervar.),&y.,$)" then per=&y.;
    %end;

    %do z=1 %to %sysfunc(countw(%quote(&trtvar.),$));
        if TREATMENT= "%scan(%quote(&trtvar.),&z.,$)" then trt=&z.;
    %end;
run;


proc sort data=&work.unionboth;
by SUBJECT ARM PERIOD TREATMENT;
run;

proc sort data=&work.nomisswidepc;
by SUBJECT ARM PERIOD TREATMENT;
run;


proc sort data=&work.nomissppresultwidepp;
by SUBJECT ARM PERIOD TREATMENT;
run;

data &work.pcinput;
merge &work.unionboth(in=a) &work.nomisswidepc(in=b);
by SUBJECT ARM PERIOD TREATMENT;
if a and b;
run;


data &work.InputPC;
retain sub seq per trt C1-&Cend Ke_First Ke_Last T1-&Tend SUBJECT ARM PERIOD TREATMENT;
set &work.pcinput;
RUN;


data &work.AllInputPP;
merge &work.unionboth(in=a) &work.nomissppresultwidepp(in=b);
by SUBJECT ARM PERIOD TREATMENT;
if a and b;
run;

proc sort data=&work.AllInputPP out=&work.InputPP;
by sub seq per trt ;
run;

data &work.InputPP;
retain sub seq per trt 
  %do i=1 %to %sysfunc(countw(%quote(&pasel.), $));
    %scan(%quote(&pasel),&i.,$)
  %end;
SUBJECT ARM PERIOD TREATMENT;
set &work.InputPP;
run;


%mend;
%OGDPCPP;


/*output PC and PP inputs*/
%SmCheckAndCreateFolder(
        BasePath = &OutputFolder.,
        FolderName = &StudyId.
);

%SmCheckAndCreateFolder(
        BasePath = &OutputFolder.\&StudyId.,
        FolderName = &ReportFolder.
);

ods tagsets.excelxp file="&OutputFolder.\&StudyId.\&ReportFolder.\&StudyId.NCAInput.xls" style=printer;
ods tagsets.excelxp options(sheet_name="conc");
proc print data=&work.InputPC noobs;
run;

ods tagsets.excelxp options(sheet_name="pk");
proc print data=&work.InputPP noobs;
run;
ods tagsets.excelXP close;

/*cross validation for PP input and PC input*/
%macro crossvalidation;
/*cross validation - PP input*/

%do i =1 %to %sysfunc(countw(%quote(&pasel),$));
proc summary data=&work.AllInputPP nway missing;
class treatment;
var  %scan(%quote(&pasel.),&i.,$);
output out=&work.mengout_&i (drop= _TYPE_ _FREQ_ )
mean=mean
std=std
n=n;
run;

data &work.mengout_&i;
length treatment parameter $ 100;
format treatment parameter $ 100.;
set &work.mengout_&i; 
mean=round(mean,0.01);
std=round(std,0.01);
Mean_STD=cats(mean,"(", std,")");
parameter="%scan(%quote(&pasel.),&i.,$)";
drop mean std;
rename n=Number;

run;


%end;

 data &work.PPvalidation;
 length treatment parameter $ 100;
 format treatment parameter $ 100.;
            set 
                %do j = 1 %to %sysfunc(countw(%quote(&pasel.), $));      
                    %if %sysfunc(exist(mengout_&j.)) %then %do;
                        &work.mengout_&j.
                    %end;

                %end;
               ;
        run;




/*cross validation for PP input ends*/
/*cross validation for PC input*/

proc sql noprint;
select count(distinct NOMINALTIME) into:noassay 
from &work.longpc;
quit;
%put noassay =&noassay;

%let noassay=%sysfunc(trim(&noassay));
%put noassay=&noassay;

data &work.meng1;
set &work.inputpc;
clast=C&noassay;;
run;

proc sql noprint;
select distinct clast into:clast from &work.meng1;
quit;
%put clast=&clast;


data &work.meng1;
set &work.meng1;
subcmax=max(of C1-C&noassay);
run;

proc means data=&work.meng1 missing nway noprint ;
output out=&work.cmax(drop=_TYPE_ _FREQ_  ) mean=mean n=n std=std;
class treatment;
var subcmax;
run;

data &work.cmax;
length treatment $ 100;
format treatment $ 100.;
set &work.cmax; 
mean=round(mean,0.01);
std=round(std,0.01);
CMAX_Mean_STD=cats(mean,"(", std,")");
rename n=Cmax_N;
drop mean std;
run;

data &work.meng2;
array c(&noassay) c1-c&noassay;
array t(&noassay) t1-t&noassay;
no_assay=%sysfunc(trim(&noassay));
set &work.meng1;

if c(1)=.  then c(1)=0;  
if c(&noassay)=. then c(&noassay)=0; 
subauclst=0;

do i=2 to &noassay;
    k=i-1;
    subauclst=subauclst+((c(k)+c(i))*(t(i)-t(k))/2);
end;

do i=no_assay to 2 by -1;
    if c(no_assay)>0 then do;
       subnewauct=subauclst;
       subclast=c(no_assay);
       goto f;
    end;
    else do;
        k=i-1;
        if c(i)=0 and c(k)>0 then do;
           subnewauct=subauclst-(c(i)+c(k))*(t(i)-t(k))/2;
           subclast=c(k);
           goto f;
        end;
    end;
  
end;
f: subnewauct=subnewauct;
if subnewauct=. then subnewauct=0;

run;



proc means data=&work.meng2 missing nway noprint ;
output out=&work.auct(drop=_TYPE_ _FREQ_ ) mean=mean n=n std=std;
class treatment;
var subNEWAUCT;
run;


data &work.auct;
length treatment $ 100;
format treatment $ 100.;
set &work.auct; 
mean=round(mean,0.01);
std=round(std,0.01);
AUCT_Mean_STD=cats(mean,"(", std,")");
rename n=AUCT_N;
drop mean std;
run;


proc sort data=&work.auct;by treatment;run;
proc sort data=&work.cmax;by treatment;run;

data &work.PCvalidation;
merge &work.auct &work.cmax;
by treatment;
run;



/*cross validation for PC input ends*/
/*options orientation=landscape;*/

/*ods rtf file="&OutputFolder.\&StudyId.\&ReportFolder.\&StudyId.validation.rtf" style=printer startpage=no bodytitle;*/
/*ods escapechar="^";*/
/*Title "PC PP and PK Summary Table Validation";*/
/*proc report data=&work.pcvalidation nowd*/
/*style(header)={background=white}*/
/*style(report)={outputwidth=6in};*/
/* column ('{\~} ' ('PC Input' TREATMENT AUCT_N AUCT_Mean_STD Cmax_N CMAX_Mean_STD )) ;*/
/*run;*/
/*proc report data=&work.ppvalidation nowd*/
/**/
/*style(header)={background=white}*/
/*style(report)={outputwidth=6in};*/
/* column ('{\~} ' ('PP Input ' treatment parameter Number Mean_STD )) ;*/
/*run;*/
/*ods rtf close;*/



%mend;
%crossvalidation;


%macro longconc;

/*long conc starts*/
/*1. extract pc.xpt raw data*/
libname pcxpt xport "&inputpc" access=readonly;

proc sort data=pcxpt.pc out=&work.pcraw;
by usubjid;
run;

/*2. transpose NCA CONC into long format*/
proc sort data=&work.OGDPC out=&work.longconc nodup;
by SUBJECT ARM PERIOD TREATMENT NOMINALTIME descending RESULT;
run;

data &work.longconc;
retain SUBJECT COHORT ARM PERIOD ANALYTE SPECIMEN TREATMENT NOMINALTIME RESULT ;
set &work.longconc;
run;
%SmCheckAndCreateFolder(
        BasePath = &OutputFolder.,
        FolderName = &StudyId.
);

%SmCheckAndCreateFolder(
        BasePath = &OutputFolder.\&StudyId.,
        FolderName = Individual Conc-Time Listing
);
ods tagsets.excelxp file="&OutputFolder.\&StudyId.\Individual Conc-Time Listing\&StudyId.Conc vs RawPC.xls"  style=statistical;

ods tagsets.excelxp options(sheet_name="Concentration Data_Long Format" center_horizontal="yes" fittopage="yes" suppress_bylines="yes" orientation="landscape" embedded_titles="yes");
title1 "Study &studyid Concentration Data ";
proc print data=&work.longconc noobs;run;

ods tagsets.excelxp options(sheet_name="Raw PC Data" center_horizontal="yes" fittopage="yes" suppress_bylines="yes" orientation="landscape" embedded_titles="yes");
title1 "Study &studyid Raw PC.xpt Data";
proc print data=&work.pcraw noobs;run;

ods tagsets.excelXP close;



/*output to phoenix winnonlin folder*/

%SmCheckAndCreateFolder(
        BasePath = &OutputFolder.\&StudyId.,
        FolderName =Phoenix WinNonlin
);
ods tagsets.excelxp file="&OutputFolder.\&StudyId.\Phoenix WinNonlin\&StudyId.Conc vs RawPC.xls"  style=statistical;

ods tagsets.excelxp options(sheet_name="Concentration Data_Long Format" center_horizontal="yes" fittopage="yes" suppress_bylines="yes" orientation="landscape" embedded_titles="yes");
title1 "Study &studyid Concentration Data ";
proc print data=&work.longconc noobs;run;

ods tagsets.excelxp options(sheet_name="Raw PC Data" center_horizontal="yes" fittopage="yes" suppress_bylines="yes" orientation="landscape" embedded_titles="yes");
title1 "Study &studyid Raw PC.xpt Data";
proc print data=&work.pcraw noobs;run;

ods tagsets.excelXP close;
%mend longconc;
%longconc;



/*Individual c-t listing starts*/

%macro CTbyColumn;

%SmCheckAndCreateFolder(
        BasePath = &OutputFolder.\&StudyId.,
        FolderName = Individual c-t listing by columns
);


/*CROSSOVER: delete period column and sort data by treatment */
%if %upcase(&StudyDesign)=CROSSOVER %then %do;

    data OGDPC_CO;
    set OGDPC; 
    drop ARM PERIOD;
    run;

    proc sort data=OGDPC_CO;
    by COHORT ANALYTE SPECIMEN TREATMENT NOMINALTIME SUBJECT;
    run;

    proc transpose data=OGDPC_CO out=CtColumn;
    id subject;
    by COHORT ANALYTE SPECIMEN TREATMENT NOMINALTIME;
    var result;
    run;

    data CtColumn;
    set CtColumn;
    drop _LABEL_ _NAME_;
    run;

    ods tagsets.excelxp file="&OutputFolder.\&StudyId.\Individual c-t listing by columns\Crossover C-T Listing.xls"  style=statistical;
    ods tagsets.excelxp options(sheet_name="Crossover CT Listing" center_horizontal="yes" fittopage="yes" suppress_bylines="yes" orientation="landscape" embedded_titles="yes");

    title1 "Individual C-T listing by columns for &studyid";
    proc print data=CtColumn noobs;run;

    ods tagsets.excelXP close;
%end;

/*SEQUENTIAL*/
%if %upcase(&StudyDesign)=SEQUENTIAL %then %do;

    data OGDPC_SQ;
    set OGDPC; 
    run;

    proc sort data=OGDPC_SQ;
    by COHORT ARM PERIOD ANALYTE SPECIMEN TREATMENT NOMINALTIME SUBJECT;
    run;

    proc transpose data=OGDPC_SQ out=CtColumn;
    id SUBJECT;
    by COHORT ARM PERIOD ANALYTE SPECIMEN TREATMENT NOMINALTIME;
    var result;
    run;

    data CtColumn;
    set CtColumn;
    drop _LABEL_ _NAME_ ;
    run;

    proc sort data=CtColumn;
    by COHORT ARM PERIOD ANALYTE SPECIMEN TREATMENT;
    RUN;

    ods tagsets.excelxp file="&OutputFolder.\&StudyId.\Individual c-t listing by columns\Sequential C-T Listing.xls"  style=statistical;
    ods tagsets.excelxp options(sheet_name="Sequential CT Listing" center_horizontal="yes" fittopage="yes" suppress_bylines="yes" orientation="landscape" embedded_titles="yes");

    title1 "Individual C-T listing by columns for &studyid";
    proc print data=CtColumn noobs;run;

    ods tagsets.excelXP close;

%end;

/*PARALLEL*/
%if %upcase(&StudyDesign)=PARALLEL %then %do;

    data OGDPC_PL;
    set OGDPC; 
    run;

    proc sql noprint;
        select distinct ARM into: ARMLIST separated by "$" from OGDPC_PL;
    quit;
    %put ARMLIST in OGDPC_PL:&ARMLIST ;

    ods listing close;
    ods tagsets.excelxp file="&OutputFolder.\&StudyId.\Individual c-t listing by columns\Parallel C-T Listing.xls" style=statistical ;
        %do i=1 %to %sysfunc(countw(%nrquote(&ARMLIST),$));
            data OGDPC_PL&i;
            set OGDPC_PL;
            where ARM="%scan(%nrquote(&ARMLIST),&i,$)";
            run;

            proc sort data=OGDPC_PL&i;
            by COHORT ARM PERIOD ANALYTE SPECIMEN TREATMENT NOMINALTIME SUBJECT;
            run;

            proc transpose data=OGDPC_PL&i out=CtColumn&i;
            id SUBJECT;
            by COHORT ARM PERIOD ANALYTE SPECIMEN TREATMENT NOMINALTIME;
            var result;
            run;

            data CtColumn&i;
            set CtColumn&i;
            drop _LABEL_ _NAME_ ;
            run;

            proc sort data=CtColumn&i;
            by COHORT ARM PERIOD ANALYTE SPECIMEN TREATMENT;
            RUN;

            ods tagsets.excelxp options( sheet_name="ARM&i" embedded_titles='yes' embedded_footnotes='yes' );

            title "Individual C-T Listing by Columns for &studyid";
            footnote1 j=left height=10pt color=green  "ARM&i.:%scan(%nrquote(&ARMLIST), &i., $)";
            proc print data=CtColumn&i NOOBS;
            run;        
        %end;
ods tagsets.excelxp close;
%end;/*ends-studydesign=PARALLEL*/


%mend;
%CTbyColumn;


%mend PKViewReportNcaAnalysis;  

 
