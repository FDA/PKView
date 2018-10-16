%*****************************************************************************************;
%**                                                                                     **;
%** Run script to generate Concentration Plots from the user settings                   **;
%**                                                                                     **;
%** Created by Meng Xu and Eduard Porta                                                 **;
%**                                                                                     **;
%*****************************************************************************************;

%macro PKViewReportConcentrationPlot();

%SmReadMappingsFromDataSet();

/* Read report settings from websvc input dataset (provided by C#) */
%SmReadReportSettingsConc();

/* Retrieve NDA Id */
%let Nda_Number=&SubmissionId.;
%put Nda_number=&Nda_Number.;
%put StudyId=&StudyId.;

/* Generate output path based on NDA Id, User Id and settings Id */
%let OutputFolder = &SasSpPath.\Output Files\PKView\&UserName.\&ProfileName.\&nda_number.\&SupplementNum;

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

/*********************************************/
/*********************************************/
/* CODE TO MAKE CONCENTRATION PLOTS HERE */
/*********************************************/
/*********************************************/


%mend PKViewReportConcentrationPlot;  
