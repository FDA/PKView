%*****************************************************************************************;
%**                                                                                     **;
%** Run script to generate statistical output and plots                                 **;
%**                                                                                     **;
%** Created by:                                                                         **;
%**     Jens Stampe Soerensen  (2013/2014)                                              **;
%**                                                                                     **;
%*****************************************************************************************;

%macro PkViewRunStudyAnalysisSimple();
    
    /* Read mappings from websvc input dataset (provided by C#) */
    %SmReadMappingsFromDataSet();
    
    %Log(
        Progress = 1,
        TextFeedback = Creating folder structures for study &StudyId.
    );   
    

    %** Retrieve NDA Id **;
    %let Nda_Number=&SubmissionId.;
    
    %** Generate output path based on NDA Id, User Id and settings Id **;
    %let OutputFolder = &SasSpPath.\Output Files\PKView\&UserName.\&ProfileName.\&nda_number.;
    
    %** Create missing folders **;
    %SmCheckAndCreateFolder(
        BasePath = &SasSpPath.\Output Files\PKView,
        FolderName =  &UserName.
    );
    %SmCheckAndCreateFolder(
        BasePath = &SasSpPath.\Output Files\PKView\&UserName.,
        FolderName = &ProfileName.
    );
    %SmCheckAndCreateFolder(
        BasePath = &SasSpPath.\Output Files\PKView\&UserName.\&ProfileName.,
        FolderName = &nda_number.
    );
    
    %** Generate the necessary styles and formats **;
    %SmFormatAndStyles;

    %** Run the study by study analysis **;
%if %upcase(&ProgressGo.) = SUCCESS %then %do;

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

    %** Create a folder for the output **;
    %SmCheckAndCreateFolder(
        BasePath = &OutputFolder.,
        FolderName = &CurrentStudy.
    );

    %*********************************************;
    %**     Prepare data for analysis (PC)      **;
    %*********************************************;
    %** Initially merge **;
    
    %Log(
        Progress = 20,
        TextFeedback = Preparing concentration data for study &StudyId.
    );

    %SmReadAndMergeDataset(
        Input1 = &InputDm.,
        Input2 = &InputPc.,
        UsubjidVar = &UsubjidVar.,
        Output = &work.adpc
    );
    
    /* Replace DM arm variable with custom one */
    %if &UseCustomArms.=1 %then %do;
        proc sort data = &work.adpc; by &ArmVar.; run;
        proc sort data = &work.customDmArms; by OldArm; run;
        data &work.adpc(rename=(NewArm=&ArmVar.));
            merge &work.adpc(rename=(&ArmVar.=OldArm) in=hasData)
                  &work.customDmArms;
            by OldArm;
            if hasData;
        run;
    %end;
    
    /* Replace PC:Visit variable with custom one */
    %if &UseCustomPcVisit.=1 %then %do;
        proc sort data = &work.adpc; by &PcVisitVar.; run;
        proc sort data = &work.customPcVisit; by OldValue; run;
        data &work.adpc(rename=(NewValue=&PcVisitVar.));
            merge &work.adpc(rename=(&PcVisitVar.=OldValue) in=hasData)
                  &work.customPcVisit;
            by OldValue;
            if hasData;
        run;
    %end;

    %if %upcase(&StudyDesign.) = PARALLEL %then %do;
        %SmParallelGrouping(
            Input = &work.adpc,
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
        
        /* Replace DM arm variable with custom one */
        %if &UseCustomArms.=1 %then %do;
            proc sort data = &work.adex; by &ArmVar.; run;
            proc sort data = &work.customDmArms; by OldArm; run;
            data &work.adex(rename=(NewArm=&ArmVar.));
                merge &work.adex(rename=(&ArmVar.=OldArm))
                      &work.customDmArms;
                by OldArm;
            run;
        %end;

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
    
    %** Then process **;
    %if %upcase(&StudyDesign.) ne UNKNOWN and &PeriodPcVar. ne and &SequenceVar. ne 
        and &AnalytePcVar. ne and &TimeVar. ne %then %do;
        %put TimeVar = &TimeVar.;
        %put 1016JG PeriodExVar=&PeriodExVar.;
        %SmPrepareDataForAnalysis(
                Input = &work.adpc,
                SequenceVar = &SequenceVar.,
                AnalyteVar = &AnalytePcVar.,
                TimeVar = &TimeVar.,
                PeriodVar = &PeriodPcVar.,
                ResultVar = &ResultPcVar.,
                ExData = &work.adex,
                %if %SYMEXIST(ExTrtVar) %then %do;
                  ExTrtVar = &ExTrtVar.,
                %end;
                %if %SYMEXIST(ExDateVar) %then %do;
                  ExDateVar = &ExDateVar.,
                %end;
                ExPeriodVar = &PeriodExVar.,
                Type = pc,
                StudyArea = &StudyType.,
                StudyDesign = &StudyDesign.
        );
        %put TimeVar = &TimeVar.;

        %Log(
            Progress = 40,
            TextFeedback = Creating concentration-time profiles for study &StudyId.
        );
    
        *jiaxiang1030 check PC status;
        %macro CheckPcStatus(input=);
        %global PcStatus;
            %CheckifvarexistinAData(varname=combination, data=&input.);
            %if &varexist.=1 %then %let combinationPc = 1;
                %else %let combinationPc = 0;
            %CheckifvarexistinAData(varname=treatmentinperiodtext, data=&input.);
            %if &varexist.=1 %then %let treatmentinperiodtextPc = 1;
                %else %let treatmentinperiodtextPc = 0;

        %if &combinationPc.=1 and &treatmentinperiodtextPc.=1 %then %let PcStatus=1;
            %else %let PcStatus=0;
        %mend;
        %checkPcStatus(input=&work.adpc);
        *jiaxiang1030 check PC status;

        %if %upcase(&ProgressGo.) = SUCCESS and &PcStatus.=1 %then %do;
            %** Time Concentration Plots **;
            %Time_Profile(
                Input = &work.adpc,
                TimeVar = &TimeVar.,
                AnalyteVar = &AnalytePcVar.,
                PeriodVar = &PeriodPcVar.,
                ResultVar = &ResultPcVar.,
                StudyDesign = &StudyDesign.,
                StudyId = &CurrentStudy.,
                OutputFolder = &OutputFolder.\&CurrentStudy.
            );
        %end;
    %end;           

    %*********************************************;
    %**     Prepare data for analysis (PK)      **;
    %*********************************************;
    %** Initially merge **;
    
    %Log(
        Progress = 60,
        TextFeedback = Preparing PK data for study &StudyId.
    );
    
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
    
    /* Replace PP:Visit variable with custom one */
    %if &UseCustomPpVisit.=1 %then %do;
        proc sort data = &work.adpp; by &PpVisitVar.; run;
        proc sort data = &work.customPpVisit; by OldValue; run;
        data &work.adpp(rename=(NewValue=&PpVisitVar.));
            merge &work.adpp(rename=(&PpVisitVar.=OldValue) in=hasData)
                  &work.customPpVisit;
            by OldValue;
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
        
        /* Replace DM arm variable with custom one */
        %if &UseCustomArms.=1 %then %do;
            proc sort data = &work.adex; by &ArmVar.; run;
            proc sort data = &work.customDmArms; by OldArm; run;
            data &work.adex(rename=(NewArm=&ArmVar.));
                merge &work.adex(rename=(&ArmVar.=OldArm))
                      &work.customDmArms;
                by OldArm;
            run;
        %end;

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

*meng fix it on 06022015;
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
    
        %Log(
            Progress = 80,
            TextFeedback = Executing pk analysis summary of study &StudyId.
        );

        %** Pharmacokinetic parameters - run analyses **;
        %if %upcase(&ProgressGo.) = SUCCESS %then %do;

            data &work.analysisInput;
                set &work.adpp;
            run;
            
           %PK_Analysis_SummarySimple(
                Input = &work.analysisInput,
                AnalyteVar = &AnalytePpVar.,
                ParameterVar = &ParameterVar.,
                ResultVar = &ResultPpVar.,
                PeriodVar = &PeriodPpVar.,
                UsubjidVar = &UsubjidVar.,
                SequenceVar = &SequenceVar.,
                StudyDesign = &StudyDesign.,
                StudyId = &CurrentStudy., 
                OutputFolder = &OutputFolder.\&CurrentStudy.
            );  

           /*%meng( Input = &work.estimates,
                AnalyteVar = &AnalytePpVar.
            );*/
        





        %end;
    %end;
    
    %Log(
        Progress = 100,
        TextFeedback = Analysis of study &StudyId. complete
    );
 

 
%end;

%** Output the study information **;
%*StudyInformation(
    ListOfStudies = %nrbquote(&Study_list.),
    NumberOfStudies = %sysfunc(countw(%nrbquote(&Study_list.),#)),
    OutputFolder = &OutputFolder.
);

%** Output **;
%put Progress = &ProgressGo.; 
  
%mend PkViewRunStudyAnalysisSimple;

