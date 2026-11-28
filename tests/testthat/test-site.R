test_that("site tiers follow GBIF evidence and IUCN systems", {
  expect_equal(
    site_tier(n_site = c(3, 0, 0, 5, 0),
              n_buffer = c(3, 2, 0, 5, 0),
              systems = c("Terrestrial", "Terrestrial; Freshwater (=Inland waters)",
                          "Terrestrial", "Marine", "")),
    c(1L, 2L, 3L, 4L, 3L))
  # Marine plus another system is not "marine only"
  expect_equal(site_tier(0, 0, "Marine; Terrestrial"), 3L)
})

test_that("site ranking orders by tier, national priority, then score", {
  x <- data.frame(
    scientific_name = c("a", "b", "c", "d", "e", "f"),
    priority = c("P2", "P1", "P1", "P1", "P1", "P1"),
    priority_score = c(500, 40, 160, 160, 360, 10),
    site_tier = c(1L, 1L, 1L, 1L, 2L, 4L),
    n_buffer = c(1, 1, 1, 1, 2, 0), n_country = c(10, 4, 2, 0, 4, 1),
    stringsAsFactors = FALSE)
  r <- site_rank(x)
  expect_equal(r$scientific_name, c("c", "d", "b", "a", "e", "f"))
  expect_equal(r$site_rank, c(1L, 1L, 3L, 4L, 1L, NA))
  expect_equal(r$site_tier_label[1], "Recorded in the site")
  expect_equal(r$site_share[r$scientific_name == "c"], 0.5)
  expect_true(is.na(r$site_share[r$scientific_name == "d"]))
})

test_that("GBIF WKT has an anticlockwise exterior ring", {
  cw <- sf::st_sfc(sf::st_polygon(list(rbind(c(0, 0), c(0, 1), c(1, 1), c(1, 0), c(0, 0)))))
  w <- gbif_wkt(cw)
  pts <- regmatches(w, gregexpr("-?[0-9.]+ -?[0-9.]+", w))[[1]]
  xy <- do.call(rbind, lapply(strsplit(pts, " "), as.numeric))
  a <- sum(xy[-nrow(xy), 1] * xy[-1, 2] - xy[-1, 1] * xy[-nrow(xy), 2]) / 2
  expect_gt(a, 0)
})
