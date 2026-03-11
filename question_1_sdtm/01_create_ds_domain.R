# ============================================================================
# PROGRAM:    01_create_ds_domain.R
# PURPOSE:    Derive an SDTM-compliant DS (Disposition) domain from raw data
# INPUT:      pharmaverseraw::ds_raw, question_1_sdtm/sdtm_ct.csv
# OUTPUT:     question_1_sdtm/ds_domain.csv, ds.rds
# PACKAGES:   pharmaverseraw, sdtm.oak, dplyr, stringr, stringdist, readr
# NOTES:      - DSSTDTC derived from IT.DSSTDAT at Baseline visit
#             - Subjects without Baseline records get DSSTDTC = NA
#             - Controlled terminology (CT) applied via sdtm.oak functions
# ============================================================================

# Load required packages
if (!requireNamespace("pharmaverseraw", quietly = TRUE)) {
  install.packages("remotes")
  remotes::install_github("pharmaverse/pharmaverseraw")
}

if (!requireNamespace("dplyr", quietly = TRUE)) {
  install.packages("dplyr")
}

library(pharmaverseraw)
library(dplyr)
library(readr)
library(sdtm.oak)

# ── Load controlled terminology & raw source data ─────────────────────────
sdtm_ct <- read_csv("question_1_sdtm/sdtm_ct.csv")

# Load raw disposition data and generate oak traceability IDs
ds_raw <- pharmaverseraw::ds_raw %>%
  # Create oak_id variables for traceability
    generate_oak_id_vars(
        pat_var = "PATNUM",
        raw_src = "ds_raw"
    )
oak_id_vars <- setdiff(
    names(ds_raw),
    names(pharmaverseraw::ds_raw)
)

# ── Derive DS domain variables ────────────────────────────────────────────
# Target variables: STUDYID, DOMAIN, USUBJID, DSSEQ, DSTERM, DSDECOD,
#                   DSCAT, VISITNUM, VISIT, DSDTC, DSSTDTC, DSSTDY

# DSDECOD: Map from IT.DSDECOD (standard) or OTHERSP (free-text) via CT
ds <- assign_ct(
        raw_dat =  condition_add(ds_raw, is.na(OTHERSP)),
        raw_var = "IT.DSDECOD",
        ct_spec = sdtm_ct,
        ct_clst = "C66727",
        tgt_var = "DSDECOD"
    ) %>%
    assign_ct(
        raw_dat =  condition_add(ds_raw, !is.na(OTHERSP)),
        raw_var = "OTHERSP",
        ct_spec = sdtm_ct,
        ct_clst = "C66727",
        tgt_var = "DSDECOD",
        id_vars = oak_id_vars
    ) %>%

    # DSCAT: "PROTOCOL MILESTONE" if Randomized, "DISPOSITION EVENT" otherwise,
    #        or "OTHER EVENT" when OTHERSP is populated
    hardcode_ct(
        raw_dat = condition_add(ds_raw, IT.DSDECOD == "Randomized"),
        raw_var = "IT.DSDECOD",
        tgt_var = "DSCAT",
        tgt_val = "PROTOCOL MILESTONE",
        id_vars = oak_id_vars,
        ct_spec = sdtm_ct,
        ct_clst = "C74558"
    ) %>%
    hardcode_ct(
        raw_dat = condition_add(ds_raw, IT.DSDECOD != "Randomized"),
        raw_var = "IT.DSDECOD",
        tgt_var = "DSCAT",
        tgt_val = "DISPOSITION EVENT",
        id_vars = oak_id_vars,
        ct_spec = sdtm_ct,
        ct_clst = "C74558"
    ) %>%
    # If OTHERSP is not null, map it to DSCAT as "OTHER EVENT"
    hardcode_ct(
        raw_dat = condition_add(ds_raw, !is.na(OTHERSP)),
        raw_var = "OTHERSP",
        tgt_var = "DSCAT",
        tgt_val = "OTHER EVENT",
        id_vars = oak_id_vars,
        ct_spec = sdtm_ct,
        ct_clst = "C74558"
    ) %>%

    # DSTERM: Use OTHERSP verbatim if populated, otherwise IT.DSDECOD
    assign_no_ct(
        raw_dat = condition_add(ds_raw, !is.na(OTHERSP)),
        raw_var = "OTHERSP",
        tgt_var = "DSTERM",
        id_vars = oak_id_vars
    ) %>%
    assign_no_ct(
        raw_dat = condition_add(ds_raw, is.na(OTHERSP)),
        raw_var = "IT.DSDECOD",
        tgt_var = "DSTERM",
        id_vars = oak_id_vars
    ) %>%
    
    # DSDTC: Combine date (DSDTCOL) and time (DSTMCOL) → ISO 8601
    assign_datetime(
        raw_dat = ds_raw,
        raw_var = c("DSDTCOL", "DSTMCOL"),
        tgt_var = "DSDTC",
        raw_fmt = c(list(c("mm-dd-yyyy")), "H:M")
    ) %>%

    # DSSTDTC: Disposition start date from IT.DSSTDAT → ISO 8601
    assign_datetime(
        raw_dat = ds_raw,
        raw_var = "IT.DSSTDAT",
        tgt_var = "DSSTDTC",
        raw_fmt = list(c("dd-mm-yyyy"))
    ) %>%

    # VISIT / VISITNUM: Map from INSTANCE via CT codelists
    assign_ct(
        raw_dat = ds_raw,
        raw_var = "INSTANCE",
        ct_spec = sdtm_ct,
        ct_clst = "VISIT",
        tgt_var = "VISIT"
    ) %>%
    assign_ct(
        raw_dat = ds_raw,
        raw_var = "INSTANCE",
        ct_spec = sdtm_ct,
        ct_clst = "VISITNUM",
        tgt_var = "VISITNUM"
    ) %>%
    
    # Bring in remaining raw columns for STUDYID / PATNUM derivation
    left_join(
        ds_raw, by = c(oak_id_vars)
    ) %>%

    # STUDYID, USUBJID, DOMAIN: Standard identifiers
    mutate(
        STUDYID = STUDY,
        USUBJID = paste0(STUDYID, "-", PATNUM),
        DOMAIN = "DS"
    ) %>%

    # DSSEQ: Sequence number within each subject
    derive_seq(
        tgt_var = "DSSEQ",
        rec_vars = c("STUDYID", "USUBJID", "DSDECOD", "DSSTDTC"),
    )

# ── DSSTDY: Study day relative to Baseline reference date ────────────────
ds <- derive_study_day(
        sdtm_in = ds,
        dm_domain = ds %>% filter(INSTANCE == "Baseline") %>%
            select(USUBJID, DSSTDTC) %>%
            rename(REF_DSDTC = DSSTDTC),
        refdt = "REF_DSDTC",
        tgdt = "DSSTDTC",
        study_day_var = "DSSTDY"
    ) %>%
    # Select only the required variables for the final DS dataset
    select(
        STUDYID, DOMAIN, USUBJID, DSSEQ,
        DSTERM, DSDECOD, DSCAT, VISITNUM,
        VISIT, DSDTC, DSSTDTC, DSSTDY
    )

# ── Variable labels & metadata ────────────────────────────────────────────
labels_ds_vars <- c(
    STUDYID = "Study Identifier",
    DOMAIN = "Domain Abbreviation",
    USUBJID = "Unique Subject Identifier",
    DSSEQ = "Sequence Number",
    DSTERM = "Dictionary-Derived Term",
    DSDECOD = "Dictionary-Derived Code",
    DSCAT = "Category for Disposition Event",
    VISITNUM = "Visit Number",
    VISIT = "Visit Name",
    DSDTC = "Date/Time of Disposition Event",
    DSSTDTC = "Date/Time of Disposition Start",
    DSSTDY = "Study Day of Disposition Start"
)
for (var in names(labels_ds_vars)) {
    attr(ds[[var]], "label") <- labels_ds_vars[[var]]
}
attr(ds, "dataset_name") <- "Disposition"

# ── Export final DS dataset ───────────────────────────────────────────────
saveRDS(ds, file = "question_1_sdtm/ds.rds") # Considers also labels
write.csv(ds, "question_1_sdtm/ds.csv", row.names = FALSE)

