# Question 1 — SDTM DS Domain Derivation

## Objective

Create an SDTM Disposition (DS) domain dataset from raw clinical trial data using `{sdtm.oak}`.

## Task

Develop an R program to create the DS domain using the inputs below.

- **Input raw data:** `pharmaverseraw::ds_raw`
- **Study controlled terminology:** The `study_ct` file is required to solve this exercise and you can get it by the options below:
  1. Download it from GitHub, **or**
  2. If the GitHub link is not accessible, you can follow the instructions in the Pharmaverse *Running the example* page — any of the examples in the SDTM section can provide the `study_ct` object, **or**
  3. If (1) or (2) above doesn't work, create the required file using the instructions following the below code.

## Expected Result

An error-free program with good documentation that will create the DS domain with the following variables: `STUDYID`, `DOMAIN`, etc.

## Deliverables

| Deliverable | Path |
|-------------|------|
| SDTM creation script | `question_1_sdtm/01_create_ds_domain.R` |
| Resulting SDTM dataset | Any format |
| Log file (evidence of error-free run) | Text file |
