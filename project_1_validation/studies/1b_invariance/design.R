## =====================================================================
##  Study 1b: is the Bayes factor invariant to units and coding?   (heading 1, row b)
##  The design. What is tested, what is expected and why:
##  docs/validation_tests.md, study 1b. The code: code.R.
## =====================================================================


## ---- The design -------------------------------------------------------------------
##   prior (3) × dataset (ordinary regression,
##   shared/data/ordinary_regression.R) × change (rescaled, recoded)
priors_1b <- data.frame(prior = c("joint_partial_r", "flat_r", "flat_r_squared"))


## ---- How many (docs/validation_tests.md, "How many datasets") -------------------------
## Δ per quantity: the Monte Carlo SE must be at most Δ / 1.96
deltas_1b <- c(
  "change in log BF, rescaled" = log(1.1),   # .095: the Bayes factor off by 10%
  "change in log BF, recoded"  = log(1.1)
)
## The first round (the Chow-Robbins rule's, per prior) has the project's
## size (part_sizes, settings/settings.R); later rounds add datasets until
## both changes reach their targets (engine/workers/batches.R)


## ---- How it runs (engine/study_form.R) ------------------------------------------
## In rounds, per prior: a batch is a batch of datasets, each with its five
## log Bayes factors; a prior is judged on its pooled changes. A change of
## one dataset is judged against bridge sampling's error as 3a part B
## measures it, so that part runs with 1b.
declared_parts[["1b"]] <- part_until_target(
  study = "1b", cells = priors_1b, by = "prior",
  # 5 per batch, not the project's 25: a dataset is five Bayes factors, so
  # smaller batches are saved more often; and the v2 run's batches keep
  # their names
  batch_size = 5,
  work = function(batch, model) invariance_batch_1b(batch["prior"], replications_of(batch)),
  table = function(rows) list(pooled_1b(changes_of_1b(rows))),
  needs = "3a-repeats"
)
