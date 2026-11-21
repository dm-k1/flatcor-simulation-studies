## =====================================================================
##  A full run from start to finish (run_all.R calls full_run())
##
##    1. from scratch, if asked (always for the smoke test and the dry run)
##    2. one commit of the package under test per run
##    3. what the workers share, built once (prepare_models())
##    4. the scheduler: every batch of every part the studies declare
##       (engine/workers/scheduler.R)
##    5. the pipeline: every study's results, from the saved batches (_targets.R)
##    6. which results there are, and the check of them
##       (engine/tests/check_results.R)
##
##  `requested`: the studies to run (their codes, as "3a"), or none for all.
##  A study's steps in the pipeline end in _<study>, so tar_make() can run
##  one study's steps alone.
## =====================================================================

full_run <- function(requested = character(0)) {
  started <- Sys.time()
  fresh <- identical(Sys.getenv("VALIDATION_FRESH"), "1")

  ## ---- 1. From scratch: always for the smoke test, on request for a real run ---------
  if (fresh && length(requested) > 0) {
    stop(
      "VALIDATION_FRESH=1 starts the whole validation from scratch: run it without ",
      "naming studies. To redo one study, mark its steps outdated first, ",
      "targets::tar_invalidate(names = tidyselect::ends_with(\"_<study>\")), then ",
      "Rscript run_all.R <study>."
    )
  }
  if (dry && recording) stop("VALIDATION_DRY=1 replays recordings; it cannot also record them.")
  if (recording && !smoke) {
    stop(
      "Recordings for the dry run come from a smoke test: VALIDATION_SMOKE=1 VALIDATION_RECORD=1"
    )
  }
  if (smoke || fresh) unlink(c(store, file.path(results_root, "studies")), recursive = TRUE)
  # a recording run replaces every recording, so none is left from an older
  # design or package (engine/tests/dry_run.R)
  if (recording) unlink(recordings_folder, recursive = TRUE)

  ## ---- 2. One commit of the package under test per run ----------------------------
  ## The store remembers the commit of the package under test (tested_package,
  ## <project>/engine_settings/settings.R) it was started with; continuing
  ## with another would mix two versions in one results file.
  package_commit <- utils::packageDescription(tested_package)$RemoteSha
  if (is.null(package_commit)) package_commit <- "not installed from GitHub"
  commit_file <- file.path(store, paste0(tested_package, "_commit"))
  if (file.exists(commit_file)) {
    started_with <- readLines(commit_file)
    if (!identical(started_with, package_commit)) {
      stop(
        "This run was started with ", tested_package, " ", started_with, "; installed now is ",
        package_commit, ". Continuing would mix the two in the results. Install the ",
        "first again (renv::restore()), or start from scratch: VALIDATION_FRESH=1 Rscript run_all.R"
      )
    }
  } else {
    dir.create(store, recursive = TRUE, showWarnings = FALSE)
    writeLines(package_commit, commit_file)
  }

  ## ---- 3. What the workers share, built before any of them starts -------------------
  ## prepare_models() (<project>/engine_settings/settings.R): done here,
  ## once, so no worker's own compile rebuilds a shared file under another
  prepare_models()

  ## ---- 4. The scheduler: every part the studies declare -----------------------------
  ## A study run alone brings along the parts its results also use (`needs`),
  ## so it gives the same results as in a full run
  parts <- declared_parts
  if (length(requested) > 0) {
    wanted <- names(Filter(function(part) part$study %in% requested, parts))
    needed <- unlist(lapply(parts[wanted], `[[`, "needs"))
    parts <- parts[names(parts) %in% c(wanted, needed)]
  }
  until_target <- Filter(function(part) !is.null(part$cells), parts)
  for (name in names(until_target)) until_target[[name]]$name <- name
  run_once <- lapply(Filter(function(part) !is.null(part$batches), parts), `[[`, "batches")

  ## The budget: raising it is a decision written in the log:
  ## VALIDATION_BUDGET_CORE_HOURS=3000. The run stops when what it has
  ## spent plus what it still expects to cost is more (engine/workers/scheduler.R).
  budget_core_hours <- as.numeric(Sys.getenv("VALIDATION_BUDGET_CORE_HOURS", "2500"))

  ## the core hours the pipeline's own steps have cost so far (a run that
  ## continues): every step's seconds, times the cores a batch keeps busy
  pipeline_core_hours <- function() {
    if (!file.exists(file.path(store, "meta", "meta"))) return(0)
    steps <- targets::tar_meta(fields = c("type", "seconds"), store = store)
    sum(steps$seconds[steps$type %in% c("stem", "branch")], na.rm = TRUE) * cores_per_batch / 3600
  }

  all_done <- run_parts(
    until_target, run_once, store, budget_core_hours,
    # the dry run samples nothing: every batch in this process
    workers = if (dry) 0 else worker_count(),
    spent_elsewhere = pipeline_core_hours(),
    one_extension = smoke
  )
  if (!all_done) {
    stop(
      "Stopped: what the run still expects to cost does not fit the budget. Every finished ",
      "batch is saved. To go on, raise the budget (VALIDATION_BUDGET_CORE_HOURS) or change a ",
      "target (<project>/engine_settings/stopping_rule.R, or a study's deltas), and start ",
      "again: the run continues where it was. The study results are made only when every ",
      "cell is done.",
      call. = FALSE
    )
  }

  ## ---- 5. The pipeline: every study's results -----------------------------------------
  ## The batches the scheduler ran are read from the store (batch_rows(),
  ## engine/workers/batches.R), not run again; what is left takes seconds
  if (length(requested) == 0) {
    targets::tar_make(store = store)
  } else {
    targets::tar_make(names = tidyselect::ends_with(!!paste0("_", requested)), store = store)
  }

  ## ---- 6. Which results there are, and the check of them --------------------------------
  results_folder <- file.path(results_root, "studies")
  for (file in sort(list.files(results_folder, pattern = "^study_.*[.]rds$", full.names = TRUE))) {
    setup <- readRDS(file)$setup
    cat(sprintf(
      "%s: finished %s, commit %s, %s %s (%s)%s\n", basename(file), setup$finished,
      setup$commit, tested_package, setup[[tested_package]],
      substr(setup[[paste0(tested_package, "_commit")]], 1, 7),
      if (isTRUE(setup$smoke)) " (smoke test)" else ""
    ))
  }
  studies_run <- if (length(requested) > 0) {
    requested
  } else {
    unique(vapply(declared_parts, `[[`, "", "study"))
  }
  check_results(results_folder, studies_run, package_commit, smoke)

  minutes <- as.numeric(difftime(Sys.time(), started, units = "mins"))
  cat(sprintf("Run took %.1f minutes.\n", minutes))
}
