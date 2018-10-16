*ProcessBody;

%global SasSpPath;
options nofmterr compress = yes mprint nospool sasautos = (sasautos "&SasSpPath.\Macros" "&SasSpPath.\Sub Macros");

libname user "%sysfunc(getoption(work))" ACCESS=TEMP FILELOCKWAIT=20;
%let work = user.;

%PkViewCreateStudyPackage;


