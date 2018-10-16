%*****************************************************************************************;
%**                                                                                     **;
%**       Start ISS Analysis                                                            **;
%**                                                                                     **;
%** Created by:                                                                         **;
%**     Yue Zhou (2017)                                                                 **;
%*****************************************************************************************;


%macro IssAnalysis();

	%** Macro variables **;
	%global
	USUBJIDVar TRTPVar AEBODSYSVar ASTDYVar AESEVVar	 STUDYIDVar AEDECODVar AESERVar 
	AESTDYVar	 ASEVVar ASTDTVar 	ARMVar TRTSDTVar   ADYVar   InputAe InputSl InputVs
    ID 	Time 	Severity Adverse_Event Treatment Body	 TEAE Study max_ae Analysis_day
	LSTVSTDTVar FirstTreatDay LastTreatDay 	min_ob		 cutoff 	TimeStartAtZero ARM
	Nda_Number 	StudyId OutputFolder  UserName 	ProfileName	 SupplementNum ResultFolder 
    Submission Supplement StudyCode  foldername	  subfoldername	level0   level1  level2 
	level3 level4 level5	ADAE ADSL SummaryFolder geomean ClinicalDose;
 

 
	%** Save into global macro variables **;
	data _null_;
		set websvc.IssMappingSAS;
		if upcase(Source)="ADAE" and upcase(ISS_Variable)="USUBJID" then call symputx("USUBJIDVar",File_Variable,"G");
		if upcase(Source)="ADAE" and upcase(ISS_Variable)="TRTA" then call symputx("TRTPVar",File_Variable,"G");
		if upcase(Source)="ADAE" and upcase(ISS_Variable)="AEBODSYS" then call symputx("AEBODSYSVar",File_Variable,"G");
		if upcase(Source)="ADAE" and upcase(ISS_Variable)="ASTDY" then call symputx("ASTDYVar",File_Variable,"G");
		if upcase(Source)="ADAE" and upcase(ISS_Variable)="AESEV" then call symputx("AESEVVar",File_Variable,"G");
		if upcase(Source)="ADAE" and upcase(ISS_Variable)="STUDYID" then call symputx("STUDYIDVar",File_Variable,"G");
		if upcase(Source)="ADAE" and upcase(ISS_Variable)="AEDECOD" then call symputx("AEDECODVar",File_Variable,"G");
		if upcase(Source)="ADAE" and upcase(ISS_Variable)="AESER" then call symputx("AESERVar",File_Variable,"G");
		if upcase(Source)="ADAE" and upcase(ISS_Variable)="AESTDY" then call symputx("AESTDYVar",File_Variable,"G");
		if upcase(Source)="ADAE" and upcase(ISS_Variable)="ASEV" then call symputx("ASEVVar",File_Variable,"G");
		if upcase(Source)="ADAE" and upcase(ISS_Variable)="ASTDT" then call symputx("ASTDTVar",File_Variable,"G");
		if upcase(Source)="ADSL" and upcase(ISS_Variable)="ARM" then call symputx("ARMVar",File_Variable,"G");
		if upcase(Source)="ADSL" and upcase(ISS_Variable)="TRTSDT" then call symputx("TRTSDTVar",File_Variable,"G");
		if upcase(Source)="ADSL" and upcase(ISS_Variable)="LSTVSTDT" then call symputx("LSTVSTDTVar",File_Variable,"G");
		if upcase(Source)="ADVS" and upcase(ISS_Variable)="ADY" then call symputx("ADYVar",File_Variable,"G");
		if upcase(Source)="ADAE"  then call symputx("InputAe",Path,"G");
		if upcase(Source)="ADSL"  then call symputx("InputSl",Path,"G");
		if upcase(Source)="ADVS"  then call symputx("InputVs",Path,"G");

	run;





	%** Debug **;
	%put InputAe=&InputAe;
	%put InputSl=&InputSl;
	%put InputVs=&InputVs;
	%put USUBJIDVar = &USUBJIDVar.; 
	%put TRTPVar=&TRTPVar.;
	%put ArmVar = &ArmVar.; 
	%put AEBODSYSVar = &AEBODSYSVar.; 
	%put ASTDYVar = &ASTDYVar.; 
	%put AESEVVar = &AESEVVar.; 
	%put STUDYIDVar = &STUDYIDVar.; 
	%put AEDECODVar = &AEDECODVar.; 
	%put AESERVar = &AESERVar.;
	%put AESTDYVar = &AESTDYVar.;
	%put ASEVVar = &ASEVVar.;
	%put ASTDTVar = &ASTDTVar.; 
	%put TRTSDTVar = &TRTSDTVar.;
	%put LSTVSTDTVar=&LSTVSTDTVar.; 
	%put ADYVar = &ADYVar.; 

	
        %*********************************************;
        %**             Map Demographic             **;
        %*********************************************;
%let inputfolder=\\localhost\clinical\;

	%if  &InputAe. ne  %then %do;
	libname input1 xport "&inputfolder/&InputAe" access=readonly;
	proc copy inlib=input1 outlib=user;
	run; 
	%end;
	%if  &InputSl. ne  %then %do;

	libname input1 xport "&inputfolder/&InputSl" access=readonly;
	proc copy inlib=input1 outlib=user;
	run; 

	%end;

	%if  &InputVs. ne  %then %do;

 	libname input1 xport "&inputfolder/&InputVs" access=readonly;
	proc copy inlib=input1 outlib=user;
	run; 
	%end;


 	data &work.TRTPS;
		set websvc.TRTPs;
	RUN;
/*LET NUMERICDOSE HAS SAME LEVEL AT THE SAME ORDER*/
data TRTPS;
set TRTPS;
where not missing(trtp);
run;

proc sort data=TRTPS ;
by order descending numericdose;
run;
proc sort data=TRTPS nodupkey out=uni_order;
by order;
run;
data single_order;
set uni_order nobs=nobs;
call symput("nobsorder",nobs);
run;

%put nobs=&nobsorder;
%macro uni_order;

%do i=1 %to &nobsorder;
	%global order&i.;
	data _null_;set uni_order;
	if _n_=&i then do;
	call symput("order&i",trim(order));
	call symput("Numericdose&i",trim(Numericdose));
	PUT order=;STOP;end;run;

	data uni_order&i;
	set TRTPS;where order=&&order&i.;Numericdose=&&Numericdose&i.;
	run;
	%put order&i=&&order&i.;
	%put numericdose=&&numericdose&i.;
%end;

data TRTPS;
set  
%do i=1 %to &nobsorder;
	uni_order&i 
%end;;
 
run;
%mend;
%uni_order;


%***********************************;
%*  Define Global Variable        **;
%***********************************;
*set AE start day by user;
%if &ASTDYVar. ne %then %do;%let Time = &ASTDYVar.;%end;
%else %do;%let Time=&AESTDYVar.;%end;

*set severity by user selection;
%if &AESEVVar. ne %then %do; %let Severity = &AESEVVar.; %end;
%else  %do;%let Severity = &ASEVVar.;  %end;

*set treatment by user;
%if  &TRTPVar. ne %then %do; %let Treatment = &TRTPVar.; %end;
%else %do; %let Treatment = &ARMVar.; %end;

%let Study = &STUDYIDVar.; 
%let ID = &USUBJIDVar.; 
%let Adverse_Event = &AEDECODVar.;
%let TEAE = &AESERVar.;
%let BODY=&AEBODSYSVar.;
%let LastTreatDay=&LSTVSTDTVar.;
%let FirstTreatDay =&TRTSDTVar.; 
%let ARM=&ARMVar.;
%let ADAE=ADAE;
%let ADSL=ADSL;

%put Study = &STUDY.; 
%put ID = &ID.; 
%put Time = &Time.;
%put Severity = &Severity.; 
%put Adverse_Event = &Adverse_Event.; 
%put Treatment = &Treatment.; 
%put TEAE = &TEAE.;
%put BODY=&AEBODSYSVar.;
%put LastTreatDay=&LSTVSTDTVar.;
%put FirstTreatDay =&TRTSDTVar.;

%*Get the variable type of severity*;

%global severlevel;
DATA _NULL_;
SET adae;
call symput("severlevel",vtype(&severity));
run;
%put severlevel=&severlevel;




/*Get the conditional criteria for adae and adsl;*/
 	data &work.IssInOutStep2;
		set websvc.IssInOutStep2;
	RUN;
%IssConditionSelect;

%*****************************************;
%* keep user selected value of treatment *;
%*****************************************;

%IssReorderTrtp;

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
proc sort data=trtp_up3;
by &treatment;
run;

data studys;
SET trtp_up3;
IF INCLUDESTUDY="true" OR INCLUDESTUDY="TRUE";
drop studyduration  revisedtrtp;
ARM=UPCASE(ARM);
rename ARM=&ARM;
RUN;
Proc sort data=studys nodupkey;
by studyid &TREATMENT &arm;
run;


proc sort data=&ADSL out=adsl1;by &Study &ID; run;
data adsl_new;set adsl1; stu=put(STUDYID,25.); DROP STUDYID; RENAME STU=STUDYID; run; 

/**get updated id in adsl***/
data unidbysl;
set adsl_new ;
keep &id;
run;
/**subset adae by id got from adsl****/
proc sql;
create table &adae._sub1 as 
select *
from unidbysl
inner join &adae
on unidbysl.&id.=&adae..&id. ;
quit;


DATA &work.TRTXXP;
SET websvc.TRTXXP ;
WHERE SELECTION="TRUE";
KEEP TRTXXP;
RUN;

%MACRO TRTXXP_EXIST();
*check number of trtxxp in trtxxp table;
%let dsid = %sysfunc( open(&work.TRTXXP) );
%let nobs = %sysfunc( attrn(&dsid,nobs) );
%let rc = %sysfunc(close(&dsid));
*when at least one trtxxp exists then count the number of subjects;
%if &nobs NE 0 %then %do ;
	%macro ADAETRTP();
	DATA _NULL_;
	SET &work.TRTXXP NOBS=NOBS;
	CALL SYMPUT("NOBS",NOBS);
	PUT NOBS=;
	RUN;

	%macro TRTXXP;
	%do i=1 %to &NOBS;
			data _null_ ; set &work.TRTXXP;
				if _n_=&i then do; 
				call symput("TRT&i.P", TRTXXP); 
				output ;stop; end; 
			run;

		%PUT TRTXXP=&&TRT&i.P;

		data &work.adsl_&i.;
		set &work.adsl_new;
		keep &Study &ID &FirstTreatDay. &LastTreatDay. &&TRT&i.P INCLUDESTUDY &ARM;
		rename &&TRT&i.P=TRTXXP;
		&ARM=UPCASE(&ARM);
		run;

		proc sort data=&work.adsl_new;by &Study &ID ;run;
		proc sort data=&work.adsl_&i.;by &Study &ID ;run;


	%end;
	data &work.adsl_new;
	SET 
	%do i=1 %to &NOBS;
	&work.adsl_&i. %END;
	;
	by  &Study &ID ;
	run;

	proc sort data=&work.adsl_new nodupkey out=adsl3;
	by &Study &ID TRTXXP;
	where not missing(TRTXXP);
	run;
	data adsl4;
	set adsl3;
	TRTXXP=UPCASE(TRTXXP);
	&TREATMENT.=UPCASE(TRTXXP);
	run;
	%mend;
	%TRTXXP;
	PROC SORT DATA=ADSL4;
	BY &STUDY &TREATMENT &ARM;
	RUN;
	PROC SORT DATA=STUDYS;
	BY &STUDY &TREATMENT &ARM;
	RUN;
	DATA ADSL4;
	MERGE ADSL4 STUDYS;
	BY &STUDY &TREATMENT &ARM;
	RUN;
	DATA ADSL4;
	SET ADSL4 ;
	IF INCLUDESTUDY="true" OR INCLUDESTUDY="TRUE";
	RUN;

	*when treatment exists then it might from adae or adsl;
	%if &Treatment. ne %then %do;
	%macro TREATFROM();
	%if &TRTPVar. ne %then %do;

		*Get the count of unique subject id of different treatments in each study*;
		proc sql; 
		create table NOB as																	 
		select*, 
		count(distinct &ID) as N_OB 
		from ADSL4
		group by &Study, Order; 
		quit; 
		*Get the count of unique subject id of different pooled treatments*;
		proc sql; 
		create table NOBS as																	 
		select*, 
		count(distinct &ID) as N_OB_ALL 
		from NOB
		group by  Order; 
		quit; 

		proc sort data=&adae._sub1 out=adae_1;by &Study &ID; run;
		data adae_1;set adae_1; stu=put(STUDYID,25.); DROP STUDYID; RENAME STU=STUDYID;&treatment.=upcase(&treatment.); run; 
		proc sort data=adae_1;
		by &study &treatment;
		data adae1;
		merge adae_1 studys;
		by &study &TREATMENT;
		run;
		data adae1;
		set adae1;
		IF INCLUDESTUDY="true" OR INCLUDESTUDY="TRUE";
		RUN;

		data ADAE1;
		set adae1;
		keep &Study &ID &Time &Severity &Adverse_Event &Treatment TRTXXP &TEAE  &BODY INCLUDESTUDY ;
		TRTXXP=&Treatment;
		run;
		PROC SORT DATA=NOBS;
		BY &Study &ID TRTXXP;
		RUN;
		proc sort data=ADAE1;
		by &Study &ID  TRTXXP;
		run;
		*REMOVE BY TRTXXP, ALL ID CAN GET FIRST AND LAST TREAT DAY;
		data AE_SL1;												 
		merge ADAE1 NOBS ;
		by &Study &id TRTXXP;
		keep &Study &ID &Time &Severity &Adverse_Event &Treatment TRTXXP &FirstTreatDay. &LastTreatDay.  &TEAE  &BODY  INCLUDESTUDY;
		run;
		data new_ob;
		set nobs;
		keep &study trtxxp n_ob n_ob_all;
		run;
		proc sort data=new_ob nodupkey;
		by &study trtxxp n_ob n_ob_all;
		run;
		Proc sort data=ae_sl1;by &study trtxxp;
		run;

		data ae_sl;
		merge ae_sl1 new_ob;
		by &study trtxxp;
		run;

	%end;
	%else %if &TRTPVar. eq and &ARMVar. ne %then %do;
		proc sql; *****Treatment is from ADSL*****;
		create table NOB as																	 
		select*, 
		count(distinct &ID) as N_OB 
		from ADSL4
		group by &Study, Order; 
		quit; 
		*Get the count of unique subject id of different pooled treatments*;
		proc sql; 
		create table NOBS as																	 
		select*, 
		count(distinct &ID) as N_OB_ALL 
		from NOB
		group by  Order; 
		quit; 

		*If Treatment is mising in ADAE, Then the default value of treatment is numerical. So, change it to character value;

		data ADAE1;
		set &adae._sub1;
		keep &Study &ID &Time &Severity &Adverse_Event &TEAE  &BODY    ;
		run;
		PROC SORT DATA=NOBS;
		BY &Study &ID TRTXXP;
		RUN;
		proc sort data=ADAE1;
		by &Study &ID  ;
		run;
		data SL_TRTP;
		set &ADSL;
		keep &Study &ID &treatment ;
		run;
		data SL_TRTPXP;
		merge NOBS SL_TRTP;
		by &Study &ID;
		run;
		data SL_TRTPXP;set SL_TRTPXP; where TRTXXP=upcase(&Treatment);run;
		data AE_SL;												 
		merge ADAE1 SL_TRTPXP ;
		by &Study &ID;
		keep &Study &ID &Time &Severity &Adverse_Event &Treatment trt TRTXXP &FirstTreatDay. &LastTreatDay.  INCLUDESTUDY   order  &TEAE  &BODY N_OB N_OB_ALL;
		run;

		proc sort data=AE_SL nodupkey out=AE_SL;
		by &Study &ID TRTXXP &Time &Severity &Adverse_Event ;
		run;
	%end;
	%mend;%TREATFROM;

	%if &time ne %then %do;

		%if &LastTreatDay. ne and &FirstTreatDay. ne %then %do;
			data GETLENGTH1;
			set AE_SL;
			Duration=&LastTreatDay.-&FirstTreatDay. +1;
			run;
			proc sql; 
			create table GETLENGTH2 as																	 
			select*, 
			max(Duration, &time) as max_duration
			from GETLENGTH1
			group by &Study, &ID; 
			quit;
		%end;
		%else %do;
			data GETLENGTH1;
			set AE_SL;
			run;
			proc sql; 
			create table GETLENGTH2 as																	 
			select*, 
			max(&time) as max_duration
			from GETLENGTH1
			group by &Study, &ID; 
			quit;
		%end;
	%end;
	%if &time EQ %then %do;
		%if &LastTreatDay. ne and &FirstTreatDay. ne %then %do;
		data GETLENGTH1;
		set AE_SL;
		Duration=&LastTreatDay.-&FirstTreatDay. +1;
		run;
		proc sql; 
		create table GETLENGTH2 as																	 
		select*, 
		max(Duration) as max_duration
		from GETLENGTH1
		group by &Study, &ID; 
		quit;%end;
	%END;
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
	MAX(max_duration) AS max_LENGTH 
	from GETLENGTH3
	;quit; 

	data ae_check ;
	set GETLENGTH4;
	*where not missing(LENGTH);
	&Treatment.=upcase(&Treatment.);
	TRTXXP=upcase(TRTXXP);
	Drop INCLUDESTUDY;
	where n_ob_all>0;
	run;
	%end;

	%mend;%ADAETRTP;
%end;
%else  %IF &nobs Eq 0 AND &TREATMENT=&ARMVar %then %do;
	proc sort data=adsl_new nodupkey out=adsl3;
	by &Study &ID &treatment;
	keep &Study &ID &treatment &FirstTreatDay. &LastTreatDay.   N_OB N_OB_ALL  ;
	run;
	data adsl4;
	set adsl3;
	IF INCLUDESTUDY="true" OR INCLUDESTUDY="TRUE";
	run;
	proc sql; 
	create table NOB as																	 
	select*, 
	count(distinct &ID) as N_OB 
	from ADSL4
	group by &Study, Order; 
	quit; 
	*Get the count of unique subject id of different pooled treatments*;
	proc sql; 
	create table NOBS as																	 
	select*, 
	count(distinct &ID) as N_OB_ALL 
	from NOB
	group by  Order; 
	quit; 
	proc sort data=ADAE1;
	by &Study &ID  ;
	run;
	proc sort data=NOBS;
	by &Study &ID  ;
	run;

	data AE_SL;												 
	merge ADAE1 NOBS ;
	by &Study &ID;
	keep &Study &ID &Time &Severity &Adverse_Event &Treatment  &FirstTreatDay. &LastTreatDay. &TEAE  &BODY N_OB N_OB_ALL   ;
	run;
	PROC SORT data=AE_SL NODUPKEY;
	BY  &Study &ID &Treatment  &Adverse_Event   &Time ;
	RUN;
	*calculate the length of study;
	%if &LastTreatDay. ne and &FirstTreatDay. ne %then %do;
		data GETLENGTH1;
		set AE_SL;
		Duration=&LastTreatDay.-&FirstTreatDay. +1;
		run;
		proc sql; 
		create table GETLENGTH2 as																	 
		select*, 
		max(Duration, &time) as max_duration
		from GETLENGTH1
		group by &Study, &ID; 
		quit;
	%end;
	%else %do;
		data GETLENGTH1;
		set AE_SL;
		run;
		proc sql; 
		create table GETLENGTH2 as																	 
		select*, 
		max(&time) as max_duration
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
	MAX(max_duration) AS max_LENGTH 
	from GETLENGTH3
	;quit; 

	data ae_check ;
	set GETLENGTH4;
	&Treatment.=upcase(&Treatment.);
	TRTXXP=upcase(TRTXXP);
	Drop INCLUDESTUDY;
	where n_ob_all>0;
	run;

%END;
%MEND;
%TRTXXP_EXIST;



********************************************************************************;
*5. Additional Options								****************************;
********************************************************************************;
 
%let min_ob = 1;*set minimum AE observations in the Plot of "Timecourse of AE by Dose".;
%Let TimeStartAtZero="yes"; *If yes, X axis will start at day=0, or start at the lowest points;

*******************************************************************;
%let level0=NONE;
%let level1=MILD;     *Define lowest severity level;
%let level2=MODERATE; *Define middle severity level;
%let level3=SEVERE;   *Define highest severity level;
%let level4=LIFE-THREATENING;
%let level5=DEATH;

*******************************************************************;
%Let AE_of_interest="no";
%Let Analysis_day=&ADYVar.; *Analysis Relative Day;
*******************************************************************;


%IssAnalysisDataReset;


	data &work.userData;
		set websvc.userConfig end = eof;
	if Name="Username" then 
		call symputx("UserName", dequote(value), "G");
	if Name="ProfileName" then 
		call symputx("ProfileName", dequote(value), "G");
	run;

	%** Debug **;
	%put User: &UserName.;
	%put Settings Id: &ProfileName.;


         data study ;        
	        set websvc.study  end=eof;
	if eof then do;
            call symputx("Submission", Submission);
			call symputx("Supplement", dequote(Supplement), "G");
			call symputx("StudyCode", StudyCode);
			call symputx("folderName",folderName);
		end;
 	run;
	data _null_;
 		set study;
 		SupplementNum=put(input(Supplement,best32.),z4.);
		Call Symputx("SupplementNum",SupplementNum);
	run;

    %put SupplementNum=&SupplementNum.;   

    %put Submission=&Submission;
    %put Studycode=&StudyCode;

%let Nda_Number=&Submission.;
%put Nda_number=&Nda_Number.;
%put StudyId=&StudyCode.;
%put foldername=&folderName.;
%let subfoldername=Safety Analysis;
%put subfoldername=&subfoldername.;




/* Generate output path based on NDA Id, User Id and settings Id */
%let OutputFolder = &SasSpPath.\Output Files\PKView\&UserName.\&ProfileName.\&nda_number.\&SupplementNum.\ISS\&folderName\&subfoldername.;
%put OutputFolder=&OutputFolder;
%IssRemoveDir(&OutputFolder);
	%SmCheckAndCreateFolder(
        BasePath = &SasSpPath.\Output Files\PKView,
        FolderName =  &UserName.
    );
    %SmCheckAndCreateFolder( 
        BasePath = &SasSpPath.\Output Files\PKView\&UserName.,
        FolderName = &ProfileName.
    );
    %SmCheckAndCreateFolder(
        BasePath = &SasSpPath.\Output Files\PKView\&UserName.\&ProfileName.,
        FolderName = &nda_number.
    );
    
    %SmCheckAndCreateFolder(
        BasePath = &SasSpPath.\Output Files\PKView\&UserName.\&ProfileName.\&nda_number.,
        FolderName = &SupplementNum.
    );
    %SmCheckAndCreateFolder(
        BasePath = &SasSpPath.\Output Files\PKView\&UserName.\&ProfileName.\&nda_number.\&SupplementNum.,
        FolderName = ISS
    );
    %SmCheckAndCreateFolder(
        BasePath = &SasSpPath.\Output Files\PKView\&UserName.\&ProfileName.\&nda_number.\&SupplementNum.\ISS,
        FolderName = &folderName.
    );
	%SmCheckAndCreateFolder(
        BasePath = &SasSpPath.\Output Files\PKView\&UserName.\&ProfileName.\&nda_number.\&SupplementNum.\ISS\&folderName.,
        FolderName = &subfoldername.
        );


	data _null_;
 		set study;
		Call Symputx("CumulativeAePooled",CumulativeAePooled);
		Call Symputx("CumulativeAeIndividual",CumulativeAeIndividual);
		Call Symputx("DoseResponse",DoseResponse);
		Call Symputx("DosingRecord",DosingRecord);
		Call Symputx("PkSafetyDdi",PkSafetyDdi);
		Call Symputx("ClinicalDose ",ClinicalDose );

	run;
    %put CumulativeAePooled=&CumulativeAePooled.;   
    %put CumulativeAeIndividual=&CumulativeAeIndividual.;   
    %put IssBarchartPerAe=&DoseResponse.;   
    %put IssDoseBarchart=&DosingRecord.; 
    %put PkSafetyDdi=&PkSafetyDdi.; 
    %put ClinicalDose=&ClinicalDose.; 


%if &severity. ne %then %do;
%IF &DoseResponse=true %THEN %DO;
	%IssBarchartPerAe;
%END;

%Iss3DBarchart;
%end;

%if  &InputVs. ne  %then %do;
%IF &DosingRecord=true %THEN %DO;
	%IssDoseBarchart;
%END;
%end; 


%IF &CumulativeAeIndividual=true %THEN %DO;
	%IssScatterAeIndividual;
%END;



%IF &CumulativeAePooled=true %THEN %DO;
	%IssScatterAePooled;
%END;

%if &severity. ne %then %do;
%IF &PkSafetyDdi=true %THEN %DO;
%IssSummary3Plot;
%END;
%end;

%mend;
