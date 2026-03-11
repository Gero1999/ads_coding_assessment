# ============================================================================
# PROGRAM:  log_generator.R
# PURPOSE:  Execute create_adsl.R under logrx to produce an auditable
#           execution log (create_adsl.log)
# USAGE:    Rscript question_2_adam/log_generator.R
# ============================================================================

library(logrx)
logrx::axecute(
  file = "question_2_adam/create_adsl.R"
)

# Reset the log session for a clean state
suppressWarnings(try(log_reset(), silent = TRUE))