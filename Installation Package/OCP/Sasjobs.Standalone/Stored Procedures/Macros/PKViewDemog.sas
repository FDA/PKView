%*****************************************************************************************;
%**                                                                                     **;
%** Run script to generate demographic summary in similar format as sponsors reports    **;
%**                                                                                     **;
%** Starting Point- Read users mapping from interface                                   **;
%**                                                                                     **;
%** Created by Meng Xu (2015-09)                                                        **;
%**                                                                                     **;
%*****************************************************************************************;


%macro PKViewDemog();

data _null_;
set websvc.study;
call symput("DEMOGRAPHICTABLE",DEMOGRAPHICTABLE);
run;
%put DEMOGRAPHICTABLE=&DEMOGRAPHICTABLE;

%IF &DEMOGRAPHICTABLE=1 %THEN %DO;

/* Read mappings from websvc input dataset (provided by C#) */
%SmReadMappingsFromDataSet();


/* Retrieve NDA Id */
%let Nda_Number=&SubmissionId.;

/* Generate output path based on NDA Id, User Id and settings Id */
%let OutputFolder = &SasSpPath.\Output Files\PKView\&UserName.\&ProfileName.\&nda_number.\&SupplementNum;
        

%** Retrieve NDA Id **;
%let Nda_Number=&SubmissionId.;
    
%** Generate output path based on NDA Id, User Id and settings Id **;
%let OutputFolder = &SasSpPath.\Output Files\PKView\&UserName.\&ProfileName.\&nda_number.\&SupplementNum;

  
%let CurrentStudy = &StudyId.;
%put ------------------------------------------FIXME-----------------------------------------------------;
%put The current study is: &StudyId.;       

%global InputDm InputPc InputEx InputPp SequenceVar PeriodPcVar PeriodPpVar AnalytePcVar AnalytePpVar 
        ResultPcVar ResultPpVar TimeVar ParameterVar ExTrtVar ExDateVar ExPeriodVar;

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
    
%SmReadAndMergeDataset(
    Input1 = &InputDm.,
    Input2 = &InputPp.,
    UsubjidVar = &UsubjidVar.,
    Output = &work.adpp
);

/* Replace DM arm variable with custom one */
%if &UseCustomArms.=1 %then %do;
    proc sort data = &work.adpp; by &ArmVar.; run;
    proc sort data = &work.customDmArms; by OldArm; run;
    data &work.adpp(rename=(NewArm=&ArmVar.));
        merge &work.adpp(rename=(&ArmVar.=OldArm) in=hasData)
              &work.customDmArms;
        by OldArm;
        if hasData;
    run;        
%end;

%if %upcase(&StudyDesign.) = PARALLEL %then %do;
    %SmParallelGrouping(
        Input = &work.adpp,
        UsubjidVar = &UsubjidVar.,
        SequenceVar = &SequenceVar.,
        UseSuppdm = &UseSuppdm.,
        DataPath = &InputDm.
    );
%end;   

%if &UseEx.=1 and %sysfunc(fileexist(&InputEx.)) %then %do;
    %SmReadAndMergeDataset(
        Input1 = &InputDm.,
        Input2 = &InputEx.,
        UsubjidVar = &UsubjidVar.,
        Output = &work.adex
    );

    %if %upcase(&StudyDesign.) = PARALLEL %then %do;
        %SmParallelGrouping(
            Input = &work.adex,
            UsubjidVar = &UsubjidVar.,
            SequenceVar = &SequenceVar.,
            UseSuppdm = &UseSuppdm.,
            DataPath = &InputDm.
        );
    %end;
%end;

%** If we found the study design and dont have a period variable - create it **;
%if &StudyDesign. ne and &PeriodPpVar. eq %then %do;
    proc sort data = &work.adpp;
        by &UsubjidVar. &AnalytePpVar. &ParameterVar.;
    run;

    data &work.adpp;
        set &work.adpp;
          by &UsubjidVar. &AnalytePpVar. &ParameterVar.;
        length EstPeriodVar $20.;
        retain cnt;

        %** Add the period content **;
        if first.&ParameterVar. then do;
            cnt = 1;
        end;
        else do;
            cnt + 1;
        end;
        EstPeriodVar = cat("Period ", cnt);
        
        %** Clean-up **;
        drop cnt;
    run;
    %let PeriodPpVar = EstPeriodVar;
%end;  

%** Then process **;
%if %upcase(&StudyDesign.) ne UNKNOWN and &PeriodPpVar. ne and &SequenceVar. ne 
    and &AnalytePpVar. ne and &ParameterVar. ne %then %do;
    %SmPrepareDataForAnalysis(
            Input = &work.adpp,
            SequenceVar = &SequenceVar.,
            AnalyteVar = &AnalytePpVar.,
            ParameterVar = &ParameterVar.,
            PeriodVar = &PeriodPpVar.,
            ResultVar = &ResultPpVar.,
            ExData = &work.adex,
            %if %SYMEXIST(ExTrtVar) %then %do;
              ExTrtVar = &ExTrtVar.,
            %end;
            %if %SYMEXIST(ExDateVar) %then %do;
              ExDateVar = &ExDateVar.,
            %end;
            ExPeriodVar = &PeriodExVar.,
            Type = pp,
            StudyArea = &StudyType.,
            StudyDesign = &StudyDesign.
    );
%end;

/*Assign the macro variable back because of different naming*/
%global  SequenceVar;

%put sequencevar=&sequencevar;


data input1;
set input1;
if indexw(&sequencevar.,"SCRNFAIL" )or 
indexw(&sequencevar.,"SCREEN FAILURE" )or
indexw(&sequencevar.,"Screen Failure" )or
indexw(&sequencevar.,"screen failure" )or
indexw(&sequencevar.,"Not Assigned" ) or
indexw(&sequencevar.,"NOT ASSIGNED" ) or
indexw(&sequencevar.,"not assigned" ) or
indexw(&sequencevar.,"NOTASSGN" )then delete;
run;

/*step 1- treat sequential and paralell studies*/
%if %upcase(&StudyDesign.) ne CROSSOVER %then %do;

    /*part 1.1: categorical variable-country, race, sex and ethnicity classed by group*/
    proc sql;
    create table allmapwant as
    select * from websvc.mapping
    where domain in ("DM") and stdmvar not in ("USUBJID","ARM") and filevar not in (" ");

    create table condemo as
    select * from allmapwant
    where stdmvar in ("AGE");

    create table catdemo as
    select * from allmapwant
    where stdmvar not in ("AGE");
    quit;

    proc sql noprint;
    select distinct filevar into: catvarlist separated by "$" from catdemo;
    select distinct &sequencevar. into:sequencevarlist separated by "$" from input1;
    quit;

    %put sequencevar=&sequencevar.;
    %let numseq=%sysfunc(countw(%nrbquote(&sequencevarlist.),$));
    %put catvarlist=&catvarlist;
    %put sequencevarlist=&sequencevarlist;
    %put numseq=&numseq;

    /*number of sequences*/
    %do a=1 %to &numseq;
        data input1;
            set input1;
            if &sequencevar.="%scan(%nrbquote(&sequencevarlist.), &a., "$")" then do;
                newseq=tranwrd(&sequencevar.,trim("%scan(%nrbquote(&sequencevarlist.), &a., "$")"),trim("Arm&a."));
            end;
        run;
    %end;

    /*generate frequency table for each categorical variable*/
    %do i = 1 %to %sysfunc(countw(%nrbquote(&catvarlist.), $)); 

        proc freq data=input1 noprint;
            tables %scan(%nrbquote(&catvarlist.),&i.,"$")*newseq/out=cat&i. outpct;
        run;

        data cat&i.;
            set cat&i.;
            drop percent pct_row;
            rename PCT_COL=percent;
        run;

        /*merge count and percent as sponsors' formats*/
        data cat&i.;
            length Count_Percent $200;
            set cat&i.;

            percent=round(percent,0.01);
            if count ne . and percent ne . then do ;
            Count_Percent= cats(count, " (", percent, ")");
            drop percent count;
        end;

        /*to change: newseq. change to cohortdescription*/
        proc transpose data=cat&i. out=catout&i.(drop=_label_);
            by %scan(%nrbquote(&catvarlist.),&i.,"$");
            id newseq;
            var count_percent;
        run;

        /*reshape by create couters- catn and order*/
        data catout&i.;
            length whichvar $20 cat _NAME_ $200;
            set catout&i;
            by %scan(%nrbquote(&catvarlist.),&i.,$);
            catn+1;
            order=&i;
            whichvar="%scan(%nrbquote(&catvarlist.),&i.,"$")";
            if %scan(%nrbquote(&catvarlist.),&i.,"$") ne "     " then cat=%scan(%nrbquote(&catvarlist.),&i.,"$");
            drop %scan(%nrbquote(&catvarlist.),&i.,"$");
        run;

        /*part 1.2 categorical variables for Overall*/
        proc freq data=input1 noprint;
            tables %scan(%nrbquote(&catvarlist.),&i.,"$")/out=catoverall&i.;
        run;

        /*merge count and percent, round values*/
        data catoverall&i.;
            length Count_Percent $200;
            set catoverall&i.;
            percent=round(percent,0.01);
            if count ne . and percent ne . then do ;
            Count_Percent= cats(count, " (", percent, ")");
            drop percent count;
        end;

        *to change: newseq. change to cohortdescription;
        proc transpose data=catoverall&i. out=catoverall&i.(drop=_label_);
            by %scan(%nrbquote(&catvarlist.),&i.,"$");
            var count_percent;
        run;

        *reshape;
        data catoverall&i.;
            length whichvar $20 cat _NAME_ $200;
            set catoverall&i.;
            by %scan(%nrbquote(&catvarlist.),&i.,$);
            catn+1;
            order=&i;
            whichvar="%scan(%nrbquote(&catvarlist.),&i.,"$")";
            if %scan(%nrbquote(&catvarlist.),&i.,"$") ne "     " then cat=%scan(%nrbquote(&catvarlist.),&i.,"$");
            drop %scan(%nrbquote(&catvarlist.),&i.,"$");
        run;

        /*merge overall and grouped categorical variables into one table for each variable*/
        proc sort data=catout&i.;
            by whichvar cat order catn;
        run;

        proc sort data=catoverall&i.;
            by whichvar cat order catn;
        run;

        data catout&i.;
            merge catout&i. catoverall&i.;
            by whichvar cat order catn ;
            rename COL1=Overall;
        run;

    %end;

    *put categorical summary into one tables and reshape the categoriacal summary table;
    data CatAll;
        set 
            %do i = 1 %to %sysfunc(countw(%nrbquote(&catvarlist.), $));      
                %if %sysfunc(exist(catout&i.)) %then %do;
                    catout&i.
                %end;

            %end;
           ;
    run;
    
    /*part2.1 continous variable: age by group*/
    proc sql noprint;
        select distinct filevar into: convar separated by "$" from condemo;
        select distinct newseq into:cohlist separated by "$" from input1;
    quit;
    %put convar=&convar;
    %put cohlist=&cohlist;  

    /*generate descriptive statistics*/
    proc means data=input1 maxdec=2 noprint;
        var &convar.;
        class newseq;
        output out=condata n=nn mean=nmean std=nstd median=nmedian min=nmin max=nmax ;
    run;

    /*delete unused one*/
    data condata;
        set condata;
        if _type_ eq 0 then delete;
    run;

    /*array mean median std min max*/
    data ConOut(drop=nn nmean nmedian nstd nmin nmax);
        length n mean std median min max $20 &convar. $20. whichvar newseq $20;
        set condata; 
        order=%sysfunc(countw(%nrbquote(&catvarlist.), $))+ 1;
        whichvar="&convar.";
        mean=put(nmean, 5.1);
        STD=put(nstd, 6.2);
        array v{4} nn nmedian nmin nmax;/*array new variable names*/
        array c{4} $ n median min max;
        do a=1to 4; 
            c{a}=put(round(v{ a},.1),3.);
        end;
    run;

    /*merge column*/
    data conout;
        set conout;
        length mean_std min_max $200;

        if mean ne . and std ne . then do ;
            mean_std=cats(mean, " (", std, ")");
        end;

        if min ne . and max ne . then do;
            min_max=cats(min, "," ,max);
        end;

        drop mean std min max; 
    run;


    /*Reshape column and row of continous variable: age*/
    proc transpose data=ConOut out=ConOne;
        id newseq;
        by order whichvar; 
        var n mean_std min_max median ;
    run;

    /*2.2 continous variable for overall */
    proc means data=input1 maxdec=2 noprint;
        var &convar.;
        output out=conoveralldata n=nn mean=nmean std=nstd median=nmedian min=nmin max=nmax ;
    run;

    data ConOverallOut(drop=nn nmean nmedian nstd nmin nmax);
        length n mean std median min max $20 &convar. $20. whichvar newseq $20;
        set conoveralldata; 
        order=%sysfunc(countw(%nrbquote(&catvarlist.), $))+ 1;
        whichvar="&convar.";
        mean=put(nmean, 5.1);
        STD=put(nstd, 6.2);
        array v{4} nn nmedian nmin nmax;/*array new variable names*/
        array c{4} $ n median min max;
        do a=1to 4; 
            c{a}=put(round(v{ a},.1),3.);
        end;
    run;

    *merge column*;
    data ConOverallOut;
        set ConOverallOut;
        length mean_std min_max $200;
        if mean ne . and std ne . then do ;
            mean_std=cats(mean, " (", std, ")");
        end;
        if min ne . and max ne . then do;
            min_max=cats(min, "," ,max);
        end;
        drop mean std min max; 
    run;

    *Reshape column and row of continous variable: age;
    proc transpose data=ConOverallOut out=ConoverallOne;
        by order whichvar; 
        var n mean_std min_max median ;
    run;

    proc sort data=conone;
        by order whichvar;
    run;

    proc sort data=conoverallone;
        by order whichvar;
    run;

    /*merge continous vairbales by group and overall into one table */
    data conone;
        merge conone conoverallone;
        by order whichvar;
        rename COL1=overall;
    run;

    proc sql;
        select distinct newseq into:newseq separated by "$" from input1;
    quit;
    %put newseq=&newseq;

    /*change character to numeric*/
    %do a=1 %to &numseq;
    data conone;
    set conone;
    Var_C=%scan(%nrbquote(&newseq.), &a, "$");
    Var_N=Var_C+0;
    drop var_C %scan(%nrbquote(&newseq.), &a, "$");
    rename var_N=%qscan(%nrbquote(&newseq.), &a, "$");
    run;
    %end;
    */

    data conone;
        length cat $200;
        set conone;
        select (_name_);
        when ("n") do; cat="N"; catn= 1; end;  
        when ("mean_std") do; cat="Mean(STD)"; catn=2;end;
        when ("median") do; cat="Median"; catn=3;end;
        when ("min_max") do; cat="Min Max"; catn=4; end;

        otherwise;
        end;
    run;

    /*concatenate*/
    data all;
        length _NAME_ $200;
        set conone catall;
    run;

    /*data format modification*/
    proc sort data=all;
        by order;
    run;

    data all0;
        set all;
        by order ;
        if first.order then row=0;
            row+1;
            output;

        if last.order then do;
            _n_=row;
            call missing(of  _NAME_ cat whichvar %do a=1 %to &numseq; Arm&a. %end; overall catn );
            row = _n_+1;
            output;
        end;
    run;

    data all1;
        set all0;
        by order;
        if not first.order then whichvar= .;
    run;

    data allinput;
    length characteristic $200;
    set all1;
    cat=lag(cat);

    %do i = 1 %to %sysfunc(countw(%nrbquote(&sequencevarlist.), $)); 
        Arm&i.=lag(Arm&i.);
    %end;

    overall=lag(overall);
    catn=lag(catn);
    whichvar=tranwrd(whichvar, . , "-");
    Characteristic= catx(" ",whichvar,cat);
    drop _break_ order catn whichvar cat _NAME_ row;
    run;

    /*create output folder, folder name and pathway*/
    %put OutputFolder=&OutputFolder;
    %let demogFolder = &OutputFolder.\&StudyId.\Demographic;

    %SmCheckAndCreateFolder(
            BasePath = &OutputFolder.\&StudyId.,
            FolderName =Demographic
    );

    /*generate report with clean format*/
    ods escapechar='^';
    ods listing close;
    options nodate nonumber;

    ods pdf file="&demogfolder.\demographic summary table of &StudyId..pdf" style = sasdocprinter;

    proc report data=allinput headskip nowd
        style(report)=[frame=box]
        style(summary)=[background=lightblue]
        style(lines)=[background=white];

        title1 bold  font ="Times New Roman"  height = 12pt justify = center underlin = 0 color = black "Demographic Table Summary of &StudyId.";
        column characteristic %do a=1 %to &numseq;Arm&a. %end;Overall ; 

        define characteristic/display spacing=1 width=6 left"Characteristic";
        %do a=1 %to &numseq;
        define Arm&a./display spacing=1 width=10 center"Arm&a." "n (%)"; 
        %end;
        define overall/display spacing=1 width=6 center"Overall" "n (%)";

    run;

    ods text= "Footnote:";
    %do b = 1 %to %sysfunc(countw(%nrbquote(&sequencevarlist.), $));
        ods text= "         ";
        ods text=" Arm&b:  %scan(%nrbquote(&sequencevarlist.), &b, $)";
    %end;

    ods pdf close;
    ods listing;

%end;/*STEP 1 loop ended*/


/*STEP 2- Treat crossover studies */
%if %upcase(&StudyDesign.) eq CROSSOVER %then %do;

    %if &UseEx.=1 and %sysfunc(fileexist(&InputEx.)) %then %do;
        /*allinput*/
        proc sort data=adpp_w1;
            by &sequencevar.;
        run;

        proc sort data=input1;
            by &sequencevar.;
        run;

        data covinput;
            merge input1(in=a) adpp_w1(in=b);
            by &sequencevar.;
            if a;
        run;
    %end;
    %else %do;
        proc sort data=&work.groups;
            by &sequencevar.;
        run;

        proc sort data=input1;
            by &sequencevar.;
        run;

        data covinput;
            merge input1(in=a) &work.groups(in=b);
            by &sequencevar.;
            if a;
        run;
    %end;

    /*cohort description lists macro variable created*/ 
    proc sql noprint;
        select distinct cohortdescription into: cohortdescriptionlist separated by "$$$" from covinput;
    quit;

    %put cohortdescriptionlist=&cohortdescriptionlist;

    %do y = 1 %to %sysfunc(countw(%nrbquote(&cohortdescriptionlist.), $$$)); 

        data covinput_&y.(where=(CohortDescription="%scan(%nrbquote(&cohortdescriptionlist.),&y.,"$$$")"));
            set covinput;
        run;
        
       *part 1.1: categorical variable-country, race, sex and ethnicity classed by group;
        proc sql;
            create table allmapwant as
            select * from websvc.mapping
            where domain in ("DM") and stdmvar not in ("USUBJID","ARM") and filevar not in (" ");

            create table condemo as
            select * from allmapwant
            where stdmvar in ("AGE");

            create table catdemo as
            select * from allmapwant
            where stdmvar not in ("AGE");
        quit;

        proc sql noprint;
            select distinct filevar into: catvarlist separated by "$" from catdemo;
            select distinct &sequencevar. into:sequencevarlist separated by "$" from covinput_&y.;
        quit;

        %put sequencevar=&sequencevar.;
        %let numseq=%sysfunc(countw(%nrbquote(&sequencevarlist.),$));
        %put catvarlist=&catvarlist;
        %put sequencevarlist=&sequencevarlist;
        %put numseq=&numseq;

        %do a=1 %to &numseq;
        data covinput_&y.;
            set covinput_&y.;
            if &sequencevar.="%scan(%nrbquote(&sequencevarlist.), &a., "$")" then do;
            newseq=tranwrd(&sequencevar.,trim("%scan(%nrbquote(&sequencevarlist.), &a., "$")"),trim("Arm&a."));
            end;
        run;
        %end;

        /*generate frequency tables*/
        %do i = 1 %to %sysfunc(countw(%nrbquote(&catvarlist.), $)); 
            proc freq data=covinput_&y. noprint;
                tables %scan(%nrbquote(&catvarlist.),&i.,"$")*newseq/out=cat&i. outpct;
            run;

            data cat&i.;
                set cat&i.;
                drop percent pct_row;
                rename PCT_COL=percent;
            run;

            data cat&i.;
                length Count_Percent $200;
                set cat&i.;

                percent=round(percent,0.01);
                if count ne . and percent ne . then do ;
                Count_Percent= cats(count, " (", percent, ")");
                drop percent count;
            end;

            /*to change: newseq. change to cohortdescription*/
            proc transpose data=cat&i. out=catout&i.(drop=_label_);
                by %scan(%nrbquote(&catvarlist.),&i.,"$");
                id newseq;
                var count_percent;
            run;

            /*reshape*/
            data catout&i.;
                length whichvar $20 cat _NAME_ $200;
                set catout&i;
                by %scan(%nrbquote(&catvarlist.),&i.,$);
                catn+1;
                order=&i;
                whichvar="%scan(%nrbquote(&catvarlist.),&i.,"$")";
                if %scan(%nrbquote(&catvarlist.),&i.,"$") ne "     " then cat=%scan(%nrbquote(&catvarlist.),&i.,"$");
                drop %scan(%nrbquote(&catvarlist.),&i.,"$");
            run;

            /*part 1.2 categorical variables for Overall*/
            proc freq data=covinput_&y. noprint;
                tables %scan(%nrbquote(&catvarlist.),&i.,"$")/out=catoverall&i.;
            run;

            data catoverall&i.;
                length Count_Percent $200;
                set catoverall&i.;
                percent=round(percent,0.01);
                if count ne . and percent ne . then do ;
                Count_Percent= cats(count, " (", percent, ")");
                drop percent count;
            end;

            *to change: newseq. change to cohortdescription;
            proc transpose data=catoverall&i. out=catoverall&i.(drop=_label_);
                by %scan(%nrbquote(&catvarlist.),&i.,"$");
                var count_percent;
            run;

            *reshape;
            data catoverall&i.;
                length whichvar $20 cat _NAME_ $200;
                set catoverall&i.;
                by %scan(%nrbquote(&catvarlist.),&i.,$);
                catn+1;
                order=&i;
                whichvar="%scan(%nrbquote(&catvarlist.),&i.,"$")";
                if %scan(%nrbquote(&catvarlist.),&i.,"$") ne "     " then cat=%scan(%nrbquote(&catvarlist.),&i.,"$");
                drop %scan(%nrbquote(&catvarlist.),&i.,"$");
            run;

            /*merge overall and grouped categorical variables into one table for each variable*/
            proc sort data=catout&i.;
                by whichvar cat order catn;
            run;

            proc sort data=catoverall&i.;
                by whichvar cat order catn;
            run;

            data catout&i.;
                merge catout&i. catoverall&i.;
                by whichvar cat order catn ;
                rename COL1=Overall;
            run;

        %end;

        *put categorical summary into one tables and reshape the categoriacal summary table;
        data CatAll;
            set 
                %do i = 1 %to %sysfunc(countw(%nrbquote(&catvarlist.), $));      
                    %if %sysfunc(exist(catout&i.)) %then %do;
                        catout&i.
                    %end;

                %end;
               ;
        run;

        *part2.1 continous variable: age by group;
        proc sql noprint;
            select distinct filevar into: convar separated by "$" from condemo;
            select distinct newseq into:cohlist separated by "$" from covinput_&y.;
        quit;
        %put convar=&convar;
        %put cohlist=&cohlist;  

        proc means data=covinput_&y. maxdec=2 noprint;
            var &convar.;
            class newseq;
            output out=condata n=nn mean=nmean std=nstd median=nmedian min=nmin max=nmax ;
        run;

        data condata;
            set condata;
            if _type_ eq 0 then delete;
        run;


        data ConOut(drop=nn nmean nmedian nstd nmin nmax);
            length n mean std median min max $20 &convar. $20. whichvar newseq $20;
            set condata; 
            order=%sysfunc(countw(%nrbquote(&catvarlist.), $))+ 1;
            whichvar="&convar.";
            mean=put(nmean, 5.1);
            STD=put(nstd, 6.2);
            array v{4} nn nmedian nmin nmax;/*array new variable names*/
            array c{4} $ n median min max;
            do a=1to 4; 
                c{a}=put(round(v{ a},.1),3.);
            end;
        run;

        /*merge column*/
        data conout;
            set conout;
            length mean_std min_max $200;
            if mean ne . and std ne . then do ;
                mean_std=cats(mean, " (", std, ")");
            end;
            if min ne . and max ne . then do;
                min_max=cats(min, "," ,max);
            end;
            drop mean std min max; 
        run;


        /*Reshape column and row of continous variable: age*/
        proc transpose data=ConOut out=ConOne;
            id newseq;
            by order whichvar; 
            var n mean_std min_max median ;
        run;

        /*2.2 continous variable for overall */
        proc means data=covinput_&y. maxdec=2 noprint;
            var &convar.;
            output out=conoveralldata n=nn mean=nmean std=nstd median=nmedian min=nmin max=nmax ;
        run;

        data ConOverallOut(drop=nn nmean nmedian nstd nmin nmax);
            length n mean std median min max $20 &convar. $20. whichvar newseq $20;
            set conoveralldata; 
            order=%sysfunc(countw(%nrbquote(&catvarlist.), $))+ 1;
            whichvar="&convar.";
            mean=put(nmean, 5.1);
            STD=put(nstd, 6.2);
            array v{4} nn nmedian nmin nmax;/*array new variable names*/
            array c{4} $ n median min max;
            do a=1to 4; 
            c{a}=put(round(v{ a},.1),3.);
            end;
        run;

        *merge column*;
        data ConOverallOut;
            set ConOverallOut;
            length mean_std min_max $200;
            if mean ne . and std ne . then do ;
                mean_std=cats(mean, " (", std, ")");
            end;
            if min ne . and max ne . then do;
                min_max=cats(min, "," ,max);
            end;
            drop mean std min max; 
        run;

        *Reshape column and row of continous variable: age;
        proc transpose data=ConOverallOut out=ConoverallOne;
            by order whichvar; 
            var n mean_std min_max median ;
        run;

        proc sort data=conone;
            by order whichvar;
        run;

        proc sort data=conoverallone;
            by order whichvar;
        run;

        /*merge continous vairbales by group and overall into one table */
        data conone;
            merge conone conoverallone;
            by order whichvar;
            rename COL1=overall;
        run;

        proc sql;
            select distinct newseq into:newseq separated by "$" from covinput_&y.;
        quit;
        %put newseq=&newseq;

        /*
        *change character to numeric*;
        %do a=1 %to &numseq;
        data conone;
        set conone;
        Var_C=%scan(%nrbquote(&newseq.), &a, "$");
        Var_N=Var_C+0;
        drop var_C %scan(%nrbquote(&newseq.), &a, "$");
        rename var_N=%qscan(%nrbquote(&newseq.), &a, "$");
        run;
        %end;
        */

        data conone;
            length cat $200;
            set conone;
            select (_name_);
            when ("n") do; cat="N"; catn= 1; end;  
            when ("mean_std") do; cat="Mean(STD)"; catn=2;end;
            when ("median") do; cat="Median"; catn=3;end;
            when ("min_max") do; cat="Min Max"; catn=4; end;

            otherwise;
            end;
        run;

        *concatenate;
        data all;
            length _NAME_ $200;
            set conone catall;
        run;

        *data format modification;
        proc sort data=all;
            by order;
        run;

        data all0;
            set all;
            by order ;
            if first.order then row=0;
                row+1;
                output;

            if last.order then do;
                _n_=row;
                call missing(of  _NAME_ cat whichvar %do a=1 %to &numseq; Arm&a. %end; overall catn );
                row = _n_+1;
                output;
            end;
        run;


        data all1;
            set all0;
            by order;
            if not first.order then whichvar= .;
        run;

        data allinput;
            length characteristic $200;
            set all1;
            cat=lag(cat);
            %do i = 1 %to %sysfunc(countw(%nrbquote(&sequencevarlist.), $)); 
            Arm&i.=lag(Arm&i.);
            %end;
            overall=lag(overall);
            catn=lag(catn);
            whichvar=tranwrd(whichvar, . , "-");
            Characteristic= catx(" ",whichvar,cat);
            drop _break_ order catn whichvar cat _NAME_ row;
        run;

        /*create folder, pathway, folder name for crossover with reading EX stuides*/
        %put OutputFolder=&OutputFolder;
        %let demogFolder = &OutputFolder.\&StudyId.\Demographic;

        %SmCheckAndCreateFolder(
                BasePath = &OutputFolder.\&StudyId.,
                FolderName =Demographic
        );

        /*genreate report with clean format for crossover with reading EX studies*/
        ods listing close;
        options nodate nonumber;

        ods pdf file="&demogfolder.\demographic summary table of &StudyId._&y..pdf" style = sasdocprinter;
      

        proc report data=allinput headskip nowd
            style(report)=[frame=box]
            style(summary)=[background=lightblue]
            style(lines)=[background=white];

            title1 bold  font ="Times New Roman"  height = 12pt justify = center underlin = 0 color = black "Demographic Table Summary of &StudyId.";
            title2 bold  font ="Times New Roman"  height = 10pt justify = center underlin = 0 color = black "Cohort:%scan(%nrbquote(&cohortdescriptionlist.),&y.,"$$$")";

           /* %do b = 1 %to %sysfunc(countw(%nrbquote(&sequencevarlist.), $));
            footnote&b. font ="Times New Roman"  height = 10pt justify = left"Arm&b:  %scan(%nrbquote(&sequencevarlist.), &b, $)";
            %end;*/

            column characteristic %do a=1 %to &numseq;Arm&a. %end;Overall; 
            define characteristic/display spacing=1 width=6 left"Characteristic";
            %do a=1 %to &numseq;
            define Arm&a./display spacing=1 width=10 center"Arm&a." "n (%)"; 
            %end;
            define overall/display spacing=1 width=6 center"Overall" "n (%)";
        
        run;

        ods text= "Footnote:";
        %do b = 1 %to %sysfunc(countw(%nrbquote(&sequencevarlist.), $));
            ods text= "         ";
            ods text=" Arm&b:  %scan(%nrbquote(&sequencevarlist.), &b, $)";
        %end;

        ods pdf close;
        ods listing;
    %end;/*multiple cohorts ended*/

%end;/*crossover ended*/

%END;

%mend PKViewDemog;  



