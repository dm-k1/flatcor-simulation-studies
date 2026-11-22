## =====================================================================
##  Study 1a: how do the priors' Bayes factors differ in the decisions
##  they lead to?
##  The design. The run spec, and why: README.md. The code: code.R.
## =====================================================================


## ---- The design: stage 1 ----------------------------------------------------------
##   n (6) × partial r of x1 (5) × [k = 1, or k (3) × covariates' R-squared (2)
##   × predictor correlation (3)] = 6 × 5 × (1 + 18) = 570 cells.
## At k = 1 there are no other predictors, so their R-squared and
## correlation mean nothing there: one cell per n and partial r (both 0).
## Every cell carries its stage, which names its datasets (code.R) and sets
## its cap (settings/stopping_rule.R).
ns_1a <- c(25, 50, 100, 200, 400, 800)
partial_rs_1a <- c(0, 0.05, 0.1, 0.2, 0.3)

x1_alone_1a <- expand.grid(
  n = ns_1a,
  k = 1,
  partial_r = partial_rs_1a,
  covariates_r_squared = 0,
  predictor_correlation = 0
)
with_covariates_1a <- expand.grid(
  n = ns_1a,
  k = c(3, 6, 12),
  partial_r = partial_rs_1a,
  covariates_r_squared = c(0, 0.3),
  predictor_correlation = c(0, 0.3, 0.6)
)
cells_stage1_1a <- data.frame(
  stage = "stage 1",
  rbind(x1_alone_1a, with_covariates_1a),
  stringsAsFactors = FALSE
)

## The smoke test: a corner (n = 50; k = 1 and 3; no effect and the largest)
if (smoke) {
  cells_stage1_1a <- subset(
    cells_stage1_1a,
    n == 50 & k %in% c(1, 3) & partial_r %in% c(0, 0.3) &
      (k == 1 | (covariates_r_squared == 0.3 & predictor_correlation == 0.3))
  )
}
rownames(cells_stage1_1a) <- NULL


## ---- Decisions -----------------------------------------------------------------------
## A Bayes factor decides at 10 (either way); the p-value at alpha = .05
evidence_threshold_1a <- 10
alpha_1a <- 0.05


## ---- How many (README.md, "Stopping") ------------------------------------------------
## Every rate of the cell must have a Monte Carlo SE of at most Δ / 1.96,
## computed with the floor (rate_mcse()); the cap is 100 datasets per cell
## (dataset_caps, settings/stopping_rule.R). First datasets and batch size:
## the project's (part_sizes, settings/settings.R).
deltas_1a <- c(rate = 0.10)


## ---- How it runs (engine/study_form.R) ------------------------------------------
## Stage 1: one part over every cell, in rounds per cell. A batch is a batch
## of datasets, each through every method; a cell is judged on its rates.
## Stage 2 comes later as a part of its own ("1a-stage2"), over chosen cells,
## with its own stage label: its datasets get names, and so seeds, of their
## own, and stage 1's stay untouched.
declared_parts[["1a-stage1"]] <- part_until_target(
  study = "1a", cells = cells_stage1_1a, by = names(cells_stage1_1a),
  work = function(batch, model) {
    datasets_1a(batch[names(cells_stage1_1a)], replications_of(batch))
  },
  table = function(rows) list(decision_rates_1a(rows))
)
