## =====================================================================
##  The dry run's seams for this project (engine/tests/dry_run.R sources this
##  file last, after every study's code): the expensive calls, each replaced
##  by a version that records or replays it, and what the dry run skips.
##  Every expensive call in the studies' code must be inside one of the
##  seams (the static check enforces it: engine/tests/static_check.R).
## =====================================================================

## The expensive calls: every call of one of these must be inside a seam
## (the static check, engine/tests/static_check.R, rule a)
expensive_calls <- c(
  "bayes_factor_models", "fit_regression", "compute_SBC", "bridge_sampler",
  "cmdstan_model", "sample" # sample: model$sample(), a CmdStan fit
)

## The seams. fit_regression is flatcor's, called by the studies without
## flatcor::, so a function of that name here comes first.
replayed_functions <- c(
  "log_bayes_factor_between", # comparison_methods.R: flatcor's Bayes factors (1b, 3a, 3b)
  "fit_regression",           # flatcor's fit (2b)
  "sample_setting_1a",        # 1a: the prior draws of one setting
  "sbc_batch_2a"              # 2a: the SBC fits of one batch
)

## Skipped in the dry run, which samples nothing: compiling flatcor's
## models, with what each gives instead (tested_package/flatcor_models.R).
## The static check fails when one of these no longer exists, so a rename never
## silently brings compiling back into the dry run.
skipped_in_dry_run <- list(
  compile_flatcor_models = function() invisible(TRUE),
  flatcor_stan_model = function() "dry run: no model"
)


## flatcor's Bayes factor between two models (the three priors; the
## references are cheap and run as they are)
replace_function("log_bayes_factor_between", function(original) {
  function(method, predictors_a, predictors_b, outcome, name) {
    if (!(method %in% names(contenders))) {
      return(original(method, predictors_a, predictors_b, outcome, name))
    }
    replayable(
      "bayes_factor",
      shape = list(
        prior = contenders[[method]], k_a = ncol(predictors_a), k_b = ncol(predictors_b)
      ),
      inputs = list(method, predictors_a, predictors_b, outcome, name, bayes_factor_draws),
      original(method, predictors_a, predictors_b, outcome, name)
    )
  }
})

## 1a: the prior draws of one setting (`model` is not part of the inputs:
## in the dry run there is none)
replace_function("sample_setting_1a", function(original) {
  function(setting, predictors, model) {
    replayable(
      "sample_setting_1a",
      shape = list(prior = setting$prior, design = setting$design),
      inputs = list(setting, predictors, start_draws_1a),
      original(setting, predictors, model)
    )
  }
})

## 2a: the SBC fits of one batch
replace_function("sbc_batch_2a", function(original) {
  function(setting, replications, model) {
    replayable(
      "sbc_batch_2a",
      shape = list(prior = setting$prior, k = setting$k, fits = length(replications)),
      inputs = list(setting, replications, iterations_2a),
      original(setting, replications, model)
    )
  }
})

## flatcor's fit (2b). What is kept of the fit: everything but the CmdStan
## fit object itself (its draws, divergences, sampler per chain, seconds,
## seed).
if (exists("estimates_2b", envir = overlay_env, inherits = FALSE)) {
  fit_regression <- function(formula, data, prior, ..., seed) {
    replayable(
      "fit_regression",
      shape = list(prior = prior, k = length(all.vars(formula)) - 1),
      inputs = list(deparse(formula), data, prior, list(...), seed),
      {
        fit <- flatcor::fit_regression(formula, data, prior = prior, ..., seed = seed)
        fit[c("draws", "divergent", "sampler", "seconds", "seed")]
      }
    )
  }
  attr(fit_regression, "replayed") <- TRUE
}
