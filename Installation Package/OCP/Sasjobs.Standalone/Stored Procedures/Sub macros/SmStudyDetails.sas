%macro SmStudyDetails(
		Input = ,
		PeriodVar = ,
		SequenceVar = ,
		TimeVar = ,
		AnalyteVar = ,
		ParameterVar = ,
		Type = ,
		Id = ,
		StudyArea = ,
		StudyTypeKnown =
);

%** Macro variables **;
%local i j;
%global ProgressGo Reference;

%*********************************************************;
%**														**;
%**				Period and sequences 					**;
%**														**;
%*********************************************************;

%** Modify the analysis dataset to show periods and handle analytes with groups in **;
data &Input.;
	set &Input.;

	%** Keep the original periods **;
	OriginalPeriod = &PeriodVar.;

	%** Define the pattern of interest **;
	if _n_ = 1 then do;
		pattern_per = prxparse("/PERIOD.*?(\d+)/");
		pattern_day = prxparse("/DAY.*?(\d+)/");
		pattern_shortper = prxparse("/P.*?(\d+)/");
		pattern_shortday = prxparse("/D.*?(\d+)/");
	end;
	retain pattern_per pattern_day pattern_shortper pattern_shortday;

	%** If both days and period are present - only extract the period **;
	if (index(upcase(&PeriodVar.), "PERIOD") and index(upcase(&PeriodVar.), "DAY")) or index(upcase(&PeriodVar.), "PERIOD") then do;
		if prxmatch(pattern_per, upcase(strip(&PeriodVar.))) then do;
			&PeriodVar. = "PERIOD " || prxposn(pattern_per, 1, upcase(strip(&PeriodVar.)));
			/*&PeriodVar.Num = input(prxposn(pattern_per, 1, upcase(strip(&PeriodVar.))), 8.);*/
			&PeriodVar.Num = input(scan(&PeriodVar., -1), 8.);
		end;
	end;
	else if (index(upcase(&PeriodVar.), "P") and index(upcase(&PeriodVar.), "D")) or index(upcase(&PeriodVar.), "P") then do;
		if prxmatch(pattern_shortper, upcase(strip(&PeriodVar.))) then do;
			&PeriodVar. = "PERIOD " || prxposn(pattern_shortper, 1, upcase(strip(&PeriodVar.)));
			&PeriodVar.Num = input(prxposn(pattern_shortper, 1, upcase(strip(&PeriodVar.))), 8.);
		end;
		else if prxmatch(pattern_day, upcase(strip(&PeriodVar.))) then do;
			&PeriodVar. = "DAY " || prxposn(pattern_day, 1, upcase(strip(&PeriodVar.)));
			&PeriodVar.Num = input(prxposn(pattern_day, 1, upcase(strip(&PeriodVar.))), 8.);
		end;
	end;
	%** Extract the day **;
	else if index(upcase(&PeriodVar.), "DAY") then do;
		if prxmatch(pattern_day, upcase(strip(&PeriodVar.))) then do;
			&PeriodVar. = "DAY " || prxposn(pattern_day, 1, upcase(strip(&PeriodVar.)));
			&PeriodVar.Num = input(prxposn(pattern_day, 1, upcase(strip(&PeriodVar.))), 8.);
		end;
	end;
	else if index(upcase(&PeriodVar.), "D") then do;
		if prxmatch(pattern_day, upcase(strip(&PeriodVar.))) then do;
			&PeriodVar. = "DAY " || prxposn(pattern_shortday, 1, upcase(strip(&PeriodVar.)));
			&PeriodVar.Num = input(prxposn(pattern_shortday, 1, upcase(strip(&PeriodVar.))), 8.);
		end;
	end;
	%** If everything fails then just report what is already there **;
	else do;
		&PeriodVar. = strip(&PeriodVar.);
	end;

	%** Handle strange analytes where groups/periods are included (simple case) **;
	idx_max = max(index(upcase(&AnalyteVar.), "PERIOD"),  index(upcase(&AnalyteVar.), "DAY"), index(upcase(&AnalyteVar.), "GROUP"), index(upcase(&AnalyteVar.), "TRT"));
	if idx_max then do;
		if idx_max then do;
			&AnalyteVar. = scan(&AnalyteVar., -1, "_-/\");
		end;
		else do;
			&AnalyteVar. = scan(&AnalyteVar., 1, "_-/\");
		end;
	end;
	else do;
		%** Handle strange analytes where groups/periods are included (triggy case - need regex in the future) **;
		if upcase(substr(&AnalyteVar., 1, 6)) = "PERIOD" then do;
			&AnalyteVar. = scan(&AnalyteVar., -1, "_-/\");
		end;
		else if upcase(substr(&AnalyteVar., 1, 3)) in ("DAY", "TRT") then do;
			&AnalyteVar. = scan(&AnalyteVar., -1, "_-/\");
		end;		
		else if upcase(substr(&AnalyteVar., 1, 5)) = "GROUP" then do;
			&AnalyteVar. = scan(&AnalyteVar., -1, "_-/\");
		end;
	end;

	%** Clean-up **;
	drop pattern_: idx_;
run;

%** Combine periods if need be (only needed for concentration data) **;
%if %upcase(&Type.) = PC %then %do;
	%** In some cases the time points are reported as continouse values while in fact they are in larger intervals (NUM = 1, 2, 3 CHAR = 1h, 4h, 12h) **;
	%** Check if PCTPT exist - if it does continue processing **;
	data _null_;
		set &Input.(obs = 1) end = eof;
		array c{*} _CHARACTER_;
		do i = 1 to dim(c);
			if vname(c{i}) = "PCTPT" then do;
				tpt_char = 1;
				call symputx("pctpt_exist", tpt_char);
			end;
		end;
	run;

	%** Use the character version of tpt to get the right numbering **;
	%if %symexist(pctpt_exist) %then %do;
		data &Input.;
			set &Input.;

			%** Setup the regular expression (content structure: PT12H30M, PT0H15M) **;
			if _N_ = 1 then do;
				retain patternid;
				pattern = "/(\d+)\s(H*)\s(\d*)\s(M*)/";
				patternid = prxparse(pattern);
			end;

			%** Array to contain the results **;
			%** {1} = Hour, {2} = Hour unit, {3} = Minutes, {4} = Minute unit **;
			array match{4} $8.;

			%** Apply the regular expression and insert it into the match array **;
			if prxmatch(patternid, PCTPT) ^= 0 then do;
				do i = 1 to prxparen(patternid);
					call prxposn(patternid, i, start, length);
					if start ^= 0 and length ^= 0 then do;
						match{i} = substr(PCTPT, start, length);
					end;
				end;
			end;

			%** Create a nummeric reprentation of the specify variable**;
			%** Pre-dose **;
			label NOM_TIME = "Nominal Time Point (H)";
			if index(PCTPT, "PRE") or index(PCTPT, "-PT") then do;
				NOM_TIME = 0;
			end;
			%** Only got hour information **;
			else if match{2} ^= "" and match{4} = "" then do;
				NOM_TIME = input(match{1},8.);
			end;
			%** Hour and minutes present (minutes represented as fraction of 60 minutes) **;
			else if match{2} ^= "" and match{4} ^= "" then do;
				NOM_TIME = input(cats(match{1}, ".", scan(round(input(match{3}, 8.) / 60, 0.01), -1, ".")), 8.);
			end;

			drop pattern patternid i start length match:;
		run;

		%** Check whether there is a mismatch between PCTPT and PCTPTNUM **;
		proc sort data = &Input. out = &work.mismatch nodupkey;
			by descending &TimeVar.;
		run;

		data _null_;
			set &work.mismatch (obs = 1);
			if &TimeVar. > NOM_TIME and NOM_TIME ne . then do;
				call symputx("TimeVar", "NOM_TIME", "G");
			end;
		run;
		%put Debug TimeVar = &TimeVar.;
	%end;

	%** Count the number of periods per time point per sequence **;
	proc freq data = &Input. noprint;
		tables &SequenceVar.*&PeriodVar.Num*&PeriodVar.*&TimeVar. / list missing out = &work.periods_&Type._&Id._(drop = percent);
	run;

	%** Group the periods **;
	data &work.periods_&Type._&Id.;
		set &work.periods_&Type._&Id._;
		by &SequenceVar. &PeriodVar.Num &PeriodVar. &TimeVar.;
		retain _&PeriodVar. PreValue;

		%** Remove redundant info **;
		if first.&PeriodVar. eq last.&PeriodVar. and PreValue >= &TimeVar. and &TimeVar. < 5 then do;
			delete;
		end;

		if first.&SequenceVar. then do;
			PreValue = &TimeVar.;
			_&PeriodVar. = &PeriodVar.;
		end;
		else do;
			if PreValue > &TimeVar. and first.&PeriodVar.Num ne last.&PeriodVar.Num then do;
				_&PeriodVar. = &PeriodVar.;
			end;
		end;
		PreValue = &TimeVar.;
	run;

	%** Merge the periods with the input dataset **;
	proc sort data = &Input.;
		by &SequenceVar. &PeriodVar.;
	run;

	proc sort data = &work.periods_&Type._&Id.;
		by &SequenceVar. &PeriodVar.;
	run;

	data &Input.(rename = (&PeriodVar. = _temp_ _&PeriodVar. = &PeriodVar.));
		merge	&Input.(in = a)
				&work.periods_&Type._&Id.(in = b);
		by &SequenceVar. &PeriodVar.;
		if a and b;

		%** Clean-up **;
		keep &UsubjidVar. &PeriodVar. &SequenceVar. &AnalyteVar. &TimeVar. &ResultPcVar. _&PeriodVar.;
	run;
	
%end;
%** Clear any unwanted sequences (only for Parameters) **;
%else %if %upcase(&Type.) = PP %then %do;

	%** Clean-up any unwanted sequences (Screening / Follow-up) **;
	data &Input.;
		set &Input.;

		%** Anything called screen / screening present? **;
		if index(upcase(&SequenceVar.), "SCREENING") then do;
			%** Identify potential separators right after Screening **;
			loc_scr = index(upcase(&SequenceVar.), "SCREENING");
			sep_scr = compress(substr(&SequenceVar., loc_scr + 9, 2));

			%** Identify the separator **;
			if index(sep_scr, ":") then do;
				sep_scr = ":";
			end;
			else if index(sep_scr, ";") then do;
				sep_scr = ";";
			end;
			else if index(sep_scr, "/") then do;
				sep_scr = "/";
			end;
			else if index(sep_scr, "-") then do;
				sep_scr = "-";
			end;
			else if index(sep_scr, "&") then do;
				sep_scr = "&";
			end;
			else if index(sep_scr, "+") then do;
				sep_scr = "+";
			end;

			%** Remove information from the separtor and forward **;
			&SequenceVar. = substr(&SequenceVar., index(&SequenceVar., strip(sep_scr)) + 1);
		end;
		%** Anything called Follow-up / Follow up present? **;
		if index(upcase(&SequenceVar.), "FOLLOW-UP") or index(upcase(&SequenceVar.), "FOLLOW UP") then do;
			%** Identify potential separators right before Follow-Up **;
			if index(upcase(&SequenceVar.), "FOLLOW-UP") then do;
				loc_fu = index(upcase(&SequenceVar.), "FOLLOW-UP");
				sep_fu = compress(substr(&SequenceVar., loc_fu - 2, 2));
			end;
			else do;
				loc_fu = index(upcase(&SequenceVar.), "FOLLOW UP");
				sep_fu = compress(substr(&SequenceVar., loc_fu - 2, 2));
			end;

			%** Identify the separator **;
			if index(sep_fu, ":") then do;
				sep_fu = ":";
			end;
			else if index(sep_fu, ";") then do;
				sep_fu = ";";
			end;
			else if index(sep_fu, "/") then do;
				sep_fu = "/";
			end;
			else if index(sep_fu, "-") then do;
				sep_fu = "-";
			end;
			else if index(sep_fu, "&") then do;
				sep_fu = "&";
			end;
			else if index(sep_fu, "+") then do;
				sep_fu = "+";
			end;

			%** Remove the information from the separator and onwards **;
			if index(upcase(&SequenceVar.), "FOLLOW-UP") then do;
				_temp_ = strip(substr(&SequenceVar., 1, index(&SequenceVar., scan(&SequenceVar., -2, strip(sep_fu)))-1));
				&SequenceVar. = substr(_temp_, 1, length(_temp_) - 1);
			end;
			else do;
				_temp_ = strip(substr(&SequenceVar., 1, index(&SequenceVar., scan(&SequenceVar., -1, strip(sep_fu)))));
				&SequenceVar. = substr(_temp_, 1, length(_temp_) - 1);
			end;
		end;

		%** Remove leading and trailing blanks **;
		&SequenceVar. = strip(&SequenceVar.);

		%** Clean-up **;
		drop _t: sep_: loc_: ;
		keep &UsubjidVar. &PeriodVar. &SequenceVar. &AnalyteVar. &ParameterVar. &ResultPpVar.;
	run;
%end;

%** Get the different Periods and Sequences **;
proc sort data = &Input. (keep = &SequenceVar. &PeriodVar.)
			out = &work.periods_&Type._&Id. nodupkey;
	by &SequenceVar. &PeriodVar.;
run;

proc sort data = &Input. (keep = &SequenceVar.)
			out = &work.sequences_&Type._&Id. nodupkey;
	by &SequenceVar.;
run;

%** Find the number of periods and sequences and put them in a macro variable **;
%global MaxNumberOfPeriods MinNumberOfPeriods NumberOfSequences;

%** Find the maximum number of periods within each cohort **;
data &work._null_;
	set &work.periods_&Type._&Id. end = eof;
	by &SequenceVar. &PeriodVar.;
	retain MinNumberOfPeriods MaxNumberOfPeriods counter;

	%** Initialize **;
	if _n_ = 1 then do;
		MaxNumberOfPeriods = 0;
		MinNumberOfPeriods = 99;
	end;
	if first.&SequenceVar. then do;
		counter = 0;
	end;
		
	%** Count and compare **;
	counter + 1;
	if last.&SequenceVar. then do;
		if MaxNumberOfPeriods < counter then do;
			MaxNumberOfPeriods = counter;
		end;
		if MinNumberOfPeriods > counter then do;
			MinNumberOfPeriods = counter;
		end;
	end;

	%** Create the macro variable **;
	if eof then do;
		call symputx("MaxNumberOfPeriods", MaxNumberOfPeriods);
		call symputx("MinNumberOfPeriods", MinNumberOfPeriods);
	end;
run;
%** Debug **;
%put Maximum number of Periods = &MaxNumberOfPeriods.;
%put Minimum number of Periods = &MinNumberOfPeriods.;

%** Find the number of unique sequences **;
proc sql noprint;
	select distinct
		&SequenceVar.
	into:
		SequenceList separated by "~!~"
	from
		&work.sequences_&Type._&Id.
	;
quit;
%let NumberOfSequences = %sysfunc(countw(&SequenceList., ~!~));

%** Debug **;
%put Number of Sequences = &NumberOfSequences.;

%*********************************************************;
%**														**;
%** 			Separator identification				**;
%**														**;
%*********************************************************;

%** Find what separator to use **;
%let Separator = ;
%let HitList = ;
%let HitCount = ;
%if %upcase(&StudyArea.) ne INTRINSIC %then %do i = 1 %to &NumberOfSequences.;
	%** Get the next in line **;
	%let CurrentSequence = %scan(%quote(&SequenceList.), &i., ~!~);

	%** Debug **;
	%put CurrentSequence: &CurrentSequence.;

	%** Count the number of occurence of each of the separator **;
	%let NumberOfColon 		= %sysfunc(count(%quote(&CurrentSequence.), %str(:)));
	%let NumberOfSemiColon 	= %sysfunc(count(%quote(&CurrentSequence.), %str(;)));
	%let NumberOfSlash 		= %sysfunc(count(%quote(&CurrentSequence.), %str(/)));
	%let NumberOfDash 		= %sysfunc(count(%quote(&CurrentSequence.), %str(-)));
	%let NumberOfAmpersand	= %sysfunc(count(%quote(&CurrentSequence.), %str(&)));
	%let NumberOfPluses		= %sysfunc(count(%quote(&CurrentSequence.), %str(+)));

	%** Debug **;
	%put NumberOfColon = &NumberOfColon.;
	%put NumberOfSemiColon = &NumberOfSemiColon.;
	%put NumberOfSlash = &NumberOfSlash.;
	%put NumberOfDash = &NumberOfDash.;
	%put NumberOfAmpersand = &NumberOfAmpersand.;
	%put NumberOfPluses = &NumberOfPluses.;

	%** Helper macro variables **;
	%let SeparatorListFull = &NumberOfColon.~!~&NumberOfSemiColon.~!~&NumberOfSlash.~!~&NumberOfDash.~!~&NumberOfAmpersand.~!~&NumberOfPluses.;
	%let SeparatorList = %str(:)~!~%str(;)~!~%str(/)~!~%str(-)~!~%str(+)~!~%str(&);
	%let NumberOfSeparators = %eval(&MaxNumberOfPeriods. - 1);

	%if %eval(&NumberOfColon. + &NumberOfSemiColon. + &NumberOfSlash. + &NumberOfDash. + &NumberOfPluses. + &NumberOfAmpersand.) ^= 0 %then %do;
		%do j = 1 %to 6;
			%if %scan(&SeparatorListFull., &j., ~!~) = &NumberOfSeparators. %then %do;
				%if %nrbquote(&HitList.) eq %then %do;
					%let HitList = %scan(&SeparatorList., &j., ~!~);
					%let HitCount = %eval(&HitCount + 1);
				%end;
			%end;
		%end;

		%** If there is only one match then use that as the separator **;
		%if &HitCount. = 1 %then %do;
			%let Separator = &HitList.;
		%end;
	%end;
	%else %if &Separator. eq %then %do;
		%let Separator = ;
	%end;
%end;

%** Additional checks to ensure that separators are indeed present (might not always be the case) **;
data _null_;
	set &work.sequences_&Type._&Id. end = eof;
	if count(&SequenceVar., "&Separator.") then do;
		counter + 1;
	end;

	if eof then do;
		if counter < (&NumberOfSequences. - 1) then do;
			call symputx("Separator", "");
		end;
	end; 

	drop counter;
run;

%** Debug **;
%put Separator is: &Separator.;

%*********************************************************;
%**														**;
%** 					Cohorts							**;
%**														**;
%*********************************************************;
%if &MaxNumberOfPeriods. >= 2 and &NumberOfSequences. > 1 and %quote(&Separator.) ne %then %do;		
	%** Using the separator identify the different components **;
	%let UniqueSequences = ;
	%let hit = 0;
	%** Loop for all sequences **;
	%do i = 1 %to &NumberOfSequences.;

		%** Loop for all treatments within the sequence **;
		%let CurrentSequence = %scan(%quote(&SequenceList.), &i., ~!~);
		%put Current Sequence = &CurrentSequence.;
		%do j = 1 %to %sysfunc(countw(%quote(&CurrentSequence.), &Separator.));

			%** Is the treatment already in the list? **;
			%let CurrentTreatment = %scan(%quote(&CurrentSequence.), &j., &Separator.);
			%put Current Treatment = &CurrentTreatment.;
			%if %nrbquote(&UniqueSequences.) ne %then %do;
				%let k = 0;
				%let hit = 0;
				%do %until(&k. = %sysfunc(countw(%quote(&UniqueSequences.),~!~)));
					%** Match found! **;
					%if %nrbquote(&CurrentTreatment.) eq %nrbquote(%scan(%nrbquote(&UniqueSequences.), %eval(&k.+1), ~!~)) %then %do;
						%let hit = 1;
					%end;
					%let k = %eval(&k. + 1);
				%end;

				%** If not add it **;
				%if &hit. = 0 %then %do;
					%let UniqueSequences = &UniqueSequences.~!~&CurrentTreatment.;
				%end;
			%end;
			%** If not add it **;
			%else %do;
				%let UniqueSequences = &CurrentTreatment.;
			%end;
		%end;
	%end;
	%let NumberOfUniqueSequences = %sysfunc(countw(%quote(&UniqueSequences.),~!~));

	%** Debug **;
	%put Final Unique Sequences = &UniqueSequences.;

	%** Identify how many different groups / cohorts there really are **;
	%** Each sequences gets a numeric value and the number of distinct values is the number of cohorts **;
	%** Loop for all sequences **;
	data &work.groups_&Type._&Id.;
		set &work.sequences_&Type._&Id.;
		length UniqueSequences $500.;
		UniqueSequences = "&UniqueSequences.";

		%** Count the unique cohort number **;
		counter = 0;
		do i = 1 to &NumberOfUniqueSequences.;
			do j = 1 to countw(&SequenceVar., "&Separator.");
				if strip(scan(UniqueSequences, i, "~!~")) = strip(scan(&SequenceVar., j, "&Separator.")) then do;
					counter + i;
				end;
			end;
		end;
		
		%** Clean - up **;
		drop i j;
	run;

	%** Sort **;
	proc sort data = &work.groups_&Type._&Id.;
		by counter &SequenceVar.;
	run;

	%** Create a unique Cohort Number, Name and Description**;
	data &work.groups_&Type._&Id.;
		set &work.groups_&Type._&Id.;
		by counter &SequenceVar.;
		retain CohortNumber CohortName CohortDescription;

		%** Assign **;
		if first.counter then do;
			CohortNumber + 1;
			CohortName = "Cohort " || strip(CohortNumber);
			CohortDescription = &SequenceVar.;
		end;

		%** Clean-up **;
		drop counter;
	run;
%end;
%else %do;
	%** Sort **;
	proc sort data = &work.sequences_&Type._&Id.
				out = &work.groups_&Type._&Id.;
		by &SequenceVar.;
	run;

	%** Create a unique Cohort Number, Name and Description **;
	data &work.groups_&Type._&Id.;
		set &work.groups_&Type._&Id.;
		by &SequenceVar.;
		retain CohortNumber CohortName CohortDescription;

		%** Assign **;
		if first.&SequenceVar. then do;
			CohortNumber + 1;
			CohortName = "Cohort " || strip(CohortNumber);
			CohortDescription = &SequenceVar.;
		end;
	run;
%end;

%** Add cohorts and log transform the results **;
proc sort data = &Input.;
	by &SequenceVar.;
run;

proc sort data = &work.groups_&Type._&Id.;
	by &SequenceVar.;
run;

data &Input.(drop = _t:);
	merge	&Input.(in = a)
			&work.groups_&Type._&Id.(in = b);
	by &SequenceVar.;
	if a;
run;

%** Save the number of cohorts in a macro variable **;
proc sql noprint;
	select 
		max(CohortNumber)
	into
		:NumberOfCohorts
	from
		&Input.
	;
quit;

%** Debug **;
%put Number of Groups = &NumberOfCohorts.;

%*********************************************************;
%**														**;
%**					Study design 						**;
%**														**;
%*********************************************************;

%if %upcase(&StudyTypeKnown.) eq %then %do;
	%** Define the study design as a global macro variable **;
	%global StudyDesign;

	%put Study Area = &StudyArea.;
	%** If the study type is intrinsic - it is safe to assume that we can only have a parallel study **;
	%if %upcase(&StudyArea.) = INTRINSIC %then %do;
		%if &NumberOfSequences. > 1 and &MaxNumberOfPeriods. = 1 %then %do;
			%let StudyDesign = Parallel;
		%end;
		%else %if &MinNumberOfPeriods. = 1 and &MaxNumberOfPeriods. > 1 %then %do;
			%let StudyDesign = ParallelSequential;
		%end;
		%else %do;
			%let StudyDesign = Parallel;
		%end;
	%end;
	%else %if %upcase(&StudyArea.) = EXTRINSIC %then %do;
		%if &NumberOfSequences. > &NumberOfCohorts. %then %do;
			%let StudyDesign = Crossover;
		%end;
		%else %if &NumberOfSequences. = &NumberOfCohorts. %then %do;
			%let StudyDesign = Sequential;
		%end;
		%else %do;
			%let StudyDesign = Unknown;
		%end;
	%end;
	%else %do;
		%let StudyDesign = ;
		%put ERROR: Study design not supported yet;
	%end;

	%put Study design is: &StudyDesign.;
%end;

%*********************************************************;
%**														**;
%**					Comparisons 						**;
%**														**;
%*********************************************************;
%let ProgressGo = success;
%if %upcase(&StudyArea.) = EXTRINSIC %then %do;
	%** For Crossover studies the treatment changes depending on the period **;
	proc sort data = &Input.;
		by &UsubjidVar. &SequenceVar. &PeriodVar.;
	run;

	data &Input.;
		length TreatmentInPeriodText TreatmentInPeriod $200.;
		set	&Input.;
		by &UsubjidVar. &SequenceVar. &PeriodVar.;
		retain split;

		if first.&UsubjidVar. then do;
			split = 0;
		end;
		if first.&PeriodVar. then do;
			split + 1;	
		end;

		if scan(&SequenceVar., split, "&Separator.") = &SequenceVar. or scan(&SequenceVar., split, "&Separator.") = "" then do;
			TreatmentInPeriodText = strip(&PeriodVar.);
		end;
		else do;
			TreatmentInPeriodText = strip(scan(&SequenceVar., split, "&Separator."));
		end;
		TreatmentInPeriodLength = length(strip(TreatmentInPeriodText));
		TreatmentInPeriod = put(TreatmentInPeriodLength, z4.) || "_" || strip(TreatmentInPeriodText);
	run;

	%** Create the possible comparisions **;
	proc sort data = &Input.;
		%if %upcase(&Type.) = PC %then %do;
			by &UsubjidVar. &AnalyteVar. &PeriodVar. &TimeVar.;
		%end;
		%else %do;
			by &UsubjidVar. &ParameterVar. &AnalyteVar. TreatmentInPeriod &PeriodVar.;
			*fixme: recent change;
			*by &UsubjidVar. &ParameterVar. &AnalyteVar. &PeriodVar.;
		%end;
	run;

	data &work.combinations_&i._&j.;
		set &Input.;
		%if %upcase(&Type.) = PC %then %do;
			by &UsubjidVar. &AnalyteVar. &PeriodVar. &TimeVar.;
		%end;
		%else %do;
			by &UsubjidVar. &ParameterVar. &AnalyteVar. TreatmentInPeriod &PeriodVar.;
			*fixme: recent change - added to avoid crossover studies generating comparison that didnt exist;
			*fixme: A - B, B - A created A vs B and B vs A - thus no pair;
			*by &UsubjidVar. &ParameterVar. &AnalyteVar. &PeriodVar.;
		%end;
		length Combination $200.;
		retain Combination;

		if first.&AnalyteVar. then do;
			Combination = strip(TreatmentInPeriodText);
		end;
		else if not index(Combination, "~vs~") and first.&PeriodVar. then do;
			if length(Combination) > length(TreatmentInPeriodText) then do;
				Combination = strip(TreatmentInPeriodText) || " ~vs~ " || strip(Combination);
			end;
			else do;
				Combination = strip(Combination) || " ~vs~ " || strip(TreatmentInPeriodText);
			end;
		end;

		%if %upcase(&Type.) = PC %then %do;
			if last.&PeriodVar. and findw(Combination, "~vs~") then do;
				output;
			end;

			keep &UsubjidVar. &AnalyteVar. Combination;
		%end;
		%else %do;
			if last.&AnalyteVar. and findw(Combination, "~vs~") then do;
				output;
			end;

			keep &UsubjidVar. &ParameterVar. &AnalyteVar. Combination;
		%end;
	run;

	%** If rare cases no combinations can be found - so use visit as a combination **;
	%SmGetNumberOfObs(Input = &work.combinations_&i._&j.);
	%if &NumberOfObs. = 0 %then %do;
		proc sort data = &Input.;
			by &UsubjidVar. &PeriodVar.;
		run;

		data &work.combinations_&i._&j.;
			set &Input.;
			by &UsubjidVar. &PeriodVar.;
			length Combination $200.;
			retain Combination;

			if first.&UsubjidVar. then do;
				Combination = strip(&PeriodVar.);
			end;
			else if not index(Combination, "~vs~") and first.&PeriodVar. then do;
				if length(Combination) > length(&PeriodVar.) then do;
					Combination = strip(&PeriodVar.) || " ~vs~ " || strip(Combination);
				end;
				else do;
					Combination = strip(Combination) || " ~vs~ " || strip(&PeriodVar.);
				end;
			end;

			if last.&UsubjidVar. and findw(Combination, "~vs~") then do;
				output;
			end;

			keep &UsubjidVar. Combination;
		run;
	%end;

	%** Merge with the input dataset **;
	data &Input.;
		merge	&Input. (in = a)
				&work.combinations_&i._&j. (in = b);
		%if %upcase(&Type.) = PC and &NumberOfObs. >= 1 %then %do;
			by &UsubjidVar. &AnalyteVar.;
		%end;
		%else %if %upcase(&Type.) = PP and &NumberOfObs. >= 1 %then %do;
			by &UsubjidVar. &ParameterVar. &AnalyteVar.;
		%end;
		%else %do;
			by &UsubjidVar.;
		%end;

		if a;
	run;
%end;
%else %if %upcase(&StudyArea) = INTRINSIC and &NumberOfCohorts. > 1 %then %do;
	%** Is one of the treatment a reference? **;
	data _null_;
		set &Input.;

		if indexw(upcase(strip(&SequenceVar.)), "HEALTHY") or indexw(upcase(strip(&SequenceVar.)), "NORMAL") then do;
			call symputx("reference", &SequenceVar.);
			stop;
		end;
	run;

	%if %symexist(reference) %then %do;
		%** Debug **;
		%put Reference Treatment = &reference.;

		%** Get the treatments that are not references **;
		proc sql noprint;
			select distinct
				&SequenceVar.
			into:
				arm_list separated by "@"
			from
				&Input.(where = (&SequenceVar. ^= "&reference."))
			;
		quit;

		%** Debug **;
		%put Non-reference arms = &arm_list.;
		
		%** For the treatments add the comparison variables **;
		data &Input.;
			length Combination CohortName CohortDescription TreatmentInPeriodText TreatmentInPeriod $200.;
			set &Input.;
			CohortNumber = 1;
			CohortName = "Cohort";
			CohortDescription = CohortName;
			Combination = "&reference." || " ~vs~ All Arms";
			TreatmentInPeriodText = &SequenceVar.;
			TreatmentInPeriodLength = length(strip(TreatmentInPeriodText));
			TreatmentInPeriod = strip(TreatmentInPeriodLength) || "_" || strip(TreatmentInPeriodText);
		run;
	%end;
	%else %do;
		%** Get the different treatments **;
		proc sql noprint;
			select distinct
				&SequenceVar.
			into
				:arm_list separated by "@"
			from
				&Input.
			;
		quit;
		%put ARM LIST EQUAL TO: &arm_list.;

		%** For all compinations create the comparisons **;
		data &Input.;
			length Combination $200.;
			set &Input.;
			%do i = 1 %to %sysfunc(countw(%nrbquote(&arm_list.), @));
				%do j = 1 %to %sysfunc(countw(%nrbquote(&arm_list.), @));
				%put monkey1 = %scan(%nrbquote(&arm_list.), &i., @);
				%put monkey2 = %scan(%nrbquote(&arm_list.), &j., @);
					%if %nrbquote(%scan(%nrbquote(&arm_list.), &i., @)) ne %nrbquote(%scan(%nrbquote(&arm_list.), &j., @)) %then %do;
						CohortNumber = 1;
						CohortName = "Cohort";
						CohortDescription = CohortName;
						Combination = "%scan(%quote(&arm_list.), &i., @)" || " ~vs~ " || "%scan(%quote(&arm_list.), &j., @)";
						TreatmentInPeriodText = &SequenceVar.;
						TreatmentInPeriodLength = length(strip(TreatmentInPeriodText));
						TreatmentInPeriod = strip(TreatmentInPeriodLength) || "_" || strip(TreatmentInPeriodText);
						output;
					%end;
				%end;
			%end;
		run;
	%end;
%end;
%else %do;
	%put ERROR: Generation of comparisons not possible. Check the data;
	%let ProgressGo = fail;
%end;

%mend;
