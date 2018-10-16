%*****************************************************************************************;
%**                                                                                     **;
%** Generate Updated Treatment Table                                  	                **;
%**                                                                                     **;
%** Created by:                                                                         **;
%**     Yue Zhou (2017)                                                                 **;
%*****************************************************************************************;
%macro IssReadTRTPsFromServer();

%global  
USUBJIDVar TRTPVar ASTDYVar STUDYIDVar AESTDYVar ARMVar TRTSDTVar LSTVSTDTVar
InputAe	InputSl Time Treatment Study    ID    LastTreatDay      FirstTreatDay ;


 
	%** Save into global macro variables **;
	data _null_;
		set websvc.IssMappingSAS;
		if upcase(Source)="ADAE" and upcase(ISS_Variable)="USUBJID" then call symputx("USUBJIDVar",File_Variable,"G");
		if upcase(Source)="ADAE" and upcase(ISS_Variable)="TRTA" then call symputx("TRTPVar",File_Variable,"G");
		if upcase(Source)="ADAE" and upcase(ISS_Variable)="ASTDY" then call symputx("ASTDYVar",File_Variable,"G");
		if upcase(Source)="ADAE" and upcase(ISS_Variable)="STUDYID" then call symputx("STUDYIDVar",File_Variable,"G");
		if upcase(Source)="ADAE" and upcase(ISS_Variable)="AESTDY" then call symputx("AESTDYVar",File_Variable,"G");
		if upcase(Source)="ADSL" and upcase(ISS_Variable)="ARM" then call symputx("ARMVar",File_Variable,"G");
		if upcase(Source)="ADSL" and upcase(ISS_Variable)="TRTSDT" then call symputx("TRTSDTVar",File_Variable,"G");
		if upcase(Source)="ADSL" and upcase(ISS_Variable)="LSTVSTDT" then call symputx("LSTVSTDTVar",File_Variable,"G");
		if upcase(Source)="ADAE"  then call symputx("InputAe",Path,"G");
		if upcase(Source)="ADSL"  then call symputx("InputSl",Path,"G");
	run;
%******************************SET MACRO VARIABLES****************;
*set AE start day by user;
%if &ASTDYVar. ne %then %do;%let Time = &ASTDYVar.;%end;
%else %do;%let Time=&AESTDYVar.;%end;

*set treatment by user;
%if  &TRTPVar. ne %then %do; %let Treatment = &TRTPVar.; %end;
%else %do; %let Treatment = &ARMVar.; %end;

%let Study = &STUDYIDVar.; 
%let ID = &USUBJIDVar.; 
%let LastTreatDay=&LSTVSTDTVar.;
%let FirstTreatDay =&TRTSDTVar.;

%** Debug **;
%put Study = &STUDY.; 
%put ID = &ID.; 
%put Time = &Time.;
%put Treatment = &Treatment.; 
%put LastTreatDay=&LSTVSTDTVar.;
%put FirstTreatDay =&TRTSDTVar.;



%*************INPUT ADAE AND ADSL DATASETS*************************;
	%let inputfolder=\\localhost\clinical\;

	%if  &InputAe. ne  %then %do;
	libname input1 xport "&inputfolder/&InputAe." access=readonly;
	proc copy inlib=input1 outlib=user;
	run; 
	%end;
	%if  &InputSl. ne  %then %do;

	libname input1 xport "&inputfolder/&InputSl." access=readonly;
	proc copy inlib=input1 outlib=user;
	run; 
	%end;


%***************************GET THE VALUE TRTPs TABLE WITH ARM, STUDYID, ORDER```FOR PAGE 2*****;


%if &ARMVar ne %then %do;
	proc sort data=&work.ADSL(keep= &STUDY &ID &ARMVar &LastTreatDay &FirstTreatDay ) nodupkey out=&work.ADSL1;
	by &STUDY &ID &ARMVar;
	run;
	%if &treatment=&TRTPVar %then %do;
		proc sort data=&work.ADAE(keep= &STUDY &ID &Treatment &TIME) OUT=&work.ADAE1;
		by &Study &ID  ;
		run;
	%end;
	%else %if &treatment=&ARMVar %then %do;
		proc sort data=&work.ADAE(keep= &STUDY &ID &TIME) OUT=&work.ADAE1;
		by &Study &ID  ;
		run;
	%end;
	data &work.AE_SL;												 
	merge &work.ADAE1 &work.ADSL1 ;
	by &Study &ID;
	keep &Study &ID &Time  &Treatment  &FirstTreatDay. &LastTreatDay. &ARMVar ;
	run;
	PROC SORT data=&work.AE_SL NODUPKEY;
	BY  &Study &ID &Treatment    &Time ;
	RUN;


	data GETLENGTH1;
	set &work.AE_SL;
	Duration=&LastTreatDay.-&FirstTreatDay. +1;
	run;
	%if &Time. ne %then %do;
	proc sql; 
	create table GETLENGTH2 as																	 
	select*, 
	max(Duration, &time) as max_duration
	from GETLENGTH1
	group by &Study, &ID; 
	quit;
	%end;
	%if &Time. eq %then %do;
	proc sql; 
	create table GETLENGTH2 as																	 
	select*, 
	max(Duration) as max_duration
	from GETLENGTH1
	group by &Study, &ID; 
	quit;
	%end;
	proc sql; 
	create table GETLENGTH3 as																	 
	select*, 
	MAX(max_duration) AS LENGTH 
	from GETLENGTH2
	group by &Study; 
	quit;
	proc sql; 
	create table GETLENGTH4 as																	 
	select*, 
	MAX(LENGTH) AS MaxDayCumulative 
	from GETLENGTH3
	;quit; 

	proc sort data=GETLENGTH4(keep=&Treatment &study &ARMVar   length MaxDayCumulative) nodupkey out=GETLENGTH4;
	by  &Treatment &study &ARMVar   length;
	where not missing(&treatment.);
	run;		
	data &work.data NOLIST;
    length dataset $32.;
    dataset="TRTPs"; output;
 	run;
        
	DATA &work.New_TRTPs_raw;
	LENGTH ARM $500.;
	SET GETLENGTH4;
	where not missing(length);
	rename length=DURATION;
	IF &TREATMENT=TRTP THEN TRTP=UPCASE(TRTP);
	ELSE IF &TREATMENT=ARM THEN TRTP=upcase(ARM);
	ELSE DO ;TRTP=upcase(&TREATMENT.);END;
	ARM=UPCASE(&ARMVar);
	ORDER=.;
	REVISEDTRTP="";
	RUN;
	data &work.data NOLIST;
    length dataset $32.;
    dataset="TRTPs"; output;
 	run;
    data &work.dummy_TRTPs;
    length   ARM $2000.;
    stop;
    run;


    data &work.TRTPs ;
    set &work.dummy_TRTPs
    %if %sysfunc(exist(&work.New_TRTPs_raw)) %then %do;
    	&work.New_TRTPs_raw
    %end;
        ;
	run;

%end;
%else %do;
	proc sort data=&work.ADSL(keep= &STUDY &ID  &LastTreatDay &FirstTreatDay ) nodupkey out=&work.ADSL1;
	by &STUDY &ID ;
	run;

	proc sort data=&work.ADAE(keep= &STUDY &ID &Treatment &TIME) OUT=&work.ADAE1;
	by &Study &ID  ;
	run;


	data &work.AE_SL;												 
	merge &work.ADAE1 &work.ADSL1 ;
	by &Study &ID;
	keep &Study &ID &Time  &Treatment  &FirstTreatDay. &LastTreatDay.  ;
	run;
	PROC SORT data=&work.AE_SL NODUPKEY;
	BY  &Study &ID &Treatment    &Time ;
	RUN;


	data GETLENGTH1;
	set &work.AE_SL;
	Duration=&LastTreatDay.-&FirstTreatDay. +1;
	run;

	%if &Time. ne %then %do;
	proc sql; 
	create table GETLENGTH2 as																	 
	select*, 
	max(Duration, &time) as max_duration
	from GETLENGTH1
	group by &Study, &ID; 
	quit;
	%end;
	%if &Time. eq %then %do;
	proc sql; 
	create table GETLENGTH2 as																	 
	select*, 
	max(Duration) as max_duration
	from GETLENGTH1
	group by &Study, &ID; 
	quit;
	%end;
	proc sql; 
	create table GETLENGTH3 as																	 
	select*, 
	MAX(max_duration) AS LENGTH 
	from GETLENGTH2
	group by &Study; 
	quit;

	proc sql; 
	create table GETLENGTH4 as																	 
	select*, 
	MAX(LENGTH) AS MaxDayCumulative 
	from GETLENGTH3
	;quit; 

	proc sort data=GETLENGTH4(keep=&Treatment &study  length MaxDayCumulative) nodupkey out=GETLENGTH4;
	by &Treatment &study  length;
	where not missing(&treatment.);
	run;

	data &work.data NOLIST;
    length dataset $32.;
    dataset="TRTPs"; output;
 	run;

	DATA &work.New_TRTPs_raw;
	LENGTH ARM $500.;
	SET GETLENGTH4;
	where not missing(length);
	rename &treatment.=TRTP;
	rename length=DURATION;
	ARM=UPCASE(ARM);
	&treatment.=UPCASE(&treatment.);
	ORDER=.;
	REVISEDTRTP="";
	RUN;

    data &work.dummy_TRTPs;
    length   ARM $2000.;
    stop;
    run;

    data &work.TRTPs ;
    set &work.dummy_TRTPs
    %if %sysfunc(exist(&work.New_TRTPs_raw)) %then %do;
    	&work.New_TRTPs_raw
    %end;
        ;
	run;
%end;


%*************
%**   Debug output
%*************

%**%let inputfolder=\\&SYSHOSTNAME.\clinical\;

%if %sysfunc(exist(&work.TRTPs)) %then %do;
				proc export data=&work.TRTPs
		outfile="\\&SYSHOSTNAME.\Output Files\PkView\Peter\TRTPs.csv"
		dbms=dlm replace;
		delimiter=',';
		run; 
	%end;




/*%**************/

%mend;
