****************************************************
* 310_RCS_time_bmi.do
* Purpose: To evaluate and plot the relationship between the continuous variable BMI and procedure time
*       using restricted cubic splines (RCS).
*
* Method: Linear regression + robust standard error
* Y-axis: Predicted procedure time (minutes), adjusted for covariates
* X-axis: BMI (kg/m^2)
*
* Input: $CLEAN\df01.dta
* Output: $OUT\RCS_time_bmi.dta
*       $OUT\RCS_time_bmi.png
****************************************************

version 19.5

*--------------------------------------------------
* Argument Processing
*
* Example of usage:
*   do 310_RCS_time_bmi.do
*   do 310_RCS_time_bmi.do suffix(main)
*
* If `suffix` is specified,
* "_suffix" is appended to the end of the output filename.
*--------------------------------------------------
local 0 `", `0'"'
syntax [, SUFFIX(string)]

local fsuffix ""
if `"`suffix'"' != "" {
    local fsuffix "_`suffix'"
}

****************************************************
* 1) Preparing for the analysis
****************************************************

* Analytical variables
local expv bmi
local outv time

* Adjustment factors (same variables as in 210_time_bmi_cat.do)
local covvars age sex purpose inout antibact anticoa antiplt beva

* Specifying in the regression model
* Enter "age" as a continuous variable and the others as categorical variables.
local covterms c.age i.sex i.purpose i.inout ///
    i.antibact i.anticoa i.antiplt i.beva

* 1) Input Data Files and Output Data Files
local read_file   "$CLEAN\df01.dta"
local write_file  "$OUT\RCS_time_bmi`fsuffix'.dta"
local write_graph "$OUT\RCS_time_bmi`fsuffix'"

* Log
capture log close log310
log using "$LOG\log_310_RCS_time_bmi`fsuffix'.smcl", ///
    name(log310) replace

noi display as text "Outcome : `outv'"
noi display as text "Exposure: `expv'"
noi display as text "Suffix  : `fsuffix'"

use "`read_file'", clear

****************************************************
* 2) Defining the Analysis Subject and Verifying the Data
****************************************************

* Verify that the required variables exist as numeric variables.
local required `outv' `expv' `covvars'
foreach v of local required {
    capture confirm numeric variable `v'
    local rc = _rc
    if `rc' {
        noi display as error ///
            "Required numeric variable `v' was not found."
        capture log close log310
        exit `rc'
    }
}

* Define the study population for which the outcome, exposure, and all adjustment factors are observed.
* Use the same study participants for knot estimation and regression analysis.
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
    capture log close log310
    exit 2000
}

* If the procedure time is a negative value, the process will stop because it is highly likely to be an input error.
quietly count if `touse' & `outv' < 0
local N_negative = r(N)
if `N_negative' > 0 {
    noi display as error ///
        "`outv' contains `N_negative' negative value(s)."
    capture log close log310
    exit 459
}

* Cases with a duration of 0 minutes are not excluded, but a warning is displayed prompting the user to verify the entry.
quietly count if `touse' & `outv' == 0
local N_zero = r(N)
if `N_zero' > 0 {
    noi display as error ///
        "Warning: `outv' contains `N_zero' zero value(s)."
}

* If the BMI is 0 or less, it is considered an input error, and the analysis is terminated.
quietly count if `touse' & `expv' <= 0
local N_bad_bmi = r(N)
if `N_bad_bmi' > 0 {
    noi display as error ///
        "`expv' contains `N_bad_bmi' nonpositive value(s)."
    capture log close log310
    exit 459
}

****************************************************
* 3) Creating an RCS Base
****************************************************

/*
Place 4 knots at Harrell's recommended percentiles (5th, 35th, 65th, 95th).
The knot positions are determined based on participants 
for whom all outcome, exposure, and adjustment variables were observed.
*/

makespline rcs `expv' if `touse', ///
    knots(4) harrell norescalevars basis(bmi_rcs)

* Save the knot positions so that the same RCS basis can be regenerated later.
matrix RCS_knots = r(knots)
local rcsvars `r(basisnames1)'
local nknots = colsof(RCS_knots)
local nbasis : word count `rcsvars'

* The first ground state is the linear component, and the second ground state and higher are the nonlinear components.
local linear : word 1 of `rcsvars'
local nonlinear : list rcsvars - linear

noi display as text "Number of knots       = `nknots'"
noi display as text "Number of RCS terms   = `nbasis'"
noi display as text "RCS terms             = `rcsvars'"
matrix list RCS_knots

if `nknots' != 4 {
    noi display as error "Four RCS knots were not generated."
    capture log close log310
    exit 459
}

if `"`nonlinear'"' == "" {
    noi display as error "Nonlinear RCS terms were not generated."
    capture log close log310
    exit 459
}

****************************************************
* 4) Adjusted linear regression including RCS
****************************************************

/*
Estimate the relationship between BMI and average procedure time using linear regression.
To account for heteroscedasticity in procedure times,
robust standard errors are used.

Since robust standard errors do not minimize the influence of extreme procedure times
on the coefficients, outliers and points of concern should be identified separately.
*/

regress `outv' `rcsvars' `covterms' if `touse', vce(robust)

* Joint Wald test for the overall association between BMI and procedure duration
testparm `rcsvars'
local p_overall = r(p)

* Joint Wald test to determine whether the relationship with BMI deviates from a linear trend
testparm `nonlinear'
local p_nonlin = r(p)

display as text "P for overall association = " ///
    as result %6.4f `p_overall'
display as text "P for nonlinearity       = " ///
    as result %6.4f `p_nonlin'

* Identify the observations that are the subject of the estimation.
generate byte estimation_sample = e(sample)

quietly count if estimation_sample
local N_estimation = r(N)
if `N_estimation' != `N_analysis' {
    noi display as error ///
        "Complete-case N (`N_analysis') and e(sample) N " ///
        "(`N_estimation') differ."
    noi display as error ///
        "Knots and regression must use the same analysis sample."
    capture log close log310
    exit 459
}

* The graph should show the range from the minimum to the maximum BMI values in the sample.
quietly summarize `expv' if estimation_sample, meanonly
local bmi_low  = r(min)
local bmi_high = r(max)
local ngrid    = 101
local neval    = `ngrid' + `nknots'

****************************************************
* 5) Calculation of the adjusted estimated procedure time for each BMI score
****************************************************

/*
Duplicate each subject in the estimated sample at 101 BMI evaluation points and
4 knot locations.

Regenerate the RCS basis at each evaluation point, while keeping the other covariates
as observed for each subject. Then, average the predicted values
across all subjects to obtain the adjusted prediction times.
*/
keep if estimation_sample

generate long __id = _n
expand `neval'
bysort __id: generate int __grid = _n

* Create 101 evaluation points at equal intervals between the minimum and maximum BMI values.
generate double bmi_grid = ///
    `bmi_low' + (`bmi_high' - `bmi_low') * ///
    (__grid - 1) / (`ngrid' - 1) if __grid <= `ngrid'

* To obtain accurate predictions at the knots, the knot positions are also included.
forvalues j = 1/`nknots' {
    replace bmi_grid = RCS_knots[1, `j'] ///
        if __grid == `ngrid' + `j'
}

* Substitute the exposure BMI for each assessment point.
replace `expv' = bmi_grid

* Regenerate the RCS basis using the same knot that was saved.
makespline rcs `expv', knotsmat(RCS_knots) ///
    norescalevars basis(bmi_rcs) replace

/*
Calculate the average of the linear predicted values (= predicted average procedure time)
at each BMI score across all participants.

The `noesample` option is required to include the replicate rows created
after model estimation in the margins calculation.
*/
margins, over(__grid) predict(xb) noesample

* Generate data for the point estimates, standard errors, and 95% confidence intervals of the margins.
matrix M = r(table)'
local N_margin_rows = rowsof(M)

if `N_margin_rows' != `neval' {
    noi display as error ///
        "margins returned `N_margin_rows' rows; `neval' were expected."
    capture log close log310
    exit 459
}

clear
svmat double M, names(col)

rename b  predicted_time
rename se time_se
rename ll ci_lb
rename ul ci_ub

* If a negative predicted mean occurs, the user should be prompted to verify the model's fit and extrapolation range.
quietly count if predicted_time < 0 & !missing(predicted_time)
local N_negative_prediction = r(N)
if `N_negative_prediction' > 0 {
    noi display as error ///
        "Warning: `N_negative_prediction' predicted time value(s) are negative."
}

/*
The original 95% CI (ci_lb, ci_ub) is preserved without change.
Since procedure duration cannot be negative, only the lower limit of the CI for graphing purposes
is restricted to 0 if it is less than 0. No restriction is placed on the upper limit.
*/
generate double ci_lb_plot = max(ci_lb, 0) if !missing(ci_lb)
generate double ci_ub_plot = ci_ub if !missing(ci_ub)

* Reconstruct the corresponding BMI score based on the line number in "margins."
generate int grid_index = _n
generate double bmi_grid = ///
    `bmi_low' + (`bmi_high' - `bmi_low') * ///
    (grid_index - 1) / (`ngrid' - 1) if grid_index <= `ngrid'

* Identify the row containing the knot position and restore its BMI value.
generate byte is_knot = 0
forvalues j = 1/`nknots' {
    replace bmi_grid = RCS_knots[1, `j'] ///
        if grid_index == `ngrid' + `j'
    replace is_knot = 1 if grid_index == `ngrid' + `j'
}

sort bmi_grid is_knot

keep bmi_grid predicted_time time_se ci_lb ci_ub ///
    ci_lb_plot ci_ub_plot is_knot
order bmi_grid predicted_time time_se ci_lb ci_ub ///
    ci_lb_plot ci_ub_plot is_knot

label variable bmi_grid ///
    "BMI (kg/m^2)"
label variable predicted_time ///
    "Adjusted predicted procedure time (min)"
label variable time_se ///
    "Standard error of adjusted predicted procedure time"
label variable ci_lb ///
    "Lower 95% CI"
label variable ci_ub ///
    "Upper 95% CI"
label variable ci_lb_plot ///
    "Display-truncated lower 95% CI"
label variable ci_ub_plot ///
    "Upper 95% CI used for graph"
label variable is_knot ///
    "RCS knot position"

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
* 7) Automatically set the vertical axis range in 5-minute increments
****************************************************

* Round the minimum and maximum values of the 95% CI displayed to the nearest 5-minute interval.
* For this dataset, the range is 20–40 minutes, with 5-minute intervals on the scale.
quietly summarize ci_lb_plot, meanonly
local y_min = 5 * floor(r(min) / 5)

quietly summarize ci_ub_plot, meanonly
local y_max = 5 * ceil(r(max) / 5)

* Even if the CI is very narrow, ensure that the display width is at least 5 minutes.
if `y_max' <= `y_min' {
    local y_max = `y_min' + 5
}

noi display as text ///
    "Y-axis range = `y_min' to `y_max' minutes (5-minute intervals)"

****************************************************
* 8) Drawing and Saving RCS
****************************************************

twoway ///
    (rarea ci_lb_plot ci_ub_plot bmi_grid, sort ///
        fcolor(eltblue%60) lcolor(navy%40) lwidth(vthin)) ///
    (line predicted_time bmi_grid, sort ///
        lcolor(navy) lwidth(medthick)) ///
    (scatter predicted_time bmi_grid if is_knot == 1, ///
        msymbol(O) mcolor(navy) msize(medsmall)), ///
    xtitle("BMI (kg/m{superscript:2})") ///
    ytitle("Adjusted predicted procedure time (min)") ///
    yscale(range(`y_min' `y_max')) ///
    xlabel(, grid glcolor(gs15) glpattern(solid) glwidth(vthin)) ///
    ylabel(`y_min'(5)`y_max', format(%4.0f) angle(horizontal) ///
        grid glcolor(gs15) glpattern(solid) glwidth(vthin)) ///
    legend(off) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(RCS_time_bmi, replace) ///
    note("P overall `p_overall_txt'; P nonlinear `p_nonlin_txt'" , ///
        size(small))

save "`write_file'", replace
graph save   "`write_graph'.gph", replace
graph export "`write_graph'.png", replace width(2400) 

capture log close log310
