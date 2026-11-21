## =====================================================================
##  The pipeline's steps for the parts the studies declare
##  (R/engine/study_form.R). Each helper makes the steps a part needs, named
##  after `rows`, the step that holds the part's rows:
##
##    steps_until_target("fits_2b", "2b")   plan_fits_2b, batches_fits_2b, fits_2b
##    steps_once("samples_1a", "1a")        batches_samples_1a, samples_1a
##
##  A batch's rows are the ones the scheduler saved in the store, read back,
##  or, if the scheduler has not run it (a plain tar_make(), a timing run),
##  computed in the step itself (batch_rows(), R/engine/workers/batches.R).
##  Every batch gets the pipeline's step `model` (batch_model(),
##  R/project/engine_settings/settings.R).
## =====================================================================

## A part that runs until its targets are reached: its plan, its batches and
## their rows
steps_until_target <- function(rows, part) {
  plan <- paste0("plan_", rows)
  batches <- paste0("batches_", rows)
  list(
    # the plan: per cell, the datasets so far (R/engine/workers/batches.R);
    # read every time, but what follows reruns only if it changed
    targets::tar_target_raw(
      plan,
      bquote(read_plan(
        .(part), targets::tar_path_store(),
        declared_parts[[.(part)]]$cells, declared_parts[[.(part)]]$first_datasets
      )),
      cue = targets::tar_cue(mode = "always")
    ),
    # one batch per cell and group of datasets; more datasets only add batches
    targets::tar_target_raw(
      batches, bquote(batches_of_plan(.(as.name(plan)), declared_parts[[.(part)]]$batch_size))
    ),
    targets::tar_target_raw(
      rows, bquote(batch_rows(.(part), .(as.name(batches)), model)),
      pattern = bquote(map(.(as.name(batches))))
    )
  )
}

## A part that runs once: its batches and their rows. `iteration`: "list" to
## keep each batch's result as it is, "vector" to bind them into one table.
steps_once <- function(rows, part, iteration = "vector") {
  batches <- paste0("batches_", rows)
  list(
    targets::tar_target_raw(batches, bquote(declared_parts[[.(part)]]$batches)),
    targets::tar_target_raw(
      rows, bquote(batch_rows(.(part), .(as.name(batches)), model)),
      pattern = bquote(map(.(as.name(batches)))), iteration = iteration
    )
  )
}
