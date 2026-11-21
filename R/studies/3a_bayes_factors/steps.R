## =====================================================================
##  Study 3a: its steps in the pipeline (_targets.R collects every
##  study's steps.R; study_steps(), R/engine/pipeline/pipeline_steps.R)
##  Are the Bayes factors right?
##  Every step's name ends in _3a, so tar_make() can run the study alone.
## =====================================================================

list(
  # part A, calibration, until their targets are reached: the part "3a" its design.R declares
  steps_until_target("calibration_runs_3a", "3a"),
  # layer 1: every dataset's row (R/engine/results/per_dataset_files.R)
  tar_target(
    per_dataset_calibration_3a,
    write_per_dataset(calibration_runs_3a, "3a_calibration"),
    format = "file"
  ),
  tar_target(calibration_rows_3a, read_per_dataset(per_dataset_calibration_3a)),
  # the data-averaged posterior decides; the bins and the line describe
  tar_target(averaged_table_3a, data_averaged_posterior_3a(calibration_rows_3a)),
  tar_target(bins_table_3a, calibration_bins_3a(calibration_rows_3a)),
  tar_target(line_table_3a, calibration_line_3a(calibration_rows_3a)),

  # part B, bridge sampling's error: each dataset run repeat_runs_3a times,
  # until its own targets are reached: the part "3a-repeats"
  steps_until_target("repeated_3a", "3a-repeats"),
  tar_target(
    per_dataset_repeats_3a,
    write_per_dataset(repeated_3a, "3a_repeated_runs"),
    format = "file"
  ),
  tar_target(repeated_rows_3a, read_per_dataset(per_dataset_repeats_3a)),
  tar_target(spread_table_3a, repeat_spread_3a(repeated_rows_3a, repeat_runs_3a)),
  # the factor by which the reported error falls short, over every cell:
  # used by 1b and 3b for quantities about one given dataset
  tar_target(shortfall_3a, bridge_shortfall_3a(repeated_rows_3a)),

  # also reported, and the results file
  tar_target(diagnostics_table_3a, diagnostics_3a(calibration_rows_3a)),
  tar_target(
    results_3a,
    save_results_3a(
      averaged_table_3a, bins_table_3a, line_table_3a, spread_table_3a, shortfall_3a,
      diagnostics_table_3a
    ),
    format = "file"
  )
)
