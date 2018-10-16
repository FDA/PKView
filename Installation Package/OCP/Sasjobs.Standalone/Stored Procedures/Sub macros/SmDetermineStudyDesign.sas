%*****************************************************************************************;
%**                                                                                     **;
%** Determine the study design of a clinical PK study (intrinsic / extrinsic)           **;
%**                                                                                     **;
%** Input:                                                                              **;
%**     InputDm             -       Input DM dataset                                    **;
%**     UsubjidVar          -       Name of the usubjid variable from DM                **;
%**     SequenceVar         -       Name of the sequence variable from DM               **;
%**     InputPp             -       Input PP dataset                                    **;
%**     AnalyteVar          -       Name of the analyte variable from PP                **;
%**     ParameterVar        -       Name of the PK parameter variable from PP           **;
%**     PeriodVar           -       Name of the period variable from PP                 **;
%**     InputEx             -       Input EX dataset                                    **;
%**     ExTrtVar            -       Name of the treatment variable from EX              **;
%**     ExDataVar           -       Name of the date variable from EX                   **;
%**     StudyArea           -       Either Intrinsic or Extrinsic if known              **;
%**                                                                                     **;
%** Output:                                                                             **;
%**     Macro variable called StudyDesign (Unknown, Sequential, Parallel, Crossover)    **;
%**                                                                                     **;
%** Created by:                                                                         **;
%**     Jens Stampe Soerensen  (2013/2014)                                              **;
%**                                                                                     **;
%*****************************************************************************************;

%macro SmDetermineStudyDesign(
    InputDm = ,
    UsubjidVar = ,
    SequenceVar = ,
    InputPp = ,
    AnalyteVar = ,
    ParameterVar = ,
    PeriodVar = ,
    InputEx = ,
    ExTrtVar = ,
    ExDateVar = ,
    StudyArea = 
);

%** Global macro variables **;
%global studydesign NumberOfCohorts NumberOfSequences MinNumberOfPeriods MaxNumberOfPeriods;
%let studyDesign = UNKNOWN; /* Default value */

%** Local macro variables **;
%local i j k h l m n;

%** Handle groups anywhere else than DM (SUPPDM/SC) **;
%SmParallelGrouping(
    Input = &work.dm,
    UsubjidVar = &UsubjidVar,
    SequenceVar = &SequenceVar,
    UseSuppdm = &UseSuppdm,
    DataPath = &InputDm
);

%** Clean-up any unwanted sequences (Screening / Follow-up) **;
%if &SequenceVar ne %then %do;
    data &work.dm;
        set &work.dm(where = (&SequenceVar ne "SCREEN FAILURE"));

        %** Anything called screen / screening present? **;
        if index(upcase(&SequenceVar), "SCREENING") then do;
            %** Identify potential separators right after Screening **;
            loc_scr = index(upcase(&SequenceVar), "SCREENING");
            sep_scr = compress(substr(&SequenceVar, loc_scr + 9, 2));

            %** Identify the separator **;
            if index(sep_scr, ":") then do;
                sep_scr = ":";
            end;
            else if index(sep_scr, ";") then do;
                sep_scr = ";";
            end;
            else if index(sep_scr, "/") then do;
                sep_scr = "/";
            end;
            else if index(sep_scr, "-") then do;
                sep_scr = "-";
            end;
            else if index(sep_scr, "&") then do;
                sep_scr = "&";
            end;
            else if index(sep_scr, "+") then do;
                sep_scr = "+";
            end;

            %** Remove information from the separtor and forward **;
            &SequenceVar = substr(&SequenceVar, index(&SequenceVar, strip(sep_scr)) + 1);
        end;
        %** Anything called Follow-up / Follow up present? **;
        if index(upcase(&SequenceVar), "FOLLOW-UP") or index(upcase(&SequenceVar), "FOLLOW UP") then do;
            %** Identify potential separators right before Follow-Up **;
            if index(upcase(&SequenceVar), "FOLLOW-UP") then do;
                loc_fu = index(upcase(&SequenceVar), "FOLLOW-UP");
                sep_fu = compress(substr(&SequenceVar, loc_fu - 2, 2));
            end;
            else do;
                loc_fu = index(upcase(&SequenceVar), "FOLLOW UP");
                sep_fu = compress(substr(&SequenceVar, loc_fu - 2, 2));
            end;

            %** Identify the separator **;
            if index(sep_fu, ":") then do;
                sep_fu = ":";
            end;
            else if index(sep_fu, ";") then do;
                sep_fu = ";";
            end;
            else if index(sep_fu, "/") then do;
                sep_fu = "/";
            end;
            else if index(sep_fu, "-") then do;
                sep_fu = "-";
            end;
            else if index(sep_fu, "&") then do;
                sep_fu = "&";
            end;
            else if index(sep_fu, "+") then do;
                sep_fu = "+";
            end;

            %** Remove the information from the separator and onwards **;
            if index(upcase(&SequenceVar), "FOLLOW-UP") then do;
                _temp_ = strip(substr(&SequenceVar, 1, index(&SequenceVar, scan(&SequenceVar, -2, strip(sep_fu)))-1));
                &SequenceVar = substr(_temp_, 1, length(_temp_) - 1);
            end;
            else do;
                _temp_ = strip(substr(&SequenceVar, 1, index(&SequenceVar, scan(&SequenceVar, -1, strip(sep_fu)))));
                &SequenceVar = substr(_temp_, 1, length(_temp_) - 1);
            end;
        end;

        %** Remove leading and trailing blanks **;
        &SequenceVar = strip(&SequenceVar);

        %** Clean-up **;
        drop _t: sep_: loc_: ;
        keep &UsubjidVar &SequenceVar;
    run;
%end;

%** FIXME: not a good way to output dm to SmDetermineStudyDesignJiaxiang, merge both scripts in the future **;
data &work.dm_cleaned;
set &work.dm;run;

%** If all the three datasets are present use EX as the driver for the study design determination **;
%if &UseEx.=1 and %sysfunc(fileexist(&InputDm.)) and %sysfunc(fileexist(&InputPp.)) and %sysfunc(fileexist(&InputEx.)) %then %do;
    %*****************************************************;
    %**                                                 **;
    %**                 Data merging                    **;
    %**                                                 **;
    %*****************************************************;
    %put using ex;
    %** Sort and trim the datasets **;
    %if &UsubjidVar ne %then %do;
        proc sort data = &work.dm(keep = &UsubjidVar &SequenceVar);
            by &UsubjidVar;
        run;

        proc sort data = &work.pp(keep = &UsubjidVar &ParameterVar &AnalyteVar &PeriodVar.);
            by &UsubjidVar;
        run;

        proc sort data = &work.ex(keep = &UsubjidVar &ExTrtVar &ExDateVar.);
            by &UsubjidVar;
        run;

        %** Merge **;
        data &work.PpDm;
            merge   &work.pp (in = a)
                    &work.dm (in = b);
            by &UsubjidVar;
            if a and b;
        run;

        data &work.ExDm;
            merge   &work.ex (in = a)
                    &work.dm (in = b);
            by &UsubjidVar;
            if a and b;
        run;
    %end;
    
    %*****************************************************;
    %**                                                 **;
    %**         Number of sequences and periods         **;
    %**                                                 **;
    %*****************************************************;
    %let sequence_tot = 0;
    %if &SequenceVar ne %then %do;
        %** Get the unique sequences and the number of unique sequences **;
        proc sort data = &work.dm (keep = &SequenceVar) 
                   out = &work.sequences nodupkey;
            by &SequenceVar;
        run;

        data _null_;
            set &work.sequences(where = (strip(&SequenceVar) ne "SCREEN FAILURE")) end = eof;
            by &SequenceVar;
            length sequence_list $800;
            retain sequence_list;

            if _n_ = 1 then do;
                sequence_list = strip(&SequenceVar);
            end;
            else do;
                sequence_list = strip(sequence_list) || " || " || strip(&SequenceVar);
            end;

            if eof then do;
                call symputx("sequence_list", sequence_list, "G");
                call symputx("sequence_tot", _n_, "G");
            end;
        run;
    %end;
    
    %** If the period is missing from the dataset **;
    %if &PeriodVar eq and &UsubjidVar ne %then %do;
        proc sort data = &work.PpDm;
            by &UsubjidVar &AnalyteVar &ParameterVar;
        run;

        data &work.PpDm;
            set &work.PpDm;
            by &UsubjidVar &AnalyteVar &ParameterVar;
            length PeriodVar $20;
            retain cnt;

            %** Add the period content **;
            if first.&ParameterVar then do;
                cnt = 1;
            end;
            else do;
                cnt + 1;
            end;
            PeriodVar = cat("Period ", cnt);
            
            %** Clean-up **;
            drop cnt;
        run;
        %let PeriodVar = PeriodVar;
    

        %** Get the unique periods and the number of unique periods **;
        proc sort data = &work.PpDm (keep = &PeriodVar.) 
                   out = &work.periods nodupkey; 
            by &PeriodVar;
        run;    

        data _null_;
            set &work.periods end = eof;
            by &PeriodVar;
            length period_list $800;
            retain period_list period_num;

            if _n_ = 1 then do;
                period_list = strip(&PeriodVar.);
            end;
            else do;
                period_list = strip(period_list) || " || " || strip(&PeriodVar.);
            end;
            period_num + 1;

            if eof then do;
                call symputx("period_list", period_list, "G");
                call symputx("period_num", period_num, "G");
            end;
        run;
    %end;
    %else %do;
        %let Period_Num = 1;
    %end;
    
    %*****************************************************;
    %**                                                 **;
    %**                 Data clean-up                   **;
    %**                                                 **;
    %*****************************************************; 
    %** Handle missing dates in EX **;
    %if &UsubjidVar ne %then %do;
        data &work.ExDm;
            set &work.ExDm;
            lagsubjid = lag(&UsubjidVar.);
            %if &ExDateVar ne %then %do;
                lagdate = lag(&ExDateVar.);
            %end;
        run;

        data &work.w1;
            set &work.ExDm;
            %** If the dates is missing use the previous date as the actually date           **;
            %** This prevents multiple periods to be created when they are actually the same **;
            if strip(&ExDateVar.) = "" and &UsubjidVar = lagsubjid then do;
                &ExDateVar = lagdate;
            end;

            %** Dont consider time in exposure **;
            ExDate = scan(&ExDateVar., 1, "T");

            %** Add a counter to count the number exposures per subjects (see below for more info) **;
            cntvar = 1;
        run;

        %** Determine the number of average exposures per group **;
        proc summary data = &work.w1 nway missing;
            class &UsubjidVar &SequenceVar ;
            var cntvar;
            output out = &work.ex_sum1 (drop = _type_ _freq_) sum = sum_cnt;
        run;
    
        proc summary data = &work.ex_sum1 nway missing;
            class &SequenceVar;
            var sum_cnt;
            output out = &work.ex_sum2 (drop = _type_ _freq_) mean = mean_cnt;
        run;
    
        %** Merge the two and create thus create a dataset containing the subjects with enough exposure measurements **;
        %if &SequenceVar ne %then %do;
            proc sort data = &work.ex_sum1;
                by &SequenceVar;
            run;

            data &work.ex_sum3(drop = sum_cnt mean_cnt);
                merge   &work.ex_sum1(in = a)
                        &work.ex_sum2(in = b);
                by &SequenceVar;

                %** Clean-up rule **;
                if a and b and sum_cnt >= mean_cnt/2;
            run;

            %** Inner join this dataset with the exposure dataset to remove unwanted subjects **;
            proc sort data = &work.w1(drop = cntvar);
                by &UsubjidVar &SequenceVar;
            run;

            proc sort data = &work.ex_sum3;
                by &UsubjidVar &SequenceVar;
            run;

            data &work.w1;
                merge   &work.w1 (in = a)
                        &work.ex_sum3 (in = b);
                by &UsubjidVar &SequenceVar;
                if b;
            run;
        %end;
    %end;
    
    %*****************************************************;
    %**                                                 **;
    %**             Process the data                    **;
    %**                                                 **;
    %*****************************************************;

    %if &UsubjidVar ne %then %do;
        %** For each sequence determine the actual treatment **;
        proc sort data = &work.w1;
            by &SequenceVar &UsubjidVar ExDate &ExTrtVar;
        run;

        %** Combine treatments on the same date **;
        data &work.w2;
            length trt_list prev_trt $800;
            set &work.w1(keep = &UsubjidVar &SequenceVar &ExTrtVar ExDate);
            by &SequenceVar &UsubjidVar ExDate;
            retain trt_list;

            prev_trt = lag(&ExTrtVar.);
            if first.&UsubjidVar then do;
                prev_trt = "";
            end;

            if first.ExDate then do;
                trt_list = &ExTrtVar;
            end;
            else if &ExTrtVar ^= prev_trt then do;
                trt_list = strip(trt_list) || " + " || strip(&ExTrtVar.);
            end;

            if last.ExDate then do;
                output;
            end;
        run;

        %** Combine multiple days of treatment into one **;
        data &work.w3;
            set &work.w2;
            by &SequenceVar &UsubjidVar;
            length extrt_list $800;
            retain CurrCnt;

            %** Add previous treatment in the sequence before **;
            prev_trt = lag(trt_list);
            if first.&UsubjidVar then do;
                prev_trt = trt_list;
                cnt = 0;
            end;

            %** Find the unique treatments where S -> Single dose, M -> Multiple dose **;
            if trt_list = prev_trt then do;
                cnt + 1;
                CurrCnt = cnt;
            end;
            else if trt_list ^= prev_trt then do;
                cnt = 1;
                if CurrCnt > 1 then do;
                    extrt_list = strip(prev_trt) || "_M";
                end;
                else do;
                    extrt_list = strip(prev_trt) || "_S";
                end;
                CurrCnt = cnt;
                output;
            end;
            if last.&UsubjidVar then do;
                if trt_list ^= prev_trt then do;
                    extrt_list = strip(trt_list) || "_S";
                    output;
                end;
                else if first.&UsubjidVar = last.&UsubjidVar then do;
                    extrt_list = strip(trt_list) || "_S";
                    output;
                end;
                else do;
                    extrt_list = strip(trt_list) || "_M";
                    output;
                end;
            end;
            
            %** Clean-up **;
            drop currcnt cnt &ExTrtVar prev_trt trt_list;
        run;

        %** Create the extrt list (list of all unique treatment) **;
        %global ExTrt_list;
        proc sql noprint;
            select distinct
                extrt_list
            into
                :ExTrt_list separated by " @ "
            from
                &work.w3
            ;
        quit;

        %** Create the trtseq list (list unique treatments per arm) **;
        proc sort data = &work.w3 out = &work.w4 nodupkey;
            by &SequenceVar extrt_list;
        run;

        data &work.w5;
            set &work.w4 end = eof;
            by &SequenceVar extrt_list;
            length trtseq_list trtseq trtseq_list_orig trtseq_orig $3000;
            retain trtseq_list trtseq trtseq_list_orig trtseq_orig trtcnt;

            if first.&SequenceVar then do;
                trtseq = strip(extrt_list);
                trtseq_orig = substr(strip(trtseq), 1, length(strip(extrt_list))-2);
                trtcnt = 1;
            end;
            else do;
                trtseq = strip(trtseq) || " @ " || strip(extrt_list);
                trtseq_orig = strip(trtseq_orig) || " @ " || substr(strip(extrt_list), 1, length(strip(extrt_list))-2);;
                trtcnt + 1;
            end;

            if last.&SequenceVar then do;
                if TrtSeq_list ne "" then do;
                    TrtSeq_list = strip(TrtSeq_list) || " || " || strip(trtseq);
                    TrtSeq_list_orig = strip(TrtSeq_list_orig) || " || " || strip(trtseq_orig);
                end;
                else do;
                    TrtSeq_list = strip(trtseq);
                    TrtSeq_list_orig = strip(trtseq_orig);
                end;
                output;
            end;
            if eof then do;
                call symputx("TrtSeq_list", TrtSeq_list, "G");
                call symputx("TrtSeq_Num", trtcnt, "G");
                call symputx("TrtSeq_list_orig", TrtSeq_list_orig, "G");
            end;
        run;
    %end;
    
    %** Get PTbyAllRegimentSession **;
    %let hit = 0;
    %let separator = @;
    %let UniqueSequences = ;
    %** Loop for all sequences **;
    %do i = 1 %to %sysfunc(countw(%nrbquote(&TrtSeq_list_orig.), ||));

        %** Loop for all treatments within the sequence **;
        %let CurrentSequence = %scan(%nrbquote(&TrtSeq_list_orig.), &i., ||);
        %put Current Sequence = &CurrentSequence;
        %do j = 1 %to %sysfunc(countw(%nrbquote(&CurrentSequence.), &Separator.));

            %** Is the treatment already in the list? **;
            %let CurrentTreatment = %scan(%nrbquote(&CurrentSequence.), &j., &Separator.);
            %put Current Treatment = &CurrentTreatment;
            %if %nrbquote(&UniqueSequences.) ne %then %do;
                %let k = 0;
                %let hit = 0;
                %do %until(&k = %sysfunc(countw(%nrbquote(&UniqueSequences.),||)));
                    %** Match found! **;
                    %if %nrbquote(&CurrentTreatment.) eq %nrbquote(%scan(%nrbquote(&UniqueSequences.), %eval(&k.+1), ||)) %then %do;
                        %let hit = 1;
                    %end;
                    %let k = %eval(&k + 1);
                %end;

                %** If not add it **;
                %if &hit = 0 %then %do;
                    %let UniqueSequences = &UniqueSequences.||&CurrentTreatment;
                %end;
            %end;
            %** If not add it **;
            %else %do;
                %let UniqueSequences = &CurrentTreatment;
            %end;
        %end;
    %end;
    %let NumberOfUniqueSequences = %sysfunc(countw(%quote(&UniqueSequences.),||));  

    %** Identify how many groups there really are **;
    %let regiment_chk = 0;
    %if &UsubjidVar ne %then %do;
        data &work.w6;
            set &work.w5;
            length UniqueSequences $500;
            UniqueSequences = "&UniqueSequences.";

            %** Count the unique cohort number **;
            counter = 0;
            do i = 1 to &NumberOfUniqueSequences;
                do j = 1 to countw(TrtSeq_orig, "&Separator.");
                    if strip(scan(UniqueSequences, i, "||")) = strip(scan(TrtSeq_orig, j, "&Separator.")) then do;
                        counter + i;
                    end;
                end;
            end;
            
            %** Clean - up **;
            drop i j;
        run;

        %** Create the regiment **;
        proc sort data = &work.w6;
            by counter TrtSeq_orig;
        run;

        data &work.w6;
            set &work.w6 end = eof;
            by counter TrtSeq_orig;
            length PTbyAllRegimentSession $40;
            retain PTbyAllRegimentSession;

            %** Assign **;
            if first.counter then do;
                cnt + 1;
                if _n_ = 1 then do;
                    PTbyAllRegimentSession = strip(cnt);
                end;
                else do;
                    PTbyAllRegimentSession = strip(PTbyAllRegimentSession) || " || " || strip(cnt);
                end;
            end;

            if eof then do;
                call symputx("PTbyAllRegimentSession", PTbyAllRegimentSession, "G");
            end;
        run;

        %** Check the treatments in the each arm. If they are the same set a check  **;
        %** The same treatment indicates a parallel study - see below for more      **;
        proc sort data = &work.w3 out = &work.w7 nodupkey;
            by &SequenceVar extrt_list;
        run;

        proc sort data = &work.w7;
            by &SequenceVar ExDate;
        run;

        data _null_;
            set &work.w7 end = eof;
            by &SequenceVar ExDate;
            length armregimen armregimen_list trtseq curr_regimen $800;
            retain armregimen armregimen_list trtseq curr_regimen regiment_chk;

            if first.&SequenceVar then do;
                trtseq = strip(extrt_list);
                armregimen = substr(strip(trtseq), 1, length(strip(extrt_list))-2);
            end;
            else do;
                trtseq = strip(extrt_list);
                armregimen = strip(armregimen) || " @ " || substr(strip(extrt_list), 1, length(strip(extrt_list))-2);
            end;

            if last.&SequenceVar then do;
                if armregimen_list ne "" then do;
                    armregimen_list = strip(armregimen_list) || " || " || strip(armregimen);
                    if strip(curr_regimen) = strip(armregimen) then do;
                        regiment_chk = 1;
                    end;
                    else do;
                        regiment_chk = 0;
                    end;
                end;
                else do;
                    armregimen_list = strip(armregimen);
                    curr_regimen = strip(armregimen);
                end;
                output;
            end;
            if eof then do;
                call symputx("armregimen", armregimen_list, "G");
                call symputx("regiment_chk", regiment_chk, "G");
            end;
        run;
    %end;
    
    %*****************************************************;
    %**                                                 **;
    %**             Determine study design              **;
    %**                                                 **;
    %*****************************************************;
    %put Sequence tot = &Sequence_tot;
    %put Period num = &Period_Num;
    %put By all regiment = %sysfunc(countw(%nrbquote(&PTbyAllRegimentSession.), ||)) - %nrbquote(&PTbyAllRegimentSession.);
    %if &Sequence_tot = 1 and &Period_Num = 1 %then %do;
        %let studydesign = Sponsor Error;
    %end;
    %else %if &Regiment_chk = 1 and &Sequence_tot > 1 %then %do;
        %let studydesign = Parallel;
    %end;
    %else %if &Sequence_tot > %sysfunc(countw(%nrbquote(&PTbyAllRegimentSession.), ||)) %then %do;
        %let studydesign = Crossover;
    %end;
    %else %if &Sequence_tot = %sysfunc(countw(%nrbquote(&PTbyAllRegimentSession.), ||)) %then %do;
        %let studydesign = Sequential;
    %end;
    %else %do;
        %let studydesign = Unknown;
    %end;
%end;
%** If there is no EX then purely go on DM **;
%else %if %sysfunc(fileexist(&InputDm.)) and %sysfunc(fileexist(&InputPp.)) %then %do;
    %*****************************************************;
    %**                                                 **;
    %**                 Data merging                    **;
    %**                                                 **;
    %*****************************************************;

    %if &UsubjidVar ne %then %do;
        %** Sort and trim the datasets **;
        proc sort data = &work.dm(keep = &UsubjidVar &SequenceVar);
            by &UsubjidVar ;
        run;

        proc sort data = &work.pp(keep = &UsubjidVar &ParameterVar &AnalyteVar &PeriodVar.);
            by &UsubjidVar;
        run;

        %** Merge **;
        data &work.PpDm;
            merge   &work.pp (in = a)
                    &work.dm (in = b);
            by &UsubjidVar;
            if a and b;
        run;
    %end;
    
    %*********************************************************;
    %**                                                     **;
    %**             Period and sequences                    **;
    %**                                                     **;
    %*********************************************************;
    %** Modify the analysis dataset to show periods and handle analytes with groups in **;
    %if %SYMEXIST(PeriodVar) and %length(&PeriodVar) ne 0  and %length(&UsubjidVar) ne 0 and %length(&SequenceVar) ne 0 %then %do;
        %put PeriodVar=&PeriodVar;

        data &work.PpDm;
            set &work.PpDm;

            %** Keep the original periods **;
            OriginalPeriod = &PeriodVar;

            %** Define the pattern of interest **;
            if _n_ = 1 then do;
                pattern_per = prxparse("/PERIOD.*?(\d+)/");
                pattern_day = prxparse("/DAY.*?(\d+)/");
                pattern_shortper = prxparse("/P.*?(\d+)/");
                pattern_shortday = prxparse("/D.*?(\d+)/");
            end;
            retain pattern_per pattern_day pattern_shortper pattern_shortday;

            %** If both days and period are present - only extract the period **;
            if (index(upcase(&PeriodVar.), "PERIOD") and index(upcase(&PeriodVar.), "DAY")) or index(upcase(&PeriodVar.), "PERIOD") then do;
                if prxmatch(pattern_per, upcase(strip(&PeriodVar.))) then do;
                    &PeriodVar = "PERIOD " || prxposn(pattern_per, 1, upcase(strip(&PeriodVar.)));
                    /*&PeriodVar.Num = input(prxposn(pattern_per, 1, upcase(strip(&PeriodVar.))), 8.);*/
                    &PeriodVar.Num = input(scan(&PeriodVar., -1), 8.);
                end;
            end;
            else if (index(upcase(&PeriodVar.), "P") and index(upcase(&PeriodVar.), "D")) or index(upcase(&PeriodVar.), "P") then do;
                if prxmatch(pattern_shortper, upcase(strip(&PeriodVar.))) then do;
                    &PeriodVar = "PERIOD " || prxposn(pattern_shortper, 1, upcase(strip(&PeriodVar.)));
                    &PeriodVar.Num = input(prxposn(pattern_shortper, 1, upcase(strip(&PeriodVar.))), 8.);
                end;
                else if prxmatch(pattern_day, upcase(strip(&PeriodVar.))) then do;
                    &PeriodVar = "DAY " || prxposn(pattern_day, 1, upcase(strip(&PeriodVar.)));
                    &PeriodVar.Num = input(prxposn(pattern_day, 1, upcase(strip(&PeriodVar.))), 8.);
                end;
            end;
            %** Extract the day **;
            else if index(upcase(&PeriodVar.), "DAY") then do;
                if prxmatch(pattern_day, upcase(strip(&PeriodVar.))) then do;
                    &PeriodVar = "DAY " || prxposn(pattern_day, 1, upcase(strip(&PeriodVar.)));
                    &PeriodVar.Num = input(prxposn(pattern_day, 1, upcase(strip(&PeriodVar.))), 8.);
                end;
            end;
            else if index(upcase(&PeriodVar.), "D") then do;
                if prxmatch(pattern_day, upcase(strip(&PeriodVar.))) then do;
                    &PeriodVar = "DAY " || prxposn(pattern_shortday, 1, upcase(strip(&PeriodVar.)));
                    &PeriodVar.Num = input(prxposn(pattern_shortday, 1, upcase(strip(&PeriodVar.))), 8.);
                end;
            end;
            %** If everything fails then just report what is already there **;
            else do;
                &PeriodVar = strip("&PeriodVar.");
            end;

            %** Handle strange analytes where groups/periods are included (simple case) **;
            idx_max = max(index(upcase(&AnalyteVar.), "PERIOD"),  index(upcase(&AnalyteVar.), "DAY"), index(upcase(&AnalyteVar.), "GROUP"), index(upcase(&AnalyteVar.), "TRT"));
            if idx_max then do;
                if idx_max then do;
                    &AnalyteVar = scan(&AnalyteVar., -1, "_-/\");
                end;
                else do;
                    &AnalyteVar = scan(&AnalyteVar., 1, "_-/\");
                end;
            end;
            else do;
                %** Handle strange analytes where groups/periods are included (triggy case - need regex in the future) **;
                if upcase(substr(&AnalyteVar., 1, 6)) = "PERIOD" then do;
                    &AnalyteVar = scan(&AnalyteVar., -1, "_-/\");
                end;
                else if upcase(substr(&AnalyteVar., 1, 3)) in ("DAY", "TRT") then do;
                    &AnalyteVar = scan(&AnalyteVar., -1, "_-/\");
                end;        
                else if upcase(substr(&AnalyteVar., 1, 5)) = "GROUP" then do;
                    &AnalyteVar = scan(&AnalyteVar., -1, "_-/\");
                end;
            end;

            %** Clean-up **;
            drop pattern_: idx_;
        run;
    %end;

    %** Get the different Periods and Sequences **;
    %if %sysfunc(fileexist(&work.PpDm)) %then %do;
        proc sort data = &work.PpDm (keep = &SequenceVar &PeriodVar.)
                    out = &work.periods nodupkey;
            by &SequenceVar &PeriodVar;
        run;

        %if &SequenceVar ne %then %do;
            proc sort data = &work.PpDm (keep = &SequenceVar)
                        out = &work.sequences nodupkey;
                by &SequenceVar;
            run;
        %end;
        
        %** Find the maximum number of periods within each cohort **;
        data _null_;
            set &work.periods end = eof;
            by &SequenceVar &PeriodVar;
            retain MinNumberOfPeriods MaxNumberOfPeriods counter;

            %** Initialize **;
            if _n_ = 1 then do;
                MaxNumberOfPeriods = 0;
                MinNumberOfPeriods = 99;
            end;
            if first.&SequenceVar then do;
                counter = 0;
            end;
                
            %** Count and compare **;
            counter + 1;
            if last.&SequenceVar then do;
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

        %** Find the number of unique sequences **;
        %if &SequenceVar ne %then %do;
            proc sql noprint;
                select distinct
                    &SequenceVar
                into:
                    SequenceList separated by "~!~"
                from
                    &work.sequences
                ;
            quit;
            %let NumberOfSequences = %sysfunc(countw(&SequenceList., ~!~));
        %end;
        %else %do;
            %let NumberOfSequences = 1;
        %end;
    %end;
    %else %do;
        %let NumberOfSequences = 1;
        %let MaxNumberOfPeriods = 0;
    %end;

    %*********************************************************;
    %**                                                     **;
    %**             Separator identification                **;
    %**                                                     **;
    %*********************************************************;

    %** Find what separator to use **;
    %let Separator = ;
    %let HitList = ;
    %let HitCount = ;
    %if %upcase(&StudyArea.) ne INTRINSIC %then %do i = 1 %to &NumberOfSequences;
        %** Get the next in line **;
        %let CurrentSequence = %scan(%quote(&SequenceList.), &i., ~!~);

        %** Debug **;
        %put CurrentSequence: &CurrentSequence;

        %** Count the number of occurence of each of the separator **;
        %let NumberOfColon      = %sysfunc(count(%quote(&CurrentSequence.), %str(:)));
        %let NumberOfSemiColon  = %sysfunc(count(%quote(&CurrentSequence.), %str(;)));
        %let NumberOfSlash      = %sysfunc(count(%quote(&CurrentSequence.), %str(/)));
        %let NumberOfDash       = %sysfunc(count(%quote(&CurrentSequence.), %str(-)));
        %let NumberOfAmpersand  = %sysfunc(count(%quote(&CurrentSequence.), %str(&)));
        %let NumberOfPluses     = %sysfunc(count(%quote(&CurrentSequence.), %str(+)));

        %** Debug **;
        %put NumberOfColon = &NumberOfColon;
        %put NumberOfSemiColon = &NumberOfSemiColon;
        %put NumberOfSlash = &NumberOfSlash;
        %put NumberOfDash = &NumberOfDash;
        %put NumberOfAmpersand = &NumberOfAmpersand;
        %put NumberOfPluses = &NumberOfPluses;

        %** Helper macro variables **;
        %let SeparatorListFull = &NumberOfColon.~!~&NumberOfSemiColon.~!~&NumberOfSlash.~!~&NumberOfDash.~!~&NumberOfAmpersand.~!~&NumberOfPluses;
        %let SeparatorList = %str(:)~!~%str(;)~!~%str(/)~!~%str(-)~!~%str(+)~!~%str(&);
        %let NumberOfSeparators = %eval(&MaxNumberOfPeriods - 1);

        %if %eval(&NumberOfColon + &NumberOfSemiColon + &NumberOfSlash + &NumberOfDash + &NumberOfPluses + &NumberOfAmpersand.) ^= 0 %then %do;
            %do j = 1 %to 6;
                %if %scan(&SeparatorListFull., &j., ~!~) = &NumberOfSeparators %then %do;
                    %if %nrbquote(&HitList.) eq %then %do;
                        %let HitList = %scan(&SeparatorList., &j., ~!~);
                        %let HitCount = %eval(&HitCount + 1);
                    %end;
                %end;
            %end;

            %** If there is only one match then use that as the separator **;
            %if &HitCount = 1 %then %do;
                %let Separator = &HitList;
            %end;
        %end;
        %else %if &Separator eq %then %do;
            %let Separator = ;
        %end;
    %end;

    %** Additional checks to ensure that separators are indeed present (might not always be the case) **;
    %if &SequenceVar ne && &Separator ne %then %do;
        data _null_;
            set &work.sequences end = eof;
            if count(&SequenceVar, "&Separator.") then do;
                counter + 1;
            end;

            if eof then do;
                if counter < (&NumberOfSequences - 1) then do;
                    call symputx("Separator", "");
                end;
            end; 

            drop counter;
        run;
    %end;
    %else %do;
        %let Separator =;
    %end;

    %** Debug **;
    %put Separator is: &Separator;

    %*********************************************************;
    %**                                                     **;
    %**                     Cohorts                         **;
    %**                                                     **;
    %*********************************************************;
    %if &MaxNumberOfPeriods >= 2 and &NumberOfSequences > 1 and %quote(&Separator.) ne %then %do;       
        %** Using the separator identify the different components **;
        %let UniqueSequences = ;
        %let hit = 0;
        %** Loop for all sequences **;
        %do i = 1 %to &NumberOfSequences;

            %** Loop for all treatments within the sequence **;
            %let CurrentSequence = %scan(%quote(&SequenceList.), &i., ~!~);
            %put Current Sequence = &CurrentSequence;
            %do j = 1 %to %sysfunc(countw(%quote(&CurrentSequence.), &Separator.));

                %** Is the treatment already in the list? **;
                %let CurrentTreatment = %scan(%quote(&CurrentSequence.), &j., &Separator.);
                %put Current Treatment = &CurrentTreatment;
                %if %nrbquote(&UniqueSequences.) ne %then %do;
                    %let k = 0;
                    %let hit = 0;
                    %do %until(&k = %sysfunc(countw(%quote(&UniqueSequences.),~!~)));
                        %** Match found! **;
                        %if %nrbquote(&CurrentTreatment.) eq %nrbquote(%scan(%nrbquote(&UniqueSequences.), %eval(&k.+1), ~!~)) %then %do;
                            %let hit = 1;
                        %end;
                        %let k = %eval(&k + 1);
                    %end;

                    %** If not add it **;
                    %if &hit = 0 %then %do;
                        %let UniqueSequences = &UniqueSequences.~!~&CurrentTreatment;
                    %end;
                %end;
                %** If not add it **;
                %else %do;
                    %let UniqueSequences = &CurrentTreatment;
                %end;
            %end;
        %end;
        %let NumberOfUniqueSequences = %sysfunc(countw(%quote(&UniqueSequences.),~!~));

        %** Debug **;
        %put Final Unique Sequences = &UniqueSequences;

        %** Identify how many different groups / cohorts there really are **;
        %** Each sequences gets a numeric value and the number of distinct values is the number of cohorts **;
        %** Loop for all sequences **;
        %if &SequenceVar ne %then %do;
            data &work.groups;
                set &work.sequences;
                length UniqueSequences $500;
                UniqueSequences = "&UniqueSequences.";

                %** Count the unique cohort number **;
                counter = 0;
                do i = 1 to &NumberOfUniqueSequences;
                    do j = 1 to countw(&SequenceVar, "&Separator.");
                        if strip(scan(UniqueSequences, i, "~!~")) = strip(scan(&SequenceVar, j, "&Separator.")) then do;
                            counter + i;
                        end;
                    end;
                end;
                
                %** Clean - up **;
                drop i j;
            run;

            %** Sort **;
            proc sort data = &work.groups;
                by counter &SequenceVar;
            run;

            %** Create a unique Cohort Number, Name and Description**;
            data &work.groups;
                set &work.groups;
                by counter &SequenceVar;
                retain CohortNumber CohortName CohortDescription;

                %** Assign **;
                if first.counter then do;
                    CohortNumber + 1;
                    CohortName = "Cohort " || strip(CohortNumber);
                    CohortDescription = &SequenceVar;
                end;

                %** Clean-up **;
                drop counter;
            run;
        %end;
    %end;
    %else %if &MaxNumberOfPeriods > 0 %then %do;
        %** Sort **;
        %if &SequenceVar ne %then %do;
            proc sort data = &work.sequences
                        out = &work.groups;
                by &SequenceVar;
            run;

            %** Create a unique Cohort Number, Name and Description **;
            data &work.groups;
                set &work.groups;
                by &SequenceVar;
                retain CohortNumber CohortName CohortDescription;

                %** Assign **;
                if first.&SequenceVar then do;
                    CohortNumber + 1;
                    CohortName = "Cohort " || strip(CohortNumber);
                    CohortDescription = &SequenceVar;
                end;
            run;
        %end;
    %end;

    %** Add cohorts and log transform the results **;
    %if &SequenceVar ne && &MaxNumberOfPeriods > 0 %then %do;
        proc sort data = &work.PpDm;
            by &SequenceVar;
        run;

        proc sort data = &work.groups;
            by &SequenceVar;
        run;

        data &work.PpDm(drop = _t:);
            merge   &work.PpDm(in = a)
                    &work.groups(in = b);
            by &SequenceVar;
            if a;
        run;

        %** Save the number of cohorts in a macro variable **;
        proc sql noprint;
            select 
                max(CohortNumber)
            into
                :NumberOfCohorts
            from
                &work.PpDm
            ;
        quit;
        
    %end;
    
    %** Debug **;
    %put Number of Groups = &NumberOfCohorts;
    %put Number of Sequences = &NumberOfSequences;
    %put Number of periods (max) = &MaxNumberOfPeriods;
    
    %*********************************************************;
    %**                                                     **;
    %**                 Study design                        **;
    %**                                                     **;
    %*********************************************************;
    %** If the study type is intrinsic - it is safe to assume that we can only have a parallel study **;
    %if %upcase(&StudyArea.) = INTRINSIC %then %do;
        %if &NumberOfSequences > 1 and &MaxNumberOfPeriods = 1 %then %do;
            %let StudyDesign = Parallel;
        %end;
        %else %if &MinNumberOfPeriods = 1 and &MaxNumberOfPeriods > 1 %then %do;
            %let StudyDesign = Unknown;
        %end;
        %else %do;
            %let StudyDesign = Parallel;
        %end;
    %end;
    %else %if %upcase(&StudyArea.) = EXTRINSIC %then %do;
        %put Sequences: &NumberOfSequences;
        %put Cohorts: &NumberOfCohorts;
        %if &NumberOfSequences > &NumberOfCohorts %then %do;
            %let StudyDesign = Crossover;
        %end;
        %else %if &NumberOfSequences = &NumberOfCohorts %then %do;
            %let StudyDesign = Sequential;
        %end;
        %else %do;
            %let StudyDesign = Unknown;
        %end;
    %end;
    %else %do;
        %let StudyDesign = Unknown;
    %end;
%end;
%else %do;
    %let StudyDesign = Unknown;
%end;

%mend;


