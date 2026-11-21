## =====================================================================
##  Study 3a: are the Bayes factors right?   (heading 3, row a)
##  The design. What is tested, what is expected and why, how a dataset is
##  drawn and the reasons for each choice: docs/validation_tests.md, study 3a.
##  The code: code.R.
## =====================================================================


## ---- The design -------------------------------------------------------------------
##   prior (3) × setting (k = 3, n = 50; k = 8, n = 200) = 6 cells,
##   data from the prior (R/1_data/3_from_the_prior.R), half from the model
##   without x1
cells_3a <- data.frame(
  prior = rep(c("flat_partial_r", "flat_r", "flat_r_squared"), each = 2),
  k     = c(3, 8),
  n     = c(50, 200)
)
if (smoke) cells_3a <- cells_3a[cells_3a$k == 3, ]


## ---- How many (docs/validation_tests.md, "How many datasets") -------------------------
## Δ per quantity: the Monte Carlo SE must be at most Δ / 1.96. Part A is
## decided by the data-averaged posterior; its calibration line and bins
## describe, without a Δ (docs/validation_tests.md, 3a, why)
deltas_3a <- c(
  "data-averaged posterior"                     = 0.05, # 10% of 1/2
  "spread of repeated log BFs / reported error" = 0.1   # 10% of 1
)
## The first rounds (the Chow-Robbins rule's): parts A and B each have their
## own plan, and later rounds add datasets until their quantities reach
## their targets (R/engine/rounds.R)
first_round_3a         <- datasets(50, in_smoke = 40)   # part A, datasets per cell
first_round_repeats_3a <- datasets(50, in_smoke = 2)    # part B, datasets per cell
repeat_runs_3a         <- 5                             # part B: runs per dataset
bin_minimum_3a         <- if (smoke) 2 else 10          # part A: datasets a bin needs to be shown


## ---- Bookkeeping (no effect on the results) ------------------------------------
batch_size_3a         <- if (smoke) 4 else 25   # part A: datasets per piece of work
batch_size_repeats_3a <- if (smoke) 2 else 5    # part B: datasets (of 5 runs) per piece


## ---- How it runs (R/engine/parts.R) ------------------------------------------
## Two parts, each in rounds per cell. Part A: a piece is a batch of
## datasets, a cell judged on its data-averaged posterior. Part B: a piece
## is a batch of datasets each run repeat_runs_3a times, a cell judged on
## the spread of its repeated log Bayes factors.
declared_parts[["3a"]] <- part_in_rounds(
  study = "3a", cells = cells_3a, by = c("prior", "k", "n"),
  first_round = first_round_3a, batch_size = batch_size_3a,
  work = function(piece, model) {
    calibration_batch_3a(piece[names(cells_3a)], replications_of(piece))
  },
  table = function(rows) list(data_averaged_posterior_3a(rows))
)
declared_parts[["3a-repeats"]] <- part_in_rounds(
  study = "3a", cells = cells_3a, by = c("prior", "k", "n"),
  first_round = first_round_repeats_3a, batch_size = batch_size_repeats_3a,
  work = function(piece, model) {
    repeats_3a(piece[names(cells_3a)], replications_of(piece), repeat_runs_3a)
  },
  table = function(rows) list(repeat_spread_3a(rows, repeat_runs_3a))
)
