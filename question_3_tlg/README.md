# Question 3 — TLG Adverse Events Summary

## Objective

Create outputs for adverse events summary using the ADAE dataset and `{gtsummary}`. This tests your ability to create regulatory-compliant clinical reports.

**Input datasets:** `pharmaverseadam::adae` and `pharmaverseadam::adsl`

## Tasks

### 1. Summary Table using `{gtsummary}` *(Hint — FDA Table 10)*

Create a summary table of treatment-emergent adverse events (TEAEs).

- Treatment-emergent AE records will have `TRTEMFL == "Y"` in `pharmaverseadam::adae`
- **Rows:** `AETERM` or `AESOC`
- **Columns:** Treatment groups (`ACTARM`)
- **Cell values:** Count (*n*) and percentage (%)
- Include total column with all subjects
- Sort by descending frequency

**Output format:** HTML / DOCX / PDF file

### 2. Visualizations using `{ggplot2}`

- **Plot 1:** AE severity distribution by treatment (bar chart or heatmap). AE Severity is captured in the `AESEV` variable in the `pharmaverseadam::adae` dataset.
- **Plot 2:** Top 10 most frequent AEs (with 95% CI for incidence rates). AEs are captured in the `AETERM` variable in the `pharmaverseadam::adae` dataset.

**Output format:** PNG file

## Deliverables

| Deliverable | Path |
|-------------|------|
| Summary table script | `question_3_tlg/01_create_ae_summary_table.R` |
| Visualizations script | `question_3_tlg/02_create_visualizations.R` |
| Log files (evidence of error-free run) | Text files |

## Explicit Derivation Logic Implemented

### TEAE definition
- A record is treated as treatment-emergent if `TRTEMFL == "Y"` in `pharmaverseadam::adae`.

### Summary table (`01_create_ae_summary_table.R`)
- **Row variable:** `AETERM`
- **Column variable:** `ACTARM` + Total
- **Numerator (n):** count of unique `USUBJID` with at least one TEAE for each `AETERM` and `ACTARM`
- **Treatment denominator:** unique `USUBJID` in `pharmaverseadam::adsl` per `ACTARM`
- **Total denominator:** all unique `USUBJID` in `pharmaverseadam::adsl`
- **Cell display:** `n (percent)` where `percent = 100 * n / denominator`
- **Sorting:** descending by total TEAE subject count per `AETERM`

### Visualizations (`02_create_visualizations.R`)
- **Plot 1 (severity by treatment):**
  - Uses TEAE records only
  - Counts records by `ACTARM` and `AESEV`
  - Draws stacked bar chart of TEAE record counts
- **Plot 2 (top 10 AEs + 95% CI):**
  - Uses TEAE records only
  - For each `AETERM`, numerator = unique subjects with ≥1 TEAE for that term
  - Denominator = all unique subjects in `pharmaverseadam::adsl`
  - Incidence rate: `p = numerator / denominator`
  - 95% CI (Wald): `p ± 1.96 * sqrt(p*(1-p)/N)`, clipped to `[0, 1]`
  - Selects top 10 AEs by descending numerator
