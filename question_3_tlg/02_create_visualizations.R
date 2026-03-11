#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(forcats)
  library(pharmaverseadam)
})

# -------------------------------
# Objective
# -------------------------------
# Create two AE visualizations:
#   Plot 1: AE severity distribution by treatment
#   Plot 2: Top 10 most frequent AEs with 95% CI for incidence rates
#
# Explicit derivation logic used in this script:
#   - TEAE records are defined as ADAE records where TRTEMFL == "Y"
#   - Plot 1 counts AE records by ACTARM x AESEV (record-based distribution)
#   - Plot 2 computes subject-level incidence by AETERM:
#       numerator   = unique subjects with >=1 TEAE for that term
#       denominator = unique subjects in ADSL overall
#       incidence   = numerator / denominator
#       95% CI      = Wald CI: p ± 1.96 * sqrt(p * (1-p) / N), clipped to [0, 1]

output_dir <- "question_3_tlg/output"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

teae <- pharmaverseadam::adae %>%
  filter(TRTEMFL == "Y") %>%
  select(USUBJID, ACTARM, AESEV, AETERM) %>%
  filter(!is.na(ACTARM), !is.na(AESEV), !is.na(AETERM))

# -------------------------------
# Plot 1: AE severity distribution by treatment
# -------------------------------
severity_plot_data <- teae %>%
  count(ACTARM, AESEV, name = "n_records")

p1 <- ggplot(severity_plot_data, aes(x = ACTARM, y = n_records, fill = AESEV)) +
  geom_col(position = "stack") +
  labs(
    title = "TEAE Severity Distribution by Treatment",
    x = "Treatment Arm (ACTARM)",
    y = "Number of TEAE Records",
    fill = "AE Severity"
  ) +
  theme_minimal(base_size = 12) +
  theme(axis.text.x = element_text(angle = 15, hjust = 1))

ggsave(
  filename = file.path(output_dir, "plot1_ae_severity_by_treatment.png"),
  plot = p1,
  width = 10,
  height = 6,
  dpi = 300
)

# -------------------------------
# Plot 2: Top 10 most frequent AEs with 95% CI
# -------------------------------
adsl_n <- pharmaverseadam::adsl %>%
  distinct(USUBJID) %>%
  nrow()

term_subject_counts <- teae %>%
  distinct(USUBJID, AETERM) %>%
  count(AETERM, name = "n_subjects") %>%
  mutate(
    incidence = n_subjects / adsl_n,
    se = sqrt((incidence * (1 - incidence)) / adsl_n),
    ci_low = pmax(0, incidence - 1.96 * se),
    ci_high = pmin(1, incidence + 1.96 * se)
  ) %>%
  arrange(desc(n_subjects), AETERM) %>%
  slice_head(n = 10) %>%
  mutate(AETERM = forcats::fct_reorder(AETERM, incidence))

p2 <- ggplot(term_subject_counts, aes(x = AETERM, y = incidence)) +
  geom_col(fill = "steelblue") +
  geom_errorbar(aes(ymin = ci_low, ymax = ci_high), width = 0.2) +
  coord_flip() +
  scale_y_continuous(labels = function(x) paste0(round(x * 100, 1), "%")) +
  labs(
    title = "Top 10 TEAE Preferred Terms by Subject Incidence",
    x = "AETERM",
    y = "Incidence Rate (95% CI)"
  ) +
  theme_minimal(base_size = 12)

ggsave(
  filename = file.path(output_dir, "plot2_top10_aeterm_incidence_ci.png"),
  plot = p2,
  width = 10,
  height = 6,
  dpi = 300
)

message("Visualizations created successfully:")
message(" - ", file.path(output_dir, "plot1_ae_severity_by_treatment.png"))
message(" - ", file.path(output_dir, "plot2_top10_aeterm_incidence_ci.png"))
