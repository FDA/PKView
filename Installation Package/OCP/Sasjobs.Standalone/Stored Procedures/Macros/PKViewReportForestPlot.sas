%*****************************************************************************************;
%**                                                                                     **;
%** Run script to generate Forest Plots from the user settings                          **;
%**                                                                                     **;
%** Created by Meng Xu (2015)                                                           **;
%**                                                                                     **;
%** Updated by Eduard Porta (2015-06-22)                                                **;
%**                                                                                     **;
%*****************************************************************************************;

%macro PKViewReportForestPlot();

%SmReadMappingsFromDataSet();

/* Read report settings from websvc input dataset (provided by C#) */
%SmReadReportSettingsForest();

/* Retrieve NDA Id */
%let Nda_Number=&SubmissionId.;
%put Nda_number=&Nda_Number.;
%put StudyId=&StudyId.;

/* Generate output path based on NDA Id, User Id and settings Id */
%let OutputFolder = &SasSpPath.\Output Files\PKView\&UserName.\&ProfileName.\&nda_number.\&SupplementNum;

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

%put sortfiles=&sortfiles;

/*select the cohort,analyte, parameter from usering settings*/
%do i = 1 %to %sysfunc(countw(%quote(&cohort_sel.), $));
    %do m= 1 %to %sysfunc(countw(%quote(&anal_sel.), $));
        %do q= 1 %to %sysfunc(countw(%quote(&param_sel.), $));              
            data work.select_&i._&m._&q.;
            set result.estimates (where = ( CohortDescription = "%scan(%quote(&Cohort_sel.), &i., $)" and
                                            Reference_L = "%scan(%quote(&ref_sel.), &i., $)" and 
                                            &AnalyteVar ="%scan(%quote(&anal_sel.), &m., $)" and
                                            &ParameterVar = "%scan(%quote(&param_sel.), &q., $)" and
                                            EstType= "&method_sel" and ratio ne .  ));
            run;

            /*proc print data=work.select_&i._&m._&q.; run;*/              
        %end;
    %end;
%end;


/*STEP1 all cohorts in one table**/
/*one table will be generated for all cohorts when “cohort” is NOT selected in the dropdown and thus not present in macro var SortFiles******/
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

    /*Allcohorts-option1 starts ************/

    data lengthcheck;
        set allcohorts;
        length_analytevar=length(strip(&AnalyteVar));
        length_combination=length(strip(combination));
    run;

    /*get the length of longest character string for analyte and combiantion macro variables*/
    proc sql;
        select max(length_analytevar) as largest_analytevar into: largest_analytevar from lengthcheck ;
        select max(length_combination) as largest_combination into: largest_combination from lengthcheck;
    quit;

    %put largest_analytevar=&largest_analytevar;
    %put largest_combination=&largest_combination;

    /*generate forest plot with analyte and combination string larher than 30 */
    %if &largest_analytevar gt 30 or &largest_combination gt 30 %then %do;

        %put allcohorts with footnotes when var greater than 30;

        proc sql noprint;
            select distinct &AnalyteVar
            into: AnalyteLabel separated by "@"
            from allcohorts;

            select distinct combination
            into: combinationLabel separated by "@"
            from allcohorts;
        quit;      

        %let analytenumber = %sysfunc(countw(%nrbquote(&analytelabel.), @));
        %let combinationnumber = %sysfunc(countw(%nrbquote(&combinationlabel.), @));
        %put analytenumber=&analytenumber;
        %put analytelabel=&analytelabel;
        %put combinationnumber=&combinationnumber;
        %put combinationlabel=&combinationlabel;

        /*treat anaylte label*/
        data allcohorts;
        set allcohorts;
        %do i=1 %to &analytenumber;
            if &AnalyteVar="%scan(%nrbquote(&analytelabel), &i., @)" then do;
            &AnalyteVar=tranwrd(&AnalyteVar,trim("%scan(%nrbquote(&analytelabel), &i., @)"),"Analyte &i.");
            end;
        %end;
        run;
        
        /*treat combination label*/
        data allcohorts;
        set allcohorts;
        %do j=1 %to &combinationnumber;
            if combination="%scan(%nrbquote(&combinationlabel), &j., @)" then do;
            combination=tranwrd(combination,trim("%scan(%nrbquote(&combinationlabel), &j, @)"),"Test/Ref(&j.)");
            end;
        %end;
        run;

        /*sorting function*/
        data AllCohorts(rename=(&AnalyteVar=analyte &ParameterVar=parameter CohortNumber=cohort Combination=comparison));
            set AllCohorts;
        run;
        
        /*sort by user selected sequences from the interface*/
        proc sort data=AllCohorts;
            by %scan(%quote(&sort_list.),1,@)  %scan(%quote(&sort_list.),2,@)
            %scan(%quote(&sort_list.),3,@) %scan(%quote(&sort_list.),4,@);
        run;

        /*list columns by the sorted orders*/
        data AllCohorts;
            retain  %scan(%quote(&sort_list.),1,@)  %scan(%quote(&sort_list.),2,@)
            %scan(%quote(&sort_list.),3,@) %scan(%quote(&sort_list.),4,@);
            set AllCohorts;
        run;
 
        data AllCohorts (keep= parameter analyte cohort comparison   Reference_L EstType ratio lcl ucl
                           );
        set AllCohorts;
        run;
        

        /*prepare input table format for forest plot genration */
        data allcohorts(rename=(&analyteVar=analyte &parameterVar=parameter Combination=comparison));
            set allcohorts;
        run;
            
        proc sort data=allcohorts;
            by %scan(%quote(&sort_list.),1,@)  %scan(%quote(&sort_list.),2,@)
            %scan(%quote(&sort_list.),3,@)   ;
        run;

        data allcohorts ;
            retain %scan(%quote(&sort_list.),1,@)  %scan(%quote(&sort_list.),2,@)
            %scan(%quote(&sort_list.),3,@)  ;
        set allcohorts;
        run;

        data allcohorts;
            length fir sec thi $200.;
            format fir sec thi $200.;
            drop analyte parameter comparison;
            retain fir sec thi ;
            set allcohorts;
    
            fir=%scan(%quote(&sort_list.),1,@); 
            sec=%scan(%quote(&sort_list.),2,@);
            thi=%scan(%quote(&sort_list.),3,@);
        run;

            
        proc sort data=allcohorts;
            by cohort fir sec thi  ;
        run;

        /*step1 add blank row*/
        data input;
        set allcohorts;
        by Cohort fir;
            if first.Cohort then row=0;
            if first.fir then row1=0;
            row+1;
            row1+1;
        output;

        if last.Cohort then do;
            _n_=row;
            call missing(of thi CohortDescription EstType ratio lcl ucl combination1 Reference_L );;
            row = _n_+1;
        output;
        end;

        if last.fir then do;
            call missing(of thi CohortDescription EstType ratio lcl ucl combination1 Reference_L );
            _n_=row1;
        output;
        end;
        run;

        /*step 2 with 1st level-combination, and 2nd level-analyte*/
        data input;
            set input;
            by Cohort fir sec;
            if not first.Cohort then Cohort= . ;
            if not first.fir then fir= .;
            if not first.sec then sec=. ;
        run;


        /*step 3 lag the rows*/
        data laginput;
            set input;
            sec=lag(sec);
            thi=lag(thi);
            CohortDescription=lag(CohortDescription);
            EstType=lag(EstType);
            ratio=lag(ratio);
            lcl=lag(lcl);
            ucl=lag(ucl);
            combination1=lag(combination1);
            Reference_L =lag(Reference_L);

            cohortlabel=strip(cohort);
            firlabel=strip(fir);
            seclabel=strip(sec);
            thilabel=strip(thi);
        run;

        /* Temporary fix: Replace cohort numbers with . until we figure out a good way to tag them */
        data laginput;
            set laginput;
            if cohortlabel ne . then cohortlabel= .;
        run;

        ***********************************************************
        ************all cohorts forest plot**********************
        ***********************************************************;

        data forest_plot;
            set laginput;
            cohort_lbl="cohort";
            fir_lbl = "%scan(%quote(&sort_list.),1,@)";
            sec_lbl = "%scan(quote(&sort_list.),2,@)";
            thi_lbl = "%scan(%quote(&sort_list.),3,@)";

            ratio_lbl="ratio";
            lcl_lbl="lower limit";
            ucl_lbl="upper limit";

            if _n_=1 then do;
                obsid=0;
            end;

            obsid+1;
            output;
        run;

        /*prepare template for generating forest plot*/
        proc template;
        define statgraph ForestPlot;
        begingraph / designwidth=1000px designheight=1200px;
        entrytitle "The Forest Plot of &studyid for All Cohorts " / textattrs = (size = 10pt weight = bold) pad = (bottom = 5px);
        layout lattice / columns = 5 columnweights=(0.08 0.16 0.16 0.30 0.30);
            %** First column for subgroup **;
            layout overlay /    walldisplay = none 
            /*x2axisopts*/xaxisopts= (display = none/*(tickvalues)*/ offsetmin = 0.0 offsetmax = 0.0 tickvalueattrs = (size = 9)) 
            yaxisopts = (reverse = true display = none tickvalueattrs = (weight = bold) offsetmin = 0);
            scatterplot y = obsid x = Cohort_lbl  /   markercharacter  =cohortlabel  markerattrs = (size = 0);
            endlayout;

            %** First column for subgroup **;
            layout overlay /    walldisplay = none 
            xaxisopts = (display =none  offsetmin = 0.0 offsetmax = 0.0 tickvalueattrs = (size = 8)) 
            yaxisopts = (reverse = true display = none tickvalueattrs = (weight = bold) offsetmin = 0);
            scatterplot y = obsid x = fir_lbl  /   markercharacter  =firlabel  markercharacterattrs=(family='Lucida Console' size=7 weight=bold  );
            scatterplot y = obsid x = fir_lbl  /   markercharacter  =seclabel  markerattrs = (size = 0);
            endlayout;

            %** Second column for PK parameters **;
            layout overlay /    walldisplay = none
            xaxisopts = (display =none  offsetmin = 0.0 offsetmax = 0.0 tickvalueattrs = (size = 8))
            yaxisopts = (reverse = true display = none tickvalueattrs = (weight = bold) offsetmin = 0);
            scatterplot y = obsid x = thi_lbl      /   markercharacter  =thilabel  markerattrs = (size = 0);
            endlayout;


            %** Fourth column showing odds ratio graph **;
            layout  overlay /   walldisplay = none
            yaxisopts = (reverse = true display = none offsetmin = 0) 
            xaxisopts = (tickvalueattrs = (size = 7pt) labelattrs = (size = 7pt)  
                        label = "Geometric Mean Ratio of Test to Reference and 90% CI");
            *highlowplot y = obsid low = lratio high = uratio; 
            *scatterplot y = obsid x = ratio / markerattrs = (symbol = diamondfilled);
            scatterplot y = obsid x = ratio  / xerrorlower = lcl xerrorupper = ucl markerattrs = (size = 0.6pct symbol = squarefilled);        
            referenceline x = 1;
            endlayout;

            layout overlay    /   walldisplay = none
                            x2axisopts = (display = (tickvalues) offsetmin = 0.25 offsetmax = 0.25)
                            yaxisopts  = (reverse = true display = none);

            scatterplot y = obsid x = ratio_lbl /   markercharacter = ratio
                                                    markercharacterattrs = graphvaluetext xaxis = x2;
            scatterplot y = obsid x = lcl_lbl   /   markercharacter = lcl
                                                    markercharacterattrs = graphvaluetext xaxis = x2;
            scatterplot y = obsid x = ucl_lbl   /   markercharacter = ucl
                                                    markercharacterattrs = graphvaluetext xaxis = x2;
            endlayout;  

            layout overlay;
            endlayout;

            %do i = 1 %to %sysfunc(countw(%nrbquote(&analytelabel.), @));

                entryfootnote halign=left "Analyte &i :%scan(%nrbquote(&analytelabel), &i., @) "  / textattrs = (size = 8pt) ;
            %end;

            %do j = 1 %to %sysfunc(countw(%nrbquote(&combinationlabel.), @));

                entryfootnote halign=left "Test/Ref(&j.) :%scan(%nrbquote(&combinationlabel), &j., @) "  / textattrs = (size = 8pt) ;
            %end;

        endlayout;
        endgraph;
        end;
        run;

        %put OutputFolder=&OutputFolder.;
        %let ResultFolder = &OutputFolder.\&StudyId.\&ReportFolder;

        /*output folder and output forst plot EACH COHORT*/
        %SmCheckAndCreateFolder(
        BasePath = &OutputFolder.\&StudyId.,
        FolderName = &ReportFolder
        );

        options nodate nonumber;
        ods listing gpath = " &OutputFolder.\&StudyId.\&ReportFolder";
        ods graphics on / noborder imagefmt = png imagename = "&StudyId._ForestPlot" width = 1000px height = 1200;

        proc sgrender data=forest_plot template = ForestPlot;
        run;

        ods listing close;
        ods graphics off;

    %end;/*Allcohorts-option1 generate forest plot with footnotes ( longer analyte and combination string) nds*/

    %else %do;/*Allcohorts-option2 generate forest plot with no footnotes( shorter analyte and combination string) starts*/

        /*sorting function*/
        data AllCohorts(rename=(&AnalyteVar=analyte &ParameterVar=parameter CohortNumber=cohort Combination=comparison));
        set AllCohorts;
        run;

        /*sort by useres selected*/
        proc sort data=AllCohorts;
            by %scan(%quote(&sort_list.),1,@)  %scan(%quote(&sort_list.),2,@)
            %scan(%quote(&sort_list.),3,@) %scan(%quote(&sort_list.),4,@);
        run;

        /*list columns in same way as sorting order*/
        data AllCohorts;
            retain  %scan(%quote(&sort_list.),1,@)  %scan(%quote(&sort_list.),2,@)
            %scan(%quote(&sort_list.),3,@) %scan(%quote(&sort_list.),4,@);
            set AllCohorts;
        run;
     
        data AllCohorts (keep= parameter analyte cohort comparison Reference_L EstType ratio lcl ucl
                           );
        set AllCohorts;
        run;


        /*prepare format for forest plot genration */
        data allcohorts(rename=(&analyteVar=analyte &parameterVar=parameter Combination=comparison));
            set allcohorts;
        run;

        proc sort data=allcohorts;
            by %scan(%quote(&sort_list.),1,@)  %scan(%quote(&sort_list.),2,@)
            %scan(%quote(&sort_list.),3,@)   ;
        run;

        data allcohorts ;
            retain %scan(%quote(&sort_list.),1,@)  %scan(%quote(&sort_list.),2,@)
            %scan(%quote(&sort_list.),3,@)  ;
            set allcohorts;
        run;


        data allcohorts;
            length fir sec thi $200.;
            format fir sec thi $200.;
            drop analyte parameter comparison;
            retain fir sec thi ;
            set allcohorts;
            fir=%scan(%quote(&sort_list.),1,@); 
            sec=%scan(%quote(&sort_list.),2,@);
            thi=%scan(%quote(&sort_list.),3,@);
        run;


        proc sort data=allcohorts;
            by cohort fir sec thi  ;
        run;

        *1) add blank row;
        data input;
            set allcohorts;
            by Cohort fir;
            if first.Cohort then row=0;
            if first.fir then row1=0;
            row+1;
            row1+1;
            output;

            if last.Cohort then do;
                _n_=row;
                call missing(of thi CohortDescription EstType ratio lcl ucl combination1 Reference_L );;
                row = _n_+1;
                output;
            end;

            if last.fir then do;
                call missing(of thi CohortDescription EstType ratio lcl ucl combination1 Reference_L );
                _n_=row1;
            output;
            end;
        run;

        *2) add . with 1st level-combination, and 2nd level-analyte;
        data input;
            set input;
            by Cohort fir sec;
            if not first.Cohort then Cohort= . ;
            if not first.fir then fir= .;
            if not first.sec then sec=. ;
        run;

        *3) lag the rows;
        data laginput;
            set input;
            sec=lag(sec);
            thi=lag(thi);
            CohortDescription=lag(CohortDescription);
            EstType=lag(EstType);
            ratio=lag(ratio);
            lcl=lag(lcl);
            ucl=lag(ucl);
            combination1=lag(combination1);
            Reference_L =lag(Reference_L);

            cohortlabel=strip(cohort);
            firlabel=strip(fir);
            seclabel=strip(sec);
            thilabel=strip(thi);
        run;

        /* Temporary fix: Replace cohort numbers with . until we figure out a good way to tag them */
        data laginput;
            set laginput;
            if cohortlabel ne . then cohortlabel= .;
        run;

         
        ***********************************************************
        ************all cohorts forest plot**********************
        ***********************************************************;

        data forest_plot;
            set laginput;

            cohort_lbl="cohort";

            fir_lbl = "%scan(%quote(&sort_list.),1,@)";
            sec_lbl = "%scan(quote(&sort_list.),2,@)";
            thi_lbl = "%scan(%quote(&sort_list.),3,@)";

            ratio_lbl="ratio";
            lcl_lbl="lower limit";
            ucl_lbl="upper limit";

            if _n_=1 then do;
                obsid=0;
            end;
            obsid+1;
            output;
        run;

        /*template the input forest plot table*/
        proc template;
        define statgraph ForestPlot;
        begingraph / designwidth=1000px designheight=1200px;
        entrytitle "The Forest Plot of &studyid for All Cohorts " / textattrs = (size = 10pt weight = bold) pad = (bottom = 5px);
        layout lattice / columns = 5 columnweights=(0.08 0.16 0.16 0.30 0.30);

            %** First column for subgroup **;
            layout overlay /    walldisplay = none 
            /*x2axisopts*/xaxisopts= (display = none/*(tickvalues)*/ offsetmin = 0.0 offsetmax = 0.0 tickvalueattrs = (size = 9)) 
            yaxisopts = (reverse = true display = none tickvalueattrs = (weight = bold) offsetmin = 0);
            scatterplot y = obsid x = Cohort_lbl  /   markercharacter  =cohortlabel  markerattrs = (size = 0);
            endlayout;

            %** First column for subgroup **;
            layout overlay /    walldisplay = none 
            xaxisopts = (display =none  offsetmin = 0.0 offsetmax = 0.0 tickvalueattrs = (size = 8)) 
            yaxisopts = (reverse = true display = none tickvalueattrs = (weight = bold) offsetmin = 0);
            scatterplot y = obsid x = fir_lbl  /   markercharacter  =firlabel  markercharacterattrs=(family='Lucida Console' size=7 weight=bold  );
            scatterplot y = obsid x = fir_lbl  /   markercharacter  =seclabel  markerattrs = (size = 0);
            endlayout;

            %** Second column for PK parameters **;
            layout overlay /    walldisplay = none
            xaxisopts = (display =none  offsetmin = 0.0 offsetmax = 0.0 tickvalueattrs = (size = 8))
            yaxisopts = (reverse = true display = none tickvalueattrs = (weight = bold) offsetmin = 0);

            scatterplot y = obsid x = thi_lbl      /   markercharacter  =thilabel  markerattrs = (size = 0);
            endlayout;

            %** Fourth column showing odds ratio graph **;
            layout  overlay /   walldisplay = none
            yaxisopts = (reverse = true display = none offsetmin = 0) 
            xaxisopts = (tickvalueattrs = (size = 7pt) labelattrs = (size = 7pt)  
            label = "Geometric Mean Ratio of Test to Reference and 90% CI");
            *highlowplot y = obsid low = lratio high = uratio; 
            *scatterplot y = obsid x = ratio / markerattrs = (symbol = diamondfilled);
            scatterplot y = obsid x = ratio  / xerrorlower = lcl xerrorupper = ucl markerattrs = (size = 0.6pct symbol = squarefilled);        
            referenceline x = 1;
            endlayout;

            layout overlay    /   walldisplay = none
            x2axisopts = (display = (tickvalues) offsetmin = 0.25 offsetmax = 0.25)
            yaxisopts  = (reverse = true display = none);

            scatterplot y = obsid x = ratio_lbl /   markercharacter = ratio
            markercharacterattrs = graphvaluetext xaxis = x2;
            scatterplot y = obsid x = lcl_lbl   /   markercharacter = lcl
            markercharacterattrs = graphvaluetext xaxis = x2;
            scatterplot y = obsid x = ucl_lbl   /   markercharacter = ucl
            markercharacterattrs = graphvaluetext xaxis = x2;
            endlayout;  

            layout overlay;
            endlayout;

        endlayout;
        endgraph;
        end;
        run;

        %put OutputFolder=&OutputFolder.;
        %let ResultFolder = &OutputFolder.\&StudyId.\&ReportFolder;

        /*output folder and output forst plot EACH COHORT*/

        %SmCheckAndCreateFolder(
        BasePath = &OutputFolder.\&StudyId.,
        FolderName = &ReportFolder
        );

        options nodate nonumber;
        ods listing gpath = " &OutputFolder.\&StudyId.\&ReportFolder";
        ods graphics on / noborder imagefmt = png imagename = "&StudyId._ForestPlot" width = 1000px height = 1200;

        proc sgrender data=forest_plot template = ForestPlot;run;

        ods listing close;
        ods graphics off;

    %end;/*Allcohorts-option2 ends*/
%end;/*STEP1: all cohorts ends*/

/*STEP2: seperate by cohort starts*/
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

        /*each cohort options1 use footnote starts*/
        data lengthcheck;
            set cohort_&i;

            length_analytevar=length(strip(&AnalyteVar));
            length_combination=length(strip(combination));
        run;


        proc sql;
            select max(length_analytevar) as largest_analytevar into: largest_analytevar from lengthcheck ;
            select max(length_combination) as largest_combination into: largest_combination from lengthcheck;
        quit;

        %put largest_analytevar=&largest_analytevar;
        %put largest_combination=&largest_combination;


        %if &largest_analytevar gt 30 or &largest_combination gt 30 %then %do;
            %put  footnotes when var length greater than 30;

            proc sql noprint;
                    select distinct &AnalyteVar
                    into: AnalyteLabel separated by "@"
                    from cohort_&i;

                    select distinct combination
                    into: combinationLabel separated by "@"
                    from cohort_&i;
             quit;       
            %let analytenumber = %sysfunc(countw(%nrbquote(&analytelabel.), @));
            %let combinationnumber = %sysfunc(countw(%nrbquote(&combinationlabel.), @));
            %put analytenumber=&analytenumber;
            %put analytelabel=&analytelabel;
            %put combinationnumber=&combinationnumber;
            %put combinationlabel=&combinationlabel;


            data cohort_&i;
            set cohort_&i;
            %do b=1 %to &analytenumber;
            if &AnalyteVar="%scan(%nrbquote(&analytelabel), &b., @)" then do;
            &AnalyteVar=tranwrd(&AnalyteVar,trim("%scan(%nrbquote(&analytelabel), &b, @)"),"Analyte &b.");
            end;
            %end;
            run;


            data cohort_&i;
                set cohort_&i;
                %do c=1 %to &combinationnumber;
                    if combination="%scan(%nrbquote(&combinationlabel), &c., @)" then do;
                        combination=tranwrd(combination,trim("%scan(%nrbquote(&combinationlabel), &c, @)"),"Test/Ref(&c.)");
                    end;
                %end;
            run;

            /*sorting function*/
            data cohort_&i(rename=(&AnalyteVar=analyte &ParameterVar=parameter CohortNumber=cohort Combination=comparison));
                set cohort_&i;
            run;
            
            proc sort data=cohort_&i;
                by %scan(%quote(&sort_list.),1,@)  %scan(%quote(&sort_list.),2,@)
                %scan(%quote(&sort_list.),3,@) ;
            run;

            /*let the columns shown in the same ways as sorting order*/
            data cohort_&i ;
                retain  %scan(%quote(&sort_list.),1,@)  %scan(%quote(&sort_list.),2,@)
                %scan(%quote(&sort_list.),3,@) ;
                set cohort_&i;
            run;

            /*forest plot: start from treating format*/
            data cohort_&i;
                length fir sec thi $200.;
                format fir sec thi $200.;
                drop analyte parameter comparison;
                retain fir sec thi ;
                set cohort_&i;

                fir=%scan(%quote(&sort_list.),1,@); 
                sec=%scan(%quote(&sort_list.),2,@);
                thi=%scan(%quote(&sort_list.),3,@);
            run;

            *1) add blank row;
            data input_cohort_&i.;
                set cohort_&i;
                by fir;
                if first.fir then row=0;
                    row+1;
                 output;
                if last.fir then do;
                    _n_=row;
                    call missing(of thi cohort CohortDescription EstType ratio lcl ucl combination1 Reference_L  );;
                    row = _n_+1;
                output;
                end;
            run;

            *2) add . with 1st level-combination, and 2nd level-analyte;
            data input_cohort_&i.;
                set input_cohort_&i.;
                by fir sec;
                if not first.fir then fir= . ;
                if not first.sec then sec= . ;
            run;

                *3) lag the rows;
            data laginput_cohort_&i.;
                set input_cohort_&i.;
                sec=lag(sec);
                thi=lag(thi);
                CohortDescription=lag(CohortDescription);
                Cohort=lag(cohort);
                EstType=lag(EstType);
                ratio=lag(ratio);
                lcl=lag(lcl);
                ucl=lag(ucl);
                combination1=lag(combination1);
                Reference_L =lag(Reference_L);
                /*for forest plot formatting-put better header and remove the old ones*/
                firlabel=strip(fir);
                seclabel=strip(sec);
                thilabel=strip(thi);
            run;

            /* Temporary fix: Replace cohort numbers with . until we figure out a good way to tag them */
            data laginput_cohort_&i.;
                set laginput_cohort_&i.;
                if cohort ne . then cohort=. ;
            run;


            *************start coding forest plot**********************;
            data forest_plot_&i.;
                length fir_lbl sec_lbl thi_lbl $200.;
                format fir_lbl sec_lbl thi_lbl $200.;
                set laginput_cohort_&i.;

                fir_lbl = "%scan(%quote(&sort_list.),1,@)";
                sec_lbl = "%scan(quote(&sort_list.),2,@)";
                thi_lbl = "%scan(%quote(&sort_list.),3,@)";
                ratio_lbl="ratio";
                lcl_lbl="lower limit";
                ucl_lbl="upper limit";

                if _n_=1 then do;
                    obsid=0;
                end;
                obsid+1;
                output;
            run;

            /*generate forest template*/
            proc template;
            define statgraph ForestPlot;
            begingraph / designwidth=1000px designheight=600px;
            entrytitle "The Forest Plot of &StudyId for the Cohort %scan(%nrbquote(&&cohort_sel.), &i., $) " / textattrs = (size = 12pt weight = bold) pad = (bottom = 5px);
            layout lattice / columns = 4 columnweights=(0.2 0.2 0.30 0.30);

                %** First column for subgroup **;
                layout overlay /    walldisplay = none 
                /* x2axisopts*/ xaxisopts = (display = none offsetmin = 0.0 offsetmax = 0.0 tickvalueattrs = (size = 8)) 
                yaxisopts = (reverse = true display = none tickvalueattrs = (weight = bold) offsetmin = 0);
                scatterplot y = obsid x = fir_lbl  /   markercharacter  =firlabel  markercharacterattrs=(family='Lucida Console' size=7 weight=bold  );
                scatterplot y = obsid x = fir_lbl  /   markercharacter  =seclabel  markerattrs = (size = 0);
                endlayout;

                %** Second column for PK parameters **;
                layout overlay /    walldisplay = none
                xaxisopts = (display = none offsetmin = 0.0 offsetmax = 0.0 tickvalueattrs = (size = 8))
                yaxisopts = (reverse = true display = none tickvalueattrs = (weight = bold) offsetmin = 0);
                scatterplot y = obsid x = thi_lbl      /   markercharacter  =thilabel  markerattrs = (size = 0);
                endlayout;

                %** Fourth column showing odds ratio graph **;
                layout  overlay /   walldisplay = none
                yaxisopts = (reverse = true display = none offsetmin = 0) 
                xaxisopts = (tickvalueattrs = (size = 7pt) labelattrs = (size = 7pt)  
                label = "Geometric Mean Ratio of Test to Reference and 90% CI");
                *highlowplot y = obsid low = lratio high = uratio; 
                *scatterplot y = obsid x = ratio / markerattrs = (symbol = diamondfilled);
                scatterplot y = obsid x = ratio  / xerrorlower = lcl xerrorupper = ucl markerattrs = (size = 0.6pct symbol = squarefilled);        
                referenceline x = 1;
                endlayout;

                layout overlay    /   walldisplay = none
                x2axisopts = (display = (tickvalues) offsetmin = 0.25 offsetmax = 0.25)
                yaxisopts  = (reverse = true display = none);

                scatterplot y = obsid x = ratio_lbl /   markercharacter = ratio
                markercharacterattrs = graphvaluetext xaxis = x2;
                scatterplot y = obsid x = lcl_lbl   /   markercharacter = lcl
                markercharacterattrs = graphvaluetext xaxis = x2;
                scatterplot y = obsid x = ucl_lbl   /   markercharacter = ucl
                markercharacterattrs = graphvaluetext xaxis = x2;
                endlayout;  


                %do b = 1 %to %sysfunc(countw(%nrbquote(&analytelabel.), @));
                    entryfootnote halign=left "Analyte &b :%scan(%nrbquote(&analytelabel), &b, @) "  / textattrs = (size = 8pt) ;
                %end;

                %do c = 1 %to %sysfunc(countw(%nrbquote(&combinationlabel.), @));
                    entryfootnote halign=left "Test/Ref(&c.) :%scan(%nrbquote(&combinationlabel), &c., @) "  / textattrs = (size = 8pt) ;
                %end;

            endlayout;
            endgraph;
            end;
            run;


            %put OutputFolder=&OutputFolder.;
            %let ResultFolder = &OutputFolder.\&StudyId.\&ReportFolder;

            /*output folder and output forst plot EACH COHORT*/
            %SmCheckAndCreateFolder(
                    BasePath = &OutputFolder.\&StudyId.,
                    FolderName = &ReportFolder
            );

            options nodate nonumber;
            ods listing gpath = " &OutputFolder.\&StudyId.\&ReportFolder";
            ods graphics on / noborder imagefmt = png imagename = "&StudyId._ForestPlot_&i." width = 1000px height =600px;

            proc sgrender data= forest_plot_&i. template = ForestPlot; run;

            ods listing close;
            ods graphics off;

        %end;/*each cohort option1 */

        %else %do;/*each cohort option2 starts*/

            /*sorting function*/
            data cohort_&i(rename=(&AnalyteVar=analyte &ParameterVar=parameter CohortNumber=cohort Combination=comparison));
                set cohort_&i;
            run;
            

            proc sort data=cohort_&i;
                by %scan(%quote(&sort_list.),1,@)  %scan(%quote(&sort_list.),2,@)
                %scan(%quote(&sort_list.),3,@) ;
            run;


            data cohort_&i ;
                retain  %scan(%quote(&sort_list.),1,@)  %scan(%quote(&sort_list.),2,@)
                %scan(%quote(&sort_list.),3,@) ;
                set cohort_&i;
            run;

            /*forest plot: start from treating format*/
            data cohort_&i;
                length fir sec thi $200.;
                format fir sec thi $200.;
                drop analyte parameter comparison;
                retain fir sec thi ;
                set cohort_&i;

                fir=%scan(%quote(&sort_list.),1,@); 
                sec=%scan(%quote(&sort_list.),2,@);
                thi=%scan(%quote(&sort_list.),3,@);
            run;

            *1) add blank row;
            data input_cohort_&i.;
                set cohort_&i;
                by fir;
                if first.fir then row=0;
                    row+1;
                output;
                if last.fir then do;
                    _n_=row;
                    call missing(of thi cohort CohortDescription EstType ratio lcl ucl combination1 Reference_L  );;
                    row = _n_+1;
                    output;
                end;
            run;
    
            *2) add . with 1st level-combination, and 2nd level-analyte;
            data input_cohort_&i.;
                set input_cohort_&i.;
                by fir sec;
                if not first.fir then fir= . ;
                if not first.sec then sec= . ;
            run;


            *3) lag the rows;
            data laginput_cohort_&i.;
                set input_cohort_&i.;
                sec=lag(sec);
                thi=lag(thi);
                CohortDescription=lag(CohortDescription);
                Cohort=lag(cohort) ;
                EstType=lag(EstType);
                ratio=lag(ratio);
                lcl=lag(lcl);
                ucl=lag(ucl);
                combination1=lag(combination1);
                Reference_L =lag(Reference_L);
                /*for forest plot formatting-put better header and remove the old ones*/
                firlabel=strip(fir);
                seclabel=strip(sec);
                thilabel=strip(thi);
            run;

            /* Temporary fix: Replace cohort numbers with . until we figure out a good way to tag them */
            data laginput_cohort_&i.;
                set laginput_cohort_&i.;
                if cohort ne . then cohort= .;
            run;

            *************start coding forest plot**********************;
            data forest_plot_&i.;
                length fir_lbl sec_lbl thi_lbl $200.;
                format fir_lbl sec_lbl thi_lbl $200.;
                set laginput_cohort_&i.;

                fir_lbl = "%scan(%quote(&sort_list.),1,@)";
                sec_lbl = "%scan(quote(&sort_list.),2,@)";
                thi_lbl = "%scan(%quote(&sort_list.),3,@)";
                ratio_lbl="ratio";
                lcl_lbl="lower limit";
                ucl_lbl="upper limit";

                if _n_=1 then do;
                    obsid=0;
                end;
                    obsid+1;
                output;
            run;


            /*template forest plot input data format*/        
            proc template;
            define statgraph ForestPlot;
            begingraph / designwidth=1000px designheight=600px;
            entrytitle "The Forest Plot of &StudyId for the Cohort %scan(%nrbquote(&&cohort_sel.), &i., $) " / textattrs = (size = 12pt weight = bold) pad = (bottom = 5px);
            layout lattice / columns = 4 columnweights=(0.2 0.2 0.30 0.30);

                %** First column for subgroup **;
                layout overlay /    walldisplay = none 
                /* x2axisopts*/ xaxisopts = (display = none offsetmin = 0.0 offsetmax = 0.0 tickvalueattrs = (size = 8)) 
                yaxisopts = (reverse = true display = none tickvalueattrs = (weight = bold) offsetmin = 0);
                scatterplot y = obsid x = fir_lbl  /   markercharacter  =firlabel  markercharacterattrs=(family='Lucida Console' size=7 weight=bold  );
                scatterplot y = obsid x = fir_lbl  /   markercharacter  =seclabel  markerattrs = (size = 0);
                endlayout;

                %** Second column for PK parameters **;
                layout overlay /    walldisplay = none
                xaxisopts = (display = none offsetmin = 0.0 offsetmax = 0.0 tickvalueattrs = (size = 8))
                yaxisopts = (reverse = true display = none tickvalueattrs = (weight = bold) offsetmin = 0);

                scatterplot y = obsid x = thi_lbl      /   markercharacter  =thilabel  markerattrs = (size = 0);
                endlayout;

                %** Fourth column showing odds ratio graph **;
                layout  overlay /   walldisplay = none
                yaxisopts = (reverse = true display = none offsetmin = 0) 
                xaxisopts = (tickvalueattrs = (size = 7pt) labelattrs = (size = 7pt)  
                label = "Geometric Mean Ratio of Test to Reference and 90% CI");
                *highlowplot y = obsid low = lratio high = uratio; 
                *scatterplot y = obsid x = ratio / markerattrs = (symbol = diamondfilled);
                scatterplot y = obsid x = ratio  / xerrorlower = lcl xerrorupper = ucl markerattrs = (size = 0.6pct symbol = squarefilled);        
                referenceline x = 1;
                endlayout;

                layout overlay    /   walldisplay = none
                x2axisopts = (display = (tickvalues) offsetmin = 0.25 offsetmax = 0.25)
                yaxisopts  = (reverse = true display = none);

                scatterplot y = obsid x = ratio_lbl /   markercharacter = ratio
                markercharacterattrs = graphvaluetext xaxis = x2;
                scatterplot y = obsid x = lcl_lbl   /   markercharacter = lcl
                markercharacterattrs = graphvaluetext xaxis = x2;
                scatterplot y = obsid x = ucl_lbl   /   markercharacter = ucl
                markercharacterattrs = graphvaluetext xaxis = x2;
                endlayout;     

            endlayout;
            endgraph;
            end;
            run;

            %put OutputFolder=&OutputFolder.;
            %let ResultFolder = &OutputFolder.\&StudyId.\&ReportFolder;

            /*output folder and output forst plot EACH COHORT*/
            %SmCheckAndCreateFolder(
            BasePath = &OutputFolder.\&StudyId.,
            FolderName = &ReportFolder
            );

            options nodate nonumber;
            ods listing gpath = " &OutputFolder.\&StudyId.\&ReportFolder";
            ods graphics on / noborder imagefmt = png imagename = "&StudyId._ForestPlot_&i." width = 1000px height =600px;

            proc sgrender data= forest_plot_&i. template = ForestPlot; run;

            ods listing close;
            ods graphics off;

        %end;/*eachcohort option2 ends*/
    %end;/*select which cohort ends*/
%end;/*STEP2:select each cohort ends*/ 
%mend PKViewReportForestPlot;  
