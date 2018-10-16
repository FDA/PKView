%*****************************************************************************************;
%**																						**;
%** Read mappings from the SQL database	based on a Study ID code						**;
%**																						**;
%**	Input:																				**;
%**		SubmissionId		-		Submission ID from the SQL database					**;
%**		StudyCode	        -		Study Id code from the SQL database					**;
%**																						**;
%** Output:                                                                             **;
%**		Macro variables with the mappings (see bottom of code)							**;
%**																						**;
%**	Created by:																			**;
%**		Jens Stampe Soerensen  (2013/2014)                                              **;
%**																						**;
%*****************************************************************************************;

%macro SmReadMappingsFromDB(
			SubmissionId = ,
			StudyCode = ,
	);

%** Macro variables **;
%global StudyDesign StudyType DmPath ExPath PcPath PpPath
		UsubjidVar ArmVar AgeVar SexVar CountryVar RaceVar EthnicVar
		ExTrtVar ExStdtcVar ExVisitVar
		PcstresnVar PcVisitVar PcTestVar PcTptnumVar
		PpstresnVar PpVisitVar PpCatVar PpTestcdVar
;

%local i;

%put I am here!;

data &work.test;
	set iportal.IPORTAL_STUDY(where = (SUBMISSION_ID = &SubmissionId. and strip(STUDY_CODE) = "&StudyCode."));
	put STUDY_ID;
	put STUDY_CODE;
run;

%** Get the study design **;
proc sql noprint;
	create table 
		&work.study_design
	as select
		a.STUDY_CODE,
		a.STUDY_ID,
		b.NAME as StudyDesign,
		c.NAME as StudyType
	from
		iportal.IPORTAL_STUDY(where = (SUBMISSION_ID = &SubmissionId. and strip(STUDY_CODE) = "&StudyCode.")) as a
	left join
		iportal.IPORTAL_STUDY_DESIGN as b
	on
		a.STUDY_DESIGN_ID = b.STUDY_DESIGN_ID

	left join
		iportal.IPORTAL_STUDY_TYPE as c
	on
		a.STUDY_TYPE_ID = c.STUDY_TYPE_ID
	;

	select
		StudyDesign,
		StudyType,
		STUDY_ID
	into
		:StudyDesign,
		:StudyType,
		:StudyId
	from
		&work.study_design
	;
quit;

%** Debug **;
%put Extracted Study Design: &StudyDesign.;
%put Extracted Study Type: &StudyType.;
%put Extracted Study Id: &StudyId.;

%** Get the mappings for each file **;
%let filetype = DM#EX#PC#PP;
proc sql noprint;
	%do i = 1 %to %sysfunc(countw(%nrbquote(&filetype.),#));
		%let file = %scan(%nrbquote(&filetype.), &i., #); 
		%** Merge the file and dataset tables **;
		create table 
			&work.&file._dataset
		as select
			a.*,
			b.*
		from
			iportal.IPORTAL_&file._DATASET(where = (STUDY_ID = &StudyId.)) as a 
		left join
			iportal.IPORTAL_&file._FILE as b
		on
			a.&file._DATASET_ID = b.&file._DATASET_ID
		;

		%** Get the file Id **;
		select
			FILE_ID
		into
			:FileId
		from
			&work.&file._dataset
		;
		
		%** Debug **;
		%put File id = &FileId.;

		%** Merge the SDTM and variables mappings **;
		create table
			&work.sdtm_variable_mapping
		as select
			a.*,
			b.*
		from
			iportal.IPORTAL_VARIABLE_MAPPING(where = (FILE_ID = &FileId.)) as a
		left join
			iportal.IPORTAL_SDTM_VARIABLE as b
		on
			a.SDTM_VARIABLE_ID = b.SDTM_VARIABLE_ID
		;

		%** Get the mappings **;
		create table
			&work.&file._mappings
		as select
			a.*,
			b.*,
			c.*
		from
			&work.&file._dataset as a
		left join
			iportal.IPORTAL_FILE as b
		on
			a.FILE_ID = b.FILE_ID

		left join
			&work.sdtm_variable_mapping as c
		on
			a.FILE_ID = c.FILE_ID
		;
	%end;
quit;

%** Save into global macro variables **;
%do i = 1 %to %sysfunc(countw(%nrbquote(&filetype.),#));
	%let file = %scan(%nrbquote(&filetype.), &i., #); 
	data _null_;
		set &work.&file._mappings end = eof;
		length NAME_VAR $36.;

		if upcase(NAME) ^= "VISIT" then do;
			NAME_VAR = cats(NAME, "VAR");
		end;
		else do;
			NAME_VAR = cats("&file.", NAME, "VAR");
		end;
		call symputx(NAME_VAR, FILE_VARIABLE, "G");

		if eof then do;
			call symputx("&File.Path", SERVER_PATH, "G");
		end;
	run;

%end;

%** Debug **;
%put DM file path = &DmPath.;
%put EX file path = &ExPath.;
%put PC file path = &PcPath.;
%put PP file path = &PpPath.;

%put UsubjidVar = &UsubjidVar.; 
%put ArmVar = &ArmVar.; 
%put AgeVar = &AgeVar.; 
%put SexVar = &SexVar.; 
%put CountryVar = &CountryVar.; 
%put RaceVar = &RaceVar.; 
%put EthnicVar = &EthnicVar.; 
%put ExTrtVar = &ExTrtVar.;
%put ExVisitVar = &ExVisitVar.;
%put ExStdtcVar = &ExStdtcVar.;
%put PcstresnVar = &PcStresnVar.; 
%put PcVisitVar = &PcVisitVar.; 
%put PctptnumVar = &PctptnumVar.; 
%put PpstresnVar = &PpstresnVar.; 
%put PpVisitVar = &PpVisitVar.; 
%put PpcatVar = &PpcatVar.; 
%put PptestcdVar = &PptestcdVar.; 

%mend SmReadMappingsFromDb;
