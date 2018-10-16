
/**************************************************************** 
  This macro will load the specified dataset
  
  Input parameters:
  -filename: Path to the xpt file to load 
    
  Output macro variables:
  -outputName: the name for the loaded dataset
******************************************************************/
%macro LoadDataSet(filename=, outputName=output);

   %if %index(%upcase(%quote(&filename.)), .XPT) %then %do;

      %** Define libname **;
      libname input1 xport %quote(&filename.) access = readonly; 

      %let expectedDsName = %scan(%scan(%quote(%quote(&filename.)), -1, "/\"), 1, .);
      %SmDetermineDataSetName(
         libname=input1, 
         expectedName="&expectedDsName.", 
         outputVar=datasetName);   

      %** Output **;
      data &outputName.;
         set input1.&datasetName.;           
      run;
        
   %end;
   %else %do;
      %put ERROR: Dataset is not an XPT file;
   %end;

   %** Clean-up **;
   libname input1 clear;

%mend;

/**************************************************************** 
  This macro will determine the real dataset name of the 
  dataset stored in an xpt file.
  
  Input parameters:
  -libname: the sas library name of the loaded xpt file
  -expectedName: the expected dataset name, this is used in case
    the xpt file contains multiple datasets.  
    
  Output macro variables:
  -inputDsName: the name of the dataset
******************************************************************/
%macro SmDetermineDatasetName(libname=, expectedName=, outputVar=datasetName);

   %global &outputVar.;
   %let &outputVar.=;

    /* Get the list of datasets in the library */
   proc contents data=&libname.._ALL_ memtype=data out=dsNames0(keep=memname) noprint;
   run;

   proc sort data=dsNames0 OUT=dsNames nodupkey;
     BY memname;
   run;

    /* If expected dataset name is found set inputDsName to it */
   data _null_;
      set dsNames;
      if index(trim(upcase(memname)), trim(upcase(&expectedName.))) ne 0 then do;
         call symputx("&outputVar.", memname);         
      end;
   run;
 
    /* If expected dataset name was not found return the first 
       dataset in the list, this will generally work as XPT files
       submitted by the sponsors should never contain more than one */
   %if &&&outputVar. eq %then %do;
      data _null_;
         set dsNames;
         by memname;
         if first.memname then do;
            call symputx("&outputVar.", memname);
         end;
      run;
   %end;

   /* cleanup */
   proc delete data=dsNames0 dsNames; run;
   
%mend;




