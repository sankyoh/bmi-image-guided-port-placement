****************************************************
* 010_import.do
* Import the prepared Excel input and save a Stata dataset.
* input.xlsx -> df00.dta
****************************************************

* 0) Log
cap log close
log using "$LOG\log_010_import.smcl", replace

* 1) Input Data Files and Output Data Files
local read_file  "$RAW/input.xlsx"
local write_file "$RAW/df00.dta"
local import_excel_ops "cellrange(A2) clear firstrow"

* 2) Import the first worksheet; row 2 contains variable names.
import excel using "`read_file'", `import_excel_ops'

* 3) Sanity Check
// Purpose: To verify that the data is not corrupted
describe  // Is the variable type correct?
count     // Is the number of lines as expected?

di "Sanity Check Lv1 completed (no modification applied)"

* 4) Save as RAW data
compress
label data "RAW data"
save "`write_file'", replace

di "=== Import done ==="

log close