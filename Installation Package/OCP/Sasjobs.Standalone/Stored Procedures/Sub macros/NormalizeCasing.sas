%*****************************************************************************************;
%**                                                                                     **;
%** Normalize the casing of the selected variables to lower case with initial capital   **;
%**                                                                                     **;
%** Created by Eduard Porta (2016-05-11)                                                **;
%**                                                                                     **;
%*****************************************************************************************;


%macro NormalizeCasing(
			Input = ,
			SelectedVariables =,
			Output = 
);

%local i currentVariable;

data &Output;
    set &Input;
    %do i=1 %to %sysfunc(countw(&SelectedVariables));
       %let currentVariable = %scan(&SelectedVariables, &i);
       &currentVariable.=propcase(&currentVariable);
    %end;
run;

%mend NormalizeCasing;
