%*****************************************************************************************;
%**																						**;
%**	Transfor xpt datasets to the web-service											**;
%**																						**;
%** Output:                                                                             **;
%**		Converted xpt file 																**;
%**																						**;
%**	Created by:																			**;
%**		Jens Stampe Soerensen  (2013/2014)                                              **;
%**																						**;
%*****************************************************************************************;

%macro test4variability();

libname output "C:\forsas9.4";
proc datasets library=websvc;
copy out=output; 
run;
%mend test4variability;

