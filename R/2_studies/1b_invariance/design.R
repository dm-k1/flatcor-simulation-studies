## =====================================================================
##  Study 1b: is the Bayes factor invariant to units and coding?   (heading 1, row b)
##  The design. What is tested, what is expected and why:
##  docs/validation_tests.md, study 1b. The code: code.R.
## =====================================================================


## ---- The design -------------------------------------------------------------------
##   prior (3) × dataset (ordinary regression, R/1_data/2_ordinary_regression.R) ×
##   change (rescaled, recoded)
priors_1b <- data.frame(prior = c("flat_partial_r", "flat_r", "flat_r_squared"))


## ---- How many (docs/validation_tests.md, "How many datasets") -------------------------
## Δ per quantity: the Monte Carlo SE must be at most Δ / 1.96
deltas_1b <- c(
  "change in log BF, rescaled" = log(1.1),   # .095: the Bayes factor off by 10%
  "change in log BF, recoded"  = log(1.1)
)
## The first round (the Chow-Robbins rule's, per prior); later rounds add
## datasets until both changes reach their targets (R/engine/rounds.R)
first_round_1b <- datasets(50, in_smoke = 2)


## ---- Bookkeeping (no effect on the results) ------------------------------------
batch_size_1b <- if (smoke) 2 else 5   # datasets per piece of work, saved as it finishes


## ---- How it runs (R/engine/parts.R) ------------------------------------------
## In rounds, per prior: a piece is a batch of datasets, each with its five
## log Bayes factors; a prior is judged on its pooled changes. A change of
## one dataset is judged against bridge sampling's error as 3a part B
## measures it, so that part runs with 1b.
declared_parts[["1b"]] <- part_in_rounds(
  study = "1b", cells = priors_1b, by = "prior",
  first_round = first_round_1b, batch_size = batch_size_1b,
  work = function(piece, model) invariance_batch_1b(piece["prior"], replications_of(piece)),
  table = function(rows) list(pooled_1b(changes_of_1b(rows))),
  needs = "3a-repeats"
)
