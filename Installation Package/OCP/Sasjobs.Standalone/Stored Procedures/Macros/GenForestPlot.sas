

options nofmterr compress = yes mprint spool;

libname iportal odbc dsn = "OCPSQL";

%let &work. = &work.;

%macro GenForestPlot();

%** Check if we have received any data from the sas service **;
%if %sysfunc(exist(websvc.sasdata)) %then %do;
	%** Get a forest plot ID (one plot) or a project ID (multiple plots) **;
	%** Save in a variable called IdName and content in IdVal 			 **;
	data _null_;
		set websvc.sasdata;
		call symputx(IdName, Idval);
		call symputx("PlotId", PlotId);
	run;

	%*****************************************;
	%** Check which kind of analysis to run **;
	%*****************************************;
	%if %symexist(PROJECT_ID) %then %do;
		%** Grap the FP_IDs associated with the PROJECT_ID **;
		data _null_;
			set iportal.IPORTAL_FP(where = (PROJECT_ID = &PROJECT_ID.)) end = eof;
			length FP_ID_LIST $40.;
			retain FP_ID_LIST;
			
			if _n_ = 1 then do;
				FP_ID_LIST = strip(FP_ID);
			end;
			else do;
				FP_ID_LIST = strip(FP_ID_LIST) || " " || strip(FP_ID);
			end;

			if eof then do;
				call symputx("FP_ID_LIST", FP_ID_LIST);
			end;
		run;
	%end;
	%else %if %symexist(FP_ID) %then %do;
		%let FP_ID_LIST = &FP_ID.;
	%end;
	%else %do;
		%** Return and push a table with failed back to the sas service **;
		data &work.out;
			PROGRESS = "FAIL - No valid ID received";
			output;
		run;
		%return;
	%end;

	%**********************;
	%** Process the data **;
	%**********************;
	%** Sort and make sure the sorting order holds true **;
	proc sort data = iportal.IPORTAL_FP_ROW(where = (FP_ID in (&FP_ID_LISt.))) 
				out = &work.w1;
		by FP_ID FP_ROW_ID;
	run;

	data &work.w2;
		set &work.w1;
		by FP_ID FP_ROW_ID;

		%** Lags to detect data changes **;
		lagcat = lag(CATEGORY);
		lagsubcat = lag(SUBCATEGORY);

		%** Reset for each FP_ID **;
		if first.FP_ID then do;
			sort1 = .;
			sort2 = .;
		end;

		%** Group each category according to their FP_ROW_ID **;
		if lagcat ^= category then do;
			sort1 + 1;
		end;

		%** Group each subcategory according to their FP_ROW_ID **;
		if lagsubcat ^= SUBCATEGORY or lagcat ^= CATEGORY then do;
			sort2 + 1;
		end;

		%** Clean-up **;
		drop lag:;
	run;

	%** Prepare data for presentation **;
	proc sort data = &work.w2
				out = &work.w3;
		by FP_ID sort1 sort2 FP_ROW_ID;
	run;

	data &work.w3;
		set &work.w3;
		by FP_ID sort1 sort2 FP_ROW_ID;
		retain currCategory;

		%** Set the subcategory to missing for all other than the first **;
		if not first.sort2 then do;
			SUBCATEGORY = "";
			COMMENT = "";
		end;

		%** Helper variables **;
		sort3 = 2;
		currCategory = CATEGORY;

		%** Category should only be present once per category (see below) **;
		CATEGORY = "";

		%** Default output **;
		output;

		%** Add category heading **;
		if first.sort1 then do;
			CATEGORY = currCategory;
			SUBCATEGORY = "";
			PARAMETER = "";
			RATIO = .;
			LOWER_CI = .;
			UPPER_CI = .;
			COMMENT = "";
			sort3 = 1;
			output;
		end;

		%** Clean-up **;
		drop currCategory;
	run;

	%** Add the y-axis values **;
	proc sort data = &work.w3
				out = &work.w4;
		by FP_ID sort1 sort2 sort3;
	run;

	data &work.w4;
		set &work.w4;
		by FP_ID sort1 sort2 sort3;

		if first.FP_ID then do;
			yvalue = .;
		end;

		yvalue + 1;
		one = 1;
		zero = 0;
	run;

	%***********************************************;
	%** Generate the template for the forest plot **;
	%***********************************************;
	proc template;
		define statgraph ForestPlot;
			dynamic PlotTitle PlotFootnote LabelX RangeBottom RangeTop RangeStep PlotType;
			begingraph;
				layout lattice / columns = 4 columnweights = (0.25 0.10 0.45 0.20);
					%** Title and footnote **;
					entrytitle PlotTitle 		/ textattrs = (weight = bold) pad = (bottom = 5px);
					entryfootnote PlotFootnote 	/ textattrs = (weight = normal) pad = (top = 5px);
			
					%** Category column **;
					layout overlay /	xaxisopts = (display = none linearopts = (viewmin = 0 viewmax = 20)) 
										yaxisopts = (reverse = true display = none tickvalueattrs = (weight = bold))
										walldisplay = none;
						entry halign = left "Description" / textattrs = (size = 12) location = outside valign = top pad = (bottom = 10px) opaque = false; 
						highlowplot y = yvalue low = zero high = zero/ 	highlabel = CATEGORY lineattrs = (thickness = 0) 
																		labelattrs = (size = 10 weight = bold);
						highlowplot y = yvalue low = zero high = one / 	highlabel = SUBCATEGORY lineattrs = (thickness = 0) 
																		labelattrs = (size = 10);
					endlayout;

					%** Parameter column **;
					layout overlay /	xaxisopts = (display = none linearopts = (viewmin = 0 viewmax = 20)) 
										yaxisopts = (reverse = true display = none tickvalueattrs = (weight = bold))
										walldisplay = none;
						entry halign = left "PK" / textattrs = (size = 12) location = outside valign = top pad = (bottom = 10px) opaque = false; 
						highlowplot y = yvalue low = zero high = zero/ 	highlabel = PARAMETER lineattrs = (thickness = 0) 
																		labelattrs = (size = 10);
					endlayout;

					%** Fold changes and CI **;
					layout overlay /	xaxisopts = (label = LabelX type = PlotType
													 linearopts = (tickvaluesequence = (start = RangeBottom end = RangeTop increment = RangeStep) tickvaluepriority = true) labelattrs = (weight = normal))
										yaxisopts = (reverse = true display = none) walldisplay = none;
						entry halign = left "Fold Change and 90% CI" / textattrs = (size = 12) location = outside valign = top pad = (bottom = 10px) opaque = false; 
						highlowplot y = yvalue low = LOWER_CI high = UPPER_CI; 
						scatterplot y = yvalue x = RATIO	/	markerattrs = (symbol = squarefilled);
						referenceline x = 1 / lineattrs = (color = black);
					endlayout;

					%** Comment column **;
					layout overlay /	xaxisopts = (display = none linearopts = (viewmin = 0 viewmax = 20)) 
										yaxisopts = (reverse = true display = none tickvalueattrs = (weight = bold))
										walldisplay = none;
						entry halign = left "Recommendation" / textattrs = (size = 12) location = outside valign = top pad = (bottom = 10px) opaque = false; 
						highlowplot y = yvalue low = zero high = zero/ 	highlabel = COMMENT lineattrs = (thickness = 0) 
																		labelattrs = (size = 10);
					endlayout;
				endlayout;
			endgraph;
		end;
	run;

	%** Loop for each FP_ID and create the plot **;
	%do i = 1 %to %sysfunc(countw(%nrbquote(&FP_ID_LIST)));
		%** Extract the plot features **;
		data _null_;
			set iportal.IPORTAL_FP(where = (FP_ID = %qscan(&FP_ID_LIST., &i.)));
			call symputx("PlotTitle", TITLE);
			call symputx("ScaleId", SCALEID);
			call symputx("PlotFootnote", FOOTNOTE);
			call symputx("LabelX", XLABEL);
			call symputx("RangeBottom", RANGE_BOTTOM);
			call symputx("RangeTop", RANGE_TOP);
			call symputx("RangeStep", RANGE_STEP);

			if SCALE_ID = 1 then do;
				call symputx("PlotType", "LINEAR");
			end;
			else if SCALE_ID = 2 then do;
				call symputx("PlotType", "LOG");
			end;
		run;

		title;
		footnote;

		ods graphics on / imagename = "&PlotId._%qscan(&FP_ID_LIST., &i.)" border = off reset = index;
		ods listing gpath = "&SasSpPath.\Output Files\ForestPlot";
		proc sgrender data = &work.w4(where = (FP_ID = %qscan(&FP_ID_LIST., &i.))) template = ForestPlot;
			dynamic PlotTitle = "&PlotTitle" PlotFootnote = "&PlotFootnote" LabelX = "&LabelX" 
					RangeBottom = &RangeBottom. RangeTop = &RangeTop. RangeStep = &RangeStep. PlotType = "&PlotType.";
		run;
		ods graphics off;
	%end;
%end;
%else %do;
	%** Return and push a table with failed back to the sas service **;
	data &work.out;
		PROGRESS = "FAIL - No data available";
		output;
	run;
	%return;
%end;

%mend;

%GenForestPlot();
