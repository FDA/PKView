%*****************************************************************************************;
%**																						**;
%** Check if a variable exist in a dataset												**;
%**																						**;
%**	Input:																				**;
%**		Ds					-		Input dataset										**;
%**		Var			        -		Variable to look for in ds							**;
%**																						**;
%** Output:                                                                             **;
%**		Macro variable varexist (1 = exist, missing = does not exist)					**;
%**																						**;
%**	Created by:																			**;
%**		Jens Stampe Soerensen  (2013/2014)                                              **;
%**																						**;
%*****************************************************************************************;

%macro SmVarExist(
	Ds = ,
	Var = 
);

%** Local/Global macro variables **;
%local rc dsid varexist;

%** Create a reference to the dataset and open the dataset **;
%let dsid = %sysfunc(open(&ds.));

%** Check for existance **;
%if %sysfunc(varnum(&dsid., &var.)) > 0 %then %do;
	%let varexist = 1;
%end;
%else %do;
	%let varexist = ;
%end;

%** Close the dataset / reference **;
%let rc = %sysfunc(close(&dsid.));

%** Return **;
&varexist.
%mend;
