#' Weights from Akcakaya et al. (2026), Global Ecology and Conservation 72:
#' e04536, Tables 1-4. Each function scores one species; `score_species()`
#' in scoring.R applies them row by row.

# ---- Table 1: Risk ---------------------------------------------------------
risk_weight <- function(category) {
  w <- c(CR = 4, EN = 2, VU = 1)
  out <- unname(w[category])
  out[is.na(out)] <- 0
  out
}

# ---- Table 2: Decline -------------------------------------------------------
#' @param category Red List category code ("CR", "EN", "VU", ...).
#' @param tokens Output of parse_criteria().
#' @param trend Population trend text ("Decreasing", "Unknown", ...).
#' @param cd Named logical list of continuing-decline flags: pop, area, loc,
#'   eoo, aoo, subp (NA = not recorded).
#' @param missing_trend_is_unknown Treat a blank trend as "Unknown" (0.5).
decline_weight <- function(category, tokens, trend, cd,
                           missing_trend_is_unknown = FALSE) {
  has <- function(...) any(c(...) %in% tokens)
  CR <- identical(category, "CR"); EN <- identical(category, "EN")
  VU <- identical(category, "VU")
  trend <- if (is.null(trend) || is.na(trend)) NA_character_ else tolower(trend)
  b_items <- c(paste0("B1b_", c("i", "ii", "iii", "iv")),
               paste0("B2b_", c("i", "ii", "iii", "iv")))
  ok <- function(name) isTRUE(cd[[name]])

  if (CR && has("A3", "A4", "E")) return(10)
  if (CR && has("C1")) return(8)
  if (EN && has("A3", "A4", "E")) return(6)
  if (CR && has("A1", "A2")) return(5)
  if ((VU && has("A3", "A4", "E")) || (EN && has("C1"))) return(4)
  if ((VU && has("C1")) || (EN && has("A1", "A2"))) return(3)
  if (has("C2", "B1b_v", "B2b_v") || ok("pop") ||
      identical(trend, "decreasing") || (VU && has("A1", "A2"))) return(2)
  if (has(b_items) || ok("area") || ok("loc") || ok("eoo") || ok("aoo") ||
      ok("subp")) return(1)
  if (identical(trend, "unknown") ||
      (missing_trend_is_unknown && is.na(trend))) return(0.5)
  0
}

# ---- Table 3: Restriction ---------------------------------------------------
#' @param pop Population size (mature individuals), numeric or NA.
#' @param aoo,eoo Area of occupancy / extent of occurrence in km2, or NA.
#' @param loc Number of locations, or NA.
#' @param area_restricted Logical "AreaRestricted" flag, or NA.
restriction_weight <- function(category, tokens, pop, aoo, eoo, loc,
                               area_restricted) {
  has <- function(...) any(c(...) %in% tokens)
  CR <- identical(category, "CR"); EN <- identical(category, "EN")
  VU <- identical(category, "VU")
  lt <- function(x, v) isTRUE(x < v)
  le <- function(x, v) isTRUE(x <= v)
  eq <- function(x, v) isTRUE(x == v)

  if ((CR && has_letter(tokens, "D")) || lt(pop, 50)) return(10)
  if ((CR && has_letter(tokens, "B")) || lt(aoo, 10) || lt(eoo, 100) ||
      lt(pop, 100)) return(9)
  if ((CR && has_letter(tokens, "C")) || (EN && has_letter(tokens, "D")) ||
      lt(pop, 250)) return(8)
  if (lt(pop, 500)) return(7)
  if ((VU && has("D1")) || lt(pop, 1000) || eq(loc, 1)) return(6)
  if ((EN && has_letter(tokens, "C")) || lt(pop, 2500) || eq(loc, 2)) return(5)
  if (le(loc, 5) || lt(pop, 5000) || (VU && has("D2")) ||
      isTRUE(area_restricted)) return(4)
  if ((EN && has_letter(tokens, "B")) || lt(aoo, 500) || lt(eoo, 5000)) return(3)
  if ((VU && has_letter(tokens, "C")) || lt(pop, 10000) || le(loc, 10)) return(2)
  if ((VU && has_letter(tokens, "B")) || lt(aoo, 2000) || lt(eoo, 20000)) return(1)
  0
}

# ---- Table 4: Endemism ------------------------------------------------------
#' 10 / number of countries where the species is extant (and native), if it
#' qualifies in the focal country; otherwise 0.
endemism_weight <- function(in_focal, n_countries) {
  ifelse(is_true(in_focal) & !is.na(n_countries) & n_countries > 0,
         10 / n_countries, 0)
}
