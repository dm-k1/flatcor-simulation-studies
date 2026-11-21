## =====================================================================
##  What every worker starts with: its environment and the code. Sourced by
##  _targets.R (the pipeline's workers) and run_all.R (the queue's workers,
##  R/engine/queue.R) before any worker starts, so both kinds inherit the
##  same settings. The project's own part comes from R/project/settings.R.
## =====================================================================

source(file.path("R", "project", "settings.R"))

## Packages that keep compiled code in R's user cache folder (flatcor's
## Stan models): keep that in cache/, writable everywhere
if (!nzchar(Sys.getenv("R_USER_CACHE_DIR"))) {
  Sys.setenv(R_USER_CACHE_DIR = file.path(getwd(), "cache", "r_user_cache"))
}

## What this project's workers should inherit (R/project/settings.R)
prepare_workers()

## One thread per process for linear algebra (BLAS, OpenMP). Each piece of
## work already keeps its cores busy (cores_per_piece), and the workers are
## sized for that; a BLAS that starts a thread per core in every worker
## overloads the machine instead (a load of about 200 on 64 cores, seen on
## AWS). A value set from outside (a cluster job, say) is kept.
local({
  for (variable in c("OPENBLAS_NUM_THREADS", "OMP_NUM_THREADS", "MKL_NUM_THREADS")) {
    if (!nzchar(Sys.getenv(variable))) do.call(Sys.setenv, stats::setNames(list("1"), variable))
  }
})

## A worker per piece of work running at once: each piece keeps
## cores_per_piece cores busy (R/project/settings.R), and one core is left
## for the main process. The cores are those given to this run: on a
## cluster, the job's allocation (parallelly reads SLURM, PBS and cgroups),
## not all cores of the node.
worker_count <- function() max(1, (parallelly::availableCores() - 1) %/% cores_per_piece)

## The code, in the order it is sourced: the engine, the project's shared
## code (its settings first), the data sets, each study's design and then
## its code (the studies are the folders of R/2_studies/), and last, only to
## record or replay the expensive calls, the dry run's file, which replaces
## a few of the functions before it (R/dry_run/replay.R)
code_files <- function() {
  engine <- file.path("R", "engine", c(
    "random_streams.R", "pipeline.R", "expectations.R", "results.R", "per_dataset.R",
    "rounds.R", "parts.R", "steps.R"
  ))
  project <- list.files(file.path("R", "project"), pattern = "[.]R$", full.names = TRUE)
  project <- project[!basename(project) %in% c("settings.R", "seams.R")]
  studies <- sort(list.dirs(file.path("R", "2_studies"), recursive = FALSE))
  replay <- identical(Sys.getenv("VALIDATION_DRY"), "1") ||
    identical(Sys.getenv("VALIDATION_RECORD"), "1")
  c(
    engine,
    file.path("R", "project", "settings.R"), project,
    list.files(file.path("R", "1_data"), pattern = "[.]R$", full.names = TRUE),
    file.path(studies, "design.R"),
    file.path(studies, "code.R"),
    if (replay) file.path("R", "dry_run", "replay.R")
  )
}
