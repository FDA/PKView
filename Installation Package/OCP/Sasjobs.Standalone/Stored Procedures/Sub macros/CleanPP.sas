%macro CleanPP(input= );

data x;set &input ;run;

proc sort data=x; by cohortnumber &ANALYTEPPVAR &periodppvar;run;

proc freq data=x noprint;tables TreatmentInPeriod/ out=x1;by cohortnumber &ANALYTEPPVAR  &periodppvar;run;

data &work.x1;set x1;run;

data x1;set x1; if TreatmentInPeriod='' then TreatmentInPeriod="ZZZZZZZZZZZZZZ";run;


proc sort data=x1;by CohortNumber &ANALYTEPPVAR &periodppvar TreatmentInPeriod COUNT ;run;

data x1; set x1;by CohortNumber &ANALYTEPPVAR &periodppvar TreatmentInPeriod COUNT ;
if  first.&periodppvar then freq=1; else freq=0;run;


proc sort data=x;by CohortNumber &ANALYTEPPVAR &periodppvar TreatmentInPeriod;run;
proc sort data=x1;by CohortNumber &ANALYTEPPVAR &periodppvar TreatmentInPeriod;run;

data x2; merge x x1(keep=CohortNumber &ANALYTEPPVAR &periodppvar TreatmentInPeriod freq) ; 
by CohortNumber &ANALYTEPPVAR &periodppvar TreatmentInPeriod;run;


proc sort data=x2; by CohortNumber &ANALYTEPPVAR &periodppvar TreatmentInPeriod freq;run;

data x2;set x2;
if freq=1 then do;
new_treatmentinperiod= treatmentinperiod;
new_treatmentinperiodtext=treatmentinperiodtext;
new_combination=Combination;
retain new_treatmentinperiod new_treatmentinperiodtext new_combination;
end;
run;

%global PPwrongassignment;
%let PPwrongassignment=0;

data x1;set x1;
if freq=0 then call symputx("PPwrongassignment","1","G");
run;

%put PPwrongassignment=&PPwrongassignment;

%if &PPwrongassignment=1 and %upcase(&StudyDesign.) = SEQUENTIAL %then %do;
data &input;
set x2(drop=treatmentinperiod treatmentinperiodtext Combination);
rename new_treatmentinperiod= treatmentinperiod;
rename new_treatmentinperiodtext=treatmentinperiodtext;
rename new_combination=Combination;
run;

%end;


%mend;
