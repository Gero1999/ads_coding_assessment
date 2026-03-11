#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(stringr)
  library(lubridate)
  library(readr)
  library(pharmaversesdtm)
})

`%||%` <- function(x, y) if (is.null(x)) y else x

is_complete_datepart <- function(dtc) {
  !is.na(dtc) & str_detect(dtc, "^\\d{4}-\\d{2}-\\d{2}")
}

date_from_dtc <- function(dtc) {
  case_when(
    is_complete_datepart(dtc) ~ as.Date(str_sub(dtc, 1, 10)),
    TRUE ~ as.Date(NA)
  )
}

# Parse EXSTDTC/other --DTC variables where datepart is complete and time can be
# partially missing. Missing time components are imputed with 00.
# TRTSTMF is only set when missing hour or minute required imputation.
# If only seconds are missing then TRTSTMF remains NA by specification.
parse_imputed_dtm <- function(dtc) {
  dtc <- str_trim(dtc)
  out <- tibble(
    dtc = dtc,
    complete_datepart = is_complete_datepart(dtc),
    date_part = str_sub(dtc, 1, 10),
    time_part = if_else(str_detect(dtc, "T"), str_sub(dtc, 12), NA_character_),
    hour = NA_character_,
    minute = NA_character_,
    second = NA_character_,
    trtstmf = NA_character_,
    trtsdtm = as.POSIXct(NA, origin = "1970-01-01", tz = "UTC")
  )

  out$hour <- if_else(
    !is.na(out$time_part) & str_detect(out$time_part, "^\\d{2}"),
    str_sub(out$time_part, 1, 2),
    NA_character_
  )
  out$minute <- if_else(
    !is.na(out$time_part) & str_detect(out$time_part, "^\\d{2}:\\d{2}"),
    str_sub(out$time_part, 4, 5),
    NA_character_
  )
  out$second <- if_else(
    !is.na(out$time_part) & str_detect(out$time_part, "^\\d{2}:\\d{2}:\\d{2}$"),
    str_sub(out$time_part, 7, 8),
    NA_character_
  )

  needs_hour_impute <- out$complete_datepart & is.na(out$hour)
  needs_minute_impute <- out$complete_datepart & is.na(out$minute)
  needs_second_impute <- out$complete_datepart & is.na(out$second)

  out$hour[needs_hour_impute] <- "00"
  out$minute[needs_minute_impute] <- "00"
  out$second[needs_second_impute] <- "00"

  # Flag only if hour/minute were imputed. If only seconds were imputed leave NA.
  out$trtstmf <- case_when(
    needs_hour_impute & needs_minute_impute ~ "HOUR_MINUTE",
    needs_hour_impute ~ "HOUR",
    needs_minute_impute ~ "MINUTE",
    TRUE ~ NA_character_
  )

  parsed_dtm <- ymd_hms(
    paste(out$date_part, out$hour, out$minute, out$second, sep = " "),
    tz = "UTC",
    quiet = TRUE
  )
  out$trtsdtm <- if_else(out$complete_datepart, parsed_dtm, as.POSIXct(NA, origin = "1970-01-01", tz = "UTC"))
  out
}

derive_adsl <- function(dm, ex, vs, ds, ae) {
  dm_base <- dm %>%
    mutate(AGE = suppressWarnings(as.numeric(AGE)))

  adsl <- dm_base %>%
    mutate(
      AGEGR9N = case_when(
        !is.na(AGE) & AGE < 18 ~ 1,
        !is.na(AGE) & AGE <= 50 ~ 2,
        !is.na(AGE) & AGE > 50 ~ 3,
        TRUE ~ NA_real_
      ),
      AGEGR9 = case_when(
        AGEGR9N == 1 ~ "<18",
        AGEGR9N == 2 ~ "18 - 50",
        AGEGR9N == 3 ~ ">50",
        TRUE ~ NA_character_
      ),
      ITTFL = if_else(!is.na(ARM) & str_trim(ARM) != "", "Y", "N")
    )

  ex_valid <- ex %>%
    mutate(
      EXDOSE_NUM = suppressWarnings(as.numeric(EXDOSE)),
      valid_dose = (!is.na(EXDOSE_NUM) & EXDOSE_NUM > 0) |
        (!is.na(EXDOSE_NUM) & EXDOSE_NUM == 0 & str_detect(str_to_upper(EXTRT %||% ""), "PLACEBO"))
    ) %>%
    filter(valid_dose, is_complete_datepart(EXSTDTC)) %>%
    bind_cols(parse_imputed_dtm(.$EXSTDTC)) %>%
    filter(!is.na(trtsdtm))

  trts <- ex_valid %>%
    arrange(USUBJID, trtsdtm) %>%
    group_by(USUBJID) %>%
    slice_head(n = 1) %>%
    ungroup() %>%
    transmute(
      USUBJID,
      TRTSDTM = trtsdtm,
      TRTSTMF = trtstmf
    )

  vs_last <- vs %>%
    filter(
      is_complete_datepart(VSDTC),
      !(is.na(VSSTRESN) & (is.na(VSSTRESC) | str_trim(VSSTRESC) == ""))
    ) %>%
    transmute(USUBJID, src_date = date_from_dtc(VSDTC))

  ae_last <- ae %>%
    filter(is_complete_datepart(AESTDTC)) %>%
    transmute(USUBJID, src_date = date_from_dtc(AESTDTC))

  ds_last <- ds %>%
    filter(is_complete_datepart(DSSTDTC)) %>%
    transmute(USUBJID, src_date = date_from_dtc(DSSTDTC))

  ex_last <- ex_valid %>%
    transmute(USUBJID, src_date = as.Date(trtsdtm, tz = "UTC"))

  last_alive <- bind_rows(vs_last, ae_last, ds_last, ex_last) %>%
    group_by(USUBJID) %>%
    summarise(LASTVLDT = suppressWarnings(max(src_date, na.rm = TRUE)), .groups = "drop") %>%
    mutate(LASTVLDT = if_else(is.infinite(as.numeric(LASTVLDT)), as.Date(NA), LASTVLDT))

  adsl %>%
    left_join(trts, by = "USUBJID") %>%
    left_join(last_alive, by = "USUBJID")
}

run <- function() {
  file_arg <- commandArgs(trailingOnly = FALSE)
  script_path <- file_arg[str_detect(file_arg, "^--file=")] %>%
    str_remove("^--file=") %>%
    .[1]
  script_dir <- dirname(normalizePath(script_path, mustWork = FALSE))
  if (is.na(script_dir) || script_dir == "." || script_dir == "") {
    script_dir <- getwd()
  }

  out_dataset <- file.path(script_dir, "adsl.csv")
  out_log <- file.path(script_dir, "create_adsl.log")

  log_con <- file(out_log, open = "wt")
  sink(log_con, type = "output")
  sink(log_con, type = "message")
  on.exit({
    sink(type = "message")
    sink(type = "output")
    close(log_con)
  }, add = TRUE)

  cat("Starting ADSL derivation...\n")
  cat("Timestamp (UTC):", format(with_tz(Sys.time(), "UTC"), "%Y-%m-%d %H:%M:%S"), "\n\n")

  adsl <- derive_adsl(
    dm = pharmaversesdtm::dm,
    ex = pharmaversesdtm::ex,
    vs = pharmaversesdtm::vs,
    ds = pharmaversesdtm::ds,
    ae = pharmaversesdtm::ae
  )

  write_csv(adsl, out_dataset, na = "")

  cat("ADSL derivation finished successfully.\n")
  cat("Records:", nrow(adsl), "\n")
  cat("Output:", out_dataset, "\n")
}

run()
