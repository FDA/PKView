%*****************************************************************************************;
%**                                                                                     **;
%** Run script to generate a statistical table from the user settings                   **;
%**                                                                                     **;
%** Created by Meng Xu(2015-06-15)                                                      **;
%** Updated by Eduard Porta (2015-06-22)                                                **;
%**                                                                                     **;
%*****************************************************************************************;

%macro PKViewReport();

    /* Read mappings from websvc input dataset (provided by C#) */
    %SmReadMappingsFromDataSet();

    /* Read report settings from websvc input dataset (provided by C#) */
    %SmReadReportSettingsFromDataSet();

    /* Retrieve NDA Id */
    %let Nda_Number=&SubmissionId.;

    /* Generate output path based on NDA Id, User Id and settings Id */
    %let OutputFolder = &SasSpPath.\Output Files\PKView\&UserName.\&ProfileName.\&nda_number.\&SupplementNum;
        
/*      Locate and load estimates file */
    %let EstimatesPath = &OutputFolder.\&StudyId.\estimates;
     libname result "&EstimatesPath"; /*generate result.estimates*/  


    libname pkOutput "&OutputFolder.\estimates";

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


   ods csv file= "&ResultFolder.\AllCohrotsNew.csv" ;

   proc print data=AllCohortsNew;
   run;

  ods csv close;

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

    ods csv file= "&ResultFolder.\cohort_&i..csv" ;

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
    


%mend PKViewReport;  


