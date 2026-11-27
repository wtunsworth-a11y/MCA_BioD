# Run from the repository root: Rscript tests/testthat.R
library(testthat)
for (f in list.files("R", pattern = "\\.R$", full.names = TRUE)) source(f)
test_dir("tests/testthat", reporter = "summary", stop_on_failure = TRUE)
