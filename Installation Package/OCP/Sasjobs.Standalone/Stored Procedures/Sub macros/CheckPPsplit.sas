%macro checkppsplit(input=,splitvar= );

%if %SYMEXIST(periodppvar) and &input=&work.adpp %then %do;
%if &ReAsignMaxNumberOfPeriods=0 %then %do;

proc freq data=&input noprint;
tables &periodppvar*&splitvar/out=split_freq;run;

proc sort data=split_freq;by &periodppvar &splitvar count;run;
data split_freq;set split_freq;by &periodppvar &splitvar count;if last.&periodppvar then output;rename &splitvar=new_split;run;

proc sort data=&input;by &periodppvar;
proc sort data=split_freq;by &periodppvar;

data adpp_jiaxiang;merge &input split_freq;by &periodppvar;

data &input;set adpp_jiaxiang(drop=&splitvar);rename new_split=&splitvar;run;
%end;

%if &ReAsignMaxNumberOfPeriods=1 %then %do;
proc freq data=&input noprint;
tables &periodppvar*&splitvar/out=split_freq;run;

proc sort data=split_freq;by &periodppvar;

data split_freq;set split_freq; by &periodppvar;if first.&periodppvar then new_Split+1;retain new_split;run;

proc sort data=&input;by &periodppvar;
proc sort data=split_freq;by &periodppvar;

data adpp_jiaxiang;merge &input split_freq;by &periodppvar;

data &input;set adpp_jiaxiang(drop=&splitvar);rename new_split=&splitvar;run;

%end;
%end;

%mend;
