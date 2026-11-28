#' Site-level prioritisation: which of a country's Target 4 species occur in,
#' or near, one conservation area, using GBIF occurrence records.
#'
#' Steps:
#'   1. Read the site boundary (e.g. a WDPA polygon) and build a buffer.
#'   2. Match each species name to the GBIF backbone (accepted species key).
#'   3. Count GBIF records per species inside the boundary, inside the buffer,
#'      and in the whole country.
#'   4. Assign an evidence tier and rank within tiers by the national Target 4
#'      priority (see site_rank()).

gbif_base_url <- "https://api.gbif.org/v1"

# Record types kept: everything except fossils and living (cultivated or
# captive) specimens.
gbif_basis <- c("PRESERVED_SPECIMEN", "HUMAN_OBSERVATION", "MACHINE_OBSERVATION",
                "MATERIAL_SAMPLE", "OCCURRENCE", "OBSERVATION")

gbif_get <- function(path, query = list(), pause = 0.1) {
  req <- httr2::request(gbif_base_url) |>
    httr2::req_url_path_append(path) |>
    httr2::req_url_query(!!!query, .multi = "explode") |>
    httr2::req_user_agent("target4-species-ranking (R; httr2)") |>
    httr2::req_retry(max_tries = 5, backoff = function(i) 2^i)
  resp <- httr2::req_perform(req)
  Sys.sleep(pause)
  httr2::resp_body_json(resp, simplifyVector = FALSE)
}

# ---- Boundary ---------------------------------------------------------------

#' Read a site polygon and build a buffer around it (km), both in EPSG:4326.
#' `utm_epsg` is the projected CRS used for buffering and simplifying
#' (32755 = UTM zone 55S, which covers Oro Province, PNG).
site_geometries <- function(path, buffer_km = 25, utm_epsg = 32755,
                            max_wkt_chars = 1500) {
  site <- sf::st_read(path, quiet = TRUE) |> sf::st_make_valid()
  site <- sf::st_union(sf::st_geometry(site))
  proj <- sf::st_transform(site, utm_epsg)
  buf <- sf::st_buffer(proj, buffer_km * 1000)
  sq <- simplify_to_fit(proj, max_wkt_chars)
  bq <- simplify_to_fit(buf, max_wkt_chars)
  list(
    site = site,
    buffer = sf::st_transform(buf, 4326),
    site_query = sq$geom, site_query_tolerance_m = sq$tolerance,
    buffer_query = bq$geom, buffer_query_tolerance_m = bq$tolerance,
    area_km2 = as.numeric(sf::st_area(proj)) / 1e6,
    buffer_km = buffer_km
  )
}

#' GBIF rejects request URLs over about 4,000 characters, so the query
#' polygon is simplified (Douglas-Peucker, in metres) until its WKT fits.
simplify_to_fit <- function(proj, max_chars) {
  for (tol in c(50, 100, 200, 300, 500, 750, 1000, 1500, 2000)) {
    g <- sf::st_transform(sf::st_simplify(proj, dTolerance = tol), 4326)
    if (nchar(gbif_wkt(g)) <= max_chars) return(list(geom = g, tolerance = tol))
  }
  stop("Site polygon is too detailed to send to GBIF even at 2 km tolerance.")
}

#' WKT for GBIF: GBIF needs anticlockwise exterior rings.
gbif_wkt <- function(geom) {
  g <- sf::st_cast(sf::st_geometry(geom), "POLYGON")
  fix <- lapply(g, function(p) {
    rings <- lapply(seq_along(p), function(i) {
      r <- p[[i]]
      a <- sum(r[-nrow(r), 1] * r[-1, 2] - r[-1, 1] * r[-nrow(r), 2]) / 2
      ccw <- a > 0
      # exterior (i == 1) anticlockwise, holes clockwise
      if ((i == 1 && !ccw) || (i > 1 && ccw)) r[nrow(r):1, ] else r
    })
    sf::st_polygon(rings)
  })
  geom <- if (length(fix) == 1) fix[[1]] else sf::st_multipolygon(lapply(fix, unclass))
  sf::st_as_text(geom, digits = 6)
}

# ---- Names ------------------------------------------------------------------

#' Match scientific names to GBIF accepted species keys (cached as JSON).
gbif_match_names <- function(names, kingdoms, cache_dir) {
  d <- file.path(cache_dir, "gbif_match")
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  out <- lapply(seq_along(names), function(i) {
    f <- file.path(d, paste0(gsub("[^A-Za-z0-9]+", "_", names[i]), ".json"))
    m <- if (file.exists(f)) {
      jsonlite::read_json(f, simplifyVector = FALSE)
    } else {
      k <- tools::toTitleCase(tolower(kingdoms[i] %||% ""))
      m <- gbif_get("species/match", list(name = names[i], kingdom = k,
                                          strict = "false"))
      jsonlite::write_json(m, f, auto_unbox = TRUE, null = "null")
      m
    }
    if (i %% 200 == 0) message(sprintf("  matched %d/%d names", i, length(names)))
    ok <- identical(m$rank, "SPECIES") &&
      (m$matchType %||% "") %in% c("EXACT", "FUZZY") &&
      (m$confidence %||% 0) >= 90
    # GBIF sometimes treats an IUCN species as a synonym of a broader species
    # (e.g. six IUCN Actinodaphne species -> A. nitida). Counting the accepted
    # species would give each IUCN species the others' records, so synonyms
    # are counted by their own name key ("name"), which GBIF restricts to
    # records filed under that name.
    syn <- ok && !identical(m$status, "ACCEPTED")
    data.frame(
      scientific_name = names[i],
      gbif_key = if (!ok) NA_character_ else if (syn) as.character(m$usageKey)
                 else as.character(m$speciesKey %||% m$usageKey),
      gbif_key_type = if (!ok) NA_character_ else if (syn) "name" else "species",
      gbif_name = m$species %||% m$scientificName %||% NA_character_,
      gbif_match = m$matchType %||% NA_character_,
      gbif_status = m$status %||% NA_character_,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, out)
}

# ---- Occurrence counts -------------------------------------------------------

#' Records per GBIF species key for one occurrence query, via facets.
gbif_species_counts <- function(query, page = 1000) {
  base <- c(list(limit = 0, facet = "speciesKey", facetLimit = page,
                 hasGeospatialIssue = "false",
                 occurrenceStatus = "PRESENT", basisOfRecord = gbif_basis),
            query)
  counts <- list()
  offset <- 0
  repeat {
    res <- gbif_get("occurrence/search", c(base, list(facetOffset = offset)))
    f <- res$facets
    vals <- if (length(f)) f[[1]]$counts else list()
    if (!length(vals)) break
    counts <- c(counts, vals)
    if (length(vals) < page) break
    offset <- offset + page
  }
  if (!length(counts)) {
    return(data.frame(gbif_key = character(0), n = numeric(0)))
  }
  data.frame(gbif_key = vapply(counts, function(x) as.character(x$name), ""),
             n = vapply(counts, function(x) as.numeric(x$count), 0),
             stringsAsFactors = FALSE)
}

#' Number of records for one GBIF name key (taxonKey) and query.
gbif_count <- function(taxon_key, query) {
  res <- gbif_get("occurrence/search",
                  c(list(limit = 0, taxonKey = taxon_key,
                         hasGeospatialIssue = "false",
                         occurrenceStatus = "PRESENT", basisOfRecord = gbif_basis),
                    query))
  as.numeric(res$count %||% 0)
}

#' Records in the site, the buffer and the whole country.
#' @param keys data frame with gbif_key and gbif_key_type ("species" or "name").
gbif_site_counts <- function(geoms, keys, country, cache_dir) {
  keys <- unique(keys[!is.na(keys$gbif_key), c("gbif_key", "gbif_key_type")])
  id <- paste(keys$gbif_key_type, keys$gbif_key)
  f <- file.path(cache_dir, "gbif_counts.rds")
  if (file.exists(f)) {
    cached <- readRDS(f)
    if (setequal(cached$id, id)) return(cached$counts)
  }
  site_q <- list(geometry = gbif_wkt(geoms$site_query))
  buf_q <- list(geometry = gbif_wkt(geoms$buffer_query))
  sp <- keys$gbif_key[keys$gbif_key_type == "species"]
  message("  GBIF: records inside the site")
  inside <- gbif_species_counts(site_q)
  message("  GBIF: records within the buffer")
  near <- gbif_species_counts(buf_q)
  message("  GBIF: records in the whole country")
  batches <- split(sp, ceiling(seq_along(sp) / 50))
  national <- do.call(rbind, lapply(batches, function(b) {
    gbif_species_counts(list(country = country, speciesKey = b), page = 100)
  }))
  counts <- keys
  counts$n_site <- inside$n[match(counts$gbif_key, inside$gbif_key)]
  counts$n_buffer <- near$n[match(counts$gbif_key, near$gbif_key)]
  counts$n_country <- national$n[match(counts$gbif_key, national$gbif_key)]
  nm <- which(counts$gbif_key_type == "name")
  message(sprintf("  GBIF: %d names GBIF treats as synonyms, counted one by one",
                  length(nm)))
  for (i in nm) {
    k <- counts$gbif_key[i]
    counts$n_site[i] <- gbif_count(k, site_q)
    counts$n_buffer[i] <- gbif_count(k, buf_q)
    counts$n_country[i] <- gbif_count(k, list(country = country))
  }
  for (v in c("n_site", "n_buffer", "n_country")) counts[[v]][is.na(counts[[v]])] <- 0
  saveRDS(list(id = id, counts = counts), f)
  counts
}

# ---- Ranking -----------------------------------------------------------------

#' Evidence tier for a species at the site.
#'   1 Recorded in the site        GBIF record inside the boundary
#'   2 Recorded nearby             GBIF record within the buffer, none inside
#'   3 No records nearby           land or freshwater species, no record in the buffer
#'   4 Marine only                 IUCN lists only the Marine system
site_tier <- function(n_site, n_buffer, systems) {
  marine_only <- !is.na(systems) & nzchar(systems) &
    !grepl("Terrestrial|Freshwater", systems)
  ifelse(marine_only, 4L,
  ifelse(is_true(n_site > 0), 1L,
  ifelse(is_true(n_buffer > 0), 2L, 3L)))
}

site_tier_labels <- c("1" = "Recorded in the site", "2" = "Recorded nearby",
                      "3" = "No records nearby", "4" = "Marine only")

#' Rank species for a site: by evidence tier, then national priority
#' (P1 before P2), then national priority score.
site_rank <- function(ranked) {
  pri <- match(ranked$priority, c("EW", "P1", "P2"))
  o <- order(ranked$site_tier, pri, -ranked$priority_score, ranked$scientific_name)
  out <- ranked[o, , drop = FALSE]
  out$site_rank <- NA_integer_
  for (t in 1:3) {
    i <- which(out$site_tier == t)
    if (!length(i)) next
    key <- paste(pri[o][i], -out$priority_score[i])
    out$site_rank[i] <- match(key, key)  # ties share the first position
  }
  out$site_tier_label <- unname(site_tier_labels[as.character(out$site_tier)])
  out$site_share <- ifelse(out$n_country > 0,
                           round(out$n_buffer / out$n_country, 3), NA)
  rownames(out) <- NULL
  out
}
