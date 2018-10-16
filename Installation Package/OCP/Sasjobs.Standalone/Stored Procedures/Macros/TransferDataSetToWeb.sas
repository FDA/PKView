%*****************************************************************************************;
%**																						**;
%**	Transfor xpt datasets to the web-service											**;
%**																						**;
%** Output:                                                                             **;
%**		Converted xpt file 																**;
%**																						**;
%**	Created by:																			**;
%**		Jens Stampe Soerensen  (2013/2014)                                              **;
%**																						**;
%*****************************************************************************************;

%macro TransferDataSetToWeb();

%if %sysfunc(exist(websvc.sasdata)) %then %do;
	%** Get the file path **;
	data _null_;
		set websvc.sasdata;
		call symputx("filepath", filepath);
	run;
	
	%** Read the dataset and transfer to &work.out (which the C# code reads) **;
    %SmReadAndMergeDataset(
        Input1 = &filepath.,
        Output = &work.out
    );    
	
	data &work.data;
		length dataset $20.;
		dataset="out"; output;
	run;

	%if %sysfunc(exist(&work.out)) %then %do;
	proc export data=&work.out
		outfile="\\&SYSHOSTNAME.\Output Files\PkView\Peter\outforxptdata.csv"
		dbms=dlm replace;
		delimiter=',';
		run; 
	%end;

	%** Clean up **;
	libname input clear;
%end;
%mend;

