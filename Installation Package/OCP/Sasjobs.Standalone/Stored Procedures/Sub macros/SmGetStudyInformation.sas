%macro SmGetStudyInformation(
	InputDm = ,
	SexVar = ,
	InputGroup = ,
	InputEx = ,
	StudyDesign = ,
	Id = ,
	StudyCode = 
);

%** Macro variables **;
%local SexSummary TrtGroupSummary;

%** Get the Number of Males and Females **;
%if %sysfunc(exist(&InputDm.)) and &SexVar. ne %then %do;
	proc freq data = &InputDm. noprint;
		tables &SexVar / list missing out = &work.sex;
	run;

	%** Handle different ways of presenting the gender **;
	data &work.sex;
		set &work.sex;
		if substr(&SexVar.,1,1) in ("W", "F") then do;
			sort1 = 2;
		end;
		else do;
			sort1 = 1;
		end;
	run;

	proc sort data = &work.sex;
		by sort1;
	run;

	%** Output the counts into the macro variable SexSummary **;
	data _null_;
		set &work.sex end = eof;
		by sort1;
		length countstr $10.;
		retain countstr;
		
		if _n_ = 1 then do;
			countstr = put(count, 8.);
		end;
		else do;
			countstr = cats(countstr, "/", put(count, 8.));
		end;

		if eof then do;
			call symputx("SexSummary", countstr);
		end;
	run;
%end;
%else %do;
	%let SexSummary = Not Available;
%end;

%** Treatment Groups **;
%if %sysfunc(exist(&InputGroup.)) %then %do;
	proc sort data = &InputGroup.;
		by CohortNumber CohortDescription;
	run;

	data _null_;
		set &InputGroup. end = eof;
		by CohortNumber CohortDescription;
		length trtgroups $500.;
		retain trtgroups;

		if _n_ = 1 then do;
			trtgroups = strip(CohortDescription);
		end;
		else if first.CohortNumber then do;
			trtgroups = strip(trtgroups) || "|#|" || strip(CohortDescription);
		end;

		if eof then do;
			call symputx("TrtGroupSummary", trtgroups);
		end;
	run;
%end;
%else %do;
	%let TrtGroupSummary = Not Available;
%end;

%** Class dataset **;
data &work.info_group_&Id.;
	length desc study_&id. $32. value_&id. $500.;

	study_&id. = "&StudyCode.";
	descnum = 1;
	desc = "Design";
	value_&id. = "&StudyDesign.";
	output;

	descnum = 2;
	desc = "Number of Subjects (M/F)";
	value_&id. = "&SexSummary.";
	output;

	descnum = 3;
	desc = "Treatment Groups";
	value_&id. = "&TrtGroupSummary.";
	output;

	descnum = 4;
	desc = "Dose Frequency";
	value_&id. = "";
	output;

	descnum = 5;
	desc = "Dosage";
	value_&id. = "";
	output;

	descnum = 6;
	desc = "Treatment Duration";
	value_&id. = "";
	output;
run;

%mend;

