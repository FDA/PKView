%*****************************************************************************************;
%**																						**;
%**	Extract the column names and labels for a dataset									**;
%**																						**;
%**	Input:																				**;
%**		Input		        -		Input dataset 										**;
%**		Output				-		Output dataset with column names and labels			**;
%**		MacroVarName		-		Name of the macro variable containing the variable	**;
%**									names												**;
%**		MacroVarLabel		-		Name of the macro variable containing the variable	**;
%**									labels												**;
%**																						**;
%** Output:                                                                             **;
%**		Output dataset specified in the OutputVariable, macro variables MacroVarName	**;
%**		and MacroVarLabel																**;
%**																						**;
%**	Created by:																			**;
%**		Jens Stampe Soerensen  (2013/2014)                                              **;
%**																						**;
%*****************************************************************************************;

%macro SmGetColumnNames(
			Input = ,
			Output = ,
			MacroVarName = ,
			MacroVarLabel = 
);

%** Does the input dataset exist? **;
%if not %sysfunc(exist(&Input.)) %then %do;
	%let status = fail;
	%put Fail: Input dataset does not exist.;
	%return;
%end;
%** Are the macro names defined? **;
%if &MacroVarName. eq or &MacroVarLabel. eq %then %do;
	%let status = fail;
	%put Warning: The macro variable names are not defined.;
%end;

%** Initialize the global macro variables **;
%global &MacroVarName. &MacroVarLabel.;

%** Read first line in the dataset and get the column names - output to a dataset**;
data &Output.;
	set &Input. (obs = 1);

	%** Arrays containing all numeric and character columns **;
	array n{*} _NUMERIC_;
	array c{*} _CHARACTER_;

	%** Output the numeric column names **;
	do i = 1 to dim(n);
		colname = vname(n{i});
		collabel = vlabel(n{i});
		output;
	end;

	%** Output the character column names **;
	do i = 1 to dim(c);
		colname = vname(c{i});
		collabel = vlabel(c{i});
		output;
	end;

	%** Only keep the column names **;
	keep colname collabel;
run;

%** Sort **;
proc sort data = &Output.;
	by colname;
run;

%** Read the dataset and create macro list of the column names and labels **;
%if &MacroVarName. ne or &MacroVarLabel. ne %then %do;
	data _null_;
		set &Output. end = eof;
		length &MacroVarName. &MacroVarLabel. $2000.;
		retain &MacroVarName. &MacroVarLabel.;

		%** Generate the lists **;
		if _n_ = 1 then do;
			&MacroVarName. = colname;
			&MacroVarLabel. = collabel;
		end;
		else do;
			&MacroVarName. = strip(&MacroVarName.) || "#" || colname;
			&MacroVarLabel. = strip(&MacroVarLabel.) || "#" || collabel;
		end;

		%** Create the macro variables **;
		if eof then do;
			call symputx("&MacroVarName.", strip(&MacroVarName.));
			call symputx("&MacroVarLabel.", strip(&MacroVarLabel.));
		end;
	run;
%end;

%mend SmGetColumnNames;
