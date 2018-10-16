%macro StudyInformation(
			ListOfStudies = ,
			NumberOfStudies = ,
			OutputFolder =
	);

%** Macro variables **;
%local i;

%** Merge the study information datasets into one **;
data &work.study_info;
	merge	
		%do i = 1 %to &NumberOfStudies.;
			%if %sysfunc(exist(&work.info_group_&i.)) %then %do;
				&work.info_group_&i.
			%end;
		%end;
	;
	by descnum;
run;

%** Output **;
options orientation = landscape;
ods rtf file = "&OutputFolder.\Study_Information.rtf" style = fda_style;
proc report data = &work.study_info nowd;
	column descnum desc
		%do i = 1 %to &NumberOfStudies.;
			value_&i.
		%end; 
	;

	define descnum		/ order order = internal noprint;
	define desc			/ style = {just = left width = 3cm} "";
	%do i = 1 %to &NumberOfStudies.;
		define value_&i.	/ style = {just = right width = 4cm} "%scan(%nrbquote(&ListOfStudies.), &i., #)";
	%end; 
run;
ods rtf close;
options orientation = portrait;

%mend;
