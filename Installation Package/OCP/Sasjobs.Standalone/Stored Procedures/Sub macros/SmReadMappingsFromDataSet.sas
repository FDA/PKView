
%macro SmReadMappingsFromDataSet();

	%** Macro variables **;
	%global StudyDesign StudyType DmPath ExPath PcPath PpPath
			UsubjidVar ArmVar AgeVar SexVar CountryVar RaceVar EthnicVar
			ExTrtVar ExStdtcVar ExVisitVar
			PcstresnVar PcVisitVar PcTestVar PcTptnumVar PcSpecimenVar
			PpstresnVar PpVisitVar PpCatVar PpTestcdVar PpSpecimenVar
            UseEx UseSuppdm SupplementNum
	;
	%local i;
	
	%** Retrieve user settings **;
	data &work.userData;
		set websvc.userConfig end = eof;
	if Name="Username" then 
		call symputx("UserName", dequote(value), "G");
	if Name="ProfileName" then 
		call symputx("ProfileName", dequote(value), "G");
	run;
	
	%** Debug **;
	%put User: &UserName.;
	%put Settings Id: &ProfileName.;

	data &work.study;
		set websvc.study end = eof;        
	if eof then do;
		call symputx("StudyType", Type, "G");
		call symputx("StudyId", StudyCode, "G");
		call symputx("StudyDesign", Design, "G");
		call symputx("SubmissionID", Submission, "G");
        call symputx("SupplementNum", dequote(Supplement), "G");
		call symputx("UseEx", UseEx, "G");
		call symputx("UseSuppdm", UseSuppdm, "G");
        call symputx("DisablePcCleanup", DisablePcCleanup, "G");
        
        call symputx("UseCustomArms", UseCustomArms, "G");
        call symputx("UseCustomPcVisit", UseCustomPcVisit, "G");
        call symputx("UseCustomPcPctptnum", UseCustomPcPctptnum, "G");
        call symputx("UseCustomPpVisit", UseCustomPpVisit, "G");
	end;
	run;




	%if &StudyDesign=2 %then %let StudyDesign=SEQUENTIAL;
	%if &StudyDesign=3 %then %let StudyDesign=PARALLEL;
	%if &StudyDesign=4 %then %let StudyDesign=CROSSOVER;
	
	%if &StudyType=0 %then %let StudyType=UNKNOWN;
	%if &StudyType=1 %then %let StudyType=INTRINSIC;
	%if &StudyType=2 %then %let StudyType=EXTRINSIC;
    
	%** Debug **;
	%put Extracted Study Design: &StudyDesign.;
	%put Extracted Study Type: &StudyType.;
	%put Extracted Study Id: &StudyId.;
	%put Extracted Submission Id: &SubmissionID.;
    %put Supplement Number: &SupplementNum.;
	%put Use EX: &UseEx.;
	%put Use SUPPDM: &UseSuppdm.;
    %put Use Custom Pc Visit: &UseCustomPcVisit.;
    %put Use Custom Pp Visit: &UseCustomPpVisit.;
    %put Use Custom Pc pctptnum: &UseCustomPcPctptnum.;

	%** Save into global macro variables **;
	data _null_;
		set websvc.mapping;
		if upcase(DOMAIN)="DM" and upcase(STDMVAR)="USUBJID" then call symputx("UsubjidVar",FILEVAR,"G");
		if upcase(DOMAIN)="DM" and upcase(STDMVAR)="ARM" then call symputx("ArmVar",FILEVAR,"G");
		if upcase(DOMAIN)="DM" and upcase(STDMVAR)="AGE" then call symputx("AgeVar",FILEVAR,"G");
		if upcase(DOMAIN)="DM" and upcase(STDMVAR)="SEX" then call symputx("SexVar",FILEVAR,"G");
		if upcase(DOMAIN)="DM" and upcase(STDMVAR)="RACE" then call symputx("RaceVar",FILEVAR,"G");
		if upcase(DOMAIN)="DM" and upcase(STDMVAR)="COUNTRY" then call symputx("CountryVar",FILEVAR,"G");
		if upcase(DOMAIN)="DM" and upcase(STDMVAR)="ETHNIC" then call symputx("EthnicVar",FILEVAR,"G");
		if upcase(DOMAIN)="EX" and upcase(STDMVAR)="EXTRT" then call symputx("ExTrtVar",FILEVAR,"G");
		if upcase(DOMAIN)="EX" and upcase(STDMVAR)="EXSTDTC" then call symputx("ExStdtcVar",FILEVAR,"G");
		if upcase(DOMAIN)="EX" and upcase(STDMVAR)="VISIT" then call symputx("ExVisitVar",FILEVAR,"G");
		if upcase(DOMAIN)="PC" and upcase(STDMVAR)="VISIT" then call symputx("PcVisitVar",FILEVAR,"G");
		if upcase(DOMAIN)="PC" and upcase(STDMVAR)="PCTEST" then call symputx("PCTESTVar",FILEVAR,"G");
		if upcase(DOMAIN)="PC" and upcase(STDMVAR)="PCSTRESN" then call symputx("PcStresnVar",FILEVAR,"G");
		if upcase(DOMAIN)="PC" and upcase(STDMVAR)="PCTPTNUM" then call symputx("PctptnumVar",FILEVAR,"G");
		if upcase(DOMAIN)="PP" and upcase(STDMVAR)="VISIT" then call symputx("PpVisitVar",FILEVAR,"G");
		if upcase(DOMAIN)="PP" and upcase(STDMVAR)="PPCAT" then call symputx("PpcatVar",FILEVAR,"G");
		if upcase(DOMAIN)="PP" and upcase(STDMVAR)="PPSTRESN" then call symputx("PpstresnVar",FILEVAR,"G");
		if upcase(DOMAIN)="PP" and upcase(STDMVAR)="PPTESTCD" then call symputx("PptestcdVar",FILEVAR,"G");
	run;
    
    /* hardcode specimen for now (FIXME) */
    %let PpSpecimenVar=PPSPEC;
    %let PcSpecimenVar=PCSPEC;
    
    /* Load custom dm arms */
    %if &UseCustomArms.=1 %then %do;
        data &work.customDmArms;
			set websvc.customDmArms;
		run;
    %end;  

    /* Load custom pc:visit */
    %if &UseCustomPcVisit.=1 %then %do;
        data &work.customPcVisit;
			set websvc.customPcVisit;
		run;
    %end;   
    
    /* Load custom pc:visit */
    %if &UseCustomPcPctptnum.=1 %then %do;
        data &work.customPcPctptnum;
			set websvc.customPcPctptnum;
		run;
    %end;   

    /* Load custom pp:visit */
    %if &UseCustomPpVisit.=1 %then %do;
        data &work.customPpVisit;
			set websvc.customPpVisit;
		run;
    %end;    
	
	data _null_;
		set sashelp.vmember(where = (libname = "WEBSVC" and memtype = "DATA"));
		if upcase(memname) = "%upcase(references)" then call symput("Exist",1);
		else call symput("Exist",0);
	run;
    %put references exist=&Exist;
	
	/* copy reference treatments/groups if present 
	(when we are not creating the reference for the first time) */
	%if &Exist %then %do;
		data &work.references;
			set websvc.references;
		run;
        %put references loaded;
	%end;
	

	%let inputfolder=&inputfolder.&SubmissionID.;
	%put inputfolder=&inputfolder.;
	%SmListFilesInFolder(
		Path = &inputfolder.,
		Out = &work.files
	);

	** Get the path to the datasets **;
	data _null_;
		set &work.files end = eof;
		if scan(upcase(path), -1, "\") = "&StudyId." then do;
			call symputx("DatasetPath", substr(path, 1, length(path) - length("&StudyId") - 1));
			stop;
		end;
	run;
	%put DatasetPath = &DatasetPath.;

	%SmIdentifySdtmData(
		DataSetPath = &DataSetPath.,
		StudyId = &StudyId.
	);

	%** Debug **;
	%put DM file path = &InputDm.;
	%put EX file path = &InputEx.;
	%put PC file path = &InputPc.;
	%put PP file path = &InputPp.;

	%put UsubjidVar = &UsubjidVar.; 
	%put ArmVar = &ArmVar.; 
	%put AgeVar = &AgeVar.; 
	%put SexVar = &SexVar.; 
	%put CountryVar = &CountryVar.; 
	%put RaceVar = &RaceVar.; 
	%put EthnicVar = &EthnicVar.; 
	%put ExTrtVar = &ExTrtVar.;
	%put ExVisitVar = &ExVisitVar.;
	%put ExStdtcVar = &ExStdtcVar.;
	%put PcstresnVar = &PcStresnVar.; 
	%put PcVisitVar = &PcVisitVar.; 
	%put PctptnumVar = &PctptnumVar.; 
	%put PpstresnVar = &PpstresnVar.; 
	%put PpVisitVar = &PpVisitVar.; 
	%put PpcatVar = &PpcatVar.; 
	%put PptestcdVar = &PptestcdVar.; 
    %put PpSpecimenVar = &PpSpecimenVar.;
    %put PcSpecimenVar = &PcSpecimenVar.;

%mend SmReadMappingsFromDataSet;
