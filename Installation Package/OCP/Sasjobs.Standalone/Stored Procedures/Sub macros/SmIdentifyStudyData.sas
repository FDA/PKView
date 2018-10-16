%*****************************************************************************************;
%**																						**;
%**	Identify the location of the SDTM data in a study               					**;
%**																						**;
%**	Input:																				**;
%**		StudyDir - Path to the dataset folder in EDR                                    **;
%**																						**;
%** Output:                                                                             **;
%**		Macro variables InputDm, InputPc, InputPp, InputEx containing the full path to	**;
%**		the DM, PC, PP and EX dataset													**;
%**																						**;
%**	Created by:																			**;
%**		Eduard Porta Martin Moreno  (2015)                                              **;
%**																						**;
%*****************************************************************************************;

%macro SmIdentifyStudyData(
	StudyDir = 
);

%** Macro variables **;
%global InputDm InputPc InputPp InputEx InputSuppdm InputSc ProgressGo ;

%let ProgressGo = success;

%put StudyDir = &StudyDir.;

%** We always have a DM dataset so first identify the folder structure and use that for the rest of the domains **;
%if %sysfunc(fileexist(&StudyDir.\tabulations\sdtm)) %then %do;
	%let InputDm = &StudyDir.\tabulations\sdtm\dm.xpt;
	%let InputPc = &StudyDir.\tabulations\sdtm\pc.xpt;
	%let InputPp = &StudyDir.\tabulations\sdtm\pp.xpt;
	%let InputEx = &StudyDir.\tabulations\sdtm\ex.xpt;
    %let InputSuppdm = &StudyDir.\tabulations\sdtm\suppdm.xpt;
    %let InputSc = &StudyDir.\tabulations\sdtm\sc.xpt;
%end;
%else %if %sysfunc(fileexist(&StudyDir.\tabulations)) %then %do;
	%let InputDm = &StudyDir.\tabulations\dm.xpt;
	%let InputPc = &StudyDir.\tabulations\pc.xpt;
	%let InputPp = &StudyDir.\tabulations\pp.xpt;
	%let InputEx = &StudyDir.\tabulations\ex.xpt;
    %let InputSuppdm = &StudyDir.\tabulations\suppdm.xpt;
    %let InputSc = &StudyDir.\tabulations\sc.xpt;
%end;
%else %if %nrbquote(&StudyDir.) ne and %sysfunc(fileexist(&StudyDir.)) %then %do;
	%let InputDm = &StudyDir.\dm.xpt;
	%let InputPc = &StudyDir.\pc.xpt;
	%let InputPp = &StudyDir.\pp.xpt;
	%let InputEx = &StudyDir.\ex.xpt;
    %let InputSuppdm = &StudyDir.\suppdm.xpt;
    %let InputSc = &StudyDir.\sc.xpt;
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

%mend SmIdentifyStudyData;
