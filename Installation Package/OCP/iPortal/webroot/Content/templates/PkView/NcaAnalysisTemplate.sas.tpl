/*================================================================================
/ Program   : {@SCRIPT_NAME@}.SAS (Generated:{@GENERATION_DATE@})
/ SubMacros : macrolib.sas
/ Purpose   : Perform non-compartmental analysis.
/================================================================================
/ DISCLAIMER: CERTAIN PARTS THIS SCRIPT HAVE BEEN AUTOMATICALLY CUSTOMIZED
/ BASED ON DATA FROM THE SELECTED STUDY. EDIT THIS SCRIPT AT YOUR OWN RISK!
/================================================================================*/

%let rootFolder = %qsubstr(%sysget(SAS_EXECFILEPATH), 1, %length(%sysget(SAS_EXECFILEPATH)) - %length(%sysget(SAS_EXECFILENAME)));

options ps=60; 
%include "&rootFolder.\libraries\macrolib.sas";

/* Submission, study, analyte */
%let submission={@SUBMISSION@};
%let study={@STUDY@};
%let level={@LEVEL@};

/* Firm nomenclature for pk parameters */
%let FIRMAUCI={@FIRMAUCI@};
%let FIRMAUCT={@FIRMAUCT@};
%let FIRMCMAX={@FIRMCMAX@};
%let FIRMTHALF={@FIRMTHALF@};
%let FIRMTMAX={@FIRMTMAX@};

/* Output paths */
%let studydir=&rootFolder.\results;
%LET REVIEWERPKFILE=&studydir\&submission._&study._Reviewer_PK_&level..doc;
%LET FRRATIOFILE=&studydir\&submission._&study._Firm-Reviewer_Ratio_&level..doc;
%LET CONCOUTPUT=&studydir\&submission._&study._Concentration_Datasets_&level..doc;

/* Declare global variables */
%GLOBAL SUB PER SEQ TRT GRP TREAT C T AUCT CMAX TMAX AUCI KE DF NNAME
THALF CLAST KE_FIRST KE_LAST OLDNAME NEWNAME;

/* import blood level data using DDE communication. WARNNING: EXCEL FILE MUST BE OPEN AND IT SHOULD BE THE ONLY FILE LOADED IN EXCEL */
filename orgplasm DDE 'EXCEL|Conc!C1:C1000';
%let plasmaLineSize=8000;   /* Maximum line size available from the input, increase if needed */

/* Read file columns and determine the total number of sampling points */
data _null_;
   length header $800.;
   array columns{1000} $32.;
   infile orgplasm obs=1 ls=&plasmaLineSize dlm='09'x notab dsd missover;
   input columns{*};
   header=""; i=1; n=0;
   do while (length(columns[i]) > 1);
      header = trim(header) || " " || trim(columns[i]);      
      if ((index(columns[i], "C") = 1) and (verify(trim(columns[i]), "cC0123456789") = 0)) then do;
         number = input(substr(trim(columns[i]), 2), 8.);
         if (number > n) then n = number;
      end;
      i = i + 1;
   end;
   call symputx("plasmaVariables", header, "G"); 
   call symputx("no_assay", n, "G"); 
run;
filename orgplasm clear;
%put &plasmaVariables;
/* read blood level data from the DDE link */
filename orgplasm DDE 'EXCEL|Conc!C1:C1000' notab;
data plasma(drop=subject arm period treatment);
   length subject arm period treatment $200;
   infile orgplasm firstobs=2 ls=&plasmaLineSize dlm='09'x dsd missover;
   input &plasmaVariables.;
run;
filename orgplasm clear;
proc print data=plasma;run;

 /* import pk parameter data using DDE communication. WARNNING: EXCEL FILE MUST BE OPEN AND IT SHOULD BE THE ONLY FILE LOADED IN EXCEL */
filename orgparam DDE 'EXCEL|Pk!C1:C1000' notab;
%let paramLineSize=500;   /* Maximum line size available from the input, increase if needed */

/* Read file columns and determine the total number of sampling points */
data _null_;
   length header $800;
   array columns{1000} $32.;
   infile orgparam obs=1 ls=&paramLineSize dlm='09'x dsd missover;
   input columns{*};
   header=""; i=1;
   do while (length(columns[i]) > 1);
      header = trim(header) || " " || trim(columns[i]);            
      i = i + 1;
   end;
   call symputx("paramVariables", header, "G"); 
run;

/* read pk parameter data from the DDE link */
data parame(drop=subject arm period treatment);
   length subject arm period treatment $200;
   infile orgparam firstobs=2 ls=&paramLineSize dlm='09'x notab dsd missover;
   input &paramVariables;
run;
filename orgparam clear;
proc print data=parame;run;

***** PROVIDE NOMINAL SCHEDULED SAMPLE TIMES FOR GENERATING MEAN PLASMA TABLE *****;

/* Convert treatment to numeric if needed */
data plasma(drop=trt rename=(trtnew=trt));
   set plasma;
   trtnew=trt * 1;
run;
data parame (drop=trt rename=(trtnew=trt));
   set parame;
   trtnew=trt * 1;
run;

/* Re-sort data to avoid non consecutive subject numbers */
proc sort data=plasma;
by sub seq per trt;
run;

proc sort data=parame;
by sub seq per trt;
run;

data origin;
   array C(&NO_ASSAY) C1-C&NO_ASSAY;
   array T(&NO_ASSAY) T1-T&NO_ASSAY;
   merge plasma parame;
   by sub seq per trt;
   CLAST=C&NO_ASSAY;
   NEWCMAX=MAX(of C1-C&NO_ASSAY);
run;
%COPYDS(ORIGIN, NEW)
run;
proc print data=origin;run;

proc template;
  define style mystyle;
  parent = styles.rtf;
    REPLACE fonts /
    'headingFont' = ("Arial", 8pt,Bold)
    'docFont' = ("Arial", 8pt)
     'TitleFont2' = ("Arial",8pt,Bold)
    'TitleFont' = ("Arial",8pt,Bold)
    'StrongFont' = ("Arial",8pt,Bold)
    'EmphasisFont' = ("Arial",8pt)
    'FixedEmphasisFont' = ("Arial",8pt)
    'FixedStrongFont' = ("Arial",8pt,Bold)
    'FixedHeadingFont' = ("Arial",8pt,Bold)
    'BatchFixedFont' = ("Arial",8pt)
    'FixedFont' = ("Arial",8pt)
    'headingEmphasisFont' = ("Arial",8pt,Bold);

    style SysTitleAndFooterContainer from Container /
      outputwidth = 85%
      cellpadding = 2
      cellspacing = 2
      borderwidth = 0;

   REPLACE Body from Document /
     bottommargin = 1.0in
     topmargin = 1.0in
     rightmargin = 0.25in
     leftmargin = 0.25in;
  END;
run;

proc template;
  define style mystyle1;
  parent = styles.rtf;
    REPLACE fonts /
    'headingFont' = ("Arial", 8pt,Bold)
    'docFont' = ("Arial", 8pt)
     'TitleFont2' = ("Arial",8pt,Bold)
    'TitleFont' = ("Arial",8pt,Bold)
    'StrongFont' = ("Arial",8pt,Bold)
    'EmphasisFont' = ("Arial",8pt)
    'FixedEmphasisFont' = ("Arial",8pt)
    'FixedStrongFont' = ("Arial",8pt,Bold)
    'FixedHeadingFont' = ("Arial",8pt,Bold)
    'BatchFixedFont' = ("Arial",8pt)
    'FixedFont' = ("Arial",8pt)
    'headingEmphasisFont' = ("Arial",8pt,Bold);

    style SysTitleAndFooterContainer from Container /
      outputwidth = 85%
      cellpadding = 2
      cellspacing = 2
      borderwidth = 0;

   REPLACE Body from Document /
     bottommargin = 1.0in
     topmargin = 1.0in
     rightmargin = 1in
     leftmargin = 1in;
  END;
run;

/* Create output folder */
%CreateFolder(Basepath=&rootFolder., FolderName=results);

/* output blood level data to the concentration rtf file */
options orientation=landscape papersize=letter;
ods rtf file="&concoutput" style=mystyle bodytitle;
TITLE "&study CONCENTRATION DATASET";
proc print data=plasma;run;
ods rtf close;

/* DETERMINE NEWTMAX, KE_FIRST, KE_LAST, NEWAUCT AND AUCLST */
DATA NEW;
       ARRAY C(&NO_ASSAY) C1-C&NO_ASSAY;
       ARRAY T(&NO_ASSAY) T1-T&NO_ASSAY;
       NO_ASSAY=&NO_ASSAY;
   SET NEW;
   CLAST=C&NO_ASSAY;
   NEWCMAX=MAX(of C1-C&NO_ASSAY);

   /* Replace missing time or concentration by zero */
   DO M=1 TO NO_ASSAY;
   IF T(M)=. THEN T(M)=0;
   END;
   DO N=1 TO NO_ASSAY;
   IF C(N)=. THEN C(N)=0;
   END;

   /* DETERMINE NEWTMAX */
   DO I=1 TO NO_ASSAY;
   IF C(I)=NEWCMAX THEN NEWTMAX=T(I);
   END;
   /* INTERPOLATE MISSING VALUE ON LINEAR SCALE */
   IF C(1)=. THEN C(1)=0;  /* MISSING VALUE */
   IF C(NO_ASSAY)=. THEN C(NO_ASSAY)=0;  /* MISSING VALUE */
   DO I=2 TO (NO_ASSAY-1);
      H=I-1;
      J=I+1;
   IF C(I)=. THEN DO;    /* FIRST MISSING VALUE */
   IF C(J)=. THEN J=J+1; /* SECOND CONSECUTIVE MISSING VALUE */
   IF C(J)=. THEN J=J+1; /* THIRD CONSECUTIVE MISSING VALUE */
   C(I)=C(H)+((C(J)-C(H))/(T(J)-T(H)))*(T(I)-T(H));
       END;
       END;
   NEWTMAX=NEWTMAX;
   /* CALCULATE AUCLST(TO THE LAST SAMPLING TIME POINT) */
   AUCLST=0;
   DO I=2 TO NO_ASSAY;
   K=I-1;
   AUCLST=AUCLST+((C(K)+C(I))*(T(I)-T(K))/2);
   END;

   /* CALCULATE AUCT AND STORE AS NEWAUCT(TO THE LAST DETECTABLE
   CONC) */
   DO I=NO_ASSAY TO 2 BY -1;
   IF C(NO_ASSAY)>0 THEN DO;
          NEWAUCT=AUCLST;
          CLAST=C(NO_ASSAY);
          GOTO F;
          END;
      ELSE DO;
           K=I-1;
           IF C(I)=0 AND C(K)>0 THEN DO;
              NEWAUCT=AUCLST-(C(I)+C(K))*(T(I)-T(K))/2;
              CLAST=C(K);
              GOTO F;
              END;
       END;
   END;


   F: NEWAUCT=NEWAUCT; /* FLAG TO CONTINUE */
   NEWAUCI=NEWAUCT+CLAST/KE;

   /* TRANSVERSE THE C AND T DATA INTO COLUMNS WITH NEW VARIABLE
   NAMES */
   DO I=1 TO NO_ASSAY;
   TIME=T(I);
   CONC=C(I);
   IF CONC=0 OR CONC=. THEN LOGCONC=.;
   ELSE LOGCONC=LOG(CONC);
   NEWAUCT=NEWAUCT;
   I=I;
   OUTPUT;
   END;

RUN; 
PROC PRINT DATA=NEW;RUN;

PROC SORT DATA=NEW;
BY SUB TRT PER;
RUN; 
DATA NEW1;
SET NEW;
IF I>=KE_FIRST and I<=KE_LAST; 
RUN;

PROC REG DATA=NEW1 NOPRINT OUTEST=KEOUT;
BY SUB TRT PER ;
MODEL LOGCONC=TIME;
RUN;

/* NEW KE IS STORED IN NEW4KE */
DATA KEOUT;
SET KEOUT;
KEEP SUB TRT PER TIME;
TIME=ABS(TIME);
KEEP TIME;
RENAME TIME=KEL;
run;
proc print data=keout;run;

/* CALCULATE THALF FROM REVIEWER'S KEL*/
DATA KEOUT;
SET KEOUT;
THALFR=LOG(2)/KEL;
run;
PROC PRINT DATA=KEOUT;
RUN;

/* DROP KE AND THALF FROM FIRM'S PK DATASET */
DATA NEW1;
SET NEW;
DROP THALF KE;
RUN;

PROC SORT DATA=NEW1;
BY SUB TRT PER;
RUN; 
PROC PRINT DATA=NEW1;RUN;

/*CREATE NEW PK DATASET WITH REVIEWER'S THALF AND KE*/;
DATA NEW1;
MERGE NEW1 KEOUT;
BY SUB TRT PER ;
RUN;

DATA NEW1;
   ARRAY C(&NO_ASSAY) C1-C&NO_ASSAY;
          ARRAY T(&NO_ASSAY) T1-T&NO_ASSAY;
          NO_ASSAY=&NO_ASSAY;
   SET NEW1;

   CLAST=C&NO_ASSAY;
   /*CLAST AS NON-ZERO*/;

   DO J=NO_ASSAY TO 2 BY -1;
   IF C(NO_ASSAY)>0 THEN DO;
      CLAST=C(NO_ASSAY);
      NEWAUCI=NEWAUCT+CLAST/KEL;
      END; 
      ELSE DO;
           K=J-1;
           IF C(J)=0 AND C(K)>0 THEN DO;
              CLAST=C(K);
            NEWAUCI=NEWAUCT+CLAST/KEL;
              END;
       END;
   END;

   KEEP I KE_FIRST SUB TRT SEQ PER NEWAUCT NEWAUCI NEWCMAX NEWTMAX THALFR KEL TIME;
run;
PROC PRINT DATA=NEW1; RUN;
%PUT &CLAST;

******************************************************************;
******* DATA SET PK CONTAINS PARAMETERS CALCULATED BY REVIEWER****;
DATA PK1;
SET NEW1;
IF I=1;  
PUT SUB TRT SEQ PER NEWAUCT NEWAUCI NEWCMAX NEWTMAX THALFR KEL;
KEEP SUB TRT SEQ PER NEWAUCT NEWAUCI NEWCMAX NEWTMAX THALFR KEL;
rename   newauct=auct
      newauci=auci
      NEWCMAX=CMAX
      NEWTMAX=TMAX;
run;
PROC PRINT DATA=NEW1; RUN;

DATA FDAPK;
	retain sub seq per trt FDAAUCI FDAAREA FDACMAX;
	SET PK1;
	FDAAREA=AUCT;
	FDAAUCI=AUCI;
	FDACMAX=CMAX;
	DROP AUCT AUCI CMAX TMAX KEL THALFR;
run;
PROC PRINT DATA=FDAPK; RUN;

PROC SORT DATA=FDAPK; BY SUB PER TRT; RUN;

*****READ FIRM'S PK PARAMETER DATA *****;
DATA FIRMPK;
   %RenameVariable(Name=&FIRMAUCI., NewName=FIRMAUCI);
   %RenameVariable(Name=&FIRMAUCT., NewName=FIRMAREA);
   %RenameVariable(Name=&FIRMCMAX., NewName=FIRMCMAX);
   %RenameVariable(Name=&FIRMTMAX., NewName=FIRMTMAX);
   %RenameVariable(Name=&FIRMTHALF., NewName=FIRMTHALF);
SET PARAME;
RUN;

PROC SORT DATA=FIRMPK;
   BY SUB PER TRT;
RUN;
PROC PRINT DATA=FIRMPK;RUN;

DATA FIRMREVIEWERRATIO;
SET FDAPK FIRMPK;
MERGE FDAPK FIRMPK;
BY SUB PER TRT;

RAUCT=FIRMAREA/FDAarea;
RAUCI=FIRMAUCI/FDAAUCI;
RCMAX=FIRMCMAX/FDACMAX;
run;
proc print;RUN;

/* output to reviewer pk rtf file */
options orientation=landscape papersize=letter;
ods rtf file="&REVIEWERPKFILE." /*style=mystyle bodytitle*/;
TITLE "&submission &study REVIEWER-CALCULATED PHARMACOKINETIC DATASET";
proc print data=PK1;
VAR SUB TRT SEQ PER AUCT AUCI CMAX TMAX THALFR KEL;
run;

/* output to firm versus reviewer ratio rtf file */
options orientation=landscape papersize=letter;
ods rtf file="&FRRATIOFILE." /*style=mystyle bodytitle*/;
TITLE "&submission &study FIRM TO REVIEWER RATIO";
proc print data=FIRMREVIEWERRATIO; run;
ods rtf close;



/*adding boxplot and whisker plots on 2016*/
%put start generates boxplots;

data boxplot;
set FIRMREVIEWERRATIO;
drop _NAME_;
run;

proc sort data=boxplot;
by sub seq per trt ;
run;

proc transpose data=boxplot out=longboxplot(rename=(_NAME_=RParameter  COL1=FDA_vs_FIRM))  ;
var RAUCT RAUCI RCMAX ;
by  sub seq per trt;
run;


/*output path for boxplot*/

%LET BOXPLOTFILE=&studydir\&submission._&study._boxplot_&level..doc;


ods rtf style=Journal2 file="&BOXPLOTFILE.";
ods trace on;
ods graphics on;

proc sgplot data=longboxplot;
title "&submission  Study:&study  Analyte:&level";
label trt="Treatment Group" FDA_vs_FIRM="FIRM vs FDA Ratio" rparameter="Parameter";
vbox FDA_vs_FIRM/category=trt group=Rparameter;
run;

ods graphics off;
ods trace off;
ods rtf close;

