%macro IssAnalysisDataReset();

proc sort data=ae_check;
by &treatment. &study;
run;

%if %sysfunc(exist(merge_trtp)) %then %do;
	data reorder;
	set merge_trtp ;
	rename  trtp=&treatment.;
	run;
%end;

%else %do;
	data reorder;
	set server_trtp ;
	rename trtp=&treatment.;
	by order;
	run;
	data qq;
	set server_trtp;
	rename trtp=trt;
	by order;
	run;
	data reorder;
	merge qq reorder;
	by order;
	run;
%end;

proc sort data=reorder;
by &treatment.;
run;

 data TRTPS;
 set  trtps;
 stu=put(STUDYID,25.);
 DROP STUDYID;
 RENAME STU=STUDYID;
 run; 
data trtp_up1;
set trtps;
retain trtp_n1 order_n1;
if order>. then order_n1=order;
if not missing(trtp)  then trtp_n1=trtp;
run;
data trtp_up2;
set trtp_up1;
drop trtp order;
rename trtp_n1=&treatment. order_n1=ORDER;
run;
proc sort data=trtp_up2   ;
by order;
where not missing(&treatment.);
run;
proc sort data=reorder;
by order;
run;
 data reorder;
 set  reorder;
 stu=put(STUDYID,25.);
 DROP STUDYID;
 RENAME STU=STUDYID;
 run; 

data trtp_up3;
merge  reorder trtp_up2;
by order;
run;
proc sort data=trtp_up3 ;
by &treatment &study;
run;
data ae_all;
length &study $25.;
merge ae_check trtp_up3;
by &treatment. &study;
run;
DATA ae;
SET ae_all;
IF INCLUDESTUDY="true" OR INCLUDESTUDY="TRUE";
RUN;
%if &time ne %then %do;
*Take the highest level of severity for each individual, and use this severity level in the further calculation;
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
	IF %SYSFUNC(UPCASE(&Severity)) NOT  IN ('NONE','MILD','MODERATE','SEVERE','THREATEN','DEATH');
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
drop sev_max  ;
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
 


proc sql;/*calculate adverse event rate, count the number of each AE with the same first occurrence time, and divided by the count of all the unique subject in that treatment group of each study*/

create table ae5 as													 
select *, 
1/N_OB as single_rate
from ae4
group by &Study, trt, &Adverse_Event, &ID;
quit; 

proc sort data=ae5 nodupkey out=ae6 ;where not missing(&Time) and single_rate^=0 and first_occur="Y";  
by &Study trt &Adverse_Event &ID;
run;
proc sort data=ae6;
by &Study trt &Adverse_Event &Time;
run;

data ae7;/* Calculate cumulative rate of each AE using accumulation of single_rate by time*/
set ae6;																	 
by &Study trt &Adverse_Event ;
if  first.&Adverse_Event then sum_rate=0;
sum_rate+single_rate;
run;

*Get the data ready for the cumuative_rate plot;
proc sort data=ae7 out=ae8;by &Study trt &Adverse_Event &Time sum_rate;run;  
proc sql; /*count the number of each adverse event within each treatment of each study*/
create table ae9 as													 
select *,
count(&Adverse_Event) as count_AE
from ae8
group by &Study,&Adverse_Event,trt;
quit;
%macro ae_interest_by_study; 
data AE_interest;													 
set ae9;
where &Adverse_Event=&AE1 or &Adverse_Event=&AE2 or &Adverse_Event=&AE3 or &Adverse_Event=&AE4 
or &Adverse_Event=&AE5 or &Adverse_Event=&AE6 or &Adverse_Event=&AE7 or &Adverse_Event=&AE8
or &Adverse_Event=&AE9;
run;
proc sort data=AE_interest out=ae_9;by &Study &Adverse_Event trt &Time;
WHERE NOT MISSING(N_OB);
run;
%mend;
%macro ae_all_by_study; /* Show all the adverse events in reuslts*/
proc sort data=ae9 out=ae_9;by &Study &Adverse_Event trt &Time;
WHERE NOT MISSING(N_OB);
run; 
%mend;
*run macros according to user selections;
data _null_;
if &AE_of_interest="yes" then call execute('%ae_interest_by_study');
else call execute('%ae_all_by_study');
run;

proc sort data=ae_9;BY &STUDY trt  &ADVERSE_EVENT &time;RUN; 
*Get the start point(0) and end point(maximum length) of each study;
proc sql ;
create table ae11 as
select  *,
max(sum_rate) as maxsum,
min(sum_rate) as minsum
from ae_9
group by  &STUDY, trt, &ADVERSE_EVENT;
quit;
*if first ae relative day is less than zero then start point is first ae relative day.
if first ae relative day is ge zero then start point is zero.;
 
data ae0 ;set ae11;
where sum_rate=minsum;
if &time<0 then  &time=&time; 
else  &time=0  ; sum_rate=0; 
run;

data ae13;
set ae11;
WHERE  sum_rate=maxsum;
&Time=LENGTH;
run;
data ae10;
set ae13 ae_9 ae0;
run;
proc sort data=ae10 nodupkey;

by &Study &Adverse_Event trt &Time sum_rate;
WHERE NOT MISSING(N_OB);run; 



%end;
%mend;

