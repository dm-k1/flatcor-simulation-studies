## =====================================================================
##  The methods compared: every dataset goes to every one of them (common
##  random numbers). Project 1's set (project_1_validation/shared/
##  comparison_methods.R), with the p-value added.
##
##  The three priors, all R-squared ~ Beta(a, 1) with a uniform direction
##  (flatcor):
##    flat partial r   a = k/2
##    flat R           a = 1/2
##    flat R-squared   a = 1
##  Two references, the standard defaults (BayesFactor / JASP; Liang et al., 2008):
##    JZS default      Cauchy prior, scale sqrt(2)/4 ("medium")
##    Zellner-Siow     Cauchy prior, scale 1 (R-squared ~ Beta(k/2, 1/2))
##  And the p-value of x1's slope in the ordinary least squares fit.
##
##  For the three priors a Bayes factor is flatcor's: each model fitted
##  with its Stan model, its marginal likelihood estimated by bridge
##  sampling. For the references it is BayesFactor's, from R-squared, n and k,
##  and their posterior, for estimation, is BayesFactor's too (lmBF() and
##  posterior() with the same scale).
## =====================================================================


## ---- Method names --------------------------------------------------------------------

contenders <- c(
  `flat partial r` = "flat_partial_r",
  `flat R` = "flat_r",
  `flat R-squared` = "flat_r_squared"
)
model_methods <- c(names(contenders), "JZS default", "Zellner-Siow")

## ---- The Bayes factor between two models -------------------------------------------

## Draws per model for a Bayes factor: ten times the estimation draws (the
## bridgesampling authors' rule), fewer in the smoke test
bayes_factor_draws <- if (identical(Sys.getenv("VALIDATION_SMOKE"), "1")) 1000 else 10000

## The two models as formulas on one data frame, as flatcor takes them: the
## outcome, model A's columns a1, a2, ... and model B's b1, b2, ... (no
## columns: the intercept-only model)
models_as_formulas <- function(predictors_a, predictors_b, outcome) {
  colnames(predictors_a) <- sprintf("a%d", seq_len(ncol(predictors_a)))
  colnames(predictors_b) <- sprintf("b%d", seq_len(ncol(predictors_b)))
  formula_of <- function(columns) {
    reformulate(if (length(columns) == 0) "1" else columns, response = "outcome")
  }
  list(
    formula_a = formula_of(colnames(predictors_a)),
    formula_b = formula_of(colnames(predictors_b)),
    data = data.frame(outcome = outcome, predictors_a, predictors_b)
  )
}

## Posterior draws for estimation with the references (BayesFactor's
## posterior()): as many as a Bayes factor's draws per model, fewer in the
## smoke test
posterior_draws <- bayes_factor_draws

## The summary of every variable of some posterior draws, in the columns
## flatcor gives (mean, median, sd, mad, quantiles, R-hat, bulk and tail ESS)
summarise_posterior <- function(draws) {
  as.data.frame(posterior::summarise_draws(
    draws,
    "mean", "median", "sd", "mad",
    ~ posterior::quantile2(.x, probs = c(0.025, 0.05, 0.95, 0.975)),
    "rhat", "ess_bulk", "ess_tail"
  ))
}

## The estimates every Bayes factor method gives, from the full model's
## summary, as one row in the same columns for all five: x1's slope
## (flatcor's b[1], BayesFactor's x1) as slope_x1_*, and the population
## R-squared (R_squared in both) as posterior_r_squared_*, each with its
## mean, median, sd and the 90% and 95% intervals
estimates_of <- function(summary, slope_variable) {
  one <- function(variable, prefix) {
    row <- summary[summary$variable == variable, ]
    values <- unlist(row[c("mean", "median", "sd", "q2.5", "q5", "q95", "q97.5")])
    tibble::as_tibble_row(stats::setNames(as.list(values), paste0(prefix, "_", names(values))))
  }
  bind_cols(one(slope_variable, "slope_x1"), one("R_squared", "posterior_r_squared"))
}

## The population R-squared of each posterior draw of a regression, as
## flatcor defines it: b' S b / (b' S b + sigma^2), with S the predictors'
## covariance (divided by n). `slopes`: a draw per row; `noise_variance`:
## sigma^2 per draw.
r_squared_of_draws <- function(slopes, noise_variance, predictors) {
  centred <- scale(predictors, scale = FALSE)
  covariance <- crossprod(centred) / nrow(predictors)
  explained <- rowSums((slopes %*% covariance) * slopes)
  explained / (explained + noise_variance)
}

## The sample R-squared of the outcome on some predictors (0 for none)
sample_r_squared <- function(predictors, outcome) {
  if (ncol(predictors) == 0) 0 else summary(lm(outcome ~ predictors))$r.squared
}

## The log BF of model A (columns predictors_a) against model B
## (predictors_b), for one method, with everything computed on the way, as
## one row (a tibble) for the per-dataset files (engine/results/per_dataset_files.R):
##   id, seed        the name the Stan fits and bridge sampling are seeded
##                   from, and the seed (model B's is seed + 1)
##   log_bf, error   the log BF and its approximate Monte Carlo SE
##   divergent       Stan's divergent transitions of both fits
##   n, k_a, k_b, r_squared_a, r_squared_b
##                   the data's size, both models' numbers of predictors and
##                   their sample R-squared
##   log_ml_a, error_a, ... (and _b)
##                   per model: the log marginal likelihood, its error,
##                   divergences, bridge sampling's iterations, seconds, and
##                   the largest R-hat and smallest bulk and tail ESS over
##                   its Stan variables
##   slope_x1_mean, slope_x1_median, slope_x1_sd, slope_x1_q2.5, ... q97.5,
##   posterior_r_squared_mean, ... _q97.5
##                   model A's posterior of x1's slope (its first column)
##                   and of the population R-squared (estimates_of())
##   variables       per model, the summary of every Stan variable (flatcor)
##   chains          per model, the sampler per chain (flatcor)
## For JZS and Zellner-Siow: BayesFactor's Bayes factor of each model against
## the intercept-only model and its error, no Stan; and model A's posterior
## under the same prior (BayesFactor's posterior()), with R_squared added per
## draw as flatcor defines it: the same estimates as the three priors, the
## summary of every variable (`variables`, model "a", in flatcor's columns),
## posterior_draws and seconds_posterior.
log_bayes_factor_between <- function(method, predictors_a, predictors_b, outcome, name) {
  seed <- seed_of(name)
  common <- tibble(
    id = name, seed = seed, method = method, n = length(outcome),
    k_a = ncol(predictors_a), k_b = ncol(predictors_b),
    r_squared_a = sample_r_squared(predictors_a, outcome),
    r_squared_b = sample_r_squared(predictors_b, outcome)
  )

  # the three priors: flatcor
  if (method %in% names(contenders)) {
    # once per worker, one worker at a time (shared/flatcor_models.R)
    compile_flatcor_models()
    models <- models_as_formulas(predictors_a, predictors_b, outcome)
    result <- suppressWarnings(flatcor::bayes_factor_models(
      models$formula_a,
      models$formula_b,
      models$data,
      prior = contenders[[method]],
      iter_sampling = bayes_factor_draws,
      seed = seed
    ))
    per_model <- function(part) {
      m <- result$models[[part]]
      # (a variable that never changes, such as R at k = 0, has no R-hat or ESS)
      worst <- function(column, summary) {
        values <- m$summary[[column]]
        if (all(is.na(values))) NA_real_ else summary(values, na.rm = TRUE)
      }
      row <- tibble(
        log_ml = m$log_marginal_likelihood, error = m$error, divergent = m$divergent,
        bridge_iterations = m$bridge_sampling$iterations,
        seconds_sampling = m$seconds[["sampling"]],
        seconds_bridge = m$seconds[["bridge_sampling"]],
        rhat_max = worst("rhat", max),
        ess_bulk_min = worst("ess_bulk", min),
        ess_tail_min = worst("ess_tail", min)
      )
      names(row) <- paste0(names(row), "_", part)
      row
    }
    long <- function(table) {
      bind_rows(lapply(c("a", "b"), function(part) {
        cbind(model = part, as.data.frame(result$models[[part]][[table]]))
      }))
    }
    return(bind_cols(
      common,
      tibble(log_bf = result$log_bayes_factor, error = result$error,
             divergent = sum(result$divergent)),
      per_model("a"), per_model("b"),
      if (ncol(predictors_a) > 0) estimates_of(result$models$a$summary, "b[1]"),
      tibble(variables = list(long("summary")), chains = list(long("sampler")))
    ))
  }

  # the references: BayesFactor's regression Bayes factor of each model
  # against the intercept-only model, from R-squared, n and k
  scale <- switch(method,
    `JZS default` = sqrt(2) / 4,
    `Zellner-Siow` = 1,
    stop("Unknown method: ", method)
  )
  log_bf_against_intercept <- function(predictors) {
    if (ncol(predictors) == 0) {
      return(c(bf = 0, error = 0))
    }
    bf <- BayesFactor::linearReg.R2stat(
      length(outcome), ncol(predictors), sample_r_squared(predictors, outcome),
      rscale = scale,
      simple = FALSE
    )
    c(bf = bf$bf, error = bf$properror)
  }
  a <- log_bf_against_intercept(predictors_a)
  b <- log_bf_against_intercept(predictors_b)

  # estimation: model A's posterior under the same prior (BayesFactor's
  # lmBF() and posterior(), with the same scale), drawn in the stream of
  # its own name (engine/seeds.R). Columns x1 ... xk, so x1 is model A's
  # first predictor; also mu, sig2 and g.
  started <- Sys.time()
  data_a <- data.frame(outcome = outcome, predictors_a)
  names(data_a) <- c("outcome", paste0("x", seq_len(ncol(predictors_a))))
  draws <- with_stream_of(name_of(name, "posterior"), {
    model_a <- BayesFactor::lmBF(outcome ~ ., data = data_a, rscaleCont = scale, progress = FALSE)
    BayesFactor::posterior(model_a, iterations = posterior_draws, progress = FALSE)
  })
  draws <- unclass(as.matrix(draws))
  # and the population R-squared of every draw, as flatcor's R_squared
  draws <- cbind(draws, R_squared = r_squared_of_draws(
    draws[, names(data_a)[-1], drop = FALSE], draws[, "sig2"], predictors_a
  ))
  summary <- summarise_posterior(posterior::as_draws_matrix(draws))

  bind_cols(
    common,
    tibble(
      log_bf = a[["bf"]] - b[["bf"]],
      error = sqrt(a[["error"]]^2 + b[["error"]]^2),
      divergent = 0,
      log_bf_intercept_a = a[["bf"]], error_intercept_a = a[["error"]],
      log_bf_intercept_b = b[["bf"]], error_intercept_b = b[["error"]]
    ),
    estimates_of(summary, "x1"),
    tibble(
      posterior_draws = posterior_draws,
      seconds_posterior = as.numeric(difftime(Sys.time(), started, units = "secs")),
      variables = list(cbind(model = "a", summary))
    )
  )
}

## ---- The p-value -------------------------------------------------------------------------

## The two-sided p-value of the first predictor's slope (x1) in the ordinary
## least squares fit of the outcome on all predictors, with its t statistic
p_value_of_first <- function(predictors, outcome) {
  coefficients <- summary(lm(outcome ~ predictors))$coefficients
  c(t = coefficients[2, "t value"], p = coefficients[2, "Pr(>|t|)"])
}
