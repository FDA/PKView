%*****************************************************************************************;
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
%**     Forest plots and PK summary tables                                              **;
%**                                                                                     **;
%** Created by:                                                                         **;
%**     Jens Stampe Soerensen  (2013/2014)                                              **;
%**                                                                                     **;
%*****************************************************************************************;

%macro PK_Analysis_SummarySimple(
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

%** Get the mean, std, min, max and median **;
proc summary data = &Input. nway missing;
    class CohortNumber CohortDescription TreatmentInPeriod TreatmentInPeriodText &AnalyteVar. &ParameterVar.;
    var &ResultVar.;
    output out = &work.summary_mean (drop = _freq_ _type_)
                    mean = mean 
                    std = std 
    ;
run;

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
    proc sort data = &Input.;
        by CohortNumber CohortName CohortDescription &ParameterVar. &AnalyteVar. Combination TreatmentInPeriod;
    run;
    
    *ods select Estimates;
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

        %** Analysis **;
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


%mend;


