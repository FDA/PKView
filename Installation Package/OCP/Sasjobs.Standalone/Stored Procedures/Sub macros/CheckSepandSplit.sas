%macro checkSepandSplit;

	%if %nrbquote(&Separator.)  ne %then %do; 
		data a;
		set &work.sequences ;
		length treatment $ 300;
		do i=1 to (&MaxNumberOfPeriods.);
			period=i;
			output;
		end;

		data a;set a(drop=treatment);treatment=strip(scan(&SequenceVar., period, "&Separator."));
		proc freq data=a noprint;tables treatment/out=a1;run;

		%SmGetNumberOfObs(Input = a1);
		%put &NumberOfObs. ;
		%put &NumberOfSequences;

		%if  %upcase(&StudyDesign.) = CROSSOVER %then %do;
			%let maxtrt=%eval(&NumberOfSequences/2*&MaxNumberOfPeriods);
			%put maxtrt=&maxtrt;
			%if &NumberOfObs. > &maxtrt %then %let wrongsep=1;
			%else %let wrongsep=0;
			%if &wrongsep=1 %then %let separator = ;
			%put separator=&separator;
		%end;
	%end;

%mend;
