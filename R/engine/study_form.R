## =====================================================================
##  The study form: what every study tells the engine about itself, in its
##  own design.R, so that the engine never names a study
##
##    declared_parts    the work it runs, for the scheduler
##                      (R/engine/workers/scheduler.R) and the pipeline
##                      (R/engine/pipeline/pipeline_steps.R): a part that runs
##                      until its targets are reached (part_until_target()),
##                      or once (part_once())
##    declared_blanks   columns of its results that are NA on purpose, for
##                      the check at the end of a run (R/engine/tests/check_results.R)
##    declared_empty_in_smoke   tables of its results that are empty in the
##                      smoke test, whose corner of the design leaves their
##                      cells out
##
##  A study adds to them, as in 2b's design.R:
##    declared_parts[["2b"]] <- part_until_target(study = "2b", ...)
## =====================================================================

declared_parts <- list()
declared_blanks <- list()
declared_empty_in_smoke <- list()

## A part that runs until its targets are reached: every cell starts with
## first_datasets datasets and gets more, batch by batch, until the stopping
## rule (R/project/engine_settings/stopping_rule.R) says its quantities have
## reached their targets.
##   study        the study it belongs to (its folder's first two characters)
##   cells        the design: one row per cell
##   by           the columns that name what a quantity is computed over: a
##                cell, or the cells of a slope over n together
##   first_datasets, batch_size   datasets per cell at first, and per batch
##   work         function(batch, model): the rows of one batch (its cell's
##                columns, and replications batch$from to batch$to)
##   table        function(rows): the study's table(s) whose quantities must
##                reach their targets (columns `by`, mcse, target_mcse,
##                reached), from a cell's per-dataset rows, as a list
##   needs        parts the study's results also use: they run with it
part_until_target <- function(study, cells, by, first_datasets, batch_size, work, table,
                              needs = character(0)) {
  list(
    study = study, cells = cells, by = by, first_datasets = first_datasets,
    batch_size = batch_size, work = work, table = table, needs = needs
  )
}

## A part that runs once: every row of `batches` is one batch
##   work   function(batch, model): the rows (or result) of one batch
part_once <- function(study, batches, work, needs = character(0)) {
  list(study = study, batches = batches, work = work, needs = needs)
}

## The replications of a batch: from to to
replications_of <- function(batch) batch$from:batch$to

## The replications 1 ... total in batches of `size`
split_into_batches <- function(total, size) split(seq_len(total), ceiling(seq_len(total) / size))
