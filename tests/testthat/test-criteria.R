test_that("criteria strings are tokenised", {
  expect_setequal(parse_criteria("A2cd+3cd; B1ab(i,ii,iii)+2ab(iii,v); C2a(i)"),
                  c("A2", "A3", "B1", "B1b_i", "B1b_ii", "B1b_iii",
                    "B2", "B2b_iii", "B2b_v", "C2"))
  expect_setequal(parse_criteria("D"), "D")
  expect_setequal(parse_criteria("D1+2"), c("D1", "D2"))
  expect_setequal(parse_criteria("C1+2a(ii)"), c("C1", "C2"))
  expect_setequal(parse_criteria("A4cde"), "A4")
  expect_setequal(parse_criteria("E"), "E")
  expect_setequal(parse_criteria(" B1ab(iii) ; D "), c("B1", "B1b_iii", "D"))
  expect_length(parse_criteria(NA), 0)
  expect_length(parse_criteria(""), 0)
})

test_that("has_letter ignores B subitems", {
  expect_true(has_letter(parse_criteria("B2ab(iii)"), "B"))
  expect_true(has_letter(parse_criteria("D1"), "D"))
  expect_false(has_letter(parse_criteria("A2c"), "C"))
})
