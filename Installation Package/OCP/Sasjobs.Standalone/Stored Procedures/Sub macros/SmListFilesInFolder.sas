%*****************************************************************************************;
%**	                                                                                    **;
%**	List all folder, sub-folder and files within a folder                               **;
%**                                                                                     **;
%**	Input:																				**;
%**		Path	        	-		Path to the folder									**;
%**		Out					-		Dataset containing the identified content			**;
%**																						**;
%** Output:                                                                             **;
%**		Dataset with paths to the sub-folder and files									**;
%**																						**;
%**	Created by:																			**;
%**		Jens Stampe Soerensen  (2013/2014)                                              **;
%**																						**;
%*****************************************************************************************;

%macro SmListFilesInFolder( 
		PATH = , 
		OUT = ,
);

data &work.dirs_found (compress=no); 
	length Root $500.; 
	root = "&Path."; 
	output;
run;

data &work.dirs_found &work.files_found (compress=no);
	keep Path FileName FileType;
	length fref $8 Path Filename $500 FileType $16;
	modify &work.dirs_found;
	Path = root;

	rc = filename(fref, path);
	if rc = 0 then do; 
		did = dopen(fref); 
		rc = filename(fref); 
	end; 
	else do; 
		length msg $500.; 
		msg = sysmsg(); 
		putlog msg=; 
		did = .; 
	end;

	if did <= 0 then do; 
		return; 
	end;
	dnum = dnum(did);
	do i = 1 to dnum; 
		filename = dread(did, i); 
		fid = mopen(did, filename);
		if fid > 0 then do; 
			FileType = prxchange('s/.*\.{1,1}(.*)/$1/', 1, filename); 
			if filename = filetype then filetype = ' '; 
			output &work.files_found; 
		end; 
		else do;
			root = catt(path, "\", filename); 
			output &work.dirs_found; 
		end; 
	end;
	rc = dclose(did);
run;

data &Out.(rename = (root = path));
	set &work.dirs_found;
run;

%mend SmListFilesInFolder;
