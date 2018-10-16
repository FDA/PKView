*ProcessBody;

%global SasSpPath;
options nofmterr compress = yes mprint spool sasautos = (sasautos "&SasSpPath.\Macros" "&SasSpPath.\Sub Macros");

libname user "%sysfunc(getoption(work))" ACCESS=TEMP FILELOCKWAIT=20;
%let work = user.;

ods path &work.templat(update) 
    sasuser.templat(read)
    sashelp.tmplmst(read)
;

%TransferDataSetToWeb;

