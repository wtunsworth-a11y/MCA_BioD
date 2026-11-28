#' Convert IUCN API v4 assessment records into the standardised species table
#' that score_species() expects.
#'
#' Presence/origin rules (Section 2.3.1 and Table 4 of the paper):
#'   * A species qualifies in the focal country if it is recorded there with a
#'     qualifying origin and presence "Extant" or "Possibly Extinct"; for EW
#'     species "Extinct Post-1500" also qualifies.
#'   * Qualifying origins: Native, Reintroduced, Assisted Colonisation.
#'   * Endemism denominator = number of countries (two-letter codes only, not
#'     sub-national units such as "NWG-IJ") with a qualifying presence and
#'     origin.

default_presence <- c("Extant", "Possibly Extinct")
default_origin <- c("Native", "Reintroduced", "Assisted Colonisation")

#' One row per assessment.
standardise_assessments <- function(assessments, focal,
                                    presence = default_presence,
                                    origin = default_origin,
                                    species_only = TRUE,
                                    num_summary = "max") {
  rows <- lapply(assessments, standardise_one, focal = focal,
                 presence = presence, origin = origin,
                 num_summary = num_summary)
  df <- do.call(rbind, lapply(rows, as.data.frame, stringsAsFactors = FALSE))
  if (species_only) df <- df[is_true(df$is_species), , drop = FALSE]
  rownames(df) <- NULL
  df
}

standardise_one <- function(a, focal, presence, origin, num_summary) {
  tx <- a$taxon %||% list()
  si <- a$supplementary_info %||% list()
  cat_code <- a$red_list_category$code %||% NA_character_
  # First non-null field among `names` (the API spells some fields oddly,
  # e.g. "estimated_extent_of_occurence").
  g <- function(...) {
    for (n in c(...)) if (!is.null(si[[n]])) return(si[[n]])
    NA
  }

  locs <- a$locations %||% list()
  lcode <- vapply(locs, function(l) l$code %||% NA_character_, character(1))
  lpres <- vapply(locs, function(l) en_text(l$presence), character(1))
  lorig <- vapply(locs, function(l) en_text(l$origin), character(1))
  is_country <- !is.na(lcode) & grepl("^[A-Z]{2}$", lcode)
  ok_origin <- lorig %in% origin

  focal_pres <- presence
  if (identical(cat_code, "EW")) focal_pres <- c(presence, "Extinct Post-1500")
  in_focal_rows <- lcode %in% focal & lpres %in% focal_pres & ok_origin
  qualifying <- is_country & lpres %in% presence & ok_origin
  n_countries <- length(unique(lcode[qualifying]))
  # If the focal country qualifies but is somehow not counted (e.g. it is a
  # sub-national code), make sure it is in the denominator.
  if (any(in_focal_rows) && !focal %in% lcode[qualifying]) {
    n_countries <- n_countries + 1L
  }
  fi <- which(lcode %in% focal)[1]

  list(
    assessment_id = as.character(a$assessment_id %||% NA),
    sis_taxon_id = as.character(a$sis_taxon_id %||% NA),
    scientific_name = tx$scientific_name %||% NA_character_,
    kingdom = tx$kingdom_name %||% NA_character_,
    phylum = tx$phylum_name %||% NA_character_,
    class = tx$class_name %||% NA_character_,
    order = tx$order_name %||% NA_character_,
    family = tx$family_name %||% NA_character_,
    is_species = isTRUE(tx$species %||% TRUE),
    category = cat_code,
    criteria_version = a$red_list_category$version %||% NA_character_,
    criteria = a$criteria %||% NA_character_,
    year_published = as.character(a$year_published %||% NA),
    possibly_extinct = isTRUE(a$possibly_extinct),
    population_trend = en_text(a$population_trend),
    pop_size = parse_num(g("population_size"), num_summary),
    aoo = parse_num(g("estimated_area_of_occupancy"), num_summary),
    eoo = parse_num(g("estimated_extent_of_occurence",
                      "estimated_extent_of_occurrence"), num_summary),
    n_locations = parse_num(g("number_of_locations"), num_summary),
    area_restricted = parse_yes(g("area_restricted_is_restricted")),
    cd_pop = parse_yes(g("population_continuing_decline")),
    cd_area = parse_yes(g("continuing_decline_in_area")),
    cd_loc = parse_yes(g("continuing_decline_in_number_of_locations")),
    cd_eoo = parse_yes(g("continuing_decline_in_extent_of_occurence",
                         "continuing_decline_in_extent_of_occurrence")),
    cd_aoo = parse_yes(g("continuing_decline_in_area_of_occupancy")),
    cd_subp = parse_yes(g("continuing_decline_in_subpopulations")),
    in_focal = any(in_focal_rows),
    focal_presence = if (is.na(fi)) NA_character_ else lpres[fi],
    focal_origin = if (is.na(fi)) NA_character_ else lorig[fi],
    n_countries = n_countries,
    systems = paste(unique(vapply(a$systems %||% list(), en_text, character(1))),
                    collapse = "; "),
    elev_lower = parse_num(g("lower_elevation_limit"), "min"),
    elev_upper = parse_num(g("upper_elevation_limit"), "max"),
    url = a$url %||% NA_character_
  )
}
