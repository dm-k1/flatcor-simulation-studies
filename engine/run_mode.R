## =====================================================================
##  Which project, which kind of run, and where its files go
##
##  The project: a folder project_<n>_<name>/ next to the engine, chosen as
##  the first argument of run_all.R or with PROJECT=<folder>; with only one
##  project folder, that one.
##
##    a full run        Rscript run_all.R
##    the smoke test    VALIDATION_SMOKE=1  a corner of each design, to test the
##                      code (engine/tests/README.md)
##    the dry run       VALIDATION_DRY=1    the smoke test's design with the
##                      expensive calls replayed (engine/tests/dry_run.R)
##    a recording       VALIDATION_SMOKE=1 VALIDATION_RECORD=1  a smoke test that
##                      records those calls for the dry run
##    the first round   VALIDATION_FIRST_ROUND=1  a real run that stops once
##                      every cell is judged, and reports what the stopping
##                      rule asks for next (engine/workers/scheduler.R): the
##                      run-time estimate; without it the run continues
##
##  Every process sources this file (engine/load_code.R), so each project
##  and each kind of run keeps its own store and results, and none mixes
##  with another.
## =====================================================================

## ---- The project ---------------------------------------------------------------------

## The project folders: project_<n>_<name>/, next to the engine
project_folders <- function() {
  folders <- list.files(".", pattern = "^project_")
  sort(folders[dir.exists(folders)])
}
project <- Sys.getenv("PROJECT")
if (!nzchar(project)) {
  if (length(project_folders()) != 1) {
    stop(
      "Which project? Name it first, as in Rscript run_all.R ", project_folders()[1],
      ", or set PROJECT. The projects: ", paste(project_folders(), collapse = ", "),
      call. = FALSE
    )
  }
  project <- project_folders()
}
if (!dir.exists(project)) stop("No project folder ", project, call. = FALSE)
# set, so every process the run starts (the pipeline, the workers) has it
Sys.setenv(PROJECT = project)

## The project's own folder in cache/: its smoke test, dry run and
## recordings
project_cache <- file.path("cache", project)

## The dry run's recordings (engine/tests/dry_run.R)
recordings_folder <- file.path(project_cache, "dry_recordings")

dry <- identical(Sys.getenv("VALIDATION_DRY"), "1")
recording <- identical(Sys.getenv("VALIDATION_RECORD"), "1")
# the dry run has the smoke test's design (set here, so every process it
# starts inherits it)
if (dry) Sys.setenv(VALIDATION_SMOKE = "1")
smoke <- identical(Sys.getenv("VALIDATION_SMOKE"), "1")
first_round <- identical(Sys.getenv("VALIDATION_FIRST_ROUND"), "1")


## ---- Where the files go ------------------------------------------------------------

## The folder of the results: the project's results/ for a full run, its
## folder in cache/ otherwise
results_root_of <- function(dry, smoke) {
  if (dry) return(file.path(project_cache, "dry_results"))
  if (smoke) return(file.path(project_cache, "smoke_results"))
  file.path(project, "results")
}

## The targets store, one per project
store <- if (dry) {
  file.path(project_cache, "targets_dry")
} else if (smoke) {
  file.path(project_cache, "targets_smoke")
} else {
  file.path("_targets", project)
}
results_root <- results_root_of(dry, smoke)


## ---- How much to run ---------------------------------------------------------------

## The number of datasets to run: `full` normally, `in_smoke` in the smoke
## test
datasets <- function(full, in_smoke) if (smoke) in_smoke else full
