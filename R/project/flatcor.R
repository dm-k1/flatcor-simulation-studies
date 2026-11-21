## =====================================================================
##  flatcor and Stan: building flatcor's models once, and the model the
##  studies sample directly. The engine reaches these only through
##  R/project/settings.R.
## =====================================================================

## ---- flatcor's Stan model and log density, built once ----------------------------
## flatcor builds two things (flatcor 2.1): the model, for sampling
## (flatcor_model(), cmdstanr's executable) and its log density, for the Bayes
## factors' bridge sampling (flatcor_density(), BridgeStan's library). Both
## are files in flatcor's cache folder, which R/engine/workers.R puts in
## cache/r_user_cache, so every worker finds them. run_all.R calls this once
## before any worker starts, so the workers only load them. Compiling can make
## CmdStan rebuild files every model shares (the main.o every model is linked
## with, the TBB library), so two compiles at once break each other ("cannot
## find src/cmdstan/main.o", seen with 7 workers on AWS): a worker that still
## has to build does so under a lock, one worker at a time (flatcor also locks
## its own cache folder). The lock is a folder: creating one is atomic, so
## only one worker succeeds; a lock older than 30 minutes is taken to be left
## by a worker that stopped while compiling, and removed.
compile_flatcor_models <- function() {
  if (isTRUE(getOption("validation_flatcor_compiled"))) {
    return(invisible(TRUE))
  }
  dir.create("cache", showWarnings = FALSE)
  lock <- file.path("cache", "compile.lock")
  repeat {
    if (dir.create(lock, showWarnings = FALSE)) break
    age <- difftime(Sys.time(), file.mtime(lock), units = "mins")
    if (!is.na(age) && age > 30) unlink(lock, recursive = TRUE)
    Sys.sleep(5)
  }
  on.exit(unlink(lock, recursive = TRUE))

  flatcor::flatcor_model("cmdstanr")
  flatcor::flatcor_density()
  options(validation_flatcor_compiled = TRUE)
  invisible(TRUE)
}

## The model for the studies that sample it directly (the prior only, SBC):
## the pipeline's first step, so that their workers find it compiled
flatcor_stan_model <- function() {
  compile_flatcor_models()
  flatcor::flatcor_model("cmdstanr")
}
prior_shape <- function(prior, k) utils::getFromNamespace("prior_shape", "flatcor")(prior, k)
