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

%** Get the unique sequences **;
proc sort data = &DmDs. (keep = &SequenceVar.) out = &work.sequences nodupkey;
	by &SequenceVar.;
run;

data _null_;
	set &work.sequences end = eof;
	by &SequenceVar.;
	length sequence_list $400.;
	retain sequence_list;

	if _n_ = 1 then do;
		sequence_list = strip(&SequenceVar.);
	end;
	else do;
		sequence_list = strip(sequence_list) || " || " || strip(&SequenceVar.);
	end;

	if eof then do;
		call symputx("sequence_list", sequence_list, "G");
	end;
run;

%** Get the unique periods **;
proc sort data = &PpDs. (keep = &AnalyteVar. &PeriodVar.) out = &work.periods nodupkey; 
	by &PeriodVar.;
run;

data _null_;
	set &work.periods end = eof;
	by &PeriodVar.;
	length period_list $200.;
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

%** Check if exposure exists - if it does try to get the treatment sequence **;
%if %sysfunc(exist(&ExDs.)) %then %do;
	%** Merge DM and EX **;
	proc sort data = &DmDs.(keep = &UsubjidVar. &SequenceVar.);
		by &UsubjidVar.;
	run;

	proc sort data = &ExDs. (keep = &UsubjidVar. &ExTrtVar. &ExDtcVar.);
		by &UsubjidVar.;
	run;

	data &work.w1;
		merge	&DmDs. (in = a)
				&ExDs. (in = b);
		by &UsubjidVar.;
		if a and b;

		%** Handle difficult data **;
		ExDate = scan(&ExDtcVar., 1, "T");
	run;

	%** For each sequence determine the actual treatment **;
	proc sort data = &work.w1;
		by &SequenceVar. &UsubjidVar. ExDate &ExTrtVar.;
	run;

	%** Combine treatments on the same date **;
	data &work.w2;
		length trt_list $200.;
		set &work.w1(keep = &UsubjidVar. &SequenceVar. &ExTrtVar. ExDate);
		by &SequenceVar. &UsubjidVar. ExDate;
		retain trt_list;

		prev_trt = lag(&ExTrtVar.);
		if first.&UsubjidVar. then do;
			prev_trt = "";
		end;

		if first.ExDate then do;
			trt_list = &ExTrtVar.;
		end;
		else do;
			trt_list = strip(trt_list) || " + " || strip(&ExTrtVar.);
		end;

		if last.ExDate then do;
			output;
		end;
	run;

	%** Combine multiple days of treatment into one **;
	data &work.w3;
		set &work.w2;
		by &SequenceVar. &UsubjidVar.;
		length extrt_list $200.;
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
			:ExTrt_list separated by " /\ "
		from
			&work.w3
		;
 	quit;

	%** Create the trtseq list (list unique treatments per arm) **;
	proc sort data = &work.w3 out = &work.w4 nodupkey;
		by &SequenceVar. extrt_list;
	run;

	data &work.w5;
		set &work.w4 end = eof;
		by &SequenceVar. extrt_list;
		length trtseq_list trtseq $200.;
		retain trtseq_list trtseq;

		if first.&SequenceVar. then do;
			trtseq = strip(extrt_list);
		end;
		else do;
			trtseq = strip(trtseq) || " /\ " || strip(extrt_list);
		end;

		if last.&SequenceVar. then do;
			if TrtSeq_list ne "" then do;
				TrtSeq_list = strip(TrtSeq_list) || " || " || strip(trtseq);
			end;
			else do;
				TrtSeq_list = strip(trtseq);
			end;
			output;
		end;

		if eof then do;
			call symputx("TrtSeq_list", TrtSeq_list, "G");
		end;
	run;

	%** Get PTbyRegimen and PtByAllTreatment **;
	proc sort data = &work.w5 out = &work.w6;
		by trtseq;
	run;

	data _null_;
		set &work.w6 end = eof;
		length ptbyalltreatment $200.;
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

	proc sort data = &work.w5 out = &work.w7;
		by &SequenceVar. trtseq;
	run;

	data _null_;
		set &work.w7 end = eof;
		length ptbyregimine $200.;
		retain ptbyregimine cnt;
		by &SequenceVar. trtseq;

		if _N_ = 1 then do;
			cnt = 1;
			ptbyregimine = "1";
		end;
		else if first.trtseq then do;
			cnt + 1;
			ptbyregimine = strip(ptbyregimine) || " || " || strip(cnt);
		end;

		if eof then do;
			call symputx("ptbyregimine", ptbyregimine, "G");
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
