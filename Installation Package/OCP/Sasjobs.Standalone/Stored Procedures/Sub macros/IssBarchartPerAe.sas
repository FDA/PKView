%macro IssBarchartPerAe();

*********************************************************************************************
*******************************  Bar chart per AE  ******************************************
*********************************************************************************************;


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

proc sql;
create table ae5_pool as													 
select *, 
1/N_OB_all as single_rate
from ae4
group by &Study, trt, &Adverse_Event, &ID;
quit; 

proc sort data=ae5_pool out=per_ae_p nodupkey;where not missing(&Time) and single_rate^=0 and first_occur="Y"; 
by trt &Adverse_Event &Severity &ID;
run;
proc sort data=per_ae_p;
by trt &Adverse_Event &severity ;
run;
*Caluculate AE rate using the combination of treatments of all the studies;

proc sql; 
create table per_ae_p1 as
select *, sum(single_rate) as Cumulative_rate
from per_ae_p
group by trt, &Adverse_Event ,&severity;
quit;

/**For each trt, AE and severity, get the unique cumulative_rate which is the sum of rate in this senario;*/

proc sort data=per_ae_p1 nodupkey out=per_ae9;
by trt &Adverse_Event &severity ;
run;





*get the round value or default value of cumulative rate ;
%macro roundbar();
data per_ae9_round;														 
set per_ae9;
Cumulative_rate = round(Cumulative_rate, 0.0001);
run;
*remove zero records;
proc sort data=per_ae9_round out=per_ae10 ; by &Adverse_event &Severity;
where Cumulative_rate>0;run;
%mend;

%macro defaultbar();
proc sort data=per_ae9 out=per_ae10 ; by &Adverse_event &Severity;
where Cumulative_rate>0;run;
%mend;
*get round result of cumulative ae rate;
%let roundbarchart="yes";
data _null_;
if &roundbarchart="yes" then call execute('%roundbar');
else call execute('%defaultbar');
run;
 
proc sql;  
create table barchart as 														 
select unique
order as start,
trt as label
from per_ae10;
quit; run;

data control; 														
set barchart;
fmtname = 'barfmt';
type = 'N';
end = START;
run;
proc format lib=work cntlin=control;
run;
 
%if &severlevel=C %then %do;

	proc sql; /*assign severity level to each severity in the bar chart*/
	create table sever as 														 
	select unique
	sev_level as start,
	&severity as label
	from most_sev;
	quit; run;


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

*define a format which will be used in reordering treatments;


/******************************************************/
*Replace special symbols "'","-" to "_";
*Remove extra spaces of variable AEDECOD and AEBODSYS;
/******************************************************/
%let flag=%eval(239-%length(&outputfolder.));%put flag=&flag;
%let len_outputfolder=%length(&outputfolder.);%put len_outputfolder=&len_outputfolder;
%let len_path=%eval((239-%length(&outputfolder.))*3/5);%put len_path=&len_path;
%let body_path=%eval((239-%length(&outputfolder.))*2/5);%put body_path=&body_path;

data per_ae11;

		set per_ae10 ;
		where not missing(&BODY);
		z=translate(&Adverse_Event,"",",");
		y=translate(Z,"","'");
		x=translate(y,"","-");
		m=(translate(trim(x),"_"," "));
		if length(m)>=&len_path then do;
		AEDECOD_NEW=substr(m,1,&len_path);
		end;
		if length(m)<&len_path then do;
		AEDECOD_NEW=m;
		end;

	
		a=translate(&BODY,"",",");
		b=translate(a,"",")");
		c=translate(b,"","(");
		n=tranwrd(c,"AND","");
		f=tranwrd(n,"and","");
		d=compbl(f);
		e=translate(trim(d),"_","");

		if length(f)>=&body_path then do;
		AEBODSYS_NEW=substr(e,1,&body_path);
		end;
		if length(f)<&body_path then do;
		AEBODSYS_NEW=f;
		end;

		RUN;
 

/**********************************************************************************/
*create macro variable AEBODSYS_count which is the count of variable AEBODSYS      ;
/**********************************************************************************/
Proc Sql noprint;
	select  count(distinct(AEBODSYS_NEW)) into :AEBODSYS_COUNT
	from per_ae11;
quit;

/******************************************************/
*Create new dataset with unique value of AEBODSYS_new;
/******************************************************/
data per_ae12; 
	set per_ae11(keep=AEBODSYS_new ); 
run;
proc sort data=per_ae12 noduprecs  out=per_aeuo;
	by AEBODSYS_new ;
run;
*ods results off; 
        %Log(
        Progress = 2,
        TextFeedback = Generating the output for Submission &Nda_number.
    );

/************************************************************************************************/
*Use loop define each AEBODSYS_new into macro variable AEBODSYS_new;                            *;
*Each iteration creates a new dataset by AEBODSYS_new per_aedecod_new to generate plots;        *;
/************************************************************************************************/
%macro Bar_per_ae;
	%do j=1 %to &AEBODSYS_count;
		data _null_ ; set per_aeuo;
			if _n_=&j then do; 
			call symput("AEBODSYS_new", AEBODSYS_new); 
			put AEBODSYS_new=;output ;stop; end; 
		run;

		data aa; set per_ae11;
			where  compress(AEBODSYS_new) = compress("&AEBODSYS_new."); 
		run;
		%SmCheckAndCreateFolder(
        BasePath = &OutputFolder.,
        FolderName = Dose_Response
        );

%put OutputFolder=&OutputFolder.;

        %SmCheckAndCreateFolder(
        BasePath = &OutputFolder.\Dose_Response,
        FolderName = &AEBODSYS_new
        );

		proc sort data=aa; 
			by AEDECOD_NEW; 
		run;
    	data aa1;
			set aa; 
			by AEDECOD_NEW; 
			if first.AEDECOD_NEW then output; 
		run;
    	data _null_; 
			set aa1 nobs=nobs; 
			call symput("nobs1", nobs); 
		run; 

		
	%macro barae;
		%do i=1 %to &nobs1;
			data _null_; 
				set aa1; 
				if _n_=&i then do; 
				call symput("AEDECOD_NEW", AEDECOD_NEW); output;
				put AEDECOD_NEW=;stop; end;
			run;

			proc sort data=aa;
				by AEBODSYS_new AEDECOD_NEW; 
			run;

			data newper_ae10; 
				set aa; 
				where compress(AEDECOD_NEW)=compress("&AEDECOD_NEW.") ;
			run;


			ods _all_ close;

        options nodate nonumber;
        ods listing gpath = " &OutputFolder.\Dose_Response\&AEBODSYS_new";	
				ods graphics on/antialiasmax=5000  imagename=" &AEDECOD_NEW. " imagefmt=png border=off width=12in height=10in  LABELMAX=200;

			/**generate plot;*/
			title "Cumulative rate per AE";
			proc sgplot data=newper_ae10; by AEDECOD_NEW ;										  
			format order barfmt. 
					%if &severlevel=C %then %do; 
					sev_level sevfmt. %end;;

   			vbar order / group=sev_level  response=Cumulative_rate name="sever" stat=sum datalabel grouporder=ascending;
					xaxis display=(nolabel noline noticks) ;
  					yaxis display=(noline noticks) grid;
   			label order="Treatment Group" Cumulative_rate="AE Rate" &Severity="Severity";
			keylegend "sever";
			run;

		%end;
	%mend;
	%barae; 
/*Send the time percentage to GUI*/		
%if &j.=%sysfunc(round(&AEBODSYS_count./2)) %then %do;
        %Log(
        Progress = 20,
        TextFeedback = Generating the output for Submission &Nda_number.
    );

		%put j=&j;
		%put median=%sysfunc(round(&AEBODSYS_count./2));
		%put totalbar=&AEBODSYS_count.;
%end;

 
 
	%end;
%mend;
%Bar_per_ae;
/*Send the time percentage to GUI*/		
        %Log(
        Progress = 35,
        TextFeedback = Generating the output for Submission &Nda_number.
    );

%mend;
