%macro IssScatterAeIndividual();
data ae11;
length AEDECOD_NEW $ 36;
	set ae10 ;
		z=translate(&Adverse_Event,"",",");
		y=translate(Z,"","'");
		x=translate(y,"","-");
		AEDECOD_NEW=(translate(trim(x),"_"," "));
		Study_NEW= translate(trim(&STUDY),"_","-");
RUN;

/**********************************************************************/
*create macro variable study_count which is the count of variable Study;
/**********************************************************************/
Proc Sql noprint;
	select  count(distinct(Study_NEW)) into :Study_COUNT
	from ae11;
quit;

/******************************************************/
*Create new dataset with unique value of Study_new;
/******************************************************/
data ae12; 
	set ae11(keep=study_new ); 
run;
proc sort data=ae12 noduprecs  out=aeuo;
	by study_new ;
run;
/**Check and Create folder and delete plots in the folder*/
%put OutputFolder=&OutputFolder.;

        %SmCheckAndCreateFolder(
        BasePath = &OutputFolder.,
        FolderName = Cumulative_AE
        );
        %SmCheckAndCreateFolder(
        BasePath = &OutputFolder.\Cumulative_AE,
        FolderName = bystudy
        );
/**************************************************************************************************/
*Use loop define each study_new into macro variable study_new;
*Each iteration creates a new dataset by study_new aedecod_new to generate plots;
/**************************************************************************************************/

%macro bystudy;
	%do j=1 %to &study_count;
		data _null_ ; set aeuo;
			if _n_=&j then do; 
			call symput("study_new", study_new); 
			put study_new=;output ;stop; end; 
		run;

		data aa; set ae11;
			where  compress(study_new) = compress("&study_new."); 
		run;



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
		
		
	%macro databyae;
		%do i=1 %to &nobs1;
			data _null_; 
				set aa1; 
				if _n_=&i then do; 
				call symput("AEDECOD_NEW", AEDECOD_NEW); output;
				put AEDECOD_NEW=;stop; end;
			run;

			proc sort data=aa;
				by Study_new AEDECOD_NEW; 
			run;

			data new_ae10; 
				set aa; 
				where compress(AEDECOD_NEW)=compress("&AEDECOD_NEW.") and count_AE>=&min_ob;
			run;
			ods _all_ close;



        options nodate nonumber;
        ods listing gpath = " &OutputFolder.\Cumulative_AE\bystudy";		
		ods graphics on/antialiasmax=5000  imagename=" &AEDECOD_NEW. " imagefmt=png border=off width=8in height=6in  LABELMAX=200;

		proc sgplot data=new_ae10; by Study_new AEDECOD_NEW;where count_AE>=&min_ob ;
		title"Timecourse of AEs by dose";
		scatter x=&Time y=sum_rate /group=trt name="scatter" markerattrs=(symbol=CircleFilled size=9);
		series x=&Time y=sum_rate /group=trt lineattrs=(pattern=1 thickness=2);
		label &Time="Study Day" sum_rate="Cumulative AE rate" ;
		keylegend "scatter"/ACROSS=1 DOWN=20  ;

		run; 

		%end;
	%mend;
	
			
	
	%databyae; 
/*Send the time percentage to GUI*/		
%if &j.=%sysfunc(round(&study_count./2)) %then %do;
        %Log(
        Progress = 55,
        TextFeedback = Generating the output for Submission &Nda_number.
    );

	%put j=&j.;
	%put median=%sysfunc(round(&study_count./2));
	%put total=&study_count.;

%end;	

  
	%end;
	

%mend;



%bystudy;

/*Send the time percentage to GUI*/		
        %Log(
        Progress = 70,
        TextFeedback = Generating the output for Submission &Nda_number.
    );


 %mend;