%*****************************************************************************************;
%**																						**;
%**	Creates a demographic table															**;
%**																						**;
%**	Input:																				**;
%**		Pat			        -		Input DM file		                				**;
%**		PatSel				-		Selection in Pat									**;
%**		PatKeep				-		Variables to keep in Pat					 		**;
%**		ArmVar				-		Name of the sequence/group variable in DM			**;
%**		AnlVar				-		List of variables to summarize separated by #		**;
%**		PctFmt				-		Format to apply to the percentages values			**;
%**		Id					-		Output Id											**;
%**		OutputFolder		-		Destination of the output file						**;
%**																						**;
%** Output:                                                                             **;
%**		RTF file containing a summary demographic table									**;
%**																						**;
%**	Created by:																			**;
%**		Jens Stampe Soerensen  (2013/2014)                                              **;
%**																						**;
%*****************************************************************************************;
%macro Demographic_Summary(
			Pat = ,
			PatSel = ,
			PatKeep = ,
			ArmVar = ,
			AnlVar = ,
			PctFmt = ,
			Id = ,
			OutputFolder = 
);

%** Specify used macro variables to avoid clashes **;
%local i j;

%*************************************************************************************;
%**																					**;
%**		Pre-processing: Identify categorical and continous variables				**;
%**						Sort and get the treatment arms 							**;
%**																					**;
%*************************************************************************************;

%** Identify which variables are categorical and which are continous variables **;
data _null_;
	set &Pat. (keep = 
		%do i = 1 %to %sysfunc(countw(&AnlVar., #));
			%scan(&AnlVar., &i., #)
		%end;
	);
	length AnlVarNum AnlVarChar $50.;

	%** Check the variable type (needs to be expanded for increased flexibility) **;
	%do i = 1 %to %sysfunc(countw(&AnlVar., #));
		if vtype(%scan(&AnlVar., &i., #)) = "N" then do;
			AnlVarNum = cats(AnlVarNum, "#", vname(%scan(&AnlVar., &i., #)));
		end;
		else if vtype(%scan(&AnlVar., &i., #)) = "C" then do;
			AnlVarChar = cats(AnlVarChar, "#", vname(%scan(&AnlVar., &i., #)));
		end;
	%end;

	%** Output the categories **;
	if _N_ = 2 then do;
		call symputx("AnlVarNum", substr(AnlVarNum, 2));
		call symputx("AnlVarChar", substr(AnlVarChar, 2));
		stop;
	end;
run;

%** Get the treatment arms **;
proc sql noprint;
	select distinct 
		&ArmVar.
	into
		:arm_lst separated by "#"
	from 
		&Pat. 
			%if &Patsel. ne %then %do;
				(where = (&PatSel.))
			%end;
	order by
		&ArmVar.
	;
quit;

%** Sort and subset the Pat dataset **;
proc sort data = &Pat. 
				%if &PatSel. ne and &PatKeep. ne %then %do;
					(where = (&PatSel.) keep = &PatKeep.)
				%end;
				%else %if &PatSel. ne %then %do;
					(where = (&PatSel.))
				%end;
				%else %if &PatKeep. ne %then %do;
					(keep = &PatKeep.)
				%end;
			out = &work.pat;
	by &ArmVar.;
run;

%*************************************************************************************;
%**																					**;
%**		Count the number of subjects / patients										**;
%**																					**;
%*************************************************************************************;

%** Prepare count of the number of subjects **;
data &work.pat;
	set &work.pat;
	__tot = 1;
run;

%** Count the number of subjects **;
proc summary data = &work.pat;
	by &ArmVar.;
	var __tot;
	output out = &work.patcnt (drop = _type_ _freq_) 
					n = n
	;
run;

%** Add additional variables to ease the presentation of the results **;
data &work.patcnt;
	set &work.patcnt;
	length PARAMCD $20. PARAM $50. AVAL $50.;

	PARAMCD = "NUMSUBJ";
	PARAM = "Number of Subjects";

	AVAL = PARAM;
	TYPE = "TOT ";

	SORT0 = 1;
	SORT1 = -1;
run;

%** Flip the data (use for calculating percentages later on **;
data &work.patcnt_flip;	
	merge	%do i = 1 %to %sysfunc(countw(&arm_lst., #));
				&work.patcnt(where = (&ArmVar. = "%scan(&arm_lst., &i., #)") 
									rename = (n = tot_&i.)
									)
			%end;
		;
	keep tot_:;
run;

%*************************************************************************************;
%**																					**;
%**		Summary of categorical variables											**;
%**																					**;
%*************************************************************************************;
%do i = 1 %to %sysfunc(countw(&AnlVarChar., #));

	%** Use proc freq to summarize the categorical variables **;
	proc freq data = &work.pat noprint;
		by &ArmVar. ;
		tables %scan(&AnlVarChar., &i., #) / list missing out = &work.stat_char_&i.;
	run;

	%** Add additional variables to ease the presentation of the results **;
	data &work.stat_char_&i. (drop = %scan(&AnlVarChar., &i., #));
		set &work.stat_char_&i. (drop = percent);
		length PARAMCD $20. PARAM $50. AVAL $50.;

		PARAMCD = propcase("%scan(&AnlVarChar., &i., #)");
		PARAM = propcase(vlabel(%scan(&AnlVarChar., &i., #)));

		AVAL = propcase(%scan(&AnlVarChar., &i., #));
		TYPE = "CHAR";

		SORT0 = 2;
		SORT1 = &i.;
		SORT2 = 1;
	run;
%end;

%*************************************************************************************;
%**																					**;
%**		Summary of continous variables												**;
%**																					**;
%*************************************************************************************;
%do i = 1 %to %sysfunc(countw(&AnlVarNum., #));

	%** Summarize the continous variables using proc summary / means / univariate **;
	proc summary data = &work.pat nway missing;
		by &ArmVar.;
		var %scan(&AnlVarNum., &i., #);
		output out = &work.stat_num_&i. (drop = _type_ _freq_)
						n = n 
						mean = mean 
						std = std 
						min = min
						max = max 
						median = median;
	run;

	%** Get the variable labels **;
	data _null_;
		set &work.pat (keep = %scan(&AnlVarNum., &i., #));
		call symputx('Label', propcase(vlabel(%scan(&AnlVarNum., &i., #))));
		stop;
	run;

	%** Add additional variables to ease the presentation of the results and flip the data **;
	data &work.stat_num_&i.;
		set &work.stat_num_&i.;

		%** Arrays containing the result and labels **;
		array stat_vars {6} n mean std min max median;
		array stat_names {6} $ _temporary_ ("n" "Mean" "STD" "Min" "Max" "Median");

		length PARAMCD $20. PARAM $50. AVAL $50.;

		PARAMCD = propcase("%scan(&AnlVarNum., &i., #)");
		PARAM = propcase("&Label.");
		TYPE = "NUM ";

		SORT0 = 3;
		SORT1 = &i.;

		%** Flip the data and round if necessary **;
		do i = 1 to dim(stat_vars);
			SORT2 = i;
			if i > 1 then do;
				COUNT = round(stat_vars(i), 0.1);
			end;
			else do;
				COUNT = stat_vars(i);
			end;
			AVAL = stat_names(i);
			output;
		end;

		%** Drop the redundant information **;
		drop i n mean std min max median;
	run;

	%** Sort **;
	proc sort data = &work.stat_num_&i.;
		by paramcd param aval;
	run;
%end;

%*************************************************************************************;
%**																					**;
%**		Prepare presentation of the data											**;
%**																					**;
%*************************************************************************************;

%** Combine the continous and categorical data by transposing the datasets **;
data &work.combined (drop = &ArmVar.);
	merge	
		%do i = 1 %to %sysfunc(countw(&arm_lst., #));
			&work.patcnt(where = (&ArmVar. = "%scan(&arm_lst., &i., #)") 
									rename = (n = n_&i.)
									)
			%do j = 1 %to %sysfunc(countw(&AnlVarChar., #));
				&work.stat_char_&j. (where = (&ArmVar. = "%scan(&arm_lst., &i., #)") 
												rename = (count = n_&i.)
												)
			%end;
			%do j = 1 %to %sysfunc(countw(&AnlVarNum., #));
				&work.stat_num_&j. (where = (&ArmVar. = "%scan(&arm_lst., &i., #)") 
												rename = (count = n_&i.)
												)
			%end;
		%end;
	;
	by paramcd param aval;

	%** Indent for pretty output **;
	if type in ("NUM", "CHAR") then do;
		aval = "      " || aval;
	end;

	%** Insert zeros if a value is missing **;
	%do i = 1 %to %sysfunc(countw(&arm_lst., #));
		if type = "CHAR" and n_&i. = . then do;
			n_&i. = 0;
		end;
	%end;
run;

%** Merge the total number of patients onto the dataset and calculate the percentages **;
proc sql noprint;
	create table
		&work.combined
	as select
		a.*,
		b.*
		%do i = 1 %to %sysfunc(countw(&arm_lst., #));
		, case 
			when type = "CHAR" and n_&i. > 0 then put((n_&i. / tot_&i.)*100, &PctFmt.)
			else ""
			end as pct_&i.
		%end;
	from
		&work.combined as a,
		&work.patcnt_flip as b
	;
quit;

%** Create a heading for each variable. The heading is equal to the label of the variable **;
proc sort data = &work.combined(keep = paramcd param sort0 sort1 where = (paramcd ^= "NUMSUBJ"))
			out = &work.param_comb nodupkey;
	by paramcd param sort0 sort1;
run;

data &work.combined;
	set &work.combined   (in = a)
		&work.param_comb (in = b);
	if a then SORT3 = 2;
	else if b then do;
		SORT3 = 1;
	end;

	if b then do;
		aval = param;
	end;

	if SORT2 = . then do;
		SORT2 = 0;
	end;
run;

%*************************************************************************************;
%**																					**;
%**		Output generation															**;
%**																					**;
%*************************************************************************************;

%** Sort before presenting. Not necessary but will provide a nice output for the user **;
proc sort data = &work.combined;
	by sort0 sort1 sort2 sort3 aval;
run;

%** Create the report **;
title "&Id. - Demographics";
options missing = "" orientation = landscape nodate nonumber;
ods rtf file = "&OutputFolder.\demographic_&Id..rtf" style = fda_style;
proc report data = &work.combined nowd;
	column sort0 sort1 sort2 sort3 aval
			%do i = 1 %to %sysfunc(countw(&arm_lst., #));
				("%scan(&arm_lst., &i., #)" n_&i.
											pct_&i.
				) 	
			%end;
	;

	define	sort0		/ noprint order;
	define 	sort1		/ noprint order;
	define 	sort2		/ noprint order;
	define	sort3 		/ noprint order;
	define 	aval		/ order style = {cellwidth = 5.0cm just = left asis = on} '';

	%do i = 1 %to %sysfunc(countw(&arm_lst., #));
		define	n_&i. 			/ style = {cellwidth = 1.4cm just = right} 'n';
		define	pct_&i. 		/ style = {cellwidth = 1.4cm just = right} '(%)';
	%end;

	compute after sort1;
		line "";
	endcomp;
run;
ods rtf close;
options missing = . orientation = portrait;

%mend;


