****************************************************
* 210_time_bmi_cat.do
* Objective: To evaluate the association between the four BMI categories and procedure duration
*
* Methods: Linear regression + robust standard error
*       Output the regression coefficient as the difference in average procedure duration (minutes)
*
* Criteria: bmi_cat1 = 2 (BMI 18.5 or higher but less than 25.0)
* Input: $CLEAN\df01.dta
* Output: $OUT\Mean_Time_Difference_bmi_cat.xlsx
****************************************************

version 19.5

*--------------------------------------------------
* Processing Arguments
*
* Example of usage:
*   do 210_time_bmi_cat.do
*   do 210_time_bmi_cat.do suffix(main)
*
* Notes:
* If `suffix` is specified,
* "_suffix" is appended to the end of the filename.
*--------------------------------------------------
local 0 `", `0'"'
syntax [, SUFFIX(string)]

local fsuffix ""
if `"`suffix'"' != "" {
    local fsuffix "_`suffix'"
}

****************************************************
* 1) Preparing for the Analysis
****************************************************

* Analytical variables
local outv time
local expv bmi_cat1
local ref  2

* Adjustment variables (same variables as in 200_riskratio_bmi_cat.do)
local covvars age sex purpose inout antibact anticoa antiplt beva

* Specifying in the regression equation
* Enter "age" as a continuous variable and the others as categorical variables.
* For 0/1 variables, the regression results remain the same even if included the "i." prefix.
local covterms c.age i.sex i.purpose i.inout ///
    i.antibact i.anticoa i.antiplt i.beva

* Adjustment variables by model
local covars0                 // Crude model
local covars1 `covterms'      // Adjusted model

* Input Data Files and Output Data Files
local read_file  "$CLEAN\df01.dta"
local write_file "$OUT\Mean_Time_Difference_bmi_cat`fsuffix'.xlsx"

* Log
capture log close log210
log using "$LOG\log_210_time_bmi_cat`fsuffix'.smcl", ///
    name(log210) replace

noi display as text "Outcome : `outv'"
noi display as text "Exposure: `expv' (reference category = `ref')"
noi display as text "Suffix  : `fsuffix'"

use "`read_file'", clear

****************************************************
* 2) Review of Analysis Data
****************************************************

* Verify that the required variables exist as numeric variables.
local required `outv' `expv' `covvars'
foreach v of local required {
    capture confirm numeric variable `v'
    local rc = _rc
    if `rc' {
        noi display as error ///
            "Required numeric variable `v' was not found."
        capture log close log210
        exit `rc'
    }
}

* Since the same participants are used in both the unadjusted and adjusted analyses,
* we define the study population as those for whom the outcome, exposure, and all adjustment factors are observed.
tempvar touse
quietly generate byte `touse' = 1
foreach v of local required {
    quietly replace `touse' = 0 if missing(`v')
}

quietly count if `touse'
local N_analysis = r(N)
noi display as text "Complete-case analysis sample: N = `N_analysis'"

if `N_analysis' == 0 {
    noi display as error "No complete observations are available."
    capture log close log210
    exit 2000
}

* If the procedure time is a negative value, the process will stop because it is highly likely to be an input error.
quietly count if `touse' & `outv' < 0
local N_negative = r(N)
if `N_negative' > 0 {
    noi display as error ///
        "`outv' contains `N_negative' negative value(s)."
    capture log close log210
    exit 459
}


* Cases with a duration of 0 minutes are not excluded from the analysis, but a warning is displayed prompting the user to verify the data.
quietly count if `touse' & `outv' == 0
local N_zero = r(N)
if `N_zero' > 0 {
    noi display as error ///
        "Warning: `outv' contains `N_zero' zero value(s)."
}

* Verify that `bmi_cat1` consists of the expected four categories (1–4).
quietly count if `touse' & !inlist(`expv', 1, 2, 3, 4)
local N_badcat = r(N)
if `N_badcat' > 0 {
    noi display as error ///
        "`expv' contains `N_badcat' value(s) outside categories 1-4."
    capture log close log210
    exit 459
}

* Verify that all four BMI categories are present in the dataset.
forvalues k = 1/4 {
    quietly count if `touse' & `expv' == `k'
    local N_category = r(N)
    noi display as text ///
        "`expv' category `k': N = `N_category'"

    if `N_category' == 0 {
        noi display as error ///
            "Category `k' of `expv' is absent from the analysis sample."
        capture log close log210
        exit 459
    }
}

****************************************************
* 3) Preparing the postfile to store the results
****************************************************

tempname memhold
tempfile results

postfile `memhold' ///
    str70 exposure ///
    double cMD cCI_l cCI_u cPv ///
    double aMD aCI_l aCI_u aPv ///
    using "`results'", replace

****************************************************
* 4) Linear Regression (Robust Standard Error)
*
* Regression Coefficient = Difference in Average Procedure Time (minutes)
*   Positive value: Average procedure time is longer than that of the reference group
*   Negative value: Average procedure time is shorter than that of the reference group
*
* Using bmi_cat1 = 2 as the reference, perform unadjusted and adjusted analyses.
*
* Since heteroscedasticity is a concern in right-skewed distributions,
* robust standard errors, which are resilient to heteroscedasticity, are used for inference.
* However, since robust standard errors do not reduce the influence of outliers
* on the coefficients, outliers must be checked separately.
****************************************************

quietly levelsof `expv' if `touse', local(levels)

foreach k of local levels {

    * The reference category itself does not generate a row in the comparison results.
    if `k' != `ref' {

        * Display names for each category
        local comparison "`expv': `k' vs `ref'"
        if `k' == 1 local comparison ///
            "BMI <18.5 vs 18.5 to <25.0 kg/m^2"
        if `k' == 3 local comparison ///
            "BMI 25.0 to <30.0 vs 18.5 to <25.0 kg/m^2"
        if `k' == 4 local comparison ///
            "BMI >=30.0 vs 18.5 to <25.0 kg/m^2"

        * Initialize the macro for storing results.
        local b0  = .
        local lb0 = .
        local ub0 = .
        local pv0 = .

        local b1  = .
        local lb1 = .
        local ub1 = .
        local pv1 = .

        * m=0: Crude analysis; m=1: Adjusted analysis
        forvalues m = 0/1 {

            local modelname "crude"
            if `m' == 1 local modelname "adjusted"

            capture noisily regress `outv' ib`ref'.`expv' ///
                `covars`m'' if `touse', ///
                vce(robust)

            local rc_model = _rc
            if `rc_model' {
                noi display as error ///
                    "Linear regression failed: `modelname' model " ///
                    "(return code `rc_model')."
                postclose `memhold'
                capture log close log210
                exit `rc_model'
            }

            * Calculate the difference in average procedure time between BMI category k and reference category 2.
            capture noisily lincom `k'.`expv', level(95)

            local rc_lincom = _rc
            if `rc_lincom' {
                noi display as error ///
                    "lincom failed: `modelname' model, category `k' " ///
                    "(return code `rc_lincom')."
                postclose `memhold'
                capture log close log210
                exit `rc_lincom'
            }

            local b`m'  = r(estimate)
            local lb`m' = r(lb)
            local ub`m' = r(ub)
            local pv`m' = r(p)
        }

        post `memhold' ("`comparison'") ///
            (`b0') (`lb0') (`ub0') (`pv0') ///
            (`b1') (`lb1') (`ub1') (`pv1')
    }
}

postclose `memhold'

****************************************************
* 5) Load the results data
****************************************************

use "`results'", clear

****************************************************
* 6) Create a list of strings for the table in the paper
*    "Point estimate (95% confidence interval)" and "p-value"
****************************************************

* Crude model: Point estimates (95% confidence intervals)
generate str40 cMD_CI = ""
replace cMD_CI = ///
    strtrim(string(cMD,   "%9.3f")) + " (" + ///
    strtrim(string(cCI_l, "%9.3f")) + " to " + ///
    strtrim(string(cCI_u, "%9.3f")) + ")" ///
    if !missing(cMD, cCI_l, cCI_u)

* Crude model: p-value
generate str8 cP = ""
replace cP = "<0.001" if cPv < 0.001 & !missing(cPv)
replace cP = strtrim(string(cPv, "%9.3f")) ///
    if cPv >= 0.001 & !missing(cPv)

* Adjusted model: Point estimates (95% confidence intervals)
generate str40 aMD_CI = ""
replace aMD_CI = ///
    strtrim(string(aMD,   "%9.3f")) + " (" + ///
    strtrim(string(aCI_l, "%9.3f")) + " to " + ///
    strtrim(string(aCI_u, "%9.3f")) + ")" ///
    if !missing(aMD, aCI_l, aCI_u)

* Adjusted model: p-value
generate str8 aP = ""
replace aP = "<0.001" if aPv < 0.001 & !missing(aPv)
replace aP = strtrim(string(aPv, "%9.3f")) ///
    if aPv >= 0.001 & !missing(aPv)

****************************************************
* 7) Save as an Excel file
****************************************************

label variable exposure ///
    "BMI category comparison"
label variable cMD_CI ///
    "Crude mean difference, min (95% CI)"
label variable cP ///
    "p-value"
label variable aMD_CI ///
    "Adjusted mean difference, min (95% CI)"
label variable aP ///
    "p-value"

order exposure cMD_CI cP aMD_CI aP
keep exposure cMD_CI cP aMD_CI aP

list exposure cMD_CI cP aMD_CI aP, ///
    noobs abbreviate(40) sep(0)

export excel using "`write_file'", ///
    sheet("Mean difference") firstrow(varlabels) replace

capture log close log210
