#' Parse IUCN Red List criteria strings into a set of tokens.
#'
#' Examples of input: "A2cd+3cd; B1ab(i,ii,iii)+2ab(i,ii,iii); C2a(i)",
#' "D", "D1+2", "C1+2a(ii)", "B1ab(iii,v)".
#'
#' Output tokens:
#'   * main criteria with sub-number: "A1".."A4", "B1", "B2", "C1", "C2",
#'     "D1", "D2"; a bare letter ("D", "E", or "C" when written without a
#'     number) gives just the letter.
#'   * B subcriterion b items: "B1b_i", ..., "B2b_v".
#'
#' The parser is written for version 3.1 criteria. Version 2.3 strings have the
#' same syntax and are parsed the same way; their meanings differ slightly
#' (see README), which is why the output table keeps `criteria_version`.
parse_criteria <- function(crit) {
  if (is.null(crit) || length(crit) == 0 || is.na(crit) || !nzchar(trimws(crit))) {
    return(character(0))
  }
  s <- gsub("\\s+", "", crit)
  parts <- strsplit(s, ";", fixed = TRUE)[[1]]
  tokens <- character(0)
  for (p in parts) {
    if (!nzchar(p)) next
    letter <- toupper(substr(p, 1, 1))
    if (!letter %in% c("A", "B", "C", "D", "E")) next
    rest <- substr(p, 2, nchar(p))
    pieces <- if (nzchar(rest)) strsplit(rest, "+", fixed = TRUE)[[1]] else ""
    for (pc in pieces) {
      num <- regmatches(pc, regexpr("^[0-9]+", pc))
      qual <- sub("^[0-9]+", "", pc)
      code <- if (length(num)) paste0(letter, num) else letter
      tokens <- c(tokens, code)
      if (letter == "B") {
        m <- regmatches(qual, regexpr("b\\([^)]*\\)", qual))
        if (length(m)) {
          items <- strsplit(gsub("^b\\(|\\)$", "", m), ",", fixed = TRUE)[[1]]
          items <- tolower(trimws(items))
          items <- items[items %in% c("i", "ii", "iii", "iv", "v")]
          tokens <- c(tokens, paste0(code, "b_", items))
        }
      }
    }
  }
  unique(tokens)
}

#' Does the token set meet any criterion under `letter`, e.g. "B" (B1 or B2)?
has_letter <- function(tokens, letter) {
  any(startsWith(tokens, letter) & !grepl("b_", tokens, fixed = TRUE))
}
