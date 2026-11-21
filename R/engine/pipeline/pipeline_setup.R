## =====================================================================
##  The pipeline's settings (targets), used in _targets.R: the packages
##  every step loads, the root seed, and the workers for the final pass
## =====================================================================

pipeline_setup <- function() {
  targets::tar_option_set(
    packages = step_packages,
    # targets seeds R before each step from the step's name and this seed;
    # every draw that matters has its own seed (R/engine/seeds.R), but
    # whatever is left follows the same root seed
    seed = root_seed,
    # a worker per batch's cores (worker_count(), R/engine/workers/worker_setup.R).
    # The dry run samples nothing, so it runs every step in this one
    # process: starting workers would take longer than the steps.
    controller = if (dry) NULL else crew::crew_controller_local(
      workers = worker_count(),
      # a log per worker (its R output, including Stan's own messages), for
      # finding out why a step failed
      options_local = crew::crew_options_local(
        log_directory = file.path("cache", "logs", "workers")
      )
    )
  )
}
