%*****************************************************************************************;
%**                                                                                     **;
%** Load report settings from the websvc dataset passed from C#                         **;
%**                                                                                     **;
%** Created by Eduard Porta (2015-06-22)                                                **;
%**                                                                                     **;
%*****************************************************************************************;


%macro SmReadReportSettingsNca();

    %global ReportFolder;
    
    %** Retrieve user settings **;
    data _null_;
        set websvc.reportConfig end = eof;
        if Name="Name" then call symputx("ReportFolder", value, "G");
    run; 

    /* Retrieve concentration curves */
    data &work.concentration;
        set websvc.concentration;
    run;
    
    /* Retrieve pk values */
    data &work.pharmacokinetics;
        set websvc.pharmacokinetics;
    run;    
 
%mend SmReadReportSettingsNca;
