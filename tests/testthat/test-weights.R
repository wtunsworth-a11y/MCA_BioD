cd0 <- list(pop = NA, area = NA, loc = NA, eoo = NA, aoo = NA, subp = NA)
dw <- function(cat, crit, trend = NA, cd = cd0, ...) {
  decline_weight(cat, parse_criteria(crit), trend, cd, ...)
}
rw <- function(cat, crit, pop = NA, aoo = NA, eoo = NA, loc = NA, ar = NA) {
  restriction_weight(cat, parse_criteria(crit), pop, aoo, eoo, loc, ar)
}

test_that("Table 1 risk weights", {
  expect_equal(risk_weight(c("CR", "EN", "VU", "NT", "LC", "DD", "EX", "EW")),
               c(4, 2, 1, 0, 0, 0, 0, 0))
})

test_that("Table 2 decline weights, row by row", {
  expect_equal(dw("CR", "A3c"), 10)
  expect_equal(dw("CR", "A4c"), 10)
  expect_equal(dw("CR", "E"), 10)
  expect_equal(dw("CR", "C1"), 8)
  expect_equal(dw("EN", "A3c"), 6)
  expect_equal(dw("EN", "E"), 6)
  expect_equal(dw("CR", "A2c"), 5)
  expect_equal(dw("CR", "A1a"), 5)
  expect_equal(dw("VU", "A4d"), 4)
  expect_equal(dw("EN", "C1"), 4)
  expect_equal(dw("VU", "C1"), 3)
  expect_equal(dw("EN", "A2bd"), 3)
  expect_equal(dw("EN", "C2a(i)"), 2)
  expect_equal(dw("CR", "B1ab(v)"), 2)
  expect_equal(dw("EN", "B2ab(ii,v)"), 2)
  expect_equal(dw("VU", "A2cd"), 2)
  expect_equal(dw("CR", "D", trend = "Decreasing"), 2)
  expect_equal(dw("CR", "D", cd = modifyList(cd0, list(pop = TRUE))), 2)
  expect_equal(dw("EN", "B1ab(iii)"), 1)
  expect_equal(dw("CR", "D", cd = modifyList(cd0, list(aoo = TRUE))), 1)
  expect_equal(dw("CR", "D", trend = "Unknown"), 0.5)
  expect_equal(dw("CR", "D", trend = "Stable"), 0)
  expect_equal(dw("CR", "D"), 0)
  expect_equal(dw("CR", "D", missing_trend_is_unknown = TRUE), 0.5)
})

test_that("Table 2 takes the highest qualifying weight", {
  # CR A2 (5) and C1 (8) -> 8
  expect_equal(dw("CR", "A2c; C1", trend = "Decreasing"), 8)
})

test_that("Table 3 restriction weights, row by row", {
  expect_equal(rw("CR", "D"), 10)
  expect_equal(rw("VU", "A2c", pop = 40), 10)
  expect_equal(rw("CR", "B1ab(iii)"), 9)
  expect_equal(rw("LC", "", aoo = 8), 9)
  expect_equal(rw("LC", "", eoo = 90), 9)
  expect_equal(rw("LC", "", pop = 99), 9)
  expect_equal(rw("CR", "C2a(i)"), 8)
  expect_equal(rw("EN", "D"), 8)
  expect_equal(rw("LC", "", pop = 249), 8)
  expect_equal(rw("LC", "", pop = 499), 7)
  expect_equal(rw("VU", "D1"), 6)
  expect_equal(rw("LC", "", pop = 999), 6)
  expect_equal(rw("LC", "", loc = 1), 6)
  expect_equal(rw("EN", "C2a(i)"), 5)
  expect_equal(rw("LC", "", pop = 2499), 5)
  expect_equal(rw("LC", "", loc = 2), 5)
  expect_equal(rw("LC", "", loc = 5), 4)
  expect_equal(rw("LC", "", pop = 4999), 4)
  expect_equal(rw("VU", "D2"), 4)
  expect_equal(rw("LC", "", ar = TRUE), 4)
  expect_equal(rw("EN", "B1ab(iii)"), 3)
  expect_equal(rw("LC", "", aoo = 499), 3)
  expect_equal(rw("LC", "", eoo = 4999), 3)
  expect_equal(rw("VU", "C2a(i)"), 2)
  expect_equal(rw("LC", "", pop = 9999), 2)
  expect_equal(rw("LC", "", loc = 10), 2)
  expect_equal(rw("VU", "B1ab(iii)"), 1)
  expect_equal(rw("LC", "", aoo = 1999), 1)
  expect_equal(rw("LC", "", eoo = 19999), 1)
  expect_equal(rw("VU", "A2c", pop = 50000, eoo = 424000), 0)
  expect_equal(rw("CR", "A2c"), 0)
})

test_that("Table 4 endemism", {
  expect_equal(endemism_weight(c(TRUE, TRUE, FALSE, TRUE), c(1, 4, 1, 0)),
               c(10, 2.5, 0, 0))
})

test_that("numeric parsing handles ranges and text", {
  expect_equal(parse_num(c("424000", "1000-2500", ">10,000", "Unknown", NA)),
               c(424000, 2500, 10000, NA, NA))
  expect_equal(parse_num("1000-2500", "min"), 1000)
  expect_equal(parse_yes(c("Yes", "No", "Unknown", NA)), c(TRUE, FALSE, NA, NA))
})
