/********************************************************************
 000_config.do
********************************************************************/
version 16.0
clear all
set more off
set linesize 255

* Run master.do from the project root.
global PROJ "`c(pwd)'"

global RAW    "${PROJ}/data_raw"     // Raw data
global CLEAN  "${PROJ}/data_clean"   // Processed, cleaned data
global DO     "${PROJ}/do"           // Standard do file
global LOG    "${PROJ}/log"          // do file logs
global OUT    "${PROJ}/output"       // Charts and graphs resulting from the analysis

