%macro Checkcohort(input=);

%if %sysfunc(exist(&input)) and &input = &work.adpp_w1  %then %do;

proc sql noprint;
	select max(CohortNumber)
	into:CheckNumberOfCohorts
	from &input;
quit;
%put CheckNumberOfCohorts=&CheckNumberOfCohorts;
%put NumberOfSequences=&NumberOfSequences;
%global Wrongcohort;
%let Wrongcohort=0;
%if &NumberOfSequences=&CheckNumberOfCohorts  and %upcase(&StudyDesign.)= CROSSOVER %then %let Wrongcohort=1;
%put Wrongcohort=&wrongcohort;

%if &Wrongcohort=1 and &periodppvar ne NumPerVar  %then %do;

data &work.dm2;set &work.dm2(keep=ARM Cohort_Trt Cohort_Num);

proc sort data=&work.dm2 out=cohort_jiaxiang nodupkey;by ARM Cohort_Trt Cohort_Num;run;

data cohort_jiaxiang;set cohort_jiaxiang;
length cohortname $300.;
rename Cohort_Trt=cohortDescription;
rename Cohort_Num=cohortnumber;
CohortName="cohort "||strip(Cohort_Num);run;

data &work.adpp_w1;set cohort_jiaxiang;run;

%end;


%if  %upcase(&StudyDesign.)= SEQUENTIAL and &NumberOfSequences ne &CheckNumberOfCohorts %then %let Wrongcohort=1;
		%if &Wrongcohort=1  and %upcase(&StudyDesign.)= SEQUENTIAL %then %do;
		%let Input=&work.adpp;
			proc sort data = &Input.;
						by &SequenceVar.;
					run;
			data cohort_jiaxiang;
			    set &Input._w1;
						by &SequenceVar.;
						if first.&SequenceVar. then do;
							Cohort_Num + 1;
						end;
					run;
			data &work.adpp_w1;set cohort_jiaxiang(drop=CohortNumber);
		rename Cohort_Num=cohortnumber;
		Cohortname="cohort "||strip(Cohort_Num);
		cohortDescription=cohortname;run;

		%end;
%end;

%mend;
