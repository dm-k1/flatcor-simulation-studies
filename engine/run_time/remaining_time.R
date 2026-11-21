## =====================================================================
##  During a run: how much time is left, per part, per study and in all
##
##    Rscript engine/run_time/remaining_time.R               a full run's store
##    VALIDATION_SMOKE=1 Rscript engine/run_time/remaining_time.R   the smoke test's
##
##  It reads only the store (the plans and the finished batches), so it can
##  run beside a running run, on the same machine, without disturbing it.
##  For each part: the datasets the stopping rule has asked for so far and
##  those done; the core hours per dataset, the median over its finished
##  batches; and what is left, the datasets not done times that. A cell not
##  judged yet may still ask for more, so the estimate grows as cells are
##  judged, and settles as the run goes. The scheduler prints the same
##  estimate as it runs (engine/workers/scheduler.R).
## =====================================================================

source(file.path("engine", "load_code.R"))
for (package in step_packages) {
  suppressPackageStartupMessages(library(package, character.only = TRUE))
}
for (file in code_files()) source(file)
if (!dir.exists(store)) stop("No store at ", store, ": no run to estimate")

## Every part's batches so far: from its plan (a part that runs until its
## targets are reached) or as declared (a part that runs once)
batches_so_far <- function(name) {
  part <- declared_parts[[name]]
  if (is.null(part$cells)) return(part$batches)
  plan <- read_plan(name, store, part$cells, part$first_datasets)
  batches_of_plan(plan, part$batch_size)
}

rows <- lapply(names(declared_parts), function(name) {
  batches <- batches_so_far(name)
  finished <- lapply(seq_len(nrow(batches)), function(i) {
    read_batch(name, batch_row(batches, i), store)
  })
  done <- !vapply(finished, is.null, logical(1))
  datasets <- vapply(seq_len(nrow(batches)), function(i) datasets_in(batch_row(batches, i)), 1)
  seconds <- vapply(finished[done], `[[`, numeric(1), "seconds")
  per_dataset <- seconds / datasets[done]
  hours_per_dataset <- if (sum(done) >= 2) {
    stats::median(per_dataset) * cores_per_batch / 3600
  } else {
    NA_real_
  }
  data.frame(
    study = declared_parts[[name]]$study, part = name,
    datasets_asked = sum(datasets), datasets_done = sum(datasets[done]),
    core_hours_spent = sum(seconds) * cores_per_batch / 3600,
    core_hours_left = sum(datasets[!done]) * hours_per_dataset
  )
})
table <- do.call(rbind, rows)

per_study <- stats::aggregate(
  cbind(core_hours_spent, core_hours_left) ~ study, data = table, FUN = sum, na.action = na.pass
)
workers <- worker_count()
cat("\nPer part:\n")
print(table, row.names = FALSE, digits = 3)
cat("\nPer study:\n")
print(per_study, row.names = FALSE, digits = 3)
left <- sum(table$core_hours_left, na.rm = TRUE)
cat(sprintf(
  "\nIn all: %.1f core hours spent, about %.1f left: %.1f hours on %d workers%s.\n",
  sum(table$core_hours_spent), left, left / (workers * cores_per_batch), workers,
  if (anyNA(table$core_hours_left)) " (NA: fewer than two batches of that part back yet)" else ""
))
