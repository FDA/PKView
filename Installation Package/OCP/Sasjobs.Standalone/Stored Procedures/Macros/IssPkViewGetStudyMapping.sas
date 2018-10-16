%*****************************************************************************************;
%**                                                                                     **;
%** Get the ISS Mappings of a single study                                              **;
%**                                                                                     **;
%** Created by:                                                                         **;
%**     Yue Zhou (2017)                                                                 **;
%**       based on work by                                                              **;
%**     Jens Stampe Soerensen  (2013/2014)                                              **;
%**     Eduard Porta Martin Moreno (2015)                                               **;
%*****************************************************************************************;

%macro IssPkViewGetStudyMapping();

    %** Read the StudyFolder from the SAS web service **;
    %if %sysfunc(exist(websvc.sasdata)) %then %do;
        data _null_;
            set websvc.sasdata;
            call symputx("StudyFolder", StudyFolder);
        run;
    %end;
    
    %** Get the name of the study **;
    %let CurrentStudy = %sysfunc(strip(%sysfunc(upcase(%sysfunc(scan(&StudyFolder., -1, ".\"))))));
    %put Study: &CurrentStudy;
    


    %** Debug **;
    %put StudyFolder = &StudyFolder.;

    %** List the files in the input folder **;
    %SmListFilesInFolder(
        Path = &StudyFolder.,
        Out = &work.files
    );                                 
                    
 
    %*********************************;
    %** Identify the input datasets **;
    %*********************************;
    %IssIdentifyStudyData(
        StudyDir = &StudyFolder.
    );

    *Check if ADVS file exists;
	%let MissingVs=0;
    %if %upcase(&ProgressGo.) = SUCCESS %then %do;
        %if %SYSFUNC(FileEXIST(&inputVs.)) =0   
            %then %let MissingVs=1;
        %put MissingVs=&MissingVs.;
        %put current study=&currentstudy.;
 	%end;


    *Check if ADAE ADSl files exist;
    %let MissingAeSl=0;
    %if %upcase(&ProgressGo.) = SUCCESS %then %do;
        %if %SYSFUNC(FileEXIST(&inputAe.)) =0 or %SYSFUNC(FileEXIST(&inputSl.))=0 
            %then %let MissingAeSl=1;
        %put MissingAeSl=&MissingAeSl.;
        %put current study=&currentstudy.;
    
        %if &MissingAeSl. = 1 %then %do;
            data &work.errorstudy_raw;
                length study_id $64.;
                study_id ="&currentstudy."; 
                error_code =1;
                output;
            run;                
        %end;



    %end;
    *If ADAE ADSl files exist, then run the progress;

    %if %upcase(&ProgressGo.) = SUCCESS and &MissingAeSl.=0 %then %do;
                
        %*********************************************;
        %**             Map Demographic             **;
        %*********************************************;
        
        %** Read the data **;
        %SmReadAndMergeDataset(
            Input1 = &InputAe.,
            Output = &work.Ae
        );  



        %** Get the variables **;
        %SmGetColumnNames(
            Input = &work.Ae,
            Output = &work.Ae_cols,
            MacroVarName = AeVarNameList,
            MacroVarLabel = AeVarLableList
        );
        
        %** Save the unmodified column list to return it to the interface **;
        data &work.Ae_cols_orig;
            set &work.Ae_cols;
        run;

        %** Try and map **;
        %IssMapAeSlVs(
            Input = &work.Ae_cols,
            Type = Ae
        );


                    

        %** Read the data **;
        %SmReadAndMergeDataset(
            Input1 = &InputSl.,
            UsubjidVar = &UsubjidVar.,
            Output = &work.Sl
        );

        %** Get the variables **;
        %SmGetColumnNames(
            Input = &work.Sl,
            Output = &work.Sl_cols,
            MacroVarName = SlVarNameList,
            MacroVarLabel = SlVarLableList
        );

        %** Save the unmodified column list to return it to the interface **;
        data &work.Sl_cols_orig;
            set &work.Sl_cols;
        run;


        %** Try and map **;
        %IssMapAeSlVs(
            Input = &work.Sl_cols,
            Type = Sl
        );

        
        
        %********************************;
		%* Mapping when ADVS file exists*;
        %********************************;

		%if %SYSFUNC(FileEXIST(&inputVs.))=1    %then %do;

        %** Read the data **;
        %SmReadAndMergeDataset(
            Input1 = &InputVs.,
            UsubjidVar = &UsubjidVar.,
            Output = &work.Vs
        );

        %** Get the variables **;
        %SmGetColumnNames(
            Input = &work.Vs,
            Output = &work.Vs_cols,
            MacroVarName = VsVarNameList,
            MacroVarLabel = VsVarLableList
        );
        
        %** Save the unmodified column list to return it to the interface **;
        data &work.Vs_cols_orig;
            set &work.Vs_cols;
        run;

        %** Try and map **;
        %IssMapAeSlVs(
            Input = &work.Vs_cols,
            Type = Vs
        );


            
        %************************************************;
        %**     Mappings                               **;
        %************************************************;

		data &work.currentMapping_raw NOLIST;
            length  Study_Code $64. Source Path $200. 
                    File_Variable ISS_Variable $32.;

            %** Generel stuff **;
            Study_Code = "&CurrentStudy";
            
            %** Demographic **;
            Source = "ADAE";
            Path = substr("&InputAe.", length("&InputFolder.") + 1);

            File_Variable = "&UsubjidVar.";
            ISS_Variable = "USUBJID";
            Mapping_Quality = &UsubjidVarQual.;
            output;

            File_Variable = "&TRTPVar.";
            ISS_Variable = "TRTA";
            Mapping_Quality = &TRTPVarQual.;
            output;


            File_Variable = "&AEBODSYSVar.";
            ISS_Variable = "AEBODSYS";
            Mapping_Quality = &AEBODSYSVarQual.;
            output;

            File_Variable = "&ASTDYVar.";
            ISS_Variable = "ASTDY";
            Mapping_Quality = &ASTDYVarQual.;
            output; 



            File_Variable = "&AESEVVar.";
            ISS_Variable = "AESEV";
            Mapping_Quality = &AESEVVarQual.;
            output;

            File_Variable = "&STUDYIDVar.";
            ISS_Variable = "STUDYID";
            Mapping_Quality = &STUDYIDVarQual.;
            output; 



            File_Variable = "&AEDECODVar.";
            ISS_Variable = "AEDECOD";
            Mapping_Quality = &AEDECODVarQual.;
            output;

            File_Variable = "&AESERVar.";
            ISS_Variable = "AESER";
            Mapping_Quality = &AESERVarQual.;
            output; 

            File_Variable = "&AESTDYVar.";
            ISS_Variable = "AESTDY";
            Mapping_Quality = &AESTDYVarQual.;
            output;

            File_Variable = "&ASEVVar.";
            ISS_Variable = "ASEV";
            Mapping_Quality = &ASEVVarQual.;
            output; 

            File_Variable = "&ASTDTVar.";
            ISS_Variable = "ASTDT";
            Mapping_Quality = &ASTDTVarQual.;
            output;  
			File_Variable = "&APERIODVar.";
            ISS_Variable = "APERIOD";
            Mapping_Quality = &APERIODVarQual.;
            output; 


			/*ADSL*/
            Source = "ADSL";
            Path = substr("&InputSl.", length("&InputFolder.") + 1);

            File_Variable = "&ARMVar.";
            ISS_Variable = "ARM";
            Mapping_Quality = &ARMVarQual.;
            output;
            File_Variable = "&TRTSDTVar.";
            ISS_Variable = "TRTSDT";
            Mapping_Quality = &TRTSDTVarQual.;
            output;

            File_Variable = "&LSTVSTDTVar.";
            ISS_Variable = "LSTVSTDT";
            Mapping_Quality = &LSTVSTDTVarQual.;
            output;   

 			/*ADVS*/
            Source = "ADVS";
            Path = substr("&InputVs.", length("&InputFolder.") + 1);

            File_Variable = "&ADYVar.";
            ISS_Variable = "ADY";
            Mapping_Quality = &ADYVarQual.;
            output;
	
		run;

		%* Combine *;
		data &work.data_content_raw NOLIST;
            length STUDY $64.;
            set &work.Ae_cols_orig (in = a)
                &work.Sl_cols_orig (in = b)
				&work.Vs_cols_orig (in = c);
 

            STUDY = "&CurrentStudy";

            if a then do;
                SOURCE = "ADAE";
            end;
              
            else if b then do;
                SOURCE = "ADSL";
            end;

            else if c then do;
                SOURCE = "ADVS";
            end;

            rename colname = variable collabel = variabledescription;
        	run;

			DATA &work.TRTXXP_1;
			length Selection $10.;
			SET &work.Sl_cols_orig;
			WHERE colname  LIKE 'TRT__A';
			KEEP colname Selection;
			Selection="TRUE";
			RUN; 

			DATA &work.TRTXXP_2;
			length Selection $10.;
			SET &work.Sl_cols_orig ;
			KEEP colname Selection;
			Selection="FALSE";
			RUN; 
			PROC SORT DATA=&work.TRTXXP_1;
			BY colname Selection;
			RUN;
			PROC SORT DATA=&work.TRTXXP_2;
			BY colname Selection;
			RUN;

			DATA TRTXXP_RAW;
			length Selection $10.;
			merge &work.TRTXXP_2 &work.TRTXXP_1 ;
			by colname;
			RENAME colname=TRTXXP;
			RUN; 


	


		
	%end;
		%* Mapping when ADVS file does not exist*;
	 	%else %do;
         data &work.currentMapping_raw NOLIST;
            length  Study_Code $64. Source Path $200. 
                    File_Variable ISS_Variable $32.;

            %** Generel stuff **;
            Study_Code = "&CurrentStudy";
            
            %** Demographic **;
            Source = "ADAE";
            Path = substr("&InputAe.", length("&InputFolder.") + 1);

            File_Variable = "&UsubjidVar.";
            ISS_Variable = "USUBJID";
            Mapping_Quality = &UsubjidVarQual.;
            output;

            File_Variable = "&TRTPVar.";
            ISS_Variable = "TRTA";
            Mapping_Quality = &TRTPVarQual.;
            output;


            File_Variable = "&AEBODSYSVar.";
            ISS_Variable = "AEBODSYS";
            Mapping_Quality = &AEBODSYSVarQual.;
            output;

            File_Variable = "&ASTDYVar.";
            ISS_Variable = "ASTDY";
            Mapping_Quality = &ASTDYVarQual.;
            output; 



            File_Variable = "&AESEVVar.";
            ISS_Variable = "AESEV";
            Mapping_Quality = &AESEVVarQual.;
            output;

            File_Variable = "&STUDYIDVar.";
            ISS_Variable = "STUDYID";
            Mapping_Quality = &STUDYIDVarQual.;
            output; 



            File_Variable = "&AEDECODVar.";
            ISS_Variable = "AEDECOD";
            Mapping_Quality = &AEDECODVarQual.;
            output;

            File_Variable = "&AESERVar.";
            ISS_Variable = "AESER";
            Mapping_Quality = &AESERVarQual.;
            output; 

            File_Variable = "&AESTDYVar.";
            ISS_Variable = "AESTDY";
            Mapping_Quality = &AESTDYVarQual.;
            output;

            File_Variable = "&ASEVVar.";
            ISS_Variable = "ASEV";
            Mapping_Quality = &ASEVVarQual.;
            output; 

            File_Variable = "&ASTDTVar.";
            ISS_Variable = "ASTDT";
            Mapping_Quality = &ASTDTVarQual.;
            output; /*RUN;*/


			/*ADSL*/
            Source = "ADSL";
            Path = substr("&InputSl.", length("&InputFolder.") + 1);

            File_Variable = "&ARMVar.";
            ISS_Variable = "ARM";
            Mapping_Quality = &ARMVarQual.;
            output;
            File_Variable = "&TRTSDTVar.";
            ISS_Variable = "TRTSDT";
            Mapping_Quality = &TRTSDTVarQual.;
            output;
			File_Variable = "&LSTVSTDTVar.";
            ISS_Variable = "LSTVSTDT";
            Mapping_Quality = &LSTVSTDTVarQual.;
			output;
 
			run;

                
        %** Combine **;
 

 		data &work.data_content_raw NOLIST;
            length STUDY $64.;
            set &work.Ae_cols_orig (in = a)
                &work.Sl_cols_orig (in = b);
 

            STUDY = "&CurrentStudy";

            if a then do;
                SOURCE = "ADAE";
            end;
              
            else if b then do;
                SOURCE = "ADSL";
            end;
 

            rename colname = variable collabel = variabledescription;
        	run; 

			DATA &work.TRTXXP_1;
			length Selection $10.;
			SET &work.Sl_cols_orig;
			WHERE colname  LIKE 'TRT__A';
			KEEP colname Selection;
			Selection="TRUE";
			RUN; 

			DATA &work.TRTXXP_2;
			length Selection $10.;
			SET &work.Sl_cols_orig ;
			KEEP colname Selection;
			Selection="FALSE";
			RUN; 
			PROC SORT DATA=&work.TRTXXP_1;
			BY colname Selection;
			RUN;
			PROC SORT DATA=&work.TRTXXP_2;
			BY colname Selection;
			RUN;

			DATA TRTXXP_RAW;
			length Selection $10.;
			merge &work.TRTXXP_2 &work.TRTXXP_1 ;
			by colname;
			RENAME colname=TRTXXP;
			RUN; 



		%end;




    %** Create output datasets **;
    data &work.data NOLIST;
        length dataset $32.;
        dataset="IssVariables"; output;
        dataset="IssMappingSAS"; output;
		dataset="TRTXXP"; output;

 	run;
        
    data &work.dummy_out;
        length study $64. source $8. variable variabledescription $2000.;
        stop;
    run;
    data &work.IssVariables NOLIST;
        set &work.dummy_out
            %if %sysfunc(exist(&work.data_content_raw)) %then %do;
                &work.data_content_raw
            %end;
        ;
    run;
    


     
    data &work.dummy_mapping;
        length  Study_Code $64. Source $8. Path $200. 
            File_Variable ISS_Variable $32. Mapping_Quality 3;
        stop;
    run;
    data &work.IssMappingSAS NOLIST;
        set &work.dummy_mapping
            %if %sysfunc(exist(&work.currentMapping_raw)) %then %do;
                &work.currentMapping_raw                    
            %end;
        ;
    run;

	data &work.dummy_TRTXXP;
        length Selection TRTXXP $32.;
        stop;
    run;
    data &work.TRTXXP NOLIST;
        set &work.dummy_TRTXXP
            %if %sysfunc(exist(&work.TRTXXP_RAW)) %then %do;
                &work.TRTXXP_RAW                    
            %end;
        ;
    run;

	proc sort data=&work.TRTXXP;by descending selection;run;


 %end; 

%*************
%**   Debug output
%*************

%**%let inputfolder=\\&SYSHOSTNAME.\clinical\;

%if %sysfunc(exist(&work.IssVariables)) %then %do;
				proc export data=&work.IssVariables
		outfile="\\&SYSHOSTNAME.\Output Files\PkView\Peter\IssVariables.csv"
		dbms=dlm replace;
		delimiter=',';
		run; 
	%end;

	%if %sysfunc(exist(&work.IssMappingSAS)) %then %do;
				proc export data=&work.IssMappingSAS
		outfile="\\&SYSHOSTNAME.\Output Files\PkView\Peter\IssMappingSAS.csv"
		dbms=dlm replace;
		delimiter=',';
		run; 
	%end;

		%if %sysfunc(exist(&work.TRTXXP)) %then %do;
				proc export data=&work.TRTXXP
		outfile="\\&SYSHOSTNAME.\Output Files\PkView\Peter\TRTXXP.csv"
		dbms=dlm replace;
		delimiter=',';
		run; 
	%end;






/*%**************/

 
%mend IssPkViewGetStudyMapping;
