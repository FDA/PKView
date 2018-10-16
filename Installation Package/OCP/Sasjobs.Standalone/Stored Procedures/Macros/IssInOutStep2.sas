%*****************************************************************************************;
%**                                                                                     **;
%** Get the Unique value of inclusion or exclusion variable                             **;
%**                                                                                     **;
%** Created by:                                                                         **;
%**     Yue Zhou (2017)                                                                 **;
%*****************************************************************************************;

%macro IssInOutStep2();


    %if %sysfunc(exist(websvc.IssInOutclusion)) %then %do;

data &work.IssInOutclusion;
set websvc.IssInOutclusion;
call symputx("Variable",Variable);
call symputx("Domain",Domain);
call symputx("FileLocation",FileLocation);
run;
%put x=&variable;
%put y=&Domain;
%put filelocation=&FileLocation;
%put inputfolder=&inputfolder;
	%end;

%if &variable ne and &domain ne %then %do;

    %** Debug **;
    %let InputAe =&inputfolder.&FileLocation.;
	%put Input=&inputae.;
                
        %*********************************************;
        %**             Map Demographic             **;
        %*********************************************;
        %** Read the data **;
        %SmReadAndMergeDataset(
            Input1 = &InputAe.,
            Output = &work.&Domain
        );  

data &work.IssInOutStep2_raw;
set &work.&Domain.;
keep &variable. type Domain variable;
type=vtype(&variable);
Domain="&Domain.";
variable="&variable.";
rename &variable.=value;
run;

proc sort data=&work.IssInOutStep2_raw nodupkey;
by value;
run;
data  &work.IssInOutStep2_raw;
set &work.IssInOutStep2_raw;
where not missing(value);
run;
%end;

    %** Create output datasets **;
    data &work.data NOLIST;
        length dataset $32.;
        dataset="IssInOutStep2"; output;
 	run;
        

     
    data &work.dummy_IssInOutStep2;
        length  Domain $8. variable  $200. type $1.;
        stop;
    run;
    data &work.IssInOutStep2 NOLIST;
        set &work.dummy_IssInOutStep2
            %if %sysfunc(exist(&work.IssInOutStep2_raw)) %then %do;
                &work.IssInOutStep2_raw                    
            %end;
        ;
    run;

	
%*************
%**   Debug output
%*************

%**%let inputfolder=\\&SYSHOSTNAME.\clinical\;

%if %sysfunc(exist(&work.IssInOutStep2)) %then %do;
				proc export data=&work.IssInOutStep2
		outfile="\\&SYSHOSTNAME.\Output Files\PkView\Peter\IssInOutStep2.csv"
		dbms=dlm replace;
		delimiter=',';
		run; 
	%end;




/*%**************/

%mend;
