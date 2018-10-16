%*****************************************************************************************;
%**                                                                                     **;
%** Prepare data for analysis by adding groupings, comparisons and treatment in periods **;
%**                                                                                     **;
%** Input:                                                                              **;
%**     Input               -       Input dataset (either PC or PP based)               **;
%**     SequenceVar         -       Name of the sequence variable from DM               **;
%**     TimeVar             -       Name of the timing variable from PC                 **;
%**     AnalyteVar          -       Name of the analyte variable from PC or PP          **;
%**     ParameterVar        -       Name of the parameter variable from PP              **;
%**     PeriodVar           -       Name of the period variable from PC or PP           **;
%**     ResultVar           -       Name of the result variable from PC or PP           **;
%**     ExData              -       Exposure input dataset                              **;
%**     ExTrtVar            -       Name of the treatment variable from EX              **;
%**     ExDateVar           -       Name of the date variable from EX                   **;
%**     ExPeriodVar         -       Name of the period variable from EX                 **;
%**     Type                -       Underlying SDTM domain (PC or PP)                   **;
%**     StudyArea           -       Intrinsic or extrinsic (not required)               **;
%**     StudyDesign         -       Study design                                        **;
%**                                                                                     **;
%** Output:                                                                             **;
%**     Dataset with same name as Input but with possible corrected groupings           **;
%**                                                                                     **;
%** Created by:                                                                         **;
%**     Jens Stampe Soerensen  (2013/2014)                                              **;
%** Debuged by Meng Xu (2015)                                                           **;
%*****************************************************************************************;

%macro SmPrepareDataForAnalysis(
        Input = ,
        SequenceVar = ,
        TimeVar = ,
        AnalyteVar = ,
        ParameterVar = ,
        PeriodVar = ,
        ResultVar = ,
        ExData = ,
        ExTrtVar = ,
        ExDateVar = ,
        ExPeriodVar = ,
        Type = ,
        StudyArea = ,
        StudyDesign = 
);

%** Macro variables **;
%local i j;
%global ProgressGo Separator;

%*********************************************************;
%**                                                     **;
%**             Period and sequences                    **;
%**                                                     **;
%*********************************************************;



%** Modify the analysis dataset to show periods and handle analytes with groups in **;
%** (FIXME: needs to be updated to do this for all numeric variables) **;
%if &PeriodVar. ne PPDY %then %do;  
    data &Input.;
        set &Input.;

        %** Keep the original periods **;
        OriginalPeriod = &PeriodVar.;

        %** Define the pattern of interest **;
        if _n_ = 1 then do;
            pattern_per = prxparse("/PERIOD.*?(\d+)/");
            pattern_day = prxparse("/DAY.*?([0-9-]+)/"); %** FIXME: better handling of DAY -8 versus DAY 8 etc **; 
            pattern_shortper = prxparse("/P.*?(\d+)/");
            pattern_shortday = prxparse("/D.*?(\d+)/");
        end;
        retain pattern_per pattern_day pattern_shortper pattern_shortday;

        %** If both days and period are present - only extract the period **;
        if (index(upcase(&PeriodVar.), "PERIOD") and index(upcase(&PeriodVar.), "DAY")) or index(upcase(&PeriodVar.), "PERIOD") then do;
            if prxmatch(pattern_per, upcase(strip(&PeriodVar.))) then do;
                &PeriodVar. = "PERIOD " || prxposn(pattern_per, 1, upcase(strip(&PeriodVar.)));
                /*&PeriodVar.Num = input(prxposn(pattern_per, 1, upcase(strip(&PeriodVar.))), 8.);*/
                &PeriodVar.Num = input(scan(&PeriodVar., -1), 8.);
            end;
        end;
        else if (index(upcase(&PeriodVar.), "P") and index(upcase(&PeriodVar.), "D")) or index(upcase(&PeriodVar.), "P") then do;
            if prxmatch(pattern_shortper, upcase(strip(&PeriodVar.))) then do;
                &PeriodVar. = "PERIOD " || prxposn(pattern_shortper, 1, upcase(strip(&PeriodVar.)));
                &PeriodVar.Num = input(prxposn(pattern_shortper, 1, upcase(strip(&PeriodVar.))), 8.);
            end;
            else if prxmatch(pattern_day, upcase(strip(&PeriodVar.))) then do;
                &PeriodVar. = "DAY " || prxposn(pattern_day, 1, upcase(strip(&PeriodVar.)));
                &PeriodVar.Num = input(prxposn(pattern_day, 1, upcase(strip(&PeriodVar.))), 8.);
            end;
        end;
        %** Extract the day **;
        else if index(upcase(&PeriodVar.), "DAY") then do;
            if prxmatch(pattern_day, upcase(strip(&PeriodVar.))) then do;
                &PeriodVar. = "DAY " || prxposn(pattern_day, 1, upcase(strip(&PeriodVar.)));
                &PeriodVar.Num = input(prxposn(pattern_day, 1, upcase(strip(&PeriodVar.))), 8.);
            end;
        end;
        else if index(upcase(&PeriodVar.), "D") then do;
            if prxmatch(pattern_day, upcase(strip(&PeriodVar.))) then do;
                &PeriodVar. = "DAY " || prxposn(pattern_shortday, 1, upcase(strip(&PeriodVar.)));
                &PeriodVar.Num = input(prxposn(pattern_shortday, 1, upcase(strip(&PeriodVar.))), 8.);
            end;
        end;
        %** If everything fails then just report what is already there **;
        else do;
            &PeriodVar. = strip(&PeriodVar.);
        end;

        if index(upcase(&PeriodVar.), "Test") or index(upcase(&PeriodVar.), "Ref")then do;
             &PeriodVar. = strip(&PeriodVar.);
        end;

        %** Handle strange analytes where groups/periods are included (simple case) **;
        idx_max = max(index(upcase(&AnalyteVar.), "PERIOD"),  index(upcase(&AnalyteVar.), "DAY"), index(upcase(&AnalyteVar.), "GROUP"), index(upcase(&AnalyteVar.), "TRT"));
        if idx_max then do;
            %** FIXME: CHANGE MADE to -1 and 1 **;
            if idx_max then do;
                &AnalyteVar. = scan(&AnalyteVar., 1, "_-/\");
            end;
            else do;
                &AnalyteVar. = scan(&AnalyteVar., -1, "_-/\");
            end;
        end;
        else do;
            %** Handle strange analytes where groups/periods are included (triggy case - need regex in the future) **;
            if upcase(substr(&AnalyteVar., 1, 6)) = "PERIOD" then do;
                &AnalyteVar. = scan(&AnalyteVar., -1, "_-/\");
            end;
            else if upcase(substr(&AnalyteVar., 1, 3)) in ("DAY", "TRT") then do;
                &AnalyteVar. = scan(&AnalyteVar., -1, "_-/\");
            end;        
            else if upcase(substr(&AnalyteVar., 1, 5)) = "GROUP" then do;
                &AnalyteVar. = scan(&AnalyteVar., -1, "_-/\");
            end;
            else if upcase(substr(&AnalyteVar., 1, 9)) = "TREATMENT" then do;
                &AnalyteVar. = scan(&AnalyteVar., -1, "_-/\");
            end;
        end;

        %** Clean-up **;
        drop pattern_: idx_;
    run;
%end;
%else %do;
    %** Check in exposure for how the visit variable (if present) is represented **;
    %** FIXME: could be moved. If not present crash on 204629, 1245-0041 **;
    %if &ExData. ne and &ExPeriodVar. ne %then %do;
        data _null_;
            set &ExData. (obs = 1);
            if indexw(&ExPeriodVar., "PERIOD") then do;
                ExVarName = "PERIOD";
            end;
            else if indexw(&ExPeriodVar., "DAY") then do;
                ExVarName = "DAY";
            end;
            else if indexw(&ExPeriodVar., "VISIT") then do;
                ExVarName = "VISIT";
            end;

            call symputx("ExVarName", ExVarName);
        run;
        %let NumPerVar = &ExPeriodVar.;
    %end;
    %else %do;
        %let ExVarName = PERIOD;
        %let NumPerVar = NumPerVar;
    %end;

    %** Sort the data based on subject and ppdy **;
    proc sort data = &Input.;
        by &UsubjidVar. &PeriodVar.;
    run;
    
    data &Input.;
        set &Input.;
        by &UsubjidVar. &PeriodVar.;
        
        if first.&UsubjidVar. then do;
            PeriodCounter = 0;
        end;

        if first.&PeriodVar. then do;
            PeriodCounter + 1;
        end;

        &NumPerVar. = "&ExVarName. " || strip(PeriodCounter);
    run;

    %let PeriodVar = &NumPerVar.;
    %let PeriodPpVar = &NumPerVar.;

%end;
%** Handle Periods in exposure so they match the ones in the input dataset **;
%if &ExData. ne and &ExPeriodVar. ne and %SYSFUNC(EXIST(&ExData)) %then %do;
    data &ExData.;
        set &ExData.;

        %** Keep the original periods **;
        OriginalPeriod = &ExPeriodVar.;

        %** Define the pattern of interest **;
        if _n_ = 1 then do;
            pattern_per = prxparse("/PERIOD.*?(\d+)/");
            pattern_day = prxparse("/DAY.*?([0-9-]+)/"); %** FIXME: better handling of DAY -8 versus DAY 8 etc **; 
            pattern_shortper = prxparse("/P.*?(\d+)/");
            pattern_shortday = prxparse("/D.*?(\d+)/");
        end;
        retain pattern_per pattern_day pattern_shortper pattern_shortday;

        %** If both days and period are present - only extract the period **;
        if (index(upcase(&ExPeriodVar.), "PERIOD") and index(upcase(&ExPeriodVar.), "DAY")) or index(upcase(&ExPeriodVar.), "PERIOD") then do;
            if prxmatch(pattern_per, upcase(strip(&ExPeriodVar.))) then do;
                &ExPeriodVar. = "PERIOD " || prxposn(pattern_per, 1, upcase(strip(&ExPeriodVar.)));
                &ExPeriodVar.Num = input(scan(&ExPeriodVar., -1), 8.);
            end;
        end;
        else if (index(upcase(&ExPeriodVar.), "P") and index(upcase(&ExPeriodVar.), "D")) or index(upcase(&ExPeriodVar.), "P") then do;
            if prxmatch(pattern_shortper, upcase(strip(&ExPeriodVar.))) then do;
                &ExPeriodVar. = "PERIOD " || prxposn(pattern_shortper, 1, upcase(strip(&ExPeriodVar.)));
                &ExPeriodVar.Num = input(prxposn(pattern_shortper, 1, upcase(strip(&ExPeriodVar.))), 8.);
            end;
            else if prxmatch(pattern_day, upcase(strip(&ExPeriodVar.))) then do;
                &ExPeriodVar. = "DAY " || prxposn(pattern_day, 1, upcase(strip(&ExPeriodVar.)));
                &ExPeriodVar.Num = input(prxposn(pattern_day, 1, upcase(strip(&ExPeriodVar.))), 8.);
            end;
        end;
        %** Extract the day **;
        else if index(upcase(&ExPeriodVar.), "DAY") then do;
            if prxmatch(pattern_day, upcase(strip(&ExPeriodVar.))) then do;
                &ExPeriodVar. = "DAY " || prxposn(pattern_day, 1, upcase(strip(&ExPeriodVar.)));
                &ExPeriodVar.Num = input(prxposn(pattern_day, 1, upcase(strip(&ExPeriodVar.))), 8.);
            end;
        end;
        else if index(upcase(&ExPeriodVar.), "D") then do;
            if prxmatch(pattern_day, upcase(strip(&ExPeriodVar.))) then do;
                &ExPeriodVar. = "DAY " || prxposn(pattern_shortday, 1, upcase(strip(&ExPeriodVar.)));
                &ExPeriodVar.Num = input(prxposn(pattern_shortday, 1, upcase(strip(&ExPeriodVar.))), 8.);
            end;
        end;
        %** If everything fails then just report what is already there **;
        else do;
            &ExPeriodVar. = strip(&ExPeriodVar.);
        end;

        %** Clean-up **;
        drop pattern_: idx_;
    run;
%end;

%** Combine periods if need be (only needed for concentration data) **;
%if %upcase(&Type.) = PC %then %do;


    %** In some cases the time points are reported as continouse values while in fact they are in larger intervals (NUM = 1, 2, 3 CHAR = 1h, 4h, 12h) **;
    %** Check if PCTPT exist - if it does continue processing **;
    data _null_;
        set &Input.(obs = 1) end = eof;
        array c{*} _CHARACTER_;
        do i = 1 to dim(c);
            if vname(c{i}) = "PCTPT" then do;
                tpt_char = 1;
                call symputx("pctpt_exist", tpt_char);
            end;
            if vname(c{i}) = "PCSPEC" then do;
                spec_char = 1;
                call symputx("spec_exist", spec_char);
            end;
        end;
    run;



    %** Only considered speciments in plasma and serum **;
    %if %symexist(spec_exist) %then %do;
        data &Input.;
            set &Input. (where = (upcase(PCSPEC) in ("SERUM", "PLASMA", "BLOOD")));
        run;
    %end;

    %** Use the character version of tpt to get the right numbering **;
          
%if %upcase(&TimeVar.) =PCTPT %then %do;


  proc sql;
        select distinct pctpt into: pctptvar from &Input.;
        run;
        quit;

      %if %index(&pctptvar, :)^=0 and %index(%upcase(&pctptvar,day))=0 %then %do;

        data &Input.;
           set &Input.;

           if _N_ = 1 then do;
           retain patternid;
           pattern = "/(\d+):(\d\d)/";
           patternid = prxparse(pattern);
           end;

           array match{2} $8.;
           if prxmatch(patternid, upcase(PCTPT)) ^= 0 then do;
		   do i = 1 to prxparen(patternid);
           call prxposn(patternid, i, start, length);
           if start ^= 0 and length ^= 0 then do;
           match{i} = substr(PCTPT, start, length);
           end;
           end;
           end;                  
              
           if index(upcase(PCTPT), "PRE") or index(upcase(PCTPT), "-PT")or indexw(upcase(PCTPT), "PRIOR")or index(upcase(PCTPT), "-") then do;
           NOM_TIME=0;
         

           end;

           else if match{1} ^= "" and match{2} = "" then do;
              NOM_TIME = input(match{1}, 8.);
           end;

           else if match{1} = "" and match{2} ^= "" then do;
             NOM_TIME = input(match{2}, 8.)/60;
           end;

          else if match{1} ^= "" and match{2} ^= "" then do;
             NOM_TIME = input(cats(match{1}, ".", scan(round(input(match{2}, 8.) / 60, 0.01), -1, ".")), 8.);
          end;

          if NOM_TIME ne . then do;
           NonStd = 1;
           end;

         run;
         %put run loop1 :;
       %end;

       %else %do;


            %if %index(&pctptvar, :)^=0 and %index(%upcase(&pctptvar,day))^=0 %then %do;
           
              data &Input.;
                set &Input.;
                new=trim("%scan(%nrbquote(&pctptvar.),2,:)");
                run;

                data  &Input.(rename=(pctpt=PCTPTOrig new=PCTPT));
                set  &Input.;
                run;
            %put timevar pctpt contain DAY[Num] : [Num]Hour;
            %end;

        data &Input.;
          set &Input.;
          if _N_ = 1 then do;
          retain patternid;
          pattern = "/(\d+\.?\d+|\d+\.?|\.?\d+)\s*(H?)\s*(\d*)\s*(M?)/";
          patternid = prxparse(pattern);
          end;

          array match{4} $8.;
          if prxmatch(patternid, upcase(PCTPT)) ^= 0 then do;

          do i = 1 to prxparen(patternid);
          call prxposn(patternid, i, start, length);

          if start ^= 0 and length ^= 0 then do;
          match{i} = substr(PCTPT, start, length);
          end;

          end;

          end;
          label NOM_TIME = "Nominal Time Point (H)";

           if index(upcase(PCTPT), "PRE") or index(upcase(PCTPT), "-PT") or indexw(upcase(PCTPT), "PRIOR") then do;
           NOM_TIME=0;
        
           end;

           else if match{2} ^= "" and match{4} = "" then do;
           NOM_TIME = input(match{1}, 8.);
           end;

           else if match{2} = "" and match{4} ^= "" then do;
           NOM_TIME = input(match{1}, 8.)/60;
           end;

           else if match{2} ^= "" and match{4} ^= "" then do;
           NOM_TIME = input(cats(match{1}, ".", scan(round(input(match{3}, 8.) / 60, 0.01), -1, ".")), 8.);
           end;

           if NOM_TIME ne . then do;
           NonStd = 1;
           end;
          run;
          %put run loop 2;
          /*drop pattern patternid i start length match:;*/
        %end;

        %** Check whether there is a mismatch between PCTPT and PCTPTNUM **;
        proc sort data = &Input. out = &work.mismatch(keep = &TimeVar. PCTPT NOM_TIME NonStd) nodupkey;
            by descending &TimeVar. NonStd;
        run;

        data _null_;
            set &work.mismatch (obs = 1);
            if (&TimeVar. > NOM_TIME and NOM_TIME ne .) or NonStd then do;
                %let ChgTimeVar = Yes;
            end;
        run;

        %if &ChgTimeVar. ne %then %do;
            data &Input.;
                set &Input. (rename = (&TimeVar. = _&TimeVar. NOM_TIME = &TimeVar.));
            run;
        %end;
        
        %put Debug TimeVar = &TimeVar.;
        
    %end;

proc sort data=&Input.;
by &SequenceVar. &UsubjidVar. &AnalyteVar. &PeriodVar. VISITNUM &TimeVar.;
run;


data &Input.;
set &Input.;
by &SequenceVar. &UsubjidVar. &AnalyteVar. &PeriodVar. &TimeVar.;

if &TimeVar. eq 0.00 and last.&TimeVar. then last=1;
else if &TimeVar. ne 0.00 then last=2;

if last eq . then delete;
run;
    
    %** Count the number of periods per time point per sequence **;
    proc freq data = &Input. noprint;
        tables &SequenceVar.*&PeriodVar.Num*&PeriodVar.*&TimeVar. / list missing out = &work.periods(drop = percent);
    run;
  
      
      

    %** Group the periods **;
    data &work.periods;
        set &work.periods;
        by &SequenceVar. &PeriodVar.Num &PeriodVar. &TimeVar.;
        retain _&PeriodVar. PreValue;

        %** Remove redundant info **;
        if first.&PeriodVar. eq last.&PeriodVar. and PreValue >= &TimeVar. and &TimeVar. < 5 then do;
            delete;
        end;

        if first.&SequenceVar. then do;
            PreValue = &TimeVar.;
            _&PeriodVar. = &PeriodVar.;
        end;
        else do;
            if PreValue > &TimeVar. and first.&PeriodVar.Num ne last.&PeriodVar.Num then do;
                _&PeriodVar. = &PeriodVar.;
            end;
        end;
        PreValue = &TimeVar.;
    run;

    %** Merge the periods with the input dataset **;
    proc sort data = &Input.;
        by &SequenceVar. &PeriodVar. &TimeVar.;
    run;

    proc sort data = &work.periods;
        by &SequenceVar. &PeriodVar. &TimeVar.;
    run;



    data &Input.(rename = (&PeriodVar. = _temp_ _&PeriodVar. = &PeriodVar.));
    
        merge   &Input.(in = a)
                &work.periods(in = b);
        by &SequenceVar. &PeriodVar. &TimeVar.;
        if a and b;

        %** Clean-up **;
        keep &UsubjidVar. &PeriodVar. &SequenceVar. &AnalyteVar. &TimeVar. &ResultVar. _&PeriodVar. PCSPEC _&TimeVar.;
    run;   

%end;
%** Clear any unwanted sequences (only for Parameters) **;
%else %if %upcase(&Type.) = PP %then %do;
    %** Clean-up any unwanted sequences (Screening / Follow-up) **;
    data &Input.;
        length &SequenceVar. $500.;
        set &Input.(where = (find(upcase(&ParameterVar.), "AUC") or find(upcase(&ParameterVar.), "CMAX") or 
                            find(upcase(&ParameterVar.), "ACTAU") or find(upcase(&ParameterVar.), "ACINF") or
                            find(upcase(&ParameterVar.), "TMAX") or find(upcase(&ParameterVar.), "THALF")));
                       

        %** Anything called screen / screening present? **;
        if index(upcase(&SequenceVar.), "SCREENING") then do;
            %** Identify potential separators right after Screening **;
            loc_scr = index(upcase(&SequenceVar.), "SCREENING");
            sep_scr = compress(substr(&SequenceVar., loc_scr + 9, 2));

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
            &SequenceVar. = substr(&SequenceVar., index(&SequenceVar., strip(sep_scr)) + 1);        
            
        end;
        
        %** Anything called Follow-up / Follow up present? **;
        if index(upcase(&SequenceVar.), "FOLLOW-UP") or index(upcase(&SequenceVar.), "FOLLOW UP") then do;
            %** Identify potential separators right before Follow-Up **;
            if index(upcase(&SequenceVar.), "FOLLOW-UP") then do;
                loc_fu = index(upcase(&SequenceVar.), "FOLLOW-UP");
                sep_fu = compress(substr(&SequenceVar., loc_fu - 2, 2));
            end;
            else do;
                loc_fu = index(upcase(&SequenceVar.), "FOLLOW UP");
                sep_fu = compress(substr(&SequenceVar., loc_fu - 2, 2));
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
            if index(upcase(&SequenceVar.), "FOLLOW-UP") then do;
                _temp_ = strip(substr(&SequenceVar., 1, index(&SequenceVar., scan(&SequenceVar., -2, strip(sep_fu)))-1));
                &SequenceVar. = substr(_temp_, 1, length(_temp_) - 1);
            end;
            else do;
                _temp_ = strip(substr(&SequenceVar., 1, index(&SequenceVar., scan(&SequenceVar., -1, strip(sep_fu)))));
                &SequenceVar. = substr(_temp_, 1, length(_temp_) - 1);
            end;
        end;

        %** Remove leading and trailing blanks **;
        &SequenceVar. = strip(&SequenceVar.);

        /* added ppspec for OGD ouputs*/
        drop _t: sep_: loc_: ;
        keep &UsubjidVar. &PeriodVar. &SequenceVar. &AnalyteVar. &ParameterVar. &ResultVar. PPSPEC PPDTC;
    run;
    
%end;

%if %sysfunc(fileexist(&ExData.)) %then %do;
    %** Clean-up any unwanted sequences (Screening / Follow-up) **;
    data &ExData.;
        set &ExData.;

        %** Anything called screen / screening present? **;
        if index(upcase(&SequenceVar.), "SCREENING") then do;
            %** Identify potential separators right after Screening **;
            loc_scr = index(upcase(&SequenceVar.), "SCREENING");
            sep_scr = compress(substr(&SequenceVar., loc_scr + 9, 2));

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
            &SequenceVar. = substr(&SequenceVar., index(&SequenceVar., strip(sep_scr)) + 1);
        end;
        %** Anything called Follow-up / Follow up present? **;
        if index(upcase(&SequenceVar.), "FOLLOW-UP") or index(upcase(&SequenceVar.), "FOLLOW UP") then do;
            %** Identify potential separators right before Follow-Up **;
            if index(upcase(&SequenceVar.), "FOLLOW-UP") then do;
                loc_fu = index(upcase(&SequenceVar.), "FOLLOW-UP");
                sep_fu = compress(substr(&SequenceVar., loc_fu - 2, 2));
            end;
            else do;
                loc_fu = index(upcase(&SequenceVar.), "FOLLOW UP");
                sep_fu = compress(substr(&SequenceVar., loc_fu - 2, 2));
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
            if index(upcase(&SequenceVar.), "FOLLOW-UP") then do;
                _temp_ = strip(substr(&SequenceVar., 1, index(&SequenceVar., scan(&SequenceVar., -2, strip(sep_fu)))-1));
                &SequenceVar. = substr(_temp_, 1, length(_temp_) - 1);
            end;
            else do;
                _temp_ = strip(substr(&SequenceVar., 1, index(&SequenceVar., scan(&SequenceVar., -1, strip(sep_fu)))));
                &SequenceVar. = substr(_temp_, 1, length(_temp_) - 1);
            end;
        end;

        %** Remove leading and trailing blanks **;
        &SequenceVar. = strip(&SequenceVar.);

        %** Clean-up **;
        drop _t: sep_: loc_: ;
        keep &UsubjidVar. &ExPeriodVar. &SequenceVar. &ExTrtVar. &ExDateVar.;
    run;
%end;

%** Get the different Periods and Sequences **;
proc sort data = &Input. (keep = &SequenceVar. &PeriodVar.)
            out = &work.periods nodupkey;
    by &SequenceVar. &PeriodVar.;
run;

proc sort data = &Input. (keep = &SequenceVar.)
            out = &work.sequences nodupkey;
    by &SequenceVar.;
run;

%** Find the number of periods and sequences and put them in a macro variable **;
%global MaxNumberOfPeriods MinNumberOfPeriods NumberOfSequences;

%** Find the maximum number of periods within each cohort **;
data &work._null_;
    set &work.periods end = eof;
    by &SequenceVar. &PeriodVar.;
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



%** Find the number of unique sequences **;
proc sql noprint;
    select distinct
        &SequenceVar.
    into:
        SequenceList separated by "~!~"
    from
        &work.sequences
    ;
quit;
%put SequenceList = &SequenceList.;
%let NumberOfSequences = %sysfunc(countw(%nrbquote(&SequenceList.), ~!~));

%** Debug **;
%put Number of Sequences = &NumberOfSequences.;

%*********************************************************;
%**                                                     **;
%**             Separator identification                **;
%**                                                     **;
%*********************************************************;

%** Find what separator to use **;
%let Separator = ;
%let HitList = ;
%let HitCount = ;
/* %if %upcase(&StudyArea.) ne INTRINSIC %then %do i = 1 %to &NumberOfSequences.; FIXME */
%if %upcase(&StudyDesign.) ne PARALLEL %then %do i = 1 %to &NumberOfSequences.;
    %** Get the next in line **;
    %let CurrentSequence = %scan(%quote(&SequenceList.), &i., ~!~);

    %** Debug (list start) **;
    %put CurrentSequence: &CurrentSequence.;

    %** Count the number of occurence of each of the separator **;
    %let NumberOfColon      = %sysfunc(count(%quote(&CurrentSequence.), %str(:)));
    %let NumberOfSemiColon  = %sysfunc(count(%quote(&CurrentSequence.), %str(;)));
    %let NumberOfSlash      = %sysfunc(count(%quote(&CurrentSequence.), %str(/)));
    %let NumberOfDash       = %sysfunc(count(%quote(&CurrentSequence.), %str(-)));
    %let NumberOfAmpersand  = %sysfunc(count(%quote(&CurrentSequence.), %str(&)));
    %let NumberOfPluses     = %sysfunc(count(%quote(&CurrentSequence.), %str(+)));

    %** Debug **;
    %put NumberOfColon = &NumberOfColon.;
    %put NumberOfSemiColon = &NumberOfSemiColon.;
    %put NumberOfSlash = &NumberOfSlash.;
    %put NumberOfDash = &NumberOfDash.;
    %put NumberOfAmpersand = &NumberOfAmpersand.;
    %put NumberOfPluses = &NumberOfPluses.;

    %** Helper macro variables **;
    %let SeparatorListFull = &NumberOfColon.~!~&NumberOfSemiColon.~!~&NumberOfSlash.~!~&NumberOfDash.~!~&NumberOfAmpersand.~!~&NumberOfPluses.;
    %let SeparatorList = %str(:)~!~%str(;)~!~%str(/)~!~%str(-)~!~%str(&)~!~%str(+);
    %let NumberOfSeparators = %eval(&MaxNumberOfPeriods. - 1);

    %put SeparatorListFull=&SeparatorListFull;
    %put NumberOfSeparators=&NumberOfSeparators;
    %put SeparatorList=&SeparatorList;

    %if %eval(&NumberOfColon. + &NumberOfSemiColon. + &NumberOfSlash. + &NumberOfDash. + &NumberOfPluses. + &NumberOfAmpersand.) ^= 0 %then %do;
        %do j = 1 %to 6;
            %if %scan(&SeparatorListFull., &j., "~!~") = &NumberOfSeparators. %then %do;
                %if %nrbquote(&HitList.) eq %then %do;
                    %let HitList = %scan(&SeparatorList., &j., "~!~");
                    %let HitCount = %eval(&HitCount + 1);
                %end;
            %end;
        %end;
        %put HitCount=&Hitcount;
        %put HitList=&HitList;
        %** If there is only one match then use that as the separator **;
        %if &HitCount. = 1 %then %do;
            %let Separator = &HitList.;
        %end;
    %end;

    /*%else %if &Separator. eq %then %do;
        %let Separator = ;
    %end;*/

    %else %if %SYMEXIST(Separator) ne 0 %then %do;
        %if %eval(&NumberOfColon. + &NumberOfSemiColon. + &NumberOfSlash. + &NumberOfDash. + &NumberOfPluses. + &NumberOfAmpersand.) = 0 %then %do;
           %let Separator= ; 
         %put Seperator is null;
        %end;
    %end;
%end;
        
%if &HitCount. = 1 %then %do;
    %let Separator = &HitList.;
%end;
%put Seperator before: &Separator.;
%** Additional checks to ensure that separators are indeed present (might not always be the case) **;
data _null_;
    set &work.sequences end = eof;
    if count(&SequenceVar., "&Separator.") then do;
        counter + 1;
    end;

    if eof then do;
        /* FIXME - added or counter = 0 */
        if counter < (&NumberOfSequences. - 1) or counter = 0 then do;
            call symputx("Separator", "");
        end;
    end; 

    drop counter;
run;

%** Debug **;
%put Separator is: &Separator.;

%checksepandsplit;
%GetSeparator;
%checksepandsplit;

%*********************************************************;
%**                                                     **;
%**                     Cohorts                         **;
%**                                                     **;
%*********************************************************;
%if &MaxNumberOfPeriods. >= 2 and &NumberOfSequences. > 1 and %nrbquote(&Separator.) ne  %then %do;     
    %** Using the separator identify the different components **;
    %let UniqueSequences = ;
    %let hit = 0;
    %** Loop for all sequences **;
    %do i = 1 %to &NumberOfSequences.;

        %** Loop for all treatments within the sequence **;
        %let CurrentSequence = %scan(%quote(&SequenceList.), &i., ~!~);
        %put Current Sequence = &CurrentSequence.;
        %do j = 1 %to %sysfunc(countw(%quote(&CurrentSequence.), &Separator.));

            %** Is the treatment already in the list? **;
            %let CurrentTreatment = %scan(%quote(&CurrentSequence.), &j., &Separator.);
            %put Current Treatment = &CurrentTreatment.;
            %if %nrbquote(&UniqueSequences.) ne %then %do;
                %let k = 0;
                %let hit = 0;
                %do %until(&k. = %sysfunc(countw(%quote(&UniqueSequences.),~!~)));
                    %** Match found! **;
                    %if %nrbquote(&CurrentTreatment.) eq %nrbquote(%scan(%nrbquote(&UniqueSequences.), %eval(&k.+1), ~!~)) %then %do;
                        %let hit = 1;
                    %end;
                    %let k = %eval(&k. + 1);
                %end;

                %** If not add it **;
                %if &hit. = 0 %then %do;
                    %let UniqueSequences = &UniqueSequences.~!~&CurrentTreatment.;
                %end;
            %end;
            %** If not add it **;
            %else %do;
                %let UniqueSequences = &CurrentTreatment.;
            %end;
        %end;
    %end;
    %let NumberOfUniqueSequences = %sysfunc(countw(%quote(&UniqueSequences.),~!~));

    %** Debug **;
    %put Final Unique Sequences = &UniqueSequences.;

    %** Identify how many different groups / cohorts there really are **;
    %** Each sequences gets a numeric value and the number of distinct values is the number of cohorts **;
    %** Loop for all sequences **;
    data &work.groups;
        set &work.sequences;
        length UniqueSequences $500.;
        UniqueSequences = "&UniqueSequences.";

        %** Count the unique cohort number **;
        counter = 0;
        do i = 1 to &NumberOfUniqueSequences.;
            do j = 1 to countw(&SequenceVar., "&Separator.");
                if strip(scan(UniqueSequences, i, "~!~")) = strip(scan(&SequenceVar., j, "&Separator.")) then do;
                    counter + i;
                end;
            end;
        end;
        
        %** Clean - up **;
        drop i j;
    run;

    %** Sort **;
    proc sort data = &work.groups;
        by counter &SequenceVar.;
    run;

    %** Create a unique Cohort Number, Name and Description**;
    data &work.groups;
        set &work.groups;
        by counter &SequenceVar.;
        retain CohortNumber CohortName CohortDescription;

        %** Assign **;
        if first.counter then do;
            CohortNumber + 1;
            CohortName = "Cohort " || strip(CohortNumber);
            CohortDescription = &SequenceVar.;
        end;

        %** Clean-up **;
        drop counter;
    run;
    %let TreatInPeriodExist = 0;
%end;
%else %do;
    %if &UseEx.=1 and %sysfunc(fileexist(&InputEx.)) and %upcase(&StudyDesign.) ne PARALLEL %then %do;
        data &ExData.;
            set &ExData.;
            %** Dont consider time in exposure **;
            ExDate = scan(&ExDateVar., 1, "T");

            %** Add a counter to count the number exposures per subjects (see below for more info) **;
            cntvar = 1;
        run;

        %** Handle exposure **;
        %** Determine the number of average exposures per group **;
        proc summary data = &ExData. nway missing;
            class &UsubjidVar. &SequenceVar. ;
            var cntvar;
            output out = &work.ex_sum1 (drop = _type_ _freq_) sum = sum_cnt;
        run;

        proc summary data = &work.ex_sum1 nway missing;
            class &SequenceVar.;
            var sum_cnt;
            output out = &work.ex_sum2 (drop = _type_ _freq_) mean = mean_cnt;
        run;

        %** Merge the two and create thus create a dataset containing the subjects with enough exposure measurements **;
        proc sort data = &work.ex_sum1;
            by &SequenceVar.;
        run;

        data &work.ex_sum3(drop = sum_cnt mean_cnt);
            merge   &work.ex_sum1(in = a)
                    &work.ex_sum2(in = b);
            by &SequenceVar.;

            %** Clean-up rule **;
            if a and b and sum_cnt >= mean_cnt/2;
        run;

        %** Inner join this dataset with the exposure dataset to remove unwanted subjects **;
        proc sort data = &ExData.(drop = cntvar);
            by &UsubjidVar. &SequenceVar.;
        run;

        proc sort data = &work.ex_sum3;
            by &UsubjidVar. &SequenceVar.;
        run;

        data &ExData.;
            merge   &ExData. (in = a)
                    &work.ex_sum3 (in = b);
            by &UsubjidVar. &SequenceVar.;
            if b;
        run;


        %put ExPeriodVar = &ExPeriodVar.;
        %put PeriodVar = &PeriodVar.;
        %*return;
    
        %if %upcase(&ExPeriodVar.) = %upcase(&PeriodVar.) and &ExPeriodVar. ne %then %do;
            %** Combine exposure in the same period **;
            proc sort data = &ExData.;
                by &SequenceVar. &UsubjidVar. &ExPeriodVar. &ExTrtVar.;
            run;

            %** Combine treatments on the same date **;
            data &ExData.;
                length TreatmentInPeriodText TreatmentInPeriod $800.;
                set &ExData.(keep = &UsubjidVar. &SequenceVar. &ExPeriodVar. &ExTrtVar. ExDate);
                by &SequenceVar. &UsubjidVar. &ExPeriodVar. &ExTrtVar.;
                retain TreatmentInPeriodText;

                if first.&ExPeriodVar. then do;
                    TreatmentInPeriodText = &ExTrtVar.;
                end;
                else if first.&ExTrtVar. then do;
                    TreatmentInPeriodText = strip(TreatmentInPeriodText) || " + " || strip(&ExTrtVar.);
                end;

                if last.&ExPeriodVar. then do;
                    TreatmentInPeriodLength = length(strip(TreatmentInPeriodText));
                    TreatmentInPeriod = put(TreatmentInPeriodLength, z4.) || "_" || strip(TreatmentInPeriodText);
                    output;
                end;

                keep &UsubjidVar. &SequenceVar. &ExPeriodVar. TreatmentInPeriodText TreatmentInPeriod TreatmentInPeriodLength;
            run;

            %** Merge with the input dataset **;

            %CleanArm(input=&ExData.);

            proc sort data = &ExData.;
                by &UsubjidVar. &SequenceVar. &ExPeriodVar;
            run;

            proc sort data = &Input.;
                by &UsubjidVar. &SequenceVar. &ExPeriodVar;
            run;

            data &work.exPP;set  &Input.;run;

            data &Input.(where = (TreatmentInPeriodText ne ""));
                merge   &Input.(in = a)
                        &ExData.(in = b);
                by &UsubjidVar. &SequenceVar. &ExPeriodVar;
                if a;
            run;

            data &work.exJG;set  &ExData.;run;
        

        %end;
        %else %if &UseEx.=1 and %sysfunc(fileexist(&InputEx.)) %then %do;
            %** Combine exposures **;
            %** For each sequence determine the actual treatment **;

            data &work.exJG;set &ExData.;run;
            data &work.ppJG;set &Input.;run;

            proc sort data = &ExData.;
                by &SequenceVar. &UsubjidVar. ExDate &ExTrtVar.;
            run;

            %** Combine treatments on the same date **;
            data &ExData.;
                length TreatmentInPeriodText TreatmentInPeriod prev_trt $200.;
                set &ExData.(keep = &UsubjidVar. &SequenceVar. &ExTrtVar. ExDate);
                by &SequenceVar. &UsubjidVar. ExDate;
                retain TreatmentInPeriodText;

                prev_trt = lag(&ExTrtVar.);
                if first.&UsubjidVar. then do;
                    prev_trt = "";
                end;

                if first.ExDate then do;
                    TreatmentInPeriodText = &ExTrtVar.;
                    
                end;
                else if &ExTrtVar. ^= prev_trt then do;
                    TreatmentInPeriodText = strip(TreatmentInPeriodText) || " + " || strip(&ExTrtVar.);
                end;

                if last.ExDate then do;
                    TreatmentInPeriodLength = length(strip(TreatmentInPeriodText));
                    TreatmentInPeriod = put(TreatmentInPeriodLength, z4.) || "_" || strip(TreatmentInPeriodText);
                    output;
                end;
            run;

            %** Combine multiple days of treatment into one **;
            proc sort data = &ExData.;
                by &SequenceVar. &UsubjidVar. TreatmentInPeriodText ExDate;
            run;

            data &ExData.;
                set &ExData.;
                by &SequenceVar. &UsubjidVar. TreatmentInPeriodText ExDate;

                if first.TreatmentInPeriodText then do;
                    output;
                end;

                %** Clean-up **;
                keep &UsubjidVar. &SequenceVar. TreatmentInPeriodLength TreatmentInPeriod TreatmentInPeriodText ExDate;
            run;

            %** Add a split variable **;
            data &work.exJG;set &ExData.;run;
            data &work.ppJG;set &Input.;run;




            proc sort data = &ExData.;
                by &SequenceVar. &UsubjidVar. ExDate;
            run;

            data &ExData.;
                set &ExData.;
                by &SequenceVar. &UsubjidVar. ExDate;

                if first.&UsubjidVar. then do;
                    SplitVar = 1;
                end;
                else do;
                    SplitVar + 1;
                end;
            run;

            

            %** Add a similiar split variable to the PP dateset **;
            proc sort data = &Input.;
                by &SequenceVar. &UsubjidVar. &ParameterVar. &AnalyteVar. &PeriodVar.;
            run;

            data &Input.;
                set &Input.;
                by &SequenceVar. &UsubjidVar. &ParameterVar. &AnalyteVar. &PeriodVar.;
                    
                if first.&AnalyteVar. then do;
                    SplitVar = 0;
                end;

                if first.&PeriodVar. then do;
                    SplitVar + 1;
                end;
            run;


            %** Merge the two datasets **;

            proc sort data = &Input.;
                by &SequenceVar. &UsubjidVar. SplitVar;
            run;

            proc sort data = &ExData.;
                by &SequenceVar. &UsubjidVar. SplitVar;
            run;

            data &Input.;
                merge   &Input.     (in = a)
                        &ExData.    (in = b);
                by &SequenceVar. &UsubjidVar. SplitVar;
                if a;
            run;
        %end;
        
        %if %sysfunc(exist(&Input.))  %then %do;
            %if %upcase(&StudyDesign.) = SEQUENTIAL %then %do;
                %** Get the treatment sequence (for crossovers force the same sequences always) **;
                proc sql noprint;
                select distinct exdate into:
                exdateList separated by "$$"
                from &Input.
                ;
                quit;

                %put exdatelist=&exdatelist;
                %put exdatelist=&exdatelist;

                %if %symexist(exdatelist) %then %do;
    

                proc sort data = &Input. out = &Input._w1 nodupkey;
                by &SequenceVar. &UsubjidVar. exdate;
                run;
                data &Input._w1;
                    set &Input._w1;
                    by &SequenceVar. &UsubjidVar. exdate;
                    length CohortDescription $300.;
                    retain CohortDescription;

                    if first.&UsubjidVar. then do;
                        CohortDescription = TreatmentInPeriodText;
                    end;
                    else do;
                        CohortDescription = strip(CohortDescription) || " / " || strip(TreatmentInPeriodText);
                    end;

                    if last.&UsubjidVar. then do;
                        CohortLength = length(CohortDescription);
                        output;
                    end;
                run;
				
                %end;
                
                %else %do;
                    proc sort data = &Input. out = &Input._w1 nodupkey;
                    by &SequenceVar. &UsubjidVar. TreatmentInPeriodText;
                    run;
                    data &Input._w1;
                        set &Input._w1;
                        by &SequenceVar. &UsubjidVar. TreatmentInPeriodText;
                        length CohortDescription $300.;
                        retain CohortDescription;

                        if first.&UsubjidVar. then do;
                            CohortDescription = TreatmentInPeriodText;
                        end;
                        else do;
                            CohortDescription = strip(CohortDescription) || " / " || strip(TreatmentInPeriodText);
                        end;

                        if last.&UsubjidVar. then do;
                            CohortLength = length(CohortDescription);
                            output;
                        end;
                    run;
                %end;
            %end;

              /* Create the groups/cohorts */
            %else %do;
          
                %** Get the treatment sequence (for crossovers force the same sequences always) **;
                proc sort data = &Input. out = &Input._w1 nodupkey;
                    by &SequenceVar. &UsubjidVar. TreatmentInPeriodText;
                run;

                data &Input._w1;
                    set &Input._w1;
                    by &SequenceVar. &UsubjidVar. TreatmentInPeriodText;
                    length CohortDescription $300.;
                    retain CohortDescription;

                    if first.&UsubjidVar. then do;
                        CohortDescription = TreatmentInPeriodText;
                    end;
                    else do;
                        CohortDescription = strip(CohortDescription) || "/" || strip(TreatmentInPeriodText);
                    end;

                    if last.&UsubjidVar. then do;
                        CohortLength = length(CohortDescription);
                        output;
                    end;
                run;
            %end;

            %** Get the unique ones per sequence **;
            proc sort data = &Input._w1;
                by &SequenceVar. descending CohortLength;
            run;

            data &Input._w1;
                set &Input._w1;
                by &SequenceVar. descending CohortLength;

                if first.&SequenceVar. then do;
                    output;
                end;

                drop CohortLength;
            run;

            %** Add the groups **;
            proc sort data = &Input._w1;
                by CohortDescription;
            run;

            data &Input._w1;
                set &Input._w1;
                by CohortDescription;
                length CohortName $300.;
                retain CohortName;

                if first.CohortDescription then do;
                    CohortNumber + 1;
                    CohortName = "Cohort " || strip(CohortNumber);
                end;

                keep &SequenceVar. CohortNumber CohortName CohortDescription;
            run;

            %checkcohort(input=&Input._w1);

            %** Merge with the original data **;
            proc sort data = &Input._w1;
                by &SequenceVar.;
            run;

            proc sort data = &Input.;
                by &SequenceVar. &UsubjidVar. &PeriodVar.;
            run;

            data &Input.;
                merge   &Input.     (in = a)
                        &Input._w1  (in = b);
                by &SequenceVar.;
                if a and b;
            run;
            %let TreatInPeriodExist = 1;
        %end;
    %end;
    %else %do;
        %** FIXME!! **;
        %** Account for multiple periods for parallel studies **;
        %if %upcase(&StudyDesign) = PARALLEL and &MaxNumberOfPeriods. > 1 %then %do;
            data &Input.;
                set &Input.;
                &SequenceVar. = strip(&SequenceVar.) || " - " || strip(&PeriodVar.);
            run;

            proc sort data = &Input.
                        out = &work.sequences nodupkey;
                by &SequenceVar.;
            run;
        %end;

        %** Sort **;
        proc sort data = &work.sequences
                   out = &work.groups;
            by &SequenceVar.;
        run;

        %** Create a unique Cohort Number, Name and Description **;
        data &work.groups;
            set &work.groups;
            by &SequenceVar.;
            retain CohortNumber CohortName CohortDescription;

            %** Assign **;
            if first.&SequenceVar. then do;
                CohortNumber + 1;
                CohortName = "Cohort " || strip(CohortNumber);
                CohortDescription = &SequenceVar.;
            end;
        run;
        %let TreatInPeriodExist = 0;
    %end;
%end;

%** Add cohorts **;
%if %sysfunc(exist(&work.groups)) %then %do;
    proc sort data = &Input.;
        by &SequenceVar.;
    run;

    proc sort data = &work.groups;
        by &SequenceVar.;
    run;

    data &Input.(drop = _t:);
        merge   &Input.(in = a)
                &work.groups(in = b);
        by &SequenceVar.;
        if a;
    run;
%end;
%** Save the number of cohorts in a macro variable **;
proc sql noprint;
    select 
        max(CohortNumber)
    into
        :NumberOfCohorts
    from
        &Input.
    ;
quit;

%** Debug **;
%put Number of Groups = &NumberOfCohorts.;

%*********************************************************;
%**                                                     **;
%**                 Comparisons                         **;
%**                                                     **;
%*********************************************************;


%let ProgressGo = success;
%if %upcase(&StudyDesign.) = SEQUENTIAL or %upcase(&StudyDesign.) = CROSSOVER %then %do;
    %if &TreatInPeriodExist. = 0  %then %do;    
        %** For Crossover studies the treatment changes depending on the period **;


        proc sort data = &Input.;
            by &UsubjidVar. &SequenceVar. &PeriodVar.;
        run;



        data &Input.;
            length TreatmentInPeriodText TreatmentInPeriod $200.;
            set &Input.;
            by &UsubjidVar. &SequenceVar. &PeriodVar.;
            retain split;

            if first.&UsubjidVar. then do;
                split = 0;
            end;
            if first.&PeriodVar. then do;
                split + 1;  
            end;

            if scan(&SequenceVar., split, "&Separator.") = &SequenceVar. or scan(&SequenceVar., split, "&Separator.") = "" then do;
                TreatmentInPeriodText = strip(&PeriodVar.);
            end;
            else do;
                TreatmentInPeriodText = strip(scan(&SequenceVar., split, "&Separator."));
            end;
            TreatmentInPeriodLength = length(strip(TreatmentInPeriodText));
            TreatmentInPeriod = put(TreatmentInPeriodLength, z4.) || "_" || strip(TreatmentInPeriodText);
        run;

        %checkppsplit(input=&input, splitvar=split);

     %macro checkpcsplit;
/*      %if %symexist(&PeriodPcVar.) and %upcase(&Type.) = PC %then %do;*/
         %if %upcase(&Type.) = PC %then %do;
            %if &ReAsignMaxNumberOfPeriods=0 %then %do;

                proc freq data=&Input. noprint;
                tables &PeriodVar.*split/out=&work.PCsplit_freq;
                run;

                proc sort data=&work.PCsplit_freq;
                by &PeriodVar. split count; 
                run;

                data &work.PCsplit_freq;
                set &work.PCsplit_freq;
                by &PeriodVar. split count; 
                if last.&PeriodVar. then output;
                rename split=new_pcsplit;
                run;

                proc sort data=&input.;
                by &PeriodVar.;
                run;

                proc sort data=&work.PCsplit_freq;
                by &PeriodVar.;
                run;

                data &work.bothsplit;
                merge &input. &work.PCsplit_freq;
                by &PeriodVar.;
                run;


                data &input.;
                set &work.bothsplit(drop=split);
                rename new_pcsplit=split;
                run;
            %end;

            %if &ReAsignMaxNumberOfPeriods=1 %then %do;

                proc freq data=&Input. noprint;
                tables &PeriodVar.*split/out=&work.PCsplit_freq;
                run;

                proc sort data=&work.PCsplit_freq;
                by &PeriodVar.;
                run;

                data &work.PCsplit_freq;
                set &work.PCsplit_freq;
                by &PeriodVar.;
                if first.&PeriodVar. then new_PCSplit+1;
                retain new_PCsplit;
                run;

                proc sort data=&input.;
                by &PeriodVar.;
                run;

                proc sort data=&work.PCsplit_freq;
                by &PeriodVar.;
                run;

                data &work.bothsplit;
                merge &input. &work.PCsplit_freq;
                by &PeriodVar.;
                run;

                data &input.;
                set &work.bothsplit(drop=split);
                rename new_pcsplit=split;
                run;

             %end;
        %end;
%mend checkpcsplit;
%checkpcsplit;
        /*check pc split ends*/;


        proc sort data=&input.;by  &UsubjidVar. &SequenceVar. &PeriodVar.; run;
        data &Input.;
            set &Input.;
            by &UsubjidVar. &SequenceVar. &PeriodVar.;
            if scan(&SequenceVar., split, "&Separator.") = &SequenceVar. or scan(&SequenceVar., split, "&Separator.") = "" then do;
                TreatmentInPeriodText = strip(&PeriodVar.);
            end;
            else do;
                TreatmentInPeriodText = strip(scan(&SequenceVar., split, "&Separator."));
            end;
            TreatmentInPeriodLength = length(strip(TreatmentInPeriodText));
            TreatmentInPeriod = put(TreatmentInPeriodLength, z4.) || "_" || strip(TreatmentInPeriodText);
        run;
    %end;
    
      
    %checkseparator(input=&input);


    %** Check the data for how many comparisions to do (one versus all) **;
    %** Sort the data **;
    proc sort data = &Input. out = &work.w1 nodupkey;
        by &SequenceVar. &PeriodVar. &AnalyteVar.;
    run;

    %** Count the number of times an analyte occurs per Cohort (if more than two we need to do multiple comparisons) **;
    data &work.w1;
        set &work.w1;
        cnt = 1;
    run;

    proc summary data = &work.w1 nway missing;
        class &SequenceVar. &AnalyteVar.;
        var cnt;
        output out = &work.w2 (drop = _type_ _freq_) sum = ;
    run;

    %** Get the maximum value and create a macro variable with the content **;
    proc sql noprint;
        select 
            max(cnt)
        into
            :AnalytesPerPeriod
        from
            &work.w2
        ;
    quit;
    %put AnalytesPerPeriod = &AnalytesPerPeriod.;
    
    %** FIXME 204671 - p7977-1819 versus 204961 - int6863 **;
    %if &AnalytesPerPeriod. > 2 %then %do;
        %** Create a list of analytes and treatments **;
        proc sql noprint;
            select
                distinct &AnalyteVar.
            into
                :AnalyteList separated by "@"
            from
                &work.w1;
            ;

            select 
                distinct TreatmentInPeriodText
            into
                :TreatmentList separated by "@"
            from
                &work.w1
            ;
        quit;
        %let NumAnalytes = %sysfunc(countw(%nrbquote(&AnalyteList.), @));
        %let NumTreatments = %sysfunc(countw(%nrbquote(&TreatmentList.), @));

        %put NumAnalytes = &NumAnalytes.;
        %put NumTreatments = &NumTreatments.;
        %put AnalyteList = &AnalyteList.;
        %put TreatmentList = &TreatmentList.;
        
        %** Create all combinations **;
        data &Input.;
            set &Input.;
            length Combination $200.;
            
            %** Define the arrays **;
            array AnalyteArray{&NumAnalytes.}$200. (
                %do i = 1 %to &NumAnalytes.;
                    "%scan(%nrbquote(&AnalyteList.), &i., @)"
                %end;
            );

            array TreatmentArray{&NumTreatments.}$200 (
                %do i = 1 %to &NumTreatments.;
                    "%scan(%nrbquote(&TreatmentList.), &i., @)"
                %end;
            );

            %** Loop and output depending on the treatments **;
            do i = 1 to dim(AnalyteArray);
                if strip(&AnalyteVar.) = strip(AnalyteArray{i}) then do;
                    do j = 1 to dim(TreatmentArray);
                        if strip(TreatmentInPeriodText) = strip(TreatmentArray{j}) then do;
                            do k = 1 to dim(TreatmentArray);
                                if j > k then do;
                                    Combination = strip(TreatmentArray{k}) || " ~vs~ " || strip(TreatmentArray{j});
                                    output;
                                end;
                                else if j < k then do;
                                    Combination = strip(TreatmentArray{j}) || " ~vs~ " || strip(TreatmentArray{k});
                                    output;
                                end;
                            end;
                        end;
                    end;
                end;
            end;

            %** Clean-up **;
            drop AnalyteArray: TreatmentArray: i j k;
        run;
        
 
    %end;
    %else %do;
        %** Create the possible comparisions **;
        proc sort data = &Input.;
            %if %upcase(&Type.) = PC %then %do;
/*                by &UsubjidVar. &AnalyteVar. TreatmentInPeriod &PeriodVar. &TimeVar.;*/
                by &UsubjidVar. &AnalyteVar. &PeriodVar. &TimeVar.; 
            %end;
            %else %do;
                by &UsubjidVar. &ParameterVar. &AnalyteVar. TreatmentInPeriod &PeriodVar.;
                *fixme: recent change;
                *by &UsubjidVar. &ParameterVar. &AnalyteVar. &PeriodVar.;
            %end;
        run;


        data &work.combinations;
            set &Input.;
            %if %upcase(&Type.) = PC %then %do;
                by &UsubjidVar. &AnalyteVar. &PeriodVar. &TimeVar.;
            %end;
            %else %do;
                by &UsubjidVar. &ParameterVar. &AnalyteVar. TreatmentInPeriod &PeriodVar.;
                *fixme: recent change - added to avoid crossover studies generating comparison that didnt exist;
                *fixme: A - B, B - A created A vs B and B vs A - thus no pair;
                *by &UsubjidVar. &ParameterVar. &AnalyteVar. &PeriodVar.;
            %end;
            length Combination $200.;
            retain Combination;

            if first.&AnalyteVar. then do;
                Combination = strip(TreatmentInPeriodText);
            end;
            else if not index(Combination, "~vs~") and first.&PeriodVar. then do;
                if length(Combination) > length(TreatmentInPeriodText) then do;
                    Combination = strip(TreatmentInPeriodText) || " ~vs~ " || strip(Combination);
                end;
                else do;
                    Combination = strip(Combination) || " ~vs~ " || strip(TreatmentInPeriodText);
                end;
            end;

            %if %upcase(&Type.) = PC %then %do;
                if last.&PeriodVar. and findw(Combination, "~vs~") then do;
                    output;
                end;

                keep &UsubjidVar. &AnalyteVar. Combination;
            %end;
            %else %do;
                if last.&AnalyteVar. and findw(Combination, "~vs~") then do;
                    output;
                end;

                keep &UsubjidVar. &ParameterVar. &AnalyteVar. Combination;
            %end;
        run;
       


        %** If rare cases no combinations can be found - so use visit as a combination **;
        %SmGetNumberOfObs(Input = &work.combinations);
        %if &NumberOfObs. = 0 %then %do;
            proc sort data = &Input.;
                by &UsubjidVar. &PeriodVar.;
            run;

            data &work.combinations;
                set &Input.;
                by &UsubjidVar. &PeriodVar.;
                length Combination $200.;
                retain Combination;

                if first.&UsubjidVar. then do;
                    Combination = strip(&PeriodVar.);
                end;
                else if not index(Combination, "~vs~") and first.&PeriodVar. then do;
                    if length(Combination) > length(&PeriodVar.) then do;
                        Combination = strip(&PeriodVar.) || " ~vs~ " || strip(Combination);
                    end;
                    else do;
                        Combination = strip(Combination) || " ~vs~ " || strip(&PeriodVar.);
                    end;
                end;

                if last.&UsubjidVar. and findw(Combination, "~vs~") then do;
                    output;
                end;

                keep &UsubjidVar. Combination;
            run;
        %end;
 
        %** Merge with the input dataset **;
        data &Input.;
            merge   &Input. (in = a)
                    &work.combinations (in = b);
            %if %upcase(&Type.) = PC and &NumberOfObs. >= 1 %then %do;
                by &UsubjidVar. &AnalyteVar.;
            %end;
            %else %if %upcase(&Type.) = PP and &NumberOfObs. >= 1 %then %do;
                by &UsubjidVar. &ParameterVar. &AnalyteVar.;
            %end;
            %else %do;
                by &UsubjidVar.;
            %end;

            if a;
        run;
  
    %end;
       
    %if %upcase(&StudyDesign.) = SEQUENTIAL %then %do;
 
        data &input.;
            set &input.;
            first=scan(combination,1, "~vs~");
            last=scan(combination, -1,"~vs~");
            if indexw(upcase(cohortdescription), trim(first), " / ") ne 0 and indexw(upcase(cohortdescription), trim(last), " / ") ne 0 then do;
                meng=1;
                PosFirst=indexw(cohortdescription, trim(first)," / ");
                PosLast=indexw(cohortdescription,trim(last)," / ");
                if posFirst >posLast then find=1; else find=0;
            end;

            else do;
                meng=0;
            end;

            if find=1 then combination_correct= strip(last) || " ~vs~ " || strip(first);
                else combination_correct=combination;
        run;
  
        data &input.(drop=combination rename=(combination_correct=combination));
            set &input. ;
        run;
   %end;

%end;
 
%else %if %upcase(&StudyDesign.) = PARALLEL and &NumberOfCohorts. > 1 %then %do;
    %** Make reference global **;
    %global reference;
    
    %** Is one of the treatment a reference? and how any do we have?**;
    proc sort data = &Input. out = &work.references nodupkey;
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
        %if %nrbquote(&reference.) eq %then %do;
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
        %end;
    %end;

    proc sql noprint;
        %** We can have multiple periods, so that needs to be accounted for **;
        select distinct
            &PeriodVar.
        into
            :period_list separated by "@"
        from
            &Input.
        ;
    quit;
    %put The references are: &Reference.;

    %if %symexist(reference) %then %do;
        %if &numref. = 1 %then %do;
            %** Debug **;
            %put Reference Treatment = &reference.;

            %** Get the treatments that are not references **;
            proc sql noprint;
                select distinct
                    &SequenceVar.
                into:
                    arm_list separated by "@"
                from
                    &Input.(where = (&SequenceVar. ^= "&reference."))
                ;
            quit;

            %** Debug **;
            %put Non-reference arms = &arm_list.;
            
            %** For the treatments add the comparison variables **;
            data &Input.;
                length Combination CohortName CohortDescription TreatmentInPeriodText TreatmentInPeriod reference comb1 comb2 $200.;
                set &Input.;
                CohortNumber = 1;
                CohortName = "Cohort";
                CohortDescription = CohortName;
                Combination = "&reference." || " ~vs~ All Arms";
                Comb1 = "&reference.";
                Comb2 = "&SequenceVar.";
                TreatmentInPeriodText = &SequenceVar.;
                TreatmentInPeriodLength = length(strip(TreatmentInPeriodText));
                TreatmentInPeriod = strip(TreatmentInPeriodLength) || "_" || strip(TreatmentInPeriodText);
                Reference = "&Reference";
            run;
        %end;
        %else %do;
            %** Loop for each period **;
            %do k = 1 %to %sysfunc(countw(&period_list., @));
                proc sql noprint;
                    %** Get the different treatments **;
                    select distinct
                        &SequenceVar.
                    into
                        :arm_list separated by "@"
                    from
                        &Input.(where = (&PeriodVar. = "%qscan(&period_list., &k., @)"))
                    order by
                        &SequenceVar.
                    ;

                    %** All treatments are references (in principle) **;
                    select distinct
                        &SequenceVar.
                    into
                        :reference_list separated by "@"
                    from
                        &Input.(where = (&PeriodVar. = "%qscan(&period_list., &k., @)"))
                    order by
                        &SequenceVar.
                    ;
                quit;

                %** Prepare the data **;
                data &Input._&k.;
                    set &Input.(where = (&PeriodVar. = "%qscan(&period_list., &k., @)"));
                    length Combination CohortName CohortDescription TreatmentInPeriodText TreatmentInPeriod reference comb1 comb2 $200.;
                    %do i = 1 %to %sysfunc(countw(%nrbquote(&arm_list.), @));
                        %do j = 1 %to %sysfunc(countw(%nrbquote(&reference_list.), @));
                            %if %nrbquote(%scan(%nrbquote(&arm_list.), &i., @)) ne %nrbquote(%scan(%nrbquote(&reference_list.), &j., @)) %then %do;
                                CohortNumber = 1;
                                CohortName = "Cohort";
                                CohortDescription = CohortName;
                                Comb1 = "%scan(%nrbquote(&arm_list.), &i., @)";
                                Comb2 = "%scan(%nrbquote(&reference_list.), &j., @)";
                                Combination = "%scan(%nrbquote(&arm_list.), &i., @)" || " ~vs~ " || "%qscan(%nrbquote(&reference_list.), &j., @)";
                                TreatmentInPeriodText = &SequenceVar.;
                                TreatmentInPeriodLength = length(strip(TreatmentInPeriodText));
                                TreatmentInPeriod = strip(TreatmentInPeriodLength) || "_" || strip(TreatmentInPeriodText);
                                Reference = "%scan(%nrbquote(&reference_list.), &j., @)";
                                output;
                            %end;
                        %end;
                    %end;
                run;
            %end;

            %** Combine **;
            data &Input.;
                set 
                    %do k = 1 %to %sysfunc(countw(&period_list., @));
                        &Input._&k.
                    %end;
                ;
            run;
        %end;
    %end;
%end;
%else  %do; 
    %let ProgressGo = fail;
%end;

%global Separatorx;
%let Separatorx=&Separator;
%mend;
