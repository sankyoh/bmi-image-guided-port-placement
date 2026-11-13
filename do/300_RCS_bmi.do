****************************************************
* 300_RCS_bmi.do
* Role: Using the continuous variable BMI as an exposure, plot the risk of secondary success using RCS.
* df01.dta -> RCS_bmi.dta / RCS_bmi.png
****************************************************

*--------------------------------------------------
* Processing Arguments
*
* Example of usage:
*   do 300_RCS_bmi.do
*   do 300_RCS_bmi.do outcome(succ) suffix(succ)
*
* Notes:
* An "_" (underscore) is automatically prepended to the filename suffix.
* The expected outcome is `adevent succ` (or just `succ` if omitted).
* Any suffix is allowed, but if omitted, it defaults to the same value as the outcome.
*--------------------------------------------------

local 0 `", `0'"'
syntax [, OUTCOME(string) SUFFIX(string) XTITLE(string)]

// outcome: Event to analyze
// suffix: File suffix

qui {
noi display as text "outcome: `outv'"
noi display as text "suffix : `suffix'"
noi display as text "xtitle : `xtitle'"
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

if `"`xtitle'"' == "" {
    local xtitle "secondary success"
} 

* 0) Log
cap log close
log using "$LOG\log_300_RCS_bmi`suffix'.smcl", replace

* 1) Input Data Files and Output Data Files
local read_file   "$CLEAN\df01.dta"
local write_file  "$OUT\RCS_bmi`suffix'.dta"
local write_graph "$OUT\RCS_bmi`suffix'" // note: no file extension

use "`read_file'", clear

****************************************************
* 2) Setting Variables
****************************************************

local expv  bmi
local outv  `outcome'
local covs  age sex purpose inout antibact anticoa antiplt beva

/******************************************************************
Objective:
    To evaluate the relationship between BMI and the risk of secondary success
    using restricted cubic splines
    (RCS).

Variables:
    bmi        : Explanatory variable (continuous)
    succ       : Response variable (0 = primary success, 1 = secondary success)
    local covs : Set of adjustment variables
RCS vertical axis:
    Expected probability of secondary success (undesirable outcome) occurring
    
RCS horizontal axis:
    BMI
******************************************************************/

****************************************************
* 3) Creating an RCS base
****************************************************

/*
Place 4 knots at Harrell's recommended percentiles (5th, 35th, 65th, 95th).
The knot positions are determined based on participants 
for whom all outcome, exposure, and adjustment variables were observed.
*/

misstable sum
makespline rcs `expv', ///
    knots(4) harrell norescalevars basis(bmi_rcs)

* Save the knot positions so that the same RCS basis can be regenerated later
matrix RCS_knots = r(knots)
local rcsvars `r(basisnames1)'
local nknots = colsof(RCS_knots)

* The first ground state corresponds to the linear component, 
* and the second ground state and beyond correspond to the nonlinear components.
local linear : word 1 of `rcsvars'
local nonlinear : list rcsvars - linear

matrix list RCS_knots

****************************************************
* 4) Adjusted Poisson regression
****************************************************

* Estimate the risk of outcome=1 using a modified Poisson regression with a log-link.

poisson `outv' `rcsvars' `covs', vce(robust)

* Overall Wald test for the association between BMI and outcomes
testparm `rcsvars'
local p_overall = r(p)

* Wald test for nonlinear components
testparm `nonlinear'
local p_nonlin = r(p)

display as text "P for overall association = " ///
    as result %6.4f `p_overall'
display as text "P for nonlinearity       = " ///
    as result %6.4f `p_nonlin'

* Identify the observations that were the subject of the estimation
generate byte estimation_sample = e(sample)

* The graph should show the range from the minimum to the maximum BMI values in the sample.
quietly summarize `expv' if estimation_sample, meanonly
local bmi_low  = r(min)
local bmi_high = r(max)
local ngrid    = 101
local neval    = `ngrid' + `nknots'

****************************************************
* 5) Calculate the adjusted risk for each BMI category
****************************************************

/*
Clone each subject in the estimated sample at 101 BMI evaluation points and
knot location evaluation points.
Regenerate the RCS basis at each evaluation point, and retain the observed values
for all other covariates for each subject.
*/
keep if estimation_sample

generate long __id = _n
expand `neval'
bysort __id: generate int __grid = _n

generate double bmi_grid = ///
    `bmi_low' + (`bmi_high' - `bmi_low') * ///
    (__grid - 1) / (`ngrid' - 1) if __grid <= `ngrid'

* To obtain accurate predictions at the knots, the knot locations are also included as evaluation points.
forvalues j = 1/`nknots' {
    replace bmi_grid = RCS_knots[1, `j'] ///
        if __grid == `ngrid' + `j'
}

* Convert the exposure BMI into a score
replace `expv' = bmi_grid

* Use the saved knots to regenerate the RCS basis corresponding to the evaluation points
makespline rcs `expv', knotsmat(RCS_knots) ///
    norescalevars basis(bmi_rcs) replace

/*
Calculate the average predicted risk across all participants for each BMI score.
The `noesample` option is required to include the observations duplicated above in the calculation.
*/
margins, over(__grid) predict(n) noesample

* Convert the point estimates and 95% confidence intervals for margins into data
matrix M = r(table)'
clear
svmat double M, names(col)

rename b  risk
rename se risk_se
rename ll ci_lb
rename ul ci_ub

/*
Since the 95% CI for margins is a symmetric interval calculated using the delta method,
the lower bound may be less than 0 when the risk is low and the standard error is large.
While retaining the estimated CI itself (ci_lb, ci_ub), we restrict it to the probability range of 0 to 1
solely for graphing purposes.
*/
generate double ci_lb_plot = max(ci_lb, 0) if !missing(ci_lb)
generate double ci_ub_plot = min(ci_ub, 1) if !missing(ci_ub)

generate int grid_index = _n
generate double bmi_grid = ///
    `bmi_low' + (`bmi_high' - `bmi_low') * ///
    (grid_index - 1) / (`ngrid' - 1) if grid_index <= `ngrid'

* Identify the row containing the knot and restore its position
generate byte is_knot = 0
forvalues j = 1/`nknots' {
    replace bmi_grid = RCS_knots[1, `j'] ///
        if grid_index == `ngrid' + `j'
    replace is_knot = 1 if grid_index == `ngrid' + `j'
}

sort bmi_grid is_knot

keep bmi_grid risk risk_se ci_lb ci_ub ci_lb_plot ci_ub_plot is_knot
order bmi_grid risk risk_se ci_lb ci_ub ci_lb_plot ci_ub_plot is_knot

label variable bmi_grid "BMI"
label variable risk     "Adjusted predicted risk"
label variable risk_se  "Standard error of adjusted predicted risk"
label variable ci_lb    "Lower 95% CI"
label variable ci_ub    "Upper 95% CI"
label variable ci_lb_plot "Lower 95% CI used for graph"
label variable ci_ub_plot "Upper 95% CI used for graph"
label variable is_knot  "RCS knot position"

****************************************************
* 6) Format the test results for display in a graph
****************************************************

if `p_overall' < 0.001 {
    local p_overall_txt "<0.001"
}
else {
    local p_overall_txt : display "= " %5.3f `p_overall'
}

if `p_nonlin' < 0.001 {
    local p_nonlin_txt "<0.001"
}
else {
    local p_nonlin_txt : display "= " %5.3f `p_nonlin'
}

****************************************************
* 7) Draw the RCS and save the data and image
****************************************************

twoway ///
    (rarea ci_lb_plot ci_ub_plot bmi_grid, sort ///
        fcolor(eltblue%60) lcolor(navy%40) lwidth(vthin)) ///
    (line risk bmi_grid, ///
        sort lcolor(navy) lwidth(medthick)) ///
    (scatter risk bmi_grid if is_knot == 1, ///
        msymbol(O) mcolor(navy) msize(medsmall)), ///
    xtitle("BMI (kg/m{superscript:2})") ///
    /// ytitle("Adjusted predicted risk of secondary success")
	ytitle("Adjusted predicted risk of `xtitle'") ///
    yscale(range(0)) ///
    xlabel(, grid glcolor(gs15) glpattern(solid) glwidth(vthin)) ///
    ylabel(, format(%4.2f) angle(horizontal) ///
        grid glcolor(gs15) glpattern(solid) glwidth(vthin)) ///
    legend(off) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
	name(`suffix', replace) ///
    note("P overall `p_overall_txt'; P nonlinear `p_nonlin_txt'", ///
        size(small))

save "`write_file'", replace
graph save   "`write_graph'.gph", replace
graph export "`write_graph'.png", replace width(2400) 

log close
exit
