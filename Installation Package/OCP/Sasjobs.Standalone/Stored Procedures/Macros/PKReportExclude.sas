%macro PKReportExclude;



/* Read mappings from websvc input dataset (provided by C#) */
/*%SmReadMappingsFromDataSet();*/


/* Read report settings from websvc input dataset (provided by C#) */
/*%SmReadReportSettingsFromDataSet();*/

%PKExcludeSub;

/* Retrieve NDA Id */
%let Nda_Number=&SubmissionId.;

/* Generate output path based on NDA Id, User Id and settings Id */
%let OutputFolder = &SasSpPath.\Output Files\PKView\&UserName.\&ProfileName.\&nda_number.\&SupplementNum;
libname pkOutput "&OutputFolder.";
/* Locate and load estimates file */
%let EstimatesPath = &OutputFolder.\&StudyId.\estimates;
libname result "&EstimatesPath"; /*generate result.estimates*/  

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
%put meng globaled resultfolder: &ResultFolder;

/*output excludedsubject into customized folder*/

%if %sysfunc(exist(excludesubject)) and &obsnum ne 0 %then %do;

  
    %SmCheckAndCreateFolder(
    BasePath = &OutputFolder.\&StudyId.,
    FolderName = &ReportFolder
    );

    %let ResultFolder = &OutputFolder.\&StudyId.\&ReportFolder;
    ods csv file= "&ResultFolder.\ExcludedSubjects.csv" ;
    proc print data=&work.excludesubject;
    run;
    ods csv close;
    %put meng got exclude subejcts and output;

%end;
%else %do;
    %put meng got no subject excluded;
%end;

/*ends*/



proc sql noprint;
select count(*) into :obscount from result.individualpkstats;
quit;
%put 1st: obscount=&obscount;


data result.IndividualPkStats;
set result.IndividualPkStats;
OrgPPSTRESN=exp(PPSTRESN);
run;



data _null_;
set websvc.excludesubject;
call symput("times1",SMALLTHANEXCLUDESD);
call symput("times2",BIGTHANEXCLUDESD);
call symput("p1",ExcludeParameters1);
call symput("p2",ExcludeParameters2);
call symput("percent",percent);
run;
%put SMALLTHANEXCLUDESD=&times1;
%put BIGTHANEXCLUDESD=&times2;
%put excludeparameters1=&p1;
%put excludeparameters=&p2;
%put percent=&percent;

/*to directly click statistical report button without clicking exclude subject button first if there is no subject to exclude*/

%if &p1 eq  and &p2 eq and &percent eq 0 and &times1 eq 0 and &times2 eq 0 %then %do;
data result.removedinput;
set result.IndividualPkStats;
run;
%put meng got no subject to be excluded;
%end;

%else %do;
%put meng got some subjects to be excluded;
%end;


proc sql noprint;
select count(*) into :obscount from result.individualpkstats;
quit;
%put 2nd: obscount=&obscount;



/*%if %upcase(&StudyDesign.) ne UNKNOWN and &PeriodPpVar. ne and &SequenceVar. ne */
/*        and &AnalytePpVar. ne and &ParameterVar. ne %then %do;*/
/*        %SmPrepareDataForAnalysisNew(*/
/*                Input = result.IndividualPkStats,*/
/*                SequenceVar = &SequenceVar.,*/
/*                AnalyteVar = &AnalytePpVar.,*/
/*                ParameterVar = &ParameterVar.,*/
/*                PeriodVar = &PeriodPpVar.,*/
/*                ResultVar = &ResultPpVar.,*/
/*                ExData = &work.adex,*/
/*                %if %SYMEXIST(ExTrtVar) %then %do;*/
/*                  ExTrtVar = &ExTrtVar.,*/
/*                %end;*/
/*                %if %SYMEXIST(ExDateVar) %then %do;*/
/*                  ExDateVar = &ExDateVar.,*/
/*                %end;*/
/*                ExPeriodVar = &PeriodExVar.,*/
/*                Type = pp,*/
/*                StudyArea = &StudyType.,*/
/*                StudyDesign = &StudyDesign.*/
/*        );*/
/*%end;*/

proc sql noprint;
select count(*) into :obscount from result.individualpkstats;
quit;
%put 3rd: obscount=&obscount;


/*STEP2: rerun pk summary model and generate estimates only*/
%macro PK_Analysis_Summary_ExcludeSub(
    Input = ,
    AnalyteVar = ,
    ParameterVar = ,
    ResultVar = ,
    PeriodVar = ,
    UsubjidVar = ,
    SequenceVar = ,
    StudyDesign = ,                                                            
    StudyId = , 
    OutputFolder = 
);


%** Get the different Periods and Sequences **;
proc sort data =result.individualpkstats(keep = &SequenceVar.)
            out = PKStatsSequences nodupkey;
    by &SequenceVar.;
run;

%** Find the number of unique sequences **;
proc sql noprint;
    select distinct
        &SequenceVar.
    into:
        SequenceList separated by "~!~"
    from
        PKStatsSequences
    ;
quit;
%put SequenceList = &SequenceList.;
%let NumberOfSequences = %sysfunc(countw(%nrbquote(&SequenceList.), ~!~));

%** Debug **;
%put Number of Sequences = &NumberOfSequences.;



%** Find the maximum number of periods within each cohort **;

proc sort data =result.individualpkstats(keep = &SequenceVar. &PeriodppVar.)
            out = PKStatsPeriods nodupkey;
    by &SequenceVar. &PeriodppVar.;
run;

data &work._null_;
    set PKStatsPeriods end = eof;
    by &SequenceVar. &PeriodppVar.;
    retain MinNumberOfPeriods MaxNumberOfPeriods counter;

    %** Initialize **;
    if _n_ = 1 then do;
        MaxNumberOfPeriods = 0;
        MinNumberOfPeriods = 99;
    end;
    if first.&SequenceVar. then do;
        counter = 0;
    end;
        
    %** Count and compare **;
    counter + 1;
    if last.&SequenceVar. then do;
        if MaxNumberOfPeriods < counter then do;
            MaxNumberOfPeriods = counter;
        end;
        if MinNumberOfPeriods > counter then do;
            MinNumberOfPeriods = counter;
        end;
    end;

    %** Create the macro variable **;
    if eof then do;
        call symputx("MaxNumberOfPeriods", MaxNumberOfPeriods);
        call symputx("MinNumberOfPeriods", MinNumberOfPeriods);
    end;
run;
%** Debug **;
%put Maximum number of Periods = &MaxNumberOfPeriods.;
%put Minimum number of Periods = &MinNumberOfPeriods.;



%** Cross-over **;
%if %upcase(&StudyDesign.) = CROSSOVER and &MaxNumberOfPeriods. <= 2 %then %do;

    /*remove the observations with missing combination or treatmentinperiod*/
   
    proc sort data = &Input.;
        by CohortNumber CohortName CohortDescription &ParameterVar. &AnalyteVar. Combination TreatmentInPeriod;
    run;

    proc mixed data = &Input.;
        by CohortNumber CohortName CohortDescription &ParameterVar. &AnalyteVar. Combination;
        class &UsubjidVar. &SequenceVar. &PeriodVar. TreatmentInPeriod;
        model &ResultVar. = &SequenceVar. &PeriodVar. TreatmentInPeriod / ddfm = kenwardroger;
        random &UsubjidVar. (&SequenceVar.);
        lsmeans TreatmentInPeriod / pdiff cl alpha = 0.1;
        estimate 'DDI Effect' TreatmentInPeriod -1 1 / cl alpha = 0.1;
        estimate 'DDI Effect Inv' TreatmentInPeriod 1 -1 / cl alpha = 0.1;
        ods output Estimates = &work.estimates_unpaired;
    run;

    proc mixed data = &Input.;
        by CohortNumber CohortName CohortDescription &ParameterVar. &AnalyteVar. Combination;
        class &UsubjidVar. TreatmentInPeriod;
        model &ResultVar. = TreatmentInPeriod / ddfm = kenwardroger;
        /* fixme random &UsubjidVar.; */
        random &UsubjidVar. ;
        lsmeans TreatmentInPeriod / pdiff cl alpha = 0.1;
        estimate 'DDI Effect' TreatmentInPeriod -1 1 / cl alpha = 0.1;
        estimate 'DDI Effect Inv' TreatmentInPeriod 1 -1 / cl alpha = 0.1;
        ods output Estimates = &work.estimates_paired;
    run;

    data &work.estimates;
        set &work.estimates_unpaired (in = a)
            &work.estimates_paired (in = b)
        ;
        
        %** Estimation type **;
        if a then do;
            EstType = "unpaired";
        end;
        else if b then do;
            EstType = "paired  ";
        end;
    run;

%end;

%else %if %upcase(&StudyDesign.) = CROSSOVER %then %do;
    /**%else %if &MaxNumberOfPeriods. > 2 and &NumberOfSequences. > 1 and %upcase(&StudyDesign.) ^= PARALLEL %then %do;*/
    %put I am here!;
    proc sort data = &Input.;
        by CohortNumber CohortName CohortDescription &ParameterVar. &AnalyteVar. Combination TreatmentInPeriod;
    run;

    %put Periods = &MaxNumberOfPeriods.;
    %put Sequences = &NumberOfSequences.;
    %put PeriodVar = &PeriodVar.;
    %*return;
    %** Special case for 3 period 2 arm groups - used due to misaligned treatments within the periods **;
    %** FIXME: needs to be improved a lot - currently &work.s somewhat but the control of references is off **;
    %if &MaxNumberOfPeriods. >= 3 and &NumberOfSequences. = 2 %then %do;
        proc sql noprint;
            select
                distinct &ParameterVar.
            into:
                param_list separated by "@"
            from
                &Input.
            ;

            select
                distinct &AnalyteVar.
            into:
                analyte_list separated by "@"
            from
                &Input.
            ;
        quit;   

        %** For each group re-calculate the periods **;
        %do p = 1 %to %sysfunc(countw(%nrbquote(&param_list.), "@"));
            %do a = 1 %to %sysfunc(countw(%nrbquote(&analyte_list.), "@")); 
                proc sort data = &Input.(where = (&ParameterVar. = "%scan(%nrbquote(&param_list.), &p., @)" and &AnalyteVar. = "%scan(%nrbquote(&analyte_list.), &a., @)"))
                            out = &Input._&p._&a.;
                    by &SequenceVar. &UsubjidVar. &PeriodVar.;
                run;

                proc sql noprint;
                    select 
                        distinct TreatmentInPeriod
                    into:
                        trt_list separated by "@"
                    from
                        &Input._&p._&a.
                    ;
                quit;

                %** Since this is a 3-way crossover but with only 2 different sequence we encounter the following problem: **;
                %** **;
                *jiaxiang0930;
                data &Input._&p._&a.;set &Input._&p._&a.;length temp $300.;temp=&PeriodVar.;run;
                data &Input._&p._&a.;set &Input._&p._&a.(drop=&PeriodVar.);rename temp=&PeriodVar.;run;
                *jiaxiang0930;

                data &Input._&p._&a.;
                    set &Input._&p._&a.;
                    by &SequenceVar. &UsubjidVar. &PeriodVar.;
                    retain 
                        %do t = 1 %to %sysfunc(countw(%nrbquote(&trt_list.), @));
                            trt&t.n trt&t.
                        %end;
                    ;

                    if first.&SequenceVar. then do;
                        armcnt + 1;
                    end;

                    if first.&UsubjidVar. then do;
                        cnt = 0;
                    end;
                    if first.&PeriodVar. then do;
                        cnt + 1;
                    end;

                    if armcnt = 1 then do;
                        &PeriodVar. = "Period " || strip(cnt);
                        %do t = 1 %to %sysfunc(countw(%nrbquote(&trt_list.), @));
                            if TreatmentInPeriod = "%scan(%nrbquote(&trt_list.), &t., @)" then do;
                                trt&t.n = cnt;
                                trt&t. = "%scan(%nrbquote(&trt_list.), &t., @)";
                            end;
                        %end;
                    end;
                    else if armcnt = 2 then do;
                        if TreatmentInPeriod = "%scan(%nrbquote(&trt_list.), 1, @)" then do;
                            cnt = trt2n;
                        end;
                        else if TreatmentInPeriod = "%scan(%nrbquote(&trt_list.), 2, @)" then do;
                            cnt = trt1n;
                        end;
                        
                        &PeriodVar. = "Period " || strip(cnt);
                    end;
                run;

            %end;
        %end;
        %** Combine **;
        data &Input.;
            set 
                %do p = 1 %to %sysfunc(countw(%nrbquote(&param_list.), "@"));
                    %do a = 1 %to %sysfunc(countw(%nrbquote(&analyte_list.), "@"));
                        &Input._&p._&a.
                    %end;
                %end;
            ;
        run;    

        proc sort data = &Input.;
            by CohortNumber CohortName CohortDescription &ParameterVar. &AnalyteVar. Combination;
        run;

        proc sort data = &Input.;
                by CohortNumber CohortName CohortDescription &ParameterVar. &AnalyteVar. Combination TreatmentInPeriod;
        run;

        ods select Estimates;
        proc mixed data = &Input.;
            by CohortNumber CohortName CohortDescription &ParameterVar. &AnalyteVar. Combination;
            class &UsubjidVar. &SequenceVar. &PeriodVar. TreatmentInPeriod;
            model &ResultVar. = &SequenceVar. &PeriodVar. TreatmentInPeriod / ddfm = kenwardroger;
            *random &UsubjidVar. (TreatmentInPeriod);
            random &UsubjidVar. (&SequenceVar.);
            lsmeans TreatmentInPeriod / pdiff cl alpha = 0.1;
            estimate 'DDI Effect' TreatmentInPeriod -1 1 / cl alpha = 0.1;
            estimate 'DDI Effect Inv' TreatmentInPeriod 1 -1 / cl alpha = 0.1;
            ods output Estimates = &work.estimates_unpaired;
        run;
        %*return;


    %end;
    %else %do;

        /*should have no clean pp*/
        
        proc sort data = &Input.;
                by CohortNumber CohortName CohortDescription &ParameterVar. &AnalyteVar. Combination TreatmentInPeriod;
        run;

        ods select Estimates;
        proc mixed data = &Input.;
            by CohortNumber CohortName CohortDescription &ParameterVar. &AnalyteVar. Combination;
            class &UsubjidVar. &SequenceVar. &PeriodVar. TreatmentInPeriod;
            model &ResultVar. = &SequenceVar. &PeriodVar. TreatmentInPeriod / ddfm = kenwardroger;
            *random &UsubjidVar. (TreatmentInPeriod);
            random &UsubjidVar. (&SequenceVar.);
            lsmeans TreatmentInPeriod / pdiff cl alpha = 0.1;
            estimate 'DDI Effect' TreatmentInPeriod -1 1 / cl alpha = 0.1;
            estimate 'DDI Effect Inv' TreatmentInPeriod 1 -1 / cl alpha = 0.1;
            ods output Estimates = &work.estimates_unpaired;
        run;
        

    %end;
*jiaxiang;

     data &Input.;
     set &Input.;
     if &ResultVar. eq . then delete;
     run;


    proc mixed data = &Input.;
        by CohortNumber CohortName CohortDescription &ParameterVar. &AnalyteVar. Combination;
        class &UsubjidVar. TreatmentInPeriod;
        model &ResultVar. = TreatmentInPeriod / ddfm =  kr;
        /* fixme random &UsubjidVar.; */
        random &UsubjidVar. ;
        lsmeans TreatmentInPeriod / pdiff cl alpha = 0.1;
        estimate 'DDI Effect' TreatmentInPeriod -1 1 / cl alpha = 0.1;
        estimate 'DDI Effect Inv' TreatmentInPeriod 1 -1 / cl alpha = 0.1;
        ods output Estimates = &work.estimates_paired;
    run;

    data &work.estimates;
        set &work.estimates_unpaired (in = a)
            &work.estimates_paired (in = b)
        ;
        
        %** Estimation type **;
        if a then do;
            EstType = "unpaired";
        end;
        else if b then do;
            EstType = "paired  ";
        end;
    run;


%end;
%** Sequential **;
%else %if %upcase(&StudyDesign.) = SEQUENTIAL %then %do;
    proc sort data = &Input.;
        by CohortNumber CohortName CohortDescription &ParameterVar. &AnalyteVar. Combination TreatmentInPeriod;
    run;

    ods select Estimates;
    proc mixed data = &Input.;
        by CohortNumber CohortName CohortDescription &ParameterVar. &AnalyteVar. Combination;
        class &UsubjidVar. &PeriodVar.;
        model &ResultVar. = &PeriodVar. / ddfm = kenwardroger;
        random &UsubjidVar.;
        lsmeans &PeriodVar. / pdiff cl alpha = 0.1;
        estimate 'DDI Effect' &PeriodVar. -1 1 / cl alpha = 0.1;
        estimate 'DDI Effect Inv' &PeriodVar. 1 -1 / cl alpha = 0.1;
        ods output Estimates = &work.estimates;
    run;

    data &work.estimates;
        set  &work.estimates;
        EstType = "paired  ";
    run;

%end;
%** Parallel **;
%else %if %upcase(&StudyDesign.) = PARALLEL %then %do;

/*get reference list from data preparation step*/

%global reference;

%** Is one of the treatment a reference? and how any do we have?**;
proc sort data =result.individualpkstats  out = &work.references nodupkey;
by &SequenceVar.;
run;

data _null_;
set &work.references end = eof;
length reference $200.;
retain reference;

if indexw(upcase(strip(&SequenceVar.)), "HEALTHY") or indexw(upcase(strip(&SequenceVar.)), "NORMAL") or 
indexw(upcase(strip(&SequenceVar.)), "YOUNGER") or indexw(upcase(strip(&SequenceVar.)), "CONTROL") or 
indexw(upcase(strip(&SequenceVar.)), "IV DOSE") or index(upcase(strip(&SequenceVar.)), "HEALTHY") >0
then do;
numref + 1;
if numref = 1 then do;
reference = &SequenceVar.;
end;
else do;
reference = strip(reference) || "@" || &SequenceVar.;
end;
end;

if eof then do;
call symputx("reference", reference);
call symputx("numref", numref);
end;
run;


%put Reference is: &reference.;

%** Did we get any references? **;
%if %symexist(reference) %then %do;
/*%if %nrbquote(&reference.) eq %then %do;*/
proc sql noprint;
select 
distinct &SequenceVar.
into:
reference separated by "@"
from
&work.references
;
quit;
%let numref = %sysfunc(countw(%nrbquote(&reference.), @));
/*%end;*/
%end;

%put meng get reference:&reference;

/*ends*/




    %if %symexist(reference) %then %do;
        %** Do the unpaired analysis **;
        %put test = test;
        %do k = 1 %to %sysfunc(countw(%nrbquote(&Reference.), @));
            %put test&i. = test;

             

            proc sort data = &Input.(where = (upcase(reference) = "%upcase(%scan(%nrbquote(&reference.), &k., @))"))
                        out = &Input._&k.;
                by &SequenceVar.;
            run;


            %** If we have a reference - find out where it is in the order of the data (might not be first) **;
            data _null_;
                set &Input._&k. end = eof;
                by &SequenceVar.;
                length sequence_list $500.;
                retain reference_loc sequence_list hit;

                %** List of sequences **;
                if _n_ = 1 then do;
                    sequence_list = strip(&SequenceVar.);
                end;
                else if first.&SequenceVar. then do;
                    sequence_list = strip(sequence_list) || "@" || strip(&SequenceVar.);
                end;

                %** Location of the reference sequence **;
                if first.&SequenceVar. and not hit then do;
                    reference_loc + 1;
                end;
                else if first.&SequenceVar. and upcase(&SequenceVar.) ne "%upcase(%scan(%nrbquote(&reference.), &k., @))" then do;
                    reference_loc + 1;
                    hit = 1;
                end;

                %** Save to macro variables **;
                if upcase(&SequenceVar.) = "%upcase(%scan(%nrbquote(&reference.), &k., @))" then do;
                    call symputx("reference_loc", reference_loc);
                end;
                if eof then do;
                    call symputx("sequence_list", sequence_list);
                end;
            run;
            %put Reference loc = &reference_loc.;
            %put Sequence list = &sequence_list.;
            
            %** Generate the estimate line for the mixed model (nasty code) **;
            %let estimation_list = ;
            %let contrast_list = ;
            %do i = 1 %to %sysfunc(countw(%nrbquote(&sequence_list.), @));  
                %let number_list = ;
                %do j = 1 %to %sysfunc(countw(%nrbquote(&sequence_list.), @));
                    %if &i. = &j. %then %do;
                        %let number_list = &number_list. 1;
                    %end;
                    %else %if &j. = &reference_loc. %then %do;
                        %let number_list = &number_list. -1;
                    %end;
                    %else %do;
                        %let number_list = &number_list. 0;
                    %end;
                %end;
                %let contrast_list = &contrast_list.@&number_list.;
                %let estimation_list = &estimation_list@%scan(%nrbquote(&sequence_list.), &i., @) / %scan(%nrbquote(&reference.), &k., @);
            %end;
            %put CONTRAST = &contrast_list.;
            %put ESITMAT = &estimation_list.;
            %put ESTIMATION LIST = %sysfunc(countw(%nrbquote(&estimation_list.), @));
            
            %if %nrbquote(&contrast_list.) ne %then %do;
                %** Sort and run the analysis **;
                proc sort data = &Input._&k.;
                    by CohortNumber CohortName CohortDescription Combination &ParameterVar. &AnalyteVar. &SequenceVar.;
                run;

                %** Run the analysis **;
              data &Input._&k.;
              set &Input._&k.;
              if &ResultVar. eq . then delete;
              run;

proc sql;
select count(*) into: checkempty from &Input._&k.;
quit;
%if &checkempty ne 0 %then %do;

                ods select Estimates;
                proc mixed data = &Input._&k.;
                    by CohortNumber CohortName CohortDescription Combination &ParameterVar. &AnalyteVar.;
                    class &UsubjidVar. &SequenceVar.;
                    model &ResultVar. = &SequenceVar. / ddfm = kenwardroger;
                    random &UsubjidVar.;
                    lsmeans &SequenceVar. / pdiff cl alpha = 0.1;
                    %do i = 1 %to %sysfunc(countw(%nrbquote(&estimation_list.), @));
                        estimate "%scan(%nrbquote(&sequence_list.), &i., @) ~vs~ %scan(%nrbquote(&reference.), &k., @)" &SequenceVar. %scan(&contrast_list., &i., @) / cl alpha = 0.1;
                    %end;
                    
                    ods output Estimates = &work.estimates_unpaired_&k.;
                run;

                %** Use the label to change the combination **;
                data &work.estimates_unpaired_&k.;
                    set &work.estimates_unpaired_&k.(where = (estimate ne .));
                    combination = label;
                    EstType = "unpaired ";
                run;


                
                /*Meng added adpp input for exclude data*/
                    data &work.adppinput_&k.;
                    set &Input._&k.;
                    run;
                /*end*/

%end;
            %end;

            %** Clean-up **;
            %symdel contrast_list estimation_list;
        %end;
        %** Combine into one estimate **;
        data &work.estimates_unpaired;
            set
            %do i = 1 %to %sysfunc(countw(%nrbquote(&Reference.), @));
                %if %sysfunc(exist(&work.estimates_unpaired_&i.)) %then %do;
                    &work.estimates_unpaired_&i.
                %end;
            %end;
            ;
        run;

        %** Do the paired comparison **;
        %do k = 1 %to %sysfunc(countw(%nrbquote(&Reference.), @));
            proc sort data = &Input.(where = (upcase(reference) = "%upcase(%scan(%nrbquote(&reference.), &k., @))" and 
                                          (&SequenceVar. eq comb1 or &SequenceVar. eq comb2)))
                        out = &Input._&k.;
                by &SequenceVar.;
            run;

            proc sql noprint;
                select distinct
                    combination
                into
                    :combo_list separated by "@"
                from
                    &Input._&k.
                ;
            quit;
            
            %** Loop for each combination **;
            %do l = 1 %to %sysfunc(countw(%nrbquote(&combo_list.), @));
                data &Input._&k._&l.;
                    set &Input._&k.(where = (combination = "%scan(%nrbquote(&combo_list.), &l., @)"));
                run;
            
                %** If we have a reference - find out where it is in the order of the data (might not be first) **;
                data _null_;
                    set &Input._&k._&l. end = eof;
                    by &SequenceVar.;
                    length sequence_list $500.;
                    retain reference_loc sequence_list hit;

                    %** List of sequences **;
                    if _n_ = 1 then do;
                        sequence_list = strip(&SequenceVar.);
                    end;
                    else if first.&SequenceVar. then do;
                        sequence_list = strip(sequence_list) || "@" || strip(&SequenceVar.);
                    end;

                    %** Location of the reference sequence **;
                    if first.&SequenceVar. and not hit then do;
                        reference_loc + 1;
                    end;
                    else if first.&SequenceVar. and upcase(&SequenceVar.) ne "%upcase(%scan(%nrbquote(&reference.), &k., @))" then do;
                        reference_loc + 1;
                        hit = 1;
                    end;

                    %** Save to macro variables **;
                    if upcase(&SequenceVar.) = "%upcase(%scan(%nrbquote(&reference.), &k., @))" then do;
                        call symputx("reference_loc", reference_loc);
                    end;
                    if eof then do;
                        call symputx("sequence_list", sequence_list);
                    end;
                run;

                %put Reference loc = &reference_loc.;
                %put Sequence list = &sequence_list.;
                    
                %** Generate the estimate line for the mixed model (nasty code) **;
                %let estimation_list = ;
                %let contrast_list = ;
                %do i = 1 %to %sysfunc(countw(%nrbquote(&sequence_list.), @));  
                    %let number_list = ;
                    %do j = 1 %to %sysfunc(countw(%nrbquote(&sequence_list.), @));
                        %if &i. = &j. %then %do;
                            %let number_list = &number_list. 1;
                        %end;
                        %else %if &j. = &reference_loc. %then %do;
                            %let number_list = &number_list. -1;
                        %end;
                        %else %do;
                            %let number_list = &number_list. 0;
                        %end;
                    %end;
                    %let contrast_list = &contrast_list.@&number_list.;
                    %let estimation_list = &estimation_list@%scan(%nrbquote(&sequence_list.), &i., @) / %scan(%nrbquote(&reference.), &k., @);
                %end;
                %put CONTRAST = &contrast_list.;
                %put ESITMAT = &estimation_list.;
                %put dfgd = %sysfunc(countw(%nrbquote(&estimation_list.), @));
                
                %if %nrbquote(&contrast_list.) ne %then %do;

                    %** Sort and run the analysis **;
                    proc sort data = &Input._&k._&l.;
                        by CohortNumber CohortName CohortDescription Combination &ParameterVar. &AnalyteVar. &SequenceVar.;
                    run;


                      data &Input._&k._&l.;
                      set &Input._&k._&l.;
                      if &ResultVar. eq . then delete;
                      run;
proc sql;
select count(*) into: checkempty1 from  &Input._&k._&l.;
quit;
%if &checkempty1 ne 0 %then %do;

                    %** Run the analysis **;
                    ods select Estimates;
                    proc mixed data = &Input._&k._&l.;
                        by CohortNumber CohortName CohortDescription Combination &ParameterVar. &AnalyteVar.;
                        class &UsubjidVar. &SequenceVar.;
                        model &ResultVar. = &SequenceVar. / ddfm = kenwardroger;
                        lsmeans &SequenceVar. / pdiff cl alpha = 0.1;
                        %do i = 1 %to %sysfunc(countw(%nrbquote(&estimation_list.), @));
                            estimate "%scan(%nrbquote(&sequence_list.), &i., @) ~vs~ %scan(%nrbquote(&reference.), &k., @)" &SequenceVar. %qscan(&contrast_list., &i., @) / cl alpha = 0.1;
                        %end;
                        
                        ods output Estimates = &work.estimates_paired_&k._&l.;
                    run;

                    %** Use the label to change the combination **;
                    data &work.estimates_paired_&k._&l.;
                        set &work.estimates_paired_&k._&l.(where = (estimate ne .));
                        combination = label;
                        EstType = "paired";

                        %** Estimate and CI **;;
                        ratio = exp(estimate);
                        lcl = exp(lower);
                        ucl = exp(upper);
                    run;
%end;

                %end;

                %** Clean-up **;
                %symdel contrast_list estimation_list;
            %end;

            %** Combine the combinations **;
            data &work.estimates_paired_&k.;
                set 
                    %do l = 1 %to %sysfunc(countw(%nrbquote(&combo_list.), @));
                        %if %sysfunc(exist(&work.estimates_paired_&k._&l.)) %then %do;
                            &work.estimates_paired_&k._&l.
                        %end;
                    %end;
                ;
            run;
        %end;
        
        %** Combine into one estimate **;
        data &work.estimates_paired;
            set
            %do i = 1 %to %sysfunc(countw(%nrbquote(&Reference.), @));
                %if %sysfunc(exist(&work.estimates_paired_&i.)) %then %do;
                    &work.estimates_paired_&i.
                %end;
            %end;
            ;

            EstType = "paired  ";
        run;

        %** Combine the unpaired and paired resutls **;
        data &work.estimates;
            set %if %sysfunc(exist(&work.estimates_unpaired)) %then %do;
                    &work.estimates_unpaired
                %end;
                %if %sysfunc(exist(&work.estimates_paired)) %then %do;
                    &work.estimates_paired
                %end;
            ;
        run;
    %end;
    %else %do;
        %put FIXME: Currently not supported!!;
    %end;
%end;

%** Map the result back to the original domain **;
data &work.estimates;
    set &work.estimates;

    %** Estimate and CI **;;
    ratio = exp(estimate);
    lcl = exp(lower);
    ucl = exp(upper);

    %** Remove entries where there is no comparison **;
    if not indexw(combination, "~vs~") then do;
        delete;
    end;

    %** All combinations are created to avoid missing any entries (hence flip the combination) **;
     *Meng 04/23/2015 fixed forest title inverse ratio;
    if label = 'DDI Effect' then do;
        combination = strip(substr(combination, indexw(combination, "~vs~") + 5)) || " ~vs~ " || substr(combination, 1, indexw(combination, "~vs~") - 1);
    end;

    %** Clean-up **;
    keep CohortNumber CohortDescription Combination &ParameterVar. &AnalyteVar. ratio lcl ucl esttype;
run;

%** Clean-up **;
proc sort data = &work.estimates nodupkey;
    by CohortNumber CohortDescription Combination &ParameterVar. &AnalyteVar. ratio lcl ucl esttype;
run;


%*****************************************;
%**         Plot and Print              **;
%*****************************************;


data &work.estimates;
set &work.estimates(where = (find(upcase(&ParameterVar.), "AUC") or find(upcase(&ParameterVar.), "CMAX") or 
                            find(upcase(&ParameterVar.), "ACTAU") or find(upcase(&ParameterVar.), "ACINF"))); 
run;


/*created excel table which results are orgins from the same output table for forestplot,
 created on 0601 2015*/

    %** Generate nice output tables 
    ATTENTION: no dash, no cap, no word for seperator **;
    data &work.estimates;
     set &work.estimates;
       combination1=TRANWRD(combination,"~vs~", "$$$");
       Reference_L=scan(combination1,-1,"$$$","R");
     run;


/* Create the estimates table, which contains the results of the analysis for plot/table generation */
libname pkOutput "&OutputFolder.\estimates";

data pkOutput.estimates_ExcludeSub;
    set &work.estimates;
run;

libname pkOutput CLEAR;

/*create individual pk stats table which is the raw table for calculating estimates*/
libname pkOutput "&OutputFolder.\estimates";

data pkOutput.IndividualPkStats_ExcludeSub;
    set &input.;
run;

libname pkOutput CLEAR;
/*ends*/


%mend PK_Analysis_Summary_ExcludeSub;

%PK_Analysis_Summary_ExcludeSub(

                Input = result.removedinput,
                AnalyteVar = &AnalytePpVar.,
                ParameterVar = &ParameterVar.,
                ResultVar = &ResultPpVar.,
                PeriodVar = &PeriodPpVar.,
                UsubjidVar = &UsubjidVar.,
                SequenceVar = &SequenceVar.,
                StudyDesign = &StudyDesign.,
                StudyId = &StudyId., 
                OutputFolder = &OutputFolder.\&StudyId.
                
            );  





%put  get excluded sub of PK analysis summary;

/*step 3 generate customized statistical reporting*/
%macro PKViewReport_ExcludeSub();

/*    %SmReadReportSettingsFromDataSet();*/
    

    %do i = 1 %to %sysfunc(countw(%quote(&cohort_sel.), $));
        %do m= 1 %to %sysfunc(countw(%quote(&anal_sel.), $));
            %do q= 1 %to %sysfunc(countw(%quote(&param_sel.), $));              
                data work.select_&i._&m._&q.;
                set result.estimates_ExcludeSub (where = ( CohortDescription = "%scan(%quote(&Cohort_sel.), &i., $)" and
                                                Reference_L = "%scan(%quote(&ref_sel.), &i., $)" and 
                                                &AnalyteVar ="%scan(%quote(&anal_sel.), &m., $)" and
                                                &ParameterVar = "%scan(%quote(&param_sel.), &q., $)" and
                                                EstType= "&method_sel" and ratio ne .  ));
                run;

                /*proc print data=work.select_&i._&m._&q.; run;*/              
            %end;
        %end;
    %end;



 /* ****cohort option1: all cohorts in one table ******/
%if %index(&SortFiles,cohort)=0 %then %do;
        data allcohorts;
            set 
            %do i = 1 %to %sysfunc(countw(%quote(&cohort_sel.), $));       
                %do m= 1 %to %sysfunc(countw(%quote(&anal_sel.), $));
                    %do q= 1 %to %sysfunc(countw(%quote(&param_sel.), $));
                        %if %sysfunc(exist(work.select_&i._&m._&q.)) %then %do;
                            work.select_&i._&m._&q.
                        %end;
                    %end;
                %end;
            %end;
        ;
        run;


    %put all cohorts in one table;
%put OutputFolder=&OutputFolder;





proc sql;
select count(*) into: checkempty2 from  allcohorts;
quit;
%if &checkempty2 ne 0 %then %do;




    /* Generate statistical table output path based on NDA Id, User Id and settings Id */
   
    ods listing close;
    proc report data= allcohorts nowd
       style(report)=[outputwidth=7in]
        style(column)=[background=white]
        style(header)=[foreground=Green]
        style(summary)=[background=purple foreground=white]
        style(lines)=[background=lime]
        style(calldef)=[background=yellow foreground=black]
        out=AllCohortsNew;

        title1 /*bold*/ /*italic*/ font = 'Times New Roman'  height = 12pt justify = center underlin = 0 color = black bcolor = white 'Summary Table Categorized by Analyte';
        footnote1 /*bold*/ /*italic*/ font = 'Times New Roman'  height = 9pt justify = center underlin = 0 color = black bcolor = white 'Note: Created on May';
        column &AnalyteVar CohortNumber combination &ParameterVar reference_L EstType ("Results of Ratio and 90% CI" ratio lcl ucl) ;
        define &AnalyteVar/ "Analyte";
        define reference_L/"reference_listed";
        define &ParameterVar/ "Estimated Parameters";
        define EstType/ "Paired or Unpaired";
        define Combination/  "Comparison";
        define CohortNumber/ "Cohorts";
        define ratio/ format=8.4 "Ratio" ;
        define lcl/ format=8.4 "Lower Limit" ;
        define ucl/ format=8.4 "Upper Limit" ;
    run;

   ods listing;
   /*sorting function*/

    data AllCohortsNew(rename=(&AnalyteVar=analyte &ParameterVar=parameter CohortNumber=cohort Combination=comparison));
    set AllCohortsNew;
    run;
    

    proc sort data=AllCohortsNew;
    by %scan(%quote(&sort_list.),1,@)  %scan(%quote(&sort_list.),2,@)
    %scan(%quote(&sort_list.),3,@) %scan(%quote(&sort_list.),4,@);
    run;


    data AllCohortsNew;
    retain  %scan(%quote(&sort_list.),1,@)  %scan(%quote(&sort_list.),2,@)
    %scan(%quote(&sort_list.),3,@) %scan(%quote(&sort_list.),4,@);
    set AllCohortsNew;
    run;
 
    data AllCohortsNew (keep= parameter analyte comparison   Reference_L EstType ratio lcl ucl
                       );
    set AllCohortsNew;
    run;
    

    %let ResultFolder = &OutputFolder.\&StudyId.\&ReportFolder;

    %SmCheckAndCreateFolder(
        BasePath = &OutputFolder.\&StudyId.,
        FolderName = &ReportFolder
    );


   ods csv file= "&ResultFolder.\AllCohrotsNew_ExcludeSub.csv" ;

   proc print data=AllCohortsNew;
   run;

  ods csv close;


%end;/*check empty*/

%end;

/*option2 seperate by cohort*/
 %else %do;
        data allcohorts;
            set 
            %do i = 1 %to %sysfunc(countw(%quote(&cohort_sel.), $));       
                %do m= 1 %to %sysfunc(countw(%quote(&anal_sel.), $));
                    %do q= 1 %to %sysfunc(countw(%quote(&param_sel.), $));
                        %if %sysfunc(exist(work.select_&i._&m._&q.)) %then %do;
                            work.select_&i._&m._&q.
                        %end;
                    %end;
                %end;
            %end;
        ;
        run;

 %do i = 1 %to %sysfunc(countw(%quote(&cohort_sel.), $));   
            data cohort_&i;
                set allcohorts (where = ( CohortDescription = "%scan(%quote(&Cohort_sel.), &i., $)" ));
            run;

 %put Seperate tables by cohort;



/*sorting function*/
    data cohort_&i(rename=(&AnalyteVar=analyte &ParameterVar=parameter CohortNumber=cohort Combination=comparison));
    set cohort_&i;
    run;
    

    proc sort data=cohort_&i;
    by %scan(%quote(&sort_list.),1,@)  %scan(%quote(&sort_list.),2,@)
    %scan(%quote(&sort_list.),3,@) %scan(%quote(&sort_list.),4,@);
    run;


    data cohort_&i ;
    retain  %scan(%quote(&sort_list.),1,@)  %scan(%quote(&sort_list.),2,@)
    %scan(%quote(&sort_list.),3,@) %scan(%quote(&sort_list.),4,@);
    set cohort_&i;
    run;

   %put OutputFolder=&OutputFolder;


   %let ResultFolder = &OutputFolder.\&StudyId.\&ReportFolder;

    %SmCheckAndCreateFolder(
        BasePath = &OutputFolder.\&StudyId.,
        FolderName = &ReportFolder
    );

    ods listing close;

    ods csv file= "&ResultFolder.\cohort_&i_ExcludeSub..csv" ;

    data cohort_&i (rename=(analyte=&AnalyteVar parameter=&ParameterVar cohort=CohortNumber comparison=Combination));
    set cohort_&i ;
    run;

    proc report data= cohort_&i nowd
        style(report)=[outputwidth=7in]
        style(column)=[background=white]
        style(header)=[foreground=Green]
        style(summary)=[background=purple foreground=white]
        style(lines)=[background=lime]
        style(calldef)=[background=yellow foreground=black];
        title1 /*bold*/ /*italic*/ font = 'Times New Roman'  height = 12pt justify = center underlin = 0 color = black bcolor = white 'Summary Table Categorized by Analyte';
        footnote1 /*bold*/ /*italic*/ font = 'Times New Roman'  height = 9pt justify = center underlin = 0 color = black bcolor = white 'Note: Created on May';
        column &AnalyteVar combination &ParameterVar reference_L EstType ("Results of Ratio and 90% CI" ratio lcl ucl) ;
        define &AnalyteVar / "Analyte";
        define reference_L/"reference_listed";
        define &ParameterVar/ "Estimated Parameters";
        define EstType/ "Paired or Unpaired";
        define Combination/  "Comparison";
        define ratio/ format=8.4 "Ratio" ;
        define lcl/ format=8.4 "Lower Limit" ;
        define ucl/ format=8.4 "Upper Limit" ;
    run;
    ods listing ;
    ods csv close;

 %end;
%end; 


proc sql noprint;
select count(*) into :obscount from result.individualpkstats;
quit;
%put 4th: obscount=&obscount;

%mend PKViewReport_ExcludeSub; 
%PKViewReport_ExcludeSub;  



%mend PKReportExclude;
