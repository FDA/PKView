
%macro Time_Profile(
        Input = ,
        TimeVar = ,
        AnalyteVar = ,
        PeriodVar = ,
        ResultVar = ,
        StudyDesign = ,
        StudyId = ,
        OutputFolder = 
);

%** Macro variables **;
%local i j k h;

%** Create output folder for time concentration profiles **;
%SmCheckAndCreateFolder(
    BasePath = &OutputFolder.,
    FolderName = Time Concentration Profiles
);



%*************************************************;
%**         Summarize the input dataset         **;
%*************************************************;
%** Sort **;
proc sort data = &Input.;
    by CohortNumber CohortName CohortDescription 
         
        TreatmentInPeriodText &TimeVar. &AnalyteVar.;
run;



%** Summarize and rename variables **;
proc summary data = &Input. nway missing;
    by CohortNumber CohortName CohortDescription       
         
        TreatmentInPeriodText &TimeVar. &AnalyteVar.;
    var &ResultVar.;
    output out = &work.ConcResult 
    
        sum=sum
        std = std
                
    ;
run;

data &work.ConcResult(where = (mean > 0));
set &work.ConcResult ;
MEAN=sum/_freq_;
drop  _freq_ _type_ sum ;
run;

%** Round the mean and standard deviations **;
data &work.ConcResult;
    set &work.ConcResult(where = (&TimeVar. ne .));
    MEAN = round(MEAN, 0.01);
    STD = round(STD, 0.01);

    MEAN_STD_LOWER = MEAN - STD;
    MEAN_STD_UPPER = MEAN + STD;
run;




%*************************************************;
%**                     Plot                    **;
%*************************************************;

%** Define the style **;
proc template;
    define style conc_plot;
        parent = styles.journal;

        class GraphData1 /
            linestyle = 1
            markersymbol = "Circle"
        ;
        class GraphData2 /
            linestyle = 1
            markersymbol = "CircleFilled"
        ;
        class GraphData3 /
            linestyle = 1
            markersymbol = "Square"
        ;
        class GraphData4 /
            linestyle = 1
            markersymbol = "SquareFilled"
        ;
        class GraphData5 /
            linestyle = 1
            markersymbol = "Triangle"
        ;
        class GraphData6 /
            linestyle = 1
            markersymbol = "TriangleFilled"
        ;
    end;
run;

%** Get the different comparision and analytes **;
proc sql noprint;
    select distinct
        CohortDescription
    into
        :CohortName_list separated by "@"
    from
        &work.ConcResult
    ;
    select distinct
        &AnalyteVar.
    into
        :Analyte_list separated by "@"
    from
        &work.ConcResult
    ;
quit;


%put cohortname_list is : &cohortname_list;
%put combination_list is : &combination_list;
%put Analyte_list is: &analyte_list;



%** Plot **;



%do k = 1 %to %sysfunc(countw(%quote(&CohortName_list.), @));
   
        %do j = 1 %to %sysfunc(countw(%quote(&Analyte_list.), @)); 
            %** Create output folder for forest plots and summary tables **;
            %SmCheckAndCreateFolder(
                BasePath = &OutputFolder.\Time Concentration Profiles,
                FolderName = Cohort&k.
            );

            %** Sort and subset **;
            proc sort data = &work.ConcResult(where = (
                CohortDescription = "%scan(%quote(&CohortName_list.), &k., @)" and
              
                &AnalyteVar. = "%scan(%quote(&Analyte_list.), &j., @)"
            ))
                out = &work.plot;
                by TreatmentInPeriodText &TimeVar.;
            run;

            %** Get the number of observations **;
            %SmGetNumberOfObs(Input = &work.plot);

            %if &NumberOfObs. >= 1 %then %do;
                
                %** Log plot **;
              ods listing style = conc_plot gpath = "&OutputFolder.\Time Concentration Profiles\Cohort&k.";
                ods graphics on / imagename = "&StudyId._log_ConcentrationPlot_&k._&j." noborder;
                title " Cohort: %scan(%quote(&CohortName_list.), &k., @) | Analyte: %scan(%quote(&Analyte_list.), &j., @)";
                
                proc sgplot data = &work.plot tmplout="%sysfunc(getoption(work))\sgtmpl_0_&k._&j.sas"; 
                    series  x = &TimeVar. y = MEAN          / group = TreatmentInPeriodText markers;
                    scatter x = &TimeVar. y = MEAN          / group = TreatmentInPeriodText yerrorupper = mean_std_upper;
                
                    xaxis label = "Nominal Time (h)";
                    yaxis logbase = 10 logstyle = logexpand type = log label = "Plasma Concentration (ng/ml)";
                run;
                ods graphics off;

          

               
               ods graphics on / imagename = "&StudyId._ConcentrationPlot_&k._&j." noborder;

                title "Cohort: %scan(%quote(&CohortName_list.), &k., @) | Analyte: %scan(%quote(&Analyte_list.), &j., @)";
              
                proc sgplot data = &work.plot tmplout="%sysfunc(getoption(work))\sgtmpl_1_&k._&j.sas";  
                    series  x = &TimeVar. y = MEAN          / group = TreatmentInPeriodText markers;
                    scatter x = &TimeVar. y = MEAN          / group = TreatmentInPeriodText yerrorupper = mean_std_upper;
                
                    xaxis label = "Nominal Time (h)";
                    yaxis label = "Plasma Concentration (ng/ml)";
                run;
                ods graphics off;
            
                %put FIXME -------DEBUG-------- FIXME;
                %put k = &k.;
          
                %put j = &j.;
                %put FIXME -------DEBUG-------- FIXME;
            %end;
        %end;

%end;



data &input.;
set &input.;
TreatmentInPeriodText=UPCASE(TreatmentInPeriodText);
run;

data &work.InputPCcat;
set &input.;
letter="a";
usubjidcat=trim(letter)||trim(usubjid);
drop usubjid;
rename usubjidcat=usubjid;
run;

/* Prepare individual concentration data set that will be sent to the UI */
data &work.IndividualConcentration;
length specimen $ 200;
    set &work.InputPCcat(
        rename=(
            USUBJID=Subject 
            CohortDescription=Cohort 
            &SequenceVar=Arm 
            &PeriodVar=Period 
            &AnalyteVar=Analyte 
            &PcSpecimenVar=Specimen 
            TreatmentInPeriodText=Treatment 
            &ResultVar=Result 
            &TimeVar=NominalTime 
            %if %upcase(&TimeVar.) =PCTPT %then %do;
                _&TimeVar=OriginalTime
            %end;
        )
        keep=USUBJID CohortDescription &SequenceVar &PeriodVar. &AnalyteVar. 
            &PcSpecimenVar. TreatmentInPeriodText &ResultVar. &TimeVar.
            %if %upcase(&TimeVar.) =PCTPT %then %do;
                _&TimeVar.
            %end;
        );

     if Specimen= "       "  then Specimen= "DEFAULT";
run;

data PCconc2;
    set &work.InputPCcat(
        rename=(
       
            &TimeVar=NominalTime 
            %if %upcase(&TimeVar.) =PCTPT %then %do;
                _&TimeVar=OriginalTime
            %end;
        )
        keep=USUBJID CohortDescription &SequenceVar &PeriodVar. &AnalyteVar. 
            &PcSpecimenVar. TreatmentInPeriodText &ResultVar. &TimeVar.
            %if %upcase(&TimeVar.) =PCTPT %then %do;
                _&TimeVar.
            %end;
        );
run;



data _null_;
set websvc.study;
call symput("SubjectCTCorrelation",SUBJECTCTCORRELATION);
run;

%put SUBJECTCTCORRELATION=&SUBJECTCTCORRELATION;


%macro integritycorrelation;

%IF &SUBJECTCTCORRELATION=1 %THEN %DO;
proc sql ;
select distinct Analyte into:PCAnalyteList separated by "$" from &work.IndividualConcentration;
select distinct Specimen into:PCSpecimenList separated by "$" from &work.IndividualConcentration;
select distinct Cohort into:PCCohortList separated by "$" from &work.IndividualConcentration;
select distinct Treatment into:PCTreatmentList separated by "$" from &work.IndividualConcentration;
quit;
/**data cleaning** removing all missing data**/
data &work.IndividualConcentration;
set &work.IndividualConcentration;
TREATMENT=UPCASE(TREATMENT);
if NOMINALTIME=. then delete;
if RESULT=. then delete;
run;

proc sql noprint;
select distinct Analyte into:PCAnalyteList separated by "$" from &work.IndividualConcentration;
select distinct Specimen into:PCSpecimenList separated by "$" from &work.IndividualConcentration;
select distinct Cohort into:PCCohortList separated by "$" from &work.IndividualConcentration;

quit;

%put integrity different levels -analytelist is:&PCAnalyteList., cohortlist is:&PCCohortList. ,treatmentlist is: &PCTreatmentList.;

/*step 1: generate table of all treatments in on sheet*/
%do a= 1 %to %sysfunc(countw(%quote(&PCAnalyteList.), $));
    %do b = 1 %to %sysfunc(countw(%quote(&PCSpecimenList.), $));
        %do c = 1 %to %sysfunc(countw(%quote(&PCCohortList.), $));
/*            %do d = 1 %to %sysfunc(countw(%quote(&PCTreatmentList.), $));*/

            data IndConc_&a._&b._&c.(where=(Analyte="%scan(%quote(&PCAnalyteList.), &a., $)"  and 
                                Specimen="%scan(%quote(&PCSpecimenList.), &b., $)"  and 
                                cohort="%scan(%quote(&PCCohortList.), &c., $)" ));
            set &work.IndividualConcentration;
            run;

            proc sql noprint;
            select count(*) into:checkobs from  IndConc_&a._&b._&c.;
            quit;
            %if &checkobs ne 0 %then %do;

            %put  checkobs not equal to 0 meaning indconc is existing;

            /*data preparation- remove redundant string*/
            data IndConc_&a._&b._&c.;
            set IndConc_&a._&b._&c.;
            subjectback=substr(subject,2,length(subject));
            drop subject;
            rename subjectback=subject;
            run;

            data IndConcLong_&a._&b._&c.;
            retain subject Treatment period originalTime nominaltime result;
            set IndConc_&a._&b._&c.;
            keep subject period OriginalTime nominaltime result Treatment;
            run;

/*            proc sort data=IndConcLong_&a._&b._&c. NODUPKEY;*/
/*            by  Treatment period subject  nominaltime originalTime result ;*/
/*            run;*/

            data IndConcLong_&a._&b._&c.;
            length sub_trt $200.;
            set IndConcLong_&a._&b._&c.;
            %do n = 1 %to %sysfunc(countw(%quote(&PCTreatmentList.), $));
             if treatment="%scan(%quote(&PCTreatmentList.), &n., $)"  then shorttrt="TRT&n.";
            %end;
            sub_trt=catx("_",of subject shorttrt);
            run;


            data IndConcLong_&a._&b._&c.;
             length newsub_trt $200.;
            set IndConcLong_&a._&b._&c.;
            newsub_trt=tranwrd(sub_trt, "-","_");
            run;

            proc sort data=IndConcLong_&a._&b._&c.;
            by nominaltime;
            run;
              
            proc transpose data=IndConcLong_&a._&b._&c. out=IndConcWide_&a._&b._&c. LET;
            by nominaltime;
            id sub_trt;
            var result;
            run;

            data IndConcWide_&a._&b._&c.;
            set IndConcWide_&a._&b._&c.;
            drop _NAME_ _LABEL_  ;
            run;

            proc sql noprint;
            select distinct newsub_trt into: newsub_trtlist separated by " " from IndConcLong_&a._&b._&c.;
            select distinct Treatment into:PCTreatmentList separated by "$" from IndConcLong_&a._&b._&c.;
            quit;
            %put &newsub_trtlist;

             %put  got &OutputFolder.;
            %SmCheckAndCreateFolder(
                BasePath = &OutputFolder.,
                FolderName = Integrity Tests
            );
            %SmCheckAndCreateFolder(
                BasePath = &OutputFolder.\Integrity Tests,
                FolderName = Subject C_T Correlation
            );
             %SmCheckAndCreateFolder(
                        BasePath = &OutputFolder.\Integrity Tests\Subject C_T Correlation,
                        FolderName =%scan(%nrbquote(&PCAnalyteList.), &a., $)_%scan(%nrbquote(&PCSpecimenList.), &b., $)
                    );
                 
            proc corr data=IndConcWide_&a._&b._&c. outp=corrresult_&a._&b._&c. noprint;
            var &newsub_trtlist;         
            run;

            data corrresult_&a._&b._&c. ;
            set corrresult_&a._&b._&c. ;
            rename _TYPE_=Statistics _NAME_=Sub_Trt;
            run;

             /*mark specific results*/        

             proc format;
             value markresult 0.99<-0.99999=red
                              0.98<-0.98999=yellow;
             run;

             ods tagsets.excelxp file="&OutputFolder.\Integrity Tests\Subject C_T Correlation\%scan(%nrbquote(&PCAnalyteList.), &a., $)_%scan(%nrbquote(&PCSpecimenList.), &b., $)\All TRTs_Cohort&c..xls" 
                style=statistical ;
             ods tagsets.excelxp options( sheet_name="Pearson Correlation Coefficient" embedded_titles='yes' embedded_footnotes='yes' );

                title "Pearson Correlation Coefficient for All Treatments";
                %do n = 1 %to %sysfunc(countw(%quote(&PCTreatmentList.), $));
                    footnote&n. j=left height=10pt color=red   "TRT&n.:%scan(%quote(&PCTreatmentList.), &n., $)";
                %end;

                proc print data=corrresult_&a._&b._&c. noobs;
                var Statistics Sub_Trt;
                var &newsub_trtlist/style=[background=markresult.];  
                run;
            ods tagsets.excelxp close;
         


            /*step 2: generate correlation by treatment: two treatments:trt1 vs trt2, trt1 vs trt3, trt1 vs trt1, trt2 vs trt2*/
            ods tagsets.excelxp file="&OutputFolder.\Integrity Tests\Subject C_T Correlation\%scan(%nrbquote(&PCAnalyteList.), &a., $)_%scan(%nrbquote(&PCSpecimenList.), &b., $)\By TRT_Cohort&c..xls"  style=statistical ;                            
                /*subset the original table to generate by trt*/
                %do d=1 %to %sysfunc(countw(%nrquote(&PCTreatmentList.),$));
                    %do e=1 %to %sysfunc(countw(%nrquote(&PCTreatmentList.),$));

                        %if &d.<=&e. %then %do;

                            data IndConcLong_&a._&b._&c._&d.;
                            set IndConcLong_&a._&b._&c.;
                            where Treatment="%scan(%nrquote(&PCTreatmentList.), &d., $)";
                            run;

                            data IndConcLong2_&a._&b._&c._&e.;
                            set IndConcLong_&a._&b._&c.;
                            where Treatment="%scan(%nrquote(&PCTreatmentList.), &e., $)";
                            run;

                            proc sql noprint;
                            select distinct newsub_trt into: newsub_bytrtlist1 separated by " " from IndConcLong_&a._&b._&c._&d.;    
                            select distinct newsub_trt into: newsub_bytrtlist2 separated by " " from  IndConcLong2_&a._&b._&c._&e.;
                            quit;
                            %put  get subtrt bytrtlist: &newsub_bytrtlist1;

                            /*create macro variables for trtd vs trte*/

                            data _null_;
                            set IndConcLong_&a._&b._&c._&d.;
                            call symput("treatmentd",shorttrt);
                            run;

                            data _null_;
                            set  IndConcLong2_&a._&b._&c._&e.;
                            call symput("treatmente",shorttrt);
                            run;
                            %put trtd: &treatmentd;
                            %put trte: &treatmente;

                            proc corr data=IndConcWide_&a._&b._&c. outp=corrresult_&a._&b._&c._&d.&e. noprint;;
                            var &newsub_bytrtlist1 ;
                            with &newsub_bytrtlist2;
                            run;

                            data corrresult_&a._&b._&c._&d.&e.;
                            set corrresult_&a._&b._&c._&d.&e.;
                            rename _TYPE_=Statistics _NAME_=Sub_Trt;
                            run;

                            /*output*/              
                            ods tagsets.excelxp options( sheet_name="&treatmentd. vs &treatmente."embedded_titles='yes' embedded_footnotes='yes' );

                            title1 "Pearson Correlation Coefficients";
                            title2 "&treatmentd.:%scan(%nrquote(&PCTreatmentList.), &d., $) VS &treatmente.:%scan(%nrquote(&PCTreatmentList.), &e., $)";

                            %if &d.=&e. %then %do; 
                                footnote1 j=left height=10pt color=red  "&treatmentd.:%scan(%nrquote(&PCTreatmentList.), &d., $)";                            
                            %end;

                            %if &d.<&e. %then %do; 
                                footnote1 j=left height=10pt color=red  "&treatmentd.:%scan(%nrquote(&PCTreatmentList.), &d., $)";
                                footnote2 j=left height=10pt color=red "&treatmente.:%scan(%nrquote(&PCTreatmentList.), &e., $)";                          
                            %end;

                            proc format;
                            value markresult 0.99<-0.99999=red
                            0.98<-0.98999=yellow;
                            run;

                            proc print data=corrresult_&a._&b._&c._&d.&e. noobs;
                            var Statistics Sub_Trt;
                            var &newsub_bytrtlist1/style=[background=markresult.];  
                            run;
                        
                        %end;                           
                    %end;/*e ends*/
                %end;/*d ends*/
            ods tagsets.excelxp close;


            %end;/*file exist*/
        %end;/*c ends*/
    %end;/*b ends*/
%end;/*a ends*/


%END;
%mend;
%integritycorrelation;


%mend;
