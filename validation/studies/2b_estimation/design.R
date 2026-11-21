## =====================================================================
##  Study 2b: how close are the estimates to a known truth?   (heading 2, row b)
##  The design. What is tested, what is expected and why:
##  docs/validation_tests.md, study 2b. The code: code.R.
## =====================================================================


## ---- The design -------------------------------------------------------------------
##   k (2, 10) × n (50, 200) × predictor correlation (0, .7) ×
##   other slopes (sparse, dense) = 16 cells; slope of x1 = 0.2
##   (validation/shared_by_studies/data/known_slopes.R)
cells_2b <- expand.grid(
  k = c(2, 10),
  n = c(50, 200),
  rho = c(0, 0.7),
  others = c("sparse", "dense"),
  slope_x1 = 0.2,
  stringsAsFactors = FALSE
)
if (smoke) {
  cells_2b <- subset(cells_2b, k == 2 & n == 50 & rho == 0 & others == "sparse")
}

## The methods, and their draws
methods_2b <- c("flat partial r", "flat R", "flat R-squared", "JZS default", "Zellner-Siow", "OLS")
stan_draws_2b <- if (smoke) {
  c(chains = 2, warmup = 200, sampling = 200)
} else {
  c(chains = 4, warmup = 1000, sampling = 1000)
}
bayesfactor_draws_2b <- if (smoke) 1000 else 4000   # BayesFactor's draws (JZS, Zellner-Siow)


## ---- How many (docs/validation_tests.md, "How many datasets") -------------------------
## Δ per quantity: the Monte Carlo SE must be at most Δ / 1.96
deltas_2b <- c(
  "bias of x1 (share of 0.2)"     = 0.1,     # .02, 10% of the slope 0.2
  "coverage of x1's 95% interval" = 0.0196,  # an MCSE of 1%, the coverage convention
  "prediction error / OLS"        = 0.1      # 10% of OLS's
)
## The first round: computed for coverage, .95 x .05 / .01^2 = 475. Bias and
## prediction are measured: a cell gets more datasets in later rounds until
## they reach their targets too (engine/workers/batches.R).
first_datasets_2b <- datasets(475, in_smoke = 10)


## ---- Bookkeeping (no effect on the results) ------------------------------------
batch_size_2b <- if (smoke) 5 else 25   # datasets per batch, saved as it finishes


## ---- How it runs (engine/study_form.R) ------------------------------------------
## In rounds, per cell: a batch is a batch of datasets, each fitted by every
## method; a cell is judged on its bias, coverage and prediction error
declared_parts[["2b"]] <- part_until_target(
  study = "2b", cells = cells_2b, by = c("k", "n", "rho", "others"),
  first_datasets = first_datasets_2b, batch_size = batch_size_2b,
  work = function(batch, model) {
    estimates_batch_2b(batch[names(cells_2b)], replications_of(batch), model)
  },
  table = function(rows) {
    list(results_table_2b(bias_and_coverage_2b(rows), prediction_2b(rows)))
  }
)

## For the check at the end of a run (engine/tests/check_results.R)
declared_blanks[[length(declared_blanks) + 1]] <- list(
  study = "2b", table = "per_dataset", columns = "divergent",
  when = function(t) t$method %in% c("OLS", "JZS default", "Zellner-Siow"),
  reason = "these methods do not use Stan, so have no divergences to count"
)
