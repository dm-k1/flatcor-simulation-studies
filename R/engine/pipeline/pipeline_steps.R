## =====================================================================
##  The pipeline's steps for the parts the studies declare (R/engine/study_form.R),
##  used in _targets.R. Each helper makes the steps a part needs, named after
##  `rows`, the step that holds the part's rows:
##
##    round_steps("fits_2b", "2b")      plan_fits_2b, pieces_fits_2b, fits_2b
##    once_steps("samples_1a", "1a")    pieces_samples_1a, samples_1a
##
##  A piece's rows are the ones run_all.R's queue saved in the store, read
##  back, or, if the queue has not run it (a plain tar_make(), a timing
##  run), computed in the step itself (piece_rows(), R/engine/workers/batches.R).
##  Every piece gets the pipeline's step `model` (piece_model(),
##  R/project/engine_settings/settings.R).
## =====================================================================

## A part that runs in rounds: its plan, its pieces and their rows
round_steps <- function(rows, part) {
  plan <- paste0("plan_", rows)
  pieces <- paste0("pieces_", rows)
  list(
    # the plan: per cell, the datasets of the rounds so far (R/engine/workers/batches.R);
    # read every time, but what follows reruns only if it changed
    targets::tar_target_raw(
      plan,
      bquote(read_plan(
        .(part), targets::tar_path_store(),
        declared_parts[[.(part)]]$cells, declared_parts[[.(part)]]$first_round
      )),
      cue = targets::tar_cue(mode = "always")
    ),
    # one piece of work per cell and batch; a new round only adds pieces
    targets::tar_target_raw(
      pieces, bquote(pieces_of_plan(.(as.name(plan)), declared_parts[[.(part)]]$batch_size))
    ),
    targets::tar_target_raw(
      rows, bquote(piece_rows(.(part), .(as.name(pieces)), model)),
      pattern = bquote(map(.(as.name(pieces))))
    )
  )
}

## A part that runs once: its pieces and their rows. `iteration`: "list" to
## keep each piece's result as it is, "vector" to bind them into one table.
once_steps <- function(rows, part, iteration = "vector") {
  pieces <- paste0("pieces_", rows)
  list(
    targets::tar_target_raw(pieces, bquote(declared_parts[[.(part)]]$pieces)),
    targets::tar_target_raw(
      rows, bquote(piece_rows(.(part), .(as.name(pieces)), model)),
      pattern = bquote(map(.(as.name(pieces)))), iteration = iteration
    )
  )
}
