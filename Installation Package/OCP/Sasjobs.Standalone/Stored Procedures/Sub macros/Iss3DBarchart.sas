****************************************************************************************************
************************************    bar chart     **********************************************
****************************************************************************************************;
%macro Iss3DBarchart();

/*read user entered severity*/
%if &AESEVVar. ne %then %do;
	data severorder;
	set websvc.aesevorder;
	rename order=sev_level value=&severity;
run;

%end;
%else %if &ASEVVAR. ne %then %do;
	data severorder;
	set websvc.asevorder;
	rename order=sev_level value=&severity;
	run;
%end;

data _null_;
set severorder;
IF _n_=1 then call symput("SeverOrder",sev_level);
RUN;
%let SeverOrder=&SeverOrder.;
%put SeverOrder=&SeverOrder.;

%macro checksevorder;
%IF  &SeverOrder eq no data %then %do;
%put SeverOrder is empty; 
%if &severlevel=N %then %do;
	data most_sev;
	set ae;
	sev_level=&severity.;
	run;
%end;
%if &severlevel=C %then %do;
	data most_sev;																	 
	set ae;/*assign numeric value to severity levels*/
	if upcase(&Severity)="" then &severity="&level0";
	if upcase(&Severity)="&level0" then sev_level=0;
	if upcase(&Severity)="&level1" then sev_level=1;
	if upcase(&Severity)="&level2" then sev_level=2;
	if upcase(&Severity)="&level3" then sev_level=3;
	if upcase(&Severity)="&level4" then sev_level=4;
	if upcase(&Severity)="&level5" then sev_level=5;
	run;
	DATA SEVALL;
	SET MOST_SEV;
	KEEP &Severity SEV_LEVEL;
	RUN;
	PROC SORT DATA=SEVALL NODUPKEY OUT=UNISEV;
	BY &Severity SEV_LEVEL;
	RUN;
	DATA EMPTYSev;
	SET UNISEV;
	IF %SYSFUNC(UPCASE(&Severity)) NOT  IN ('NONE','MILD','MODERATE','SEVERE','LIFE-THREATENING','DEATH');
	RUN;
	%macro resetsevlevel;
	%macro empty;
	%let EMPTY=1;
		data _null_;
			set EMPTYSev;
			call symput('EMPTY','0'); /* this will only occur if &DATA is not empty */
		run;


		%if &EMPTY %then %do;
			proc datasets lib=work nolist;
			delete EMPTYSev; /* delete dataset */
			quit;
		%end;
	%mend;
	%empty;

	%macro set1;
	%if %sysfunc(exist(EMPTYSev)) %then %do;

		PROC SORT DATA=EMPTYSev;
		BY &Severity;
		RUN;
		DATA _null_;
		SET EMPTYSev NOBS=NOBS;
		CALL SYMPUTX("NOBSS",NOBS);
		put nobs=nobs;
		RUN;

		%MACRO SEVLEVEL;
		%DO i=1 %to &nobss;
			data EMPSev&i.;
			set EMPTYSev;
			if _n_=&i then do;
			%let sev_level&i= -&i.;
			%put sev_level&i=&&sev_level&i;
			sev_level=&&sev_level&i;
			end;
			run;
			data EMPSev&i.;
			set  EMPSev&i.;
			where not missing(sev_level);
			run;

		%end;
		data Merge_Sev;
		SET UNISEV
		%do i=1 %to &NOBSs;
		 EMPSev&i. %END;
		;
		where not missing(sev_level);
		run;

		%mend;
		%sevlevel;
		data most_sev;set most_sev;
		drop sev_level;
		run;
		proc sort data=merge_sev;by   &Severity  ;run;
		proc sort data=most_sev; by  &Severity  ;run;

		data most_sev;
		merge most_sev merge_sev;
		by &Severity  ;run;
	%end;
	%mend; %set1;
	%mend;%resetsevlevel;
%end;

%end;
%else %if &SeverOrder ne %then %do;
	%put SeverOrder is not empty;

	proc sort data=ae;
	by &severity;
	run;
	proc sort data=severorder;
	by &severity;
	run;
	data most_sev;
	merge ae severorder;
	by &severity ;
	run;

%end;
%mend;
%checksevorder;

proc sql;/*select maximum severity level of each subject*/						    
create table max_sev as
select *,
max(sev_level) as sev_max 
from most_sev
group by &Study,&ID, trt, &Adverse_Event;
quit;

data sev_filter; /*Subset the the highest level of severity*/				 		 
set max_sev;
where sev_max=sev_level;
drop sev_max ;
run;

proc sql;/*count the number of unique subject ID and adverse event within each treatment group by each study*/
create table ae1 as																	 
select*, 
count(distinct &Adverse_Event) as N_AEcode /*number of AE kind in each trt group by study*/
from sev_filter
group by &Study, trt; 
quit;



data ae1;
set ae1;
where not missing(&Treatment);
run;
*find the earliest AEday for each subj; 
proc sql;																	 
create table ae2 as
select*, 
min(&Time) as first_occur_day
from ae1
group by &Study, trt, &ID, &Adverse_Event; 
*One person only count each specific AE once which is the first time this AE occur.;
quit;
proc sort data=ae2  out=ae3;by &Study trt &ID &Adverse_Event &Time;run;			 	 
%macro daynot0;*Use default day as starting point in the results;
data ae4 ;																 
set ae3;
if not missing (first_occur_day) and first_occur_day=&Time  then first_occur="Y"; *label the first occurrence time of AE as "Y";
by &Study trt &ID;
run;
%mend;
*Use zero as the starting point in the results;
%macro day0;
data ae4;																 
set ae3;
where &Time>=0;
if not missing (first_occur_day) and first_occur_day=&Time  then first_occur="Y"; *label the first occurrence time of AE as "Y";
by &Study trt &ID;
run;
%mend;
*run macros according to user selections;
data _null_;
if &TimeStartAtZero="yes" then call execute('%day0');
else call execute('%daynot0');
run;
 

/*calculate adverse event rate, count the number of each AE with the same first occurrence time, and divided by the count of all the unique subject in that treatment group*/
proc sql;
create table ae5_pool as													 
select *, 
1/N_OB_all as single_rate
from ae4
group by &Study, trt, &Adverse_Event, &ID;
quit; 

proc sort data=ae5_pool out=ae_p nodupkey;where not missing(&Time) and single_rate^=0 and first_occur="Y"; 
by trt &Adverse_Event  &ID;
run;
proc sort data=ae_p;
by trt &Adverse_Event &Time;
run;
*Caluculate AE rate using the combination of treatments of all the studies;
data ae_p1;													 
set ae_p;
by trt &Adverse_Event;
if  first.&Adverse_Event then sum_rate=0;
sum_rate+single_rate;
run;



*Get the data ready for the cumulative_rate plot using pooled treatment ; 
proc sort data=ae_p1 out=ae_p2;by &Adverse_Event trt &Time sum_rate;run;	 
proc sql;
create table ae_p3 as														 
select *,
count(&Adverse_Event) as count_AE
from ae_p2
group by &Adverse_Event,trt;
quit;

%macro ae_all_pool;/*Show all the adverse events in results, using pooled treatment*/ 	 
proc sort data=ae_p3 out=ae_p3_3;by &Adverse_Event trt &Time;
WHERE NOT MISSING(N_OB);
run;
%mend;
%ae_all_pool
;
*Get the start point(0) and end point(maximum length) of each treatment;

proc sql ;
create table ae_p3_1 as
select  *,
max(sum_rate) as maxsum,
min(sum_rate) as minsum
from ae_p3_3
group by   trt, &ADVERSE_EVENT;
quit;

*change start point according to user selection;

data ae_p3_4;
set ae_p3_1;
where sum_rate=minsum;
if &time<0 then &time=&time ;
else  &time=0  ; sum_rate=0; 
run;


/*use the maximum duration as the maximum study lenght from server*/
proc sql; 
create table ae_p3_1 as																	 
select*, 
MAX(STUDYDURATION) AS max_studyduration 
from ae_p3_1;
quit; 
data ae_p3_2;
set ae_p3_1;
WHERE  sum_rate=maxsum;
&Time=max_studyduration;
run;
 
data ae_P4;
set ae_p3_2 ae_p3_3 ae_p3_4;
run;
proc sort data=ae_P4 nodupkey;
by &Adverse_Event trt &Time sum_rate;run;

data permost_sev;
set ae_p4;
run;

proc sql;/*select maximum severity level of each subject*/						    
create table permax_sev as
select *,
max(sev_level) as persev_max 
from permost_sev
group by trt,&id;
quit;


data persev_filter; /*Subset the the highest level of severity*/				 		 
set permax_sev;
where persev_max=sev_level and not missing(sev_level);
run;

proc sort data=persev_filter nodupkey out=new_sev;
by trt &id  ;
run;

proc sql;
create table m_sev as
select *, count(distinct &id) as ae_coun
from new_sev
group by trt;
quit;


data aep6;
set m_sev;																	 
by trt  ;
if  first.trt then total_rate=0;
total_rate+single_rate;
run;

proc sort data=aep6;
by trt &severity;
run;



*calculate maximum ae rate by treatment, and use it as upper limit for Y axis, stored as a global macro variable &max_ae;
proc sql;
create table max_ae as 														 
select trt,sum(single_rate) as trt_rate
from aep6
group by trt;
quit;

proc sql;																 
select max(trt_rate)+0.5*max(trt_rate)
into: max_ae
from max_ae;
quit;
%macro reorder_format;
proc sql; 
create table barchart as 														 
select unique
order as start,
trt as label
from aep6;
quit; run;
%mend;

%reorder_format;

*define a format which will be used in reordering treatments;
data control; 														
set barchart;
fmtname = 'barfmt';
type = 'N';
end = START;
run;
proc format lib=work cntlin=control;
run;



proc sql; /*assign severity level to each severity in the bar chart*/
create table sever as 														 
select unique
sev_level as start,
&severity as label
from aep6;
quit; run;

%if &severlevel=C %then %do;

	*define a format which will be used in reordering severity;
	data controlsev; 														
	set sever;
	fmtname = 'sevfmt';
	type = 'N';
	end = START;
	run;
	proc format lib=work cntlin=controlsev;
	run;
%end;


******************
******************
* Customized order
******************;
%macro reorder_and_severity; /*use reordered treatment and show the seveirty rather than treatment emergent flag in bar chart*/

		%SmCheckAndCreateFolder(
        BasePath = &OutputFolder.,
        FolderName = Summary_Plots
        );

%put OutputFolder=&OutputFolder.;



        options nodate nonumber;

filename graphout "&OutputFolder.\Summary_Plots";
goptions reset=all device=png hsize=12in vsize=12in gsfname=graphout;
ods _all_ close;

ods listing;
/* Define title for chart */
title h=12pt 'AE percentage versus treatment group, subset by severity';
/* Define axis characteristics */
axis1 label=("Treatment Group");
axis2 label=(angle=90 "AE Prevalence")
      minor=NONE;
/* Define legend characteristics */
legend1 label=none cborder=black;

/* Generate vertical bar chart */
proc gchart data=aep6; 														 
format order barfmt. 
	%if &severlevel=C %then %do; 
		sev_level sevfmt. %end;;

   vbar3d order /discrete sumvar=single_rate
                 subgroup=sev_level
                 inside=subpct
                 outside=sum
                 maxis=axis1
                 raxis=axis2
                 coutline=black
				 legend=legend1;	
 
run;
ods listing close;
%mend;



%macro reorder_and_teae;/*use reordered treatment and show the treatment emergent flag rather than seveirty in bar chart*/

		%SmCheckAndCreateFolder(
        BasePath = &OutputFolder.,
        FolderName = Summary_Plots
        );

%put OutputFolder=&OutputFolder.;

        options nodate nonumber;

filename graphout "&OutputFolder.\Summary_Plots";
goptions reset=all device=png hsize=12in vsize=12in gsfname=graphout;
ods _all_ close;

ods listing;
/* Define title for chart */
title h=12pt 'AE percentage versus treatment group,subset by Treatment Emergent Flag';
/* Define axis characteristics */
axis1 label=("Treatment Group");
axis2 label=(angle=90 "AE Prevalence")
      minor=NONE;
/* Define legend characteristics */
legend1 label=none cborder=black;

/* Generate vertical bar chart */
proc gchart data=aep6; 														 
format order barfmt.;
   vbar3d order /discrete sumvar=single_rate
                 subgroup=&TEAE
                 inside=subpct
                 outside=sum
                 maxis=axis1
                 raxis=axis2
                 coutline=black
				 legend=legend1;	
 
run;
ods listing close;
%mend;

*run macros according to user selections;
%if &severity ne %then %do;
%reorder_and_severity;
/*Send the time percentage to GUI*/		
        %Log(
        Progress = 40,
        TextFeedback = Generating the output for Submission &Nda_number.
    );

%end;
%else %do;
%reorder_and_teae;
/*Send the time percentage to GUI*/		
        %Log(
        Progress = 40,
        TextFeedback = Generating the output for Submission &Nda_number.
    );

%end;



%mend;
 
