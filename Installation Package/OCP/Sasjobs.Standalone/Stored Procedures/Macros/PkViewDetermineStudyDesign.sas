%*****************************************************************************************;
%**                                                                                     **;
%** Run script to get the SDTM mappings and study design                                **;
%**                                                                                     **;
%** Created by:                                                                         **;
%**     Jens Stampe Soerensen  (2013/2014)                                              **;
%**                                                                                     **;
%** Modified by:                                                                        **;
%**     Eduard Porta Martin Moreno (2015)                                               **;
%**                                                                                     **;
%*****************************************************************************************;

%macro PkViewDetermineStudyDesign();

    /* Read mappings from websvc input dataset (provided by C#) */
    %SmReadMappingsFromDataSet();
   
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
    %**     Read Input Datasets                 **;
    %*********************************************;
    
    %SmReadAndMergeDataset(
        Input1 = &InputDm.,
        Output = &work.dm
    );
    
    /* Replace DM arm variable with custom one */
    %if &UseCustomArms.=1 %then %do;
        proc sort data = &work.dm; by &ArmVar.; run;
        proc sort data = &work.customDmArms; by OldArm; run;
        data &work.dm(rename=(NewArm=&ArmVar.));
			merge &work.dm(rename=(&ArmVar.=OldArm) in=hasData)
                  &work.customDmArms;
            by OldArm;
            if hasData;
		run;        
    %end;



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
 



    
    %if &UseEx.=1 and %sysfunc(fileexist(&InputEx.)) %then %do;   
        %SmReadAndMergeDataset(
            Input1 = &InputEx.,
            UsubjidVar = &UsubjidVar.,
            Output = &work.ex
        );
    %end;

    %*********************************************;
    %**     Determine the study design          **;
    %*********************************************;
    
    %SmDetermineStudyDesign(
        InputDm = &InputDm.,
        UsubjidVar = &UsubjidVar.,
        SequenceVar = &SequenceVar.,
        InputPp = &InputPp.,
        AnalyteVar = &AnalytePpVar.,
        ParameterVar = &ParameterVar.,
        PeriodVar = &PeriodPpVar.,  
        InputEx = &InputEx.,
        %if %SYMEXIST(ExTrtVar) %then %do;
            ExTrtVar = &ExTrtVar.,
        %end;
        %if %SYMEXIST(ExDateVar) %then %do;
            ExDateVar = &ExDateVar.,
        %end;
        StudyArea = &StudyType. 
    );
                
    %if &UseEx.=1 and %sysfunc(fileexist(&InputEx.)) %then %do;
        %put inputEX exist;
        %SmDetermineStudyDesignJiaxiang(
            InputEx = &work.ex,
            UsubjidVar = &USUBJIDVAR,
            SequenceVar = &SequenceVar,
            ExTrtVar = &ExTrtVar,
            ExDateVar = &EXDATEVAR
        );

        %put Study Design old = &StudyDesign.;
        %put StudyDesign new = &Studydesignx.;
        %if &StudyDesignx. ne %then %let StudyDesign=&StudyDesignx.;
    %end;
    
    %put Study Design = &StudyDesign.;
    
%** Output data **;
data &work.studyDesign NOLIST;
    length StudyDesign $32.;
    StudyDesign="&StudyDesign."; output;
run;



%** Output datasets list needed by C# interface **;
data &work.data NOLIST;
    length dataset $32.;
    dataset="studyDesign"; output;
run;

	%if %sysfunc(exist(&work.studyDesign)) %then %do;
		proc export data=&work.studyDesign
		outfile="\\&SYSHOSTNAME.\Output Files\PkView\Peter\studyDesign.csv"
		dbms=dlm replace;
		delimiter=',';
		run; 
	%end;

%mend PkViewDetermineStudyDesign;
