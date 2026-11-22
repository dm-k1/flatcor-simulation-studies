## =====================================================================
##  The study form: what every study tells the engine about itself, in its
##  own design.R, so that the engine never names a study
##
##    declared_parts    the work it runs, for the scheduler
##                      (engine/workers/scheduler.R) and the pipeline
##                      (engine/pipeline/pipeline_steps.R): a part that runs
##                      until its targets are reached (part_until_target()),
##                      or once (part_once())
##    declared_blanks   columns of its results that are NA on purpose, for
##                      the check at the end of a run (engine/tests/check_results.R)
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
## its first datasets and gets more, batch by batch, until the stopping
## rule (<project>/settings/stopping_rule.R) says its quantities have
## reached their targets.
##   study        the study it belongs to (its folder's first two characters)
##   cells        the design: one row per cell
##   by           the columns that name what a quantity is computed over: a
##                cell, or the cells of a slope over n together
##   work         function(batch, model): the rows of one batch (its cell's
##                columns, and replications batch$from to batch$to)
##   table        function(rows): the study's table(s) whose quantities must
##                reach their targets (columns `by`, mcse, target_mcse,
##                reached), from a cell's per-dataset rows, as a list
##   needs        parts the study's results also use: they run with it
##   first_datasets, batch_size   datasets per cell at first, and per batch,
##                in a real run: the project's (part_sizes,
##                <project>/settings/settings.R) unless the study gives its
##                own. The smoke test always has the project's: it tests that
##                every step runs, not the numbers (a table that cannot fill
##                with so few datasets goes in declared_empty_in_smoke).
## The first datasets must be whole batches, so that no batch is part-filled
## (a part-filled batch is recomputed, under another name, when its cell
## gets more datasets).
part_until_target <- function(study, cells, by, work, table, needs = character(0),
                              first_datasets = NULL, batch_size = NULL) {
  own <- Filter(Negate(is.null), list(first_datasets = first_datasets, batch_size = batch_size))
  real_sizes <- utils::modifyList(part_sizes$real, own)
  smoke_sizes <- part_sizes$smoke
  for (sizes in list(real_sizes, smoke_sizes)) {
    if (sizes$first_datasets %% sizes$batch_size != 0) {
      stop(
        "Study ", study, ": ", sizes$first_datasets, " first datasets are not whole ",
        "batches of ", sizes$batch_size, call. = FALSE
      )
    }
  }
  list(
    study = study, cells = cells, by = by,
    first_datasets = datasets(real_sizes$first_datasets, in_smoke = smoke_sizes$first_datasets),
    batch_size = if (smoke) smoke_sizes$batch_size else real_sizes$batch_size,
    work = work, table = table, needs = needs
  )
}

## The batch size of this kind of run, for a part that cuts its own batches
## (part_once()): the project's (part_sizes), or in a real run `real` where
## the study gives its own
batch_size_of_run <- function(real = NULL) {
  if (smoke) part_sizes$smoke$batch_size else real %||% part_sizes$real$batch_size
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
