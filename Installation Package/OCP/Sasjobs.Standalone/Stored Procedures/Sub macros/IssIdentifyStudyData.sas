%*****************************************************************************************;
%**																						**;
%**	Identify the location of the SDTM data in a study               					**;
%**																						**;
%**	Input:																				**;
%**		StudyDir - Path to the dataset folder in EDR                                    **;
%**																						**;
%** Output:                                                                             **;
%**		Macro variables InputAe, InputSl, InputVs, InputEx containing the full path to	**;
%**		the Ae, Sl, Vs and EX dataset													**;
%**																						**;
%**	Created by:																			**;
%**		Yue Zhou  (2017)																**;
%**			based on work by															**;
%**		Eduard Porta Martin Moreno  (2015)                                              **;
%**																						**;
%*****************************************************************************************;

%macro IssIdentifyStudyData(
	StudyDir = 
);

%** Macro variables **;
%global InputAe InputSl InputVs ProgressGo ;*InputAe InputSl InputVs ProgressGo ;

%let ProgressGo = success;

%put StudyDir = &StudyDir.;
%** We always have a adae dataset so first identify the folder structure and use that for the rest of the domains **;
%if %sysfunc(fileexist(&StudyDir.\analysis\adam\datasets)) %then %do;
	%let InputAe = &StudyDir.\analysis\adam\datasets\adAe.xpt;
	%let InputSl = &StudyDir.\analysis\adam\datasets\adSl.xpt;
	%let InputVs = &StudyDir.\analysis\adam\datasets\adVs.xpt;
%end;

%else %if %sysfunc(fileexist(&StudyDir.\analysis\adam)) %then %do;
	%let InputAe = &StudyDir.\analysis\adam\adAe.xpt;
	%let InputSl = &StudyDir.\analysis\adam\adSl.xpt;
	%let InputVs = &StudyDir.\analysis\adam\adVs.xpt;
%end;
%else %if %sysfunc(fileexist(&StudyDir.\analysis\adam)) %then %do;
	%let InputAe = &StudyDir.\analysis\adAe.xpt;
	%let InputSl = &StudyDir.\analysis\adSl.xpt;
	%let InputVs = &StudyDir.\analysis\adVs.xpt;
%end;
%else %if %nrbquote(&StudyDir.) ne and %sysfunc(fileexist(&StudyDir.)) %then %do;
	%let InputAe = &StudyDir.\adAe.xpt;
	%let InputSl = &StudyDir.\adSl.xpt;
	%let InputVs = &StudyDir.\adVs.xpt;
%end;

%else %do;
	%let ProgressGo = fail;
%end;
%put Continue? - &ProgressGo.;
%put InputAe = &InputAe.;
%put InputSl = &InputSl.;
%put InputVs = &InputVs.;

%mend IssIdentifyStudyData;
