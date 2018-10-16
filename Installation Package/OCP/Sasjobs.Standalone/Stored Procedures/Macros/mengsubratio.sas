
%macro mengsubratio;

%if &obsnum eq 0 %then %do;

    data plotsub;
    set result.individualpkstats;
    category="include";
    run;

%end;
%else %do;

    /*STEP 5 : generate include and exclude subject ratois plot*/
    data includesub;
    merge &work.subtoremove(in=a) result.individualpkstats(in=b);
    by CohortDescription &AnalytePPVar.  &ParameterVar. TreatmentInPeriodText usubjid;
    if b and not a;
    category="include";
    run;

    data excludesub;
    merge includesub(in=a) result.individualpkstats(in=b);
    by CohortDescription &AnalytePPVar.  &ParameterVar. TreatmentInPeriodText usubjid;
    if b and not a;
    category="exclude";
    run;

    data plotsub;
    set includesub excludesub;
    run;

%end;

proc sql noprint;
select distinct treatmentinperiodtext into: trtlist separated by "$" from plotsub;
quit;
%put trtlist=&trtlist;

data plotsub;
set plotsub;
%do n = 1 %to %sysfunc(countw(%quote(&trtlist.), $));
if Treatmentinperiodtext="%scan(%quote(&trtlist.), &n., $)"  then trtformat="TRT&n.";
%end;
run;

proc sort data=plotsub;
by category cohortdescription &AnalytePPVar.  &ParameterVar. combination usubjid;
run;


proc transpose data=plotsub out=plotsubwide let;
by category CohortDescription &AnalytePPVar.  &ParameterVar. combination usubjid;
id trtformat;
var orgppstresn;
run;




%do a=1 %to %sysfunc(countw(%quote(&trtlist.), $));
    %do b=1 %to %sysfunc(countw(%quote(&trtlist.), $));

        %if &a<&b %then %do;
            /*subratio2 and comparison2 are reverted results of subratio1 and comparison1*/
            data plotsubwide&a.&b.;
              set plotsubwide;
                    Comparison1="%Scan(%nrquote(&trtlist.),&a,$) ~vs~ %Scan(%nrquote(&trtlist.),&b,$)";
                    SubRatio1=TRT&a/TRT&b;
                    Comparison2="%Scan(%nrquote(&trtlist.),&b,$) ~vs~ %Scan(%nrquote(&trtlist.),&a,$)";
                    SubRatio2=TRT&b/TRT&a;
              drop _name_ _label_;
            run;
        %end;
    %end;
%end;
/*ratio=0 ratiorev=.*/

data SubInEx;
    set %do a=1 %to %sysfunc(countw(%quote(&trtlist.), $));
           %do b=1 %to %sysfunc(countw(%quote(&trtlist.), $));
                %if &a.<&b. %then %do;
                    plotsubwide&a.&b.
                %end;
            %end;
         %end;;
if SubRatio1 eq . then delete;
run;



/*fix plotting point label problem because point label has limit of 16 character, any usubjid
exceed 16 characters will be pretreated- leave last 16 character , and if first is - or _ then remove*/
data SubInEx;
length label $16.;
set SubInEx;
sublength=length(usubjid);
if sublength gt 16 then do;
    labelID=substr(usubjid,length(usubjid)-15,16);
    if substr(labelID,1,1)="-" or substr(labelID,1,1)="_"  then labelID=substr(labelID,length(labelID)-14,15);
end;
else do;
   labelID=usubjid;
end;
run;

/*concatenate ratio and revert ratio , comparison and revert comparison*/
/*allsubtrt split each comparison plot. subratio list all comparison in one table*/
data SubInExPlot;
set SubInEx;
array comp(2) comparison1 comparison2;
array rt(2) subratio1 subratio2;
do i=1 to 2;
comparison=comp(i);
subratio=rt(i);
output;
end;
run;




/*FIX: use parametervar*/
proc sql noprint; 
select distinct CohortDescription into : cohortforplot separated by "$" from SubInExPlot;
select distinct &AnalyteppVar. into : analyteforplot separated by "$" from SubInExPlot;
select distinct &ParameterVar. into : parametersforplot separated by "$" from SubInExPlot;
quit;
%put parametersforplot=&parametersforplot cohort for plot is &cohortforplot , analyte for plot is &analyteforplot;



%do a=1 %to %sysfunc(countw(%nrquote(&cohortforplot),$));
    %do b=1 %to %sysfunc(countw(%nrquote(&analyteforplot),$));
        %do c=1 %to %sysfunc(countw(%nrquote(&parametersforplot),$));

data SubInExPlot_&a._&b._&c;
set SubInExPlot;
where CohortDescription="%scan(%nrquote(&cohortforplot),&a.,$)" and &AnalyteVar.="%scan(%nrquote(&analyteforplot),&b.,$)"
and  &ParameterVar. ="%scan(%nrquote(&parametersforplot),&c.,$)" ;
run;


%SmCheckAndCreateFolder(
BasePath = &OutputFolder.\&StudyId.,
FolderName = InExSubratio
);
%SmCheckAndCreateFolder(
BasePath = &OutputFolder.\&StudyId.\InExSubratio,
FolderName =cohort&a.
);

%SmCheckAndCreateFolder(
BasePath = &OutputFolder.\&StudyId.\InExSubratio\cohort&a.,
FolderName =%scan(%nrquote(&analyteforplot),&b.,$)
);

%SmCheckAndCreateFolder(
BasePath =&OutputFolder.\&StudyId.\InExSubratio\cohort&a.\%scan(%nrquote(&analyteforplot),&b.,$),
FolderName =%scan(%nrquote(&parametersforplot),&c.,$)
);


ods listing  gpath = "&OutputFolder.\&StudyId.\InExSubratio\cohort&a.\%scan(%nrquote(&analyteforplot),&b.,$)\%scan(%nrquote(&parametersforplot),&c.,$)";
ods graphics on / imagename = "SubInExPlot_&a._&b._&c" noborder height=2300 width=2500 ;
filename grafout "&OutputFolder.\&StudyId.\InExSubratio\cohort&a.\%scan(%nrquote(&analyteforplot),&b.,$)\%scan(%nrquote(&parametersforplot),&c.,$)\SubInExPlot_&a._&b._&c..jpeg";
goptions reset=all gsfname=grafout gsfmode=replace device=JPEG hsize=15 vsize=12;
title "Include and Exclude Subject Ratio ";
title1 "Cohort:%scan(%nrquote(&cohortforplot),&a.,$)";
title2 "Analyte:%scan(%nrquote(&analyteforplot),&b.,$)";
title3 "Parameter: %scan(%nrquote(&parametersforplot),&c.,$)";

symbol value=triangle pointlabel=(height=9pt '#labelID');
axis1 value= (angle=45 f=simplex) offset=(25,25);
proc gplot data=SubInExPlot_&a._&b._&c;
plot subratio*category=comparison/haxis=axis1;
run;
quit;
ods listing close;
ods graphics off;

%end;
%end;
%end;

%mend;
%mengsubratio;
