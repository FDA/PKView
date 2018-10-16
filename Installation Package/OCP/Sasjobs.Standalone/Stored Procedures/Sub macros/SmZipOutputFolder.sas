%*****************************************************************************************;
%**																						**;
%** Zip a folder and all its content													**;
%**																						**;
%**	Input:																				**;
%**		OutputFolder					-		Output folder to place the zip file		**;
%**		FolderContent			        -		Dataset with paths to the files to zip	**;
%**		ZipName							-		Name of the zip file					**;
%**																						**;
%** Output:                                                                             **;
%**		Zip file with the name from ZipName												**;
%**																						**;
%**	Created by:																			**;
%**		Jens Stampe Soerensen  (2013/2014)                                              **;
%**																						**;
%*****************************************************************************************;

%macro SmZipOutputFolder(
	OutputFolder = ,
	FolderContent = ,
	ZipName = 
);

%** Prepare the output folders for zipping. **;
%** File = absolute path 					**;
%** Zippath = folder in the zip file 		**;
data &work.ZipFiles;
	length file zippath $500.;
	set &FolderContent.(where = (upcase(filetype) ne "ZIP"));
	if upcase(path) = "%upcase(&OutputFolder.)" then do;
		file = cats(path, "\", filename);
		zippath = "";
	end;
	else do;
		file = cats(path, "\", filename);
		zippath = scan(path, -1, "\");
	end;

	keep file zippath;
run;

data &work.zipfiles;
    length file $500.;
    set &work.files_found;
    file = cats(path, "\", filename);
    path=tranwrd(path,"&outputfolder\","");
    rename Path=zippath;
    drop filetype filename;
run;

%** Sort **;
proc sort data = &work.ZipFiles;
	by file;
run;

%** Zip (call execute is ugly but does the trick) **;
ods package(ZipOutput) open nopf;
data _null_;
	set &work.ZipFiles;
	call execute(
		catx("", 
			 "ods package(ZipOutput)",
			 "add file ='",
			 file,
			 "' path = '",
			 zippath,
			 "';"
		)
	);
run;
ods package(ZipOutput) publish archive
	properties(archive_name = "&ZipName..zip"
			   archive_path = "&OutputFolder.\..");
ods package(ZipOutput) close;

%mend;
