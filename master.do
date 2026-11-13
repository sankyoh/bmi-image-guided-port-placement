/********************************************************************
 master.do
********************************************************************/
version 19
clear all
set more off

do 000_config.do

di as text "=== START master.do ==="

* Organizing data for analysis
do "${DO}/010_import.do"
do "${DO}/020_clean.do"

* Descriptive Statistics
do "${DO}/040_DesStat.do"

* Actual Analysis
// Calculation of Effect Sizes (Risk Ratio, Mean Difference)
do "${DO}/200_riskratio_bmi_cat.do" outcome(succ)    suffix(succ)
do "${DO}/200_riskratio_bmi_cat.do" outcome(adevent) suffix(AE)
do "${DO}/210_time_bmi_cat.do"

// RCS rendering
do "${DO}/300_RCS_bmi.do" outcome(succ)    suffix(succ) xtitle(secondary success)
do "${DO}/300_RCS_bmi.do" outcome(adevent) suffix(AE)   xtitle(adverse event)
do "${DO}/310_RCS_time_bmi.do"

di as text "=== END master.do ==="
