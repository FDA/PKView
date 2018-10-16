%*****************************************************************************************;
%**                                                                                     **;
%** Run script to list all potential references                                         **;
%**                                                                                     **;
%** Created by Meng Xu (2015)                                                           **;
%**                                                                                     **;
%**                                                                                     **;
%*****************************************************************************************;  

 
%macro PkViewListPotentialReference();
    
    /* Read mappings from websvc input dataset (provided by C#) */
    %SmReadMappingsFromDataSet();
    
    %Log(
        Progress = 1,
        TextFeedback = Creating folder structures for study &StudyId.
    );

    %** Retrieve NDA Id **;
    %let Nda_Number=&SubmissionId.;

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
                length EstPeriodVar $500.;
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
        
        %end;
    
    %Log(
        Progress = 100,
        TextFeedback = Analysis of study &StudyId. complete
    );

    %put meng check it;
    %put UsubjidVar.=&UsubjidVar. ;
    %put StudyId.=&studyId;
    %put SequenceVar = &SequenceVar.;
    %put AnalyteVar = &AnalytePpVar.;
    %put ParameterVar = &ParameterVar.;
    %put PeriodVar = &PeriodPpVar.;
    %put  ResultVar = &ResultPpVar.;





    *List potential references: 
    Meng & Eduward created on 0507_2015,Meng debug on 5/15;
    *get the value of unique cohortdescriptions and create macro varibale;
    proc sql noprint;
        select count(distinct cohortdescription) into :NumVar 
        from &work.adpp;
    quit;

    /*DEBUGGING */
    %put NumVar=&NumVar.;

    /* if we have multiple cohorts; */
    %if &NumVar. > 1 %then %do;
        *whether the treatmentinperiodtext is contained in cohortdescription*;
        data &work.trtsCohort NOLIST; 
        length treatmentinperiodtext $500.;
            set &work.adpp;
            if index(CohortDescription,strip(treatmentinperiodtext))ne 0 then output;
        run;
        %let refOrigin = &work.trtsCohort;

        proc sql noprint;
            select distinct treatmentinperiodtext into :treatmentinperiodtext
            from &refOrigin;
        quit;

        proc freq data=&refOrigin noprint;
            tables CohortDescription*TreatmentInPeriodText/out=&work.reference0 ;
        run;

        * Strip leading and trailing whitespace;
        data &work.reference (keep=CohortDescription Reference);
         
            set &work.reference0;
            Reference = strip(TreatmentInPeriodText);
            output;
        run;

        %** Output datasets list needed by C# interface **;
        data &work.data NOLIST;
            length dataset $32.;
            dataset="reference"; output;
        run;
		%if %sysfunc(exist(&work.reference)) %then %do;
				proc export data=&work.reference
		outfile="\\&SYSHOSTNAME.\Output Files\PkView\Peter\reference.csv"
		dbms=dlm replace;
		delimiter=',';
		run; 
		%end;
    %end;


    /* if only 1 cohort, then output its potential references directly */
    %else %do;
        %let refOrigin = &work.adpp; 

        proc sql noprint;
            select distinct treatmentinperiodtext into :treatmentinperiodtext
            from &refOrigin;
        quit;

        %put refOrigin=&refOrigin;
            
        * get freqency tables;
        proc freq data=&refOrigin noprint;
            tables CohortDescription*treatmentinperiodtext/out=&work.reference0(keep=CohortDescription TreatmentInPeriodText) ;
        run;

        * Strip leading and trailing whitespace;
        data &work.reference (keep=CohortDescription Reference);

            set &work.reference0;
            Reference = strip(TreatmentInPeriodText);
            output;
        run;

        %** Output datasets list needed by C# interface **;
        data &work.data NOLIST;
            length dataset $32.;
            dataset="reference"; output;
        run;
		%if %sysfunc(exist(&work.reference)) %then %do;
			proc export data=&work.reference
		outfile="\\&SYSHOSTNAME.\Output Files\PkView\Peter\reference.csv"
		dbms=dlm replace;
		delimiter=',';
		run; 
		%end;
    %end;  
%end;

%mend PkViewListPotentialReference;



   























