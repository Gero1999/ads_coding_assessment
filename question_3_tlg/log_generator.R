# ============================================================================
# PROGRAM:  log_generator.R
# PURPOSE:  Execute both TLG scripts under logrx to produce auditable logs
#             - 01_create_ae_summary_table.log
#             - 02_create_visualizations.log
# USAGE:    Rscript question_3_tlg/log_generator.R
# ============================================================================

library(logrx)

# Table script
logrx::axecute(
  file = "question_3_tlg/01_create_ae_summary_table.R"
)
suppressWarnings(try(log_remove(), silent = TRUE))
# Visualisation script
logrx::axecute(
  file = "question_3_tlg/02_create_visualizations.R"
)
suppressWarnings(try(log_remove(), silent = TRUE))