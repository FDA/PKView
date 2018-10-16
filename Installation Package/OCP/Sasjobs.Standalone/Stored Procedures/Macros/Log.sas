%**	Log progress to be reported to the User Interface                                   **;
%**																						**;
%**	Input:																				**;
%**		Progress	        -		integer value 0-100 expressing the percentage done	**;
%**		TextFeedback     	-		Feedback message                    				**;
%**																						**;
%**	Created by:																			**;
%**		Eduard Porta Martin Moreno  (2015)                                              **;
%**																						**;
%*****************************************************************************************;
%macro Log(
        Progress = ,
        TextFeedback = 
);
    data &work.log;
        feedback=":I:,&Progress.,""&TextFeedback."""; output;
    run;
    proc print data=&work.log noobs;run;
%mend;