
%let work = work;
options nofmterr compress = yes mprint spool noxwait noxsync;

/* Clean the environment */
proc datasets lib=work memtype=data nolist;
delete dirs: files:;
quit;

%** Find folders and files in the specified input folder **;
%let datetime_start = %sysfunc(TIME()) ;
%put START TIME1: %sysfunc(datetime(),datetime14.);

%** Extract Submission Id (submission folder name) **;
%let submissionId = %scan(&inputfolder.,1,"\/",bt);
%put &submissionId.;

%** Speed up the script by only looking at \0000\m5 **;
%let optimizationPath = \m5\datasets;

/* Find data folders */
data &work..dirs_found1(compress=no);
	Keep root;
	length fref $8 root $500;

	/* Assign a fileref to the root path, open it and get a directory identifier */
	rc = filename(fref, "&InputFolder.");
	if rc = 0 then do; 
		did = dopen(fref); 
		rc = filename(fref); 
	end; 
	else do; 
		length msg $200.; 
		msg = sysmsg(); 
		putlog msg=; 
		did = .; 
	end;

	/* Error opening the directory */
	if did <= 0 then do; 
        putlog 'an error occurred opening the input folder';
		return; 
	end;

	/* For each member in the directory, retrieve the subdirectories */
	dnum = dnum(did);
	do i = 1 to dnum; 
		root = dread(did, i);

        /* Before attempting to access the folder, rule out excel files and other packages
		   that can be read as directories by extension */
		if index(root,  ".") = 0 then do;        
            fid = mopen(did, root);
            if fid = 0 then do;
                /* Retrieve all study folders for this serial */
                serialFolder = cats("&InputFolder.", "\", root, "&optimizationPath.");

                /* Assign a fileref to the path, open it and get a directory identifier */
                rc = filename(fref, serialFolder);
                if rc = 0 then do; 
                    did2 = dopen(fref); 
                    rc = filename(fref); 
                end; 
                else do; 
                    length msg $200.; 
                    msg = sysmsg(); 
                    putlog msg=; 
                    did2 = .; 
                    return;
                end;

                /* If there is no error and directory is not empty */
				if did2 > 0 then do;

                    /* For each member in the directory, retrieve the subdirectories */
                    dnum2 = dnum(did2);
                    do j = 1 to dnum2; 
                        root = dread(did2, j); 
                        fid2 = mopen(did2, root);
                        if fid2 = 0 then do;
                            root = cats(serialfolder,"\", root);
                            output;  
                        end;
                    end;
                end;

                rc = dclose(did2);
            end;
        end;
	end;
	rc = dclose(did);
run;
proc print data=&work..dirs_found1;run;

/* Find data files */
data &work..dirs_found1
	 &work..dirs_found(keep=path)
	 &work..files_found(compress=no);
	keep Path FileName;
	length fref $8 Filename $500;
	modify &work..dirs_found1;
	Path = root;
	
	/* Assign a fileref to the study folder, open it and get a directory identifier */
	rc = filename(fref, path);
	if rc = 0 then do; 
		did = dopen(fref); 
		rc = filename(fref); 
	end; 
	else do; 
		length msg $200.; 
		msg = sysmsg(); 
		putlog msg=; 
		did = .;
        return;        
	end;

	/* If there is no error and directory is not empty */
    if did > 0 then do;
        dnum = dnum(did);
        filesFound = 0;
        dirsFound = 0;
        array dirs {0:999} $500 _temporary_;
        do i = 1 to dnum while (filesFound < 6); 
            filename = dread(did, i); 
            
            /* Does the filename match the ones we are looking for? */
            if upcase(filename) in ("DM.XPT", "EX.XPT", "PC.XPT", "PP.XPT", "SUPPDM.XPT", 'SC.XPT') then do;          
                /* Enable this "if" to check if it is really a file. Causes a performance hit */
                /*fid = mopen(did, filename);
                if fid > 0 then do; */                
                output &work..files_found; 
                filesFound = filesFound + 1;
                /*end;*/                
            end; 
            else do;
                dirs{dirsFound} = filename; 
                dirsFound = dirsFound + 1;
            end; 
        end;

        /* If no files were found, dig deeper */
        if filesFound = 0 then do;
            do i = 0 to (dirsFound - 1);
                root = catt(path, "\", dirs{i}); 
                output &work..dirs_found1; 
            end;
        end;
        /* If folder contains data files save it to the list of folders to create */
        else output &work..dirs_found; 
    end;
	rc = dclose(did);
run;

%put END TIME1: %sysfunc(datetime(),datetime14.);
%put PROCESSING TIME1:  %sysfunc(putn(%sysevalf(%sysfunc(TIME())-&datetime_start.),mmss.)) (mm:ss) ;

%let datetime_start = %sysfunc(TIME()) ;
%put START TIME2: %sysfunc(datetime(),datetime14.);

proc print data=&work..files_found;
proc print data=&work..dirs_found;run;

%** Create the output folders **;
  %let datetime_start = %sysfunc(TIME()) ;
  %put START TIME3: %sysfunc(datetime(),datetime14.);

/* NOTE: folder creation will be synchronous so we don't try to copy files to non-existing folders */
options noxwait xsync;
data &work..output_folders;
	length OutFolder command $800.;
	set &work..dirs_found(where = ( find(upcase(path), "DATASETS")));

	%** Create the output destination **;
	OutFolder = cats("&OutputFolder.", "\", "&submissionId.", substr(path, length("&InputFolder.") + 1));

	%** Define the windows/DOS command **;
	command = "mkdir """|| OutFolder || """";

	%** Run it **;
	call system(command);
run;

  %put END TIME3: %sysfunc(datetime(),datetime14.);
  %put PROCESSING TIME3:  %sysfunc(putn(%sysevalf(%sysfunc(TIME())-&datetime_start.),mmss.)) (mm:ss) ;

%** Move the files **;
  %let datetime_start = %sysfunc(TIME()) ;
  %put START TIME4: %sysfunc(datetime(),datetime14.);

/* switch to asynchronous mode to speed up file copy */
options noxwait noxsync;
data &work..files;
	set &work..files_found;
	length OutDestination FileCopy command $800.;

	%** File to copy **;
	FileCopy = cats(Path, "\", FileName);

	%** Create the output destination **;
	OutDestination = cats("&OutputFolder.", "\", "&submissionId.", substr(Path, length("&InputFolder.") + 1));

	%** Define the windows/DOS command **;
	command = "copy """ || strip(FileCopy) || """ """ || strip(OutDestination) || """";
	call system(command);
run;



  %put END TIME4: %sysfunc(datetime(),datetime14.);
  %put PROCESSING TIME4:  %sysfunc(putn(%sysevalf(%sysfunc(TIME())-&datetime_start.),mmss.)) (mm:ss) ;

