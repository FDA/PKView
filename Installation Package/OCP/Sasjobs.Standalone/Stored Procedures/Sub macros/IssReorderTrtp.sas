%MACRO IssReorderTrtp();
	proc sort data=trtps nodupkey out=server_trtp;
	by trtp;
	run;
	proc sort data=server_trtp;
	by order;
	run;

	*separate unique value and duplicate values to different data;
	proc sort data=server_trtp nouniquekeys
	     uniqueout=singles
	           out=dups;
	by order;

	run;

*remove empty table if duplicate table does not exist;
%macro empty;
%let EMPTY=1;
	data _null_;
		set dups;
		call symput('EMPTY','0'); /* this will only occur if &DATA is not empty */
	run;


	%if &EMPTY %then %do;
		proc datasets lib=work nolist;
		delete dups; /* delete dataset */
		quit;
	%end;
%mend;
%empty;

%macro reordertrtp;
%if %sysfunc(exist(dups)) %then %do;
	%macro newtrtp;
		data nodu;
			set dups  ;
			by order;
		if first.order then seq=0;
		seq=seq+1;
		if last.order then output;
			retain seq;
			keep order seq;
		run;

		proc sort data=nodu;
		by seq;
		run;

		*get nobs of unique order duplicate group;
		data _null_;
			if nobs=0 then putlog 'There is no duplicate treatments';
		set nodu nobs=nobs;
		call symput("subnobs",nobs);
		run;



		%macro subgroup;
 			%if &subnobs. ne %then %do;	

			%do i=1 %to &subnobs;
 			data m&i.; 
			set nodu(rename=(order=order&i. )); 
			if _n_=&i. then do;
			call symput("order&i.",order&i.);
			output ;
			stop;
			end;
			run;
			%put &&order&i.;
			data newsub&i  ;
			set dups ;
 			if order=&&order&i. then output newsub&i.;
			run;


			data _null_;
			call symput("newnobs",nobs);
			set newsub&i. nobs=nobs;
			run;

			%macro subset;
				%do j=1 %to &newnobs;
 				data subgroup&j.; 
				set newsub&i.(rename=(trtp=trtp&j. )); 
				if _n_=&j. then do;
				call symput("trtp&j.",trtp&j.);
				output ;
				stop;
				end; run;
				%put &&trtp&j.;
				%end;
 

data comsubgroup&i.;
LENGTH TRT $85;
merge 
%if %sysfunc(exist(subgroup1)) %then %do;
                subgroup1           %end;
 %if %sysfunc(exist(subgroup2)) %then %do;
                subgroup2           %end;

%if %sysfunc(exist(subgroup3)) %then %do;
                subgroup3           %end;
%if %sysfunc(exist(subgroup4)) %then %do;
                subgroup4           %end;
%if %sysfunc(exist(subgroup5)) %then %do;
                subgroup5            %end;
%if %sysfunc(exist(subgroup6)) %then %do;
                subgroup6            %end;
%if %sysfunc(exist(subgroup7)) %then %do;
                subgroup7            %end;
%if %sysfunc(exist(subgroup8)) %then %do;
                subgroup8            %end;
%if %sysfunc(exist(subgroup9)) %then %do;
                subgroup9            %end;
%if %sysfunc(exist(subgroup10)) %then %do;
                subgroup10           %end;;
by order;
trt=COMPRESS(strip(trtp1) || "_" ||strip(trtp2)  
 %if %sysfunc(exist(subgroup3))  %then %do;
           || "_" ||     strip(trtp3)            %end;

%if %sysfunc(exist(subgroup4)) %then %do;
           || "_" ||     strip(trtp4)            %end;
%if %sysfunc(exist(subgroup5)) %then %do;
           || "_" ||      strip(trtp5)            %end;
%if %sysfunc(exist(subgroup6)) %then %do;
       ||  "_" ||          strip(trtp6)            %end;
%if %sysfunc(exist(subgroup7)) %then %do;
         ||  "_" ||        strip(trtp7)            %end;
%if %sysfunc(exist(subgroup8)) %then %do;
       ||  "_" ||          strip(trtp8)            %end;

%if %sysfunc(exist(subgroup9)) %then %do;
       ||  "_" ||          strip(trtp9)            %end;

%if %sysfunc(exist(subgroup10)) %then %do;
       ||  "_" ||          strip(trtp10)            %end;
);
run;

%mend;
%subset;

 

data merge_trtp;
merge server_trtp 
%if %sysfunc(exist(comsubgroup1)) %then %do;
                comsubgroup1           %end;

%if %sysfunc(exist(comsubgroup2)) %then %do;
                comsubgroup2           %end;

%if %sysfunc(exist(comsubgroup3)) %then %do;
                comsubgroup3           %end;

%if %sysfunc(exist(comsubgroup4)) %then %do;
                comsubgroup4           %end;

%if %sysfunc(exist(comsubgroup5)) %then %do;
                comsubgroup5           %end;

%if %sysfunc(exist(comsubgroup6)) %then %do;
                comsubgroup6           %end;

%if %sysfunc(exist(comsubgroup7)) %then %do;
                comsubgroup7          %end;
%if %sysfunc(exist(comsubgroup8)) %then %do;
                comsubgroup8          %end;
%if %sysfunc(exist(comsubgroup9)) %then %do;
                comsubgroup9          %end;
%if %sysfunc(exist(comsubgroup10)) %then %do;
                comsubgroup10          %end;

;
by order;
if trt=''  then trt=strip(trtp);
keep trtp order trt;
run;

%end;
			%end;
%mend;
%subgroup;

%mend newtrtp;
%newtrtp;

%end; 


%mend;
%reordertrtp;

%MEND;
