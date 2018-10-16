%*****************************************************************************************;
%**																						**;
%**	Extract all study names within the intrinsic or extrinsic folder names 				**;
%**																						**;
%**	Input:																				**;
%**		Input		        -		Input dataset containing folder paths  				**;
%**		InputSel			-		Subset in Input usually the subfolder of interest	**;
%**									(5333-INTRIN-FACTOR-PK-STUD-REP or 					**;
%**									 5334-EXTRIN-FACTOR-PK-STUD-REP)					**;
%**		MacroVarName		-		Macro variable name containing the study names		**;
%**																						**;
%** Output:                                                                             **;
%**		Macro variable with the name specified in MacroVarName							**;
%**																						**;
%**	Created by:																			**;
%**		Jens Stampe Soerensen  (2013/2014)                                              **;
%**																						**;
%*****************************************************************************************;

%macro SmExtractStudyNames(
		Input = ,
		InputSel = ,
		MacroVarName =  
);

%global &MacroVarName.;

%** Get the subfolders from the input folder and create a macro variable with the names **;
data _null_;
	set &Input.(where = (upcase(scan(path, -2, ".\")) = "&InputSel.")) end = eof;
	length &MacroVarName. $2000.;
	retain &MacroVarName.;

	%** Create a string of all the study names **;
	if _n_ = 1 then do;
		&MacroVarName. = strip(upcase(scan(path, -1, ".\")));
	end;
	else do;
		&MacroVarName. = cats(&MacroVarName., "#", strip(upcase(scan(path, -1, ".\"))));
	end;

	%** Output **;
	if eof then do;
		call symputx("&MacroVarName.", &MacroVarName.);
	end;
run;

%mend;
