# Question 2 — ADaM ADSL Dataset Creation

## Objective

Create an ADSL (Subject Level) dataset using SDTM source data, the `{admiral}` family of packages, and tidyverse tools.

## Task

Develop an R program to create the ADSL using the input SDTM data, the `{admiral}` family of packages, and tidyverse tools as explained in the [Pharmaverse examples — ADSL](https://pharmaverse.github.io/admiral/cran-release/articles/adsl.html) or in `{admiral}` documentation. Adjust the logic and derive additional variables as mentioned below.

The DM domain is used as the basis of the ADSL. Start by assigning `pharmaversesdtm::dm` to an `adsl` object as explained in the ADSL article.

**Input datasets:** `pharmaversesdtm::dm`, `pharmaversesdtm::vs`, `pharmaversesdtm::ex`, `pharmaversesdtm::ds`, `pharmaversesdtm::ae`

### Additional Variables

| Variable | Details |
|----------|---------|
| `AGEGR9` & `AGEGR9N` | Age grouping into the following categories: `<18`, `18 - 50`, `>50` |
| `TRTSDTM` & `TRTSTMF` | Treatment start date-time (using the first exposure record for each participant and imputing missing hours and minutes but not seconds) |
| `ITTFL` | `"Y"` / `"N"` flag identifying patients who have been randomized, i.e. where `ARM` is populated in `pharmaversesdtm::dm` |
| `LASTVLDT` | Last known alive date using any vital signs visit date, any adverse event start date, any disposition record and any exposure record |

### Detailed Specifications

| Variable | Specification |
|----------|---------------|
| `AGEGR9` | Age grouping into the following categories: `<18`, `18 - 50`, `>50` |
| `AGEGR9N` | Numeric age grouping of Analysis Age (`DM.AGE`). Categories are `<18`, `18 - 50`, `>50`. Numeric groupings are 1, 2, 3. |
| `TRTSDTM` / `TRTSTMF` | Set to datetime of patient's first exposure observation Start Date/Time of Treatment (`EX.EXSTDTC`) converted to numeric datetime when sorted in date/time order. Derivation only includes observations where the patient received a valid dose (see NOTE) and datepart of `EX.EXSTDTC` is complete. If time is missing (i.e. not collected), then impute completely missing time with `00:00:00`, partially missing time with `00` for missing hours, `00` for missing minutes, `00` for missing seconds. If only seconds are missing then do not populate the imputation flag (`TRTSTMF`). |
| `ITTFL` | Set to `"Y"` if `DM.ARM` is not missing; else set to `"N"`. |
| `LASTVLDT` | Set to the last date patient has documented clinical data to show them alive, converted to numeric date, using: **(1)** last complete date of vital assessment with a valid test result (`VS.VSSTRESN` and `VS.VSSTRESC` not both missing) and datepart of `VS.VSDTC` not missing; **(2)** last complete onset date of AEs (datepart of `AE.AESTDTC`); **(3)** last complete disposition date (datepart of `DS.DSSTDTC`); **(4)** last date of treatment administration where patient received a valid dose (datepart of `ADSL.TRTEDTM`). Set to max of (1)–(4). |

> **NOTE:** A valid dose is defined as `EX.EXDOSE > 0` **or** (`EX.EXDOSE == 0` **and** `EX.EXTRT` contains `'PLACEBO'`).

## Expected Result

An error-free program with good documentation that will create the ADSL dataset with all the requested variables. These should be derived using `{admiral}` functions where possible.

> **Hint:** This additional variable derivation is very similar to the ADSL example in the [Pharmaverse Examples](https://pharmaverse.github.io/admiral/cran-release/articles/adsl.html).

## Deliverables

| Deliverable | Path |
|-------------|------|
| ADSL creation script | `question_2_adam/create_adsl.R` |
| Resulting ADaM dataset | Any format |
| Log file (evidence of error-free run) | Text file |
