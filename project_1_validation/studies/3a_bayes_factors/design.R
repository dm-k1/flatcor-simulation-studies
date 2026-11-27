## =====================================================================
##  Study 3a: are the Bayes factors right?   (heading 3, row a)
##  The design. What is tested, what is expected and why, how a dataset is
##  drawn and the reasons for each choice: docs/validation_tests.md, study 3a.
##  The code: code.R.
## =====================================================================


## ---- The design -------------------------------------------------------------------
##   prior (3) × setting (k = 3, n = 50; k = 8, n = 200) = 6 cells,
##   data from the prior (shared/data/from_the_prior.R), half from the model
##   without x1
cells_3a <- data.frame(
  prior = rep(c("joint_partial_r", "flat_r", "flat_r_squared"), each = 2),
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
## their targets (engine/workers/batches.R). Both start with the project's
## first datasets (part_sizes, settings/settings.R).
repeat_runs_3a         <- 5                             # part B: runs per dataset
bin_minimum_3a         <- if (smoke) 2 else 10          # part A: datasets a bin needs to be shown


## ---- How it runs (engine/study_form.R) ------------------------------------------
## Two parts, each in rounds per cell. Part A: a batch is a batch of
## datasets, a cell judged on its data-averaged posterior. Part B: a batch
## is a batch of datasets each run repeat_runs_3a times, a cell judged on
## the spread of its repeated log Bayes factors.
declared_parts[["3a"]] <- part_until_target(
  study = "3a", cells = cells_3a, by = c("prior", "k", "n"),
  work = function(batch, model) {
    calibration_batch_3a(batch[names(cells_3a)], replications_of(batch))
  },
  table = function(rows) list(data_averaged_posterior_3a(rows))
)
declared_parts[["3a-repeats"]] <- part_until_target(
  study = "3a", cells = cells_3a, by = c("prior", "k", "n"),
  # 5 per batch, not the project's 25: a dataset is run five times, so
  # smaller batches are saved more often; and the v2 run's batches keep
  # their names
  batch_size = 5,
  work = function(batch, model) {
    repeats_3a(batch[names(cells_3a)], replications_of(batch), repeat_runs_3a)
  },
  table = function(rows) list(repeat_spread_3a(rows, repeat_runs_3a))
)

## For the check at the end of a run (engine/tests/check_results.R): the smoke
## test's few datasets per cell (4) rarely put bin_minimum_3a of them in one
## of the 14 bins, so the calibration bins can be empty there
declared_empty_in_smoke[["3a"]] <- "calibration_bins"
