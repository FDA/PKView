%macro CheckifvarexistinAData(varname=, data=);

%global varexist;

data one11;
  dsid=open("&data");
  check=varnum(dsid,"&varname");
  if check>0 then call symputx("varexist", 1,"G");
  else call symputx("varexist", 0,"G");
run;

%put varexist=&varexist;
%mend;


