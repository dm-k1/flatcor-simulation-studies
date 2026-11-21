## =====================================================================
##  Study 3b: its steps in the pipeline (_targets.R collects every
##  study's steps.R; study_steps(), R/engine/pipeline/pipeline_steps.R)
##  Do the Bayes factors meet the default-prior criteria?
##  Every step's name ends in _3b, so tar_make() can run the study alone.
## =====================================================================

list(
  # 3b.1, 3b.2: one dataset per batch, run once; 3b.3-3b.6, the rates, and
  # 3b.8, 3b.9, k growing with n, until their targets are reached: the parts 3b's design.R declares
  steps_once("formula_3b", "3b-formula"),
  steps_until_target("rates_3b", "3b-rates"),
  steps_until_target("growing_3b", "3b-growing"),

  # 3b.7: the prior's draws with the sample and the population covariance
  tar_target(draws_intrinsic_3b, intrinsic_draws_of_3b()),

  # layer 1: every Bayes factor's row and the draws (R/engine/results/per_dataset_files.R)
  tar_target(per_dataset_formula_3b, write_per_dataset(formula_3b, "3b_formula"), format = "file"),
  tar_target(per_dataset_rates_3b, write_per_dataset(rates_3b, "3b_rates"), format = "file"),
  tar_target(
    per_dataset_growing_3b,
    write_per_dataset(growing_3b, "3b_growing_k", split_by = "growth"),
    format = "file"
  ),
  tar_target(
    per_dataset_intrinsic_3b,
    write_per_dataset(draws_intrinsic_3b, "3b_intrinsic_draws", gzip = TRUE),
    format = "file"
  ),

  # the results file, from the per-dataset files
  tar_target(
    results_3b,
    save_results_3b(
      read_per_dataset(per_dataset_formula_3b),
      read_per_dataset(per_dataset_rates_3b),
      read_per_dataset(per_dataset_growing_3b),
      read_per_dataset(per_dataset_intrinsic_3b),
      shortfall_3a
    ),
    format = "file"
  )
)
