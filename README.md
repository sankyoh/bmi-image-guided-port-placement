# Procedural outcomes of image-guided central venous access port placement across the body mass index spectrum: a post hoc analysis of a prospective multicenter registry

This repository provides Stata code for a post hoc analysis of a prospective multicenter registry examining the association between BMI and procedural outcomes of image-guided central venous access port placement. The title above is the manuscript title before peer review.

The repository contains analysis code and codebooks. Patient-level data are not included.

## Analysis overview

BMI is analyzed as both a categorical and a continuous variable in relation to the following outcomes.

| Outcome | Variable | Definition used in the analysis |
| --- | --- | --- |
| Secondary success | `succ` | 0=Primary success, 1=Secondary success |
| Complications during port placement | `adevent` | 0=No, 1=Yes |
| Procedure duration | `time` | Time from local anesthesia to wound closure (minutes) |

The main analyses include descriptive statistics by BMI category, risk ratios estimated using modified Poisson regression with robust standard errors, mean differences in procedure duration estimated using linear regression, and visualization of associations using restricted cubic splines (RCS). Analyses by BMI category use unadjusted and adjusted models; RCS analyses use adjusted models. Effect estimates or predicted values are reported with 95% confidence intervals.

The reference category for both the four-category and eight-category BMI classifications is 18.5 ≤ BMI < 25. The categorical analysis of procedure duration uses the four-category classification, while RCS analyses use continuous BMI with four knots.

Adjustment variables are age, sex, purpose of port placement, outpatient or inpatient status, antibiotic use, anticoagulant use, antiplatelet use, and bevacizumab use within 30 days before port placement. See the codebooks for variable coding and the individual analysis files for how variables enter each model.

## File structure

| File | Description |
| --- | --- |
| [master.do](master.do) | Runs the workflow from data import through analysis |
| [000_config.do](000_config.do) | Configures the project directory and file locations |
| [do/010_import.do](do/010_import.do) | Imports Excel data |
| [do/020_clean.do](do/020_clean.do) | Checks IDs, assigns variable labels, and recodes variables |
| [do/040_DesStat.do](do/040_DesStat.do) | Produces descriptive statistics by the four BMI categories |
| [do/200_riskratio_bmi_cat.do](do/200_riskratio_bmi_cat.do) | Estimates risk ratios for secondary success and complications using the four- and eight-category BMI classifications |
| [do/210_time_bmi_cat.do](do/210_time_bmi_cat.do) | Estimates mean differences in procedure duration using the four BMI categories |
| [do/300_RCS_bmi.do](do/300_RCS_bmi.do) | Plots adjusted predicted risks of secondary success and complications across BMI |
| [do/310_RCS_time_bmi.do](do/310_RCS_time_bmi.do) | Plots adjusted predicted procedure duration across BMI |
| [Codebook.md](Codebook.md) | Concise codebook in English |
| [Codebook_jp.md](Codebook_jp.md) | Concise codebook in Japanese |
| [README.md](README.md) | This documentation in English |
| [README_jp.md](README_jp.md) | Documentation in Japanese |
| [LICENSE](LICENSE) | MIT license text |
| [CITATION.cff](CITATION.cff) | Citation metadata for the analysis code |

## Software and platform requirements

- A Stata environment that supports `version 19.5`, such as StataNow 19.5, is required. Some analysis files specify this version. See the [official Stata manual](https://www.stata.com/manuals/pversion.pdf) for an explanation of version control.
- The code uses official Stata commands, including `dtable` and `makespline`. It contains no installation steps for additional packages.
- File paths are written for Windows. On other operating systems, review and adjust path separators and related settings as needed.

## Data and prerequisites for reproduction

To protect personal information, the input Excel file, patient-level Stata datasets, and execution logs are not publicly shared. The public code alone cannot reproduce the numerical results of the manuscript. Running the code requires separately obtaining input data that you are authorized to use.

Provide the 33 variables listed in the codebook using the **input codes**. Using data that have already been recoded for analysis may result in recoding being applied twice. The `id` variable is expected to contain unique, nonmissing string identifiers.

The public version of `do/020_clean.do` omits corrections tied to individual records. To reproduce the results dated 19 September 2026, use a private copy of the input and verify that the approved correction to the complication outcome for that analysis is reflected. Apply it only if it is missing. The platelet count and C-reactive protein corrections dated 26 September belong to a later data version and are excluded from this reproduction. Keep the correction record and the prepared input private.

## Running the analysis

1. Make a separate local working copy of the repository to keep the original input and any existing results intact. Create `data_raw`, `data_clean`, `log`, and `output` in the root of that copy.
2. Save the prepared private workbook as `data_raw/input.xlsx`. By default, the import reads the first worksheet, with variable names in row 2 and data starting in row 3. Match the variable names and input codes in the codebook. If the workbook layout differs, adjust the import options in the working copy of `do/010_import.do`.
3. In Stata, change the working directory to the root of the working copy and run `master.do`. The configuration uses the current directory; there is no path to edit in `000_config.do`.

   ```stata
   cd "C:/analysis/port-bmi"
   do master.do
   ```

`master.do` runs the workflow in this order: import → cleaning → descriptive statistics → analyses by BMI category → RCS analyses.

## Main outputs

Analysis results are saved in `output`, and execution logs are saved in `log`.

| Output file | Description |
| --- | --- |
| `Table1.xlsx` | Descriptive statistics by the four BMI categories |
| `Risk_Ratio_bmi_cat_succ.xlsx` | Risk ratios for secondary success |
| `Risk_Ratio_bmi_cat_AE.xlsx` | Risk ratios for complications during port placement |
| `Mean_Time_Difference_bmi_cat.xlsx` | Mean differences in procedure duration |
| `RCS_bmi_succ.dta` / `.gph` / `.png` | Predicted values and curve for secondary success |
| `RCS_bmi_AE.dta` / `.gph` / `.png` | Predicted values and curve for complications during port placement |
| `RCS_time_bmi.dta` / `.gph` / `.png` | Predicted values and curve for procedure duration |

The workflow also creates intermediate datasets at `data_raw/df00.dta` and `data_clean/df01.dta`. Rerunning the code overwrites data, logs, and output files with the same names.

Keep input data, intermediate datasets, and execution logs private. Review the contents of any tables or figures before adding them for public release.

## Verification status, citation, and license

The public scripts were run in a separate working copy with StataNow 19.5 on Windows. For the 19 September analysis, model sample sizes, point estimates, and 95% confidence intervals matched the BMI four-category results at the precision reported. The predictions and 95% confidence intervals for all three spline plots matched the archived numerical outputs at every BMI grid point. The numerical reference was retained with the 26 September outputs; the accompanying PNGs were pixel-identical to the 19 September figures.

Release: [v1.0.0](https://github.com/sankyoh/bmi-image-guided-port-placement/releases/tag/v1.0.0) (13 November 2026).

If you use this analysis code, please cite it using the information in [CITATION.cff](CITATION.cff).

The code and documentation in this repository are licensed under the [MIT License](LICENSE).
