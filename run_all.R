## =====================================================================
##  Run a project: its studies, up to their results files
##
##    Rscript run_all.R <project>          every study of the project
##    Rscript run_all.R <project> 3a       one study (its steps end in _3a)
##    VALIDATION_SMOKE=1 Rscript run_all.R <project>   the smoke test (results in cache/)
##    VALIDATION_SMOKE=1 VALIDATION_RECORD=1 Rscript run_all.R <project>
##                                         the smoke test, recording the expensive calls
##    VALIDATION_DRY=1 Rscript run_all.R <project>     the dry run: the smoke test's
##                                         design with those calls replayed, a
##                                         minute or two (engine/tests/dry_run.R)
##    VALIDATION_FRESH=1 Rscript run_all.R <project>   the project from scratch
##    VALIDATION_BUDGET_CORE_HOURS=3000 Rscript run_all.R <project>   a raised budget
##
##  <project> is a project folder, such as project_1_validation; it may be
##  left out when there is only one (or set as PROJECT=<project>).
##
##  What a run does, step by step: engine/full_run.R. In short: the
##  scheduler (engine/workers/scheduler.R) runs every study's batches, each
##  cell until the project's stopping rule says it has enough datasets,
##  without waiting for other cells or studies; then the pipeline
##  (_targets.R) makes every study's results from those batches, and the
##  results are checked. A run that stopped continues where it was. A study
##  run alone gives the same results as in a full run. A run ends at the
##  results files, in the project's results/: each study's results
##  (studies/study_<study>.rds, layer 2) and every dataset's rows
##  (per_dataset/, layer 1).
## =====================================================================
arguments <- commandArgs(trailingOnly = TRUE)
# the project first, if named (engine/run_mode.R reads PROJECT)
if (length(arguments) > 0 && startsWith(arguments[1], "project_")) {
  Sys.setenv(PROJECT = arguments[1])
  arguments <- arguments[-1]
}
source(file.path("engine", "load_code.R"))
load_code()
full_run(requested = arguments)
