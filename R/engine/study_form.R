## =====================================================================
##  What each study declares about itself, in its own design.R, so that the
##  engine never names a study:
##
##    declared_parts    its pieces of work, for the queue (R/engine/workers/scheduler.R)
##                      and the pipeline (R/engine/pipeline/pipeline_steps.R): a part that runs
##                      in rounds (part_in_rounds()) or once (part_once())
##    declared_blanks   columns of its results that are NA on purpose, for
##                      the check at the end of a run (R/engine/tests/check_results.R)
##    declared_empty_in_smoke   tables of its results that are empty in the
##                      smoke test, whose corner of the design leaves their
##                      cells out
##
##  A study adds to them, as in 2b's design.R:
##    declared_parts[["2b"]] <- part_in_rounds(study = "2b", ...)
## =====================================================================

declared_parts <- list()
declared_blanks <- list()
declared_empty_in_smoke <- list()

## A part that runs in rounds (R/engine/workers/batches.R): every cell starts with
## first_round datasets and gets more, batch by batch, until its quantities
## reach their targets.
##   study        the study it belongs to (its folder's first two characters)
##   cells        the design: one row per cell
##   by           the columns that name what a quantity is computed over: a
##                cell, or the cells of a slope over n together
##   first_round, batch_size   datasets per cell at first, and per piece
##   work         function(piece, model): the rows of one piece of work (its
##                cell's columns, and replications piece$from to piece$to)
##   table        function(rows): the study's table(s) whose quantities must
##                reach their targets (columns `by`, mcse, target_mcse,
##                reached), from a cell's per-dataset rows, as a list
##   needs        parts the study's results also use: they run with it
part_in_rounds <- function(study, cells, by, first_round, batch_size, work, table,
                           needs = character(0)) {
  list(
    study = study, cells = cells, by = by, first_round = first_round,
    batch_size = batch_size, work = work, table = table, needs = needs
  )
}

## A part that runs once: every row of `pieces` is one piece of work
##   work   function(piece, model): the rows (or result) of one piece
part_once <- function(study, pieces, work, needs = character(0)) {
  list(study = study, pieces = pieces, work = work, needs = needs)
}

## The replications of a piece of work: from to to
replications_of <- function(piece) piece$from:piece$to
