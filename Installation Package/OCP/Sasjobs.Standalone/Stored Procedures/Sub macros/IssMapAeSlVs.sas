%*****************************************************************************************;
%** Mapping variables in ADAE, ADSL, ADVS												**;
%** Created by:                                                                         **;
%**     Yue Zhou (2017)                                                                 **;
%**       based on work by                                                              **;
%**     Jens Stampe Soerensen  (2013/2014)                                              **;
%**     Eduard Porta Martin Moreno (2015)                                               **;
%*****************************************************************************************;

%macro IssMapAeSlVs(
	Input = ,
	Type = 
);

%** Map the studies and add mapping quality **;
%** Define by: 0 = OKAY, 1 - non-standard(OPTIONAL), 2 - Could not be mapped(MISSING) **;

%** Handle Demographics **;
%if %upcase(&type.) = AE %then %do;
	data _null_;
		set &Input. end = eof;
		length UsubjidVar TRTPVar AEBODSYSVar ASTDYVar AESEVVar STUDYIDVar
				AEDECODVar AESERVar AESTDYVar ASEVVar ASTDTVar APERIODVar  $20.;
		retain UsubjidVar TRTPVar AEBODSYSVar ASTDYVar AESEVVar STUDYIDVar 
				AEDECODVar AESERVar  AESTDYVar ASEVVar ASTDTVar APERIODVar;

		%** Map STUDYID variable **;
		if upcase(colname) = "STUDYID" and STUDYIDVar = "" then do;
			STUDYIDVar = colname;
		end;

		%** Map Usubjid variable **;
		if upcase(colname) = "USUBJID" and UsubjidVar = "" then do;
			UsubjidVar = colname;
		end;

		%** Map TRTA variable **;
		if upcase(colname) = "TRTA" and TRTPVar = "" then do;
			TRTPVar = colname;
		end;

		%** Map AEBODSYS variable **;
		if upcase(colname) = "AEBODSYS" and AEBODSYSVar = "" then do;
			AEBODSYSVar = colname;
		end;


		%** Map ASTDY variable **;
		if upcase(colname) = "ASTDY" and ASTDYVar = "" then do;
			ASTDYVar = colname;
		end;

		%** Map AESEV variable **;
		if upcase(colname) = "AESEV" and AESEVVar = "" then do;
			AESEVVar = colname;
		end;



		%** Map AEDECOD variable **;
		if upcase(colname) = "AEDECOD" and AEDECODVar = "" then do;
			AEDECODVar = colname;
		end;

		%** Map AESER variable **;
		if upcase(colname) = "AESER" and AESERVar = "" then do;
			AESERVar = colname;
		end;

		%** Map AESTDY variable **;
		if upcase(colname) = "AESTDY" and AESTDYVar = "" then do;
			AESTDYVar = colname;
		end;

		%** Map ASEV variable **;
		if upcase(colname) = "ASEV" and ASEVVar = "" then do;
			ASEVVar = colname;
		end;

		%** Map ASTDT variable **;
		if upcase(colname) = "ASTDT" and ASTDTVar = "" then do;
			ASTDTVar = colname;
		end;
		%** Map APERIOD variable **;
		if upcase(colname) = "APERIOD" and APERIODVar = "" then do;
			APERIODVar = colname;
		end;

		if eof then do;
			%** Mappings **;
			call symputx("UsubjidVar", UsubjidVar, "G");
			call symputx("TRTPVar", TRTPVar, "G");
	
			call symputx("ASTDYVar", ASTDYVar, "G");
			call symputx("AESEVVar", AESEVVar, "G");
			call symputx("STUDYIDVar", STUDYIDVar, "G");
			call symputx("AEDECODVar", AEDECODVar, "G");
			call symputx("AESERVar", AESERVar, "G");
			call symputx("AESTDYVar", AESTDYVar, "G");
			call symputx("ASEVVar", ASEVVar, "G");
			call symputx("ASTDTVar", ASTDTVar, "G");
			call symputx("AEBODSYSVar", AEBODSYSVar, "G");
			call symputx("APERIODVar", APERIODVar, "G");




			%** Mapping quality **;
			if UsubjidVar ne "" then do;
				call symputx("UsubjidVarQual", 0, "G");
			end;
			else do;
				call symputx("UsubjidVarQual", 2, "G");
			end;

			if TRTPVar ne "" then do;
				call symputx("TRTPVarQual", 0, "G");
			end;
			else do;
				call symputx("TRTPVarQual", 2, "G");
			end;


			if ASTDYVar ne "" then do;
				call symputx("ASTDYVarQual", 0, "G");
			end;
			else do;
				call symputx("ASTDYVarQual", 2, "G");
			end;

			if AESEVVar ne "" then do;
				call symputx("AESEVVarQual", 0, "G");
			end;
			else do;
				call symputx("AESEVVarQual", 2, "G");
			end;



			if STUDYIDVar ne "" then do;
				call symputx("STUDYIDVarQual", 0, "G");
			end;
			else do;
				call symputx("STUDYIDVarQual", 2, "G");
			end;

			if AEDECODVar ne "" then do;
				call symputx("AEDECODVarQual", 0, "G");
			end;
			else do;
				call symputx("AEDECODVarQual", 2, "G");
			end;


			if AESERVar ne "" then do;
				call symputx("AESERVarQual", 0, "G");
			end;
			else do;
				call symputx("AESERVarQual", 2, "G");
			end;

			if AESTDYVar ne "" then do;
				call symputx("AESTDYVarQual", 1, "G");
			end;
			else do;
				call symputx("AESTDYVarQual", 2, "G");
			end;



			if ASEVVar ne "" then do;
				call symputx("ASEVVarQual", 1, "G");
			end;
			else do;
				call symputx("ASEVVarQual", 2, "G");
			end;

			if ASTDTVar ne "" then do;
				call symputx("ASTDTVarQual", 1, "G");
			end;
			else do;
				call symputx("ASTDTVarQual", 2, "G");
			end;

			if AEBODSYSVar ne "" then do;
				call symputx("AEBODSYSVarQual", 0, "G");
			end;
			else do;
				call symputx("AEBODSYSVarQual", 2, "G");
			end;

			if APERIODVar ne "" then do;
				call symputx("APERIODVarQual", 1, "G");
			end;
			else do;
				call symputx("APERIODVarQual", 2, "G");
			end;

	
		end;
	run;
%end;
%else %if %upcase(&type.) = SL %then %do;
	data _null_;
		set &Input. end = eof;
		length ARMVar TRTSDTVar LSTVSTDTVar   $20.;
		retain ARMVar TRTSDTVar LSTVSTDTVar	 ;

		%** Map ARM variable **;
		if upcase(colname) = "ARM" and ARMVar = "" then do;
			ARMVar = colname;
		end;
		%** Map TRTSDT variable **;
		
		if upcase(colname) = "TRTSDT" and TRTSDTVar = "" then do;
			TRTSDTVar = colname;
		end;
	   %** Map TRTSDT variable **;
		
		if upcase(colname) = "LSTVSTDT" and LSTVSTDTVar = "" then do;
			LSTVSTDTVar = colname;
		end;
	  
		if eof then do;
			%** Mappings **;
			call symputx("ARMVar", ARMVar, "G");
			call symputx("TRTSDTVar", TRTSDTVar, "G");
			call symputx("LSTVSTDTVar", LSTVSTDTVar, "G");


			%** Mapping quality **;
			if ARMVar ne "" then do;
				call symputx("ARMVarQual", 0, "G");
			end;
			else do;
				call symputx("ARMVarQual", 1, "G");
			end;

			if TRTSDTVar ne "" then do;
				call symputx("TRTSDTVarQual", 0, "G");
			end;
			else do;
				call symputx("TRTSDTVarQual", 2, "G");
			end;

			if LSTVSTDTVar ne "" then do;
				call symputx("LSTVSTDTVarQual", 0, "G");
			end;
			else do;
				call symputx("LSTVSTDTVarQual", 2, "G");
			end;


		end;
	run;

%end;

%else %if %upcase(&type.) = VS %then %do;
	data _null_;
		set &Input. end = eof;
		length ADYVar   $20.;
		retain ADYVar  ;

		%** Map ADY variable **;
		if upcase(colname) = "ADY" and ADYVar = "" then do;
			ADYVar = colname;
		end;

		if eof then do;
			%** Mappings **;
			call symputx("ADYVar", ADYVar, "G");

			if ADYVar ne "" then do;
				call symputx("ADYVarQual", 0, "G");
			end;
			else do;
				call symputx("ADYVarQual", 2, "G");
			end;
	 	end;
	run;
	

%end;
%mend;
