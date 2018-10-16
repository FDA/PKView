%macro AssignCombination(input=);

%if %upcase(&StudyDesign) = CROSSOVER and &MaxNumberOfPeriods=2 %then %do;
data y;set &input;run;

data y ;set &work.adpp;run;
data y ;set y; if combination="" then combination="ZZZZZZZZZZ";run;
proc sort data=y;by CohortName &AnalytePpVar. combination;run;

data &work.y;set y;run;


data y; set y;by  CohortName &AnalytePpVar combination;if first.&AnalytePpVar then new_comb=combination;retain new_comb;run;
data y;set y;if combination ne "ZZZZZZZZZZ" and combination ne new_comb then new_comb=combination;run;

data &input;set y(drop=combination);rename new_comb=combination;run;

%end;

%if %upcase(&StudyDesign) = SEQUENTIAL and &MaxNumberOfPeriods=2 %then %do;
data y;set &input;run;

data y ;set &work.adpp;run;
data y ;set y; if combination="" then combination="ZZZZZZZZZZ";run;
proc sort data=y;by CohortName &AnalytePpVar. combination;run;

data &work.y;set y;run;


data y; set y;by  CohortName &AnalytePpVar combination;if first.&AnalytePpVar then new_comb=combination;retain new_comb;run;
data y;set y;if combination ne "ZZZZZZZZZZ" and combination ne new_comb then new_comb=combination;run;

data &input;set y(drop=combination);rename new_comb=combination;run;

%end;





%if %upcase(&StudyDesign) = CROSSOVER  and &MaxNumberOfPeriods ne 2 %then %do;

proc freq data=&work.adpp noprint;tables &AnalytePpVar./out=analyte;run;

%SmGetNumberOfObs(Input = analyte);
%let NumofAnalyte=&NumberOfObs.;
%put &NumofAnalyte;
proc freq data=&work.adpp noprint;tables Combination/out=comb;run;
data comb;set comb;if Combination="" then delete;run;
%SmGetNumberOfObs(Input = comb);
%let NumofComb=&NumberOfObs.;
%put &NumofComb;

%if &NumofComb<= &NumofAnalyte %then %do;


data y;set &input;run;

data y ;set &work.adpp;run;
data y ;set y; if combination="" then combination="ZZZZZZZZZZ";run;
proc sort data=y;by CohortName &AnalytePpVar. combination;run;

data &work.y;set y;run;


data y; set y;by  CohortName &AnalytePpVar combination;if first.&AnalytePpVar then new_comb=combination;retain new_comb;run;
data y;set y;if combination ne "ZZZZZZZZZZ" and combination ne new_comb then new_comb=combination;run;

data &input;set y(drop=combination);rename new_comb=combination;run;

%end;

%end;
%mend;
