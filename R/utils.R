#' Small helpers shared by the Target 4 pipeline.

`%||%` <- function(a, b) if (is.null(a)) b else a

#' Parse a Red List numeric field that may be a single value or a range.
#'
#' Red List supplementary fields are free text: "424000", "1000-2500",
#' ">10000", "c. 500", "10,000", "Unknown". All numbers in the string are
#' extracted and summarised with `summary` (default "max", the conservative
#' choice: a species only counts as restricted if the whole range is below the
#' threshold). Returns NA when no number is present.
parse_num <- function(x, summary = c("max", "min", "mean")) {
  summary <- match.arg(summary)
  fn <- switch(summary, max = max, min = min, mean = mean)
  vapply(x, function(v) {
    if (is.null(v) || length(v) == 0 || is.na(v)) return(NA_real_)
    s <- gsub(",", "", as.character(v))
    nums <- regmatches(s, gregexpr("[0-9]+(\\.[0-9]+)?", s))[[1]]
    if (length(nums) == 0) return(NA_real_)
    fn(as.numeric(nums))
  }, numeric(1), USE.NAMES = FALSE)
}

#' Interpret Red List yes/no style fields ("Yes", "No", TRUE, "Unknown").
#' Returns TRUE / FALSE / NA.
parse_yes <- function(x) {
  vapply(x, function(v) {
    if (is.null(v) || length(v) == 0 || is.na(v)) return(NA)
    if (is.logical(v)) return(v)
    s <- tolower(trimws(as.character(v)))
    if (s %in% c("yes", "true", "y", "1")) return(TRUE)
    if (s %in% c("no", "false", "n", "0")) return(FALSE)
    NA
  }, logical(1), USE.NAMES = FALSE)
}

#' TRUE only when the condition is TRUE (NA -> FALSE), vectorised.
is_true <- function(x) !is.na(x) & x

#' Extract an English description from IUCN v4 `{"description":{"en":..}}`
#' objects, or return a plain string unchanged.
en_text <- function(x) {
  if (is.null(x)) return(NA_character_)
  if (is.list(x)) {
    d <- x$description %||% x
    return(as.character(d$en %||% d[[1]] %||% NA_character_))
  }
  as.character(x)
}
