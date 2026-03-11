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
