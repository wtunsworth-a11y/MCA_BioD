#!/usr/bin/env Rscript
# Prioritise Papua New Guinea's Target 4 species for the Managalas
# Conservation Area (MCA), using its WDPA boundary and GBIF occurrence records.
#
# Needs: the national run first (Rscript run_target4.R PG), and the MCA
# boundary at data/mca/managalas_wdpa.geojson (WDPA site 555651673; see README).
#
# Usage:
#   Rscript run_mca.R                 # 25 km buffer
#   Rscript run_mca.R --buffer-km 10
#
# Outputs (in output/):
#   MCA_target4_ranked.csv   every PNG Target 4 species with its MCA evidence
#                            tier, GBIF record counts and MCA rank

args <- commandArgs(trailingOnly = TRUE)
buffer_km <- 25
if ("--buffer-km" %in% args) buffer_km <- as.numeric(args[which(args == "--buffer-km") + 1])

for (f in list.files("R", pattern = "\\.R$", full.names = TRUE)) source(f)
if (file.exists(".Renviron")) readRenviron(".Renviron")

country <- "PG"
cache_dir <- file.path("data", "cache")
boundary <- file.path("data", "mca", "managalas_wdpa.geojson")
if (!file.exists(boundary)) {
  stop("MCA boundary not found at ", boundary, ". Download WDPA site ",
       "555651673 as GeoJSON (see README).", call. = FALSE)
}

# National Target 4 list (from the cached IUCN assessments)
assessments <- fetch_threatened_assessments(country, cache_dir)
species <- standardise_assessments(assessments, focal = country)
scored <- score_species(species)
scored <- scored[is_true(scored$in_focal), , drop = FALSE]
ranked <- rank_species(scored)
ranked$priority_score <- ifelse(ranked$priority == "P1", ranked$PS1, ranked$PS2)

# Site geometry and GBIF evidence
geoms <- site_geometries(boundary, buffer_km = buffer_km)
message(sprintf("MCA boundary: %.0f km2; buffer %g km; GBIF query polygons simplified at %g m (site) and %g m (buffer)", geoms$area_km2, buffer_km, geoms$site_query_tolerance_m, geoms$buffer_query_tolerance_m))
gbif_cache <- file.path(cache_dir, sprintf("gbif_mca_%gkm", buffer_km))
dir.create(gbif_cache, recursive = TRUE, showWarnings = FALSE)
message("Matching names to GBIF")
m <- gbif_match_names(ranked$scientific_name, ranked$kingdom,
                      file.path(cache_dir, "gbif"))
ranked <- cbind(ranked, m[, -1])
counts <- gbif_site_counts(geoms, ranked, country, gbif_cache)
i <- match(paste(ranked$gbif_key_type, ranked$gbif_key),
           paste(counts$gbif_key_type, counts$gbif_key))
ranked$n_site <- counts$n_site[i]
ranked$n_buffer <- counts$n_buffer[i]
ranked$n_country <- counts$n_country[i]
# Species that still share one GBIF key with another IUCN species: their
# records cannot be told apart, so flag them.
dup <- ranked$gbif_key[duplicated(ranked$gbif_key) & !is.na(ranked$gbif_key)]
ranked$gbif_shared_key <- ranked$gbif_key %in% dup
ranked$site_tier <- site_tier(ranked$n_site, ranked$n_buffer, ranked$systems)
ranked$site_tier_gbif <- ranked$site_tier

# Manual review of the GBIF records behind tiers 1 and 2 (review/): reads each
# record's original locality label, moves species whose only records are
# mislocated, and records how strong the evidence is.
review_file <- file.path("review", "mca_gbif_review.csv")
ranked$evidence <- NA_character_
ranked$evidence_note <- NA_character_
if (file.exists(review_file)) {
  rv <- read.csv(review_file, stringsAsFactors = FALSE)
  j <- match(ranked$scientific_name, rv$scientific_name)
  hit <- !is.na(j)
  ranked$site_tier[hit] <- rv$reviewed_tier[j[hit]]
  ranked$evidence[hit] <- rv$evidence[j[hit]]
  ranked$evidence_note[hit] <- rv$note[j[hit]]
  unreviewed <- ranked$site_tier_gbif %in% 1:2 & !hit
  if (any(unreviewed)) {
    warning(sum(unreviewed), " species in tiers 1-2 have no entry in ", review_file,
            ": ", paste(ranked$scientific_name[unreviewed], collapse = ", "),
            call. = FALSE)
    ranked$evidence[unreviewed] <- "Not reviewed"
  }
}
mca <- site_rank(ranked)

cols <- c("site_tier", "site_tier_label", "site_rank", "evidence", "evidence_note",
          "site_tier_gbif", "priority", "rank",
          "priority_score", "scientific_name", "kingdom", "phylum", "class",
          "order", "family", "category", "criteria", "population_trend",
          "systems", "elev_lower", "elev_upper",
          "n_site", "n_buffer", "n_country", "site_share",
          "risk_w", "decline_w", "restriction_w", "endemism_w", "n_countries",
          "gbif_key", "gbif_key_type", "gbif_name", "gbif_match", "gbif_status",
          "gbif_shared_key",
          "assessment_id", "url")
dir.create("output", showWarnings = FALSE)
out <- file.path("output", "MCA_target4_ranked.csv")
write.csv(mca[, cols], out, row.names = FALSE, na = "")

cat(sprintf("\nManagalas Conservation Area (%.0f km2), buffer %g km\n",
            geoms$area_km2, buffer_km))
cat(sprintf("  PNG Target 4 species:        %d\n", nrow(mca)))
cat(sprintf("  Not matched in GBIF:         %d\n", sum(is.na(mca$gbif_key))))
for (t in 1:4) {
  s <- mca$site_tier == t
  cat(sprintf("  %-28s %4d  (P1 %d, P2 %d)\n", paste0(site_tier_labels[t], ":"),
              sum(s), sum(s & mca$priority == "P1"), sum(s & mca$priority == "P2")))
}
cat("\nTop species for the MCA:\n")
print(head(mca[mca$site_tier <= 2, c("site_tier", "site_rank", "priority",
                                     "priority_score", "scientific_name",
                                     "class", "category", "n_site", "n_buffer")],
           25), row.names = FALSE)
cat("\nWritten:", out, "\n")
