## =====================================================================
##  Study 1b: its steps in the pipeline (_targets.R collects every
##  study's steps.R; study_steps(), engine/pipeline/pipeline_steps.R)
##  Is the Bayes factor invariant to units and coding?
##  Every step's name ends in _1b, so tar_make() can run the study alone.
## =====================================================================

list(
  # the log Bayes factors, until their targets are reached: the part 1b declares (its design.R;
  # steps_until_target(), engine/pipeline/pipeline_steps.R)
  steps_until_target("log_bfs_1b", "1b"),
  # layer 1: every log Bayes factor's row (engine/results/per_dataset_files.R)
  tar_target(
    per_dataset_1b,
    write_per_dataset(log_bfs_1b, "1b_log_bayes_factors"),
    format = "file"
  ),
  tar_target(changes_1b, changes_of_1b(read_per_dataset(per_dataset_1b))),
  # a change of one dataset is judged against bridge sampling's error as
  # measured in 3a, part B (shortfall_3a, 3a's steps.R)
  tar_target(results_1b, save_results_1b(changes_1b, shortfall_3a), format = "file")
)
