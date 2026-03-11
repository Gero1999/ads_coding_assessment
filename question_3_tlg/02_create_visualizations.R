# ============================================================================
# PROGRAM:    02_create_visualizations.R
# PURPOSE:    Create two AE visualisations using ggplot2
#               Plot 1 – AE severity distribution by treatment arm (bar chart)
#               Plot 2 – Top 10 most frequent AEs with 95% Clopper-Pearson CIs
# INPUT:      pharmaverseadam::adae
# OUTPUT:     question_3_tlg/plot1.png, question_3_tlg/plot2.png
# PACKAGES:   ggplot2, dplyr (implicitly via pipe)
# ============================================================================

adae <- pharmaverseadam::adae

# ── Plot 1: AE severity by treatment arm (grouped bar chart) ──────────────
library(ggplot2)

p1 <- ggplot2::ggplot(
    adae,
    aes(x = ACTARM, fill = AESEV)
    ) +
    geom_bar(position = "dodge") +
    labs(
        title = "AE severity distribution by treatment",
        x = "Treatment Arm",
        y = "Count of AEs",
        fill = "Severity/Intensity"
    )

ggplot2::ggsave(
    filename = "question_3_tlg/plot1.png",
    plot = p1,
    width = 8,
    height = 6
)

# ── Plot 2: Top 10 AEs with 95% Clopper-Pearson CIs ───────────────────
n_total <- n_distinct(adae$USUBJID)

#' Compute exact (Clopper-Pearson) binomial confidence interval
#'
#' @param n      Number of subjects with the event.
#' @param n_total Total number of subjects.
#' @param conf_level Confidence level (default 0.95).
#' @return Numeric vector of length 2: c(lower, upper).
get_ci_clopper_pearson <- function(n, n_total, conf_level = 0.95) {
    binom.test(n, n_total, conf.level = 0.95)$conf.int
}

p2 <- adae |>
    group_by(AETERM) |>
    summarise(
        n_pat = n_distinct(USUBJID),
        pct = 100 * n_pat/n_total,
        ci_lower = 100 * get_ci_clopper_pearson(n_pat, n_total)[1],
        ci_upper = 100 * get_ci_clopper_pearson(n_pat, n_total)[2],
        .groups = "drop"
    ) |>
    arrange(desc(pct)) |>
    slice_head(n = 10) |>
    ggplot(aes(x = pct, y = reorder(AETERM, pct))) +
    geom_point(size = 3) +
    geom_errorbarh(
        aes(xmin = ci_lower, xmax = ci_upper),
        height = 0.2
    ) +
    labs(
        title = "Top 10 Most Frequent Adverse Events",
        subtitle = paste0(
            "n = ", first(n_total), "; 95% Clopper-Pearson CIs"
        ),
        x = "Percentage of Patients (%)",
        y = ""
    ) +
    theme(
        plot.title = element_text(size = 18),
        plot.subtitle = element_text(size = 14),
        axis.text.y = element_text(size = 12),
        axis.title.x = element_text(size = 13),
        axis.text.x = element_text(size = 11)
    )
ggplot2::ggsave(
    filename = "question_3_tlg/plot2.png",
    plot = p2
)
