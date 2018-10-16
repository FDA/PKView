%*****************************************************************************************;
%**                                                                                     **;
%** Run script to get the SDTM mappings and study design                                **;
%**                                                                                     **;
%** Created by:                                                                         **;
%**     Jens Stampe Soerensen  (2013/2014)                                              **;
%**                                                                                     **;
%*****************************************************************************************;

%macro PkViewGetMapping();
    %** Read the InputFolder and SubmissionId from the SAS web service **;
    %if %sysfunc(exist(websvc.sasdata)) %then %do;
        data _null_;
            set websvc.sasdata;
            call symputx("InputFolder", InputFolder);
        run;
    %end;

    %** Debug **;
    %put InputFolder = &InputFolder.;

    %** List the files in the input folder **;
    %SmListFilesInFolder(
        Path = &inputfolder.,
        Out = &work.files
    );

    %** Get the path to the datasets **;
    data _null_;
        set &work.files end = eof;
        if scan(upcase(path), -1, "\") = "DATASETS" then do;
            call symputx("DatasetPath", path);
            stop;
        end;
    run;

    %** Debug **;
    %put DatasetPath = &DataSetPath.;

    %** Variable to note if the mapping succeeded (used below) **;
    %let MappingStatus = FAILURE;

    %** For each search criteria (intrinsic, extrinsic etc) get the mappings **;
    /*%let Selection = 5333-INTRIN-FACTOR-PK-STUD-REP#5334-EXTRIN-FACTOR-PK-STUD-REP;
    %let SelectionType = Intrinsic#Extrinsic;
    %let MacroVar = intrin_list#extrin_list;*/
    %let Selection = DATASETS;
    %let SelectionType = Unknown;
    %let MacroVar = unknown_list;
    %let NumSelections = %sysfunc(countw(&Selection., #));
    
    %do i = 1 %to &NumSelections.;
    
        %** Get the name of the study **;
        %SmExtractStudyNames(
            Input = &work.files,
            InputSel = %scan(&Selection., &i., #),
            MacroVarName = %scan(&MacroVar., &i., #)
        );

        %** Debug **;
        %put Study List: %superq(%scan(&MacroVar., &i., #));

        %** Process each of the study level datasets **;
        %let NumStudies = %sysfunc(countw(%superq(%scan(&MacroVar., &i., #)),#));
        %do j = 1 %to &NumStudies.;     
            
            %put Study: %scan(%superq(%scan(&MacroVar., &i., #)), &j., #);
            %let CurrentStudy = %scan(%superq(%scan(&MacroVar., &i., #)), &j., #);
            
            %** This flag only determines that at least one study was processed. it doesnt guarantee that any study actually contains valid files **;
            %let MappingStatus = SUCCESS;           
            %Log(
                Progress = %sysfunc(putn((&i.+((&j.*2-1)/(&NumStudies.*2))-1)*100/&NumSelections., 4.0)),
                TextFeedback = Determining file structure and study design for study &CurrentStudy.
            );
            
            %*********************************;
            %** Clean up                    **;
            %*********************************;
            %symdel DmVarNameList UsubjidVar SequenceVar AgeVar SexVar RaceVar EthnicVar CountryVar
                                  UsubdjidVarQual SequenceVarQual AgeVarQual SexVarQual RaceVarQual EthnicVarQual CountryVarQual
                    PcVarNameList PeriodPcVar AnalytePcVar ResultPcVar TimeVar
                                  PeriodPcVarQual AnalytePcVarQual ResultPcVarQual TimeVarQual
                    PpVarNameList PeriodPpVar AnalytePpVar ResultPpVar ParameterVar
                                  PeriodPpVarQual AnalytePpVarQual ResultPpVarQual ParameterVarQual
                    ExVarNameList ExTrtVar ExDateVar ExPeriodVar
                                  ExTrtVarQual ExDateVarQual ExPeriodVarQual
                    StudyDesign Reference InputDm InputEx InputPc InputPp / nowarn;
    
            %*********************************;
            %** Identify the input datasets **;
            %*********************************;
            %SmIdentifySdtmData(
                DataSetPath = &DataSetPath.,
                StudyId = %scan(%superq(%scan(&MacroVar., &i., #)), &j., #)
            );

            *Check if DM PC PP file exist;
            %let MissingDmPcPp=0;
            %if %upcase(&ProgressGo.) = SUCCESS %then %do;
                %if %SYSFUNC(FileEXIST(&inputdm.)) =0 or %SYSFUNC(FileEXIST(&inputPc.))=0 or %SYSFUNC(FileEXIST(&inputPp.))=0
                    %then %let MissingDmPcPp=1;
                %put MissingDmPcPp=&MissingDmPcPP.;
                %put current study=&currentstudy.;
            
                %if &MissingDmPcPp. = 1 %then %do;
                    data &work.errorstudy_&i._&j.;
                        length study_id $64.;
                        study_id ="&currentstudy."; 
                        error_code =1;
                        output;
                    run;                
                %end;
            %end;

            %if %upcase(&ProgressGo.) = SUCCESS and &MissingDmPcPp.=0 %then %do;
                 /*%let PeriodEXVar= ;
                 %let ExTrtVar= ;
                 %let ExDateVar= ;*/
                %** Changed the mapping status **;

                %*********************************************;
                %**             Map Demographic             **;
                %*********************************************;
                
                %** Read the data **;
                %SmReadAndMergeDataset(
                    Input1 = &InputDm.,
                    Output = &work.dm
                );

                %** Get the variables **;
                %SmGetColumnNames(
                    Input = &work.dm,
                    Output = &work.dm_cols,
                    MacroVarName = DmVarNameList,
                    MacroVarLabel = DmVarLableList
                );
                
                %** Save the unmodified column list to return it to the interface **;
                data &work.dm_cols_orig;
                    set &work.dm_cols;
                run;

                %** Try and map **;
                %SmMapDmPcPp(
                    Input = &work.dm_cols,
                    Type = dm
                );
                
                %*********************************************;
                %**     Map Plasma Concentration            **;
                %*********************************************;

                %** Read the data **;
                %SmReadAndMergeDataset(
                    Input1 = &InputPc.,
                    UsubjidVar = &UsubjidVar.,
                    Output = &work.pc
                );

                %** Get the variables **;
                %SmGetColumnNames(
                    Input = &work.pc,
                    Output = &work.pc_cols,
                    MacroVarName = PcVarNameList,
                    MacroVarLabel = PcVarLableList
                );

                %** Save the unmodified column list to return it to the interface **;
                data &work.pc_cols_orig;
                    set &work.pc_cols;
                run;
                
                %** Try and map **;
                %SmMapDmPcPp(
                    Input = &work.pc_cols,
                    Type = pc
                );

                %*********************************************;
                %**     Map Pharmacokinetic parameters      **;
                %*********************************************;

                %** Read the data **;
                %SmReadAndMergeDataset(
                    Input1 = &InputPp.,
                    UsubjidVar = &UsubjidVar.,
                    Output = &work.pp
                );

                %** Get the variables **;
                %SmGetColumnNames(
                    Input = &work.pp,
                    Output = &work.pp_cols,
                    MacroVarName = PpVarNameList,
                    MacroVarLabel = PpVarLableList
                );
                
                %** Save the unmodified column list to return it to the interface **;
                data &work.pp_cols_orig;
                    set &work.pp_cols;
                run;

                %** Try and map **;
                %SmMapDmPcPp(
                    Input = &work.pp_cols,
                    Type = pp
                );

                %CheckPeriodinPP(UsubjidVar = &UsubjidVar.);
                %global Studydesignx ;
                %let Studydesignx =  ;
                %if %sysfunc(fileexist(&INPUTEX.))=0 %then %do;
                %let PeriodEXVar = Visit;
                %let Studydesignx =  ;
              
                %end;
    
                %*********************************************;
                %**             Map Exposure                **;
                %*********************************************;
                %** Read the data **;

                %if %sysfunc(fileexist(&InputEx.)) %then %do;   
                    %SmReadAndMergeDataset(
                        Input1 = &InputEx.,
                        UsubjidVar = &UsubjidVar.,
                        Output = &work.ex
                    );

                    %** Get the variables **;
                    %SmGetColumnNames(
                        Input = &work.ex,
                        Output = &work.ex_cols,
                        MacroVarName = ExVarNameList,
                        MacroVarLabel = ExVarLableList
                    );
                
                    %** Save the unmodified column list to return it to the interface **;
                    data &work.ex_cols_orig;
                        set &work.ex_cols;
                    run;

                    %** Try and map **;
                    %SmMapDmPcPp(
                        Input = &work.ex_cols,
                        Type = ex
                    );
                %end;

                %************************************************;
                %**     Arms                                   **;
                %************************************************;
                %if &SequenceVar. ne %then %do;
                    data &work.arms_&i._&j.;
                        set &work.dm(keep=arm);
                        Study_Code = "%scan(%superq(%scan(&MacroVar., &i., #)), &j., #)";
                    run;
                    Proc sort data=&work.arms_&i._&j. nodupkey;
                        by arm;
                    run;
                %end;
                
                %************************************************;
                %**     PPVISIT                                **;
                %************************************************;
                %if &PeriodPpVarQual. < 2 %then %do;
                    data &work.ppvisit_&i._&j.(keep=Study_Code Visit);
                        set &work.pp(keep=&PeriodPpVar.);
                        Study_Code = "%scan(%superq(%scan(&MacroVar., &i., #)), &j., #)";
                        %if %upcase(&PeriodPpVar.) ne VISIT %then %do;
                            visit = put(&PeriodPpVar., 3.);
                        %end;
                    run;
                    Proc sort data=&work.ppvisit_&i._&j. nodupkey;
                    by visit;
                    run;                
                %end;
                
                %************************************************;
                %**     PCVISIT                                **;
                %************************************************;
                %if &PeriodPcVarQual. < 2 %then %do;
                    data &work.pcvisit_&i._&j.(keep=Study_Code Visit);
                        set &work.pc(keep=&PeriodPcVar.);
                        Study_Code = "%scan(%superq(%scan(&MacroVar., &i., #)), &j., #)";
                        %if %upcase(&PeriodPcVar.) ne VISIT %then %do;
                            visit = put(&PeriodPcVar., 3.);                     
                        %end;
                    run;
                    Proc sort data=&work.pcvisit_&i._&j. nodupkey;
                    by visit;
                    run;                
                %end;
                
                %************************************************;
                %**     Mappings                               **;
                %************************************************;
                data &work.currentMapping_&i._&j. NOLIST;
                    length  Study_Code $64. Source Path $200. 
                            File_Variable SDTM_Variable $32.;

                    %** Generel stuff **;
                    Study_Code = "%scan(%superq(%scan(&MacroVar., &i., #)), &j., #)";
                    
                    %** Demographic **;
                    Source = "DM";
                    Path = substr("&InputDm.", find("&InputFolder.","\", - length("&InputFolder.")));

                    File_Variable = "&UsubjidVar.";
                    SDTM_Variable = "USUBJID";
                    Mapping_Quality = &UsubjidVarQual.;
                    output;

                    File_Variable = "&SequenceVar.";
                    SDTM_Variable = "ARM";
                    Mapping_Quality = &SequenceVarQual.;
                    output;

                    File_Variable = "&AgeVar.";
                    SDTM_Variable = "AGE";
                    Mapping_Quality = &AgeVarQual.;
                    output;

                    File_Variable = "&SexVar.";
                    SDTM_Variable = "SEX";
                    Mapping_Quality = &SexVarQual.;
                    output;

                    File_Variable = "&RaceVar.";
                    SDTM_Variable = "RACE";
                    Mapping_Quality = &RaceVarQual.;
                    output;

                    File_Variable = "&CountryVar.";
                    SDTM_Variable = "COUNTRY";
                    Mapping_Quality = &CountryVarQual.;
                    output;

                    File_Variable = "&EthnicVar.";
                    SDTM_Variable = "ETHNIC";
                    Mapping_Quality = &EthnicVarQual.;
                    output;

                    %** Exposure **;
                    %if %sysfunc(fileexist(&INPUTEX.)) ne 0 %then %do;
                            Source = "EX";
                            Path = substr("&InputEx.", find("&InputFolder.","\", - length("&InputFolder.")));

                            File_Variable = "&ExTrtVar.";
                            SDTM_Variable = "EXTRT";
                            Mapping_Quality = &ExTrtVarQual.;
                            output;

                            File_Variable = "&ExDateVar.";
                            SDTM_Variable = "EXSTDTC";
                            Mapping_Quality = &ExDateVarQual.;
                            output;
                            
                            File_Variable = "&PeriodExVar.";
                            SDTM_Variable = "VISIT";
                            Mapping_Quality = &PeriodExVarQual.;
                            output;
                    %end;

                    %** Plasma concentration **; 
                    Source = "PC";
                    Path = substr("&InputPc.", find("&InputFolder.","\", - length("&InputFolder.")));

                    File_Variable = "&PeriodPcVar.";
                    SDTM_Variable = "VISIT";
                    Mapping_Quality = &PeriodPcVarQual.;
                    output;
                    
                    File_Variable = "&AnalytePcVar.";
                    SDTM_Variable = "PCTEST";
                    Mapping_Quality = &AnalytePcVarQual.;
                    output;
                    
                    File_Variable = "&ResultPcVar.";
                    SDTM_Variable = "PCSTRESN";
                    Mapping_Quality = &ResultPcVarQual.;
                    output;
            
                    File_Variable = "&TimeVar.";
                    SDTM_Variable = "PCTPTNUM";
                    Mapping_Quality = &TimeVarQual.;
                    output;

                    %** Pharmacokinetic parameters **;
                    Source = "PP";
                    Path = substr("&InputPp.", find("&InputFolder.","\", - length("&InputFolder.")));

                    File_Variable = "&PeriodPpVar.";
                    SDTM_Variable = "VISIT";
                    Mapping_Quality = &PeriodPpVarQual.;
                    output;

                    File_Variable = "&AnalytePpVar.";
                    SDTM_Variable = "PPCAT";
                    Mapping_Quality = &AnalytePpVarQual.;
                    output;

                    File_Variable = "&ResultPpVar.";
                    SDTM_Variable = "PPSTRESN";
                    Mapping_Quality = &ResultPpVarQual.;
                    output;

                    File_Variable = "&ParameterVar.";
                    SDTM_Variable = "PPTESTCD";
                    Mapping_Quality = &ParameterVarQual.;
                    output;
                    
                    /* Add Suppdm and SC, we are not interested in mapping them, so we just pass empty mapping with quality -1 */
                    %if %sysfunc(fileexist(&InputSuppdm.)) ne 0 %then %do;
                        Source = "SUPPDM";
                        Path = substr("&InputSuppdm.", find("&InputFolder.","\", - length("&InputFolder.")));
                        File_Variable = "";
                        SDTM_Variable = "";
                        Mapping_Quality = -1;
                        output;
                    %end;
                    
                    %if %sysfunc(fileexist(&InputSc)) ne 0 %then %do;
                        Source = "SC";
                        Path = substr("&InputSc.", find("&InputFolder.","\", - length("&InputFolder.")));
                        File_Variable = "";
                        SDTM_Variable = "";
                        Mapping_Quality = -1;
                        output;
                    %end;
                run;

                %************************************************;
                %**     Prepare data for the frontend          **;
                %************************************************;

                %** Study **;
                data &work.iPortal_Study_&i._&j. nolist;
                    length study_code $64.;
                    Study_Code = "%scan(%superq(%scan(&MacroVar., &i., #)), &j., #)";
                    Study_Type = 0;/*FIXME*/
                    
                    /*%if %upcase(&StudyDesign.) = UNKNOWN %then %do; 
                        Study_Design = 1;
                    %end;
                    %else %if %upcase(&StudyDesign.) = SEQUENTIAL %then %do; 
                        Study_Design = 2;
                    %end;
                    %else %if %upcase(&StudyDesign.) = PARALLEL %then %do; 
                        Study_Design = 3;
                    %end;
                    %else %if %upcase(&StudyDesign.) = CROSSOVER %then %do; 
                        Study_Design = 4;
                    %end;*/
                    
                    output;
                run;
                                
                %Log(
                    Progress = %sysfunc(putn((&i.+(&j./&NumStudies.)-1)*100/&NumSelections., 4.0)),
                    TextFeedback = Study %scan(%superq(%scan(&MacroVar., &i., #)), &j., #) completed
                );
            
                %** Combine **;
                data &work.data_content_&i._&j. NOLIST;
                    length STUDY $64.;
                    set &work.dm_cols_orig (in = a)
                          %if %sysfunc(fileexist(&INPUTEX)) ne 0 %then %do; 
                        &work.ex_cols_orig (in = b)
                          %end;
                        &work.pc_cols_orig (in = c)
                        &work.pp_cols_orig (in = d);

                    STUDY = "%scan(%superq(%scan(&MacroVar., &i., #)), &j., #)";

                    if a then do;
                        SOURCE = "DM";
                    end;
                      %if %sysfunc(fileexist(&INPUTEX.)) ne 0 %then %do;    
                    else if b then do;
                        SOURCE = "EX";
                    end;
                      %end;
                    else if c then do;
                        SOURCE = "PC";
                    end;
                    else if d then do;
                        SOURCE = "PP";
                    end;

                    rename colname = variable collabel = variabledescription;
                run;
                                                
            %end;
        %end;
                
    %end;

    %** Only output if the code succeeded **;
    %if &MappingStatus. = SUCCESS %then %do;

        %** Create output datasets **;
        data &work.data NOLIST;
            length dataset $32.;
            dataset="out"; output;
            dataset="mapping"; output;
            dataset="arms"; output;
            dataset="ppvisit"; output;
            dataset="pcvisit"; output;
            dataset="design"; output;
            dataset="errorstudy"; output;
        run;
		%if %sysfunc(exist(&work.out)) %then %do;
			proc export data=&work.out
		outfile="\\&SYSHOSTNAME.\Output Files\PkView\Peter\out.csv"
		dbms=dlm replace;
		delimiter=',';
		run; 
	%end;

	%if %sysfunc(exist(&work.mapping)) %then %do;
			proc export data=&work.mapping
		outfile="\\&SYSHOSTNAME.\Output Files\PkView\Peter\mapping.csv"
		dbms=dlm replace;
		delimiter=',';
		run; 
	%end;

		%if %sysfunc(exist(&work.arms)) %then %do;
		proc export data=&work.arms
		outfile="\\&SYSHOSTNAME.\Output Files\PkView\Peter\arms.csv"
		dbms=dlm replace;
		delimiter=',';
		run; 
	%end;
	%if %sysfunc(exist(&work.ppvisit)) %then %do;
			proc export data=&work.ppvisit
		outfile="\\&SYSHOSTNAME.\Output Files\PkView\Peter\ppvisit.csv"
		dbms=dlm replace;
		delimiter=',';
		run; 
	%end;
	%if %sysfunc(exist(&work.pcvisit)) %then %do;
			proc export data=&work.pcvisit
		outfile="\\&SYSHOSTNAME.\Output Files\PkView\Peter\pcvisit.csv"
		dbms=dlm replace;
		delimiter=',';
		run; 
	%end;
	%if %sysfunc(exist(&work.design)) %then %do;
			proc export data=&work.design
		outfile="\\&SYSHOSTNAME.\Output Files\PkView\Peter\design.csv"
		dbms=dlm replace;
		delimiter=',';
		run; 
	%end;
	%if %sysfunc(exist(&work.errorstudy)) %then %do;
			proc export data=&work.errorstudy
		outfile="\\&SYSHOSTNAME.\Output Files\PkView\Peter\errorstudy.csv"
		dbms=dlm replace;
		delimiter=',';
		run; 
	%end;

        
        data &work.dummy_out;
            length study $64. Source $8. variable variabledescription $2000.;
            stop;
        run;
        data &work.out NOLIST;
            set &work.dummy_out
                %do i = 1 %to %sysfunc(countw(&Selection., #));
                    %do j = 1 %to %sysfunc(countw(%superq(%scan(&MacroVar., &i., #)),#));
                        %if %sysfunc(exist(&work.data_content_&i._&j.)) %then %do;
                            &work.data_content_&i._&j.
                        %end;
                    %end;
                %end;
            ;
        run;
        
        data &work.dummy_arms;
            length  Study_Code $64. Arm $2000.;
            stop;
        run;
        data &work.arms NOLIST;
            set &work.dummy_arms
                %do i = 1 %to %sysfunc(countw(&Selection., #));
                    %do j = 1 %to %sysfunc(countw(%superq(%scan(&MacroVar., &i., #)),#));
                        %if %sysfunc(exist(&work.arms_&i._&j.)) %then %do;
                            &work.arms_&i._&j.
                        %end;
                    %end;
                %end;
            ;
        run;
        
        data &work.dummy_ppvisit;
            length  Study_Code Visit $64.;
            stop;
        run;
        data &work.ppvisit NOLIST;
            set &work.dummy_ppvisit
                %do i = 1 %to %sysfunc(countw(&Selection., #));
                    %do j = 1 %to %sysfunc(countw(%superq(%scan(&MacroVar., &i., #)),#));
                        %if %sysfunc(exist(&work.ppvisit_&i._&j)) %then %do;
                            &work.ppvisit_&i._&j
                        %end;
                    %end;
                %end;
            ;
        run;
        
        data &work.dummy_pcvisit;
            length  Study_Code Visit $64.;
            stop;
        run;
        data &work.pcvisit NOLIST;
            set &work.dummy_pcvisit
                %do i = 1 %to %sysfunc(countw(&Selection., #));
                    %do j = 1 %to %sysfunc(countw(%superq(%scan(&MacroVar., &i., #)),#));
                        %if %sysfunc(exist(&work.pcvisit_&i._&j.)) %then %do;
                            &work.pcvisit_&i._&j.
                        %end;
                    %end;
                %end;
            ;
        run;
         
        data &work.dummy_mapping;
            length  Study_Code $64. Source $8. Path $200. 
                File_Variable SDTM_Variable $32. Mapping_Quality 3;
            stop;
        run;
        data &work.mapping NOLIST;
            set &work.dummy_mapping
                %do i = 1 %to %sysfunc(countw(&Selection., #));
                    %do j = 1 %to %sysfunc(countw(%superq(%scan(&MacroVar., &i., #)),#));
                        %if %sysfunc(exist(&work.currentMapping_&i._&j.)) %then %do;
                            &work.currentMapping_&i._&j.
                        %end;
                    %end;
                %end;
            ;
        run;

        data &work.dummy_design;
            length study_code $64. Study_Type 3;
            stop;
        run;
        data &work.design NOLIST;
            set &work.dummy_design
                %do i = 1 %to %sysfunc(countw(&Selection., #));
                    %do j = 1 %to %sysfunc(countw(%superq(%scan(&MacroVar., &i., #)),#));
                        %if %sysfunc(exist(&work.iPortal_Study_&i._&j.)) %then %do;
                            &work.iPortal_Study_&i._&j.
                        %end;
                    %end;
                %end;
            ;
        run;
        
        data &work.dummy_errorstudy;
            length study_id $64. error_code 3;
            stop;
        run;
        data &work.errorstudy NOLIST;
            set &work.dummy_errorstudy
                %do i = 1 %to %sysfunc(countw(&Selection., #));
                    %do j = 1 %to %sysfunc(countw(%superq(%scan(&MacroVar., &i., #)),#));
                        %if %sysfunc(exist(&work.errorstudy_&i._&j.)) %then %do;
                            &work.errorstudy_&i._&j.
                        %end;
                    %end;
                %end;
            ;
        run;
        
    %end;
    
%mend PkViewGetMapping;
