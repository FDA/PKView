*ProcessBody;

%global SasSpPath;
options nofmterr compress = yes mprint spool notes msglevel=n linesize = 256
sasautos = (sasautos "&SasSpPath.\Macros" "&SasSpPath.\Sub Macros");

libname user "%sysfunc(getoption(work))" ACCESS=TEMP FILELOCKWAIT=20;
%let work = user.;

/* Path where NDAs are stored in the server */
%let inputfolder=\\localhost\clinical\;

%PkViewListPotentialReference;