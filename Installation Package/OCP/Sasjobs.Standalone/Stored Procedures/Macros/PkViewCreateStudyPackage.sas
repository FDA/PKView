%*****************************************************************************************;
%**                                                                                     **;
%** Packaging script to organize pkView results in a zip file                           **;
%**                                                                                     **;
%** Created by:                                                                         **;
%**     Feng Wang (2016)                                               **;
%**                                                                                     **;
%*****************************************************************************************;
%macro PkViewCreateStudyPackage();

    %** Read the InputFolder **;
    %if %sysfunc(exist(websvc.sasdata)) %then %do;
        data _null_;
            set websvc.sasdata;
            call symputx("ndaName", ndaName);
            call symputx("userName", userName);
            call symputx("ProfileName", profileName);
            call symputx("activeSupplement", activeSupplement);
            call symputx("activeStudy", activeStudy);
        run;
        %let activeSupplement=%sysfunc(dequote(&activeSupplement));
        %let activeSupplement=%sysfunc(trim(&activeSupplement));
    %end;
    

    %put &ndaName;
    %put &userName;
    %put &ProfileName;
    %put &activeSupplement;
    %put &activeStudy;

    %** Compose output path name on NDA Id, User Id and settings Id **;
    %let OutputFolder = &SasSpPath.\Output Files\PKView\&UserName.\&ProfileName.\&ndaName.\&activeSupplement.\&activeStudy.;

    %** Debug **;
    %put activeSupplement = &activeSupplement.;
    %put OutputFolder = &OutputFolder.;

    %** Zip the output folder **;
    %SmListFilesInFolder(
        Path = &OutputFolder.,
        Out = &work.not_used
    );

    %SmZipOutputFolder(
        OutputFolder = &OutputFolder.,
        FolderContent = &work.files_found,
        ZipName = %scan(%nrbquote(&OutputFolder.),-1,\)
    );

%mend PkViewCreateStudyPackage;

