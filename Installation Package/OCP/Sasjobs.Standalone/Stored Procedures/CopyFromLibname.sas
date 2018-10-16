libname iportal odbc dsn = "OCPSQL" access = readonly;
libname output ".\Output Files\PkView\SAS files";

options nofmterr compress = yes mprint spool;

data output.iportal_dm_dataset;
	set iportal.iportal_dm_dataset;
run;

data output.iportal_dm_file;
	set iportal.iportal_dm_file;
run;

data output.iportal_file;
	set iportal.iportal_file;
run;

data output.iportal_pc_dataset;
	set iportal.iportal_pc_dataset;
run;

data output.iportal_pc_file;
	set iportal.iportal_pc_file;
run;

data output.iportal_pp_dataset;
	set iportal.iportal_pp_dataset;
run;

data output.iportal_pp_file;
	set iportal.iportal_pp_file;
run;

data output.iportal_sdtm_variable;
	set iportal.iportal_sdtm_variable;
run;

data output.iportal_study;
	set iportal.iportal_study;
run;

data output.iportal_study_design;
	set iportal.iportal_study_design;
run;

data output.iportal_study_type;
	set iportal.iportal_study_type;
run;

data output.iportal_submission;
	set iportal.iportal_submission;
run;

data output.iportal_submission_type;
	set iportal.iportal_submission_type;
run;

data output.iportal_variable_mapping;
	set iportal.iportal_variable_mapping;
run;
