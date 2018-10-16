%macro IssRemoveDir(dir);
options noxwait;
%local rc fileref;
%let rc =%sysfunc(filename(fileref,&dir));/* This sysfunc and the filename statements check for the existence of thedirectory */ 

%if %sysfunc(fexist(&fileref))%then %do;
	%put Removing directory &dir...;
	%sysexec rmdir/Q/S "&dir";/* Options /Q for quiet mode with no prompting and /S for removing sub directories*/
	%if &sysrc eq 0 %then 
	%put The directory &dir and its sub-directories have been deleted.;
	%else 
	%put There was a problem while Removing the directory &dir;
									%end;
%else %put The directory &dir does not exist;
%mend IssRemoveDir;
