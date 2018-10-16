
%macro CleanArm(
    input = ,
    output =
);

%if &SequenceVar. ne %then %do;
    data  &output; 
        set &input;
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
    run;
%end;

%mend;
