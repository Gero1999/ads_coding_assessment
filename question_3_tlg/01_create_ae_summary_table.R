# ============================================================================
# PROGRAM:    01_create_ae_summary_table.R
# PURPOSE:    Produce a hierarchical TEAE summary table (FDA Table 10 style)
# INPUT:      pharmaverseadam::{adsl, adae}
# OUTPUT:     question_3_tlg/teaes.html
# PACKAGES:   dplyr, pharmaverseadam, gtsummary, gt
# NOTES:      - Rows: AESOC > AETERM (hierarchical)
#             - Columns: Treatment arm (ACTARM)
#             - Cells: n (%) with overall row; sorted by descending frequency
#             - Only treatment-emergent AEs (TRTEMFL == "Y")
# ============================================================================

# ── Load libraries & data ──────────────────────────────────────────────
library(dplyr)
library(pharmaverseadam)
library(gtsummary)
library(gt)

adsl <- pharmaverseadam::adsl   # Subject-level (denominator)
adae <- pharmaverseadam::adae   # AE-level analysis dataset

# ── Filter to TEAEs & build hierarchical table ───────────────────────
tbl <- adae |>
  filter(
    # Include only treatment-emergent AEs
    TRTEMFL == "Y"
  ) |>
tbl_hierarchical(
    variables = c(AESOC, AETERM),
    by = ACTARM,
    # Include total column with all subjects in the denominator for percentage calculations
    id = USUBJID,
    denominator = adsl,
    overall_row = TRUE,
    label = "..ard_hierarchical_overall.." ~ "Treatment Emergent AEs"
) |>
   # Sort rows by descending frequency (default)
    sort_hierarchical()

# ── Export as HTML ──────────────────────────────────────────────────────
gtsummary::as_gt(tbl) |>
    gt::gtsave(filename = "question_3_tlg/teaes.html")
