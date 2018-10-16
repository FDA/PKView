%*****************************************************************************************;
%**                                                                                     **;
%** Packaging script to organize pkView results in a zip file                           **;
%**                                                                                     **;
%** Created by:                                                                         **;
%**     Eduard Porta Martin Moreno (2014)                                               **;
%**                                                                                     **;
%*****************************************************************************************;
%macro PkViewCreateMetaPackage();

    %** Read the InputFolder **;
    %if %sysfunc(exist(websvc.sasdata)) %then %do;
        data _null_;
            set websvc.sasdata;
            call symputx("ndaName", ndaName);
            call symputx("userName", userName);
            call symputx("ProfileName", profileName);
			call symputx("activeSupplement", activeSupplement);
			call symputx("foldername", foldername);

        run;
		%let activeSupplement=%sysfunc(dequote(&activeSupplement));
        %let activeSupplement=%sysfunc(trim(&activeSupplement));

    %end;
    %put &ndaName;
    %put &userName;
    %put &ProfileName;
    %put &activeSupplement;
	 %put &foldername;
    %** Compose output path name on NDA Id, User Id and settings Id **;
    %let OutputFolder = &SasSpPath.\Output Files\PKView\&UserName.\&ProfileName.\&ndaName.\&activeSupplement.\&foldername.;

    %** Debug **;
	    %put foldername = &foldername.;

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

%mend PkViewCreateMetaPackage;

