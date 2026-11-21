## =====================================================================
##  Loading the code: which files, in which order
##
##  Every process that runs the validation sources this file first:
##  _targets.R (the pipeline), run_all.R (a full run), and the static check.
##  It reads which kind of run this is (engine/run_mode.R) and the
##  project's settings (<project>/engine_settings/settings.R), and sets up
##  the environment the workers inherit (engine/workers/worker_setup.R),
##  before any worker starts. code_files() lists the rest; each scheduler
##  worker sources them once (engine/workers/scheduler.R).
## =====================================================================

source(file.path("engine", "run_mode.R"))
source(file.path(project, "engine_settings", "settings.R"))
source(file.path("engine", "workers", "worker_setup.R"))

## The code, in the order it is sourced:
##   1. the engine
##   2. the project: its settings and stopping rule (<project>/engine_settings/),
##      the package under test (<project>/tested_package/), what its studies
##      share (<project>/shared_by_studies/) and the data generators (its data/)
##   3. every study: the folders of <project>/studies/, each design.R, then each code.R
##   4. only to record or replay the expensive calls: the dry run's file,
##      which replaces a few of the functions before it (engine/tests/dry_run.R)
code_files <- function() {
  engine <- file.path("engine", c(
    "run_mode.R", "seeds.R", "study_form.R",
    file.path(
      "results", c("estimates_vs_expectations.R", "results_files.R", "per_dataset_files.R")
    ),
    file.path("workers", "batches.R"),
    file.path("pipeline", "pipeline_steps.R")
  ))
  settings <- file.path(project, "engine_settings", c("settings.R", "stopping_rule.R"))
  r_files_in <- function(...) {
    list.files(file.path(project, ...), pattern = "[.]R$", full.names = TRUE)
  }
  studies <- sort(list.dirs(file.path(project, "studies"), recursive = FALSE))
  c(
    engine,
    settings,
    r_files_in("tested_package"), r_files_in("shared_by_studies"),
    r_files_in("shared_by_studies", "data"),
    file.path(studies, "design.R"),
    file.path(studies, "code.R"),
    if (dry || recording) file.path("engine", "tests", "dry_run.R")
  )
}

## All of it in this process: the packages every step loads, the code, and
## the engine's parts only a full run and the static check use (the
## scheduler, the full run, the check of the results)
load_code <- function() {
  for (package in step_packages) {
    suppressPackageStartupMessages(library(package, character.only = TRUE))
  }
  only_here <- file.path("engine", c(
    file.path("workers", "scheduler.R"), "full_run.R", file.path("tests", "check_results.R")
  ))
  for (file in c(code_files(), only_here)) source(file)
}
