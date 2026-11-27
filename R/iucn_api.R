#' Minimal client for the IUCN Red List API v4 (https://api.iucnredlist.org).
#'
#' The token is read from the IUCN_REDLIST_KEY environment variable (put it in
#' ~/.Renviron or a project .Renviron, which is git-ignored). Raw JSON
#' responses are cached on disk so reruns do not hit the API again.

rl_base_url <- "https://api.iucnredlist.org/api/v4"

rl_key <- function() {
  key <- Sys.getenv("IUCN_REDLIST_KEY")
  if (!nzchar(key)) {
    stop("Set IUCN_REDLIST_KEY (e.g. in .Renviron) to your IUCN Red List ",
         "API v4 token. Get one at https://api.iucnredlist.org.", call. = FALSE)
  }
  key
}

#' GET an API path and return the httr2 response (with retries on 429/5xx).
rl_get <- function(path, query = list(), pause = 0.25) {
  req <- httr2::request(rl_base_url) |>
    httr2::req_url_path_append(path) |>
    httr2::req_url_query(!!!query) |>
    httr2::req_headers(Authorization = paste("Bearer", rl_key()),
                       Accept = "application/json") |>
    httr2::req_user_agent("target4-species-ranking (R; httr2)") |>
    httr2::req_retry(max_tries = 6, backoff = function(i) 2^i)
  resp <- httr2::req_perform(req)
  Sys.sleep(pause)
  resp
}

#' All latest global assessments listed for a country (paged).
#' Returns a list of assessment summaries (one per assessment).
fetch_country_assessments <- function(country, cache_dir, refresh = FALSE) {
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  f <- file.path(cache_dir, sprintf("country_%s.json", country))
  if (file.exists(f) && !refresh) {
    return(jsonlite::read_json(f, simplifyVector = FALSE))
  }
  out <- list()
  page <- 1L
  repeat {
    resp <- rl_get(file.path("countries", country),
                   list(latest = "true", scope_code = "1", page = page))
    body <- httr2::resp_body_json(resp, simplifyVector = FALSE)
    a <- body$assessments
    out <- c(out, a)
    total_pages <- suppressWarnings(as.integer(
      httr2::resp_header(resp, "Total-Pages")))
    message(sprintf("  country %s: page %d/%s (%d assessments so far)",
                    country, page, total_pages %||% "?", length(out)))
    if (!length(a) || (!is.na(total_pages) && page >= total_pages)) break
    page <- page + 1L
  }
  jsonlite::write_json(out, f, auto_unbox = TRUE, null = "null")
  out
}

#' Full assessment record by assessment id (cached).
fetch_assessment <- function(assessment_id, cache_dir, refresh = FALSE) {
  d <- file.path(cache_dir, "assessments")
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  f <- file.path(d, sprintf("%s.json", assessment_id))
  if (!file.exists(f) || refresh) {
    resp <- rl_get(file.path("assessment", assessment_id))
    writeLines(httr2::resp_body_string(resp), f, useBytes = TRUE)
  }
  jsonlite::read_json(f, simplifyVector = FALSE)
}

#' Download full assessments for the CR / EN / VU / EW species of a country.
fetch_threatened_assessments <- function(country, cache_dir,
                                         categories = c("CR", "EN", "VU", "EW"),
                                         refresh = FALSE) {
  summaries <- fetch_country_assessments(country, cache_dir, refresh)
  cats <- vapply(summaries, function(a) a$red_list_category_code %||% NA_character_,
                 character(1))
  keep <- summaries[cats %in% categories]
  ids <- unique(vapply(keep, function(a) as.character(a$assessment_id),
                       character(1)))
  message(sprintf("Country %s: %d assessments, %d in %s.", country,
                  length(summaries), length(ids),
                  paste(categories, collapse = "/")))
  res <- vector("list", length(ids))
  for (i in seq_along(ids)) {
    if (i %% 100 == 0 || i == length(ids)) {
      message(sprintf("  assessments %d/%d", i, length(ids)))
    }
    res[[i]] <- fetch_assessment(ids[i], cache_dir, refresh)
  }
  res
}
