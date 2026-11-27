# Synthetic records shaped like IUCN API v4 /assessment/{id} responses.
mk <- function(id, name, cat, crit = NULL, trend = "Stable", locs = list(),
               si = list(), species = TRUE, version = "3.1") {
  list(assessment_id = id, sis_taxon_id = id, criteria = crit,
       year_published = "2020", possibly_extinct = FALSE,
       taxon = list(scientific_name = name, kingdom_name = "ANIMALIA",
                    phylum_name = "CHORDATA", class_name = "AVES",
                    order_name = "X", family_name = "Y", species = species),
       red_list_category = list(code = cat, version = version),
       population_trend = list(description = list(en = trend), code = "0"),
       supplementary_info = si, locations = locs)
}
loc <- function(code, presence = "Extant", origin = "Native") {
  list(code = code, presence = presence, origin = origin,
       description = list(en = code))
}

recs <- list(
  # PS1 = 4 * 10 * 10 * 10 = 4000 (CR A3 + D, endemic)
  mk(1, "Top endemic", "CR", "A3c; D", "Decreasing", list(loc("PG"))),
  # Two countries plus a sub-national unit that must not be counted:
  # PS1 = 2 * 5 * 3 (EN A2) * 3 (EN B) = 90
  mk(2, "Shared EN", "EN", "A2c; B1ab(iii)", "Decreasing",
     list(loc("PG"), loc("NWG-IJ"), loc("ID"))),
  # Restricted but not declining: PS1 = 0, PS2 = 1 * 10 * 6 (VU D1) = 60
  mk(3, "Stable VU D1", "VU", "D1", "Stable", list(loc("PG"))),
  # EW: unranked at top
  mk(4, "Wild-extinct", "EW", NULL, "Unknown",
     list(loc("PG", presence = "Extinct Post-1500"))),
  # Vagrant in PG: excluded
  mk(5, "Vagrant", "CR", "D", "Decreasing",
     list(loc("PG", origin = "Vagrant"), loc("AU"))),
  # Widespread VU A2: decline 2 (VU A2), restriction 0 (EOO large):
  # PS1 = 0, PS2 = 1 * 5 * 2 = 10
  mk(6, "Wide VU", "VU", "A2c", "Stable", list(loc("PG"), loc("AU")),
     si = list(estimated_extent_of_occurence = "424000")),
  # Not threatened: risk 0, never listed
  mk(10, "Near threatened", "NT", NULL, "Decreasing", list(loc("PG"))),
  # Ties with record 1 (4000); breaks alphabetically, shares rank 1
  mk(7, "Another top", "CR", "A4c; D", "Decreasing", list(loc("PG"))),
  # Restriction via supplementary data (pop < 50 -> 10), decline via C2 (2):
  # PS1 = 2 * 10 * 2 * 10 = 400
  mk(8, "Small pop", "EN", "C2a(i)", "Unknown", list(loc("PG")),
     si = list(population_size = "20-45")),
  # Subpopulation assessment: dropped when species_only = TRUE
  mk(9, "Subpop", "CR", "D", "Decreasing", list(loc("PG")), species = FALSE)
)

test_that("standardise_assessments extracts fields and presence rules", {
  sp <- standardise_assessments(recs, "PG")
  expect_false("Subpop" %in% sp$scientific_name)
  row <- function(n) sp[sp$scientific_name == n, ]
  expect_equal(row("Shared EN")$n_countries, 2)
  expect_false(row("Vagrant")$in_focal)
  expect_true(row("Wild-extinct")$in_focal)
  expect_equal(row("Wide VU")$eoo, 424000)
  expect_equal(row("Small pop")$pop_size, 45)
  expect_equal(row("Stable VU D1")$population_trend, "Stable")
})

test_that("scoring follows Eq. 1 and Eq. 2", {
  sp <- score_species(standardise_assessments(recs, "PG"))
  s <- function(n) sp[sp$scientific_name == n, ]
  expect_equal(s("Top endemic")$PS1, 4000)
  expect_equal(s("Shared EN")$PS1, 90)
  expect_equal(s("Stable VU D1")$PS1, 0)
  expect_equal(s("Stable VU D1")$PS2, 60)
  expect_equal(s("Small pop")$PS1, 400)
  expect_equal(s("Wild-extinct")$priority, "EW")
  expect_equal(s("Wide VU")$PS2, 10)
  expect_true(is.na(s("Near threatened")$priority))
  expect_true(is.na(s("Vagrant")$priority))
})

test_that("ranked list orders EW, P1, P2 with shared ranks for ties", {
  sp <- score_species(standardise_assessments(recs, "PG"))
  rk <- rank_species(sp[is_true(sp$in_focal), ])
  expect_equal(rk$scientific_name,
               c("Wild-extinct", "Another top", "Top endemic", "Small pop",
                 "Shared EN", "Stable VU D1", "Wide VU"))
  expect_equal(rk$priority, c("EW", "P1", "P1", "P1", "P1", "P2", "P2"))
  expect_equal(rk$rank, c(NA, 1L, 1L, 3L, 4L, 5L, 6L))
  expect_equal(rk$rank_in_priority, c(NA, 1L, 1L, 3L, 4L, 1L, 2L))
})
