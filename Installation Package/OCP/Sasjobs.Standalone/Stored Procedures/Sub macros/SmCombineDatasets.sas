%macro SmCombineDatasets(
		Input = ,
		DatasetName = ,
		Extension = ,
		Output = 
);

%** Read the input dataset and identify all datasets fitting with the dataset name **;
%** Create a macro variable containing the path **;
data _null_;
	set &Input. (where = (upcase(filename) = "%upcase(&DatasetName.)%upcase(&Extension.)")) end = eof;
	length filelist $2000.;
	retain filelist;

	%** Number of files found **;
	nfiles + 1;

	%** List of paths **;
	if nfiles = 1 then do;
		filelist = strip(path) || "\&DatasetName.&Extension";
	end;
	else do;
		filelist = strip(filelist) || "#" || strip(path) || "\&DatasetName.&Extension";
	end;
	
	%** Output **;
	if eof then do;
		call symputx("filelist", filelist);
		call symputx("nfiles", nfiles);
	end;
run;

%** Generate a libname to each file **;
%do i = 1 %to &nfiles.;
	libname input&i. xport "%scan(&filelist., &i., #)" access = readonly;
%end;

%** Combine the files **;
data &Output.;
	set
		%do i = 1 %to &nfiles.;
			input&i..&DatasetName.
		%end;
	;
run;

%** Clear all libnames **;
%do i = 1 %to &nfiles.;
	libname input&i. clear;
%end;

%mend SmCombineDatasets;
