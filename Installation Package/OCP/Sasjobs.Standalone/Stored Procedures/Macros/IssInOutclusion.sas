%*****************************************************************************************;
%**                                                                                     **;
%** Get the list of variables in ADAE and ADSL                                          **;
%**                                                                                     **;
%** Created by:                                                                         **;
%**     Yue Zhou (2017)                                                                 **;
%**       based on work by                                                              **;
%**     Jens Stampe Soerensen  (2013/2014)                                              **;
%**     Eduard Porta Martin Moreno (2015)                                               **;
%*****************************************************************************************;

%macro IssInOutclusion();

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
    *If ADAe ADSl files exist, then run the progress;

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

        

            
        %************************************************;
        %**     Mappings                               **;
        %************************************************;

		
		 	data &work.IssInOutclusion_raw NOLIST;
            length   Domain  $8.;
            set &work.Ae_cols_orig (in = a)
                &work.Sl_cols_orig (in = b);
 


            if a then do;
                Domain = "ADAE";
            end;
              
            else if b then do;
                Domain = "ADSL";
            end;
 

            rename colname = variable;
			drop collabel;
        	run; 

	%end;




    %** Create output datasets **;
    data &work.data NOLIST;
        length dataset $32.;
        dataset="IssInOutclusion"; output;
 	run;
        

     
    data &work.dummy_IssInOutclusion;
        length  Domain $8. ;
        stop;
    run;
    data &work.IssInOutclusion NOLIST;
        set &work.dummy_IssInOutclusion
            %if %sysfunc(exist(&work.IssInOutclusion_raw)) %then %do;
                &work.IssInOutclusion_raw                    
            %end;
        ;
    run;

%*************
%**   Debug output
%*************

%**%let inputfolder=\\&SYSHOSTNAME.\clinical\;

%if %sysfunc(exist(&work.IssInOutclusion)) %then %do;
				proc export data=&work.IssInOutclusion
		outfile="\\&SYSHOSTNAME.\Output Files\PkView\Peter\IssInOutclusion.csv"
		dbms=dlm replace;
		delimiter=',';
		run; 
	%end;


/*%**************/

%mend;
