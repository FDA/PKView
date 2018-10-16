/******************************************************/
%* Determing the status of conditional table          *;
%* Created by                                         *;
%*            Yue Zhou(2017)                          *;
/******************************************************/
%macro IssConditionSelect();
data _null_;
set IssInOutStep2;
IF _n_=1 then call symput("DOMAIN1",DOMAIN);
RUN;

%let DOMAIN1=&DOMAIN1;
%put DOMAIN1=&DOMAIN1;
%macro notempty;
%IF  &DOMAIN1 eq no data %then %do;
%put IssInOutStep2 is empty; 
%PUT ADAE=&ADAE;
%PUT ADSL=&ADSL;
%end;
%else %if &DOMAIN1 eq ADAE or &DOMAIN1 eq ADSL %then %do;
%put IssInOutStep2 is not empty;
PROC SORT DATA=IssInOutStep2(KEEP = DOMAIN) NODUPKEY OUT=NEWIssInOutStep2;
BY DOMAIN;
RUN;
    	data _null_; 
			set NEWIssInOutStep2 nobs=nobs; 
			call symput("nobs1", nobs); 
		run; 

	%macro Domain();
		%do m=1 %to &nobs1;
			data _null_; 
				set NEWIssInOutStep2; 
				if _n_=&m then do; 
				call symput("DOMAIN", DOMAIN); output;
				put DOMAIN=;stop; end;
			run;
	%InExclusionAeSl(DOMAIN=&DOMAIN);
	%if &DOMAIN eq ADAE %then   %do;
%let ADAE=SUBADAE;
%PUT ADAE=&ADAE;
								%end;
	%else %if &DOMAIN eq ADSL %then %do;

%let ADSL=SUBADSL;
%PUT ADSL=&ADSL;

									%end;
		%END;
	%mend Domain;
%Domain;
%end;
%mend notempty;%notempty;
%PUT ADAE=&ADAE;
%PUT ADSL=&ADSL;
%mend IssConditionSelect;
