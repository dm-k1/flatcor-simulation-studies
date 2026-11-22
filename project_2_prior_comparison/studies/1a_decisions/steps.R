## =====================================================================
##  Study 1a: its steps in the pipeline (_targets.R collects every
##  study's steps.R; study_steps(), engine/pipeline/pipeline_steps.R)
##  How do the priors' Bayes factors differ in the decisions they lead to?
##  Every step's name ends in _1a, so tar_make() can run the study alone.
## =====================================================================

list(
  # stage 1, every cell until its rates reach their targets or its cap: the
  # part "1a-stage1" its design.R declares
  steps_until_target("stage1_runs_1a", "1a-stage1"),
  # layer 1: every dataset's rows, one per method (engine/results/per_dataset_files.R);
  # the Stan summaries and samplers in files of their own, one per k
  tar_target(
    per_dataset_stage1_1a,
    write_per_dataset(stage1_runs_1a, "1a_stage1", gzip = TRUE, split_by = "k"),
    format = "file"
  ),
  tar_target(stage1_rows_1a, read_per_dataset(per_dataset_stage1_1a)),

  # the rates that stopped each cell, and the diagnostics
  tar_target(rates_table_1a, decision_rates_1a(stage1_rows_1a)),
  tar_target(diagnostics_table_1a, diagnostics_1a(stage1_rows_1a)),
  tar_target(
    results_1a,
    save_results_1a(rates_table_1a, diagnostics_table_1a),
    format = "file"
  )
)
