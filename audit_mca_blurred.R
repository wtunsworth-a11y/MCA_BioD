#!/usr/bin/env Rscript
# Find GBIF records of PNG Target 4 species whose location is blurred or
# imprecise (iNaturalist hidden locations, coarse georeferences) and whose
# uncertainty area reaches into the MCA. Run after run_mca.R.
# Output: output/MCA_blurred_records.csv

invisible(suppressWarnings(Sys.setlocale("LC_CTYPE", "C.UTF-8")))
for (f in list.files("R", full.names = TRUE)) source(f)
s1 <- function(v) if (is.null(v) || length(v) == 0) NA else as.character(unlist(v)[1])
g <- site_geometries("data/mca/managalas_wdpa.geojson", buffer_km = 100)
site_utm <- sf::st_transform(g$site, 32755)
mca <- read.csv("output/MCA_target4_ranked.csv", stringsAsFactors = FALSE)
inat <- "50c9509d-22c7-4a22-a47d-8c48425ef4a7"
# Candidate species: any record within 100 km that is either from iNaturalist
# or has a coordinate uncertainty of 5 km or more.
q <- list(geometry = gbif_wkt(g$buffer_query))
a <- gbif_species_counts(c(q, list(datasetKey = inat)))
b <- gbif_species_counts(c(q, list(coordinateUncertaintyInMeters = "5000,10000000")))
cand <- unique(c(a$gbif_key, b$gbif_key))
cand <- intersect(cand, mca$gbif_key[mca$gbif_key_type == "species"])
cat(length(cand), "Target 4 species with iNaturalist or low-precision records within 100 km\n")
rows <- list()
for (k in cand) {
  res <- gbif_get("occurrence/search", c(q, list(taxonKey = k, limit = 300,
    hasGeospatialIssue = "false", occurrenceStatus = "PRESENT", basisOfRecord = gbif_basis)))
  for (o in res$results) {
    unc <- suppressWarnings(as.numeric(s1(o$coordinateUncertaintyInMeters)))
    gen <- s1(o$dataGeneralizations); wh <- s1(o$informationWithheld)
    p <- sf::st_transform(sf::st_sfc(sf::st_point(c(o$decimalLongitude, o$decimalLatitude)), crs = 4326), 32755)
    d <- as.numeric(sf::st_distance(p, site_utm))
    rows[[length(rows) + 1]] <- data.frame(gbif_key = k, key = o$key, dist_km = round(d / 1000, 1),
      unc_km = round(unc / 1000, 1), dataset = ifelse(identical(o$datasetKey, inat), "iNaturalist", s1(o$institutionCode)),
      basis = s1(o$basisOfRecord), year = s1(o$year), locality = s1(c(o$locality, o$verbatimLocality)),
      generalised = s1(c(gen, wh)), stringsAsFactors = FALSE)
  }
}
x <- do.call(rbind, rows)
x$scientific_name <- mca$scientific_name[match(x$gbif_key, mca$gbif_key)]
x$common_name <- mca$common_name[match(x$gbif_key, mca$gbif_key)]
x$tier <- mca$site_tier[match(x$gbif_key, mca$gbif_key)]
x$overlaps <- !is.na(x$unc_km) & x$dist_km > 0 & x$dist_km <= x$unc_km
write.csv(x, "output/MCA_blurred_records.csv", row.names = FALSE, na = "", fileEncoding = "UTF-8")
y <- x[x$overlaps, ]
cat(nrow(y), "records outside the MCA whose uncertainty area reaches into it\n")
print(y[order(y$tier, y$scientific_name), c("tier","scientific_name","common_name","key","dataset","year","dist_km","unc_km","locality","generalised")], row.names = FALSE)
