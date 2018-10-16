%*****************************************************************************************;
%**                                                                                     **;
%** Map the values of the specified variable in the input according to a mapping table  **;
%**                                                                                     **;
%**  Parameters:                                                                        **;
%**  - Input: input dataset                                                             **;
%**  - VariableName: the variable that will be mapped                                   **;
%**  - MappingTable: a table of variable mappings with 2 columns, &MapNew. and &MapOld. **;
%**  - Output: output dataset, can be the same as input                                 **;
%**                                                                                     **;
%** Created by Eduard Porta (2016-05-11)                                                **;
%**                                                                                     **;
%*****************************************************************************************;

%macro MapValues(
    Input = ,
    VariableName =,
    MappingTable =,
    MapOld =,
    MapNew =,
    Output = 
);

    /* Save original file sorting */
    data &Output.;
        set &Input.;
        originalSorting = _n_;
    run;

	/* Obtain the data type of the variable in the input file (C or N)*/
	%let dsid=%sysfunc(open(&Output.));
	%let type=%sysfunc(vartype(&dsid., %sysfunc(varnum(&dsid., &VariableName.))));
    %let oldLength=%sysfunc(varlen(&dsid., %sysfunc(varnum(&dsid., &VariableName.))));
	%let res=%sysfunc(close(&dsid.));

	/* Copy the mapping table */
	data mappingTable;
		set &MappingTable.;
	run;

	/* If the variable is numeric, convert the 'Old" column of the mapping table to numeric *
	%if ("&type."="N") %then %do;
		data mappingTable(drop=&MapOld.C &MapNew.C);
			set mappingTable(rename=(&MapOld.=&MapOld.C &MapNew.=&MapNew.C));
			&MapOld. = input(&MapOld.C, 8.);	
            &MapNew. = input(&MapNew.C, 8.);	
		run;
	%end;*/	
    
    /* Replace variable with mapping table */
    proc sort data = &Output; by &VariableName.; run;
    proc sort data = mappingTable; by &MapOld.; run;
    data &Output(rename=(&MapNew.=&VariableName.));
        merge mappingTable(rename=(&MapOld.=&VariableName._old))
              &Output.(rename=(&VariableName.=&VariableName._old) in=hasData);
        by &VariableName._old;
        if hasData;
    run;

    
    /* Restore original file sorting */
    proc sort data = &Output. out = &Output.(drop=originalSorting);
        by originalSorting;
    run;

%mend MapValues;
