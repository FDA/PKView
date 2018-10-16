/************************************************************************/
/* Using conditional criteria to subset origianl ADAE and ADSL          */
/* Created by:                                                          */
/*				     Yue Zhou (2017)                                    */
/************************************************************************/


%macro InExclusionAeSl(DOMAIN=);
%*get the criteria for ADAE;
data &DOMAIN._inex;
set IssInOutStep2;
where Domain="&DOMAIN" ;
RUN;
%*Get the unique value of variables;
proc sort  data=&DOMAIN._inex nodupkey out=uni&DOMAIN.;
by variable;
run;
%*get the number of unique varibles;
data uni&DOMAIN.; 
set uni&DOMAIN. nobs=nobs;
call symputx("nobs",nobs);
run;
%put nobs=&nobs.;
%macro Getinex();
%do j=1 %to &nobs;
%global criteria&j;

%*separate criteria table according to variable name;
			data _null_; 
			set uni&DOMAIN; 
			if _n_=&j then do; 
			call symputx("variable&j", variable); output;
			stop; 
			end; run;
			data sub_uni&DOMAIN.&j.;
			set &DOMAIN._inex;
			where variable="&&variable&j.";
			run;
			%put variable&j.=&&variable&j.;

data _null_;
set sub_uni&DOMAIN.&j nobs=ob&j.;
call symputx("ob&j.",ob&j.);
run;
%put ob&j.=&&ob&j.;
%macro sep_rule();
%do i=1 %to &&ob&j.;

data _null_;
set sub_uni&DOMAIN.&j.;
if _n_=&i. then do;
call symput("type",type);output;
call symput("relation",relation);output;
call symput("inex",inex);output;
call symput("variable&j",variable);output;
call symput("value&i",value);output;end;
run;
%put value&i.=&&value&i.;
%put inex=&inex.;
%put variable&j=&&variable&j;
%end;

%*read criterion line by line in each variable table;
%IF &inex.=IN %THEN %DO;
%if ob&j.>1 %then %do;
%do i=2 %to &&ob&j.;
%let op&i=or &&variable&j.  &relation "&&value&i.";
%put op&i=&&op&i.;
%end;
%*create a macro variable criteria which equal to first selection criteria(&variable &relation "&value1" );
%let criteria&j=&&variable&j.  &relation "&value1" ;
%put criteria&j=&&criteria&j;
%*create a loop add other criteria(count start from 2) of one variable in to one macro variable;
%do i=2 %to &&ob&j.;
%let criteria&j=&&criteria&j &&op&i.;
%put criteria&j=&&criteria&j;
%end;
%end;
%*if only have one observation, then criteria only contain first criteria;
%else %if ob&j.=1 %then %do;
%let criteria&j=&&variable&j.  &relation "&value1" ;
%put criteria&j=&&criteria&j;
%end;
%END;
%*same rule for Exclusion criteria, only add not into the criteria;
%IF &inex.=EX %THEN %DO;
%if ob&j.>1 %then %do;
%do i=2 %to &&ob&j.;
%let op&i=and &&variable&j. not &relation "&&value&i.";
%put op&i=&&op&i.;
%end;
%let criteria&j=&&variable&j. not &relation "&value1" ;
%put criteria&j=&&criteria&j;
%do i=2 %to &&ob&j.;
%let criteria&j=&&criteria&j &&op&i.;
%put criteria&j=&&criteria&j;
%end;
%end;

%else %if ob&j.=1 %then %do;
%let criteria&j=&&variable&j. not &relation "&value1" ;
%put criteria&j=&&criteria&j;
%end;
%END;


%mend;%sep_rule;
%end;
%*combine all the criteria for all variables into one macro variable;
%let criteria=&criteria1;
%if &nobs.>1 %then %do;
%do k=2 %to &nobs;
%let criteria=(&criteria)and (&&criteria&k.);
%put criteria=&criteria;
%end;
%end;
%else %if &nobs.=1 %then %do;
%let criteria=(&criteria);
%put criteria=&criteria;
%end;
%*use all the criteria to get the subset of adae;
data sub&DOMAIN;
set &DOMAIN;
if &criteria.;
run;

%mend;
%Getinex;

%mend;
