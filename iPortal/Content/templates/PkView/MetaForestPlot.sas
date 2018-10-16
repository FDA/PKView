
/*================================================================================
 Program   : Meta Forest Plot Template Created by Meng Xu on 01/12/2017
 Purpose   : Perform Meta Forest Plot Analysis
================================================================================*/

/*Import data in csv file for meta analysis */
%let rootFolder = %qsubstr(%sysget(SAS_EXECFILEPATH), 1, %length(%sysget(SAS_EXECFILEPATH)) - %length(%sysget(SAS_EXECFILENAME)));
%put rootFolder=&rootFolder;

proc import out=metadata 
	datafile="&rootFolder\Meta_Input.csv" 
	dbms=csv replace; 
	getnames=yes; 
run;


data macrovar;
set metadata(obs=1);
call symput("ndavar",NDA);
call symput("lowerbound",lowerbound);
call symput("upperbound",upperbound);
run;
%put ndavar=&ndavar || lowerbound=&lowerbound ||upperbound=&upperbound;

/*Set up meta analysis forest plot for to list 1) ratio and 90% confidence interval 2) minimum and maximum subject ratio */
proc template;
define statgraph ForestPlotCI ;
begingraph / designwidth=1200px designheight=1000;
entrytitle "Forest Plot" / textattrs = (size = 12pt weight = bold) pad = (bottom = 5px);
layout lattice / columns = 4 columnweights=(0.3 0.2 0.3 0.2);

    layout overlay /    walldisplay = none 
    xaxisopts = (display = none offsetmin = 0.2 offsetmax = 0.2 tickvalueattrs = (size = 8)) 
    yaxisopts = (reverse = true display = none tickvalueattrs = (weight = bold) offsetmin = 0);
    scatterplot y = obsid x = comp  /   markercharacter  =combination  markercharacterattrs=(family='Lucida Console' size=7 weight=bold  );
    endlayout;

    layout overlay /    walldisplay = none
    xaxisopts = (display = none offsetmin = 0.3 offsetmax = 0.2 tickvalueattrs = (size = 8))
    yaxisopts = (reverse = true display = none tickvalueattrs = (weight = bold) offsetmin = 0);
    scatterplot y = obsid x = parcat  /   markercharacter  =analyte   markerattrs = (size = 1);
    scatterplot y = obsid x = par      /   markercharacter  =parameter markerattrs = (size = 0);
    endlayout;
    
    layout  overlay /   walldisplay = none
    yaxisopts = (reverse = true display = none offsetmin = 0) 
    xaxisopts = (tickvalueattrs = (size = 7pt) labelattrs = (size = 7pt) label = "Ratio of Geometric Means from Test against Reference and 90% CI");
    scatterplot y = obsid x = ratio  / xerrorlower = lcl xerrorupper = ucl markerattrs = (size = 1.2pct symbol = diamondfilled size=6);
    referenceline x = 1 /LINEATTRS=(COLOR=black thickness=1);
    referenceline x = &lowerbound/LINEATTRS=(COLOR=gray PATTERN=2 thickness=1);
    referenceline x = &upperbound/LINEATTRS=(COLOR=gray PATTERN=2 thickness=1);
    endlayout;

    layout overlay    /   walldisplay = none
    x2axisopts = (display = (tickvalues) offsetmin = 0.25 offsetmax = 0.25)
    yaxisopts  = (reverse = true display = none);
    scatterplot y = obsid x = r /   markercharacter = ratio
    markercharacterattrs = graphvaluetext xaxis = x2;
    scatterplot y = obsid x = lower   /   markercharacter = lcl
    markercharacterattrs = graphvaluetext xaxis = x2;
    scatterplot y = obsid x = upper   /   markercharacter = ucl
    markercharacterattrs = graphvaluetext xaxis = x2;
    endlayout;     

endlayout;
endgraph;
end;
run;

proc template;
define statgraph ForestPlotMaxMin ;
begingraph / designwidth=1200px designheight=1000;
entrytitle "&ndavar Meta Analysis Forest Plot" / textattrs = (size = 12pt weight = bold) pad = (bottom = 5px);
layout lattice / columns = 4 columnweights=(0.3 0.2 0.3 0.2);

    layout overlay /    walldisplay = none 
    xaxisopts = (display = none offsetmin = 0.2 offsetmax = 0.2 tickvalueattrs = (size = 8)) 
    yaxisopts = (reverse = true display = none tickvalueattrs = (weight = bold) offsetmin = 0);
    scatterplot y = obsid x = comp  /   markercharacter  =combination  markercharacterattrs=(family='Lucida Console' size=7 weight=bold  );
    endlayout;

    
    layout overlay /    walldisplay = none
    xaxisopts = (display = none offsetmin = 0.3 offsetmax = 0.2 tickvalueattrs = (size = 8))
    yaxisopts = (reverse = true display = none tickvalueattrs = (weight = bold) offsetmin = 0);
    scatterplot y = obsid x = parcat  /   markercharacter  =analyte   markerattrs = (size = 1);
    scatterplot y = obsid x = par      /   markercharacter  =parameter markerattrs = (size = 0);
    endlayout;

    
    layout  overlay /   walldisplay = none
    yaxisopts = (reverse = true display = none offsetmin = 0) 
    xaxisopts = (tickvalueattrs = (size = 7pt) labelattrs = (size = 7pt) label = "Ratio of Geometric Means from Test against Reference and 90% CI");
    scatterplot y = obsid x = ratio  / xerrorlower = lcl xerrorupper = ucl markerattrs = (size = 1.2pct symbol = diamondfilled size=6);
    referenceline x = 1 /LINEATTRS=(COLOR=black thickness=1);
    referenceline x = &lowerbound/LINEATTRS=(COLOR=gray PATTERN=2 thickness=1);
    referenceline x = &upperbound/LINEATTRS=(COLOR=gray PATTERN=2 thickness=1);
    endlayout;

    layout overlay    /   walldisplay = none
    x2axisopts = (display = (tickvalues) offsetmin = 0.25 offsetmax = 0.25)
    yaxisopts  = (reverse = true display = none);
    scatterplot y = obsid x = minlabel  /   markercharacter = min
    markercharacterattrs = graphvaluetext xaxis = x2;
    scatterplot y = obsid x = maxlabel   /   markercharacter = max
    markercharacterattrs = graphvaluetext xaxis = x2;
    endlayout; 

endlayout;
endgraph;
end;
run;


/*Create a new subfolder to save all results*/
%let folderpath = %sysfunc(dcreate(Results, &Rootfolder.));
%put &rootfolder.;
%put folderpath=&folderpath;


options nodate nonumber;
ods listing gpath = "&rootfolder.Results" style=statistical sge=on;
ods graphics on / noborder imagefmt = png imagename = "Meta_CI" width = 1000px height = 1200;

proc sgrender data=metadata template=ForestPlotCI;
run;
ods listing sge=off;
ods graphics off;

ods listing gpath = "&rootfolder.Results" style=statistical sge=on;
ods graphics on / noborder imagefmt = png imagename = "Meta_MaxMin" width = 1000px height = 1200;

proc sgrender data=metadata template=ForestPlotMaxMin;
run;
ods listing sge=off;
ods graphics off;

