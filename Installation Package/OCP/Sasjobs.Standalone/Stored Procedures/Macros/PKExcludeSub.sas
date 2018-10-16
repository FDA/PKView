
%macro PKExcludeSub;

/*step 1-1,2,3: show user selected data and exlude data based on 2 criteria*/

/* Read mappings from websvc input dataset (provided by C#) */
%SmReadMappingsFromDataSet();

/* Read report settings from websvc input dataset (provided by C#) */
%SmReadReportSettingsFromDataSet();

/* Retrieve NDA Id */
%let Nda_Number=&SubmissionId.;

/* Generate output path based on NDA Id, User Id and settings Id */
%let OutputFolder = &SasSpPath.\Output Files\PKView\&UserName.\&ProfileName.\&nda_number.\&SupplementNum;
%put OutputFolder=&outputfolder;

/*libname pkOutput "&OutputFolder.";*/
/* Locate and load estimates file */
%let EstimatesPath = &OutputFolder.\&StudyId.\estimates;
libname result "&EstimatesPath"; /*generate result.estimates*/  

%global  SequenceVar PeriodPcVar PeriodPpVar AnalytePcVar AnalytePpVar 
ResultPcVar ResultPpVar TimeVar ParameterVar ExTrtVar ExDateVar ExPeriodVar
AnalyteVar ParameterVar obsnum ResultFolder;

/*Assign the macro variable back because of different naming*/
%let SequenceVar = &ArmVar.;
%let ExDateVar = &ExStdtcVar.;
%let PeriodExVar = &ExVisitVar.;

%let PeriodPcVar= &PcVisitVar.;
%let ResultPcVar = &PcStresnVar.;
%let AnalytePcVar = &PcTestVar.;
%let TimeVar = &PctptnumVar.;

%let PeriodPpVar= &PpVisitVar.;
%let ResultPpVar = &PpStresnVar.;
%let AnalytePpVar = &PpCatVar.;
%let ParameterVar = &PpTestcdVar.;

/*assign macro variable of analyte and parameter from PP datasets for excel and forest plots generation*/
%let AnalyteVar=&AnalytePpVar.;
%let ParameterVar=&PpTestcdVar.;

%put AnalyteVar=&AnalyteVar;
%put ParameterVar=&ParameterVar;

data result.IndividualPkStats;
set result.IndividualPkStats;
OrgPPSTRESN=exp(PPSTRESN);
run;

/*STEP1: input data checking*/
/*fix me- need to remove parameters*/

data _null_;
set websvc.excludesubject;
call symput("times1",SMALLTHANEXCLUDESD);
call symput("times2",BIGTHANEXCLUDESD);
call symput("p1",ExcludeParameters1);
call symput("p2",ExcludeParameters2);
call symput("percent",percent);
run;
%put SMALLTHANEXCLUDESD=&times1;
%put BIGTHANEXCLUDESD=&times2;
%put excludeparameters1=&p1;
%put excludeparameters=&p2;
%put percent=&percent;


/*fix UI setting errors*/
%if &times1=0  %then %let times1=.;
%if &times2=0 %then %let times2=.;
%if &percent=0 %then %let percent=.;
%put SMALLTHANEXCLUDESD=&times1;
%put BIGTHANEXCLUDESD=&times2;
%put percent2=&percent;




/*user input no any parameter into exclude data*/
%if &times1=. and &times2=. and &p1=   and &p2=   and &percent=.  %then %do;
%put user did not exclude subject;

    proc sort data=result.individualpkstats;
    by CohortDescription &AnalytePPVar.  &ParameterVar. TreatmentInPeriodText usubjid;
    run;

    data &work.removedinput;
    set result.individualpkstats;
    by CohortDescription &AnalytePPVar.  &ParameterVar. TreatmentInPeriodText usubjid;
    run;
%end;

%else %do;
%put user input data to exclude subject;
    %do i = 1 %to %sysfunc(countw(%quote(&cohort_sel.), $));
        %do m= 1 %to %sysfunc(countw(%quote(&anal_sel.), $));
            %do q= 1 %to %sysfunc(countw(%quote(&param_sel.), $));              
                data SelectedSubPK_&i._&m._&q.;
                set result.individualpkstats (where = ( CohortDescription = "%scan(%quote(&Cohort_sel.), &i., $)" and                                                
                                                &AnalyteVar ="%scan(%quote(&anal_sel.), &m., $)" and
                                                &ParameterVar = "%scan(%quote(&param_sel.), &q., $)" ));
                run;

                %put SelectCohort=&cohort_sel;
                %put SelectAnalyte=&anal_sel;
                %put SelectParameter=&param_sel;

                /*STEP1-2: exclude subject */
                /*criteria 1*/
                proc sort data=SelectedSubPK_&i._&m._&q.;
                by cohortnumber &AnalyteVar &ParameterVar treatmentinperiodtext ;
                run;
                %put &AnalyteVar &ParameterVar;


                proc summary data=SelectedSubPK_&i._&m._&q. ;
                by cohortnumber &AnalyteVar &ParameterVar treatmentinperiodtext ;
                var OrgPPSTRESN;
                output out=StatsPK_&i._&m._&q. std=std mean=mean;
                run;

                proc sql;
                create table mergesubstd_&i._&m._&q. as
                select 
                a.cohortnumber, a.&AnalyteVar , a.&ParameterVar, a.treatmentinperiodtext, b.std, b.mean, CohortDescription, USUBJID,combination,PPSTRESN, OrgPPSTRESN
                from 
                   SelectedSubPK_&i._&m._&q. as a
                left join
                    StatsPK_&i._&m._&q. as b
                on a.cohortnumber=b.cohortnumber and a.&AnalyteVar=b.&AnalyteVar and a.&ParameterVar=b.&ParameterVar and a.treatmentinperiodtext=b.treatmentinperiodtext;
                quit;
             
                /*Input data for criteria1*/
/*               %if %sysevalf(%superq(times)=,boolean) ne 1 %then %do;*/
               %if &times1 ne . and &times2 ne .  %then %do;
               %put neither times1 nor  times2 is null , times2 is upper bound times1 is lower bound;

                    /*only includes data need to be removed*/
                    data mergesubstd_&i._&m._&q.;
                    set mergesubstd_&i._&m._&q.;
                    upperbound=mean+&times2*std;
                    lowerbound=mean-&times1*std;
                    if OrgPPSTRESN>upperbound or OrgPPSTRESN<lowerbound  then Decision="remove";
                    /*if usubjid="N01075-001-0001" or usubjid="N01075-001-0002" then Decision="remove";*/
                    run;

                    data criteria1_&i._&m._&q.;
                    set mergesubstd_&i._&m._&q.;
                    where Decision="remove";
                    run;

                    proc sql;
                    select count(*) into:obsnum1 from  criteria1_&i._&m._&q.;
                    quit;
                    %put obsnum1=&obsnum1;

                    %if &obsnum1 ne 0 %then %do;/*criteria1_&i._&m._&q. contain data*/
                        proc sort data=criteria1_&i._&m._&q.;
                        by cohortdescription &AnalyteVar treatmentinperiodtext usubjid;
                        run;

                        proc transpose data=criteria1_&i._&m._&q. out=widecriteria1_&i._&m._&q. LET;
                        by cohortdescription &AnalyteVar Treatmentinperiodtext usubjid ;
                        id &parametervar;
                        var usubjid;
                        run;

                        data widecriteria1_&i._&m._&q.;
                        set widecriteria1_&i._&m._&q.;
                        drop _NAME_ _LABEL_ usubjid ;
                        run;
                    %end;
                    %else %do;/*criteria1_&i._&m._&q. contain no data*/
                    %put criteria1_&i._&m._&q. contain no data;
                    %let output1=0;
                    %end;
                %end;/*Input data for criteria1 ends*/




                /*Input data for criteria2 (p1, p2 and percent must be input at same time)*/
/*                %if %sysevalf(%superq(p1)=,boolean) ne 1 and %sysevalf(%superq(p2)=,boolean) ne 1 and %sysevalf(%superq(percent)=,boolean) and 1 %then %do;*/
                %if &p1 ne  and &p2 ne and &percent ne .  %then %do;
                %put p1 p2 and percent must not be null;
                    /*criteria 2*/
                    data criteria2_&i._&m._&q.;
                    set result.individualpkstats(where=(&parametervar="&p1" or &parametervar="&p2"));
                    run;

                    proc sort data=criteria2_&i._&m._&q. ;
                    by usubjid cohortdescription &analytevar treatmentinperiodtext;
                    run;

                    proc transpose data=criteria2_&i._&m._&q. out=widecriteria2_&i._&m._&q. LET;
                    by usubjid cohortdescription &analytevar treatmentinperiodtext;
                    var Orgppstresn ;
                    id &parametervar;
                    run;

                    /*calculate and mark subject id by criteria 2*/
                    data widecriteria2_&i._&m._&q.;
                    set widecriteria2_&i._&m._&q.;
                    AUCI_AUCT=&p1/&p2;
                    if AUCI_AUCT>&percent/100  then Decision="remove";
                    run;

                    /*get the subject id with removed only and format the output*/
                    data widecriteria2_&i._&m._&q.;
                    set widecriteria2_&i._&m._&q.;
                    where  Decision="remove";
                    drop _NAME_ AUCI_AUCT Decision;
                    run;



                    /*only output the user selected analyte */


                    data widecriteria2_&i._&m._&q.;
                    set widecriteria2_&i._&m._&q.(where=(&AnalyteVar ="%scan(%quote(&anal_sel.), &m., $)" ));
                    run;




                    proc sql;
                    select count(*) into:obsnum2 from widecriteria2_&i._&m._&q.;
                    quit;
                    %put obsnum2=&obsnum2;

                    %if obsnum2 ne 0 %then %do;

                        data widecriteria2new_&i._&m._&q.;
                        set widecriteria2_&i._&m._&q.;
                        if &p1 ne . then p1=USUBJID;
                        /*if &p2 ne . then p2=USUBJID;*/
                        drop &p1 &p2 usubjid;
                        rename p1=&p1;
                        run;

                        proc sort data=widecriteria2new_&i._&m._&q. nodupkey;
                        by CohortDescription &analytevar TreatmentInPeriodText &p1;
                        run;
                    %end;
                    %else %do;
                    %put no data in widecriteria2_&i._&m._&q.;
                    %let output2=0;
                    %end;

               %end;/*Input data for criteria2 */

                    %if %sysfunc(exist(widecriteria1_&i._&m._&q.)) and  %sysfunc(exist(widecriteria2new_&i._&m._&q.)) %then %do;
                        data criteria_&i._&m._&q.;
                        set widecriteria1_&i._&m._&q. widecriteria2new_&i._&m._&q.;
                        if cohortdescription eq "                   "  then delete;
                        run;

/*                        proc sort data=criteria_&i._&m._&q. nodupkey;*/
/*                        by CohortDescription PPCAT TreatmentInPeriodText &p1;*/
/*                        run;  */
                    %end;

                    %else %if %sysfunc(exist(widecriteria1_&i._&m._&q.)) %then %do;
                        data criteria_&i._&m._&q.;
                        set widecriteria1_&i._&m._&q.;
                        if cohortdescription eq "                   "  then delete;
                        run;
                    %end;

                    %else %if %sysfunc(exist(widecriteria2new_&i._&m._&q.)) %then %do;
                        data criteria_&i._&m._&q.;
                        set widecriteria2new_&i._&m._&q.;
                        if cohortdescription eq "                   "  then delete;
                        run;

/*                        proc sort data=criteria_&i._&m._&q. nodupkey;*/
/*                        by CohortDescription PPCAT TreatmentInPeriodText &p1;*/
/*                        run;   */
  
                    %end;
                    %else %do;
                       data &work.ExcludeSubject;
                       stop;
                       set result.IndividualPkStats;
                       run;

                    %end;

                           
            %end;
        %end;
    %end;/*user selected cohort, analyte and parameter end*/



    /*step2: intemediate data existing and observation existing checking*/
    data &work.ExcludeSubject;
        set 
        %do i = 1 %to %sysfunc(countw(%quote(&cohort_sel.), $));       
            %do m= 1 %to %sysfunc(countw(%quote(&anal_sel.), $));
                %do q= 1 %to %sysfunc(countw(%quote(&param_sel.), $));
                    %if %sysfunc(exist(criteria_&i._&m._&q.)) %then %do;
                        criteria_&i._&m._&q.
                    %end;
                %end;
            %end;
        %end;
    ;
    run;


    proc contents data=&work.ExcludeSubject varnum noprint out=varname ;
    run;

    proc sql noprint;
    select distinct name into: varnamelist separated by " " from varname;
    quit;
    %put &varnamelist;


    proc sort data=&work.ExcludeSubject nodupkey;
    by &varnamelist;
    run;

    /* step3:output results to C#*/
    data &work.data NOLIST;
            length dataset $32.;
            dataset="ExcludeSubject"; 
    output;
    run;


	
%if %sysfunc(exist(&work.ExcludeSubject)) %then %do;
proc export data=&work.ExcludeSubject
		outfile="\\&SYSHOSTNAME.\Output Files\PkView\Peter\ExcludeSubject.csv"
		dbms=dlm replace;
		delimiter=',';
		run; 
%end;







   /* STEP4: removed pk individual data as input to model*/
    proc sql;
    select count(*) into:obsnum from  &work.ExcludeSubject;
    quit;
    %put obsnum=&obsnum;

    %if &obsnum ne 0 %then %do;
        proc contents data=&work.excludesubject varnum noprint out=&work.excludeParam;run;

        data &work.excludeparam1;
        set &work.excludeparam;
        where name ne "&AnalytePPVar" and name ne "CohortDescription" and name ne "TreatmentInPeriodText";
        run;

        proc sql noprint ;
        select distinct name into:arraylist separated by " " from &work.excludeparam1;
        select distinct name into: excludedparamlist separated by "$" from &work.excludeparam1;
        select count(distinct(name)) into: number from &work.excludeparam1;
        quit;

        %put excludeparamlist=&excludedparamlist;
        %put arraylist=&arraylist;
        %put number=&number;

        data &work.toremove;
        length usubjid pptestcd $ 200 ;
        set &work.excludesubject;
        array n[&number] &arraylist;
        %do i=1 %to &number;
            USUBJID=n[&i];
            PPTESTCD= "%scan(%quote(&excludedparamlist.), &i., $)";
            output;
            %end;
        run;

        data &work.subtoremove;
        set &work.toremove;
        if usubjid eq "                           " then delete;
        drop &arraylist;
        run;

        proc sort data=&work.subtoremove;
             by CohortDescription &AnalytePPVar. &ParameterVar. TreatmentInPeriodText usubjid;
        run;

        proc sort data=result.individualpkstats;
            by CohortDescription &AnalytePPVar.  &ParameterVar. TreatmentInPeriodText usubjid;
        run;

        data &work.removedinput;
             merge &work.subtoremove(in=a) result.individualpkstats(in=b);
             by CohortDescription &AnalytePPVar.  &ParameterVar. TreatmentInPeriodText usubjid;
             if b and not a;
        run;
    %end;


    %else %do;
        proc sort data=result.individualpkstats;
            by CohortDescription &AnalytePPVar.  &ParameterVar. TreatmentInPeriodText usubjid;
        run;
        data &work.removedinput;
            set result.individualpkstats;
             by CohortDescription &AnalytePPVar.  &ParameterVar. TreatmentInPeriodText usubjid;
        run;
    %end;
%put user input data to exclude subject ends;
%end;


/*save removedinput into ESTIMATE folder*/
data result.removedinput;
    set &work.removedinput;
run;
/*do not process %SubInExPlot if did not hit exclude subject*/
%if %sysfunc(exist(&work.subtoremove)) and %sysfunc(upcase(&studydesign)) ne PARALLEL %then %do;

    %macro SubInExPlot;
    %put meng gets studydesign:&studydesign;
    %put obsnum=&obsnum;
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


    proc transpose data=plotsub out=plotsubwide_org let;
    by category CohortDescription &AnalytePPVar.  &ParameterVar. combination usubjid;
    id trtformat;
    var orgppstresn;
    run;

    data plotsub_nocat;
    set plotsub;
    drop category;
    run;

    proc sort data=plotsub_nocat;
    by cohortdescription &AnalytePPVar.  &ParameterVar. combination usubjid;
    run;

    proc transpose data=plotsub_nocat out=plotsubwide_nocat let;
    by CohortDescription &AnalytePPVar.  &ParameterVar. combination usubjid;
    id trtformat;
    var orgppstresn;
    run;

    /*split exclude and include , use the new exclude to replace*/
    data allinclude;
    set plotsubwide_org;
    where category="include";
    run;

    data allexclude;
    set plotsubwide_org;
    where category="exclude";
    keep CohortDescription &AnalytePPVar.  &ParameterVar.  combination usubjid _NAME_;
    run;

    proc sort data=plotsubwide_nocat;
    by usubjid CohortDescription &AnalytePPVar.  &ParameterVar.  combination ;

    proc sort data=allexclude;
    by usubjid CohortDescription &AnalytePPVar.  &ParameterVar.  combination ;


    data allexclude_new;
    merge plotsubwide_nocat(in=a) allexclude(in=b);
    by usubjid CohortDescription &AnalytePPVar.  &ParameterVar. combination ;
    if b;
    category="exclude";
    run;

    data plotsubwide;
    set allexclude_new allinclude;
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

    proc sql noprint; 
    select distinct combination into : combgroup separated by "$" from  SubInExPlot_&a._&b._&c;
    quit;
    %put combgroup=&combgroup in  SubInExPlot_&a._&b._&c;
    /*result folder*/
    %do d=1 %to %sysfunc(countw(%nrquote(&combgroup ),$));

    data SubInExPlot_&a._&b._&c._&d.;
    set SubInExPlot_&a._&b._&c;
    where combination="%scan(%nrquote(&combgroup),&d.,$)";
    run;

    %put meng is here to debug output folder;

        %SmCheckAndCreateFolder(
        BasePath = &OutputFolder.\&StudyId.,
        FolderName = &ReportFolder
        );
     %let ResultFolder = &OutputFolder.\&StudyId.\&ReportFolder;   

    %SmCheckAndCreateFolder(
    BasePath = &ResultFolder,
    FolderName = InExSubratio
    );
    %SmCheckAndCreateFolder(
    BasePath = &ResultFolder\InExSubratio,
    FolderName =cohort&a.
    );

    %SmCheckAndCreateFolder(
    BasePath = &ResultFolder\InExSubratio\cohort&a.,
    FolderName =%scan(%nrquote(&analyteforplot),&b.,$)
    );

    %SmCheckAndCreateFolder(
    BasePath =&ResultFolder\InExSubratio\cohort&a.\%scan(%nrquote(&analyteforplot),&b.,$),
    FolderName =%scan(%nrquote(&parametersforplot),&c.,$)
    );

    ods listing gpath = "&ResultFolder\InExSubratio\cohort&a.\%scan(%nrquote(&analyteforplot),&b.,$)\%scan(%nrquote(&parametersforplot),&c.,$)" style=statistical sge=on;
    ods graphics on / imagename = "SubInExPlot_&a._&b._&c._&d." noborder height=2300 width=2500 ;
    filename grafout "&ResultFolder\InExSubratio\cohort&a.\%scan(%nrquote(&analyteforplot),&b.,$)\%scan(%nrquote(&parametersforplot),&c.,$)\SubInExPlot_&a._&b._&c._&d..jpeg";
    goptions reset=all gsfname=grafout gsfmode=replace device=JPEG hsize=15 vsize=12;
    title "Include and Exclude Subject Ratio ";
    title1 "Cohort:%scan(%nrquote(&cohortforplot),&a.,$)";
    title2 "Analyte:%scan(%nrquote(&analyteforplot),&b.,$)";
    title3 "Parameter: %scan(%nrquote(&parametersforplot),&c.,$)";

    proc sgpanel data=SubInExPlot_&a._&b._&c._&d. noautolegend;
    panelby comparison/novarname layout=columnlattice;
    scatter x=category y=subratio/markerattrs=(symbol=circle size=5 color=blue) datalabel=labelID;

    rowaxis grid offsetmin=0 label="Subject Ratio"  valueattrs=(size=10); 
    colaxis grid label="Category" valueattrs=(size=10); 
    run; 
    ods listing sge=off;
    ods graphics off;
    %end; /*end d*/
    %end;
    %end;
    %end;

    %mend;
    %SubInExPlot;
%end;
%mend PKExcludeSub;
