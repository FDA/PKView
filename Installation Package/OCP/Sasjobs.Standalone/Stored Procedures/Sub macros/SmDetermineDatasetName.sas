/* 
  This macro will determine the real dataset name of the 
  dataset stored in an xpt file.
  
  Input parameters:
  -libname: the sas library name of the loaded xpt file
  -expectedName: the expected dataset name, this is used in case
    the xpt file contains multiple datasets.  
    
  Output macro variables:
  -inputDsName: the name of the dataset
*/
%macro SmDetermineDatasetName(
	libname = ,
	expectedName =
);

	%global inputDsName;
	%let inputDsName =;

    /* Get the list of datasets in the library */
	proc contents data=&libname.._ALL_ memtype=data out=&work.dsNames0(keep=memname) noprint;
	run;

	proc sort data=&work.dsNames0 OUT=&work.dsNames nodupkey;
	  BY memname;
	run;

    /* If expected dataset name is found set inputDsName to it */
	data _null_;
		set &work.dsNames;
		if index(upcase(memname), upcase(&expectedName.)) ne 0 then do;
			call symput('inputDsName', memname);
		end;
	run;

    /* If expected dataset name was not found return the first 
       dataset in the list, this will generally work as XPT files
       submitted by the sponsors should never contain more than one */
	%if &inputDsName. eq %then %do;
		data _null_;
			set &work.dsNames;
			by memname;
			if first.memname then do;
				call symput('inputDsName', memname);
			end;
		run;
	%end;
%mend;




