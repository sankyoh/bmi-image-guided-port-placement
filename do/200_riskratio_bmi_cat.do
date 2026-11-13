****************************************************
* 200_riskratio_bmi_cat.do
* Role: Calculates the risk of secondary success using BMI categorized into groups as an exposure.
* df01.dta -> Risk_Ratio_bmi_cat.dta
****************************************************

*--------------------------------------------------
* Processing Arguments
*
* Example of usage:
*   do 200_riskratio_bmi_cat.do
*   do 200_riskratio_bmi_cat.do outcome(succ) suffix(succ)
*
* Notes:
* An "_" (underscore) is automatically prepended to the filename suffix.
* The expected outcome is "adevent succ" (or "succ" if omitted).
* Any suffix is allowed, but if omitted, it defaults to the same value as the outcome.
*--------------------------------------------------

local 0 `", `0'"'
syntax [, OUTCOME(string) SUFFIX(string)]

// outcome: Event to be analyzed
// suffix : File suffix

qui {
noi display as text "outcome: `outv'"
noi display as text "suffix : `suffix'"
}

if `"`outcome'"' == "" {
    local outcome succ
} 


if `"`suffix'"' != "" {
	local suffix "_`suffix'"
}
else {
	local suffix "_`outcome'"
}


****************************************************
* 0) Log
****************************************************

cap log close
log using "$LOG\log_200_riskratio_bmi_cat`suffix'.smcl", replace

****************************************************
* 1) Input Data Files and Output Data Files
****************************************************

local read_file  "$CLEAN\df01.dta"
local write_file "$OUT\Risk_Ratio_bmi_cat`suffix'.xlsx"

use "`read_file'", clear

****************************************************
* 2) Setting Variables
****************************************************

local expvs bmi_cat1 bmi_cat2
local outv  `outcome'
local covs  age sex purpose inout antibact anticoa antiplt beva

* Adjustment variables for each model
local covars0             // Crude model
local covars1 `covs'      // Adjusted model

****************************************************
* 3) Preparing the postfile to store the results
****************************************************
tempname memhold
tempfile results

postfile `memhold' ///
    str30 exposure ///
    float cRR cCI_l cCI_u cPv ///
    float aRR aCI_l aCI_u aPv ///
    using "`results'", replace

****************************************************
* 4) Adjusted Poisson regression
*    bmi_cat1: with 2 as the reference
*    bmi_cat2: with 4 as the reference
****************************************************
foreach x of local expvs {

    if "`x'" == "bmi_cat1" local ref 2
    if "`x'" == "bmi_cat2" local ref 4

    * BMI categories among participants for whom outcomes have been observed
    quietly levelsof `x' if !missing(`x', `outv'), local(levels)

    foreach k of local levels {

        * The reference category itself does not generate any result rows.
        if `k' != `ref' {

            * Initialization
            local b0  = .
            local lb0 = .
            local ub0 = .
            local pv0 = .

            local b1  = .
            local lb1 = .
            local ub1 = .
            local pv1 = .

            forvalues m = 0/1 {

                capture noisily poisson `outv' ib`ref'.`x' ///
                    `covars`m'', robust irr

                if !_rc {
                    capture noisily lincom `k'.`x', eform level(95)

                    if !_rc {
                        local b`m'  = r(estimate)
                        local lb`m' = r(lb)
                        local ub`m' = r(ub)
                        local pv`m' = r(p)
                    }
                }
            }

            post `memhold' ("`x': `k' vs `ref'") ///
                (`b0') (`lb0') (`ub0') (`pv0') ///
                (`b1') (`lb1') (`ub1') (`pv1')
        }
    }
}

postclose `memhold'

****************************************************
* 5) Load the results data
****************************************************
use "`results'", clear

****************************************************
* 6) Create a list of strings for the paper table
*    "Point estimate (95% confidence interval)" and "p-value"
****************************************************

* Crude model: Point estimates (95% confidence intervals)
gen str40 cRR_CI = ""
replace cRR_CI = ///
    strtrim(string(cRR,   "%9.3f")) + " (" + ///
    strtrim(string(cCI_l, "%9.3f")) + " to " + ///
    strtrim(string(cCI_u, "%9.3f")) + ")" ///
    if !missing(cRR, cCI_l, cCI_u)

* Crude model: p-value
gen str8 cP = ""
replace cP = "<0.001" if cPv < 0.001 & !missing(cPv)
replace cP = strtrim(string(cPv, "%9.3f")) ///
    if cPv >= 0.001 & !missing(cPv)

* Adjusted model: Point Estimates (95% Confidence Interval)
gen str40 aRR_CI = ""
replace aRR_CI = ///
    strtrim(string(aRR,   "%9.3f")) + " (" + ///
    strtrim(string(aCI_l, "%9.3f")) + " to " + ///
    strtrim(string(aCI_u, "%9.3f")) + ")" ///
    if !missing(aRR, aCI_l, aCI_u)

* Adjusted model: p-value
gen str8 aP = ""
replace aP = "<0.001" if aPv < 0.001 & !missing(aPv)
replace aP = strtrim(string(aPv, "%9.3f")) ///
    if aPv >= 0.001 & !missing(aPv)

****************************************************
* 7) Display and Save
****************************************************
order exposure cRR_CI cP aRR_CI aP
keep exposure cRR_CI cP aRR_CI aP
list exposure cRR_CI cP aRR_CI aP, noobs abbreviate(30) sep(0)

export excel using "`write_file'", sheet("Risk Ratio") first(varlabels) replace


log close
exit
