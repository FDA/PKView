%macro IssSummary3Plot();

/*get the common output folder path */

data folder;
length folderpath $250;
folderpath="&outputfolder.";
run;

data _null_; set folder;
fln1=scan(folderpath,-1,"\"); 
fln2=scan(folderpath,-2,"\"); 
fln3=scan(folderpath,-3,"\"); 
FullLength=length(folderpath); 
W1Length=length(fln1); 
W2Length=length(fln2); 
W3Length=length(fln3); 
LeftLength=FullLength-W1Length-W2Length-W3Length-3; 
SummaryFolder=substr(folderpath,1,LeftLength); 
call symput('SummaryFolder',trim(SummaryFolder));
run;
%put SummaryFolder="&SummaryFolder.";

/*check if meta and forest plot folder exist */
%macro IssCheckFolder(
		BasePath = ,
		FolderName =
);
%global exist_Meta exist_MetaVariability;
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

%if %sysfunc(fexist(&fileref.))  %then %do;
	%let exist_&FolderName.=1;
	%put NOTE: The directory "&folder." exists ;
%end;
%else %do;
	%let exist_&FolderName.=0;
	%put NOTE: There is no directory "&BasePath.\&FolderName." exists;
%end ;
%let rc=%sysfunc(filename(fileref)) ;
%mend;

%IssCheckFolder(		BasePath =&SummaryFolder. ,
		FolderName =Meta
)
%put MetaExist=&exist_Meta;
%IssCheckFolder(		BasePath =&SummaryFolder. ,
		FolderName =MetaVariability
)
%put VariabilityExist=&exist_MetaVariability;

%if &exist_Meta=1 and &exist_MetaVariability=1 %then %do;
proc import out=Variability 
	datafile="&SummaryFolder\MetaVariability\distributioninput.csv" 
	dbms=csv replace; 
	getnames=yes; 
run;


proc import out=Forest 
	datafile="&SummaryFolder.\Meta\Package\Meta_input.csv" 
	dbms=csv replace; 
	getnames=yes; 
run;
%SmCheckAndCreateFolder(        BasePath = &OutputFolder. ,
        FolderName = Summary3Plot
        );

data _null_;
set forest(obs=1);
call symput("ndavar",NDA);
call symput("lowerbound",lowerbound);
call symput("upperbound",upperbound);
run;
%put ndavar=&ndavar || lowerbound=&lowerbound ||upperbound=&upperbound;

data barchart;
set aep6;
keep &study	&id	&Treatment	&Body	&Adverse_Event		&severity SINGLE_RATE ARM NUMERICDOSE sev_level;
run;
 
data forest ;
set forest;
rename study=study2 obsID=obsid2 cohortDescription=cohortDescription2;
where not missing(NDA);
run;
data variability;
set variability;
rename usubjid=usubjid2;
where not missing(OrgMACRORESULT);
run;
data barchart;
set barchart;
where not missing(&study);
run;

/*forest plot+boxplot +barchart*/
data metabox;
set barchart variability forest;
run;

DATA _NULL_;
SET variability;
call symput("OrgMACRORESULT",vtype(OrgMACRORESULT));
run;
%put OrgMACRORESULT=&OrgMACRORESULT;
%if &OrgMACRORESULT=C %then %do;
data variability;
set variability;
   numeric_var1 = input(OrgMACRORESULT, 8.);
   numeric_var2 = input(MACRORESULT, 8.);

   drop OrgMACRORESULT MACRORESULT;
   rename numeric_var1=OrgMACRORESULT;
   rename numeric_var2=MACRORESULT;
run;
%end;
/*calculate log value for geometic mean calculation*/
DATA VARIABILITY;
SET VARIABILITY;
LOGMACRORESULT=log(MACRORESULT);
LOGOrgMACRORESULT=LOG(OrgMACRORESULT);
RUN;

/*normal auc*/
proc sort data=variability;
by dose;
run;
*calculate geometirc mean and standard error;
proc surveymeans data=variability  geomean;
var OrgMACRORESULT;
by dose; 
ods output geometricmeans=geometricmeans;run;

%let geomean=0;
%let geomean_log=0;

data _null_;
set geometricmeans;
if dose=&ClinicalDose then do;
call symput('geomean',trim(geomean));
end;
run;
%put geomean="&geomean.";

proc sql ;
create table max_dose as
select max(dose) as maxdose
from geometricmeans;
quit;
data _null_;
set max_dose;
call symput("maxdose",maxdose);
run;
%put maxdose=&maxdose;


*Using standard error calculate standard deviation;

proc means data=variability mean noprint;
var LOGOrgMACRORESULT;
by dose;
output out=LOGOrgM mean=MeanOrgM;
* merge each observation with its group mean *;
data geometricmeans_orgm;
merge variability LOGOrgM geometricmeans;
by dose;
if first.dose then do;
sum_sd=0 ;
end;
* compute geometric mean *;
Geomean_OrgM =exp(MeanOrgM);
* accumulate squared deviations ~;
squardev =(MACRORESULT - Geomean_OrgM)**2;
sum_sd + squardev;
if last.DOSE and _freq_ > 1 then do;
Stdd_OrgM =GMSTDERR*sqrt(_freq_ );
Thres_OrgM = Geomean_OrgM +(Stdd_OrgM *2);
output;
end;
RUN;
 
data _null_;
set geometricmeans_OrgM;
if dose=&maxdose then do;
call symput("MAXgeomean",geomean);
call symput("MAX_X",Thres_OrgM);
end;
run;
%put MAXgeomean=&MAXgeomean;
%PUT MAX_X=&MAX_X;







/***log x****/
proc surveymeans data=variability  geomean;
var MACRORESULT;
by dose; 
ods output geometricmeans=geometricmeans_log;run;


proc means data=variability mean noprint;
var LOGMACRORESULT;
by dose;
output out=LOGM mean=MeanM;
* merge each observation with its group mean *;
data geometricmeans_M;
merge variability LOGM geometricmeans_LOG;
by dose;
if first.dose then do;
sum_sd=0 ;
end;
* compute geometric mean *;
Geomean_M =exp(MeanM);
* accumulate squared deviations ~;
squardev =(MACRORESULT - Geomean_M)**2;
sum_sd + squardev;
if last.DOSE and _freq_ > 1 then do;
Stdd_M =GMSTDERR*sqrt(_freq_ );
Thres_M = Geomean_M +(Stdd_M *2);
output;
end;
RUN;


data _null_;
set geometricmeans_M;
if dose=&maxdose then do;
call symput("MAXgeomean_log",geomean);
call symput("MAX_X_log",Thres_M);
end;
run;
%put MAXgeomean_log=&MAXgeomean_log;
%PUT MAX_X_log=&MAX_X_log;

data _null_;
set geometricmeans_M;
if dose=&ClinicalDose then do;
call symput('geomean_log',trim(geomean));
end;
run;
%put geomean_log="&geomean_log.";


/*separate variability data by dose;*/
data variability0;
set variability;
keep dose OrgMACRORESULT MACRORESULT;
run;
proc sort data=variability0 nodupkey out=uni_var;
by dose;
run;
data single_var;
set uni_var nobs=nobs;
call symput("nobs",nobs);
run;

%put nobs=&nobs;
%macro uni_var;

%do i=1 %to &nobs;
%global dose&i.;
data _null_;set uni_var;
if _n_=&i then do;
call symput("dose&i",trim(dose));
PUT dose=;STOP;end;run;
data uni_var&i;
set variability0;where dose=&&dose&i.;
rename dose=dose&i;
rename OrgMACRORESULT=OrgMACRORESULT&i;
rename MACRORESULT=MACRORESULT&i;
run;
%put dose&i="&&dose&i.";
%end;

data metadata;
set  barchart
%do i=1 %to &nobs;
uni_var&i 
%end; forest;
run;
%mend;
%uni_var;

/*Meta forestplot variability, forest, barchart template*/
proc template;
define statgraph ForestPlotMetaVar ;
begingraph / designwidth=1400px designheight=2000;
entrytitle " Summary Plots" / textattrs = (size = 18pt weight = bold) pad = (bottom = 5px);
Layout lattice/rows=3 columns=1 rowGUTTER=50 rowdatarange=data;
 
        layout lattice ;
		layout gridded ;
			entry " AE percentage versus treatment group, subset by severity" / textattrs = (size = 15pt weight = bold) pad = (bottom = 5px);

			layout overlay/cycleattrs=true 
		    xaxisopts=(display=(tickvalues label) label="Numerical Dose" labelattrs = (size = 12pt) tickvalueattrs=(size=10pt weight=bold)
						 )
		    yaxisopts=(label="AE Prevalence" labelattrs = (size = 15pt) offsetmax=0.1 tickvalueattrs=(size=10pt weight=bold) ) ;
			barchart x=numericdose y=single_rate /group=&severity BARLABEL=TRUE barlabelattrs=(size=10pt) grouporder=ascending stat=sum dataskin=gloss name="A"
		    legendlabel="A" datatransparency=0.2   barwidth=0.5 ;
			referenceline x=&ClinicalDose. / LINEATTRS=(COLOR=gray PATTERN=solid thickness=1); 
			discretelegend "A" / title="Severity" location=inside halign=right valign=top exclude=(""".") SORTORDER=ASCENDINGFORMATTED;
			endlayout;
		endlayout;
		endlayout;

	layout gridded/valign=top ;
	entry "Meta Variability Analysis" / textattrs = (size = 15pt weight = bold) pad = (bottom = 5px);
	layout overlay / yaxisopts=(reverse=false tickvalueattrs=(size=10pt)  labelattrs = (size = 15pt) label="Density" )
		Xaxisopts=(label="Parameter"  labelattrs = (size = 12pt)  linearopts=(viewmin=0  VIEWMAX=&MAX_X.) 	);
		%do i=1 %to &nobs;
		densityplot    OrgMACRORESULT&i/ name="&&dose&i"  kernel()   
										lineattrs=(pattern=&i 
										%if &i=1 %then color=red;
											%if &i=2 %then color=blue;
												%if &i=3 %then color=green;
													%if &i=4 %then color=brown;
														%if &i=5 %then color=coral;
															%if &i=6 %then color=mediumblue;
																%if &i=7 %then color=bigb;
																	%if &i=8 %then color=gold;
																		%if &i=9 %then color=bgr;
																			%if &i=10 %then color=bip;
																				%if &i=11 %then color=bgr;
																					%if &i=12 %then color=bigy;
																						%if &i=13 %then color=bippk;
																							%if &i=14 %then color=black;
																								%if &i=15 %then color=cadetblue;
													) ;
		%end;
		discretelegend 	%do i=1 %to &nobs; "&&dose&i." 	%end;/title="Dose"   location=inside halign=right valign=top across=2  DISPLAYCLIPPED = TRUE;

  		%if &geomean ne 0 %then %do;
		referenceline x=&geomean / LINEATTRS=(COLOR=gray PATTERN=solid thickness=1); 
		%end;
	endlayout;	
	endlayout;


	layout gridded/valign=top  ;
	entry "Forest Plot" / textattrs = (size = 15pt weight = bold) pad = (bottom = 5px);
	layout lattice / columns = 3 columnweights=(0.3 0.1 0.6) border=true ;
	    layout overlay /    walldisplay = none 
	    xaxisopts = (display = none offsetmin = 0.2 offsetmax = 0.2 tickvalueattrs = (size = 8)) 
	    yaxisopts = (reverse = true display = none tickvalueattrs = (weight = bold) offsetmin = 0);
	    scatterplot y = obsid2 x = comp  /   markercharacter  =combination  markercharacterattrs=(family='Lucida Console' size=7 weight=bold  );
	    endlayout;

	    layout overlay /    walldisplay = none
	    xaxisopts = (display = none offsetmin = 0.3 offsetmax = 0.2 tickvalueattrs = (size = 8))
	    yaxisopts = (reverse = true display = none tickvalueattrs = (weight = bold) offsetmin = 0);
	    scatterplot y = obsid2 x = par      /   markercharacter  =parameter markerattrs = (size = 0);
	    endlayout;
	    
	    layout  overlay /   walldisplay = none
	    yaxisopts = (reverse = true display = none offsetmin = 0.1) 
	    xaxisopts = (tickvalueattrs = (size = 7pt) labelattrs = (size = 10pt) label = "Ratio of Geometric Means from Test against Reference and 90% CI");
	    scatterplot y = obsid2 x = ratio  / xerrorlower = lcl xerrorupper = ucl markerattrs = (size = 1.2pct symbol = diamondfilled size=6);
	    referenceline x = 1 /LINEATTRS=(COLOR=black thickness=1);
	    referenceline x = &lowerbound/LINEATTRS=(COLOR=gray PATTERN=2 thickness=1);
	    referenceline x = &upperbound/LINEATTRS=(COLOR=gray PATTERN=2 thickness=1);
	    endlayout;
		endlayout;

	endlayout;
endlayout;
endgraph;
end;
run;
/*Meta forestplot variability, forest, barchart template*/
proc template;
define statgraph ForestPlotMetaVarLogX ;
begingraph / designwidth=1400px designheight=2000;
entrytitle " Summary Plots" / textattrs = (size = 18pt weight = bold) pad = (bottom = 5px);
Layout lattice/rows=3 columns=1 rowGUTTER=50 rowdatarange=data;
 
        layout lattice ;
		layout gridded ;
			entry " AE percentage versus treatment group, subset by severity" / textattrs = (size = 15pt weight = bold) pad = (bottom = 5px);

			layout overlay/cycleattrs=true 
		    xaxisopts=(display=(tickvalues label) label="Numerical Dose" labelattrs = (size = 12pt) tickvalueattrs=(size=10pt weight=bold)
						 )
		    yaxisopts=(label="AE Prevalence" labelattrs = (size = 15pt) offsetmax=0.1 tickvalueattrs=(size=10pt weight=bold) ) ;
			barchart x=numericdose y=single_rate /group=&severity BARLABEL=TRUE barlabelattrs=(size=10pt) grouporder=ascending stat=sum dataskin=gloss name="A"
		    legendlabel="A" datatransparency=0.2   barwidth=0.5 ;
			referenceline x=&ClinicalDose. / LINEATTRS=(COLOR=gray PATTERN=solid thickness=1); 
			discretelegend "A" / title="Severity" location=inside halign=right valign=top exclude=(""".") SORTORDER=ASCENDINGFORMATTED;
			endlayout;
		endlayout;
		endlayout;

	layout gridded/valign=top ;
	entry "Meta Variability Analysis" / textattrs = (size = 15pt weight = bold) pad = (bottom = 5px);
	layout overlay / yaxisopts=(reverse=false tickvalueattrs=(size=10pt)  labelattrs = (size = 15pt) label="Density" )
		Xaxisopts=(label="Parameter"  labelattrs = (size = 12pt)  linearopts=(viewmin=0 ) 	);
		%do i=1 %to &nobs;
		densityplot    MACRORESULT&i/ name="&&dose&i"  kernel()   
										lineattrs=(pattern=&i 
										%if &i=1 %then color=red;
											%if &i=2 %then color=blue;
												%if &i=3 %then color=green;
													%if &i=4 %then color=brown;
														%if &i=5 %then color=coral;
															%if &i=6 %then color=mediumblue;
																%if &i=7 %then color=bigb;
																	%if &i=8 %then color=gold;
																		%if &i=9 %then color=bgr;
																			%if &i=10 %then color=bip;
																				%if &i=11 %then color=bgr;
																					%if &i=12 %then color=bigy;
																						%if &i=13 %then color=bippk;
																							%if &i=14 %then color=black;
																								%if &i=15 %then color=cadetblue;
													) ;
		%end;
		discretelegend 	%do i=1 %to &nobs; "&&dose&i." 	%end;/title="Dose"   location=inside halign=right valign=top across=2 DISPLAYCLIPPED = TRUE ;
		%if &geomean_log ne 0  %then %do;		
		referenceline x=&geomean_log / LINEATTRS=(COLOR=gray PATTERN=solid thickness=1); 
		%end;
	endlayout;	
	endlayout;


	layout gridded/valign=top  ;
	entry "Forest Plot" / textattrs = (size = 15pt weight = bold) pad = (bottom = 5px);
	layout lattice / columns = 3 columnweights=(0.3 0.1 0.6) border=true ;
	    layout overlay /    walldisplay = none 
	    xaxisopts = (display = none offsetmin = 0.2 offsetmax = 0.2 tickvalueattrs = (size = 8)) 
	    yaxisopts = (reverse = true display = none tickvalueattrs = (weight = bold) offsetmin = 0);
	    scatterplot y = obsid2 x = comp  /   markercharacter  =combination  markercharacterattrs=(family='Lucida Console' size=7 weight=bold  );
	    endlayout;

	    layout overlay /    walldisplay = none
	    xaxisopts = (display = none offsetmin = 0.3 offsetmax = 0.2 tickvalueattrs = (size = 8))
	    yaxisopts = (reverse = true display = none tickvalueattrs = (weight = bold) offsetmin = 0);
	    scatterplot y = obsid2 x = par      /   markercharacter  =parameter markerattrs = (size = 0);
	    endlayout;
	    
	    layout  overlay /   walldisplay = none
	    yaxisopts = (reverse = true display = none offsetmin = 0.1) 
	    xaxisopts = (tickvalueattrs = (size = 7pt) labelattrs = (size = 10pt) label = "Ratio of Geometric Means from Test against Reference and 90% CI");
	    scatterplot y = obsid2 x = ratio  / xerrorlower = lcl xerrorupper = ucl markerattrs = (size = 1.2pct symbol = diamondfilled size=6);
	    referenceline x = 1 /LINEATTRS=(COLOR=black thickness=1);
	    referenceline x = &lowerbound/LINEATTRS=(COLOR=gray PATTERN=2 thickness=1);
	    referenceline x = &upperbound/LINEATTRS=(COLOR=gray PATTERN=2 thickness=1);
	    endlayout;
		endlayout;

	endlayout;
endlayout;
endgraph;
end;
run;

options nodate nonumber;
ods listing gpath = "&OutputFolder.\Summary3Plot" style=statistical sge=on;
ods graphics on / noborder imagefmt = png imagename = "Summary3Plot" width = 1000px height = 1200;

proc sgrender data=metadata template=ForestPlotMetaVar;
run;

ods listing sge=off;
ods graphics off;

options nodate nonumber;
ods listing gpath = "&OutputFolder.\Summary3Plot" style=statistical sge=on;
ods graphics on / noborder imagefmt = png imagename = "Summary3PlotLogX" width = 1000px height = 1200;

proc sgrender data=metadata template=ForestPlotMetaVarLogX;
run;

ods listing sge=off;
ods graphics off;

/*Meta forestplot variability, forest, barchart template*/
proc template;
define statgraph ForestPlotMetaVarBox;
begingraph / designwidth=1400px designheight=2000;
entrytitle " Summary Plots" / textattrs = (size = 18pt weight = bold) pad = (bottom = 5px);
Layout lattice/rows=3 columns=1 rowGUTTER=50 rowdatarange=data;
 
        layout lattice ;
		layout gridded ;
			entry " AE percentage versus treatment group, subset by severity" / textattrs = (size = 15pt weight = bold) pad = (bottom = 5px);

			layout overlay/cycleattrs=true 
		    xaxisopts=(display=(tickvalues label) label="Numerical Dose" labelattrs = (size = 12pt) tickvalueattrs=(size=10pt weight=bold)
						 )
		    yaxisopts=(label="AE Prevalence" labelattrs = (size = 15pt) offsetmax=0.1 tickvalueattrs=(size=10pt weight=bold) ) ;
			barchart x=numericdose y=single_rate /group=&severity BARLABEL=TRUE barlabelattrs=(size=10pt) grouporder=ascending stat=sum dataskin=gloss name="A"
		    legendlabel="A" datatransparency=0.2   barwidth=0.5 ;
			referenceline x=&ClinicalDose. / LINEATTRS=(COLOR=gray PATTERN=solid thickness=1); 
			discretelegend "A" / title="Severity" location=inside halign=right valign=top exclude=(""".") SORTORDER=ASCENDINGFORMATTED;
			endlayout;
		endlayout;
		endlayout;

		layout gridded/valign=top  ;
		entry "AUC Distribution by Dose"/textattrs = (size = 15pt weight = bold) pad = (bottom = 5px) ;
        layout overlay / cycleattrs=true 
                               xaxisopts=(display=(ticks label tickvalues) label="Dose / Mg"   labelattrs = (size = 12pt weight = bold) tickvalueattrs=(size=10pt) )
                               yaxisopts=(label='AUC(Area Under the Curve) ' labelattrs = (size = 12pt weight = bold)  tickvalueattrs=(size=10pt) );
          boxplot x=dose y=OrgMACRORESULT / discreteoffset=0  boxwidth=0.2   ;
       endlayout;
	   endlayout;

	layout gridded/valign=top  ;
	entry "Forest Plot" / textattrs = (size = 15pt weight = bold) pad = (bottom = 5px);
	layout lattice / columns = 3 columnweights=(0.2 0.1 0.7) border=true ;
	    layout overlay /    walldisplay = none 
	    xaxisopts = (display = none offsetmin = 0.2 offsetmax = 0.2 tickvalueattrs = (size = 8)) 
	    yaxisopts = (reverse = true display = none tickvalueattrs = (weight = bold) offsetmin = 0);
	    scatterplot y = obsid2 x = comp  /   markercharacter  =combination  markercharacterattrs=(family='Lucida Console' size=7 weight=bold  );
	    endlayout;

	    layout overlay /    walldisplay = none
	    xaxisopts = (display = none offsetmin = 0.3 offsetmax = 0.2 tickvalueattrs = (size = 8))
	    yaxisopts = (reverse = true display = none tickvalueattrs = (weight = bold) offsetmin = 0);
	    scatterplot y = obsid2 x = par      /   markercharacter  =parameter markerattrs = (size = 0);
	    endlayout;
	    
	    layout  overlay /   walldisplay = none
	    yaxisopts = (reverse = true display = none offsetmin = 0.1) 
	    xaxisopts = (tickvalueattrs = (size = 7pt) labelattrs = (size = 10pt) label = "Ratio of Geometric Means from Test against Reference and 90% CI");
	    scatterplot y = obsid2 x = ratio  / xerrorlower = lcl xerrorupper = ucl markerattrs = (size = 1.2pct symbol = diamondfilled size=6);
	    referenceline x = 1 /LINEATTRS=(COLOR=black thickness=1);
	    referenceline x = &lowerbound/LINEATTRS=(COLOR=gray PATTERN=2 thickness=1);
	    referenceline x = &upperbound/LINEATTRS=(COLOR=gray PATTERN=2 thickness=1);
	    endlayout;
		endlayout;
	endlayout;
endlayout;
endgraph;
end;
run;
/*Meta forestplot variability, forest, barchart template*/
proc template;
define statgraph ForestPlotMetaVarBoxRatio ;
begingraph / designwidth=1400px designheight=2000;
entrytitle " Summary Plots" / textattrs = (size = 18pt weight = bold) pad = (bottom = 5px);
Layout lattice/rows=3 columns=1 rowGUTTER=50 rowdatarange=data;
 
        layout lattice ;
		layout gridded ;
			entry " AE percentage versus treatment group, subset by severity" / textattrs = (size = 15pt weight = bold) pad = (bottom = 5px);

			layout overlay/cycleattrs=true 
		    xaxisopts=(display=(tickvalues label) label="Numerical Dose" labelattrs = (size = 12pt) tickvalueattrs=(size=10pt weight=bold)
						 )
		    yaxisopts=(label="AE Prevalence" labelattrs = (size = 15pt) offsetmax=0.1 tickvalueattrs=(size=10pt weight=bold) ) ;
			barchart x=numericdose y=single_rate /group=&severity BARLABEL=TRUE barlabelattrs=(size=10pt) grouporder=ascending stat=sum dataskin=gloss name="A"
		    legendlabel="A" datatransparency=0.2   barwidth=0.5 ;
			referenceline x=&ClinicalDose. / LINEATTRS=(COLOR=gray PATTERN=solid thickness=1); 
			discretelegend "A" / title="Severity" location=inside halign=right valign=top exclude=(""".") SORTORDER=ASCENDINGFORMATTED;
			endlayout;
		endlayout;
		endlayout;

		layout gridded/valign=top  ;
		entry "AUC Distribution by Dose"/textattrs = (size = 15pt weight = bold) pad = (bottom = 5px) ;
        layout overlay / cycleattrs=true 
                               xaxisopts=(display=(ticks label tickvalues) label="Dose / Mg"   labelattrs = (size = 12pt weight = bold) tickvalueattrs=(size=10pt) )
                               yaxisopts=(label='AUC(Area Under the Curve) ' labelattrs = (size = 12pt weight = bold)  tickvalueattrs=(size=10pt) );
          boxplot x=dose y=OrgMACRORESULT / discreteoffset=0  boxwidth=0.2   ;
       endlayout;
	   endlayout;

	layout gridded/valign=top ;
	entry "Forest Plot" / textattrs = (size = 15pt weight = bold) pad = (bottom = 5px);
	layout lattice / columns = 4 columnweights=(0.3 0.1 0.4 0.2) border=true ;
	    layout overlay /    walldisplay = none 
	    xaxisopts = (display = none offsetmin = 0.2 offsetmax = 0.2 tickvalueattrs = (size = 8)) 
	    yaxisopts = (reverse = true display = none tickvalueattrs = (weight = bold) offsetmin = 0);
	    scatterplot y = obsid2 x = comp  /   markercharacter  =combination  markercharacterattrs=(family='Lucida Console' size=7 weight=bold  );
	    endlayout;

	    layout overlay /    walldisplay = none
	    xaxisopts = (display = none offsetmin = 0 offsetmax = 0 tickvalueattrs = (size = 8))
	    yaxisopts = (reverse = true display = none tickvalueattrs = (weight = bold) offsetmin = 0);
	    scatterplot y = obsid2 x = par      /   markercharacter  =parameter markerattrs = (size = 0);
	    endlayout;
	    
	    layout  overlay /   walldisplay = none
	    yaxisopts = (reverse = true display = none offsetmin = 0) 
	    xaxisopts = (tickvalueattrs = (size = 7pt) labelattrs = (size = 10pt) label = "Ratio of Geometric Means from Test against Reference and 90% CI");
	    scatterplot y = obsid2 x = ratio  / xerrorlower = lcl xerrorupper = ucl markerattrs = (size = 1.2pct symbol = diamondfilled size=6);
	    referenceline x = 1 /LINEATTRS=(COLOR=black thickness=1);
	    referenceline x = &lowerbound/LINEATTRS=(COLOR=gray PATTERN=2 thickness=1);
	    referenceline x = &upperbound/LINEATTRS=(COLOR=gray PATTERN=2 thickness=1);
	    endlayout;

	    layout overlay    /   walldisplay=none
	    x2axisopts = (display = (tickvalues) offsetmin = 0.25 offsetmax = 0.25)
	    yaxisopts  = (reverse = true display = none);
	    scatterplot y = obsid2 x = r /   markercharacter = ratio
	    markercharacterattrs = graphvaluetext xaxis = x2;
	    scatterplot y = obsid2 x = lower   /   markercharacter = lcl
	    markercharacterattrs = graphvaluetext xaxis = x2;
	    scatterplot y = obsid2 x = upper   /   markercharacter = ucl
	    markercharacterattrs = graphvaluetext xaxis = x2;
	    endlayout;     
		endlayout;
	endlayout;
endlayout;
endgraph;
end;
run;

options nodate nonumber;
ods listing gpath = "&OutputFolder.\Summary3Plot" style=statistical sge=on;
ods graphics on / noborder imagefmt = png imagename = "Summary3PlotBox" width = 1000px height = 1200;

proc sgrender data=metabox template=ForestPlotMetaVarBox;
run;

ods listing sge=off;
ods graphics off;

options nodate nonumber;
ods listing gpath = "&OutputFolder.\Summary3Plot" style=statistical sge=on;
ods graphics on / noborder imagefmt = png imagename = "Summary3PlotBoxRatio" width = 1000px height = 1200;

proc sgrender data=metabox template=ForestPlotMetaVarBoxRatio;
run;

ods listing sge=off;
ods graphics off;

%SmCheckAndCreateFolder(        BasePath = &OutputFolder.\Summary3Plot,
        FolderName = data
        );
data barchart;
set barchart;
clinicaldose=&clinicaldose;
rename &severity=SEVERITY 
		&study=STUDYID		
		&id=USUBJID	
		&Treatment=TRTA	
		&Body=AEBODSYS	
		&Adverse_Event=AEDECOD		
		;
run;
data title;
barchart="AE percentage versus treatment group, subset by severity";
boxplot="AUC Distribution by Dose";
forest="Forest Plot";
variability="Meta Variability Analysis";
run;
ods csv file="&OutputFolder.\Summary3Plot\data\barchart.csv";
proc print data=barchart noobs;
run;
ods csv file="&OutputFolder.\Summary3Plot\data\variability.csv";
proc print data=variability noobs;
run;
ods csv file="&OutputFolder.\Summary3Plot\data\forest.csv";
proc print data=forest noobs;
run;
ods csv file="&OutputFolder.\Summary3Plot\data\title.csv";
proc print data=title noobs;
run;
ods csv close;
%end;
%mend;