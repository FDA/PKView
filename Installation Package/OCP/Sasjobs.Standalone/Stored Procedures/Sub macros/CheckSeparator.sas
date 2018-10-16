%macro checkseparator(input=&input);

%if &input=&work.adpp %then %do;
   
    /* Define wrongsparator to avoid error when &input has zero observations */
    %global wrongseparator;  
	data _null_;
        set &input.;
        call symputx("wrongseparator","0","G");
        if index(&SequenceVar.,"Sequence") ne 0 then 
            call symputx("wrongseparator","1","G");
	run;

	%if &wrongseparator.=1 %then %do;
        data &input.;set &input.;
            TreatmentInPeriodText=&PeriodVar.;
            TreatmentInPeriod= &PeriodVar.;
        run;
        %let TreatInPeriodExist = 1;
	%end;
%end;

%mend;
