#' Score and rank species following Akcakaya et al. (2026), Section 2.3.
#'
#' Input: a standardised species table (see standardise.R for the columns).
#' Steps:
#'   1. Keep species that qualify in the focal country (`in_focal`).
#'   2. EW species are listed unranked at the top (Section 2.3.3).
#'   3. PS1 = Risk x Endemism x Decline x Restriction        (Eq. 1)
#'   4. For PS1 == 0: PS2 = Risk x Endemism x max(Decline, Restriction) (Eq. 2)
#'   5. Ranked list = EW, then PS1 > 0 by PS1 (Priority 1), then PS2 > 0 by
#'      PS2 (Priority 2). Ties share a rank.
score_species <- function(species, missing_trend_is_unknown = FALSE) {
  n <- nrow(species)
  species$risk_w <- risk_weight(species$category)
  species$decline_w <- vapply(seq_len(n), function(i) {
    cd <- list(pop = species$cd_pop[i], area = species$cd_area[i],
               loc = species$cd_loc[i], eoo = species$cd_eoo[i],
               aoo = species$cd_aoo[i], subp = species$cd_subp[i])
    decline_weight(species$category[i], parse_criteria(species$criteria[i]),
                   species$population_trend[i], cd, missing_trend_is_unknown)
  }, numeric(1))
  species$restriction_w <- vapply(seq_len(n), function(i) {
    restriction_weight(species$category[i], parse_criteria(species$criteria[i]),
                       species$pop_size[i], species$aoo[i], species$eoo[i],
                       species$n_locations[i], species$area_restricted[i])
  }, numeric(1))
  species$endemism_w <- endemism_weight(species$in_focal, species$n_countries)

  species$PS1 <- with(species, risk_w * endemism_w * decline_w * restriction_w)
  species$PS2 <- with(species, ifelse(PS1 == 0,
                                      risk_w * endemism_w *
                                        pmax(decline_w, restriction_w), 0))
  is_ew <- species$category %in% "EW" & is_true(species$in_focal)
  species$priority <- ifelse(is_ew, "EW",
                      ifelse(species$PS1 > 0, "P1",
                      ifelse(species$PS2 > 0, "P2", NA_character_)))
  species$PS1[is_ew] <- NA
  species$PS2[is_ew] <- NA
  species
}

#' Build the national ranked list from a scored table.
rank_species <- function(scored) {
  listed <- scored[!is.na(scored$priority), , drop = FALSE]
  listed$priority_score <- ifelse(listed$priority == "P1", listed$PS1,
                                  listed$PS2)
  grp <- match(listed$priority, c("EW", "P1", "P2"))
  ord <- order(grp, -ifelse(is.na(listed$priority_score), Inf,
                            listed$priority_score),
               listed$scientific_name)
  listed <- listed[ord, , drop = FALSE]

  listed$rank_in_priority <- NA_integer_
  listed$rank <- NA_integer_
  offset <- 0L
  for (p in c("P1", "P2")) {
    idx <- which(listed$priority == p)
    if (!length(idx)) next
    r <- rank(-listed$priority_score[idx], ties.method = "min")
    listed$rank_in_priority[idx] <- as.integer(r)
    listed$rank[idx] <- as.integer(r) + offset
    offset <- offset + length(idx)
  }
  rownames(listed) <- NULL
  listed
}
