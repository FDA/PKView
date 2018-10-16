*****************************************************************************************;
%**                                                                                     **;
%** Runs the PK analysis for intrinsic/extrinsic studies.                               **;
%**                                                                                     **;
%** Input:                                                                              **;
%**     Input                   -       Input file                                      **;
%**     AnalyteVar              -       Name of the analyte variable from PP            **;
%**     ParameterVar            -       Name of the PK parameter variable from PP       **;
%**     ResultVar               -       Name of the result variable in PP               **;
%**     PeriodVar               -       Name of the period variable in PP               **;
%**     UsubjidVar              -       Name of the usubjid variable in DM              **;
%**     SequenceVar             -       Name of the sequence/group variable in DM       **;
%**     StudyDesign             -       Study design                                    **;
%**     StudyId                 -       Study Id                                        **;
%**     OutputFolder            -       Output folder                                   **;
%**                                                                                     **;
%** Output:                                                                             **;
%**     Forest plots and PK summa                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ry tables                                              **;
%**                                                                                     **;
%** Created by:                                                                         **;
%**     Jens Stampe Soerensen  (2013/2014)                                              **;
%**                                                                                     **;
%** Updated and Debugged by:                                                                        **;
%**     Meng Xu (2015/2016)                                                                  **;
%*****************************************************************************************;

%macro PK_Analysis_Summary(
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

data &input.;
    set &input.;
    &AnalyteVar=TRANWRD(&AnalyteVar.,",", "_");
run;

%if &MAXNUMBEROFPERIODS.=1 and %upcase(&StudyDesign.) ne PARALLEL   %then %do;
        %** Read the data **;
        %SmReadAndMergeDataset(
            Input1 = &InputPp.,
            UsubjidVar = &UsubjidVar.,
            Output = &work.pp
        );
        
        /* Replace PP:Visit variable with custom one */
        %if &UseCustomPpVisit.=1 %then %do;
            proc sort data = &work.pp; by &PpVisitVar.; run;
            proc sort data = &work.customPpVisit; by OldValue; run;
            data &work.pp(rename=(NewValue=&PpVisitVar.));
                merge &work.pp(rename=(&PpVisitVar.=OldValue) in=hasData)
                      &work.customPpVisit;
                by OldValue;
                if hasData;
            run;
        %end;

        proc sort data = &Input.;by &UsubjidVar.;
        data temp;
            set &work.pp(keep=&UsubjidVar.
                %if %sysfunc(varnum(%sysfunc(open(&work.pp)),&PeriodVar.)) %then &PeriodVar.;
            );
        run;
        proc sort data = &Input.;by &UsubjidVar.;
        data &Input.;
            set &Input.(drop=&PeriodVar.)
        ;run;
        data &Input.;
            merge &Input.(in=a) temp(in=b);
            by &UsubjidVar.;
            if a;
        run;
%end;

%AssignCombination(input=&input.);

%** Macro variables **;
%local i j k h a p t;

%** Create output folder for forest plots and summary tables **;
%SmCheckAndCreateFolder(
    BasePath = &OutputFolder.,
    FolderName = Forest Plot
);

%SmCheckAndCreateFolder(
    BasePath = &OutputFolder.,
    FolderName = PK Summary Tables
);

%Log(
        Progress = 85,
        TextFeedback = Creating PK summary tables &StudyId.
    );
    
%*****************************************;
%**         Run Summary Tables          **;
%*****************************************;

%** Get the total counts, mean, std, min, max and median **;

proc sql;
create table findduplicate as
select *, count(*) as divider 
from &Input. 
group by CohortNumber, CohortDescription, TreatmentInPeriod ,TreatmentInPeriodText ,&AnalyteVar., &ParameterVar. ,USUBJID
having count(*)>1;
select distinct divider into: dividervar from findduplicate;
quit;
%put dividervar=&dividervar;

proc summary data = &Input. nway missing;
    class CohortNumber CohortDescription TreatmentInPeriod TreatmentInPeriodText &AnalyteVar. &ParameterVar.;
    var &ResultVar.;
    output out = &work.summary_mean (drop = _freq_ _type_)
                    mean = mean 
                    std = std 
                    n=n
                    
    ;
run;

%if %symexist(dividervar) %then %do;

data &work.summary_mean ;
set &work.summary_mean ;
number=round(n/&dividervar);
drop n;
rename number=n;
run;
%end;


%** Get the geometric mean and CV (proc ttest the only procedure capable of doing it without having to do it by hand) **;
proc sort data = &Input.;
    by CohortNumber CohortDescription TreatmentInPeriod TreatmentInPeriodText &AnalyteVar. &ParameterVar.;
run;

ods select Statistics;

/* { FIXME!!!!!! This prevents the merge from crashing but further analysis of the code should determine a better handling of cases
 where &Input has zero observations */
data  &work.summary_geo; 
    length CohortDescription TreatmentInPeriod TreatmentInPeriodText &AnalyteVar. &ParameterVar. $25;
run;
/* FIXME!!!! }*/
proc ttest data = &Input. dist = lognormal;
    by CohortNumber CohortDescription TreatmentInPeriod TreatmentInPeriodText &AnalyteVar. &ParameterVar.;
    var &ResultVar.;
    ods output Statistics = &work.summary_geo (keep = CohortNumber CohortDescription TreatmentInPeriod TreatmentInPeriodText &AnalyteVar. &ParameterVar geommean cv);
run;
ods select all;

%** Combine the data to have the mean + std in the same table as geomean + cv **;
data &work.summary_table;
    merge   &work.summary_mean (in = a)
            &work.summary_geo (in = b);
    by CohortNumber CohortDescription TreatmentInPeriod TreatmentInPeriodText &AnalyteVar. &ParameterVar.;
    if a or b;

    %** Convert CV to percent **;
    cv = cv * 100;

    %** Round the numeric values **;
    mean = round(mean, 0.01);
    std = round(std, 0.01);
    geommean = round(geommean, 0.01);
    cv = round(cv, 0.01);
    

    %** Combine **;
    if mean ne . and std ne . then do;
        mean_std = cat(mean, " (", std, ")");
    end;
    if geommean ne . and cv ne . then do;
        geommean_cv = cat(geommean, " [", cv, "]");
    end;
run;

%** Add combinations **;
proc sort data = &work.summary_table;
    by CohortNumber CohortDescription &ParameterVar. &AnalyteVar. TreatmentInPeriodText TreatmentInPeriod;
run;

data &work.summary_combination;
    set &work.summary_table;
    by CohortNumber CohortDescription &ParameterVar. &AnalyteVar. TreatmentInPeriodText TreatmentInPeriod;

    length Combination $200.;
    retain Combination;

    if first.&AnalyteVar. then do;
        Combination = TreatmentInPeriodText;
    end;
    else do;
        Combination = strip(Combination) || " ~vs~ " || strip(TreatmentInPeriodText);
    end;

    if index(Combination, "~vs~") = 1 then do;
        Combination = substr(Combination, 6);
    end;

    if last.&AnalyteVar. then do;
        output;
    end;

    keep CohortNumber CohortDescription &ParameterVar. &AnalyteVar. Combination;
run;

%** Merge with the summary table **;
data &work.summary_table;
    merge   &work.summary_table(in = a)
            &work.summary_combination(in = b);
    by CohortNumber CohortDescription &ParameterVar. &AnalyteVar.;
    if a;
run;

%*****************************************;
%**         Run PK analysis             **;
%*****************************************;
%Log(
        Progress = 90,
        TextFeedback = Computing pk summary data for &StudyId.
    );

data &Input.;
    set &Input.;

    %** Log transform **;
    &ResultVar. = log(&ResultVar.);
run;

data &work.TestPP;
set &Input.;
run;

%cleanpp(input=&Input);

%** Cross-over **;
%if %upcase(&StudyDesign.) = CROSSOVER and &MaxNumberOfPeriods. <= 2 %then %do;

    /*remove the observations with missing combination or treatmentinperiod*/
    data &Input.;
        set &Input.;
        if combination="ZZZZZZZZZZ" or treatmentinperiodtext="                                          " then delete;
    run;

    proc sort data = &Input.;
        by CohortNumber CohortName CohortDescription &ParameterVar. &AnalyteVar. Combination TreatmentInPeriod;
    run;

    /*replace ~vs~ with $$$$ to fix the cutoff issue*/
    data &Input.;
        length combinationnew $200.;
        set &Input.;
        combinationnew=TRANWRD(combination,"~vs~", "$$$$");
    run;

    /*add counter and rename the new and orignal ones*/
    data &Input.(rename=(combination=orig_combination correctcombination_back=combination));
        length checkcombination checktreat laststring firststring correctcombination correctcombination_back $200.;
        set &Input.;
        by CohortNumber CohortName CohortDescription  &ParameterVar. &AnalyteVar. Combination TreatmentInPeriod;

    if first.combination then do;
        combcounter+1;
        retain combcounter;
    end;

    if first.combination then treatcounter=0;
    if first.treatmentinperiod then treatcounter+1;
    retain treatcounter;

    /*findout wrong combination order and switch to the correct based on treatmentinperiod orders in same comparison*/
    checkcombination=strip(scan(combinationnew,treatcounter,"$$$$"));
    checktreat=strip(treatmentinperiodtext);

    if checkcombination ne checktreat then do;
        same="NO";
        laststring=scan(combinationnew,1, "$$$$");
        firststring=scan(combinationnew,2,"$$$$");
        correctcombination = strip(firststring) || " $$$$ " || strip(laststring);
    end;
    else do;
        correctcombination=combinationnew;
    end;

    correctcombination_back=TRANWRD(correctcombination,"$$$$","~vs~");

    drop combcounter treatcounter checkcombination checktreat laststring firststring same;
    run;

    proc sort data = &Input.;
        by CohortNumber CohortName CohortDescription &ParameterVar. &AnalyteVar. Combination TreatmentInPeriod;
    run;


    *ods select Estimates;
     data &Input.;
     set &Input.;
     if &ResultVar. eq . then delete;
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



    /* Meng added integrity cumulative1 on 2016/7/28*/
        data &work.integrity;
        set &Input.;
        run;
    /*ends*/


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

        /*should have no CleanPP*/
        data &Input.;
            set &Input.;
            if combination="ZZZZZZZZZZ" or treatmentinperiodtext="                                          " then delete;
        run;

        proc sort data = &Input.;
            by CohortNumber CohortName CohortDescription &ParameterVar. &AnalyteVar. Combination TreatmentInPeriod;
        run;

        /*replace to fix cutoff issue*/ 
        data &Input.;
            length combinationnew $200.;
            set &Input.;
            combinationnew=TRANWRD(combination,"~vs~", "$$$$");
        run;

        /*add counter to check the combination*/
        data &Input.(rename=(combination=orig_combination correctcombination_back=combination));
            length checkcombination checktreat laststring firststring correctcombination correctcombination_back $200.;
            set &Input.;
            by CohortNumber CohortName CohortDescription  &ParameterVar. &AnalyteVar. Combination TreatmentInPeriod;

            if first.combination then do;
                combcounter+1;
                retain combcounter;
            end;

            if first.combination then treatcounter=0;
            if first.treatmentinperiod then treatcounter+1;
            retain treatcounter;

            /*findout wrong combiantion order and switch to the correct based on treatmentinperiod orders in same comparison*/
            checkcombination=strip(scan(combinationnew,treatcounter,"$$$$"));
            checktreat=strip(treatmentinperiodtext);

            if checkcombination ne checktreat then do;
                same="NO";
                laststring=scan(combinationnew,1, "$$$$");
                firststring=scan(combinationnew,2,"$$$$");
                correctcombination = strip(firststring) || " $$$$ " || strip(laststring);
            end;
            else do;
                correctcombination=combinationnew;
            end;
            correctcombination_back=TRANWRD(correctcombination,"$$$$","~vs~");

            drop combcounter treatcounter checkcombination checktreat laststring firststring same;
        run;

        proc sort data = &Input.;
                by CohortNumber CohortName CohortDescription &ParameterVar. &AnalyteVar. Combination TreatmentInPeriod;
        run;


        %** Analysis **;
         data &Input.;
         set &Input.;
         if &ResultVar. eq . then delete;
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
        data &Input.;
            set &Input.;
            if combination="ZZZZZZZZZZ" or treatmentinperiodtext="                                          " then delete;
        run;

        proc sort data = &Input.;
            by CohortNumber CohortName CohortDescription &ParameterVar. &AnalyteVar. Combination TreatmentInPeriod;
        run;
            
        data &Input.;
            length combinationnew $200.;
            set &Input.;
            combinationnew=TRANWRD(combination,"~vs~", "$$$$");
        run;

        data &Input.(rename=(combination=orig_combination correctcombination_back=combination));
            length checkcombination checktreat laststring firststring correctcombination correctcombination_back $200.;
            set &Input.;
            by CohortNumber CohortName CohortDescription  &ParameterVar. &AnalyteVar. Combination TreatmentInPeriod;

            if first.combination then do;
                combcounter+1;
                retain combcounter;
            end;

            if first.combination then treatcounter=0;
            if first.treatmentinperiod then treatcounter+1;
            retain treatcounter;

            /*findout wrong combiantion order and switch to the correct based on treatmentinperiod orders in same comparison*/
            checkcombination=strip(scan(combinationnew,treatcounter,"$$$$"));
            checktreat=strip(treatmentinperiodtext);

            if checkcombination ne checktreat then do;
                same="NO";
                laststring=scan(combinationnew,1, "$$$$");
                firststring=scan(combinationnew,2,"$$$$");
                correctcombination = strip(firststring) || " $$$$ " || strip(laststring);
            end;
            else do;
                correctcombination=combinationnew;
            end;
            correctcombination_back=TRANWRD(correctcombination,"$$$$","~vs~");
            drop combcounter treatcounter checkcombination checktreat laststring firststring same;
        run;

        proc sort data = &Input.;
                by CohortNumber CohortName CohortDescription &ParameterVar. &AnalyteVar. Combination TreatmentInPeriod;
        run;

     data &Input.;
     set &Input.;
     if &ResultVar. eq . then delete;
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



 /* Meng added integrity cumulative2 on 2016/7/28*/
        data &work.integrity;
        set &Input.;
        run;
    /*ends*/




%end;
%** Sequential **;
%else %if %upcase(&StudyDesign.) = SEQUENTIAL %then %do;
    proc sort data = &Input.;
        by CohortNumber CohortName CohortDescription &ParameterVar. &AnalyteVar. Combination TreatmentInPeriod;
    run;


     data &Input.;
     set &Input.;
     if &ResultVar. eq . then delete;
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


     /* Meng added integrity cumulative1 on 2016/7/28*/
        data &work.integrity;
        set &Input.;
        run;
    /*ends*/

        


%end;
%** Parallel **;
%else %if %upcase(&StudyDesign.) = PARALLEL %then %do;

    data &work.adppinput;
    set &Input.;
    run;




    %put Reference is: &reference.;
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
%** Create the output report for the summary values **;

%Log(
        Progress = 95,
        TextFeedback = Generating reports and summary PK plots &StudyId.
    );
        
         data  &work.summary_table;
         set &work.summary_table(where = (find(upcase(&ParameterVar.), "AUC") or find(upcase(&ParameterVar.), "CMAX") or 
                            find(upcase(&ParameterVar.), "ACTAU") or find(upcase(&ParameterVar.), "ACINF")));
         run;
        

    proc sql noprint;
    %** Get the different cohorts, comparision and analytes **;
    select distinct
        CohortDescription
    into
        :CohortName_list separated by "@"
    from
        &work.summary_table
    ;

    select distinct
        Combination
    into
        :Combination_list separated by "@"
    from
        &work.summary_table
    ;

    select distinct
        &AnalyteVar.
    into
        :Analyte_list separated by "@"
    from
        &work.summary_table
    ;
quit;

%** Generate nice output tables **;
%do h = 1 %to %sysfunc(countw(%quote(&CohortName_list.), @));
    %do i = 1 %to %sysfunc(countw(%quote(&Combination_list.), @));
        %do j = 1 %to %sysfunc(countw(%quote(&Analyte_list.), @));
            %** Create the output folder **;
            %SmCheckAndCreateFolder(
                BasePath = &OutputFolder.\PK Summary Tables,
                FolderName = %scan(%nrbquote(&Analyte_list.), &j., @)
            );

            %** Sort **;
            proc sort data = &work.summary_table(where = (
                                                    CohortDescription = "%scan(%quote(&CohortName_list.), &h., @)" and
                                                    Combination = "%scan(%quote(&Combination_list.), &i., @)" and
                                                    &AnalyteVar. = "%scan(%quote(&Analyte_list.), &j., @)"
                                                ))
                        out = &work._temp_&i._&j.;
                by CohortNumber CohortDescription &AnalyteVar. &ParameterVar.;
            run;
            
            %** Get the current combination **;
            proc sql noprint;
                select distinct
                    TreatmentInPeriodText
                into
                    :TreatmentLabel separated by "@"
                from
                    &work._temp_&i._&j.
                ;
            quit;


            %** Flip the data **;
            data &work._temp_&i._&j.;
                merge   
                    %do k = 1 %to %sysfunc(countw(%quote(&TreatmentLabel.), @));
                        &work._temp_&i._&j. (in = a&k. 
                                                where = (TreatmentInPeriodText = "%scan(%quote(&TreatmentLabel.), &k., @)")
                                                rename = (mean_std = mean_std_&k. geommean_cv = geommean_cv_&k. n=n_&k.)
                                                )
                    %end;
                ;
                by CohortNumber CohortDescription &AnalyteVar. &ParameterVar.;
                if a1;
            run;

       

            %** Get the number of observations **;
            %SmGetNumberOfObs(Input = &work._temp_&i._&j.);

            %** Do the report **;
            /*Meng added number of total subjects involved in the summary analysis no 10/07/2015*/
            %if &NumberOfObs. >= 1 %then %do;
                ods listing close;
                title "%scan(%quote(&CohortName_list.), &h., @) /\ %scan(%quote(&Combination_list.), &i., @) /\ Analyte: %scan(%quote(&Analyte_list.), &j., @)";
                *title "%scan(%quote(&Combination_list.), &i., @) | Analyte: %scan(%quote(&Analyte_list.), &j., @)";
                ods rtf file = "&OutputFolder.\PK Summary Tables\%scan(%nrbquote(&Analyte_list.), &j., @)\PK_Summary_Table_&i.&j..rtf" style = sasdocprinter;
                    proc report data = &work._temp_&i._&j. nowd;
                        column &ParameterVar. 
                                %do k = 1 %to %sysfunc(countw(%quote(&TreatmentLabel.), @));
                                     ("%scan(%quote(&TreatmentLabel.), &k., @)" n_&k. mean_std_&k. geommean_cv_&k. )
                                %end;
                        ;
                     
                        define &ParameterVar.       / order style = {just = left};
                        %do k = 1 %to %sysfunc(countw(%quote(&TreatmentLabel.), @));
                            define n_&k.  / style = {just = right} "N";
                            define mean_std_&k.     / style = {just = right} "Mean (STD)";
                            define geommean_cv_&k.  / style = {just = right} "Geo. Mean (CV%)";
                            
                        %end;

                    run;
                ods rtf close;
            %end;

            %** Clean - up **;
            %symdel NumberOfObs;
        %end;
    %end;
%end;

%** Create the forest plot **;
%** Prepare data for presentation **;
proc sql noprint;
    %** Get the different cohorts, comparision and analytes **;
    select distinct
        CohortDescription
    into
        :CohortName_list separated by "@"
    from
        &work.estimates
    ;

    select distinct
        Combination
    into
        :Combination_list separated by "@"
    from
        &work.estimates
    ;

    select distinct
        &AnalyteVar.
    into
        :Analyte_list separated by "@"
    from
        &work.estimates
    ;

    select distinct
        EstType
    into
        :EstType_list separated by "@"
    from
        &work.estimates
    ;
quit;

data &work.estimates;
set &work.estimates(where = (find(upcase(&ParameterVar.), "AUC") or find(upcase(&ParameterVar.), "CMAX") or 
                            find(upcase(&ParameterVar.), "ACTAU") or find(upcase(&ParameterVar.), "ACINF"))); 
run;

%do k = 1 %to %sysfunc(countw(%nrbquote(&CohortName_list.), @));
    %do i = 1 %to %sysfunc(countw(%nrbquote(&Combination_list.), @));
        %do j = 1 %to %sysfunc(countw(%nrbquote(&Analyte_list.), @));
            %do n = 1 %to %sysfunc(countw(%nrbquote(&EstType_list.), @));
                %** Create the output folder **;
                %SmCheckAndCreateFolder(
                    BasePath = &OutputFolder.\Forest Plot,
                    FolderName = %scan(%nrbquote(&Analyte_list.), &j., @)
                );

               
                %** Subset the data **;
                data &work.estimates_&i._&j.;
                    length PkParameter $20.;
                    format PkParameter $20.;
                
                set &work.estimates(where = (
                    CohortDescription = "%scan(%nrbquote(&CohortName_list.), &k., @)" and
                    Combination = "%scan(%nrbquote(&Combination_list.), &i., @)" and
                    &AnalyteVar. = "%scan(%nrbquote(&Analyte_list.), &j., @)" and
                    strip(EstType) = "%scan(%nrbquote(&EstType_list.), &n., @)"
                ));

                    %** Helper variables **;
                    zero = 0;
                    one = 1;
                    sort1 = _n_;

                    PkParameter = strip(&ParameterVar.);

                    %** Labels **;
                    RATIO_LBL = "Ratio";
                    LCL_LBL = "Lower Limit";
                    UCL_LBL = "Upper Limit";
                run;


            %put meng check what is sort1;
           /* proc print data=&work.estimates_&i._&j.; run;*/



                %** Prepare the template for plotting **;
                proc template;
                    %** Define an appropriate style **;
                    define style forest_style; 
                        parent = Styles.Listing; 
                        style GraphFonts from GraphFonts /                                       
                            'GraphDataFont' = ("<sans-serif>, <MTsans-serif>",7pt)                                
                            'GraphValueFont' = ("<sans-serif>, <MTsans-serif>",7pt)
                            'GraphLabelFont' = ("<sans-serif>, <MTsans-serif>",7pt, bold); 
                        ;
                    end;

                    %** Graphics **;
                    define statgraph forest;
                        begingraph;
                            entrytitle "Group: %scan(%nrbquote(&CohortName_list.), &k., @)";
                            entrytitle "Comparison: %scan(%nrbquote(&Combination_list.), &i., @)";
                            entrytitle "Analyte: %scan(%nrbquote(&Analyte_list.), &j., @)";
                            entrytitle "Analysis: %scan(%nrbquote(&EstType_list.), &n., @)";

                            layout lattice / columns = 3 columnweights = (0.30 0.45 0.25);
                                layout overlay  /   walldisplay = none
                                                    xaxisopts = (display = none)
                                                    yaxisopts = (reverse = true display = none tickvalueattrs = (weight = bold));
                                    scatterplot y = sort1 x = one       /   markercharacter = PkParameter
                                                                            markercharacterattrs = (family = 'Lucida Console' size = 8 weight = bold);
                                endlayout;
                                layout overlay  /   walldisplay = none
                                                    xaxisopts = (label = "Ratio of Test to Reference" linearopts = (tickvaluepriority = true tickvaluelist = (0.0 0.5 1.0 1.5 2.0 2.5)))
                                                    yaxisopts = (reverse = true display = none);
                                    entry "Fold Change and 90% CI"      /   location = outside valign = top textattrs = graphlabeltext;
                                    scatterplot y = sort1 x = RATIO     /   xerrorlower = lcl xerrorupper = ucl
                                                                            markerattrs = (symbol = squarefilled);  
                                    referenceline x = 1;
                                endlayout;
                                layout overlay  /   walldisplay = none
                                                    x2axisopts = (display = (tickvalues) offsetmin = 0.25 offsetmax = 0.25)
                                                    yaxisopts  = (reverse = true display = none);

                                    scatterplot y = sort1 x = ratio_lbl /   markercharacter = RATIO 
                                                                            markercharacterattrs = graphvaluetext xaxis = x2;
                                    scatterplot y = sort1 x = lcl_lbl   /   markercharacter = lcl
                                                                            markercharacterattrs = graphvaluetext xaxis = x2;
                                    scatterplot y = sort1 x = ucl_lbl   /   markercharacter = ucl
                                                                            markercharacterattrs = graphvaluetext xaxis = x2;
                                endlayout;          
                            endlayout;
                        endgraph;
                    end;
                run;

                %** Get the number of observations **;
                %SmGetNumberOfObs(Input = &work.estimates_&i._&j.);

                %** Check if there is any usuable data **;
                %SmContainsMissing(Input = &work.estimates_&i._&j.);

                %** Plot **;
                %if &NumberOfObs. >= 1 and &ContainsData. = 1 %then %do;
                    options nodate nonumber;
                    ods listing gpath = "&OutputFolder.\Forest Plot\%scan(%nrbquote(&Analyte_list.), &j., @)";
                    ods graphics on / noborder imagefmt = png imagename = "&StudyId._ForestPlot_&i._&j._%scan(%nrbquote(&EstType_list.), &n., @)" width = 800px height = 1080;
                    proc sgrender data = &work.estimates_&i._&j. template = forest;
                    run;
                    ods listing close;
                    ods graphics off;
                %end;

                %** Clean up **;
                %symdel NumberOfObs;
            %end;   
        %end;
    %end;
%end;

/*created excel table which results are orgins from the same output table for forestplot,
Meng created on 0601 2015*/

    %** Generate nice output tables 
    ATTENTION: no dash, no cap, no word for seperator **;
    data &work.estimates;
     set &work.estimates;
       combination1=TRANWRD(combination,"~vs~", "$$$");
       Reference_L=scan(combination1,-1,"$$$","R");
     run;

/*Save estimates data to the output folder for further processing by the reporting scripts */
%SmCheckAndCreateFolder(
    BasePath = &OutputFolder.,
    FolderName = estimates
);


    proc sql noprint;
     select distinct  Reference_L
     into : Reference_L_list separated by "@"
     from &work.estimates;
    quit;
    %put Reference_L_list=&Reference_L_list;

 %do k= 1 %to %sysfunc(countw(%quote(&CohortName_list.), @));
    %do y = 1 %to %sysfunc(countw(%quote(&Reference_L_list.), @));

    data &work.estimates_&k._&y.;
    length PkParameter $20.;
    format PkParameter $20.;            
    set &work.estimates(where = (
    CohortDescription = "%scan(%nrbquote(&CohortName_list.), &k., @)" and
    Reference_L="%scan(%nrbquote(&Reference_L_list.), &y., @)" ));

    %** Helper variables **;
     zero = 0;
     one = 1;
     sort1 = _n_;

     PkParameter = strip(&ParameterVar.);

    %** Labels **;
    RATIO_LBL = "Ratio";
    LCL_LBL = "Lower Limit";
    UCL_LBL = "Upper Limit";                  
    run;

proc print data=&work.estimates_&k._&y;
run;

 %SmCheckAndCreateFolder(
    BasePath = &OutputFolder.,
    FolderName = PK excel table
  );

    proc sort data=&work.estimates_&k._&y;
    by EstType;
    run;


ods csv file= "&OutputFolder.\PK excel table\table_&k._&y..csv" ;

    proc report data= &work.estimates_&k._&y nowd
    style(report)=[outputwidth=7in]
    style(column)=[background=white]
    style(header)=[foreground=Green]
    style(summary)=[background=purple foreground=white]
    style(lines)=[background=lime]
    style(calldef)=[background=yellow foreground=black];
    title1 /*bold*/ /*italic*/ font = 'Times New Roman'  height = 12pt justify = center underlin = 0 color = black bcolor = white 'Summary Table Categorized by Analyte';
    footnote1 /*bold*/ /*italic*/ font = 'Times New Roman'  height = 9pt justify = center underlin = 0 color = black bcolor = white 'Note: Created on May';
    column &AnalyteVar. CohortNumber combination reference_L &ParameterVar. EstType ("Results of Ratio and 90% CI" ratio lcl ucl) ;
    define &AnalyteVar. / group "Analyte";
    define reference_L/"reference_listed";
    define &ParameterVar./ "Estimated Parameters";
    define EstType/ "Paired or Unpaired";
    define Combination/  "Comparison";
    define CohortNumber/ "Cohorts";
    define ratio/ format=8.4 "Ratio" ;
    define lcl/ format=8.4 "Lower Limit" ;
    define ucl/ format=8.4 "Upper Limit" ;
    run;

ods csv close;

 %end;
%end;

*Meng 06/15/2015  for listing all parameters and analytes of each study and output;
*purpose: for report settings;

proc freq data =&work.estimates noprint;
    tables &ParameterVar./out=&work.ParameterList(keep=&ParameterVar. rename=(&ParameterVar.=Parameter));
run; 

proc freq data =&work.estimates noprint;
    tables &AnalyteVar./out=&work.AnalyteList(keep=&AnalyteVar. rename=(&AnalyteVar.=Analyte));
run;

/* Create the estimates table, which contains the results of the analysis for plot/table generation */
libname pkOutput "&OutputFolder.\estimates";

data pkOutput.estimates;
    set &work.estimates;
run;

libname pkOutput CLEAR;

/*create individual pk stats table which is the raw table for calculating estimates*/
libname pkOutput "&OutputFolder.\estimates";

data pkOutput.IndividualPkStats;
    set &input.;
run;




data pkOutput.IndividualPkStatsMeta;
    set &input.(
 rename=(
           
            &SequenceVar=MacroArm 
            &PeriodVar=MacroPeriod 
            &AnalyteVar=MacroAnalyte 
            &PpSpecimenVar=MacroSpecimen 
            &ResultVar=MacroResult 
            &ParameterVar.=MacroParameter 
)

);
run;

libname pkOutput CLEAR;

data &work.InputPPcat;
set &input.;
letter="a";
usubjidcat=trim(letter)||trim(usubjid);
drop usubjid;
rename usubjidcat=usubjid;
run;




data &work.IndividualPk;
length specimen $ 200;
    set &work.InputPPcat(
        rename=(
            USUBJID=Subject 
            CohortDescription=Cohort 
            &SequenceVar=Arm 
            &PeriodVar=Period 
            &AnalyteVar=Analyte 
            &PpSpecimenVar=Specimen 
            TreatmentInPeriodText=Treatment 
            &ResultVar=Result 
            &ParameterVar.=Parameter 
        )
        keep=USUBJID CohortDescription &SequenceVar &PeriodVar. &AnalyteVar. 
            &PpSpecimenVar. TreatmentInPeriodText &ResultVar. &ParameterVar.
        );
       
     if Specimen= "        " then Specimen= "DEFAULT"; 
run;



/* Meng Xu added- integrity test3 for sequential and crossover starts- to be inserted HERE*/



data _null_;
set websvc.study;
call symput("scatterplot",SCATTERPLOT);          
call symput("Cumulative",CUMULATIVE );
run;

%put SCATTERPLOT=&SCATTERPLOT;
%put CUMULATIVE=&CUMULATIVE ;


%macro IntegrityCumu_SeqCro;

/*******************STEP1: generate cumulative PE**************************************/

%IF &CUMULATIVE=1 %THEN %DO;
%if %upcase(&StudyDesign.) NE PARALLEL %then %do;
/*add PCDTC to modling building input data*/


data pcxpt;
set pcconc;
run;

data pcconc;
set pcconc;
keep USUBJID PCDTC;
if PCDTC eq "                " then delete;
if PCSPEC eq "URINE" then delete;
run;

proc sort data=pcconc;
by USUBJID PCDTC ;
run;

/*get earliest pcdtc by sub in pc raw*/
data earsub;
set pcconc;
by USUBJID;
if  first.usubjid then output;
run;

/*enumerate*/
proc sort data=earsub;
by pcdtc ;
run;

data earsub;
set earsub;
by pcdtc;
retain mengcount;
if first.pcdtc then mengcount+1;
run;

proc sort data=&work.integrity;
by USUBJID;
run;
proc sort data=earsub;
by USUBJID;
run;

/*merge and keep all obs in analysisinput*/
data analysisdate;
merge &work.integrity(in=a) earsub(in=b);
by USUBJID;
if a;
run ;




proc sql noprint;
select max(cohortnumber) into: maxcohortnumber from analysisdate;
quit;
%put max cohortnumber in analysisdate: &maxcohortnumber;

%do C=1 %to &maxcohortnumber;

data analysisdate_&C.;
set analysisdate;
where cohortnumber=&C;
run;

/*read data by pctdc*/
proc sql noprint;
select distinct mengcount into : reader separated by "$" from analysisdate_&C.;
select distinct pcdtc into:datelist separated by "$" from analysisdate_&C.;
quit;
%put reader=&reader;
%put datelist=&datelist;

%do i=1 %to %sysfunc(countw(%nrquote(&reader),$));
    /*get subset*/
    data copy_&C.&i;
    set analysisdate_&C.;
    where mengcount=%scan(%nrbquote(&reader), &i., $);
    run;

    %if &i=1 %then %do;
        data &work.subset;
        set copy_&C.&i;;
        run;
    %end;
    %else %do;       
        data &work.subset;
        set &work.subset copy_&C.&i;;
        run;
    %end; 

        /*different conditions*/

        %if %upcase(&StudyDesign.) = CROSSOVER and &MaxNumberOfPeriods. <= 2 %then %do;
        proc sort data =&work.subset;
            by CohortNumber CohortName CohortDescription &ParameterVar. &AnalyteVar. Combination TreatmentInPeriod;
        run;

        proc mixed data = &work.subset;
            by CohortNumber CohortName CohortDescription &ParameterVar. &AnalyteVar. Combination;
            class &UsubjidVar. TreatmentInPeriod;
            model &ResultVar. = TreatmentInPeriod / ddfm = kenwardroger;
            /* fixme random &UsubjidVar.; */
            random &UsubjidVar. ;
            lsmeans TreatmentInPeriod / pdiff cl alpha = 0.1;
            estimate 'DDI Effect' TreatmentInPeriod -1 1 / cl alpha = 0.1;
            estimate 'DDI Effect Inv' TreatmentInPeriod 1 -1 / cl alpha = 0.1;
            ods output Estimates = meng_&C.&i;
        run;

        %end;

        %else %if %upcase(&StudyDesign.) = CROSSOVER %then %do;
        proc sort data = &work.subset;
            by CohortNumber CohortName CohortDescription &ParameterVar. &AnalyteVar. Combination TreatmentInPeriod;
        run;

        proc mixed data = &work.subset;
            by CohortNumber CohortName CohortDescription &ParameterVar. &AnalyteVar. Combination;
            class &UsubjidVar. TreatmentInPeriod;
            model &ResultVar. = TreatmentInPeriod / ddfm =  kr;
            /* fixme random &UsubjidVar.; */
            random &UsubjidVar. ;
            lsmeans TreatmentInPeriod / pdiff cl alpha = 0.1;
            estimate 'DDI Effect' TreatmentInPeriod -1 1 / cl alpha = 0.1;
            estimate 'DDI Effect Inv' TreatmentInPeriod 1 -1 / cl alpha = 0.1;
            ods output Estimates = meng_&C.&i;
        run;

        %end;

        %else %if %upcase(&StudyDesign.) = SEQUENTIAL %then %do;
        proc sort data = &work.subset;
            by CohortNumber CohortName CohortDescription &ParameterVar. &AnalyteVar. Combination TreatmentInPeriod;
        run;

        ods select Estimates;
        proc mixed data = &work.subset;
            by CohortNumber CohortName CohortDescription &ParameterVar. &AnalyteVar. Combination;
            class &UsubjidVar. &PeriodVar.;
            model &ResultVar. = &PeriodVar. / ddfm = kenwardroger;
            random &UsubjidVar.;
            lsmeans &PeriodVar. / pdiff cl alpha = 0.1;
            estimate 'DDI Effect' &PeriodVar. -1 1 / cl alpha = 0.1;
            estimate 'DDI Effect Inv' &PeriodVar. 1 -1 / cl alpha = 0.1;
            ods output Estimates =  meng_&C.&i;
        run;
        %end;
        /*different conditions ends*/

    /*FIX_MENG_1 does not exist*/
    %if %sysfunc(exist(meng_&C.&i)) %then %do;

    data mengestimate_&C.&i.;
    set  meng_&C.&i.;
    run;

    data meng_&C.&i.;
    set meng_&C.&i.;
    if not indexw(combination, "~vs~") then do;
        delete;
    end;
        if label = 'DDI Effect' then do;
        combination = strip(substr(combination, indexw(combination, "~vs~") + 5)) || " ~vs~ " || substr(combination, 1, indexw(combination, "~vs~") - 1);
    end;
    treatmentinperiodtext=substr(combination, 1, indexw(combination, "~vs~") - 1);
    CumulativeRatio=exp(estimate);
    date="%scan(%nrbquote(&datelist), &i., $)";
    run;

    data mengtest_&C.&i.;
    set meng_&C.&i.;
    run;

    %end; 
%end;



 data cumulative_&C.;  
    set 
    %do i=2 %to %sysfunc(countw(%nrquote(&reader),$));
        %if %sysfunc(exist(meng_&C.&i.)) %then %do;
            meng_&C.&i.
        %end;
    %end;    
    ;
    keep CohortNumber CohortDescription &ParameterVar. &AnalyteVar. Estimate combination treatmentinperiodtext CumulativeRatio date;
    run;


%end;/*end cohorts*/

/**FIX :check if Meng_1 exist**/
/*unite estimates output*/
data cumulative;
    set  
    %do C=1 %to &maxcohortnumber;
    cumulative_&C.
    %end;
    ;
run;

data mengcumulative;
set cumulative;
run;

/*clear missing results (including comparison groups out of cohorts)*/

data cumulative;
set cumulative;
if Estimate eq . then delete;
run;

proc sort data= cumulative;
    by CohortNumber CohortDescription &ParameterVar. &AnalyteVar. combination ;
run;    



/*******************STEP2: generate subject PE**************************************/
proc sql noprint;
select distinct treatmentinperiodtext into: pptrtlist separated by "$" from analysisdate;
quit;
%put pptrtlist=&pptrtlist;

/*exp result to get the pp xpt original result for calculating individual ratios*/
data analysisdate_exp;
set analysisdate;
&ResultVar.=exp(&ResultVar.);
run;


data analysistrt;
set analysisdate_exp;
%do m = 1 %to %sysfunc(countw(%quote(&pptrtlist.), $));
if Treatmentinperiodtext="%scan(%quote(&pptrtlist.), &m., $)"  then trtformat="TRT&m.";
%end;
run;

proc sort data=analysistrt;
by cohortdescription &ParameterVar. &AnalyteVar. usubjid mengcount pcdtc;
run;

proc transpose data=analysistrt out=trtwide LET;
by cohortdescription &ParameterVar. &AnalyteVar. usubjid mengcount pcdtc ;
id trtformat;
var PPSTRESN;
run;

%do a=1 %to %sysfunc(countw(%quote(&pptrtlist.), $));
    %do b=1 %to %sysfunc(countw(%quote(&pptrtlist.), $));

        %if &a<&b %then %do;
            /*subratio2 and comparison2 are reverted results of subratio1 and comparison1*/
            data trtwide&a.&b.;
              set trtwide;
                    Comparison1="%Scan(%nrquote(&pptrtlist.),&a,$) ~vs~ %Scan(%nrquote(&pptrtlist.),&b,$)";
                    SubRatio1=TRT&a/TRT&b;
                    Comparison2="%Scan(%nrquote(&pptrtlist.),&b,$) ~vs~ %Scan(%nrquote(&pptrtlist.),&a,$)";
                    SubRatio2=TRT&b/TRT&a;
              drop _name_ _label_;
            run;
        %end;
    %end;
%end;
/*ratio=0 ratiorev=.*/
data allsubtrt;
    set %do a=1 %to %sysfunc(countw(%quote(&pptrtlist.), $));
           %do b=1 %to %sysfunc(countw(%quote(&pptrtlist.), $));
                %if &a.<&b. %then %do;
                    trtwide&a.&b.
                %end;
            %end;
         %end;;

if SubRatio1 eq . then delete;
run;


/*fix plotting point label problem because point label has limit of 16 character, any usubjid
exceed 16 characters will be pretreated- leave last 16 character , and if first is - or _ then remove*/
data allsubtrt;
length label $16.;
set allsubtrt;
sublength=length(usubjid);
if sublength gt 16 then do;
    labelID=substr(usubjid,length(usubjid)-15,16);
    if substr(labelID,1,1)="-" or substr(labelID,1,1)="_"  then labelID=substr(labelID,length(labelID)-14,15);
end;
else do;
   labelID=usubjid;
end;
run;

/*concatenate ratio and revert ratio , comparison and revert comparison*/
/*allsubtrt split each comparison plot. subratio list all comparison in one table*/
data subratio;
set allsubtrt;
array comp(2) comparison1 comparison2;
array rt(2) subratio1 subratio2;
do i=1 to 2;
comparison=comp(i);
subratio=rt(i);
output;
end;
run;


/*******************STEP3: Plot cumulative PE and subject PE*****************************/


/*FIX: use parametervar*/
proc sql noprint; 
select distinct CohortDescription into : cohortforplot separated by "$" from cumulative;
select distinct &AnalyteVar. into : analyteforplot separated by "$" from cumulative;
select distinct &ParameterVar. into : parametersforplot separated by "$" from cumulative;
quit;
%put parametersforplot=&parametersforplot cohort for plot is &cohortforplot , analyte for plot is &analyteforplot;



%do a=1 %to %sysfunc(countw(%nrquote(&cohortforplot),$));
    %do b=1 %to %sysfunc(countw(%nrquote(&analyteforplot),$));
        %do c=1 %to %sysfunc(countw(%nrquote(&parametersforplot),$));

        /*STEP3-1: plot cumulative PE*/
        data &work.cumulative_&a._&b._&c;
        set cumulative;
        where CohortDescription="%scan(%nrquote(&cohortforplot),&a.,$)" and &AnalyteVar.="%scan(%nrquote(&analyteforplot),&b.,$)"
        and  &ParameterVar. ="%scan(%nrquote(&parametersforplot),&c.,$)" ;
        run;

        %SmCheckAndCreateFolder(
        BasePath = &OutputFolder.,
        FolderName =Integrity Tests
        );

        %SmCheckAndCreateFolder(
        BasePath = &OutputFolder.\Integrity Tests,
        FolderName =Cumulative
        );

        %SmCheckAndCreateFolder(
        BasePath = &OutputFolder.\Integrity Tests\Cumulative,
        FolderName =cohort&a.
        );

        %SmCheckAndCreateFolder(
        BasePath = &OutputFolder.\Integrity Tests\Cumulative\cohort&a.,
        FolderName =%scan(%nrquote(&analyteforplot),&b.,$)
        );

        %SmCheckAndCreateFolder(
        BasePath =&OutputFolder.\Integrity Tests\Cumulative\cohort&a.\%scan(%nrquote(&analyteforplot),&b.,$),
        FolderName =%scan(%nrquote(&parametersforplot),&c.,$)
        );
		
        ods listing  gpath = "&OutputFolder.\Integrity Tests\Cumulative\cohort&a.\%scan(%nrquote(&analyteforplot),&b.,$)\%scan(%nrquote(&parametersforplot),&c.,$)";
        ods graphics on / imagename = "cumulativePE_&a._&b._&c." noborder;
        filename grafout "&OutputFolder.\Integrity Tests\Cumulative\cohort&a.\%scan(%nrquote(&analyteforplot),&b.,$)\%scan(%nrquote(&parametersforplot),&c.,$)\Cumulative_&a._&b._&c..jpeg";
        goptions reset=all gsfname=grafout gsfmode=replace device=JPEG hsize=15 vsize=12;
        title "Cumulative Point Estimate vs Study Time Schedule ";
        title1 "Cohort:%scan(%nrquote(&cohortforplot),&a.,$)";
        title2 "Analyte:%scan(%nrquote(&analyteforplot),&b.,$)";
        title3 "Parameter: %scan(%nrquote(&parametersforplot),&c.,$)";

        axis1 value= (angle=45 f=simplex);
        proc gplot data= &work.cumulative_&a._&b._&c;
        plot CumulativeRatio*Date=combination/haxis=axis1;
        symbol interpol=spline value=triangle;
        run;
        quit;
        ods listing close;
        ods graphics off;



        /*STEP3-2: Plot individual PE*/
        data &work.subratio_&a._&b._&c;
        set subratio;
        where CohortDescription="%scan(%nrquote(&cohortforplot),&a.,$)" and &AnalyteVar.="%scan(%nrquote(&analyteforplot),&b.,$)"
        and  &ParameterVar. ="%scan(%nrquote(&parametersforplot),&c.,$)" ;
        run;

        ods listing  gpath = "&OutputFolder.\Integrity Tests\Cumulative\cohort&a.\%scan(%nrquote(&analyteforplot),&b.,$)\%scan(%nrquote(&parametersforplot),&c.,$)";
        ods graphics on / imagename = "Comp12_SubRatio_&a._&b._&c." noborder height=2300 width=2500 ;
        filename grafout "&OutputFolder.\Integrity Tests\Cumulative\cohort&a.\%scan(%nrquote(&analyteforplot),&b.,$)\%scan(%nrquote(&parametersforplot),&c.,$)\SubRatio_&a._&b._&c..jpeg";
        goptions reset=all gsfname=grafout gsfmode=replace device=JPEG hsize=15 vsize=12;
        title "Individual Ratio vs Study Time Schedule ";
        title1 "Cohort:%scan(%nrquote(&cohortforplot),&a.,$)";
        title2 "Analyte:%scan(%nrquote(&analyteforplot),&b.,$)";
        title3 "Parameter: %scan(%nrquote(&parametersforplot),&c.,$)";


        symbol value=triangle pointlabel=(height=7pt '#labelID');
        axis1 value= (angle=45 f=simplex);
        proc gplot data= &work.subratio_&a._&b._&c;
        plot subratio*PCDTC=comparison/haxis=axis1;
        run;
        quit;
        ods listing close;
        ods graphics off;


        /*STEP 3-3 plot indiviudal PE by treatment*/
        data &work.SubRatioTrt_&a._&b._&c;
        set allsubtrt;
        where CohortDescription="%scan(%nrquote(&cohortforplot),&a.,$)" and &AnalyteVar.="%scan(%nrquote(&analyteforplot),&b.,$)"
        and  &ParameterVar. ="%scan(%nrquote(&parametersforplot),&c.,$)" ;
        run;

        ods listing  gpath = "&OutputFolder.\Integrity Tests\Cumulative\cohort&a.\%scan(%nrquote(&analyteforplot),&b.,$)\%scan(%nrquote(&parametersforplot),&c.,$)";
        ods graphics on / imagename = "Comp1_SubRatioByTrt_&a._&b._&c" noborder height=2300 width=2500 ;
        filename grafout "&OutputFolder.\Integrity Tests\Cumulative\cohort&a.\%scan(%nrquote(&analyteforplot),&b.,$)\%scan(%nrquote(&parametersforplot),&c.,$)\Comp1SubRatio_&a._&b._&c..jpeg";
        goptions reset=all gsfname=grafout gsfmode=replace device=JPEG hsize=15 vsize=12;
        title "Individual Ratio vs Study Time Schedule ";
        title1 "Cohort:%scan(%nrquote(&cohortforplot),&a.,$)";
        title2 "Analyte:%scan(%nrquote(&analyteforplot),&b.,$)";
        title3 "Parameter: %scan(%nrquote(&parametersforplot),&c.,$)";

        symbol value=triangle pointlabel=(height=9pt '#labelID');
        axis1 value= (angle=45 f=simplex);
        proc gplot data=&work.SubRatioTrt_&a._&b._&c;
        plot subratio1*PCDTC=comparison1/haxis=axis1;
        run;
        quit;
        ods listing close;
        ods graphics off;


        ods listing  gpath = "&OutputFolder.\Integrity Tests\Cumulative\cohort&a.\%scan(%nrquote(&analyteforplot),&b.,$)\%scan(%nrquote(&parametersforplot),&c.,$)";
        ods graphics on / imagename = "Comp2_SubRatioByTrt_&a._&b._&c" noborder height=2300 width=2500 ;
        filename grafout "&OutputFolder.\Integrity Tests\Cumulative\cohort&a.\%scan(%nrquote(&analyteforplot),&b.,$)\%scan(%nrquote(&parametersforplot),&c.,$)\Comp2SubRatio_&a._&b._&c..jpeg";
        goptions reset=all gsfname=grafout gsfmode=replace device=JPEG hsize=15 vsize=12;
        title "Individual Ratio vs Study Time Schedule ";
        title1 "Cohort:%scan(%nrquote(&cohortforplot),&a.,$)";
        title2 "Analyte:%scan(%nrquote(&analyteforplot),&b.,$)";
        title3 "Parameter: %scan(%nrquote(&parametersforplot),&c.,$)";

        symbol value=triangle pointlabel=(height=9pt '#labelID');
        axis1 value= (angle=45 f=simplex);
        proc gplot data=&work.SubRatioTrt_&a._&b._&c;
        plot subratio2*PCDTC=comparison2/haxis=axis1;
        run;
        quit;
        ods listing close;
        ods graphics off;


        %end;
    %end;
%end;


%end;/*sequential and crossover only*/
%END;
%mend IntegrityCumu_SeqCro;
%IntegrityCumu_SeqCro;




/*integrity test 3 ends*/



/*Meng Xu added- Scatter plot for sequential and crossover studies starts*/
/*use original PPSTRESN to generate scatter plot*/



%macro scatterplot;
%IF &SCATTERPLOT=1 %THEN %DO;
%if %upcase(&StudyDesign.) NE PARALLEL %then %do;
    data &work.scatterplot;
        set &input.;
    OrgPPSTRESN=EXP(PPSTRESN);
    run;
    %put meng scatterplot;

    /*intermediate dataset generated from &input.and do data cleaning by leaving subsets with AUCxx and Cmax only*/
    data &work.scatterplot1;
        set &work.scatterplot(where=(find(upcase(&ParameterVar.), "AUC") or find(upcase(&ParameterVar.), "CMAX") or 
                                 find(upcase(&ParameterVar.), "ACTAU") or find(upcase(&ParameterVar.), "ACINF") ));
    keep combination TreatmentInPeriodText ARM USUBJID &ParameterVar. &AnalyteVar. PPSTRESN OrgPPSTRESN VISIT CohortNumber CohortName CohortDescription;
    run;

    proc freq data=&work.scatterplot1 norprint;
        tables treatmentinperiodtext*&ParameterVar.*&AnalyteVar.*Cohortnumber;
    run;

    /*create macro variables*/
    proc sql noprint;
        select distinct cohortDescription into: sccohort separated by "$" from &work.scatterplot1;
        select distinct &AnalyteVar. into: scanalyte separated by "$" from &work.scatterplot1;
        select distinct &ParameterVar. into: scparameter separated by "$" from &work.scatterplot1;
    quit;
    %put scatter plot cohort:&sccohort, analyte:&scanalyte, parameter: &scparameter;

    %do a=1 %to %sysfunc(countw(%nrquote(&sccohort),$));
        %do b=1 %to %sysfunc(countw(%nrquote(&scanalyte),$));
            %do c=1 %to %sysfunc(countw(%nrquote(&scparameter),$));

            /*subset data by cohort, analyte and parameters*/
            data &work.subsetscatter_&a._&b._&c.;
            set &work.scatterplot1(where=(cohortdescription="%scan(%nrquote(&sccohort),&a,$)" and &analyteppvar="%scan(%nrquote(&scanalyte),&b,$)" and &parametervar.="%scan(%nrquote(&scparameter),&c,$)"));
            run;


                     
            proc sql noprint;
            select min(OrgPPSTRESN) into:minresult from &work.subsetscatter_&a._&b._&c.;
            select max(OrgPPSTRESN) into:maxresult from &work.subsetscatter_&a._&b._&c.;
            select ((max(OrgPPSTRESN)-min(OrgPPSTRESN))/n(OrgPPSTRESN)) into: each from &work.subsetscatter_&a._&b._&c.;
            quit;
            %put min=&minresult, max=&maxresult, each=&each;    

            proc template;
            define statgraph scatterplot;
                begingraph;
                entrytitle "Discrete Scatter Plot for Parameter:%scan(%nrquote(&scparameter),&c,$)";
                entrytitle "&Studyid Cohort:%scan(%nrquote(&sccohort),&a,$)Analyte:%scan(%nrquote(&scanalyte),&b,$)";
               
                    layout overlay /
                        /*xaxisopts=(griddisplay=on gridattrs=(color=lightgray) label="TREATMENT" offsetmin=0.2 offsetmax=0.2 discreteopts=(colorbands=even colorbandsattrs=(transparency=0.6 color=lightgray)))*/
                        xaxisopts=(griddisplay=on gridattrs=(color=lightgray) label="TREATMENT" offsetmin=0.2 offsetmax=0.2 )
                        
                        yaxisopts=(griddisplay=on gridattrs=(color=lightgray) label="PK RESULT(PPSTREN)" 
                                   linearopts=(tickvaluesequence=(start=&minresult end=&maxresult increment=&each)));/*macro max and min and increment*/           
                        scatterplot x=treatmentinperiodtext y=OrgPPSTRESN/ primary=true group=USUBJID name="scatter" /*datalabel=USUBJID*/;/*ENABLE to show the subject label on plot*/
                        seriesplot  x=treatmentinperiodtext y=OrgPPSTRESN/ group=USUBJID name="series" lineattrs=(thickness=0.1);            
                        discretelegend  "scatter" /location=outside halign=center valign=bottom title="Subject ID (USUBJID)" border=true;
                    endlayout;
                endgraph;
            end;
            run;

            %** Get the number of observations **;
            %SmGetNumberOfObs(Input =&work.subsetscatter_&a._&b._&c.);
/*            %** Check if there is any usuable data **;*/
/*            %SmContainsMissing(Input = &work.estimates_&i._&j.);*/

            %if &NumberOfObs. >= 1 %then %do;
                    %SmCheckAndCreateFolder(
                    BasePath = &OutputFolder.,
                    FolderName = Scatter Plot
                    );

                    %SmCheckAndCreateFolder(
                    BasePath = &OutputFolder.\Scatter Plot,
                    FolderName = Cohort&a.
                    );
                    %SmCheckAndCreateFolder(
                    BasePath = &OutputFolder.\Scatter Plot\Cohort&a.,
                    FolderName = %scan(%nrquote(&scanalyte),&b,$)
                    );

                    options date number;
                    ods listing gpath="&OutputFolder.\Scatter Plot\Cohort&a.\%scan(%nrquote(&scanalyte),&b,$)";
                    ods graphics on/noborder imagefmt=png imagename="SP_&a._&b._&c._%scan(%nrquote(&scparameter),&c,$)" height=2500 width=2300;
                        proc sgrender data=&work.subsetscatter_&a._&b._&c. template=scatterplot;run;
                    ods listing close;
                    ods graphics off;
            %end;

            %end;
        %end;
    %end;
%end;
%END;
%mend scatterplot;
%scatterplot;


/* Meng add min and max to estimates for metaanalysis forest plot*/
/*for calculating*/
data &work.IndividualPk1(keep=USUBJID CohortDescription &SequenceVar &PeriodVar. &AnalyteVar. 
            &PpSpecimenVar. TreatmentInPeriodText &ResultVar. &ParameterVar.);
set &input.;
 Orgresult=exp(&ResultVar.);  
run;


%SubjectRatio(
DSN=individualpk1,
WIDEDSN=widepk,
TRT=treatmentinperiodtext,
Result=OrgResult,
OUTPUT=EstimateMinMax, 
ORDER=CohortDescription  &AnalyteVar. &ParameterVar. &UsubjidVar.);

/* Meng add min and max to estimates for metaanalysis forest plot*/
/*for calculating*/
data &work.IndividualPk1(keep=USUBJID CohortDescription &SequenceVar &PeriodVar. &AnalyteVar. 
            &PpSpecimenVar. TreatmentInPeriodText &ResultVar. &ParameterVar.);
set &input.;
 Orgresult=exp(&ResultVar.);  
run;


%SubjectRatio(
DSN=individualpk1,
WIDEDSN=widepk,
TRT=treatmentinperiodtext,
Result=OrgResult,
OUTPUT=SubPkRatio, 
ORDER=CohortDescription  &AnalyteVar. &ParameterVar. &UsubjidVar.);




data subpkratio1(keep=CohortDescription &AnalyteVar. &ParameterVar. &UsubjidVar. subratio1 comparison1 rename=(subratio1=subratio comparison1=combination));
set subpkratio;
run;

data subpkratio2(keep=CohortDescription &AnalyteVar. &ParameterVar. &UsubjidVar. subratio2 comparison2 rename=(subratio2=subratio comparison2=combination));
set subpkratio;
run;
data subpkratio12;
set subpkratio1 subpkratio2;
run;

/*calculate min and max by cohort, analyte ,parameter and combination for each study*/
proc sort data=SubPkRatio12;
by cohortdescription &AnalyteVar. &ParameterVar.  combination;
run;

proc summary data=SubPkRatio12 min max ;
by cohortdescription &AnalyteVar. &ParameterVar. combination;
output out=min_max12;
class cohortdescription &AnalyteVar. &ParameterVar.  combination;
var subratio;
run;

data min_max12(where=(_STAT_="MIN" or _STAT_="MAX") drop=_TYPE_ _FREQ_ );
set min_max12;
run;

proc sort data=min_max12 out=minmaxout12 nodupkey;
by CohortDescription &AnalyteVar. &ParameterVar.  combination _STAT_ subratio ;
run;

/*prepare wide format for data merge*/
proc sort data=minmaxout12;
by  CohortDescription &AnalyteVar. &ParameterVar.  combination ;
run;

proc transpose data= minmaxout12 out=minmaxoutwide12;
by  CohortDescription &AnalyteVar. &ParameterVar.  combination;
id _STAT_;
var SubRatio;
run;

/*merge mixed model results and min and max data together*/

proc sort data=estimates;
by CohortDescription &AnalyteVar. &ParameterVar.  combination ;

proc sort data=minmaxoutwide12;
by CohortDescription &AnalyteVar. &ParameterVar.  combination ;

data estminmax(drop=_NAME_);
merge estimates(in=a) minmaxoutwide12(in=b); 
by CohortDescription &AnalyteVar. &ParameterVar.  combination ;
if a;
run;



libname pkOutput "&OutputFolder.\estimates";

data pkOutput.estminmax;
    set estminmax;
run;

libname pkOutput CLEAR;



%mend;



