## =====================================================================
##  Study 1a: its steps in the pipeline (_targets.R collects every
##  study's steps.R; study_steps(), R/engine/pipeline/pipeline_steps.R)
##  Does the software draw the prior it claims?
##  Every step's name ends in _1a, so tar_make() can run the study alone.
## =====================================================================

list(
  # the draws of each setting: the part 1a declares (its design.R;
  # steps_once(), R/engine/pipeline/pipeline_steps.R)
  steps_once("samples_1a", "1a", iteration = "list"),
  tar_target(predictors_1a, data_prior_only_designs()),
  # layer 1: the draws, the recipe's draws, each setting's run (R/engine/report/per_dataset_files.R)
  tar_target(
    per_dataset_draws_1a,
    write_per_dataset(draws_table_1a(samples_1a), "1a_prior_draws", gzip = TRUE),
    format = "file"
  ),
  tar_target(
    per_dataset_recipe_1a,
    write_per_dataset(
      recipe_table_1a(predictors_1a[["three_correlated"]]), "1a_recipe_draws", gzip = TRUE
    ),
    format = "file"
  ),
  tar_target(
    per_dataset_settings_1a,
    write_per_dataset(settings_table_1a(samples_1a), "1a_settings"),
    format = "file"
  ),
  tar_target(
    comparisons_1a,
    compare_1a(
      read_per_dataset(per_dataset_draws_1a), read_per_dataset(per_dataset_recipe_1a),
      read_per_dataset(per_dataset_settings_1a), predictors_1a
    )
  ),
  tar_target(results_1a, save_results_1a(comparisons_1a), format = "file")
)
