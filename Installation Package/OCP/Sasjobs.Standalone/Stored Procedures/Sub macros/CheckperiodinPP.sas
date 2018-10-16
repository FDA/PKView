
%macro CheckPeriodinPP(
    UsubjidVar = ,
);

%global PeriodPPfreq;
%let PeriodPPfreq=1;
%let ii=1;
%do %until(&PeriodPPfreq > 1 | &ii > 4);
    %let ii = %eval(&ii + 1);
    
    ** Try and map **;
    %SmMapDmPcPp(
    Input = &work.pp_cols,
    Type = pp);

    %put &periodppvar;

    %if %length(&periodppvar) ne 0 %then %do;
        proc freq data= &work.pp noprint ;
            tables &periodppvar/out=PeriodPPfreq_&ii.;
        run;

        data _NULL_;
            if 0 then set PeriodPPfreq_&ii. nobs=n;
            call symputx('PeriodPPfreq',n,"G");
            stop;
        run;

        %put &PeriodPPfreq;
        %put &periodppvar;

        %if &PeriodPPfreq =1 %then %do;
            data &work.pp_cols; 
                set &work.pp_cols;
                if colname= "&periodppvar" then delete;
            run;
        %end;
    %end;
    %put &ii;
%end;
%mend;
