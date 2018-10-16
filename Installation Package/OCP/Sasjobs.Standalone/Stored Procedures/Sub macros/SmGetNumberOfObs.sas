%*****************************************************************************************;
%**																						**;
%**	Get the number of observations in a dataset											**;
%**																						**;
%**	Input:																				**;
%**		Input		        -		Input dataset 										**;
%**																						**;
%** Output:                                                                             **;
%**		Macro variable called NumberOfObs containing the number of observations in		**;
%**		Input																			**;
%**																						**;
%**	Created by:																			**;
%**		Jens Stampe Soerensen  (2013/2014)                                              **;
%**																						**;
%*****************************************************************************************;

%macro SmGetNumberOfObs(
	Input = 
);

%** Set the number of observations as a global variable so it can be access outside this macro **;
%global NumberOfObs;

%** Get the number of observations **;
%let dsid = %sysfunc(open(&Input.));
%let NumberOfObs = %sysfunc(attrn(&dsid., nlobs));
%let rc = %sysfunc(close(&dsid.));

%mend;
