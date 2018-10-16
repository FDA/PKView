

%macro SmDetermineStudyDesignJiaxiang(
    InputEx = ,
    UsubjidVar = ,
    SequenceVar = ,
    ExTrtVar =,
    ExDateVar =
);



*******************************************************************;

%let ExSequenceVar=EXSTDTC;
%let MissingDate=0;

%if &UseEx.=1 and %SYSFUNC(EXIST(&InputEx.)) %then %do;
    data &work.ex2;
      set &InputEx.;
      run;
%end;

%cleanarm(
    input = &work.dm_cleaned,
    output = &work.dm_cleaned0
);

data &work.one0;
    set &work.ex2;
    format Mydate is8601dt.;
    Exdate=scan(EXSTDTC,1,"T");
    %if &UseEx.=1 and %SYSFUNC(EXIST(&InputEx.)) %then %do;
        dset=open('&work.ex2');
        if varnum(dset,'VisitNum')>0 then do;
            call symputx("ExSequenceVar","VisitNum");
            if missing(&ExSequenceVar) then call symputx("MissingDate",1);
        end;
        if varnum(dset,'VisitNum')=0 then do;
           call symputx("ExSequenceVar","Exdate");
           if missing(&ExSequenceVar) then call symputx("MissingDate",1);
        end; 
    %end;
run;

%put &ExSequenceVar;
%put &MissingDate;
%put &inputex;

%let CountVar = ;
%if &UsubjidVar. ne %then %do;
    proc freq data=&work.ex2 noprint;
        tables &USUBJIDVAR/nopercent nocum norow out=&work.aa ;
    run;

    data &work.aa; 
        set &work.aa; 
        rename count=exposure_count;
    run;
    %let CountVar = count;

    proc freq data=&work.aa noprint;
        tables exposure_count/nopercent nocum norow out=&work.freq;
    run;  

    data &work.freq; 
        set &work.freq; 
        rename count=exposure_freq;
    run;
        
    proc sort data=&work.freq; 
        by decending percent 
    ;run;

    data &work.freq; 
        retain one_cohort;
        set &work.freq;
        OneEx=1;
        Count+1;
        Cumpct+percent;
        if count=1 and cumpct>70 then one_cohort=1;
        if one_cohort=1 and count>1 then OneEx =0;
    run;

    proc sort data=&work.freq; 
        by decending percent 
    ;run;

    data &work.freq;
        set &work.freq;
        keep=1;
        if _n_>1 and cumpct>90 then keep=0;
    run;

    data &work.freq;
        set &work.freq;
        if cumpct>90 then difference=cumpct-90;
    run;

    proc means data=&work.freq min noprint;
        var difference;
        output out=&work.min_difference min=min;
    run;

    data &work.test;
        merge &work.freq &work.min_difference;
        retain min1;
        if _n_ = 1 then do;
            min1 = min; 
        end;
        drop _freq_ _type_ m1 m2 min;
    run;

    data &work.freq;
        set &work.test;
        if difference=min1 then keep=1;
    run;

    proc sort data=&work.aa; 
        by exposure_count; 
    run;
            
    proc sort data=&work.freq; 
        by exposure_count; 
    run;    
        
    data &work.aa2;
        merge &work.aa &work.freq; 
        by exposure_count;
    run;
        
    proc sort data=&work.aa2 ;
        by decending exposure_freq;
    run;

    
    proc sort data=&work.one0; 
        by &USUBJIDVAR; 
    run;

    proc sort data=&work.aa2; 
        by &USUBJIDVAR; 
    run;

    data &work.one1;
        merge &work.one0 &work.aa2;
        by &USUBJIDVAR;
    run;

    data &work.one;
        set &work.one1;
        if (exposure_freq>2 and keep=1 and one_cohort ne 1) or (exposure_freq>2 and oneEx=1 and one_cohort=1) ;
    run;

    data &work.exsum;
        set &work.one(keep= &UsubjidVar.);
    run;

    proc sort data=&work.exsum nodupkey; 
        by &UsubjidVar.;
    run;

    proc sort data=&work.ex2; 
        by usubjid;
    run;

    proc sort data=&work.one; 
        by &USUBJIDVAR &ExTrtVar;
    run;

    data &work.excluded;
        merge &work.ex2(in=n) &work.one(in=c);
        by &USUBJIDVAR;
        if n and not c;
    run;

    %if &SequenceVar. ne %then %do;
        data &work.dm_cleaned1; 
            set &work.dm_cleaned0; 
            if index(&SEQUENCEVAR,"ail")=0;
        run;

        data _NULL_;
            if 0 then set &work.dm_cleaned1 nobs=n;
            call symputx('Nsubj',n);
            stop;
        run;
    %end;

    proc sort data=&work.excluded out=&work.excludeSubj nodupkey; 
        by usubjid;
    run;

    data _NULL_;
        if 0 then set &work.excludeSubj nobs=n;
        call symputx('NexcludeSubj',n);
        stop;
    run;

    *Number of Cohorts;
    data &work.cohorts_trt; 
        set &work.one;
        by &USUBJIDVAR &ExTrtVar;
        length Cohort_trt $1000.;
        if first.&ExTrtVar then countx=1;
            else countx+1;
        if countx=1 then cohort_trt=strip(&ExTrtVar)||"_S";
            else if countx>1 then cohort_trt=strip(&ExTrtVar)||"_M";
        if last.&ExTrtVar then output;
    run;

    proc sort data=&work.cohorts_trt;
        by &USUBJIDVAR;

    data &work.cohorts;
        set &work.cohorts_trt(keep=&UsubjidVar &ExTrtVar Cohort_trt countx);
        by &USUBJIDVAR;
        prev_cohort=lag(Cohort_trt);
        if first.&UsubjidVar then prev_cohort="";
            else cohort_trt=strip(Cohort_trt)||"@"||strip(prev_cohort);
        if last.&UsubjidVar then output;
    run;

    proc freq data=&work.cohorts noprint;
        tables Cohort_trt/out=&work.N_cohorts;
    run;

    data _NULL_;
        if 0 then set &work.N_cohorts nobs=n;
        call symputx('N_cohorts',n,"G");
        stop;
    run;
    %put N_cohorts=&N_cohorts;

    data &work.one2;
        set &work.one(keep= &USUBJIDVAR EXTRT &ExSequenceVar &CountVar.);
    run;

    proc sort data=&work.one2; 
        by &USUBJIDVAR &ExSequenceVar &ExTrtVar.; 
    run;

    data &work.two;
        length trt_list prev_trt $1000.;
        set &work.one2;
        by &UsubjidVar. &ExSequenceVar &ExTrtVar.;
        retain trt_list;

        prev_trt = lag(&ExTrtVar.);
        prevdate=lag(&ExSequenceVar);
        if first.&UsubjidVar. then do;
            prev_trt = "";
        end;
        
        if first.&ExSequenceVar then do;
            trt_list = &ExTrtVar.;
        end;

        if first.&ExSequenceVar=0 then do;
            if &ExSequenceVar = prevdate then 
                trt_list = strip(trt_list) || " + " || strip(&ExTrtVar.);
        end;
            
       if last.&ExSequenceVar then output;    
    run;

    data &work.three;
        set &work.two;
        %if &UsubjidVar. ne %then %do;
            by  &UsubjidVar.;
        %end;
        length extrt_list $1000.;
        retain CurrCnt;

        %** Add previous treatment in the sequence before **;
        prev_trt = lag(trt_list);
        if first.&UsubjidVar. then do;
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
                extrt_list = strip(prev_trt) || "_" || strip(CurrCnt);
            end;
            else do;
                extrt_list = strip(prev_trt) || "_" || strip(CurrCnt);
            end;
            CurrCnt = cnt;
            output;
        end;
        
        if last.&UsubjidVar. then do;
            if trt_list ^= prev_trt then do;
                extrt_list = strip(trt_list) || "_" || strip(CurrCnt);
                output;
            end;
            else if first.&UsubjidVar. = last.&UsubjidVar. then do;
                extrt_list = strip(trt_list) || "_" || strip(CurrCnt);
                output;
            end;
            else do;
                extrt_list = strip(trt_list) || "_" || strip(CurrCnt);
                output;
            end;
        end;
    
        %** Clean-up **;
        drop currcnt cnt &ExTrtVar. prev_trt trt_list prevdate;
    run;

    proc sort data=&work.three; 
        by &USUBJIDVAR &ExSequenceVar;
    run;

    data &work.four;
        set &work.three;
        by &USUBJIDVAR &ExSequenceVar;
        retain reg;

        if first.usubjid then do;
            reg= extrt_list;
        end;

        if first.usubjid=0 then do;
            reg= strip(reg) || "@" || strip(extrt_list);
        end;

        if last.&USUBJIDVAR then output;
    run;

    proc freq data= &work.four noprint;
        tables reg/out=&work.four1;
    run;

    data _NULL_;
        if 0 then set &work.four1 nobs=n;
        call symputx('N_reg',n);
        stop;
    run;

    proc sort data=&work.three out=&work.five; 
        by &USUBJIDVAR extrt_list;
    run;

    data &work.six;
        set &work.five;
        by &USUBJIDVAR extrt_list;
        retain unique_reg;

        if first.&USUBJIDVAR then do;
            unique_reg= extrt_list;
        end;    

        if first.&USUBJIDVAR=0 then do;
            unique_reg= strip(unique_reg) || "@" || strip(extrt_list);
        end;

        if last.&USUBJIDVAR then output;
    run;

    data &work.sex;
        set &work.six;
    run;

    proc freq data= &work.six noprint;
        tables unique_reg/out=&work.six1;
    run;
        
    data _NULL_;
        if 0 then set &work.six1 nobs=n;
        call symputx('N_unique_reg',n);
        stop;
    run;

    *parallel and sequential;
    proc sort data=&work.four; 
        by &USUBJIDVAR;
    run;
    proc sort data=&work.dm_cleaned1; 
        by &USUBJIDVAR;
    run;

    data &work.dm2;
        merge &work.four &work.six &work.dm_cleaned1;
        by &USUBJIDVAR;
    run;

    proc sort data=&work.dm2; 
        by arm;
    run;

    data &work.dm3;
        retain arm2;
        set &work.dm2;
        by arm;
        if first.arm then arm2=unique_reg;
        retain arm2;
    run;

    proc sort data=&work.dm3; 
        by arm2;
    run;
        
    data &work.dm2;
        set &work.dm3;
        by arm2;
        retain cohort;
        if first.arm2 then cohort+1;
    run;

    proc sort data=&work.four; 
        by &USUBJIDVAR;
    run;

    data &work.par;
        length dm_seq $1000;
        merge &work.four(in=a) &work.dm_cleaned1(in=b);
        by &USUBJIDVAR;
        if a;
        dm_seq=&sequencevar||"~~"||strip(reg);
    run;

    proc freq data= &work.par  noprint;
        tables dm_seq / out=&work.par1;
    run;
        
    data _NULL_;
        if 0 then set &work.par1 nobs=n;
        call symputx('N_DM_reg',n);
        stop;
    run;

    *Additial Parallel check;
    data _NULL_;
        if 0 then set &work.ex2 nobs=n;
        call symputx('N_EX_obs',n);
        stop;
    run;

    proc freq data=&work.ex2 noprint;tables &USUBJIDVAR/out=&work.EX_usubjid;run;
    data _NULL_;
        if 0 then set &work.EX_usubjid nobs=n;
        call symputx('N_EX_subj',n);
        stop;
    run;
%end;

data &work.studydesign;
    %if &UsubjidVar. ne %then %do;
        if &N_reg>&N_unique_reg then do ;
           design="Crossover  ";
           Ncohort=&N_unique_reg;
           call symputx('StudyDesignx',design,"G");
        end;
        else if &N_reg=&N_unique_reg and &N_DM_reg>&N_reg then do;
           design="Parallel   ";
           Ncohort=&N_unique_reg;
           call symputx('StudyDesignx',design,"G");
        end; 
        else if &N_reg=&N_unique_reg and &N_DM_reg=&N_reg then do;
           design="Sequential";
           Ncohort=&N_unique_reg;
           call symputx('StudyDesignx',design,"G");
        end; 
        if &N_EX_obs=&N_EX_subj then do;
           design="Parallel   ";
           Ncohort=&N_unique_reg;
           call symputx('StudyDesignx',design,"G");
        end; 
    %end;
    %else %do;
        design="Unknown    ";
        Ncohort=0;
        call symputx('StudyDesignx',design,"G");
    %end;
run;

*Output start here;
ods escapechar='^';
ods text ="Studyname = &study_name";
ods text= "Nsubj = &Nsubj   NexcludeSubj = &NexcludeSubj";
ods text= "N_reg = &N_reg   N_unique_reg = &N_unique_reg   N_DM_reg = &N_DM_reg";
ods text="ExSequenceVar = &ExSequenceVar"; 
ods text="Missing ExSequecne = &MissingDate"; 
ods text= "^{style [color=green FONT_WEIGHT=bold]StudyDesignx = &StudyDesignx}";
ods text=" Number of Cohorts= &N_cohorts";
ods text= "N_EX_obs = &N_EX_obs   N_EX_subj = &N_EX_subj";

ods text="Final Unique Sequences = &UniqueSequences" ;
ods text="UniqueSequences = &UniqueSequences";
ods text=" Number of Groups = &NumberOfCohorts";
ods text=" Number of Sequences = &NumberOfSequences";

%if &UsubjidVar. ne %then %do;

    proc freq data= &work.four noprint;
        tables reg/out=&work.four1;
    run;

    *assign number of cohorts to dm, new dm called &work.dm2;
    proc sort data=&work.cohorts;
        by Cohort_trt;
    run;
    data &work.cohorts_num;
        set &work.cohorts;
        by cohort_trt;
        if first.cohort_trt then Cohort_Num+1;
        retain Cohort_Num 
    ;run;

    data &work.cohorts_merge;
        set &work.cohorts_num(keep=USUBJID Cohort_trt Cohort_Num);
    run;

    proc sort data=&work.dm; 
        by USUBJID;
    run;
    proc sort data=&work.cohorts_merge; 
        by USUBJID;
    run;

    data &work.dm2;
        merge &work.dm &work.cohorts_merge;
        by USUBJID; 
    run;

    proc sort data=&work.dm2; 
        by ARM decending cohort_trt;
    run;

    *if not parallel then do this;
    %if &StudyDesignx ne "Parallel   " %then %do;
        data &work.dm3;
            set &work.dm2; 
            by arm;
            if first.ARM then do; 
                Cohort_trt1=cohort_trt; 
                cohort1=cohort_num;
            end;
            retain cohort_trt1 cohort1;
        run;

        data &work.dm2;
            set &work.dm3(drop=cohort_trt cohort_num);
            rename cohort1=Cohort_Num;
            rename cohort_trt1=Cohort_Trt;
        run;

        proc sort data=&work.four;
            by &USUBJIDVAR;
        run;
        proc sort data=&work.dm2;
            by &USUBJIDVAR;
        run;

        data &work.dm3;
            merge &work.four(in=a) &work.dm2(in=b);
            by &USUBJIDVAR;
            if b; 
        run;
        
    %end;
%end;

%mend;
