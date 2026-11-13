# Codebook

This concise codebook describes the variables used in the BMI analysis of image-guided port placement. The tables below describe the **input data**. Recoding and derived variables used in the analysis are documented at the end.

## Basic characteristics and BMI

| Variable | Description | Unit or input codes |
| --- | --- | --- |
| `no` | Number | — |
| `id` | Case ID | String identifier |
| `age` | Age | Years |
| `sex` | Sex | 1=Male, 2=Female |
| `purpose` | Purpose of port placement | 1=Anticancer treatment, 2=Nutritional support |
| `height` | Height | cm |
| `weight` | Weight | kg |
| `bmi` | Body mass index (BMI) | kg/m² |
| `bmi_cat1` | BMI in four categories | See [BMI categories](#bmi-categories) |
| `bmi_cat2` | BMI in eight categories | See [BMI categories](#bmi-categories) |

## Laboratory measurements

| Variable | Description | Unit |
| --- | --- | --- |
| `wbc` | White blood cell count (WBC) | /µL |
| `neu` | Neutrophil count | /µL |
| `crp` | C-reactive protein (CRP) | mg/dL |
| `plt` | Platelet count (PLT) | 10⁴/µL |
| `ptinr` | PT-INR | Unitless |

## Procedure characteristics and outcomes

| Variable | Description | Unit or input codes |
| --- | --- | --- |
| `inout` | Outpatient or inpatient status at port placement | 1=Outpatient, 2=Inpatient |
| `succ` | Success category for port placement | 1=Primary success, 2=Secondary success |
| `bv_lr` | Side of the vessel at the first puncture | 1=Left, 2=Right |
| `bv_posi` | Vessel at the first puncture | 1=Internal jugular vein, 2=Subclavian vein, 3=Basilic vein, 4=Brachial vein |
| `bv_lrposi` | Site and side of punctured vessels | 11=Left internal jugular, 12=Left subclavian, 13=Left basilic, 14=Left brachial<br>21=Right internal jugular, 22=Right subclavian, 23=Right basilic, 24=Right brachial |
| `poc_posi` | Port pocket location | 1=Anterior chest, 2=Lateral upper arm, 3=Medial upper arm, 4=Forearm, 999=Other |
| `port_lock` | Port fixation | 0=No, 1=Yes |
| `guide` | Imaging guidance | 1=Contrast imaging, 2=Ultrasound (US) |
| `cath_posi` | Catheter tip position | 1=Zone A, 2=Zone B, 3=Zone C |
| `cath_tip` | Catheter tip configuration | 1=open, 2=closed |
| `time` | Procedure duration (from local anesthesia to wound closure) | Minutes |
| `adevent` | Complications during port placement | 0=No, 1=Yes |

## Medications

| Variable | Description | Input codes |
| --- | --- | --- |
| `antibact` | Antibiotic use before and after the procedure | 1=Before, 2=Before and after, 3=None |
| `anticoa` | Anticoagulant use | 0=No, 1=Yes |
| `anticoa_stop` | Interruption of anticoagulant therapy | 0=No, 1=Yes |
| `antiplt` | Antiplatelet use | 0=No, 1=Yes |
| `antiplt_stop` | Interruption of antiplatelet therapy | 0=No, 1=Yes |
| `beva` | Bevacizumab use within 30 days before port placement | 0=No, 1=Yes |

## BMI categories

BMI is measured in kg/m². Category intervals follow the labels in the analysis code and use exclusive upper bounds.

### `bmi_cat1` (four categories)

Input and analysis codes are identical. The reference category in the analysis is 2.

| Code | BMI range |
| --- | --- |
| 1 | BMI < 18.5 |
| 2 | 18.5 ≤ BMI < 25 |
| 3 | 25 ≤ BMI < 30 |
| 4 | BMI ≥ 30 |

### `bmi_cat2` (eight categories)

Input codes are recoded to 1–8 for analysis. The reference category in the analysis is 4.

| Input code | Analysis code | BMI range |
| --- | --- | --- |
| 1.1 | 1 | BMI < 16 |
| 1.2 | 2 | 16 ≤ BMI < 17 |
| 1.3 | 3 | 17 ≤ BMI < 18.5 |
| 2 | 4 | 18.5 ≤ BMI < 25 |
| 3 | 5 | 25 ≤ BMI < 30 |
| 4.1 | 6 | 30 ≤ BMI < 35 |
| 4.2 | 7 | 35 ≤ BMI < 40 |
| 4.3 | 8 | BMI ≥ 40 |

## Variable processing for analysis

In addition to recoding the eight BMI categories above, `do/020_clean.do` performs the following recoding.

| Variable | Input codes | Analysis codes |
| --- | --- | --- |
| `sex` | 1=Male, 2=Female | 1=Male, 0=Female |
| `purpose` | 1=Anticancer treatment, 2=Nutritional support | 0=Anticancer treatment, 1=Nutritional support |
| `inout` | 1=Outpatient, 2=Inpatient | 0=Outpatient, 1=Inpatient |
| `succ` | 1=Primary success, 2=Secondary success | 0=Primary success, 1=Secondary success |

`do/040_DesStat.do` creates the following derived variables for descriptive statistics.

| Variable | Definition |
| --- | --- |
| `anticoa_des` | 1 if anticoagulant use is present (`anticoa=1`) and therapy is not interrupted (`anticoa_stop=0`); 0 otherwise |
| `antiplt_des` | 1 if antiplatelet use is present (`antiplt=1`) and therapy is not interrupted (`antiplt_stop=0`); 0 otherwise |

The original variable table does not define custom codes for missing values.

