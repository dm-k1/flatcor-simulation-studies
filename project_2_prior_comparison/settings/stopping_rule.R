## =====================================================================
##  The stopping rule: when a cell has enough datasets (README.md,
##  "Stopping")
##
##  Every quantity has an accuracy Δ; its Monte Carlo SE must be at most
##  Δ / 1.96. A cell starts with the datasets its study declares; after
##  each batch, a cell whose quantities have not all reached their target
##  gets the datasets it is estimated to lack (the Chow-Robbins rule), up to
##  the cap of its stage. The engine's scheduler (engine/workers/scheduler.R)
##  asks next_plan() after every batch a cell gets back; the studies use the
##  rest to add the targets to their tables.
##
##  As project 1's rule, with two additions: a rate's Monte Carlo SE with a
##  floor (rate_mcse()), and a cap per stage (dataset_caps).
## =====================================================================


## ---- The target ------------------------------------------------------------------------

## The largest Monte Carlo SE at which a deviation of delta reaches the 95% line
target_mcse <- function(delta) delta / 1.96

## Δ, the target and whether it is reached, added to a results table with
## columns `quantity` and `mcse`; `deltas`: Δ per quantity, named as in the
## table, or NULL when the table has a column `delta` already
with_targets <- function(table, deltas = NULL) {
  if (!is.null(deltas)) table$delta <- unname(deltas[table$quantity])
  table$target_mcse <- target_mcse(table$delta)
  # a quantity without a Δ has no target to wait for
  table$reached <- is.na(table$delta) | table$mcse <= table$target_mcse
  table
}

## The Monte Carlo SE of a rate, `hits` of `datasets`, computed from
## (hits + 2) / (datasets + 4) (Agresti & Coull, 1998) instead of the rate
## itself. The floor: a rate of 0 or 1 would have an SE of 0 and stop its
## cell at once, after the first round; with the floor, 0 of 50 has an SE
## of .027. The denominator stays `datasets`, so the worst case, a rate of
## 1/2, needs 1.96^2 x 0.25 / Δ^2 datasets (97 at Δ = .10).
rate_mcse <- function(hits, datasets) {
  floored <- (hits + 2) / (datasets + 4)
  sqrt(floored * (1 - floored) / datasets)
}


## ---- The cap ---------------------------------------------------------------------------

## The most datasets a cell may get, per stage: a part's cells carry their
## stage in a column `stage`. A multiple of the batch size, so every batch
## is full (a part-filled last batch would be recomputed if the cell were
## extended later). Where the cap binds, the study reports the width
## reached. A part without a column `stage`, or a stage not listed, has no
## cap.
dataset_caps <- c(`stage 1` = 100)

## The cap of every row of a plan
cap_of <- function(plan) {
  if (is.null(plan$stage)) return(rep(Inf, nrow(plan)))
  caps <- unname(dataset_caps[plan$stage])
  ifelse(is.na(caps), Inf, caps)
}


## ---- How many more ---------------------------------------------------------------------

## The plan after judging: every cell with a quantity whose Monte Carlo SE is
## above its target gets the datasets it is estimated to lack (the SE shrinks
## with the square root of the datasets: it needs datasets x (mcse /
## target)^2), rounded up to whole batches, at least one, and never more
## than its cap (cap_of()). `plan`: per cell its datasets so far; `table`:
## the study's results table with_targets(); `by`: the columns that name the
## unit a quantity is computed over, in the plan and in the table.
## `one_batch`: add one batch only (the smoke test, which tests the step,
## not the numbers). Returns the plan unchanged when every cell has reached
## its targets or its cap; the scheduler then counts the cell as done.
next_plan <- function(plan, table, by, batch_size, one_batch = FALSE) {
  shortfall <- table[!table$reached, c(by, "mcse", "target_mcse"), drop = FALSE]
  if (nrow(shortfall) == 0) {
    return(plan)
  }
  shortfall$needed_share <- (shortfall$mcse / shortfall$target_mcse)^2
  worst <- stats::aggregate(needed_share ~ ., data = shortfall[c(by, "needed_share")], FUN = max)

  plan_key <- do.call(paste, plan[by])
  caps <- cap_of(plan)
  if (any(is.finite(caps) & caps %% batch_size != 0)) {
    stop("A cap in dataset_caps is not whole batches of ", batch_size, call. = FALSE)
  }
  for (i in seq_len(nrow(worst))) {
    rows <- which(plan_key == do.call(paste, worst[i, by, drop = FALSE]))
    lacking <- plan$datasets[rows] * (worst$needed_share[i] - 1)
    batches <- if (one_batch) 1 else pmax(1, ceiling(lacking / batch_size))
    asked <- plan$datasets[rows] + batch_size * batches
    plan$datasets[rows] <- pmax(plan$datasets[rows], pmin(asked, caps[rows]))
  }
  plan
}
