## =====================================================================
##  Study 2a: its steps in the pipeline (_targets.R collects every
##  study's steps.R; study_steps(), R/engine/pipeline/pipeline_steps.R)
##  Is the posterior computed correctly?
##  Every step's name ends in _2a, so tar_make() can run the study alone.
## =====================================================================

list(
  # the SBC fits, a batch of a setting per batch: the part 2a declares
  steps_once("sbc_2a", "2a", iteration = "list"),
  # layer 1: every fit's rows (R/engine/results/per_dataset_files.R)
  tar_target(
    per_dataset_fits_2a,
    write_per_dataset(bind_rows(lapply(sbc_2a, `[[`, "stats")), "2a_sbc_fits"),
    format = "file"
  ),
  tar_target(
    per_dataset_diagnostics_2a,
    write_per_dataset(bind_rows(lapply(sbc_2a, `[[`, "diagnostics")), "2a_sbc_diagnostics"),
    format = "file"
  ),
  tar_target(
    results_2a,
    save_results_2a(
      read_per_dataset(per_dataset_fits_2a), read_per_dataset(per_dataset_diagnostics_2a)
    ),
    format = "file"
  )
)
