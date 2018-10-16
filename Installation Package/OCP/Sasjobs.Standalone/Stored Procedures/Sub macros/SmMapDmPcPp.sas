%macro SmMapDmPcPp(
	Input = ,
	Type = 
);

%** Map the studies and add mapping quality **;
%** Define by: 0 = OKAY, 1 - non-standard, 2 - Could not be mapped **;

%** Handle Demographics **;
%if %upcase(&type.) = DM %then %do;
	data _null_;
		set &Input. end = eof;
		length UsubjidVar SequenceVar AgeVar SexVar RaceVar EthnicVar CountryVar $20.;
		retain UsubjidVar SequenceVar AgeVar SexVar RaceVar EthnicVar CountryVar ;

		%** Map Usubjid variable **;
		if upcase(colname) = "USUBJID" and UsubjidVar = "" then do;
			UsubjidVar = colname;
		end;

		%** Map Sequence variable **;
		if upcase(colname) = "ARM" and SequenceVar = "" then do;
			SequenceVar = colname;
		end;

		%** Map Age variable **;
		if upcase(colname) = "AGE" and AgeVar = "" then do;
			AgeVar = colname;
		end;

		%** Map Sex variable **;
		if upcase(colname) = "SEX" and SexVar = "" then do;
			SexVar = colname;
		end;

		%** Map Race variable **;
		if upcase(colname) = "RACE" and RaceVar = "" then do;
			RaceVar = colname;
		end;

		%** Map Ethnic variable **;
		if upcase(colname) = "ETHNIC" and EthnicVar = "" then do;
			EthnicVar = colname;
		end;

		%** Map Country variable **;
		if upcase(colname) = "COUNTRY" and CountryVar = "" then do;
			CountryVar = colname;
		end;

		if eof then do;
			%** Mappings **;
			call symputx("UsubjidVar", UsubjidVar, "G");
			call symputx("SequenceVar", SequenceVar, "G");
			call symputx("AgeVar", AgeVar, "G");
			call symputx("SexVar", SexVar, "G");
			call symputx("RaceVar", RaceVar, "G");
			call symputx("EthnicVar", EthnicVar, "G");
			call symputx("CountryVar", CountryVar, "G");

			%** Mapping quality **;
			if UsubjidVar ne "" then do;
				call symputx("UsubjidVarQual", 0, "G");
			end;
			else do;
				call symputx("UsubjidVarQual", 2, "G");
			end;

			if SequenceVar ne "" then do;
				call symputx("SequenceVarQual", 0, "G");
			end;
			else do;
				call symputx("SequenceVarQual", 2, "G");
			end;

			if AgeVar ne "" then do;
				call symputx("AgeVarQual", 0, "G");
			end;
			else do;
				call symputx("AgeVarQual", 2, "G");
			end;

			if SexVar ne "" then do;
				call symputx("SexVarQual", 0, "G");
			end;
			else do;
				call symputx("SexVarQual", 2, "G");
			end;

			if RaceVar ne "" then do;
				call symputx("RaceVarQual", 0, "G");
			end;
			else do;
				call symputx("RaceVarQual", 2, "G");
			end;

			if EthnicVar ne "" then do;
				call symputx("EthnicVarQual", 0, "G");
			end;
			else do;
				call symputx("EthnicVarQual", 2, "G");
			end;

			if CountryVar ne "" then do;
				call symputx("CountryVarQual", 0, "G");
			end;
			else do;
				call symputx("CountryVarQual", 2, "G");
			end;
		end;
	run;
%end;
%** Handle Exposure **;
%else %if %upcase(&type.) = EX %then %do;
	%if %sysfunc(exist(&Input.)) %then %do;
		data _null_;
			set &Input. end = eof;
			length ExTrtVar ExDateVar PeriodVar $20.;
			retain ExTrtVar ExDateVar PeriodVar EpochHit;

			%** Map actual treatment **;
			if upcase(colname) = "EXTRT" then do;
				ExTrtVar = colname;
			end;

			%** Map data of exposure **;
			if upcase(colname) = "EXSTDTC" then do;
				ExDateVar = colname;
			end;

			%** Map Periods variable **;
			if upcase(colname) = "VISIT" and PeriodVar = "" then do;
				PeriodVar = colname;
			end;
			else if upcase(colname) = "EPOCH" and PeriodVar = "" then do;
				EpochHit = 1;
				PeriodVar = colname;
			end;
			else if upcase(colname) = "VISIT" and not EpochHit then do;
				PeriodVar = colname;
			end;

			if eof then do;
				%** Mappings **;
				call symputx("ExTrtVar", ExTrtVar, "G");
				call symputx("ExDateVar", ExDateVar, "G");
				call symputx("PeriodExVar", PeriodVar, "G");

				%** Mapping Quality **;
				if ExTrtVar ne "" then do;
					call symputx("ExTrtVarQual", 0, "G");
				end;
				else do;
					call symputx("ExTrtVarQual", 2, "G");
				end;

				if ExDateVar ne "" then do;
					call symputx("ExDateVarQual", 0, "G");
				end;
				else do;
					call symputx("ExDateVarQual", 2, "G");
				end;

				if PeriodVar ne "" and EpochHit then do;
					call symputx("PeriodExVarQual", 1, "G");
				end;
				else if PeriodVar ne "" and not EpochHit then do;
					call symputx("PeriodExVarQual", 0, "G");
				end;
				else do;
					call symputx("PeriodExVarQual", 2, "G");
				end;
			end;
		run;
	%end;
	%else %do;
		%let ExTrtVar = ;
		%let ExTrtVarQual = 2;
		%let ExDateVar = ;
		%let ExDateVarQual = 2;
		%let PeriodExVar = ;
		%let PeriodExVarQual = 2;
	%end;
%end;
%** Handle Plasma Concentrations **;
%else %if %upcase(&type.) = PC %then %do;
	data _null_;
		set &Input. end = eof;
		length PeriodVar AnalyteVar ResultVar TimeVar $20.;
		retain PeriodVar AnalyteVar ResultVar TimeVar EpochHit;

		%** Map Periods variable **;
		if upcase(colname) = "VISIT" and PeriodVar = "" then do;
			PeriodVar = colname;
		end;
		else if upcase(colname) = "EPOCH" and PeriodVar = "" then do;
			EpochHit = 1;
			PeriodVar = colname;
		end;
		else if upcase(colname) = "PCTPTREF" and PeriodVar = "" then do;
			PeriodVar = colname;
		end;
		else if upcase(colname) = "VISIT" and not EpochHit then do;
			PeriodVar = colname;
		end;

		%** Map Analytes variable **;
		if upcase(colname) = "PCTESTCD" and AnalyteVar = "" then do;
			AnalyteVar = colname;
		end;
		if upcase(colname) = "PCGRPID" then do;
			AnalyteVar = colname;
		end;
		else if upcase(colname) = "PCSCAT" and AnalyteVar = "" then do;
			AnalyteVar = colname;
		end;
		else if upcase(colname) = "PCTESTCD" then do;
			AnalyteVar = colname;
		end;

		%** Map Results variable **;
		if upcase(colname) = "PCSTRESN" then do;
			ResultVar = colname;
		end;

		%** Map Time variable **;
		if upcase(colname) = "PCTPTNUM" then do;
			TimeVar = colname;
		end;

		if eof then do;
			%** Mappings **;
			call symputx("PeriodPcVar", PeriodVar , "G");
			call symputx("AnalytePcVar", AnalyteVar, "G");
			call symputx("ResultPcVar", ResultVar, "G");
			call symputx("TimeVar", TimeVar, "G");

			%** Mapping Quality **;
			if PeriodVar ne "" and EpochHit then do;
				call symputx("PeriodPcVarQual", 1, "G");
			end;
			else if PeriodVar ne "" and not EpochHit then do;
				call symputx("PeriodPcVarQual", 0, "G");
			end;
			else do;
				call symputx("PeriodPcVarQual", 2, "G");
			end;

			if AnalyteVar ne "" then do;
				call symputx("AnalytePcVarQual", 0, "G");
			end;
			else do;
				call symputx("AnalytePcVarQual", 2, "G");
			end;

			if ResultVar ne "" then do;
				call symputx("ResultPcVarQual", 0, "G");
			end;
			else do;
				call symputx("ResultPcVarQual", 2, "G");
			end;

			if TimeVar ne "" then do;
				call symputx("TimeVarQual", 0, "G");
			end;
			else do;
				call symputx("TimeVarQual", 2, "G");
			end;
		end;
	run;
%end;
%** Handle PK Parameters **;
%else %if %upcase(&type.) = PP %then %do;
	data _null_;
		set &Input. end = eof;
		length PeriodVar AnalyteVar ResultVar ParameterVar DateVar $20.;
		retain PeriodVar AnalyteVar ResultVar ParameterVar DateVar EpochHit PpDyHit;

		%** Map Periods variable **;
		if upcase(colname) = "VISIT" and PeriodVar ^= "" and not EpochHit then do;
			PeriodVar = colname;
		end;
		else if upcase(colname) = "EPOCH" and PeriodVar = "" then do;
			EpochHit = 1;
			PeriodVar = colname;
		end;
		else if upcase(colname) = "PPTPTREF" and PeriodVar = "" then do;
			PeriodVar = colname;
		end;
		else if upcase(colname) = "PPGRPID" and PeriodVar = "" then do;
			PeriodVar = colname;
		end;
		else if upcase(colname) = "VISIT" and not EpochHit then do;
			PeriodVar = colname;
		end;

		%** Emergency case if there is no clear period variable **;
		if upcase(colname) = "PPDY" then do;
			PpDyHit = 1;
		end;

		%** Map Analytes variable **;
		if upcase(colname) = "PPCAT" and AnalyteVar = "" then do;
			AnalyteVar = colname;
		end;

		%** Map Results variable **;
		if upcase(colname) = "PPSTRESN" then do;
			ResultVar = colname;
		end;

		%** Map Parameter variable **;
		if upcase(colname) = "PPTESTCD" then do;
			ParameterVar = colname;
		end;

		if eof then do;
			%** Mappings **;
			if PeriodVar = "" and PpDyHit then do;
				call symputx("PeriodPpVar", "PPDY", "G");
			end;
			else do;
				call symputx("PeriodPpVar", PeriodVar, "G");
			end;
			call symputx("AnalytePpVar", AnalyteVar, "G");
			call symputx("ResultPpVar", ResultVar, "G");
			call symputx("ParameterVar", ParameterVar, "G");

			%** Mapping Quality **;
			if PeriodVar ne "" and EpochHit then do;
				call symputx("PeriodPpVarQual", 1, "G");
			end;
			else if PeriodVar ne "" and not EpochHit then do;
				call symputx("PeriodPpVarQual", 0, "G");
			end;
			else if PpDyHit = 1 then do;
				call symputx("PeriodPpVarQual", 0, "G");
			end;
			else do;
				call symputx("PeriodPpVarQual", 2, "G");
			end;

			if AnalyteVar ne "" and upcase(AnalyteVar) eq "PPCAT" then do;
				call symputx("AnalytePpVarQual", 0, "G");
			end;
			else if upcase(AnalyteVar) ne "PPCAT" then do;
				call symputx("AnalytePpVarQual", 1, "G");
			end;
			else do;
				call symputx("AnalytePpVarQual", 2, "G");
			end;

			if ResultVar ne "" then do;
				call symputx("ResultPpVarQual", 0, "G");
			end;
			else do;
				call symputx("ResultPpVarQual", 2, "G");
			end;

			if ParameterVar ne "" then do;
				call symputx("ParameterVarQual", 0, "G");
			end;
			else do;
				call symputx("ParameterVarQual", 2, "G");
			end;
		end;
	run;
%end;

%mend;
