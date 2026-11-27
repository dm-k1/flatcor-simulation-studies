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
  "bayes_factor_models", "fit_regression", "bridge_sampler",
  "cmdstan_model", "sample" # sample: model$sample(), a CmdStan fit
)

## The seams
replayed_functions <- c(
  "log_bayes_factor_between" # shared/comparison_methods.R: flatcor's Bayes factors
)

## Skipped in the dry run, which samples nothing: compiling flatcor's
## models, with what each gives instead (shared/flatcor_models.R).
## The static check fails when one of these no longer exists, so a rename never
## silently brings compiling back into the dry run.
skipped_in_dry_run <- list(
  compile_flatcor_models = function() invisible(TRUE),
  flatcor_stan_model = function() "dry run: no model"
)


## flatcor's Bayes factor between two models (the four priors, and the
## intercept-only model's two fits; the references are cheap and run as
## they are)
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
