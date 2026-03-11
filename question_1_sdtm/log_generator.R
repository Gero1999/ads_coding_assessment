# ============================================================================
# PROGRAM:  log_generator.R
# PURPOSE:  Execute 01_create_ds_domain.R under logrx to produce an
#           auditable execution log (01_create_ds_domain.log)
# USAGE:    Rscript question_1_sdtm/log_generator.R
# ============================================================================

library(logrx)
logrx::axecute(
  file = "question_1_sdtm/01_create_ds_domain.R"
)

# Reset the log session for a clean state
suppressWarnings(try(log_reset(), silent = TRUE))