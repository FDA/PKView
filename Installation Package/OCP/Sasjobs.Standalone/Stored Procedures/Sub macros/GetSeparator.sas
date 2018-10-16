%macro GetSeparator;

%global ReAsignMaxNumberOfPeriods;
%let ReAsignMaxNumberOfPeriods=0;


%** Read the data **;
%SmReadAndMergeDataset(
	Input1 = &InputPp.,
	UsubjidVar = &UsubjidVar.,
	Output = &work.pp
);

/* Replace PP:Visit variable with custom one */
%if &UseCustomPpVisit.=1 %then %do;
    proc sort data = &work.pp; by &PpVisitVar.; run;
    proc sort data = &work.customPpVisit; by OldValue; run;
    data &work.pp(rename=(NewValue=&PpVisitVar.));
        merge &work.pp(rename=(&PpVisitVar.=OldValue) in=hasData)
              &work.customPpVisit;
        by OldValue;
        if hasData;
    run;
%end;

%CheckifvarexistinAData(varname=&periodppvar, data=&work.pp);

%if %nrbquote(&Separator.)  eq and %SYMEXIST(PeriodppVar) and %length(&PeriodppVar) ne 0 and &varexist=1 %then %do;
%put PeriodppVar=&PeriodppVar;



proc freq data=&work.pp noprint;tables &periodppvar/out=period_jiaxiang;run;

%SmGetNumberOfObs(Input = period_jiaxiang);
%let MaxNumberOfPeriodsJG=&NumberOfObs;
%put MaxNumberOfPeriodsJG=&MaxNumberOfPeriodsJG;



%*********************************************************;
%**														**;
%** 			Separator identification				**;
%**														**;
%*********************************************************;

%** Find what separator to use **;
%let Separator = ;
%let HitList = ;
%let HitCount = ;
/* %if %upcase(&StudyArea.) ne INTRINSIC %then %do i = 1 %to &NumberOfSequences.; FIXME */
%if %upcase(&StudyDesign.) ne PARALLEL %then %do i = 1 %to &NumberOfSequences.;
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
	%let SeparatorList = %str(:)~!~%str(;)~!~%str(/)~!~%str(-)~!~%str(&)~!~%str(+);
	%let NumberOfSeparators = %eval(&MaxNumberOfPeriodsJG. - 1);

    %put SeparatorListFull=&SeparatorListFull;
	%put NumberOfSeparators=&NumberOfSeparators;
	%put SeparatorList=&SeparatorList;
	%if %eval(&NumberOfColon. + &NumberOfSemiColon. + &NumberOfSlash. + &NumberOfDash. + &NumberOfPluses. + &NumberOfAmpersand.) ^= 0 %then %do;
		%do j = 1 %to 6;
			%if %scan(&SeparatorListFull., &j., "~!~") = &NumberOfSeparators. %then %do;
				%if %nrbquote(&HitList.) eq %then %do;
					%let HitList = %scan(&SeparatorList., &j., "~!~");
					%let HitCount = %eval(&HitCount + 1);
				%end;
			%end;
		%end;

        %put HitCount=&Hitcount;
        %put HitList=&HitList;
		%** If there is only one match then use that as the separator **;
		%if &HitCount. = 1 %then %do;
			%let Separator = &HitList.;
		%end;
	%end;
	%else %if &Separator. eq %then %do;
		%let Separator = ;
	%end;
%end;
		%if &HitCount. = 1 %then %do;
			%let Separator = &HitList.;
		%end;
%put Seperator before: &Separator.;
%** Additional checks to ensure that separators are indeed present (might not always be the case) **;
data _null_;
	set &work.sequences end = eof;
	if count(&SequenceVar., "&Separator.") then do;
		counter + 1;
	end;

	if eof then do;
		/* FIXME - added or counter = 0 */
		if counter < (&NumberOfSequences. - 1) or counter = 0 then do;
			call symputx("Separator", "");
		end;
	end; 

	drop counter;
run;

%** Debug **;
%put Separator is: &Separator.;


   %if %nrbquote(&Separator.)  ne %then %do;
     %let MaxNumberOfPeriods=&MaxNumberOfPeriodsJG;
     %let ReAsignMaxNumberOfPeriods=1;
   %end;



%end;



%mend;

