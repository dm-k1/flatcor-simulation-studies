## =====================================================================
##  Study 2b: its steps in the pipeline (_targets.R collects every
##  study's steps.R; study_steps(), R/engine/pipeline/pipeline_steps.R)
##  How close are the estimates to a known truth?
##  Every step's name ends in _2b, so tar_make() can run the study alone.
## =====================================================================

list(
  # the fits, until their targets are reached: the part 2b declares (its
  # design.R; steps_until_target(), R/engine/pipeline/pipeline_steps.R: the
  # plan, its batches and their rows)
  steps_until_target("fits_2b", "2b"),
  # layer 1: every fit's row (R/engine/results/per_dataset_files.R)
  tar_target(per_dataset_2b, write_per_dataset(fits_2b, "2b_fits"), format = "file"),
  tar_target(results_2b, save_results_2b(read_per_dataset(per_dataset_2b)), format = "file")
)
