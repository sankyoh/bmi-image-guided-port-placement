****************************************************
* 040_DesStat.do
* Role: Calculating descriptive statistics
* df02_clean.dta -> Table1.xlsx
****************************************************

* 0) Log
cap log close
log using "$LOG\log_040_DesStat.smcl", replace

* 1) Input Data Files and Output Data Files
local read_file  "$CLEAN\df01.dta"
local write_file "${OUT}/Table1.xlsx"

use "`read_file'", clear

* Role: Calculating descriptive statistics
gen     anticoa_des = 1 if   anticoa==1 & anticoa_stop==0
replace anticoa_des = 0 if !(anticoa==1 & anticoa_stop==0)
label values anticoa_des ny

gen     antiplt_des = 1 if   antiplt==1 & antiplt_stop==0
replace antiplt_des = 0 if !(antiplt==1 & antiplt_stop==0)
label values antiplt_des ny

********************************************************************************
* Table 1
********************************************************************************

dtable age i.sex i.inout i.purpose wbc neu crp plt ptinr ///
       i.anticoa_des i.antiplt_des i.bv_lr i.bv_posi i.guide, ///
    by(bmi_cat1) ///
    continuous(age wbc neu crp plt ptinr, statistics(q2 iqi)) ///
    define(iqi = q1 q3, delimiter(" - ")) ///
    nformat(%9.1f q2 q1 q3 iqi) ///
    sformat("(%s)" iqi) ///
    export("`write_file'", replace)


log close
exit
