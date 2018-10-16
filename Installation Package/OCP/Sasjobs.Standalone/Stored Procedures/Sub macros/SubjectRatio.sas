
*******************************************************************
************Created by Meng Xu*************************************
****************11/2016********************************************
*******************************************************************
*******************************************************************;

%macro SubjectRatio(
DSN=,
WIDEDSN=,
TRT=,
RESULT=,
ORDER=,
OUTPUT=
);

/*remove duplicate*/
data &DSN;
set &DSN;
OrgResult=exp(&resultvar.);
run;

proc contents data=&DSN out=ALLVAR noprint;
run;

proc sql noprint;
select distinct name into: allvarlist separated by " " from ALLVAR;
quit;
%put allvarlist=&allvarlist;

proc sort data=&DSN nodupkey;
by &allvarlist ;
run;

/*transform treatment*/
proc sql noprint;
select distinct &TRT  into: trtlist separated by "$" from &DSN;
quit;
%put trtlist=&trtlist;

data &DSN;
set &DSN;
%do n = 1 %to %sysfunc(countw(%quote(&trtlist.), $));
if &TRT ="%scan(%quote(&trtlist.), &n., $)"  then trtformat="TRT&n.";
%end;
run;


/*prepare wide format to calculate subject ratio*/

proc sort data=&DSN;
by &ORDER;
run;

proc transpose data=&DSN out=&WIDEDSN LET;
by &ORDER;
id trtformat;
var &result;
run;


/*calculate ratios*/
%do a=1 %to %sysfunc(countw(%quote(&trtlist.), $));
    %do b=1 %to %sysfunc(countw(%quote(&trtlist.), $));

        %if &a<&b %then %do;
            /*subratio2 and comparison2 are reverted results of subratio1 and comparison1*/
            data &WIDEDSN&a.&b.;
              set &WIDEDSN;
                    Comparison1="%Scan(%nrquote(&trtlist.),&a,$) ~vs~ %Scan(%nrquote(&trtlist.),&b,$)";
                    SubRatio1=TRT&a/TRT&b;
                    Comparison2="%Scan(%nrquote(&trtlist.),&b,$) ~vs~ %Scan(%nrquote(&trtlist.),&a,$)";
                    SubRatio2=TRT&b/TRT&a;
              drop _name_ _label_;
            run;
        %end;
    %end;
%end;
/*ratio=0 ratiorev=.*/

/*OUTPUT Subject Ratio results*/
data &OUTPUT;
    set %do a=1 %to %sysfunc(countw(%quote(&trtlist.), $));
           %do b=1 %to %sysfunc(countw(%quote(&trtlist.), $));
                %if &a.<&b. %then %do;
                    &WIDEDSN&a.&b.
                %end;
            %end;
         %end;;
if SubRatio1 eq . then delete;
run;


%mend;
