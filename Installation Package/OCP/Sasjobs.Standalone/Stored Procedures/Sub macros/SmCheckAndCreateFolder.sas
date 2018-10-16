%*****************************************************************************************;
%**																						**;
%**	Checks whether a folder exist. If it does not exist - create it                     **;
%**																						**;
%**	Input:																				**;
%**		BasePath        -		Path to folder		                				**;
%**									(eg. C:\myfolder)									**;
%**		FolderName				-		Name of the folder to check or create within 		**;
%**									BasePath (eg. Forest Plot)						**;
%** Output:                                                                             **;
%**		None                                     										**;
%**																						**;
%**	Created by:																			**;
%**		Jens Stampe Soerensen  (2013/2014)                                              **;
%**																						**;
%*****************************************************************************************;
%macro SmCheckAndCreateFolder(
		BasePath = ,
		FolderName =
);

%** Local macro variables **;
%local folder folderpath;

%** Checks **;
%if %nrbquote(&BasePath.) ne and %nrbquote(&FolderName.) ne %then %do;
	%let folder = &BasePath.\&FolderName.;
%end;
%else %do;
	%let folder = &BasePath.;
%end;

%** Check if the folder exist, if not create it **;
%local rc fileref;
%let rc = %sysfunc(filename(fileref, &folder.)) ;
%if %sysfunc(fexist(&fileref.))  %then
	%put NOTE: The directory "&folder." exists ;
%else %do;
	%let folderpath = %sysfunc(dcreate(&FolderName., &BasePath.));
	%put NOTE: The directory has been created at &BasePath.\&FolderName.;
	%put NOTE: Value of folderpath = &FolderPath.;
%end ;
%let rc=%sysfunc(filename(fileref)) ;

%mend;
