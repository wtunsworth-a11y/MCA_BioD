#!/usr/bin/env Rscript
# Download every GBIF record behind the MCA tier 1-2 species, with its
# original locality label and georeference details, so each one can be
# checked by hand. Verdicts go in review/mca_gbif_review.csv.
# Run after run_mca.R. Output: output/MCA_gbif_records_audit.csv

for (f in list.files("R", full.names = TRUE)) source(f)
g <- site_geometries("data/mca/managalas_wdpa.geojson")
mca <- read.csv("output/MCA_target4_ranked.csv", stringsAsFactors = FALSE)
sp <- mca[mca$site_tier_gbif %in% 1:2, ]
site_utm <- sf::st_transform(g$site, 32755)
s1 <- function(v) if (is.null(v) || length(v) == 0) NA else as.character(unlist(v)[1])
rows <- list()
for (i in seq_len(nrow(sp))) {
  off <- 0
  repeat {
    res <- gbif_get("occurrence/search", list(taxonKey = sp$gbif_key[i],
      geometry = gbif_wkt(g$buffer_query), limit = 300, offset = off,
      hasGeospatialIssue = "false", occurrenceStatus = "PRESENT", basisOfRecord = gbif_basis))
    for (o in res$results) {
      p <- sf::st_transform(sf::st_sfc(sf::st_point(c(o$decimalLongitude, o$decimalLatitude)), crs = 4326), 32755)
      d <- as.numeric(sf::st_distance(p, site_utm)) / 1000
      rows[[length(rows) + 1]] <- data.frame(
        species = sp$scientific_name[i], tier = sp$site_tier[i], key = o$key,
        inside = d == 0, dist_km = round(d, 1),
        basis = s1(o$basisOfRecord), inst = s1(o$institutionCode),
        catalog = s1(o$catalogNumber), recordedBy = s1(o$recordedBy),
        year = s1(o$year), locality = s1(c(o$locality, o$verbatimLocality)),
        lat = o$decimalLatitude, lon = o$decimalLongitude,
        unc_m = s1(o$coordinateUncertaintyInMeters),
        geo_protocol = s1(o$georeferenceProtocol),
        geo_remarks = s1(o$georeferenceRemarks),
        geo_sources = s1(o$georeferenceSources),
        issues = paste(unlist(o$issues), collapse = ";"),
        dataset = s1(o$datasetKey), stringsAsFactors = FALSE)
    }
    if (isTRUE(res$endOfRecords) || !length(res$results)) break
    off <- off + 300
  }
}
x <- do.call(rbind, rows)
write.csv(x, "output/MCA_gbif_records_audit.csv", row.names = FALSE, na = "")
cat(nrow(x), "records;", sum(x$inside), "inside\n")
