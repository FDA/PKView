%*****************************************************************************************;
%**																						**;
%**	Check if a dataset contains missing numerical values						        **;
%**																						**;
%**	Input:																				**;
%**		Input        	-		Input dataset			                				**;
%**																						**;
%** Output:                                                                             **;
%**		Macro variable called ContainsData (0 = only missing, 1 = has non-missing data)	**;
%**																						**;
%**	Created by:																			**;
%**		Jens Stampe Soerensen  (2013/2014)                                              **;
%**																						**;
%*****************************************************************************************;
%macro SmContainsMissing(
	Input = 
);

	%** Make sure the macro variable is cleared **;
	%if %symexist(ContainsData) %then %do;
		%symdel ContainsData;
	%end;

	%** Global variables **;
	%global ContainsData;

	%** Does the dataset only contain missing? **;
	data _null_;
		set &Input. end = eof;

		%** Array for each datatype **;
		array n{*} _NUMERIC_;

		%** Hit contains whether data conntains non-missing values **;
		retain hit;
		hit = 0;

		%** Loop through the arrays and check for non-missing values **;
		do i = 1 to dim(n);
			if n{i} ^= . then do;
				hit = 1;	
			end;
		end;

		%** Output to a global macro variable **;
		if eof then do;
			call symputx("ContainsData", hit, "G");
		end;
	run;
%mend;
