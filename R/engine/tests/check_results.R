## =====================================================================
##  The check at the end of every run (run_all.R): are all outputs there,
##  and is every number in them a number?
##
##    - a results file for every study that was run, all with the commit of
##      the package under test the run used (tested_package, R/project/engine_settings/settings.R)
##    - every table of every file: no NaN, no Inf, no NA except the blanks
##      its study declares (each with its reason), and no empty table except
##      those its study declares for the smoke test
##
##  The smoke test (and so every push to main or v2, check.yml, and every image build)
##  stops with an error when something is wrong; a real run reports it in
##  its log, as its results are written and should not be lost. The figures
##  are checked by make_figures.R, which draws them.
## =====================================================================

## Blanks by design (a column NA on purpose) and tables empty in the smoke
## test are declared by each study in its design.R (declared_blanks,
## declared_empty_in_smoke; R/engine/study_form.R)

## The problems in one study's results file (character(0) for none)
check_results_file <- function(file, study, package_commit, smoke) {
  if (!file.exists(file)) return(sprintf("%s: no results file", study))
  results <- readRDS(file)
  problems <- character(0)

  made_with <- results$setup[[paste0(tested_package, "_commit")]]
  if (!identical(made_with, package_commit)) {
    problems <- c(problems, sprintf(
      "%s: made with %s %s, not %s", study, tested_package, made_with, package_commit
    ))
  }

  for (name in names(results$tables)) {
    table <- as.data.frame(results$tables[[name]])
    where <- sprintf("%s, table %s", study, name)

    if (nrow(table) == 0) {
      if (!(smoke && name %in% declared_empty_in_smoke[[study]])) {
        problems <- c(problems, sprintf("%s: empty", where))
      }
      next
    }

    # the blanks this table may have
    allowed <- matrix(FALSE, nrow(table), ncol(table), dimnames = list(NULL, names(table)))
    for (blank in declared_blanks) {
      if (blank$study == study && blank$table == name) {
        allowed[blank$when(table), blank$columns] <- TRUE
      }
    }

    for (column in names(table)) {
      values <- table[[column]]
      is_nan <- if (is.numeric(values)) is.nan(values) else rep(FALSE, length(values))
      nan <- sum(is_nan)
      inf <- if (is.numeric(values)) sum(is.infinite(values)) else 0
      na <- sum(is.na(values) & !is_nan & !allowed[, column])
      if (nan + inf + na > 0) {
        problems <- c(problems, sprintf(
          "%s, column %s: %d NA, %d NaN, %d Inf", where, column, na, nan, inf
        ))
      }
    }
  }
  problems
}

## Checks the results of the studies that were run; stops in the smoke test
## when anything is wrong
check_results <- function(results_folder, studies, package_commit, smoke) {
  problems <- character(0)
  for (study in studies) {
    file <- file.path(results_folder, sprintf("study_%s.rds", study))
    problems <- c(problems, check_results_file(file, study, package_commit, smoke))
  }

  if (length(problems) == 0) {
    message("Check of the outputs: every results file is there, every number is a number.")
    return(invisible(TRUE))
  }
  report <- paste0("Check of the outputs found ", length(problems), " problem(s):\n",
                   paste0("  - ", problems, collapse = "\n"))
  if (smoke) stop(report, call. = FALSE)
  message(report)
  invisible(FALSE)
}
