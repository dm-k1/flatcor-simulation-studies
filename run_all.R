## =====================================================================
##  Run the whole validation
##
##    Rscript run_all.R                  every study
##    Rscript run_all.R 3a               one study (its steps end in _3a)
##    VALIDATION_SMOKE=1 Rscript run_all.R   the smoke test (results in cache/)
##    VALIDATION_SMOKE=1 VALIDATION_RECORD=1 Rscript run_all.R
##                                       the smoke test, recording the expensive calls
##    VALIDATION_DRY=1 Rscript run_all.R     the dry run: the smoke test's design with
##                                       those calls replayed, a minute or two
##                                       (engine/tests/dry_run.R)
##    VALIDATION_FRESH=1 Rscript run_all.R   the whole validation from scratch
##    VALIDATION_BUDGET_CORE_HOURS=3000 Rscript run_all.R   with a raised budget
##
##  What a run does, step by step: engine/full_run.R. In short: the
##  scheduler (engine/workers/scheduler.R) runs every study's batches,
##  each cell until its stopping rule (validation/engine_settings/stopping_rule.R)
##  says it has enough datasets, without waiting for other cells or studies;
##  then the pipeline (_targets.R) makes every study's results from those
##  batches, and the results are checked. A run that stopped continues where
##  it was. A study run alone gives the same results as in a full run.
##  A run ends at the results files: each study's results
##  (results/studies/study_<study>.rds, layer 2) and every dataset's rows
##  (results/per_dataset/, layer 1).
## =====================================================================
source(file.path("engine", "load_code.R"))
load_code()
full_run(requested = commandArgs(trailingOnly = TRUE))
