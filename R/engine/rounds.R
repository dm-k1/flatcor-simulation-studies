## =====================================================================
##  Rounds: how many datasets each cell gets
##  (docs/validation_tests.md, "How many datasets")
##
##  Every quantity has an accuracy Δ; its Monte Carlo SE must be at most
##  Δ / 1.96. A study that measures its numbers runs in rounds (the
##  Chow-Robbins rule): every cell starts with a first round, fixed in
##  advance; after each round, a cell whose quantities have not all reached
##  their target gets the datasets it is estimated to lack, and the round
##  is run again. The plan, how many datasets each cell has so far, is a
##  small file in the targets store, so a fresh start deletes it with the
##  store. Each cell goes through its rounds on its own, without waiting for
##  the others: run_all.R's queue (R/engine/queue.R) runs the pieces of work
##  and judges a cell as soon as its own batch is done. The pipeline reads
##  the plan and the finished pieces.
## =====================================================================


## ---- The target ------------------------------------------------------------------------

## The largest Monte Carlo SE at which a deviation of delta reaches the 95% line
target_mcse <- function(delta) delta / 1.96

## Δ, the target and whether it is reached, added to a results table with
## columns `quantity` and `mcse`; `deltas`: Δ per quantity, named as in the
## table, or NULL when the table has a column `delta` already (a Δ that
## differs per row, such as 10% of each row's expected value)
with_targets <- function(table, deltas = NULL) {
  if (!is.null(deltas)) table$delta <- unname(deltas[table$quantity])
  table$target_mcse <- target_mcse(table$delta)
  # a quantity without a Δ (an overall check) has no target to wait for
  table$reached <- is.na(table$delta) | table$mcse <= table$target_mcse
  table
}

## Δ of a direction ("positive", "increases"), whose size is not known in
## advance: `relative` times the estimate itself, at least `floor` (the
## relative fixed-width rule, Glynn & Whitt, 1992; Flegal & Gong, 2015). The
## floor ends the rule for an estimate near 0. It asks the same precision of
## a positive and a negative estimate, so it never stops on one that looks
## clearly positive.
direction_delta <- function(estimate, relative, floor) {
  pmax(relative * abs(estimate), floor)
}


## ---- The plan ------------------------------------------------------------------------

## An .rds file, not .csv: it keeps every column's type, and a piece of work
## is the same piece only if its cell's values are identical (2 is not 2L)
plan_file <- function(study, store) file.path(store, "rounds", paste0(study, ".rds"))

## The plan of a study: its cells, each with the number of datasets so far.
## Without a plan file (the first round, or a timing run), every cell has
## the first round.
read_plan <- function(study, store, cells, first_round) {
  file <- plan_file(study, store)
  if (file.exists(file)) {
    return(readRDS(file))
  }
  data.frame(cells, datasets = first_round, stringsAsFactors = FALSE)
}

write_plan <- function(plan, study, store) {
  dir.create(dirname(plan_file(study, store)), recursive = TRUE, showWarnings = FALSE)
  saveRDS(plan, plan_file(study, store))
}

## The pieces of work of a plan: one row per cell and batch, with the cell's
## columns and the first and last replication of the batch. Batches are cut
## from 1 in steps of batch_size, so a later round only adds rows: the
## pieces already done stay done.
pieces_of_plan <- function(plan, batch_size) {
  rows <- lapply(seq_len(nrow(plan)), function(i) {
    starts <- seq(1, plan$datasets[i], by = batch_size)
    cell <- plan[rep(i, length(starts)), setdiff(names(plan), "datasets"), drop = FALSE]
    cell$from <- starts
    cell$to <- pmin(starts + batch_size - 1, plan$datasets[i])
    cell
  })
  pieces <- do.call(rbind, rows)
  rownames(pieces) <- NULL
  pieces
}


## ---- The next round ----------------------------------------------------------------------

## The plan for the next round: every cell with a quantity whose Monte Carlo
## SE is above its target gets the datasets it is estimated to lack (the SE
## shrinks with the square root of the datasets: it needs
## datasets x (mcse / target)^2), rounded up to whole batches, at least one.
## `table`: the study's results table with_targets(); `by`: the columns that
## name the unit a quantity is computed over, in the plan and in the table:
## a cell, or several (a slope over n: then every cell of the unit, each n,
## gets the datasets). `one_batch`: add one batch
## only (the smoke test, which tests the step, not the numbers). Returns the
## plan unchanged when every cell has reached its targets.
next_plan <- function(plan, table, by, batch_size, one_batch = FALSE) {
  shortfall <- table[!table$reached, c(by, "mcse", "target_mcse"), drop = FALSE]
  if (nrow(shortfall) == 0) {
    return(plan)
  }
  shortfall$needed_share <- (shortfall$mcse / shortfall$target_mcse)^2
  worst <- stats::aggregate(needed_share ~ ., data = shortfall[c(by, "needed_share")], FUN = max)

  plan_key <- do.call(paste, plan[by])
  for (i in seq_len(nrow(worst))) {
    rows <- which(plan_key == do.call(paste, worst[i, by, drop = FALSE]))
    lacking <- plan$datasets[rows] * (worst$needed_share[i] - 1)
    batches <- if (one_batch) 1 else pmax(1, ceiling(lacking / batch_size))
    plan$datasets[rows] <- plan$datasets[rows] + batch_size * batches
  }
  plan
}


## ---- The pieces ------------------------------------------------------------------------

## The work of one piece: its rows, from the work function its part
## declares (R/engine/parts.R). run_all.R's queue and the pipeline's steps
## (R/engine/steps.R) both call this, so a piece is the same work wherever it
## runs. Every draw that matters has a seed of its own already
## (R/engine/random_streams.R), but a package may seed its own draws with
## set.seed() (flatcor does, for bridge sampling), which draws with whichever
## generator R has set. So a piece starts as targets starts a step: seeded,
## with R's default generator. `model`: what piece_model() gives
## (R/project/settings.R).
piece_work <- function(part, piece, model = NULL) {
  set.seed(
    seed_of("piece", part, piece_id(piece)),
    kind = "default", normal.kind = "default", sample.kind = "default"
  )
  declared_parts[[part]]$work(piece, model)
}

## A piece's name: a hash of its cell's values and its replications (types
## included: 2 is not 2L, as in the plan)
piece_id <- function(piece) digest::digest(as.list(piece))

## Where the queue saves a finished piece: in the store, so a fresh start
## deletes it with the store
piece_file <- function(part, piece, store) {
  file.path(store, "pieces", part, paste0(piece_id(piece), ".rds"))
}

## The queue's run of one piece (R/engine/queue.R): its rows and seconds,
## saved under another name and then renamed, so a worker that stops halfway
## leaves no broken piece. Returns the seconds.
run_piece <- function(part, piece, store, model = NULL) {
  started <- Sys.time()
  rows <- piece_work(part, piece, model)
  seconds <- as.numeric(difftime(Sys.time(), started, units = "secs"))
  file <- piece_file(part, piece, store)
  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  partial <- tempfile(tmpdir = dirname(file), fileext = ".partial")
  saveRDS(list(rows = rows, seconds = seconds), partial)
  file.rename(partial, file)
  seconds
}

## A finished piece (list(rows, seconds)), or NULL if the queue has not run it
read_piece <- function(part, piece, store) {
  file <- piece_file(part, piece, store)
  if (file.exists(file)) readRDS(file) else NULL
}

## A piece's rows in the pipeline's step: the queue's, read back, or, if the
## queue has not run it (a plain tar_make(), a timing run), computed here
piece_rows <- function(part, piece, model = NULL) {
  finished <- read_piece(part, piece, targets::tar_path_store())
  if (!is.null(finished)) return(finished$rows)
  piece_work(part, piece, model)
}
