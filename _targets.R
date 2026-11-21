## =====================================================================
##  The validation as one pipeline (targets). This file is the "run all".
##
##    targets::tar_make()                          run everything that is not done yet
##    targets::tar_make(names = ends_with("_3a"))  one study
##    targets::tar_outdated()                      what tar_make() would (re)run
##    targets::tar_visnetwork()                    the steps and what depends on what
##
##  Rscript run_all.R runs the studies' batches through the scheduler first,
##  then this pipeline once, which makes every study's results from the
##  saved batches (R/engine/full_run.R). Each study writes its tables to
##  results/studies/study_<study>.rds; Rscript make_figures.R draws the
##  figures from those files afterwards. Every finished step is saved in
##  _targets/, so a run that stops continues where it was.
##
##  Smoke test and dry run, with their own store and results (R/engine/run_mode.R):
##    Sys.setenv(VALIDATION_SMOKE = "1"); targets::tar_make(store = "cache/targets_smoke")
##    Sys.setenv(VALIDATION_DRY = "1"); targets::tar_make(store = "cache/targets_dry")
##
##  This file only collects: every study is a folder in R/studies/ with its
##  design (design.R), its code (code.R), its steps here (steps.R) and its
##  figures (figures.R). What each tests, expects and why:
##  docs/validation_tests.md.
## =====================================================================
library(targets)


## ---- Setup ------------------------------------------------------------------------

## Which kind of run, the project's settings, every worker's environment
## (R/engine/load_code.R), then the code, in order, and the pipeline's
## settings (R/engine/pipeline/pipeline_setup.R)
source(file.path("R", "engine", "load_code.R"))
tar_source(c(code_files(), file.path("R", "engine", "pipeline", "pipeline_setup.R")))
pipeline_setup()


## ---- The steps ------------------------------------------------------------------------

list(
  ## The model every batch gets (batch_model(), R/project/engine_settings/settings.R),
  ## made once before the studies that use it
  tar_target(model, batch_model()),

  ## Every study's steps (its steps.R; study_steps(), R/engine/pipeline/pipeline_steps.R)
  study_steps()
)
