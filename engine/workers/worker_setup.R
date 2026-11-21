## =====================================================================
##  Worker setup: how many workers, and the environment every worker
##  inherits. Sourced (by engine/load_code.R) before any worker starts, so
##  the scheduler's workers (engine/workers/scheduler.R) and the
##  pipeline's (_targets.R) inherit the same settings. The project's own
##  part comes from <project>/engine_settings/settings.R.
## =====================================================================

## Packages that keep compiled code in R's user cache folder (flatcor's
## Stan models): keep that in cache/, writable everywhere
if (!nzchar(Sys.getenv("R_USER_CACHE_DIR"))) {
  Sys.setenv(R_USER_CACHE_DIR = file.path(getwd(), "cache", "r_user_cache"))
}

## What this project's workers should inherit (<project>/engine_settings/settings.R)
prepare_workers()

## One thread per process for linear algebra (BLAS, OpenMP). Each batch
## already keeps its cores busy (cores_per_batch), and the workers are
## sized for that; a BLAS that starts a thread per core in every worker
## overloads the machine instead (a load of about 200 on 64 cores, seen on
## AWS). A value set from outside (a cluster job, say) is kept.
local({
  for (variable in c("OPENBLAS_NUM_THREADS", "OMP_NUM_THREADS", "MKL_NUM_THREADS")) {
    if (!nzchar(Sys.getenv(variable))) do.call(Sys.setenv, stats::setNames(list("1"), variable))
  }
})

## A worker per batch running at once: each batch keeps cores_per_batch
## cores busy (<project>/engine_settings/settings.R), and one core is left
## for the main process. The cores are those given to this run: on a
## cluster, the job's allocation (parallelly reads SLURM, PBS and cgroups),
## not all cores of the node.
worker_count <- function() max(1, (parallelly::availableCores() - 1) %/% cores_per_batch)
