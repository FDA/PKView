libname tempdz ".\tempdz";

%let work = tempdz;
%let input = C:\Users\sorensenj\Desktop\PkWiz\All Studies;
%let output = .\;

options nofmterr compress = yes spool mprint sasautos = (sasautos ".\macros" ".\sub macros") notes linesize = max quotelenmax;

%macro GetMappingLeeAlgo(
	DmDs = ,
	UsubjidVar = ,
	SequenceVar = ,
	ExDs = ,
	ExTrtVar = ,
	ExDtcVar = ,
	PpDs = ,
	PeriodVar = ,
	AnalyteVar = 
);

%local i j k h l m;

%** Handle bad data in DM **;
data &DmDs.;
	set &DmDs.(where = (&SequenceVar. ne "SCREEN FAILURE"));

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

%** Get the unique sequences **;
proc sort data = &DmDs. (keep = &SequenceVar.) out = &work..sequences nodupkey;
	by &SequenceVar.;
run;

data _null_;
	set &work..sequences(where = (strip(&SequenceVar.) ne "SCREEN FAILURE")) end = eof;
	by &SequenceVar.;
	length sequence_list $800.;
	retain sequence_list;

	if _n_ = 1 then do;
		sequence_list = strip(&SequenceVar.);
	end;
	else do;
		sequence_list = strip(sequence_list) || " || " || strip(&SequenceVar.);
	end;

	if eof then do;
		call symputx("sequence_list", sequence_list, "G");
		call symputx("sequence_tot", _n_, "G");
	end;
run;
%put Debug = &sequence_list.;

%if &PeriodVar. ne %then %do;
	%** Get the unique periods **;
	proc sort data = &PpDs. (keep = &PeriodVar.) out = &work..periods nodupkey; 
		by &PeriodVar.;
	run;

	data _null_;
		set &work..periods end = eof;
		by &PeriodVar.;
		length period_list $800.;
		retain period_list;

		if _n_ = 1 then do;
			period_list = strip(&PeriodVar.);
		end;
		else do;
			period_list = strip(period_list) || " || " || strip(&PeriodVar.);
		end;

		if eof then do;
			call symputx("period_list", period_list, "G");
		end;
	run;
%end;
%** Check if exposure exists - if it does try to get the treatment sequence **;
%if %sysfunc(exist(&ExDs.)) %then %do;
	%** Pre-process EX to handle missing dates **;
	data &ExDs.;
		set &ExDs.;
		lagsubjid = lag(&UsubjidVar.);
		lagdate = lag(&ExDtcVar.);
	run;

	data &ExDs.;
		set &ExDs.;
		if strip(&ExDtcVar.) = "" and &UsubjidVar = lagsubjid then do;
			&ExDtcVar. = lagdate;
		end;
		
	run;

	%** Merge DM and EX **;
	proc sort data = &DmDs.(keep = &UsubjidVar. &SequenceVar.);
		by &UsubjidVar.;
	run;

	proc sort data = &ExDs. (keep = &UsubjidVar. &ExTrtVar. &ExDtcVar.);
		by &UsubjidVar.;
	run;

	data &work..w1;
		merge	&DmDs. (in = a)
				&ExDs. (in = b);
		by &UsubjidVar.;
		if a and b;

		%** Handle difficult data **;
		ExDate = scan(&ExDtcVar., 1, "T");

		%** See below **;
		cntvar = 1;
	run;

	%** How many entries per group **;
	proc summary data = &work..w1 nway missing;
		class &UsubjidVar. &SequenceVar. ;
		var cntvar;
		output out = &work..ex_sum1 (drop = _type_ _freq_) sum = sum_cnt;
	run;

	proc summary data = &work..ex_sum1 nway missing;
		class &SequenceVar.;
		var sum_cnt;
		output out = &work..ex_sum2 (drop = _type_ _freq_) mean = mean_cnt;
	run;

	%** Merge the two **;
	proc sort data = &work..ex_sum1;
		by &SequenceVar.;
	run;

	data &work..ex_sum3(drop = sum_cnt mean_cnt);
		merge	&work..ex_sum1(in = a)
				&work..ex_sum2(in = b);
		by &SequenceVar.;
		if a and b and sum_cnt >= mean_cnt/2;
	run;

	%** Do some rough clean-up to remove patients with too few exposures **;
	proc sort data = &work..w1(drop = cntvar);
		by &UsubjidVar. &SequenceVar.;
	run;

	proc sort data = &work..ex_sum3;
		by &UsubjidVar. &SequenceVar.;
	run;

	data &work..w1;
		merge	&work..w1 (in = a)
				&work..ex_sum3 (in = b);
		by &UsubjidVar. &SequenceVar.;
		if b;
	run;

	%** For each sequence determine the actual treatment **;
	proc sort data = &work..w1;
		by &SequenceVar. &UsubjidVar. ExDate &ExTrtVar.;
	run;

	%** Combine treatments on the same date **;
	data &work..w2;
		length trt_list prev_trt $800.;
		set &work..w1(keep = &UsubjidVar. &SequenceVar. &ExTrtVar. ExDate);
		by &SequenceVar. &UsubjidVar. ExDate;
		retain trt_list;

		prev_trt = lag(&ExTrtVar.);
		if first.&UsubjidVar. then do;
			prev_trt = "";
		end;

		if first.ExDate then do;
			trt_list = &ExTrtVar.;
		end;
		else if &ExTrtVar. ^= prev_trt then do;
			trt_list = strip(trt_list) || " + " || strip(&ExTrtVar.);
		end;

		if last.ExDate then do;
			output;
		end;
	run;

	%** Combine multiple days of treatment into one **;
	data &work..w3;
		set &work..w2;
		by &SequenceVar. &UsubjidVar.;
		length extrt_list $800.;
		retain CurrCnt;

		%** Add previous treatment in the sequence before **;
		prev_trt = lag(trt_list);
		if first.&UsubjidVar. then do;
			prev_trt = trt_list;
			cnt = 0;
		end;

		%** Find the unique treatments where S -> Single dose, M -> Multiple dose **;
		if trt_list = prev_trt then do;
			cnt + 1;
			CurrCnt = cnt;
		end;
		else if trt_list ^= prev_trt then do;
			cnt = 1;
			if CurrCnt > 1 then do;
				extrt_list = strip(prev_trt) || "_M";
			end;
			else do;
				extrt_list = strip(prev_trt) || "_S";
			end;
			CurrCnt = cnt;
			output;
		end;
		if last.&UsubjidVar. then do;
			if trt_list ^= prev_trt then do;
				extrt_list = strip(trt_list) || "_S";
				output;
			end;
			else if first.&UsubjidVar. = last.&UsubjidVar. then do;
				extrt_list = strip(trt_list) || "_S";
				output;
			end;
			else do;
				extrt_list = strip(trt_list) || "_M";
				output;
			end;
		end;
		
		%** Clean-up **;
		drop currcnt cnt &ExTrtVar. prev_trt trt_list;
	run;

	%** Create the extrt list (list of all unique treatment) **;
	%global ExTrt_list;
	proc sql noprint;
		select distinct
			extrt_list
		into
			:ExTrt_list separated by " @ "
		from
			&work..w3
		;
 	quit;

	%** Create the trtseq list (list unique treatments per arm) **;
	proc sort data = &work..w3 out = &work..w4 nodupkey;
		by &SequenceVar. extrt_list;
	run;

	data &work..w5;
		set &work..w4 end = eof;
		by &SequenceVar. extrt_list;
		length trtseq_list trtseq trtseq_list_orig trtseq_orig $800.;
		retain trtseq_list trtseq trtseq_list_orig trtseq_orig trtcnt;

		if first.&SequenceVar. then do;
			trtseq = strip(extrt_list);
			trtseq_orig = substr(strip(trtseq), 1, length(strip(extrt_list))-2);
			trtcnt = 1;
		end;
		else do;
			trtseq = strip(trtseq) || " @ " || strip(extrt_list);
			trtseq_orig = strip(trtseq_orig) || " @ " || substr(strip(extrt_list), 1, length(strip(extrt_list))-2);;
			trtcnt + 1;
		end;

		if last.&SequenceVar. then do;
			if TrtSeq_list ne "" then do;
				TrtSeq_list = strip(TrtSeq_list) || " || " || strip(trtseq);
				TrtSeq_list_orig = strip(TrtSeq_list_orig) || " || " || strip(trtseq_orig);
			end;
			else do;
				TrtSeq_list = strip(trtseq);
				TrtSeq_list_orig = strip(trtseq_orig);
			end;
			output;
		end;
		if eof then do;
			call symputx("TrtSeq_list", TrtSeq_list, "G");
			call symputx("TrtSeq_Num", trtcnt, "G");
			call symputx("TrtSeq_list_orig", TrtSeq_list_orig, "G");
		end;
	run;

	%** Get PTbyAllRegimentSession **;
	%let hit = 0;
	%let separator = @;
	%let UniqueSequences = ;
	%** Loop for all sequences **;
	%do i = 1 %to %sysfunc(countw(%nrbquote(&TrtSeq_list_orig.), ||));

		%** Loop for all treatments within the sequence **;
		%let CurrentSequence = %scan(%quote(&TrtSeq_list_orig.), &i., ||);
		%put Current Sequence = &CurrentSequence.;
		%do j = 1 %to %sysfunc(countw(%quote(&CurrentSequence.), &Separator.));

			%** Is the treatment already in the list? **;
			%let CurrentTreatment = %scan(%quote(&CurrentSequence.), &j., &Separator.);
			%put Current Treatment = &CurrentTreatment.;
			%if %nrbquote(&UniqueSequences.) ne %then %do;
				%let k = 0;
				%let hit = 0;
				%do %until(&k. = %sysfunc(countw(%quote(&UniqueSequences.),||)));
					%** Match found! **;
					%if %nrbquote(&CurrentTreatment.) eq %nrbquote(%scan(%nrbquote(&UniqueSequences.), %eval(&k.+1), ||)) %then %do;
						%let hit = 1;
					%end;
					%let k = %eval(&k. + 1);
				%end;

				%** If not add it **;
				%if &hit. = 0 %then %do;
					%let UniqueSequences = &UniqueSequences.||&CurrentTreatment.;
				%end;
			%end;
			%** If not add it **;
			%else %do;
				%let UniqueSequences = &CurrentTreatment.;
			%end;
		%end;
	%end;
	%let NumberOfUniqueSequences = %sysfunc(countw(%quote(&UniqueSequences.),||));	
	%put NumSeq = &NumberOfUniqueSequences., &UniqueSequences.;

	%** Identify how many groups there really are **;
	data &work..w9;
		set &work..w5;
		length UniqueSequences $500.;
		UniqueSequences = "&UniqueSequences.";

		%** Count the unique cohort number **;
		counter = 0;
		do i = 1 to &NumberOfUniqueSequences.;
			do j = 1 to countw(TrtSeq_orig, "&Separator.");
				TestA = strip(scan(UniqueSequences, i, "||"));
				TestB = strip(scan(TrtSeq_orig, j, "&Separator."));
				if strip(scan(UniqueSequences, i, "||")) = strip(scan(TrtSeq_orig, j, "&Separator.")) then do;
					counter + i;
				end;
			end;
		end;
		
		%** Clean - up **;
		drop i j;
	run;

	%** Create the regimine **;
	proc sort data = &work..w9;
		by counter TrtSeq_orig;
	run;

	data &work..w9;
		set &work..w9 end = eof;
		by counter TrtSeq_orig;
		length PTbyAllRegimentSession $40.;
		retain PTbyAllRegimentSession;

		%** Assign **;
		if first.counter then do;
			cnt + 1;
			if _n_ = 1 then do;
				PTbyAllRegimentSession = strip(cnt);
			end;
			else do;
				PTbyAllRegimentSession = strip(PTbyAllRegimentSession) || " || " || strip(cnt);
			end;
		end;

		if eof then do;
			call symputx("PTbyAllRegimentSession", PTbyAllRegimentSession, "G");
		end;
	run;

	%** Get PTbyRegimen and PtByAllTreatment **;
	proc sort data = &work..w5 out = &work..w6;
		by trtseq;
	run;

	data _null_;
		set &work..w6 end = eof;
		length ptbyalltreatment $800.;
		retain ptbyalltreatment cnt;
		by trtseq;

		if _N_ = 1 then do;
			cnt = 1;
			ptbyalltreatment = "1";
		end;
		else if first.trtseq then do;
			cnt + 1;
			ptbyalltreatment = strip(ptbyalltreatment) || " || " || strip(cnt);
		end;

		if eof then do;
			call symputx("ptbyalltreatment", ptbyalltreatment, "G");
		end;
	run;

	proc sort data = &work..w5 out = &work..w7;
		by &SequenceVar.;
	run;

	data _null_;
		set &work..w7 end = eof;
		length ptbyregimine $800.;
		retain ptbyregimine cnt;
		by &SequenceVar.;

		if _N_ = 1 then do;
			cnt = 1;
			ptbyregimine = "1";
		end;
		else if first.&SequenceVar. then do;
			cnt + 1;
			ptbyregimine = strip(ptbyregimine) || " || " || strip(cnt);
		end;

		if eof then do;
			call symputx("ptbyregimine", ptbyregimine, "G");
		end;
	run;

	%** Try to get the ARM Regimen **;
	proc sort data = &work..w3 out = &work..w10 nodupkey;
		by &SequenceVar. extrt_list;
	run;

	proc sort data = &work..w10;
		by &SequenceVar. ExDate;
	run;

	data &work..w11;
		set &work..w10 end = eof;
		by &SequenceVar. ExDate;
		length armregimen armregimen_list trtseq  $800.;
		retain armregimen armregimen_list trtseq;

		if first.&SequenceVar. then do;
			trtseq = strip(extrt_list);
			armregimen = substr(strip(trtseq), 1, length(strip(extrt_list))-2);
		end;
		else do;
			trtseq = strip(extrt_list);
			armregimen = strip(armregimen) || " @ " || substr(strip(extrt_list), 1, length(strip(extrt_list))-2);
		end;

		if last.&SequenceVar. then do;
			if armregimen_list ne "" then do;
				armregimen_list = strip(armregimen_list) || " || " || strip(armregimen);
			end;
			else do;
				armregimen_list = strip(armregimen);
			end;
			output;
		end;
		if eof then do;
			call symputx("armregimen", armregimen_list, "G");
		end;
	run;

	%** Try to get the Period Regimen **;
	data &work..w12;
		set &work..w10;
		by &SequenceVar.;
		retain sort1 sort2;

		if first.&SequenceVar then do;
			sort1 + 1;
			sort2 = 1;
		end;
		else do;
			sort2 + 1;
		end;
	run;

	proc sort data = &work..w12 out = &work..w13;
		by sort2 sort1;
	run;

	data &work..w14;
		set &work..w13 end = eof;
		by sort2 sort1;
		length curr_per per_list $800.;
		retain curr_per per_list;

		if first.sort2 then do;
			curr_per = substr(strip(extrt_list), 1, length(strip(extrt_list))-2);
		end;
		else do;
			curr_per = strip(curr_per) || " @ " || substr(strip(extrt_list), 1, length(strip(extrt_list))-2);
		end;
	
		if last.sort2 and per_list = "" then do;
			per_list = curr_per;
		end;
		else if last.sort2 then do;
			per_list = strip(per_list) || " || " || curr_per;
		end;

		if eof then do;
			call symputx("PeriodRegimen", per_list, "G");
		end;
	run;
%end;
%else %do;
	%let trtseq_list = ;
	%let extrt_list = ;
	%let ptbyregimine = ;
	%let ptbyalltreatment = ;
%end;

%mend;

%macro RunNewAlgorithm();

%** Clear the work folder **;
proc datasets library = &work. kill noprint;
run;

proc datasets library = work kill noprint;
run;


%** Read the folder structure **;
%SmListFilesInFolder(
	Path = &Input.,
	Out = &work..files
);

%** Generate a list of studies to loop over **;
data _null_;
	set &work..files(where = (path ^= "&Input.")) end = eof;
	length study_list $20000;
	retain study_list;

	if _n_ = 1 then do;
		study_list = strip(path);
	end;
	else do;
		study_list = strip(study_list) || "@" || strip(path);
	end;

	if eof then do;
		call symputx("study_list", study_list);
		call symputx("NumberOfStudies", _n_);
	end;
run;

%** Loop for each study **;
%do i = 1 %to &NumberOfStudies.;
	%put iter = &i;
	%** Clean-up **;
	%symdel UsubjidVar SequenceVar ExTrtVar ExDtcVar PeriodPpVar AnalytePpVar 
			ptbyregimine ptbyalltreatment Sequence_list ExTrt_list TrtSeq_list ExposureStatus Period_list
			TrtSeq_Num sequence_tot ArmRegimen PeriodRegimen
	;

	%** Identify the SDTM datasets **;
	%SmIdentifySdtmData(
		DatasetPath = %qscan(&study_list., &i., @)
	);

	%** Continnue if everything went okay **;
	%if %upcase(&ProgressGo.) = SUCCESS %then %do;
		%** 		DM 				**;
		%if %sysfunc(fileexist(&InputDm.)) %then %do;
			%** Read **;
			%SmReadAndMergeDataset(
				Input1 = &InputDm.,
				Output = &work..dm
			);

			%** Get the variables **;
			%SmGetColumnNames(
				Input = &work..dm,
				Output = &work..dm_cols,
				MacroVarName = DmVarNameList,
				MacroVarLabel = DmVarLableList
			);			

			%** Mappings **;
			%SmMapDmPcPp(
				Input = &work..dm_cols,
				Type = dm
			);
		%end;
		%else %do;
			%let ProgressGo = fail;
		%end;

		%** 		EX				**;
		%if %sysfunc(fileexist(&InputEx.)) and %upcase(&ProgressGo.) = SUCCESS %then %do;
			%** Read **;
			%SmReadAndMergeDataset(
				Input1 = &InputEx.,
				Output = &work..ex
			);

			%** Get the variables **;
			%SmGetColumnNames(
				Input = &work..ex,
				Output = &work..ex_cols,
				MacroVarName = ExVarNameList,
				MacroVarLabel = ExVarLableList
			);			

			%** Mappings **;
			%SmMapDmPcPp(
				Input = &work..ex_cols,
				Type = ex
			);
		%end;

		%** 		PP				**;
		%if %sysfunc(fileexist(&InputEx.)) and %upcase(&ProgressGo.) = SUCCESS %then %do;
			%** Read **;
			%SmReadAndMergeDataset(
				Input1 = &InputPp.,
				Output = &work..pp
			);

			%** Get the variables **;
			%SmGetColumnNames(
				Input = &work..pp,
				Output = &work..pp_cols,
				MacroVarName = PpVarNameList,
				MacroVarLabel = PpVarLableList
			);			

			%** Mappings **;
			%SmMapDmPcPp(
				Input = &work..pp_cols,
				Type = pp
			);
		%end;
		%else %do;
			%let ProgressGo = fail;
		%end;	

		%** Depending on the data available determine the study design **;
		%if %upcase(&ProgressGo.) = SUCCESS and %sysfunc(fileexist(&InputEx.)) %then %do;
			%let ExposureStatus = EX exist;
			%GetMappingLeeAlgo(
				DmDs = &work..dm,
				UsubjidVar = &UsubjidVar.,
				SequenceVar = &SequenceVar.,
				ExDs = &work..ex,
				ExTrtVar = &ExTrtVar.,
				ExDtcVar = &ExDtcVar.,
				PpDs = &work..pp,
				PeriodVar = &PeriodPpVar.,
				AnalyteVar = &AnalytePpVar.
			);
		%end;
		%else %do;
			%let ExposureStatus = No EX;
		%end;
	
		%** Collect the mappings **;
		data &work..mappings_&i.;
			length NDA Study Status Exposure $20. ArmRegimen PeriodRegimen PTbyRegimen PTbyAllTreatment PTbyAllPeriodRegiment Arm $800. NoArm $8. ExTrt TrtSeq $800. NoTrtSeq $8. Visit $800.;
			format NDA Study Status Exposure $20. ArmRegimen PeriodRegimen PTbyRegimen PTbyAllTreatment PTbyAllPeriodRegiment Arm $800. NoArm $8. ExTrt TrtSeq $800. NoTrtSeq $8. Visit $800.;
			NDA = compress("%qscan(%qscan(&study_list, &i., @), -2, %str( ))))", "@()", "a");
			Study = "%qscan(%qscan(&study_list, &i., @), -1, %str( ))";
			Status = "Okay";
			PTbyRegimen = "&ptbyregimine.";
			PTbyAllPeriodRegiment = "&ptbyalltreatment."; /* Switched on purpose! */
			PTbyAllTreatment = "&PTbyAllRegimentSession.";
			Arm = "&Sequence_list.";
			NoArm = "&Sequence_tot.";
			ExTrt = "&ExTrt_list.";
			TrtSeq = "&TrtSeq_list.";
			NoTrtSeq = "&TrtSeq_Num.";
			Exposure = "&ExposureStatus.";
			Visit = "&Period_list.";
			ArmRegimen = "&ArmRegimen.";
			PeriodRegimen = "&PeriodRegimen.";
			put arm;
			output;
		run;
		
	%end;
	
	%else %do;
		data &work..mappings_&i.;
			length NDA Study Status Exposure $20. PTbyRegimen PTbyAllTreatment PTbyAllRegimentSession Arm $800. NoArm $8. ExTrt TrtSeq $800. NoTrtSeq $8. Visit $800.;
			format NDA Study Status Exposure $20. PTbyRegimen PTbyAllTreatment PTbyAllRegimentSession Arm $800. NoArm $8. ExTrt TrtSeq $800. NoTrtSeq $8. Visit $800.;
			NDA = "%qscan(%qscan(&study_list, &i., @), -2, %str( )))";
			Study = "%qscan(%qscan(&study_list, &i., @), %str( )), -1)";
			Status = "Fail";
			output;
		run;
	%end;
		
%end;

%** Combine the mappings into one **;
data &work..mappings;
	set 
		%do i = 1 %to &NumberOfStudies.;
			%if %sysfunc(exist(&work..mappings_&i.)) %then %do;
				&work..mappings_&i.
			%end;
		%end;
	;
run;

proc import datafile = "C:\Users\sorensenj\Desktop\DevelopmentRepository\SasJobServices\trunk\Stored Procedures\Test\PKView\PkViewResultsFromCSR.xls"
			out = &work..result(rename = (Study_Id = Study)) dbms = xls replace;
run;

proc sort data = &work..result(keep = study study_design groups periods) nodupkey;
	by study;
run;

data &work..mappings;
	set &work..mappings;
	study = upcase(study);
run;

data &work..result;
	set &work..result;
	study = upcase(study);
run;

proc sort data = &work..mappings;
	by study;
run;

data &work..output;
	merge	&work..mappings (in = a)
			&work..result;
	by study;
	if a;
run;

%mend;
%RunNewAlgorithm;
