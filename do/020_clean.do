****************************************************
* 02_clean.do
* Role: Format and save data into an analyzable dataset
* * df00.dta -> df01_clean.dta
****************************************************

* 0) Log
cap log close
log using "$LOG\log_020_clean.smcl", replace

* 1) Input Data Files and Output Data Files
local read_file  "$RAW\df00.dta"
local write_file "$CLEAN\df01.dta"

use "`read_file'", clear

****************************************************
* 2) ID Check
****************************************************

* Is the `patient_id` missing?
// If there are any missing values, stop here
count if missing(id)
drop if id==""
assert id!=""

* Is the `patient_id` unique?
// Duplicates will cause subsequent analysis to fail.
// If there are duplicate IDs, stop here
isid id

****************************************************
* 3) Trimming a string
****************************************************
// Since CSV files may contain extra spaces, remove them first.
// If a string variable can be converted to a number, convert it to a number.
quietly ds, has(type string)
local strings `r(varlist)'
foreach v of local strings {
	replace `v' = strtrim(`v') if !missing(`v')
	cap noisily destring `v', replace
}


****************************************************
* 4) Adding variable labels (as Japanese)
****************************************************
label variable no           "No"
label variable id           "症例ID"
label variable age          "年齢"
label variable sex          "性別"
label variable purpose      "留置目的"
label variable height       "身長cm"
label variable weight       "体重kg"
label variable bmi          "BMI"
label variable bmi_cat1     "BMI 4分類"
label variable bmi_cat2     "BMI 8分類"
label variable wbc          "WBC"
label variable neu          "好中球数"
label variable crp          "CRP"
label variable plt          "PLT"
label variable ptinr        "PT-INR"
label variable inout        "外来/入院"
label variable succ         "成功 一次/二次"
label variable bv_lr        "穿刺血管 左右"
label variable bv_posi      "穿刺血管 部位"
label variable bv_lrposi    "穿刺血管 部位左右"
label variable poc_posi     "ポケット作成部位"
label variable port_lock    "ポート固定"
label variable guide        "使用ガイド"
label variable cath_posi    "カテーテル先端位置"
label variable cath_tip     "カテーテル先端形状"
label variable time         "手技時間"
label variable adevent      "合併症"
label variable antibact     "抗菌薬使用"
label variable anticoa      "抗凝固薬使用"
label variable anticoa_stop "抗凝固薬使用・休薬"
label variable antiplt      "抗血小板薬使用"
label variable antiplt_stop "抗血小板薬使用・休薬"
label variable beva         "ベバシズマブ使用歴"

****************************************************
* 5) Adding value labels for categorical variables (as Japanese)
****************************************************
* 性別
recode sex (2=0) 
label define sex 0 "Female" 1 "Male", replace
label values sex sex

* purpose
recode purpos (1=0) (2=1)
label define purpose 0 "抗がん剤" 1 "栄養"
label values purpose purpose

* bmi_cat1
label define bmi_cat1 ///
    1 "<18.5" ///
    2 "18.5-<25" ///
    3 "25-<30" ///
    4 ">=30"
label values bmi_cat1 bmi_cat1

* bmi_cat2
recode bmi_cat2 (1.1=1) (1.2=2) (1.3=3) (2=4) (3=5) (4.1=6) (4.2=7) (4.3=8)
label define bmi_cat2 ///
    1 "<16" ///
    2 "16-<17" ///
    3 "17-<18.5" ///
    4 "18.5-<25" ///
    5 "25-<30" ///
    6 "30-<35" ///
    7 "35-<40" ///
    8 ">=40"
label values bmi_cat2 bmi_cat2

* inout
recode inout (1=0) (2=1)
label define inout 0 "外来" 1 "入院"
label values inout inout

* succ
recode succ (1=0) (2=1)
label define succ 0 "一次成功" 1 "二次成功"
label values succ succ

* 穿刺血管：側性
label define bv_lr ///
    1 "左" ///
    2 "右"
label values bv_lr bv_lr

* 穿刺血管
label define bv_posi ///
    1 "内頸" ///
    2 "鎖骨下" ///
    3 "尺側皮静脈" ///
    4 "上腕"
label values bv_posi bv_posi

* 全穿刺血管
label define bv_lrpo ///
    11 "左内頸" ///
    12 "左鎖骨下" ///
    13 "左尺側皮静脈" ///
    14 "左上腕" ///
    21 "右内頸" ///
    22 "右鎖骨下" ///
    23 "右尺側皮静脈" ///
    24 "右上腕"
label values bv_lrposi bv_lrpo

* ポケット作成部位
label define poc_posi ///
    1   "前胸部" ///
    2   "上腕外側" ///
    3   "上腕内側" ///
    4   "前腕" ///
    999 "その他"
label values poc_posi poc_posi

* 使用ガイド
label define guide ///
    1 "造影" ///
    2 "US"
label values guide guide

* カテーテル先端位置
label define cath_po ///
    1 "Zone A" ///
    2 "Zone B" ///
    3 "Zone C"
label values cath_posi cath_po

* カテーテル先端形状
label define cath_tip ///
    1 "open" ///
    2 "closed"
label values cath_tip cath_tip

* 術前後抗生剤
label define antibact ///
    1 "前" ///
    2 "前後" ///
    3 "無"
label values antibact antibact

*--------------------------------------------------
* Binary variables (yes/no): Standardized to 0 = no, 1 = yes
*--------------------------------------------------

label define ny 0 "no" 1 "yes", replace

label values port_lock     ny
label values adevent       ny
label values anticoa       ny
label values anticoa_stop  ny
label values antiplt       ny
label values antiplt_stop  ny
label values beva          ny


****************************************************
* 6)　Sanity Check
****************************************************
* Checking Variable Types
des

* Verify that the gender is also 0 or 1. If it is anything else, stop.
assert sex==0 | sex==1

* Age: Acceptable range: 18–120
gen byte age_outlier = (age < 18 | age > 120) if !missing(age)
label variable age_outlier "Age out of plausible range (18-120)"
tab age_outlier, missing
su age if age_outlier == 1

quietly count if age_outlier == 1
if r(N) == 0 drop age_outlier
else summarize age if age_outlier == 1


****************************************************
* 7) Identifying Missing Data
****************************************************
* Checking the number of missing values and confirming their presence
misstable summarize

****************************************************
* 8) Correcting Incorrect Input Values
* Omitted from the published code because it contains personal information
****************************************************
/* Omitted */

****************************************************
* 9) Save
****************************************************

compress
label data "after Cleaning"
save "`write_file'", replace


di "=== Clean done ==="

cap log close