## =====================================================================
##  The stopping rule: when a cell has enough datasets
##  (docs/validation_tests.md, "How many datasets")
##
##  Every quantity has an accuracy Δ; its Monte Carlo SE must be at most
##  Δ / 1.96. A cell starts with the datasets its study declares; after
##  each batch, a cell whose quantities have not all reached their target
##  gets the datasets it is estimated to lack (the Chow-Robbins rule). The
##  engine's scheduler (engine/workers/scheduler.R) asks next_plan() after
##  every batch a cell gets back; the studies use the rest to add the
##  targets to their tables.
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


## ---- How many more ---------------------------------------------------------------------

## The plan after judging: every cell with a quantity whose Monte Carlo SE is
## above its target gets the datasets it is estimated to lack (the SE shrinks
## with the square root of the datasets: it needs datasets x (mcse /
## target)^2), rounded up to whole batches, at least one. `plan`: per cell
## its datasets so far; `table`: the study's results table with_targets();
## `by`: the columns that name the unit a quantity is computed over, in the
## plan and in the table: a cell, or several (a slope over n: then every
## cell of the unit, each n, gets the datasets). `one_batch`: add one batch
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
