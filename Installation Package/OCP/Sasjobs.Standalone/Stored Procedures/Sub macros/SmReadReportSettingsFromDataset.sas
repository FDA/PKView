%*****************************************************************************************;
%**                                                                                     **;
%** Load report settings from the websvc dataset passed from C#                         **;
%**                                                                                     **;
%** Created by Eduard Porta (2015-06-22)                                                **;
%**                                                                                     **;
%*****************************************************************************************;


%macro SmReadReportSettingsFromDataSet();

    %global cohort_sel ref_sel anal_sel param_sel method_sel sort_list ReportFolder SortFiles;
    %** Retrieve user settings **;
    data _null_;
        set websvc.reportConfig end = eof;
        if Name="Name" then 
        call symputx("ReportFolder", value, "G");
    run;


    %** Retrieve the references **;
    data &work.references;
        set websvc.references;
    run;
    
    %** Retrieve selected parameters **;
    data &work.parameter;
        set websvc.parameter;
    run;
    
    %** Retrieve selected analytes **;
    data &work.analyte;
        set websvc.analyte;
    run;
    
    %** Retrieve selected analytes **;
    data &work.method;
        set websvc.method;
    run;
    
    %** Retrieve selected analytes **;
    data &work.sort;
        set websvc.sort;
    run;
    
    %** Determine file sorting rules **;
    data _null_;
        set &work.sort end = eof;
        if Level="files" then 
        call symputx("SortFiles", sortOrder, "G");
    run;   

    * created on 06/21/2015
     macrovar: cohort, reference, parameteres;
    *use ORDER BY for listing references- FIX ME (genreate warning may need fix);
    *onetable or by cohort? cohort, reference, parameters,analyte, method;
    proc sql noprint;
        select distinct cohort
        into: cohort_sel separated by "$"
        from &work.references;

        select distinct reference 
        into :ref_sel separated by "$"
        from &work.references
        order by cohort;

        select distinct analyte
        into :anal_sel separated by "$"
        from &work.analyte;

        select distinct parameter
        into :param_sel separated by "$"
        from &work.parameter;

        select distinct method
        into :method_sel separated by "$"
        from &work.method;
    quit;

    /* DEBUG */
    %put cohort_sel=&cohort_sel;
    %put ref_sel=&ref_sel;
    %put anal_sel=&anal_sel;
    %put param_sel=&param_sel;
    %put method_sel=&method_sel;
    %put sortfiles=&SortFiles;

proc transpose data=&work.sort out=&work.sortt;
var sortorder;
run;

data &work.sortt( keep=COL3 COL2 COL1 _NAME_  rename= (COL3=columns  COL2=folders  COL1=files _NAME_=LEVEL));
set &work.sortt;
run;


data &work.sortt;
set &work.sortt; 
columns=TRANWRD(columns,",", "@");
run; 


proc sql noprint;
select distinct columns
into: sort_list
from &work.sortt;
quit;
 

%put sort_list=&sort_list;
 
%mend SmReadReportSettingsFromDataSet;
