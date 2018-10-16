%macro IssScatterAePooled();
******************  Pooled treatment****************;

	
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
*Add &Adverse_Event,11-14-2017
One person only count each specific AE once which is the first time this AE occur.;
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
data _null_;
set websvc.study;
call symputx("MAXDAYCUMULATIVE",MAXDAYCUMULATIVE);
run;
%put MAXDAYCUMULATIVE=&MAXDAYCUMULATIVE.;
data ae_p3_3;
set ae_p3_3;
where &time<=&MAXDAYCUMULATIVE;
run;

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

data ae_p3_2;
set ae_p3_1;
WHERE  sum_rate=maxsum;
&Time=&MAXDAYCUMULATIVE.;
run;
 
data ae_P4;
set ae_p3_2 ae_p3_3 ae_p3_4;
run;
proc sort data=ae_P4 nodupkey;
by &Adverse_Event trt &Time sum_rate;run;

 
	data ae_p41;
	length AEDECOD_NEW $ 36;
	set ae_p4 ;
		z=translate(&Adverse_Event,"",",");
		y=translate(Z,"","'");
		x=translate(y,"","-");
		AEDECOD_NEW=(translate(trim(x),"_"," "));
	RUN;



    proc sort data=ae_p41; 
		by AEDECOD_NEW; 
	run;
    data ae_p42;
		set ae_p41; 
		by AEDECOD_NEW; 
		if first.AEDECOD_NEW then output; 
	run;
    data _null_; 
		set ae_p42 nobs=nobs; 
		call symput("num", nobs); 
	run; 
 
%put OutputFolder=&OutputFolder.;

        %SmCheckAndCreateFolder(
        BasePath = &OutputFolder.,
        FolderName = Cumulative_AE
        );
        %SmCheckAndCreateFolder(
        BasePath = &OutputFolder.\Cumulative_AE,
        FolderName = PooledTreatment
        );
		
		
	%macro pooled;
		%do i=1 %to &num;
			data _null_; 
			set ae_p42; 
			if _n_=&i then do; 
			call symput("AEDECOD_NEW", AEDECOD_NEW); output;
			put AEDECOD_NEW=;stop; 
			end; run;

			proc sort data=ae_p41;
			by  AEDECOD_NEW; 
			run;

			data new_ae_p4; 
			set ae_p41; 
			where compress(AEDECOD_NEW)=compress("&AEDECOD_NEW.") and count_AE>=&min_ob ;
			run;

			ods _all_ close;



        options nodate nonumber;
        ods listing gpath = " &OutputFolder.\Cumulative_AE\PooledTreatment";		
		ods graphics on/reset antialiasmax=5000 imagename=" &AEDECOD_NEW. " imagefmt=png border=off width=8in height=6in  LABELMAX=200 ;

			proc sgplot data=new_ae_p4; by AEDECOD_NEW; where count_AE>=&min_ob;
			title"Timecourse of AEs by dose";														 
		scatter x=&Time y=sum_rate /group=trt name="scatter" markerattrs=(symbol=CircleFilled size=9);
		series x=&Time y=sum_rate /group=trt lineattrs=(pattern=1 thickness=2);
		label &Time="Study Day" sum_rate="Cumulative AE rate" ;
		keylegend "scatter"/ACROSS=1 DOWN=20  ;
			run; 

/*Send the time percentage to GUI*/		
%if &i.=%sysfunc(round(&num./2)) %then %do;
        %Log(
        Progress = 85,
        TextFeedback = Generating the output for Submission &Nda_number.
    );

		%put i=&i.;
	%put median=%sysfunc(round(&num./2));
%put totalpool=&num;
%end;
%end;
%mend;

%pooled; 

%mend;