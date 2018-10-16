%macro Initialize_Datasets();
	%** Read the datasetId **;
	%if %sysfunc(exist(websvc.systemdata)) %then %do;
		data _null_;
			set websvc.systemdata;
			call symputx("DataSuffix", DataSuffix);
		run;
	%end;
%mend;