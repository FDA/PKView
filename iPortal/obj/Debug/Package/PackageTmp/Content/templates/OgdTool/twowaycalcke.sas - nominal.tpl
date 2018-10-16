/*================================================================================
/ Program   : TWOWAYCALCKE 12FEB2010 WITH TIME AND KE DATASET ENTRIES.SAS (Updated: 12 FEB 2010)
/ SubMacros : macrolib.sas, calcke.sas
/ Purpose   : To analyze two-way crossover bioequivalence studies.
/================================================================================
/ AMENDMENT HISTORY:
/ Init --Date--  ----------------------Description-------------------------
/ 01 Sep 2009        Use nominal collection times for creating mean plasma table.
/
/ Unspecified        CALCULATION OF KE BASED ON INDIVIDUAL KE_FIRST AND KE_LAST 
/                    DATA VERIFIED BY THE REIVEWER AND INCLUDED IN CONCENTRATION DATASET
/
/ Unspecified        CALCULATION BASED ON ACTUAL SAMPLING TIMES INCLUDED IN CONCENTRATION DATASET
/================================================================================*/
**** NODATE OPTION generates error in word document.. with bodytitle ods ****;

/********************************************************************************/
/********************************************************************************/
/* WARNING: AUTOMATICALLY GENERATED CODE BELOW THIS LINE, EDIT AT YOUR OWN RISK */
/********************************************************************************/
/********************************************************************************/

********** FOLLOW THE STEPS 1-15 TO RUN THIS PROGRAM **********;

OPTIONS PS=60; 

****** STEP 1: LOCATION OF MACRO FILE (MACROLIB.SAS). CHANGE LOCATION IF APPLICABLE ********;
%INCLUDE "@@MACROLIB_LOCATION@@";

/**********************************************************
  ASSIGN WHETHER HAVE GROUP EFFECT:
   TRTGROUP = 1      TRT*GROUP INTERACTION IN GLM MODEL
   TRTGROUP = 2      TRT*GROUP INTERACTION NOT IN GLM MODEL
   TRTGROUP =        NO GROUP EFFECT IN STUDY
 NOTE:  group variable has to be named GRP in the dataset.
*************************************************************/;

*****STEP 2:  ASSIGN FLAG FROM ABOVE FOR TREAT*GROUP INTERACTION*****;
%let trtgroup=@@TRT_GRP_FLAG@@;

*****STEP 3: ENTER ANDA INFORMATION *****;
%let level=@@LEVEL@@;
%let drug=@@DRUG@@;
%let dose=@@DOSE@@;
%let anda=@@ANDA@@;
%let studytype=@@STUDY_TYPE@@;

***** STEP 4: ENTER LOCATION OF DATASETS AND LOCATION FOR SAVING OUTPUT REPORTS *****;
%let studydir=@@OUTPUT_LOCATION@@;

*****STEP 5: ENTER UNITS FOR PK PARAMETERS *****;
%let aucunit = @@AUC_UNITS@@;
%let cmaxunit = @@CMAX_UNITS@@;
%let timeunit = @@TIME_UNITS@@;


**** DO NOT CHANGE: NAME OF MS WORD STATISTICAL OUTPUT FILE ****;
%LET ODSFILE=&studydir\&anda._&studytype._stat_&level.ACTUAL.doc;

**** DO NOT CHANGE: NAME OF MS WORD REVIEW TABLES OUTPUT FILE ****;
%LET ODSFILE1=&studydir\&anda._&studytype._table_&level.ACTUAL.doc;

**** DO NOT CHANGE: NAME OF PLASMA CONCENTRATION PLOT IN CGM GRAPHIC FILE****;
%LET PLOTFILE=&studydir\&anda._&studytype._plot_&level.ACTUAL.png;

**** DO NOT CHANGE: NAME OF CONC AND PK DATASETS OUTPUT ****;
%LET CONCOUTPUT=&studydir\&anda._&studytype._Datasets_&level..doc;


%LET VARSORT=SUB PER; 

%GLOBAL SUB PER SEQ TRT GRP TREAT C T AUCT CMAX TMAX AUCI KE DF NNAME
THALF CLAST KE_FIRST KE_LAST OLDNAME NEWNAME;


*****STEP 6: SELECT TYPE OF ANALYSIS FROM BOTTOM******;

/***NOTE:  THE CURRENT PROGRAM DOES NOT INCLUDE CONTINU OR CONTINU2 OPTIONS********
*******SELECT TWOWAYCALCKE07MAR2009.SAS IF YOU WANT TO CALCULATE KE AND OTHER PARAMETERS ***/
/***SELECT TWOWAYCONTINU(2)07MAR2009.SAS IF YOU DO NOT WANT TO RECALCULATE KE.  
FOR TWOWAYCONTINU(2)07MAR2009.SAS, SPONSOR'S KE WILL BE USED FOR CALCULATION 
OF OTHER PARAMETERS WITH STATISTICS ON SPONSOR SUPPLIED PARAMETERS (CONTINU).  
OR WITH STATISTICS ON CALCULATED PARAMETERS (CONTINU2) ***/

%LET FNAME=%QUOTE(@@KE_SCRIPT_LOCATION@@);

*****STEP 7: BLOOD LEVEL DATA: NEED FILE NAME, FIRST OBSERVATION AND VARIABLE LIST *****;

/* INCLUDE DATA LOADING MACRO LIBRARY (DATALOADLIB.SAS) */
%INCLUDE "@@DATALOADLIB_LOCATION@@";

/* LOAD THE CONCENTRATION DATA */
%LoadDataSet(filename="@@CONCENTRATION_FILENAME@@", outputName=plasma);

** STEP 8:  ENSURE TREATMENT AND OTHER VARIABLES ARE PROPERLY FORMATTED..CHAR OR NUMERIC **;
** ENSURE THAT THE DATASET HAS TWO COLUMNS: KE_FIRST AND KE_LAST SPECIFYING DATA POINTS TO BE USED FOR CALCULATION OF KE **;

DATA PLASMA;
   SET PLASMA@@CONCENTRATION_SET_PARAMS@@;

   @@CONCENTRATION_SUBJECT_EXCLUSION@@

   @@CONCENTRATION_DATA_TRANSFORMATIONS@@

run;

proc print data=plasma;
run;

%SORTDS(PLASMA, &VARSORT)
RUN;

***** STEP 9: LOAD THE PK STUDY DATA *****;

%LoadDataSet(filename="@@PK_FILENAME@@", outputName=parame);

** STEP 10:  ENSURE TREATMENT AND OTHER VARIABLES ARE PROPERLY FORMATTED..CHAR OR NUMERIC **;
DATA PARAME;
   set parame@@PK_SET_PARAMS@@;

   @@PK_SUBJECT_EXCLUSION@@

   @@PK_DATA_TRANSFORMATIONS@@

RUN;

%SORTDS(PARAME, &VARSORT)
RUN;

*****STEP 11: ADD OR REDUCE THE BLOOD SAMPLE NUMBER TO FIT THE STUDY *****;
%LET CONCENT=%STR(@@CONCENTRATION_SAMPLE_ARRAY@@);

/***STEP 12: USE THIS STEP IF COMMON SAMPLING TIMES ARE USED,
			 ADD OR REDUCE THE SAMPLING TIME POINTS AND CHANGE THE TIME,
			 OR ADD FEW DEVIATED SAMPLING TIME POINTS,
			 ALSO MAKE SURE TO DEACTIVATE "SET TIME" AND ACTIVATE "&TIME" UNDER STEP 15***/

DATA TIME
%LET TIME=%STR(@@CONCENTRATION_NOMINAL_TIMES@@);

/* USE THIS STEP INSTEAD OF STEP 11 IF ACTUAL SAMPLING TIME DATASET INCLUDED
			 IN THE CONCENTRATION DATASET,
			ALSO, MAKE SURE TO ACTIVATE "SET TIME" AND DEACTIVATE "&TIME" UNDER STEP 15***/;

*DATA TIME;
*SET PLASMA;
*FILE'DESKTOP\TIME';
*PUT SUB TRT SEQ PER GRP T1-T23;
*KEEP SUB TRT SEQ PER GRP T1-T23;
	
/*PROC PRINT DATA=TIME;RUN;*/

*****STEP 13: WRITE THE TOTAL NUMBER OF SAMPLING TIME POINTS *****;
%LET NO_ASSAY=@@TOTAL_SAMPLES@@;

*****INITIALIZE KE_FIRST AND KE_LAST FOR KE CALCULATION IF THESE ARE NOT
IN THE DATA SUBMITTED. *****;
** DO NOT CHANGE SINCE KE_FIRST AND KE_LAST VALUES ARE IN CONC DATASET **;
*%LET KE_FIRST=KE_FIRST;
*%LET KE_LAST=KE_LAST;

*****STEP 14: SUBJECTS/RECORDS TO BE REMOVED FROM CALCULATION *****;
/***VARIOUS SCREENING CONDITIONS CAN BE APPLIED FOR SUBJECT REMOVAL***/
/***LEAVE AS IT IS IF NO CHANGE IS DESIRED***/
/* %LET REMOVSUB=%STR(IF SUB^=10;IF SUB^=15;IF SUB^=34;IF SUB^=37;IF SUB^=49); */
*%LET REMOVSUB=%STR(IF SUB^=1);

*****IF SEQ, PER, TRT OR OTHER VARIABLES TO BE ADDED OR MODIFIED *****;
/***CREATING NUMERIC VARIABLES FROM CHARACTER VARIABLES, ETC  ***/
/***  IF KE_FIRST AND KE_LAST ARE SUBMITTED IN THE DATA SET , KEEP THEM CLOSED ***/
 /* %LET ADD_VAR=%STR(KE_FIRST=&KE_FIRST; KE_LAST=&KE_LAST
IF TREAT='A' THEN TRT=1; ELSE TRT=2 ); */

DATA ORIGIN;
       ARRAY C(&NO_ASSAY) C1-C&NO_ASSAY;
       ARRAY T(&NO_ASSAY) T1-T&NO_ASSAY;
SET PLASMA;
*SET TIME;
SET PARAME;
*SET MERGED;
&TIME;
*KE_FIRST=0;
*KE_LAST=0;
CLAST=C&NO_ASSAY;
NEWCMAX=MAX(&CONCENT);

/***DO NOT CHANGE: TITLES FOR TABLES***/
%LET TITLE1=MEAN PLASMA &level LEVELS;
%LET TITLE2=MEAN PLASMA &level LEVELS FOR TEST AND REFERENCE PRODUCTS;

/*** DESCRIBE TITLES, FOOTNOTES AND LABELS FOR GRAPH ***/
%LET TITLE3=PLASMA &level LEVELS;
%LET TITLE4= &drug, ANDA &anda;
%LET TITLE5=UNDER &STUDYTYPE CONDITIONS;
%LET TITLE6=DOSE= &dose;
%LET FOOTNOT1=1=TEST   2=REF;
%LET FOOTNOT2=Tmax values are presented as median, range.;
%LET FOOTNOT3=;
%LET FOOTNOT4=;
%LET FOOTNOT5=;
%LET LABEL1=PLASMA LEVEL, &cmaxunit;
%LET LABEL2=TIME, HRS;
%LET LABEL3=TEST;
%LET LABEL4=REFERENCE;


%COPYDS(ORIGIN, NEW)
RUN;


proc print data=origin;
run;

*****STEP 15: OPEN IF YOU WANT TO REMOVE, ADD OR EDIT*****;
*%REMUVSUB(NEW, NEW)
RUN;

/********************************************************************************/
/********************************************************************************/
/* END OF AUTOMATICALLY GENERATED CODE                                          */
/********************************************************************************/
/********************************************************************************/

***************DO NOT CHANGE ANY OF THE STATMENTS BELOW THIS LINE ****************;
***************YOU CAN NOW SUBMIT/RUN THE PROGRAM*********************************;


*%ADDVARIA(NEW, NEW)
*RUN;

%RITEDATA(NEW, NEW, SUB TRT KE_FIRST KE_LAST) /****** TO EDIT KE-FIRST AND KE-LAST**/
RUN;

%COPYDS(NEW, NEWCONC)
RUN;

** CHECK >0 CONC FOR C1 **;
title "PRE-DOSE CONC GREATER THAN 0";

data predose;
  set origin(where=(c1 > 0));
  keep sub per seq trt c1 cmax maxlimit flag;

  maxlimit = 0.05*cmax;

  if c1 > maxlimit then flag = 1;
  else flag=0;
run;

proc print data=predose;
run;

*** dataset for data _null_***;
data updatedconc;
  set new;
run;*PROC PRINT;*RUN;


DATA NOMINALTIME;
  SET NEWCONC;

  &NOMINALTIME;
RUN;

DATA NOMINALTIME;
       ARRAY C(&NO_ASSAY) C1-C&NO_ASSAY;
       ARRAY T(&NO_ASSAY) T1-T&NO_ASSAY;
       NO_ASSAY=&NO_ASSAY;
  SET NOMINALTIME;
  
  /* TRANSVERSE THE C AND T DATA INTO COLUMNS WITH NEW VARIABLE
	NAMES */
	DO I=1 TO NO_ASSAY;
	TIME=T(I);
	CONC=C(I);
	I=I;
	OUTPUT;
	END;

RUN;


DATA NEWCONC;
       ARRAY C(&NO_ASSAY) C1-C&NO_ASSAY;
       ARRAY T(&NO_ASSAY) T1-T&NO_ASSAY;
       NO_ASSAY=&NO_ASSAY;
SET NEWCONC;
/* TRANSVERSE THE C AND T DATA INTO COLUMNS WITH NEW VARIABLE
NAMES */
DO I=1 TO NO_ASSAY;
TIME=T(I);
CONC=C(I);
I=I;
OUTPUT;
END;



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



options orientation=landscape papersize=letter;

ods rtf file="&concoutput" style=mystyle bodytitle;

TITLE "&STUDYTYPE CONCENTRATION DATASET";
proc print data=plasma;
run;

*TITLE "&STUDYTYPE PHARMACOKINETIC DATASET";
*proc print data=parame;
*run;
ods rtf close;




/* DETERMINE NEWTMAX, KE_FIRST, KE_LAST, NEWAUCT AND AUCLST */
DATA NEW;
       ARRAY C(&NO_ASSAY) C1-C&NO_ASSAY;
       ARRAY T(&NO_ASSAY) T1-T&NO_ASSAY;
       NO_ASSAY=&NO_ASSAY;
SET NEW;
CLAST=C&NO_ASSAY;
NEWCMAX=MAX(&CONCENT);



/* CALCULATE THALF IF THALF IS NOT GIVEN */
/* THALF=LOG(2)/KE;  */
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
/* PROC PRINT;
RUN; */






***********************************************************************************************************;
/*STEP 17: ONLY IF USING CALCKE.SAS: TO CALCULATE THALF AND KEL FOR THE REVIEWER-CALCULATED PK PARAMETER TABLE*/;

PROC SORT DATA=NEW;
BY SUB TRT PER GRP;

RUN; *PROC PRINT;*RUN;
DATA NEW1;
SET NEW;
IF I>=KE_FIRST and I<=KE_LAST; 
*RUN;*PROC PRINT;RUN;

PROC REG DATA=NEW1 NOPRINT OUTEST=KEOUT;
BY SUB TRT PER GRP;

MODEL LOGCONC=TIME;
RUN;
*PROC PRINT ;
*RUN;


/* NEW KE IS STORED IN NEW4KE */
DATA KEOUT;
SET KEOUT;
KEEP SUB TRT PER GRP TIME;
TIME=ABS(TIME);
KEEP TIME;
RENAME TIME=KEL;

*PROC PRINT DATA=KEOUT;
RUN;
/* CALCULATE THALF FROM REVIEWER'S KEL*/
DATA KEOUT;
SET KEOUT;
THALFR=LOG(2)/KEL;
*PROC PRINT;RUN;


/* DROP KE AND THALF FROM FIRM'S PK DATASET */
DATA NEW1;
SET NEW;
DROP THALF KE;
PROC SORT DATA=NEW1;
BY SUB TRT PER GRP;

RUN; PROC PRINT;RUN;
/*CREATE NEW PK DATASET WITH REVIEWER'S THALF AND KE*/;

DATA NEW1;
MERGE NEW1 KEOUT;
BY SUB TRT PER GRP;

RUN;PROC PRINT DATA=NEW1;RUN;


DATA NEW1;
ARRAY C(&NO_ASSAY) C1-C&NO_ASSAY;
       ARRAY T(&NO_ASSAY) T1-T&NO_ASSAY;
       NO_ASSAY=&NO_ASSAY;
SET NEW1;

%LET NO_ASSAY=23;
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

KEEP I KE_FIRST SUB TRT SEQ PER GRP NEWAUCT NEWAUCI NEWCMAX NEWTMAX THALFR KEL TIME;

*PROC PRINT DATA=NEW1;

RUN;

************************************************************************************************************;

*DATA NEW2;
*SET NEW1;
*PROC SORT;
*BY SUB TRT PER;
*RUN; *PROC PRINT;*RUN;

*DATA CONC;
*SET NEW2;

*BY SUB TRT PER;
/*KEEP SUB SEQ PER TRT C1-C23;OUTPUT; */

*RUN;*PROC PRINT DATA=CONC;*RUN;

******* DATA SET PK CONTAINS PARAMETERS CALCULATED BY REVIEWER****;
*******  THE USER MAY ENTER AT LINE  8 RAW DATA WITH PK OUTLIERS INCLUDED
           OR EXCLUDED AND COMPARE THOSE AGAINST THE FIRM'S VALUES ETC********;

DATA PK1;
SET NEW1;
IF I=1;	
*IF TIME=0;
*FILE'&studydir\PK';
PUT SUB TRT SEQ PER GRP NEWAUCT NEWAUCI NEWCMAX NEWTMAX THALFR KEL;
KEEP SUB TRT SEQ PER GRP NEWAUCT NEWAUCI NEWCMAX NEWTMAX THALFR KEL;
rename 	newauct=auct
		newauci=auci
		NEWCMAX=CMAX
		NEWTMAX=TMAX;

	
PROC PRINT DATA=PK1;RUN;


DATA FDAPK;
SET PK1;
FDAAREA=AUCT;
FDAAUCI=AUCI;
FDACMAX=CMAX;
DROP AUCT AUCI CMAX TMAX KEL THALFR;
PROC PRINT;RUN;

PROC SORT DATA=FDAPK;
BY SUB PER TRT GRP;RUN;*PROC PRINT;*RUN;



*****READ FIRM'S PK PARAMETER DATA: NEED FILE NAME, FIRST OBSERVATION AND VARIABLE LIST *****;

/***IF NO PK PARAMETER DATA, BLOCK READDATA AND SORTDS AND GO TO STEP 4 ***/
/*** IF DATA ON EXCEL WORKSHEET ACTIVATE THE LINE WITH DDE AND CLOSE THE NEXT LINE */
* FILENAME ORGPARAM DDE 'EXCEL|pk!R2C1:R121C11';
* FILENAME ORGPARAM "&studydir.\&pkdata";
*%LET FIRSTOBS=1; /* FIST OBSERVATION */
*%LET VARPARAM=SUB SEQ PER TRT $ TMAX CMAX AUCT AUCI KE THALF; /* VARIABLE LIST */
*%LET PARAMLS=256;  /* INCREASE LINE SIZE IF NEEDED */
*%READDATA(ORGPARAM,PARAME,&FIRSTOBS,&VARPARAM,&PARAMLS)
RUN;

/*
DATA PARAME;

** IF USING EXCEL FILE ACTIVATE THESE STATEMENTS **;
  infile ORGPARAM;
  input sub seq per GRP TREAT $ TMAX CMAX AUCT AUCI KE THALF;
    if TREAT = "A" then trt=1;
  	else trt=2;
	drop TREAT;
** IF SAS DATASET, ACTIVATE THESE STATEMENTS **;


RUN;*PROC PRINT;*RUN;


%SORTDS(PARAME, &VARSORT)
RUN;
*/

DATA FIRMPK;
SET PARAME;
FIRMAREA=AUCT;
FIRMAUCI=AUCI;
FIRMCMAX=CMAX;
DROP AUCT AUCI CMAX;
DROP TMAX KE THALF;
RUN; *PROC PRINT;*RUN;


PROC SORT DATA=FIRMPK;
BY SUB PER TRT;
*PROC PRINT;RUN;

DATA FIRMREVIEWERRATIO;
SET FDAPK FIRMPK;
MERGE FDAPK FIRMPK;
BY SUB PER TRT GRP;

RAUCT=FIRMAREA/FDAarea;
RAUCI=FIRMAUCI/FDAAUCI;
RCMAX=FIRMCMAX/FDACMAX;
*DROP TMAX KEL KE THALF;


proc print;RUN;

*options orientation=landscape papersize=letter;

*ods rtf file="&concoutput" style=mystyle bodytitle;

*TITLE "&ANDA &STUDYTYPE REVIEWER VERIFIED CONCENTRATION DATASET";
*proc print data=plasma;
*run;


options orientation=landscape papersize=letter;

ods rtf file="&studydir\REVIEWERPK&studytype..RTF" /*style=mystyle bodytitle*/;
TITLE "&ANDA &STUDYTYPE REVIEWER-CALCULATED PHARMACOKINETIC DATASET";
proc print data=PK1;
VAR SUB TRT SEQ PER GRP AUCT AUCI CMAX TMAX THALFR KEL;
run;

options orientation=landscape papersize=letter;

ods rtf file="&studydir\FIRMREVIEWERRATIO&studytype..RTF" /*style=mystyle bodytitle*/;
TITLE "&ANDA &STUDYTYPE FIRM TO REVIEWER RATIO";
proc print data=FIRMREVIEWERRATIO;
*VAR RAUCT RAUCI RCMAX;
run;
ods rtf close;
/*************************************************************************/
/***END OF STEP 17********************/




data _null_;
  set updatedconc(where=(trt=1)) end=last;
  
  if last then call symput('testsub',trim(left(_N_)));
run;


data _null_;
  set updatedconc(where=(trt=2)) end=last;
  
  if last then call symput('refsub',trim(left(_N_)));
run;

/* PROC GLM  CALCULATE LSMEANS */
%MACRO GRPANALYSIS(TRTGP=);

	/** TRTGRP INTERACTION **/
	%if &trtgp=1 %then
	%do;
	%PROCGLM(BASE,2,SUB TRT PER SEQ GRP,AUCT,AUCI,CMAX,LAUCT,LAUCI,LCMAX,
	, , , , , ,GRP SEQ SEQ*GRP SUB(SEQ*GRP) PER(GRP) TRT TRT*GRP,SEQ GRP,SUB(SEQ*GRP))
	RUN;
	%end;

	/** No TRT*GRP Interaction **/
	%else %if &trtgp=2 %then
	%do;
	%PROCGLM(BASE,2,SUB TRT PER SEQ GRP,AUCT,AUCI,CMAX,LAUCT,LAUCI,LCMAX,
	, , , , , ,GRP SEQ SEQ*GRP SUB(SEQ*GRP) PER(GRP) TRT,SEQ GRP,SUB(SEQ*GRP))
	RUN;
	%end;

	/** NO GROUP EFFECT **/
	%else %do;
	%PROCGLM(BASE,2,SUB TRT PER SEQ,AUCT,AUCI,CMAX,LAUCT,LAUCI,LCMAX,
	, , , , , ,SEQ SUB(SEQ) PER TRT,SEQ,SUB(SEQ))
	RUN;
	%end;

%MEND GRPANALYSIS;

/* STATISTICS ON SUBMITTED DATA WITHOUT RECALCULATION */
DATA BASE;
SET NEW;
IF I=NO_ASSAY;

LAUCT=LOG(AUCT);
LAUCI=LOG(AUCI);
LCMAX=LOG(CMAX);
AUCRATIO=AUCT/AUCI;
OUTPUT;


/* TO RECALCULATE KE  */
%INCLUDE "&FNAME";

/* PRINT SUMMARY OF PARAMETERS */
%LET TITLE=SUMMARY OF PARAMETERS;
%*PRINT(BASE, &TITLE)
RUN;


options orientation=portrait papersize=letter;

TITLE "&STUDYTYPE STATISTICAL OUTPUT";
ods rtf file="&odsfile" style=mystyle1 bodytitle;

ods graphics off;

ods rtf exclude LSMeans;
ods rtf exclude AUCT.OverallANOVA
                AUCT.FitStatistics
				AUCT.ModelANOVA
				AUCT.AltErrTests
				AUCT.Estimates
				AUCI.OverallANOVA
                AUCI.FitStatistics
				AUCI.ModelANOVA
				AUCI.AltErrTests
				AUCI.Estimates
				CMAX.OverallANOVA
                CMAX.FitStatistics
				CMAX.ModelANOVA
				CMAX.AltErrTests
				CMAX.Estimates


				AUCT.MeanPlot
				AUCT.DiffPlot
			 	AUCI.MeanPlot
			    AUCI.DiffPlot
				CMAX.MeanPlot
				CMAX.DiffPlot

				LAUCT.MeanPlot
				LAUCT.DiffPlot
			 	LAUCI.MeanPlot
			    LAUCI.DiffPlot
				LCMAX.MeanPlot
				LCMAX.DiffPlot;




ods listing exclude LSMeans;

ods output "Estimates"=estimates;
ods output "Fit Statistics"=fitstat;
%GRPANALYSIS(TRTGP=&TRTGROUP);

ods graphics on;

DATA GLMOUT;
SET GLMOUT;
RENAME _NAME_=NNAME;
DATA LSMOUT;
SET LSMOUT;
RENAME _NAME_=NNAME;
/* TRANSFER DF FROM GLMOUT TO LSMOUT3 FOR CI CALCULATIONS */
DATA GLMOUT1;
SET GLMOUT;
IF _SOURCE_='ERROR';
IF NNAME='AUCT' OR
 NNAME='AUCI' OR
 NNAME='CMAX';
/* KEEP NNAME _SOURCE_ DF; */
%SORTDS(GLMOUT1, NNAME)
RUN;
%*PRINT(GLMOUT1,GLMOUT1)
RUN;
%*LET TITLE=LSMEANS AND STANDARD ERRORS;
%*PRINT(LSMOUT, &TITLE)
RUN;

/* CALCULATE T AND 90% CI FOR NON-TRANSFORMED DATA */
%LSMFILE(LSMOUT,TRT,2,AUCT,AUCI,CMAX,X,X,X,NNAME, OR)
RUN;

%MERGMULT(2,LSMOUT,GLMOUT1, , ,LSMDAT,NNAME)
RUN;
DATA LSMDAT;
SET LSMDAT;
/* FOR 90% CI, P=0.95 */

/* CACULATION OF T BASED ON P AND DF */
%CI(0.95,2);
%*PRINT(LSMDAT,LSMDAT)
RUN;

%LET TITLE=90% CONFIDENCE INTERVALS ON NON-TRANSFORMED DATA;
%*PRINT(LSMDAT, &TITLE)
RUN;

/* TRANSFER DF FROM GLMOUT TO LSMOUT33 FOR CI CALCULATIONS */

DATA GLMOUT11;
SET GLMOUT;
IF _SOURCE_='ERROR';
IF NNAME='LAUCT' OR
 NNAME='LAUCI' OR
 NNAME='LCMAX';
/* KEEP NNAME _SOURCE_ DF; */
%SORTDS(GLMOUT11, NNAME)
RUN;

/* CALCULATE T AND 90% CI FOR LOG-TRANSFORMED DATA */
%LSMFILE(LSMOUT,TRT,2,LAUCT,LAUCI,LCMAX, , , ,NNAME,OR)
RUN;

%MERGMULT(2,LSMOUT,GLMOUT11, , ,LLSMDAT,NNAME)
RUN;

*********************************************;
data estimates;
  set estimates;

  NNAME = dependent;
  
  keep NNAME estimate stderr;
run;

proc sort data=estimates;
  by nname;
run;

proc sort data=llsmdat;
  by nname;
run;

data llsmdat;
  merge llsmdat(in=a)
        estimates(in=b);
  by nname;
  if a;
run;

************************************************;


DATA LLSMDAT;
SET LLSMDAT;
/* FOR 90% CI, P=0.95 */
%CILOG(0.95,2);

%LET TITLE=90% CONFIDENCE INTERVALS ON LOG-TRANSFORMED DATA;
%*PRINT(LLSMDAT, &TITLE)
RUN;


/* STATISTICS ON TRT1/TRT2 RATIO */
%SPLITBY(BASE,TRT,2,SUB,AUCT,AUCI,CMAX,TMAX,KE,THALF)
RUN;

%MERGMULT(2,BASE, , , ,RATIODAT,SUB)
RUN;

%RATIOCAL(RATIODAT,2,AUCT,AUCI,CMAX,TMAX,KE,THALF)
RUN;



*** USE NOMINAL TIME TO CREATE MEAN BLOOD LEVEL ***;
DATA TCDATn;
SET NOMINALTIME;
KEEP TRT TIME CONC;
%LET BY=TRT TIME;

%SORTDS(TCDATn, &BY)
RUN;

*** USE ACTUAL TIME TO CREATE MEAN BLOOD LEVEL ***;
DATA TCDAT;
SET NEWCONC;
KEEP TRT TIME CONC;
%LET BY=TRT TIME;

%SORTDS(TCDAT, &BY)
RUN;


/* CALCULATE MEAN BLOOD LEVEL AT EACH TIME POINT */
TITLE "&TITLE2";
%MEANCAL(TCDATn, CONC, TRT TIME, CMEANOUTn)
RUN;

%MEANCAL(TCDAT, CONC, TRT TIME, CMEANOUT)
RUN;
%*PRINT(CMEANOUT, CMEANOUT)
RUN;

DATA CMEANOUT;
SET CMEANOUT;
DROP _TYPE_ _FREQ_ ;

%TRANSPOS(CMEANOUT, CMEAN, CONC, TRT TIME)
RUN;

DATA CMEANOUTn;
SET CMEANOUTn;
DROP _TYPE_ _FREQ_ ;

%TRANSPOS(CMEANOUTn, CMEANn, CONC, TRT TIME)
RUN;

%*PRINT(CMEAN, CMEAN)
RUN;

DATA CMEAN;
SET CMEAN;
RENAME COL4=MEAN
 COL5=SD;
DROP _NAME_ COL1 COL2 COL3;
%*PRINT(CMEAN, &TITLE1)
RUN;

DATA CMEANn;
SET CMEANn;
RENAME COL4=MEAN
 COL5=SD;
DROP _NAME_ COL1 COL2 COL3;

%SPLITBY(CMEAN,TRT,2,TIME,MEAN,SD,X,X,X,X)
RUN;

%SPLITBY(CMEANn,TRT,2,TIME,MEAN,SD,X,X,X,X)
RUN;

%MERGMULT(2,CMEAN, , , ,CMEANRAT,TIME)
RUN;

%MERGMULT(2,CMEANn, , , ,CMEANRATn,TIME)
RUN;

%*PRINT(CMEANRAT,CMEANRAT)
RUN;

%RATIOCAL(CMEANRAT,2,MEAN,X,X,X,X,X)
RUN;

%RATIOCAL(CMEANRATn,2,MEAN,X,X,X,X,X)
RUN;

DATA CMEANRAT;
SET CMEANRAT;
DROP TRT;
%*PRINT(CMEANRAT, &TITLE2)
RUN;

DATA CMEANRATn;
SET CMEANRATn;
DROP TRT;


%SORTDS(CMEANRAT, TIME)
RUN;

%SORTDS(CMEANRATn, TIME)
RUN;

%LET BY=TRT;
%SORTDS(BASE, &BY)
RUN;



%MACRO MEANCAL(DSN, VARN, BY, MEANOUT);
        PROC MEANS DATA=&DSN NOPRINT;
        VAR &VARN;
        BY &BY;
        OUTPUT OUT=&MEANOUT;
%MEND MEANCAL;


%MACRO univCAL(DSN, VARN, BY, MEANOUT);
        PROC univariate DATA=&DSN NOPRINT;
        VAR &VARN;
        BY &BY;
        OUTPUT OUT=&MEANOUT median=median;
%MEND univCAL;


/* CALCULATE MEAN PHARMACOKINETIC PARAMETERS */
%MEANCAL(BASE,AUCT AUCI CMAX TMAX KE THALF LAUCT LAUCI
LCMAX,TRT,PARMETER)
RUN;


***** TMAX - MEDIAN DP ********;
%univCAL(BASE,TMAX,TRT,PARMETERtmax)
RUN;


data parmeter;
  merge parmeter
        parmetertmax;
  by trt;
run;


data parmeter(drop=median);
  set parmeter;

  if _STAT_ = "MEAN" then tmax = median;
  if _STAT_ = "STD" then tmax = .;  ** for median tmax, no SD or CV **;
run;


%LET TITLE=SUMMARY OF PHARMACOKINETIC PARAMETERS;
%*PRINT(PARMETER, &TITLE)
RUN;

DATA PARM;
SET PARMETER;
DROP _TYPE_ _FREQ_ ;

PROC TRANSPOSE DATA=PARM OUT=TRSPARM;
VAR AUCT AUCI CMAX TMAX KE THALF LAUCT LAUCI LCMAX;
BY TRT;
RUN;
DATA TRSPARM;
SET TRSPARM;
RENAME _NAME_=NNAME;

%LET BY=NNAME TRT;
%SORTDS(TRSPARM, &BY)
RUN;


***DEV MARCH 23 07**:  COMMENT THIS OUT**;
/*
DATA TRSPARM;
SET TRSPARM;
DROP COL1 COL2 COL3;
RENAME COL4=MEAN
      COL5=SD;
RUN;
*/
*** COL1=N COL2=MIN COL3=MAX COL4=MEAN COL5=STD**;
DATA TRSPARM;
SET TRSPARM;
DROP COL1;
RENAME COL2=MIN COL3=MAX COL4=MEAN
      COL5=SD;
RUN;


%SPLITBY(TRSPARM,TRT,4,NNAME,MEAN,MIN,MAX,SD,X,X)
RUN;


%MERGMULT(2,TRSPARM, , , ,PARMRAT,NNAME)
RUN;


DATA PARMRATS;
SET PARMRAT;
IF %SETLST(NNAME,OR,AUCT,AUCI,CMAX,TMAX,KE,THALF);
%RATIOCAL(PARMRATS,2,MEAN,X,X,X,X,X)
RUN;
DATA PARMRATL;
SET PARMRAT;
IF %SETLST(NNAME,OR,LAUCT,LAUCI,LCMAX,X,X,X);
%RATIOLOG(PARMRATL,2,MEAN,X,X,X,X,X)
RUN;
%ANTILOG(PARMRATL,2,MEAN,X,X,X,X,X)
RUN;
DATA PKRATIO;
SET PARMRATS PARMRATL;
DROP TRT;

%LET TITLE=TEST MEAN/REFERENCE MEAN RATIO;
%*PRINT(PKRATIO, &TITLE)
RUN;

%ANTILOG(LLSMDAT,2,LSMEAN,X,X,X,X,X)
RUN;

DATA CIDAT;
SET LSMDAT LLSMDAT;
KEEP NNAME %LSMENLST(2,LSMEAN)  STDERR %CILST(2);

DATA CIDAT;
SET CIDAT;
%RE_NAME(2,LSMEAN,LSM)
RUN;

%SORTDS(CIDAT, NNAME)
RUN;
%*PRINT(CIDAT, CIDAT)
RUN;


%RATIOCAL(CIDAT,2,LSM,X,X,X,X,X)
RUN;


** DEV **;
** CALCULATE %CV **;
data cmeanrat;
  set cmeanrat;

  CV1 = round((sd1/mean1)*100,.01);
  CV2 = round((sd2/mean2)*100,.01);
run;

data cmeanratn;
  set cmeanratn;

  CV1 = round((sd1/mean1)*100,.01);
  CV2 = round((sd2/mean2)*100,.01);
run;

data pkratio;
  set pkratio;

  CV1 = round((sd1/mean1)*100,.01);
  CV2 = round((sd2/mean2)*100,.01);
run;



**DEV TEMPORARILY CLOSED ** MARCH 23 07***;
ods listing close;




** sort order of PK parameters **;
data pkratio;
  set pkratio;

  select(nname);
    when('AUCT') ordervar=1;
	when('AUCI') ordervar=2;
	when('CMAX') ordervar=3;
	when('TMAX') ordervar=4;
	when('KE') ordervar=5;
	when('THALF') ordervar=6;
	when('LAUCT') ordervar=7;
	when('LAUCI') ordervar=8;
	when('LCMAX') ordervar=9;
	otherwise;
  end;
run;

DATA PKRATIO;
  SET PKRATIO;

  IF NNAME IN("LAUCT","LAUCI","LCMAX") THEN DELETE;
RUN;


proc sort
  data=pkratio;
  by ordervar;
run;


data cidat;
  set cidat;

  select(nname);
    when('AUCT') ordervar=1;
	when('AUCI') ordervar=2;
	when('CMAX') ordervar=3;
	when('LAUCT') ordervar=4;
	when('LAUCI') ordervar=5;
	when('LCMAX') ordervar=6;
	otherwise;
  end;
run;

proc sort
  data=cidat;
  by ordervar;
run;

DATA cidat;
  SET cidat;

  IF NNAME IN("AUCT","AUCI","CMAX") THEN DELETE;
RUN;

 
data pkratio;
  set pkratio;

  if nname="AUCT" then units="&aucunit";
  if nname="AUCI" then units="&aucunit";
  if nname="CMAX" then units="&cmaxunit";
  if nname="TMAX" then units="&timeunit";
  if nname="KE" then units="&timeunit.-1";
  if nname="THALF" then units="&timeunit";
run;




data rootmse;
  set fitstat(keep=dependent rootmse);
  
  if dependent = "LAUCT" then ordervar=1;
  else if dependent="LAUCI" then ordervar=2;
  else if dependent="LCMAX" then ordervar=3;

  if dependent in("LAUCT","LAUCI","LCMAX") then output;
run;

proc sort
  data=rootmse;
  by ordervar;
run;



DATA AUCDAT;
SET BASE;
KEEP SUB TRT AUCRATIO;
PROC SORT DATA=AUCDAT;
BY TRT SUB;
RUN;


/* PROC MEANS ON AUCT/AUCI RATIOS */
PROC MEANS DATA=AUCDAT noprint MAXDEC=2 FW=9;
VAR AUCRATIO;
BY TRT;
OUTPUT OUT=AUCRATIO;
TITLE 'STATISTICS ON AUCT/AUCI RATIOS';
RUN;


PROC TRANSPOSE DATA=aucratio OUT=aucratio1;
VAR aucratio;
BY TRT;
RUN;

data aucratio1;
  length treat $12.;
  set aucratio1;

  rename col1=no col2=mini col3=maxi col4=avg col5=std;
  if trt=1 then treat="TEST";
  else if trt=2 then treat="REFERENCE";
run;



%LET TITLE=AUCT/AUCI RATIO FOR INDIVIDUAL SUBJECTS;
%PRINT(AUCDAT, &TITLE)
RUN;


PROC PRINT DATA=RATIODAT ROUND noobs;
VAR SUB SEQ %RATLST(2,AUCT,AUCI,CMAX,TMAX,KE,THALF);
FORMAT %RATLST(2,AUCT,AUCI,CMAX,TMAX,KE,THALF) 4.2;
TITLE 'TEST PRODUCT/REFERENCE PRODUCT RATIOS FOR INDIVIDUAL SUBJECTS';
RUN;


ods listing;

/* PROC MEANS ON TEST/REFERENCE RATIOS */
PROC MEANS DATA=RATIODAT MAXDEC=3 FW=9 noprint;
VAR %RATLST(2,AUCT,AUCI,CMAX,TMAX,KE,THALF);
OUTPUT OUT=MEANOUT;
TITLE 'STATISTICS ON THE TEST/REFERENCE RATIOS';
RUN;


DATA CHECKDAT;
SET BASE;

AUCTO_N=OLDAUCT/NEWAUCT;
AUCIO_N=OLDAUCI/NEWAUCI;
CMAXO_N=OLDCMAX/NEWCMAX;
TMAXO_N=OLDTMAX/NEWTMAX;

OUTPUT;
KEEP SUB TRT PER SEQ AUCTO_N AUCIO_N CMAXO_N TMAXO_N;
LABEL AUCTO_N='AUCT';
LABEL AUCIO_N='AUCI';
LABEL CMAXO_N='CMAX';
LABEL TMAXO_N='TMAX';

*%LET TITLE=RATIO OF SPONSOR/REVIEWER CALCULATED PARAMETERS;
*%PRINT(CHECKDAT, &TITLE)
*RUN;



%LET TITLE=AUCT/AUCI RATIO FOR INDIVIDUAL SUBJECTS;
%*PRINT(AUCRATIO, &TITLE)
RUN;

/* GOPTIONS DEVICE=EGAL; */     /* GOPTION #1 */
/* GOPTIONS DEVICE=FX85; */     /* GOPTION #2 */
/* GOPTIONS DEVICE=HPLJS2; */   /* GOPTION #3 */
/* GOPTIONS GACCESS='SASGASTD>LPT2:'; */  /* GOPTION #4 */
* GOPTIONS RESET=ALL DEVICE=WIN TARGETDEVICE=WINPRTM ftext=arial; /* GOPTION
#5 */

ods rtf close;


ods rtf file="&odsfile1" style=mystyle1 bodytitle;

TITLE "MEAN PLASMA CONCENTRATIONS - ACTUAL SAMPLING TIMES";
proc report data=cmeanrat nowd split='~' box
  style(header)={background=lightorange
                 foreground=black}
  style(column)={background=white
                 foreground=black};
  
  column time ("Test (n=&testsub)" mean1 cv1)
         ("Reference (n=&refsub)" mean2 cv2)
		 ("Ratio" rmean12);
  
  define time /order format=8.2 spacing=2 "Time (hr)";
  define mean1 /format=8.2 spacing=2 "Mean (&cmaxunit)";
  define cv1 /format=8.2 spacing=2 "CV%";
  define mean2 /format=8.2 spacing=2 "Mean (&cmaxunit)";
  define cv2 /format=8.2 spacing=2 "CV%";
  define rmean12 /format=8.2 spacing=2 "(T/R)";
run;

TITLE "MEAN PLASMA CONCENTRATIONS - SCHEDULED SAMPLING TIMES";
proc report data=cmeanratN nowd split='~' box
  style(header)={background=lightorange
                 foreground=black}
  style(column)={background=white
                 foreground=black};
  
  column time ("Test (n=&testsub)" mean1 cv1)
         ("Reference (n=&refsub)" mean2 cv2)
		 ("Ratio" rmean12);
  
  define time /order format=8.2 spacing=2 "Time (hr)";
  define mean1 /format=8.2 spacing=2 "Mean (&cmaxunit)";
  define cv1 /format=8.2 spacing=2 "CV%";
  define mean2 /format=8.2 spacing=2 "Mean (&cmaxunit)";
  define cv2 /format=8.2 spacing=2 "CV%";
  define rmean12 /format=8.2 spacing=2 "(T/R)";
run;

footnote "* Tmax values are presented as median, range.";
TITLE "ARITHMETIC MEANS AND RATIOS";
proc report data=pkratio nowd split='\' box
  style(header)={background=lightorange
                 foreground=black}
  style(column)={background=white
                 foreground=black};
  
  column nname units ("Test" mean1 cv1 min1 max1)
         ("Reference" mean2 cv2 min2 max2)
		 ("Ratio" rmean12);
  
  define nname /format=$12. spacing=2 "Parameter";
  define units /format=$12. spacing=2 "Unit";
  define mean1 /format=8.3 spacing=2 "Mean";
  define cv1   /format=8.2 spacing=2 "CV%";
  define min1  /format=8.2 spacing=2 "Min";
  define max1  /format=8.2 spacing=2 "Max";
  define mean2 /format=8.3 spacing=2 "Mean";
  define cv2   /format=8.2 spacing=2 "CV%";
  define min2  /format=8.2 spacing=2 "Min";
  define max2  /format=8.2 spacing=2 "Max";
  define rmean12 /format=8.2 spacing=2 "(T/R)";
run;
footnote;

TITLE "LSMEANS AND 90% CONFIDENCE INTERVALS";
proc report data=cidat nowd split='\' box
  style(header)={background=lightorange
                 foreground=black}
  style(column)={background=white
                 foreground=black};
  
  column nname ("Least Squares Geometric Mean" lsm1 lsm2)
         ("Ratio" rlsm12)
		 ("90% Confidence Intervals" lowci12 uppci12);
  
  define nname /format=$12. spacing=2 "Parameter";
  define lsm1  /format=8.2 spacing=2 "Test";
  define lsm2 /format=8.2 spacing=2 "Reference";
  define rlsm12 /format=8.2 spacing=2 "(T/R)";
  define lowci12 /format=8.2 spacing=2 "Lower";
  define uppci12 /format=8.2 spacing=2 "Upper";
run;


TITLE "ROOT MEAN SQUARE ERROR";
proc report data=rootmse nowd split='\' box
  style(header)={background=lightorange
                 foreground=black}
  style(column)={background=white
                 foreground=black};
  
  column dependent rootmse;
  
  define dependent /format=$12. spacing=2 "Parameter";
  define rootmse /format=8.4 spacing=2 "RMSE";

run;


TITLE "STATISTICS ON AUCT/AUCI RATIOS";
proc report data=aucratio1 nowd split='\' box
  style(header)={background=lightorange
                 foreground=black}
  style(column)={background=white
                 foreground=black};
  
  column treat no avg mini maxi;
  
  define treat /format=$12. spacing=2 "Treatment";
  define no /format=8. spacing=2 "n";
  define avg /format=8.2 spacing=2 "Mean";
  define mini /format=8.2 spacing=2 "Minimum";
  define maxi /format=8.2 spacing=2 "Maximum";
run;

ods rtf close;


filename concplot "&plotfile";

/*
goptions reset=all
         device=cgmof97p
         gsfname=concplot
         gsfmode=replace
         ftext=swiss
         rotate=portrait
	     targetdevice=winprtm;
*/

goptions reset=all device=png ftext="Arial" htext=12pt gsfname=concplot gsfmode=replace
  hsize=8 in vsize=10 in xpixels=3600 ypixels=2400;



TITLE2 "&TITLE3";
TITLE3 "&TITLE4";
TITLE4 "&TITLE5";
TITLE5 "&TITLE6";
FOOTNOTE1 "&FOOTNOT1";
SYMBOL1 C=RED I=JOIN V=dot  w=0.5 h=0.5;
SYMBOL2 C=BLUE I=JOIN V=SQUARE w=5 h=0.5;

AXIS1 label=(a=90 "&label1");

PROC GPLOT DATA=CMEANn UNIFORM;
PLOT MEAN*TIME=TRT / FRAME vaxis=axis1;
LABEL MEAN=("&LABEL1") TIME="&LABEL2";
RUN;
TITLE1;
TITLE2;
TITLE3;
TITLE4;
TITLE5;
TITLE6;

FOOTNOTE1;
FOOTNOTE2;
FOOTNOTE3;
LABEL;
QUIT;

