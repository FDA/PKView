%*****************************************************************************************;
%**																						**;
%**	Correct the assigned grouping/sequence for parallel studies							**;
%**																						**;
%**	Input:																				**;
%**		Input		       -		Input dataset										**;
%**		UsubjidVar			-		Name of the usubjid variable from Input	    **;
%**		SequenceVar		-      Name of the sequence variable from Input		**;
%**		DataPath			-		Path to the SDTM data in EDR						**;
%**    UseSuppdm         -      Allow usage of SUPPDM to determine grouping   **;																					**;
%** Output:                                                                   **;
%**		Dataset with same name as Input but with possible corrected groupings	**;
%**																						**;
%**	Created by:																		**;
%**		Jens Stampe Soerensen  (2013/2014)                                     **;
%**																						**;
%**	Modified by:																		**;
%**		Eduard Porta Martin Moreno  (2015)                                     **;
%**																						**;
%*****************************************************************************************;

%macro SmParallelGrouping(
	Input = ,
	UsubjidVar = USUBJID,
	SequenceVar = ARM,
    UseSuppdm = 0,
	DataPath = ,
);

%** Macro variables **;
%local InputSuppDm InputSc GotGroup GroupVar GroupList;

%** Check if the data path contains xpt (hence we have a file not a folder) **;
%if %upcase(%substr(%nrbquote(&DataPath.), %length(%nrbquote(&DataPath.)) - 2)) = XPT %then %do;
	%** Check to see if the grouping is found - SUPPDM then SC **;
	%let GotGroup = ;

	%** Get the path to the study **;
	%let AllDataPath = %substr(%nrbquote(&DataPath.), 1, %length(%nrbquote(&DataPath.)) - %length(%qscan(&DataPath., -1, \)) - 1);
	
	%** Check if SUPPDM exist **;
	%if &UseSuppdm.=1 and %sysfunc(fileexist(%nrbquote(&AllDataPath.)\SUPPDM.XPT)) %then %do;
    %put using suppdm;
		%let InputSuppDm = &AllDataPath\SUPPDM.XPT;
		%SmReadAndMergeDataset(
			Input1 = &InputSuppDm.,
			UsubjidVar = &UsubjidVar.,
			Output = &work.suppdm
		);

		%** See if we can find anything suggesting a grouping (look in QVAL) **;
		data _null_;
			set &work.suppdm end = eof;
			length 	StatusHit SeverityHit RenalHit HepaticHit AgeHit ControlHit 8.
					StatusVar SeverityVar RenalVar HepaticVar AgeVar ControlVar $20.
			;
			retain 	StatusHit SeverityHit RenalHit HepaticHit AgeHit ControlHit
					StatusVar SeverityVar RenalVar HepaticVar AgeVar ControlVar
			;

			%** Does QVAL contain anything about the status (impaired etc) **;
			if findw(upcase(QVAL), "IMPAIRED") and StatusHit ne 1 then do;
				StatusHit = 1;
				StatusVar = QNAM;
			end;

			%** Does QVAL contain anything about the severity? **;
			if (findw(upcase(QVAL), "NORMAL") or findw(upcase(QVAL), "SEVERE") or findw(upcase(QVAL), "MODERATE")
				or findw(upcase(QVAL), "IMPAIRED")) and SeverityHit ne 1 then do;
				SeverityHit = 1;
				SeverityVar = QNAM;
			end;

			%** Does QVAL contain anything about Renal status? **;
			if findw(upcase(QVAL), "RENAL") and RenalHit ne 1 then do;
				RenalHit = 1;
				RenalVar = QNAM;
			end;

			%** Does QVAL contain anything about Hepatic status? **;
			if findw(upcase(QVAL), "HEPATIC") and HepaticHit ne 1 then do;
				HepaticHit = 1;
				HepaticVar = QNAM;
			end;

			%** Does QVAL contain anything about age? **;
			if findw(upcase(QVAL), "ELDERLY") and AgeHit ne 1 then do;
				AgeHit = 1;
				AgeVar = QNAM;
			end;

			%** Does QVAL contain anything about controls? **;
			if findw(upcase(QVAL), "CONTROL") and ControlHit ne 1 then do;
				ControlHit = 1;
				ControlVar = QNAM;
			end;

			%** Did we get a hit? **;
			%** If Renal / Hepatic is found assume the grouping is in that variable **;
			if eof then do;
				if RenalHit then do;
					call symputx("GroupVar", RenalVar);
				end; 
				else if HepaticHit then do;
					call symputx("GroupVar", HepaticVar);
				end;
				else if SeverityHit then do;
					call symputx("GroupVar", SeverityVar);
				end;
				else if StatusHit then do;
					call symputx("GroupVar", StatusVar);
				end;
				else if AgeHit then do;
					call symputx("GroupVar", AgeVar);
				end;
				else if ControlHit then do;
					call symputx("GroupVar", ControlVar);
				end;

				if StatusHit or RenalHit or HepaticHit or SeverityHit or AgeHit or ControlHit then do;
					call symputx("GotGroup", 1);
				end;
			end;
		run;
		%put Got Group = &GotGroup.;
		%put GroupVar = &GroupVar.;

		%** If we found a hit extract the content and merge with the input dataset (removing the Sequence set there) **;
		%if &GotGroup. ne %then %do;
			proc sort data = &Input.(rename = (&SequenceVar. = _&SequenceVar._));
				by &UsubjidVar.;
			run;

			proc sort data = &work.suppdm(where = (QNAM = "&GroupVar.") rename = (QVAL = &SequenceVar.));
				by &UsubjidVar.;
			run;

			data &Input.;
				merge	&Input. (in = a)
						&work.suppdm (in = b keep = &UsubjidVar. &SequenceVar.);
				by &UsubjidVar.;
				if a;

				%** FIXME - Should not be necessary and should be removed!! **;
				%** For any reason that we dont have a group - set it as healthy  **;
				if &SequenceVar. = "" then do;
					&SequenceVar. = "HEALTHY";
				end;
			run;
		%end;
	%end;

	%** Check if SC exist **;
	%put %nrbquote(&AllDataPath.)\SC.XPT;
	%if %sysfunc(fileexist(%nrbquote(&AllDataPath.)\SC.XPT)) and &GotGroup. eq %then %do;
		%let InputSc = &AllDataPath.\SC.XPT;
		%SmReadAndMergeDataset(
			Input1 = &InputSc.,
			UsubjidVar = &UsubjidVar.,
			Output = &work.sc
		);

		%** See if we can find anything suggesting a grouping (look in SCSTRESC) **;
		data _null_;
			set &work.sc end = eof;
			length 	StatusHit SeverityHit RenalHit HepaticHit AgeHit ControlHit 8.
					StatusVar SeverityVar RenalVar HepaticVar AgeVar ControlVar $20.
			;
			retain 	StatusHit SeverityHit RenalHit HepaticHit AgeHit ControlHit
					StatusVar SeverityVar RenalVar HepaticVar AgeVar ControlVar
			;

			%** Does QVAL contain anything about the status (impaired etc) **;
			if findw(upcase(SCSTRESC), "IMPAIRED") and StatusHit ne 1 then do;
				StatusHit = 1;
				StatusVar = SCTESTCD;
			end;

			%** Does QVAL contain anything about the severity? **;
			if (findw(upcase(SCSTRESC), "NORMAL") or findw(upcase(SCSTRESC), "SEVERE") or 
				findw(upcase(SCSTRESC), "MODERATE")) and SeverityHit ne 1 then do;
				SeverityHit = 1;
				SeverityVar = SCTESTCD;
			end;

			%** Does QVAL contain anything about Renal status? **;
			if findw(upcase(SCSTRESC), "RENAL") and RenalHit ne 1 then do;
				RenalHit = 1;
				RenalVar = SCTESTCD;
			end;

			%** Does QVAL contain anything about Hepatic status? **;
			if findw(upcase(SCSTRESC), "HEPATIC") and HepaticHit ne 1 then do;
				HepaticHit = 1;
				HepaticVar = SCTESTCD;
			end;

			%** Does QVAL contain anything about age? **;
			if findw(upcase(SCSTRESC), "ELDERLY") and AgeHit ne 1 then do;
				AgeHit = 1;
				AgeVar = SCTESTCD;
			end;

			%** Does QVAL contain anything about controls? **;
			if findw(upcase(SCSTRESC), "CONTROL") and ControlHit ne 1 then do;
				ControlHit = 1;
				ControlVar = SCTESTCD;
			end;

			%** Did we get a hit? **;
			%** If Renal / Hepatic is found assume the grouping is in that variable **;
			if eof then do;
				if RenalHit then do;
					call symputx("GroupVar", RenalVar);
				end; 
				else if HepaticHit then do;
					call symputx("GroupVar", HepaticVar);
				end;
				else if SeverityHit then do;
					call symputx("GroupVar", SeverityVar);
				end;
				else if StatusHit then do;
					call symputx("GroupVar", StatusVar);
				end;
				else if AgeHit then do;
					call symputx("GroupVar", AgeVar);
				end;
				else if ControlHit then do;
					call symputx("GroupVar", ControlVar);
				end;

				if StatusHit or RenalHit or HepaticHit  or SeverityHit or AgeHit or ControlHit then do;
					call symputx("GotGroup", 1);
				end;
			end;
		run;

		%** If we found a hit extract the content **;
		%if &GotGroup. ne %then %do;
			proc sort data = &Input.(rename = (&SequenceVar. = _&SequenceVar._));
				by &UsubjidVar.;
			run;

			proc sort data = &work.sc(where = (SCTESTCD = "&GroupVar.") rename = (SCSTRESC = &SequenceVar.));
				by &UsubjidVar.;
			run;

			data &Input.;
				merge	&Input. (in = a)
						&work.sc (in = b keep = &UsubjidVar. &SequenceVar.);
				by &UsubjidVar.;
				if a;

				%** FIXME - Should not be necessary and should be removed!! **;
				%** For any reason that we dont have a group - set it as healthy  **;
				if &SequenceVar. = "" then do;
					&SequenceVar. = "HEALTHY";
				end;
			run;
		%end;
	%end;

	%if &GotGroup. ne %then %do;
		%** Count the number of distinct _Sequences_ **;
		proc sql noprint;
			select 
				count(distinct _&SequenceVar._)
			into
				:SeqCount
			from
				&Input.
			;
		quit;
		
		%** If we have more than two combine the new group with the old one (handle different dosing) **;
		%if &SeqCount. > 1 %then %do;
			data &Input.;
				length &SequenceVar. $50.;
				set &Input.;
				&SequenceVar. = strip(&SequenceVar.) || " - " || strip(_&SequenceVar._);
			run;
		%end;
	%end;
%end;
%else %do;
	%put Warning: No possible to identify data path;
	%put Warning: SmParallelGrouping;
%end;

%mend;
