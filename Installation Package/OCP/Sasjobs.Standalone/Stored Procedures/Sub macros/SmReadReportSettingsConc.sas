%*****************************************************************************************;
%**                                                                                     **;
%** Load report settings from the websvc dataset passed from C#                         **;
%**                                                                                     **;
%** Created by Eduard Porta (2015-06-22)                                                **;
%**                                                                                     **;
%*****************************************************************************************;


%macro SmReadReportSettingsConc();

    %global ReportFolder;
    
    %** Retrieve user settings **;
    data _null_;
        set websvc.reportConfig end = eof;
        if Name="Name" then call symputx("ReportFolder", value, "G");
        if Name="PpAnalyte" then call symputx("PpAnalyte", value, "G");
        if Name="PpSpecimen" then call symputx("PpSpecimen", value, "G");
        if Name="AuctName" then call symputx("AuctName", value, "G");
        if Name="AuciName" then call symputx("AuciName", value, "G");
        if Name="CmaxName" then call symputx("CmaxName", value, "G");
        if Name="TmaxName" then call symputx("TmaxName", value, "G");
        if Name="ThalfName" then call symputx("ThalfName", value, "G");
    run; 

    /* Retrieve concentration curves */
    data &work.meanConcentration;
        set websvc.meanConcentration;
    run;

 
%mend SmReadReportSettingsConc;
