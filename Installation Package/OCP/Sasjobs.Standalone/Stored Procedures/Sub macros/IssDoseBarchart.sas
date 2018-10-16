
*********************************************************************************************
*******************************  Dose distribution over time  *******************************
*********************************************************************************************;
 %macro IssDoseBarchart();

data new_AE;
set ae;
keep &Study &ID &Treatment trt;
run;
proc sort data=NEW_AE;
by   &Study &ID ;
run;
 

 
data NEW_VS; 													 
set advs; 
where &Analysis_day>0;
keep  &Study &ID  &Analysis_day;
run;
proc sort data=NEW_VS;
by &Study  &ID ;
run;
data advs1;
merge NEW_VS NEW_AE;
by &Study  &ID;
keep &Study &Treatment &ID &Analysis_day  trt;
run;
/*sort with out duplicate*/
proc sort data=advs1 out=advs2(keep=&Study &Treatment trt &ID &Analysis_day  ) nodupkey;     
by &Study &ID trt &Analysis_day;
where not missing(&analysis_day) and not missing(trt);
 run; 

proc sql;														 
create table advs3 as
select *,
count (distinct &ID) as count_ID,
count (distinct trt) as count_trt,
max( &Analysis_day) as max_day
from advs2
group by &Study;
quit;




proc sort data=advs3 out=advs4(drop=count_ID &Analysis_day count_trt) nodupkey;		 
by &Study &ID trt;
WHERE NOT MISSING(&STUDY);run; 
*Create table with all the time point entries;
data advs5 ;													 
set advs4;
by &study &ID trt;
do N_day=1 to max_day ;
output;
end;
keep &Study &ID trt N_day;
rename N_day=&Analysis_day;
New_trt=".";
run;
*sort advs5;
proc sort data=advs5 out=advs6; by &study &ID trt &Analysis_day ;run; 	 
*sort advs2;
proc sort data=advs2 out=advs7;by &study &ID trt &Analysis_day ;run;	 
*assign values to new_trt;
data advs8;													 
set advs7;
New_trt=trt;
run;
*merge orginal data with created data by study id and day;
data advs9;														 
merge  advs6 advs8;
by &Study &ID trt &Analysis_day ;
run;

*caluculate week;
data advs10;														 
set advs9;
if missing(new_trt) then new_trt="Not Treated";
Week=round(&Analysis_day/7, 1.); 
drop trt;
rename new_trt=trt;
run;

proc sort data =advs10 out=advs11; by &Study &Analysis_day;    
 run;
proc freq data = advs11 noprint; by &Study &Analysis_day;		 
table trt/out=advs12; run;



%put OutputFolder=&OutputFolder.;

        %SmCheckAndCreateFolder(
        BasePath = &OutputFolder.,
        FolderName = IssDoseBarchart
        );
        options nodate nonumber;

filename graphout "&OutputFolder.\IssDoseBarchart";
goptions reset=all device=png hsize=12in vsize=12in gsfname=graphout;
ods _all_ close;
ods listing;
ods graphics on /width=10 in height=5 in;
ods graphics /antialiasmax=2000 BORDER = off;
axis1 label=none value=none; 
axis2 label=(angle=90 'Count');
*Generate dose-distribution plot;
Title "Dose-Distribution plot over time";
proc gchart data=advs12; by &Study ;                                                                                                     
   vbar &Analysis_day/discrete subgroup=trt levels=all                                                                                         
                 group=&Analysis_day g100 nozero                                                                                               
                 freq=Count type=freq                                                                                                
                 width=4 space=0 gspace=0                                                                                              
                 gaxis=axis1 raxis=axis2                                                                                                
                 legend=legend1;
				 label trt='Treatment';
				
run;

%mend;
