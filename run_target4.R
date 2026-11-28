#!/usr/bin/env Rscript
# Rank species in need of urgent management action under GBF Target 4
# (Akcakaya et al. 2026) for one country, using the IUCN Red List API v4.
#
# Usage:
#   Rscript run_target4.R              # Papua New Guinea (PG)
#   Rscript run_target4.R PG --refresh # re-download instead of using cache
#   Rscript run_target4.R PG --missing-trend-unknown
#
# Outputs (in output/):
#   <CC>_target4_ranked.csv   the national ranked list (EW, Priority 1, Priority 2)
#   <CC>_target4_all_scored.csv  every CR/EN/VU/EW species with all weights

args <- commandArgs(trailingOnly = TRUE)
country <- toupper(if (length(args) && !startsWith(args[1], "--")) args[1] else "PG")
refresh <- "--refresh" %in% args
missing_trend_unknown <- "--missing-trend-unknown" %in% args

# Write names with accents and curly quotes as UTF-8, whatever the locale.
invisible(suppressWarnings(Sys.setlocale("LC_CTYPE", "C.UTF-8")))
for (f in list.files("R", pattern = "\\.R$", full.names = TRUE)) source(f)

if (file.exists(".Renviron")) readRenviron(".Renviron")
cache_dir <- file.path("data", "cache")
out_dir <- "output"
dir.create(out_dir, showWarnings = FALSE)

assessments <- fetch_threatened_assessments(country, cache_dir, refresh = refresh)
species <- standardise_assessments(assessments, focal = country)
scored <- score_species(species, missing_trend_is_unknown = missing_trend_unknown)
scored <- scored[is_true(scored$in_focal), , drop = FALSE]
ranked <- rank_species(scored)

cols <- c("rank", "priority", "rank_in_priority", "priority_score",
          "scientific_name", "common_name", "kingdom", "phylum", "class", "order", "family",
          "category", "criteria", "criteria_version", "year_published",
          "population_trend", "possibly_extinct",
          "risk_w", "decline_w", "restriction_w", "endemism_w", "PS1", "PS2",
          "n_countries", "focal_presence", "focal_origin",
          "pop_size", "aoo", "eoo", "n_locations", "area_restricted",
          "assessment_id", "sis_taxon_id", "url")
write.csv(ranked[, cols], file.path(out_dir, sprintf("%s_target4_ranked.csv", country)),
          row.names = FALSE, na = "")
score_cols <- setdiff(c(cols, "cd_pop", "cd_area", "cd_loc", "cd_eoo",
                        "cd_aoo", "cd_subp"),
                      c("rank", "rank_in_priority", "priority_score"))
write.csv(scored[, score_cols],
          file.path(out_dir, sprintf("%s_target4_all_scored.csv", country)),
          row.names = FALSE, na = "")

thr <- scored$category %in% c("CR", "EN", "VU", "EW")
p1 <- sum(ranked$priority == "P1")
cat(sprintf("\n%s: %d threatened + EW species qualify in-country\n",
            country, sum(thr)))
cat(sprintf("  EW (unranked): %d\n", sum(ranked$priority == "EW")))
cat(sprintf("  Priority 1:    %d (%.1f%% of threatened + EW)\n", p1,
            100 * p1 / sum(thr)))
cat(sprintf("  Priority 2:    %d\n", sum(ranked$priority == "P2")))
cat(sprintf("  Not listed:    %d\n", sum(is.na(scored$priority))))
cat("\nTop 15:\n")
print(head(ranked[, c("rank", "priority", "priority_score", "scientific_name",
                      "class", "category", "criteria")], 15), row.names = FALSE)
