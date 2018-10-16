

%macro SmReadAndMergeDataset(
			Input1 = ,
			Input1Sel = ,
			Input1Keep = ,
			Input2 = ,
			Input2Sel = ,
			Input2Keep = ,
			UsubjidVar = ,
			Output = 
);

%** If a path is given find which separator has been used (same separator will be used for both datasets) **;
%if %index(%quote(&Input1.), \) %then %do;
	%let sep = \;
%end;
%else %if %index(%quote(&Input1.), /) %then %do;
	%let sep = /;
%end;
%else %do;
	%let sep = ;
%end;

%** If we only have one dataset no merging is required **;
%if %quote(&Input1.) ne and %quote(&Input2.) eq %then %do;
	%if %index(%upcase(%quote(&Input1.)), .XPT) %then %do;
		%** Define libname **;
		libname input1 xport "&Input1." access = readonly;  

        %let expectedDsName = %scan(%scan(%quote(%quote(&Input1.)), -1, &sep.), 1, .);
        %SmDetermineDataSetName(libname=input1, expectedName='&expectedDsName.');   

		%** Output and subset if needed **;
		data &Output._tmp;
			set input1.&inputDsName.;
				%if &Input1Sel. ne and &Input1Keep. ne %then %do;
					(where = (&Input1Sel.) keep = &Input1Keep.)
				%end;
				%else %if &Input1Sel. ne %then %do;
					(where = (&Input1Sel.))
				%end;
				%else %if &Input1Keep. ne %then %do;
					(keep = &Input1Keep.)
				%end;
			;
		run;
        
        data &Output.;
            set &Output._tmp;
        run;        
	%end;
	%else %do;
		%put ERROR: Dataset is not an XPT file;
	%end;

	%** Clean-up **;
	libname input1 clear;
%end;
%** If both datasets are specified merge them based on USUBJID **;
%else %if %quote(&Input1.) ne and %quote(&Input2.) ne %then %do;
	%if %index(%upcase(%quote(&Input1.)), .XPT) and %index(%upcase(%quote(&Input2.)), .XPT) %then %do;
		%** Define libname **;
		libname input1 xport "&Input1." access = readonly;
		libname input2 xport "&Input2." access = readonly;

		%** Sort **;
		proc sort data = input1.%scan(%scan(%quote(%quote(&Input1.)), -1, &sep.), 1, .)
											%if &Input1Sel. ne and &Input1Keep. ne %then %do;
												(where = (&Input1Sel.) keep = &Input1Keep.)
											%end;
											%else %if &Input1Sel. ne %then %do;
												(where = (&Input1Sel.))
											%end;
											%else %if &Input1Keep. ne %then %do;
												(keep = &Input1Keep.)
											%end;
					out = &work.input1;
			by &UsubjidVar.;
		run;

		proc sort data = input2.%scan(%scan(%quote(%quote(&Input2.)), -1, &sep.), 1, .)
											%if &Input2Sel. ne and &Input2Keep. ne %then %do;
												(where = (&Input2Sel.) keep = &Input2Keep.)
											%end;
											%else %if &Input2Sel. ne %then %do;
												(where = (&Input2Sel.))
											%end;
											%else %if &Input2Keep. ne %then %do;
												(keep = &Input2Keep.)
											%end;
					out = &work.input2;
			by &UsubjidVar.;
		run;

		%** Merge **;
		data &Output.;
			merge	&work.input1 (in = a)
					&work.input2 (in = b);
			by &UsubjidVar.;
			if a and b;
		run;

	%end;
	%else %do;
		%put ERROR: Dataset is not an XPT file;
	%end;

	%** Clean-up **;
	libname input1 clear;
	libname input2 clear;
%end;
%else %do;
	%put ERROR: No datasets specified;
%end;



%mend;
