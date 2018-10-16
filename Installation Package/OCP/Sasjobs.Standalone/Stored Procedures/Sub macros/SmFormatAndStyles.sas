%*****************************************************************************************;
%**																						**;
%**	Format and styles used for all PKView output										**;
%**																						**;
%**	Input:																				**;
%**		None																			**;
%** Output:                                                                             **;
%**		None																			**;
%**																						**;
%**	Created by:																			**;
%**		Jens Stampe Soerensen  (2013/2014)                                              **;
%**																						**;
%*****************************************************************************************;

%macro SmFormatAndStyles;
	proc format;
		picture par1pct
	
			0.00 - < 1.0 = '001.0)'		(prefix = '(' multiplier = 10.0)
			1 - high = '0000.0)'		(prefix = '(' multiplier = 10.0)
		;
	run;

	proc template;
		define style fda_style;
			parent = styles.sasdocprinter;

			style fonts /
				"TitleFont2" 			= ("Courier, Helvetica", 10pt, bold)
				"TitleFont" 			= ("Courier, Helvetica", 12pt, bold)
				"StrongFont" 			= ("SAS Monospace, Courier", 10pt, bold)
				"EmphasisFont" 			= ("SAS Monospace, Courier", 8pt)
				"FixedEmphasisFont" 	= ("SAS Monospace, Courier", 6pt)
				"FixedStrongFont" 		= ("SAS Monospace, Courier", 6pt,bold)
				"FixedHeadingFont" 		= ("SAS Monospace, Courier", 6pt)
				"BatchFixedFont" 		= ("SAS Monospace, Courier", 6pt)
				"FixedFont" 			= ("SAS Monospace, Courier", 6pt)                             
				"headingEmphasisFont" 	= ("SAS Monospace, Courier", 10pt,bold) 
				"headingFont" 			= ("SAS Monospace, Courier", 10pt,bold)       
				"docFont" 				= ("SAS Monospace, Courier", 8pt)
			;  
		end;
	run;

%mend;