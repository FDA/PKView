--------------------------
Update on October 15, 2018
--------------------------

# Title

eSafety: An automated tool for dose-response analyses of ISS datasets

# Authors

Peter Lee, Justin Earp, Ying Yang, Yue Zhou, Gunjan Gugale

OCP, OTS, CDER, FDA

# Description

This is an interactive tool for dose response analyses of integrated summary of safety (ISS) data in conjunction with pharmacokinetic (PK), demographic (DM), and laboratory (LAB) information.  The tool implements an automated data workflow to systematically screen the reported adverse events for potential dose dependent safety response.  It utilizes an extensive code library for data management and modeling analyses.  

Conducting analyses on the ISS datasets can be extremely challenging due to large number of adverse events reported, heterogeneous and complex study designs involved, many influencing covariates and inclusion/exclusion criteria to be considered, and wide range of methods available for assisting data interpretation.  An automated workflow is necessary to streamline the analysis process in order to navigate through the overwhelming information presented in the ISS and other associated clinical database.  The exploratory nature of drug safety analyses also necessitates an interactive tool to provide the flexibility needed for testing many different hypotheses.  

The eSafety tool provides a comprehensive solution for scientists and clinicians to efficiently analyze ISS datasets that follow the standard CDISC ADaM format.  The users can interactively explore ISS, PK, DM, and LAB datasets and render high quality analysis graphs and summary tables.   The application will also reduce the learning curve for new scientists to perform complex analyses on ISS data.

Please read [‘eSafety Data Requirement and Screen Shots’](https://github.com/FDA/PKView/blob/master/eSafety%20Data%20Requirement%20%26%20Screen%20Shots.pdf).

----------------------------------
Original Post on September 8, 2017
----------------------------------

# Title

PKView: an automated analysis tool for clinical pharmacology studies


# Authors

Peter ID Lee<sup>1</sup>, Jens Stampe Sorensen<sup>2</sup>, Eduard Porta<sup>2</sup>, Jiaxiang Gai<sup>2</sup>, Meng Xu<sup>2</sup>, Feng Wang<sup>2</sup>, Gunjan Gugale<sup>2</sup>

1. Associate Director, OCP, OTS, CDER, FDA
2. ORISE Fellow, OCP, OTS, CDER, FDA

# Abstract

PKView has been developed to automate the pharmacokinetic analyses of clinical pharmacology studies.  These studies are typically conducted during the phase 1 and 2 of the clinical development process, and are pivotal for bioequivalence determination, dosing adjustment in special populations, safety evaluation with concurrent drug administration, and the investigations of many other intrinsic and extrinsic factors.  The study design can vary widely depending on the study objectives and the pharmacokinetics and pharmacodynamics of the drug.   The treatment scheme may range from crossover, to parallel, sequential, multiple-cohort and nested, with most studies examining multiple arms of patients.  In addition, study observations can span from single visit to steady state and include the pharmacokinetics of parent drug, metabolite, and concurrent medications. 
 
Automation of clinical study data analysis has been an ambitious project for us, due to the wide spectrum of data formats among different pharmaceutical companies and the large varieties of clinical study designs.  Throughout the years, we have accumulated experiences with hundreds of NDA and BLA submissions and close to a thousand clinical studies.   The recurrent scenarios (e.g., study designs, data formats, and analysis methodologies) observed from these past submissions have been categorized in a knowledgebase, with the corresponding solutions built into PKView.  

The PKView platform consists of the following components

1. The data management module assists the user to load the study data in SDTM format.
2. The reporting module allows the user to generate various types analysis reports on a per study basis.
3. The meta-analysis module performs meta-analysis combing multiple studies.

# Sample Outputs

1. Side-by-side comparison of Source vs Default analysis outcomes
2. Standard cohort of tables and figures for typical clinical reports
3. Forest plot for drug labels
4. Study conduct integrity evaluation

For the complete list, please see [Output_listing](https://github.com/FDA/PKView/blob/master/Output%20listing.md)

# System Requirement

1. Windows 7 pro, or Windows 10 pro
2. SAS 9.4

Please see Installation_instruction. 


# User Instructions

Please see Data_requirement, Screen_shots, and Trouble_shooting.

# Disclaimer

Wherever applied, the contents in this Software and its accompanied documentations reflect the views of the authors and should not be construed to represent FDA’s views or policies.

# Questions and Comments

Please post any questions or comments under the "Issues" tab.
