%*****************************************************************************************;
%**																						**;
%**	Identify the location of the SDTM data in the EDR folder structure					**;
%**																						**;
%**	Input:																				**;
%**		DataSetPath	        -		Path to the dataset folder in EDR					**;
%**		StudyId				-		Name of the Study ID								**;
%**																						**;
%** Output:                                                                             **;
%**		Macro variables InputDm, InputPc, InputPp, InputEx containing the full path to	**;
%**		the DM, PC, PP and EX dataset													**;
%**																						**;
%**	Created by:																			**;
%**		Jens Stampe Soerensen  (2013/2014)                                              **;
%**																						**;
%*****************************************************************************************;

%macro SmIdentifySdtmData(
	DataSetPath = ,
	StudyId = 
);

%** Macro variables **;
%global InputDm InputPc InputPp InputEx InputSuppdm InputSc ProgressGo ;

%let ProgressGo = success;

%put DataSetPath = &DataSetPath.;
%put StudyId = &StudyId.;

%let StudyId2=%sysfunc(tranwrd(&Studyid,-,_));


%** We always have a DM dataset so first identify the folder structure and use that for the rest of the domains **;
%if %sysfunc(fileexist(&DataSetPath.\&StudyId.\tabulations\sdtm)) %then %do;
	%let InputDm = &DataSetPath.\&StudyId.\tabulations\sdtm\dm.xpt;
	%let InputPc = &DataSetPath.\&StudyId.\tabulations\sdtm\pc.xpt;
	%let InputPp = &DataSetPath.\&StudyId.\tabulations\sdtm\pp.xpt;
	%let InputEx = &DataSetPath.\&StudyId.\tabulations\sdtm\ex.xpt;
    %let InputSuppdm = &DataSetPath.\&StudyId.\tabulations\sdtm\suppdm.xpt;
    %let InputSc = &DataSetPath.\&StudyId.\tabulations\sdtm\sc.xpt;
%end;
%else %if %sysfunc(fileexist(&DataSetPath.\&StudyId.\tabulations)) %then %do;
	%let InputDm = &DataSetPath.\&StudyId.\tabulations\dm.xpt;
	%let InputPc = &DataSetPath.\&StudyId.\tabulations\pc.xpt;
	%let InputPp = &DataSetPath.\&StudyId.\tabulations\pp.xpt;
	%let InputEx = &DataSetPath.\&StudyId.\tabulations\ex.xpt;
    %let InputSuppdm = &DataSetPath.\&StudyId.\tabulations\suppdm.xpt;
    %let InputSc = &DataSetPath.\&StudyId.\tabulations\sc.xpt;
%end;
%else %if %nrbquote(&StudyId.) ne and %sysfunc(fileexist(&DatasetPath.\&StudyId.)) %then %do;
	%let InputDm = &DataSetPath.\&StudyId.\dm.xpt;
	%let InputPc = &DataSetPath.\&StudyId.\pc.xpt;
	%let InputPp = &DataSetPath.\&StudyId.\pp.xpt;
	%let InputEx = &DataSetPath.\&StudyId.\ex.xpt;
    %let InputSuppdm = &DataSetPath.\&StudyId.\suppdm.xpt;
    %let InputSc = &DataSetPath.\&StudyId.\sc.xpt;
%end;
%else %if %nrbquote(&StudyId) eq and %sysfunc(fileexist(&DatasetPath.)) %then %do;
	%let InputDm = &DataSetPath.\dm.xpt;
	%let InputPc = &DataSetPath.\pc.xpt;
	%let InputPp = &DataSetPath.\pp.xpt;
	%let InputEx = &DataSetPath.\ex.xpt;
    %let InputSuppdm = &DataSetPath.\suppdm.xpt;
    %let InputSc = &DataSetPath.\sc.xpt;
%end;
%else %if %sysfunc(fileexist(&DataSetPath.\&StudyId2.\tabulations)) %then %do;
	%let InputDm = &DataSetPath.\&StudyId2.\tabulations\dm.xpt;
	%let InputPc = &DataSetPath.\&StudyId2.\tabulations\pc.xpt;
	%let InputPp = &DataSetPath.\&StudyId2.\tabulations\pp.xpt;
	%let InputEx = &DataSetPath.\&StudyId2.\tabulations\ex.xpt;
    %let InputSuppdm = &DataSetPath.\&StudyId2.\tabulations\suppdm.xpt;
    %let InputSc = &DataSetPath.\&StudyId2.\tabulations\sc.xpt;
%end;

%else %do;
	%let ProgressGo = fail;
%end;
%put Continue? - &ProgressGo.;
%put InputDm = &InputDm.;
%put InputPc = &InputPc.;
%put InputPp = &InputPp.;
%put InputEx = &InputEx.;
%put InputEx = &InputSuppdm.;
%put InputEx = &InputSc.;

%mend;
