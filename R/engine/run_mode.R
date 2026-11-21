## =====================================================================
##  Which kind of run this is, and where its files go
##
##    a full run        Rscript run_all.R
##    the smoke test    VALIDATION_SMOKE=1  a corner of each design, to test the
##                      code (R/engine/tests/README.md)
##    the dry run       VALIDATION_DRY=1    the smoke test's design with the
##                      expensive calls replayed (R/engine/tests/dry_run.R)
##    a recording       VALIDATION_SMOKE=1 VALIDATION_RECORD=1  a smoke test that
##                      records those calls for the dry run
##    a timing run      VALIDATION_TIMING=<fraction>  the full design with that
##                      fraction of the datasets (R/engine/run_time/)
##
##  Every process sources this file (R/engine/load_code.R), so each kind of
##  run keeps its own store, results and figures and never mixes with a
##  real run.
## =====================================================================

dry <- identical(Sys.getenv("VALIDATION_DRY"), "1")
recording <- identical(Sys.getenv("VALIDATION_RECORD"), "1")
# the dry run has the smoke test's design (set here, so every process it
# starts inherits it)
if (dry) Sys.setenv(VALIDATION_SMOKE = "1")
smoke <- identical(Sys.getenv("VALIDATION_SMOKE"), "1")
timing_fraction <- suppressWarnings(as.numeric(Sys.getenv("VALIDATION_TIMING", NA)))


## ---- Where the files go ------------------------------------------------------------

## The folder of the results: results/ for a full run, cache/ otherwise
results_root_of <- function(dry, smoke, timing = FALSE) {
  if (dry) return(file.path("cache", "dry_results"))
  if (smoke) return(file.path("cache", "smoke_results"))
  if (timing) return(file.path("cache", "timing", "results"))
  "results"
}

## The folder of the figures
figure_folder_of <- function(dry, smoke) {
  if (dry) return(file.path("cache", "dry_figures"))
  if (smoke) return(file.path("cache", "smoke_figures"))
  file.path("results", "figures")
}

## The targets store (a timing run gives its own, R/engine/run_time/time_study.R)
store <- if (dry) {
  file.path("cache", "targets_dry")
} else if (smoke) {
  file.path("cache", "targets_smoke")
} else {
  "_targets"
}
results_root <- results_root_of(dry, smoke, timing = !is.na(timing_fraction))
figure_folder <- figure_folder_of(dry, smoke)


## ---- How much to run ---------------------------------------------------------------

## How often datasets() was asked: a study whose design never asks runs in
## full also in a timing run (R/engine/run_time/time_study.R)
datasets_asked <- new.env()
datasets_asked$times <- 0

## The number of datasets to run: `full` normally, `in_smoke` in the smoke
## test, and in a timing run that fraction of `full`, at least 2. The floor
## is 2, not more, so that the two fractions of the estimate (4% and 6%)
## give different numbers of datasets also for 50 or 100 per cell (2 and 3,
## or 4 and 6), and both stay small enough for a 6-hour GitHub runner.
datasets <- function(full, in_smoke) {
  datasets_asked$times <- datasets_asked$times + 1
  if (smoke) {
    return(in_smoke)
  }
  if (!is.na(timing_fraction)) {
    return(min(full, max(2, ceiling(full * timing_fraction))))
  }
  full
}
