# ============================================================================
# PROGRAM:    create_adsl.R
# PURPOSE:    Create ADaM ADSL (Subject-Level Analysis Dataset) from SDTM
# INPUT:      pharmaversesdtm::{dm, vs, ex, ds, ae}
# OUTPUT:     question_2_adam/adsl.rds
# PACKAGES:   admiral, dplyr, pharmaversesdtm
# NOTES:      - Age grouped into <18, 18-50, >50
#             - TRTSDTM derived from first valid EX record
#             - ITTFL = "Y" for randomised subjects (non-missing ARM)
#             - LSTAVALDT = latest alive date across VS, AE, DS, EX
# ============================================================================

# ── Load packages & source data ────────────────────────────────────────
library(pharmaversesdtm)
library(admiral)
library(dplyr)

# SDTM source domains
dm <- pharmaversesdtm::dm   # Demographics
vs <- pharmaversesdtm::vs   # Vital Signs
ex <- pharmaversesdtm::ex   # Exposure
ds <- pharmaversesdtm::ds   # Disposition
ae <- pharmaversesdtm::ae   # Adverse Events

# ── EX: Impute missing time for treatment start datetime ─────────────────
ex_ext <- ex %>%
    # Impute missing time, but don't flag imputed seconds
    derive_vars_dtm(
        dtc = EXSTDTC,
        new_vars_prefix = "EXST",
        time_imputation = "00:00:00",
        highest_imputation = "h",
        flag_imputation = "time",
        ignore_seconds_flag = FALSE
    )
# ── Build ADSL ──────────────────────────────────────────────────────────
adsl <- dm %>%
    # AGEGR9 / AGEGR9N: Categorical age group (<18, 18-50, >50)
    mutate(
        AGEGR9 = case_when(
            AGE < 18 ~ "<18",
            AGE >= 18 & AGE <= 50 ~ "18 - 50",
            AGE > 50 ~ ">50",
            TRUE ~ NA_character_
        ),
        AGEGR9N = as.numeric(
            factor(AGEGR9, levels = c("<18", "18 - 50", ">50"))
        )
    ) %>%
    # TRTSDTM / TRTSTMF: Treatment start datetime from first valid EX dose
    derive_vars_merged(
        dataset_add = ex_ext,
        filter_add = EXDOSE > 0 | (EXDOSE == 0 & grepl("PLACEBO", toupper(EXTRT))) & !is.na(EXSTDTM),
        new_vars = exprs(
            TRTSDTM = EXSTDTM,
            TRTSTMF = EXSTTMF
        ),
        order = exprs(EXSTDTM, EXSEQ),
        mode = "first",
        by_vars = exprs(STUDYID, USUBJID)
    ) %>%
    # ITTFL: "Y" if subject was randomised (ARM is not missing)
    derive_var_merged_exist_flag(
        dataset_add = dm,
        by_vars = exprs(STUDYID, USUBJID),
        new_var = ITTFL,
        false_value = "N",
        condition = !is.na(ARM)
    ) %>%
    # LSTAVALDT: Latest documented-alive date across VS, AE, DS, EX
    derive_vars_extreme_event(
        by_vars = exprs(STUDYID, USUBJID),
        events = list(
            # Event 1: Last complete vital assessment with valid test result
            event(
                dataset_name = "vs",
                condition = !is.na(VSSTRESN) & !is.na(VSSTRESC) & !is.na(VSDTC),
                set_values_to = exprs(LSTAVALDT = convert_dtc_to_dt(VSDTC)),
                order = exprs(VSDTC)
            ),
            # Event 2: Last complete AE onset date
            event(
                dataset_name = "ae",
                condition = !is.na(AESTDTC),
                set_values_to = exprs(LSTAVALDT = convert_dtc_to_dt(AESTDTC)),
                order = exprs(AESTDTC)
            ),
            # Event 3: Last complete disposition date
            event(
                dataset_name = "ds",
                condition = !is.na(DSSTDTC),
                set_values_to = exprs(LSTAVALDT = convert_dtc_to_dt(DSSTDTC)),
                order = exprs(DSSTDTC)
            ),
            # Event 4: Last treatment administration with valid dose
            event(
                dataset_name = "ex_ext",
                condition = (EXDOSE > 0 | (EXDOSE == 0 & grepl("PLACEBO", toupper(EXTRT)))) & !is.na(EXSTDTM),
                set_values_to = exprs(LSTAVALDT = EXSTDTM),
                order = exprs(EXSTDTM)
            )
        ),
        source_datasets = list(
            vs = vs,
            ae = ae,
            ds = ds,
            ex_ext = ex_ext
        ),
        tmp_event_nr_var = event_nr,
        order = exprs(LSTAVALDT, event_nr),
        mode = "last",
        new_vars = exprs(LSTAVALDT)
    )

# ── Export & log ────────────────────────────────────────────────────────
saveRDS(adsl, file = "question_2_adam/adsl.rds")
write.csv(adsl, file = "question_2_adam/adsl.csv", row.names = FALSE)
