## =====================================================================
##  Study 1a: the code
##  The run spec and why: README.md. The design: design.R. _targets.R puts
##  these steps in order.
## =====================================================================


## ---- One dataset, through every method ---------------------------------------------

## A dataset's name: its study, stage, the cell's factor values and its
## replication, never a row number, so a finished dataset keeps its seed
## when the design grows (engine/seeds.R)
dataset_name_1a <- function(cell, replication) {
  name_of(
    "1a", cell$stage,
    "n", cell$n, "k", cell$k, "partial r", cell$partial_r,
    "covariates R2", cell$covariates_r_squared,
    "correlation", cell$predictor_correlation,
    "replication", replication
  )
}

## One dataset of a cell, and its rows: one per method (the five Bayes
## factors, then the p-value). Every row starts with the dataset's name,
## the cell, its truth and both models' sample R-squared; "full" is the
## model with x1, "reduced" the model without it.
dataset_1a <- function(cell, replication) {
  dataset <- dataset_name_1a(cell, replication)
  data <- data_with_partial_r(
    cell$n, cell$k, cell$partial_r, cell$covariates_r_squared, cell$predictor_correlation,
    name = dataset
  )
  full <- data$predictors
  reduced <- full[, -1, drop = FALSE]
  timed <- function(expression) {
    started <- Sys.time()
    value <- expression
    value$seconds <- as.numeric(difftime(Sys.time(), started, units = "secs"))
    value
  }

  # the five Bayes factors for x1 (shared/comparison_methods.R), each seeded
  # from the dataset's name and the method
  bayes_factors <- bind_rows(lapply(model_methods, function(method) {
    timed(log_bayes_factor_between(
      method, full, reduced, data$outcome, name = name_of(dataset, method)
    ))
  }))

  # the intercept-only model's marginal likelihood, kept so that the whole
  # model can be tested afterwards: the same under the three priors (it has
  # no R-squared), so fitted once, with flatcor (two fits of it, of which
  # the first is kept)
  intercept_only <- timed(log_bayes_factor_between(
    names(contenders)[1], full[, 0], full[, 0], data$outcome,
    name = name_of(dataset, "intercept-only")
  ))
  bayes_factors <- bayes_factors |>
    mutate(
      log_ml_null = if_else(method %in% names(contenders), intercept_only$log_ml_a, NA),
      error_null = if_else(method %in% names(contenders), intercept_only$error_a, NA),
      seconds_null = if_else(method %in% names(contenders), intercept_only$seconds, NA)
    )

  # the p-value of x1's slope
  ols <- timed(as.list(p_value_of_first(full, data$outcome)))
  p_value_row <- tibble(
    id = name_of(dataset, "p-value"), method = "p-value",
    k_a = ncol(full), k_b = ncol(reduced),
    r_squared_a = sample_r_squared(full, data$outcome),
    r_squared_b = sample_r_squared(reduced, data$outcome),
    t_value = ols$t, p_value = ols$p, seconds = ols$seconds
  )

  # the cell and its truth first, then the methods
  methods <- bind_rows(select(bayes_factors, -n), p_value_row) |>
    rename(log_BF10 = log_bf) |>
    rename_with(function(x) sub("_a$", "_full", sub("_b$", "_reduced", x)))
  bind_cols(
    tibble(
      dataset, stage = cell$stage, n = cell$n, k = cell$k, partial_r = cell$partial_r,
      covariates_r_squared = cell$covariates_r_squared,
      predictor_correlation = cell$predictor_correlation,
      replication,
      dataset_seed = digest::digest2int(dataset, seed = root_seed), # with_stream_of()'s
      true_r_squared_full = data$r_squared,
      true_r_squared_reduced = data$r_squared_without_x1,
      true_slope_x1 = data$slopes[1],
      draws = bayes_factor_draws,
      machine = machine_of()
    )[rep(1, nrow(methods)), ],
    methods
  )
}

## One batch of datasets of one cell
datasets_1a <- function(cell, replications) {
  bind_rows(lapply(replications, function(r) dataset_1a(cell, r)))
}


## ---- The rates that decide when a cell stops ---------------------------------------

## Per dataset and method: which decision it gives. With an effect (partial
## r > 0), a Bayes factor finds it at BF10 >= 10 and misleads at BF10 <=
## 1/10; without one, it confirms the null at BF10 <= 1/10 and misleads at
## BF10 >= 10. The p-value finds the effect at p < .05, and misleads at p <
## .05 when there is none. Long: one row per dataset, method and rate.
decisions_1a <- function(rows) {
  threshold <- log(evidence_threshold_1a)
  bayes_factors <- rows |>
    filter(method != "p-value") |>
    mutate(
      correct = if_else(partial_r > 0, log_BF10 >= threshold, log_BF10 <= -threshold),
      misleading = if_else(partial_r > 0, log_BF10 <= -threshold, log_BF10 >= threshold)
    )
  bind_rows(
    transmute(
      bayes_factors, stage, n, k, partial_r, covariates_r_squared, predictor_correlation,
      method,
      quantity = if_else(partial_r > 0, "finds the effect", "confirms the null"),
      hit = correct
    ),
    transmute(
      bayes_factors, stage, n, k, partial_r, covariates_r_squared, predictor_correlation,
      method, quantity = "misleading", hit = misleading
    ),
    rows |>
      filter(method == "p-value") |>
      transmute(
        stage, n, k, partial_r, covariates_r_squared, predictor_correlation, method,
        quantity = if_else(partial_r > 0, "finds the effect", "misleading"),
        hit = p_value < alpha_1a
      )
  )
}

## Per cell, method and rate: the rate, its Monte Carlo SE with the floor
## (rate_mcse(), settings/stopping_rule.R) and its target. A cell stops when
## every one has reached its target, or at its cap; `capped` marks a rate
## whose cell stopped at the cap before reaching it, and `half_width` is the
## width reached (1.96 MCSE).
decision_rates_1a <- function(rows) {
  decisions_1a(rows) |>
    group_by(
      stage, n, k, partial_r, covariates_r_squared, predictor_correlation, method, quantity
    ) |>
    summarise(datasets = n(), hits = sum(hit), .groups = "drop") |>
    mutate(
      estimate = hits / datasets,
      mcse = rate_mcse(hits, datasets),
      half_width = 1.96 * mcse,
      delta = deltas_1a[["rate"]]
    ) |>
    with_targets() |>
    mutate(capped = !reached & datasets >= cap_of(pick(stage)))
}


## ---- Also reported: bridge sampling's errors and Stan's diagnostics ----------------

## Per cell and prior (the three priors: the references have no Stan fits)
diagnostics_1a <- function(rows) {
  rows |>
    filter(method %in% names(contenders)) |>
    group_by(
      stage, n, k, partial_r, covariates_r_squared, predictor_correlation, method
    ) |>
    summarise(
      datasets = n(),
      median_error = median(error),
      largest_error = max(error),
      largest_error_null = max(error_null),
      fits_with_divergences = sum(divergent_full > 0) + sum(divergent_reduced > 0),
      divergent_transitions = sum(divergent),
      largest_rhat = max(rhat_max_full, rhat_max_reduced),
      smallest_ess_bulk = min(ess_bulk_min_full, ess_bulk_min_reduced),
      median_seconds = median(seconds),
      median_seconds_null = median(seconds_null),
      .groups = "drop"
    )
}


## ---- The results file ---------------------------------------------------------

## Every table of the study in results/studies/study_1a.rds; the
## per-dataset rows are in results/per_dataset/ (study_1a_stage1)
save_results_1a <- function(rates, diagnostics) {
  save_study_results_file("1a", list(
    decision_rates = rates,
    datasets_per_cell = rates |>
      distinct(stage, n, k, partial_r, covariates_r_squared, predictor_correlation, datasets) |>
      left_join(
        rates |>
          group_by(stage, n, k, partial_r, covariates_r_squared, predictor_correlation) |>
          summarise(all_reached = all(reached), capped = any(capped), .groups = "drop"),
        by = c("stage", "n", "k", "partial_r", "covariates_r_squared", "predictor_correlation")
      ),
    diagnostics = diagnostics
  ))
}
