## =====================================================================
##  The project's settings: everything the engine (engine/) needs to know
##  about this project. A new project writes its own version of this file
##  (and its studies and data) and leaves the engine as it is.
## =====================================================================

## The package under test. Every results file records its version and
## commit (fields named after it), and a run never continues with another
## commit of it than the run started with (run_all.R).
tested_package <- "flatcor"

## The packages every step and every batch loads
step_packages <- c("flatcor", "dplyr")

## The cores one batch keeps busy: Stan runs its 4 chains in
## parallel. A worker per that many cores (worker_count(),
## engine/workers/worker_setup.R); a batch's core hours are its hours times this.
cores_per_batch <- 4

## Before any worker starts, once: build what the workers share, flatcor's
## models (tested_package/flatcor_models.R). The dry run skips it.
prepare_models <- function() compile_flatcor_models()

## What a batch gets as `model` (batch_work(), engine/workers/batches.R):
## flatcor's Stan model. The dry run gives a stand-in.
batch_model <- function() flatcor_stan_model()

## What a results file records about the run besides the engine's own
## fields (engine/results/results_files.R)
project_setup <- function() {
  list(CmdStan = tryCatch(
    as.character(cmdstanr::cmdstan_version()),
    error = function(e) NA_character_, warning = function(w) NA_character_
  ))
}

## Functions of the project that may read or write files (the static check,
## engine/tests/static_check.R, rule b): the compile lock, the copy of CmdStan's TBB library
project_file_functions <- c("compile_flatcor_models", "prepare_workers")

## Before any worker starts: what every worker should inherit (called by
## engine/workers/worker_setup.R). Here: on Linux, every Stan model loads CmdStan's TBB
## library (libtbb.so.2) when it starts, and compiling a model can make
## CmdStan rebuild that library in place. With several workers, one worker's
## compile then removes it under a model another worker is starting
## ("libtbb.so.2: cannot open shared object file", seen with 7 workers on
## AWS). A copy made here, before any worker starts, and put first on the
## library path the workers inherit, is never touched by such a rebuild.
prepare_workers <- function() {
  if (Sys.info()[["sysname"]] == "Linux") {
    tbb_copy <- file.path(getwd(), "cache", "tbb")
    dir.create(tbb_copy, recursive = TRUE, showWarnings = FALSE)
    tbb_libraries <- list.files(
      file.path(cmdstanr::cmdstan_path(), "stan", "lib", "stan_math", "lib", "tbb"),
      pattern = "^libtbb.*[.]so[.]2$", full.names = TRUE
    )
    file.copy(tbb_libraries, tbb_copy, overwrite = TRUE)
    library_path <- Sys.getenv("LD_LIBRARY_PATH")
    if (!startsWith(library_path, tbb_copy)) {
      library_path <- paste(c(tbb_copy, library_path[nzchar(library_path)]), collapse = ":")
      Sys.setenv(LD_LIBRARY_PATH = library_path)
    }
  }
  invisible()
}
