## =====================================================================
##  The dry run: the expensive calls recorded once, then replayed
##
##  The dry run (VALIDATION_DRY=1 Rscript run_all.R) tests the plumbing of
##  the whole validation in a minute or two: every step, every hand-over of
##  a table from one step to the next, the scheduler, every results file and
##  the check at the end. It runs the smoke test's design, in one
##  R process, with the calls to Stan and bridge sampling replaced by what
##  those same calls returned in a real smoke test.
##
##    VALIDATION_SMOKE=1 VALIDATION_RECORD=1 Rscript run_all.R
##        a smoke test that also records what each expensive call returned
##        (cache/dry_recordings/); once, and again when flatcor or what an
##        expensive call returns changes
##    VALIDATION_DRY=1 Rscript run_all.R
##        the dry run, from those recordings
##
##  This file changes no study's code. It is sourced after the studies'
##  files, and only in a recording run or the dry run (_targets.R, run_all.R);
##  a normal run never sees it. It replaces a few functions by versions that
##  record or replay the original: the seams, which the project lists in
##  validation/engine_settings/dry_run_seams.R (replayed_functions).
##  Every expensive call in the studies' code must be inside one of them
##  (the static check enforces it: engine/tests/static_check.R).
##
##  What the dry run tests: everything around the seams. What it does not:
##  the code inside them (Stan, bridge sampling, sample_setting_1a()'s
##  lengthening of the chains, ...), and whether the numbers are right; the
##  smoke test does that.
##
##  A recording is found by its call's exact inputs. A call with inputs not
##  seen in the recording run (a changed design or data step) gets a
##  recording of the same shape (same prior, numbers of predictors, ...), so
##  the dry run still runs, and says so once. With no recording of that
##  shape it stops and says what to do.
## =====================================================================

## Whether this is the dry run or a recording: `dry`, `recording`
## (engine/run_mode.R)
recordings_folder <- file.path("cache", "dry_recordings")

## The seams, the functions the dry run replaces or skips, are the
## project's: validation/engine_settings/dry_run_seams.R, sourced at the end of this file.


## ---- Record or replay one call --------------------------------------------------------

## The value of `expression`, run and saved (recording) or read from a
## recording (dry run).
##   name   the kind of call, a folder in cache/dry_recordings/
##   shape  a named list of what fixes the shape of the value (prior, k, ...)
##   inputs everything the value depends on (data, seed, settings), hashed
##          to find the recording of this exact call; no model objects
replayable <- function(name, shape, inputs, expression) {
  if (!dry && !recording) {
    return(expression)
  }
  shape_key <- paste(
    c(name, sprintf("%s-%s", names(shape), vapply(shape, paste, "", collapse = "x"))),
    collapse = "_"
  )
  shape_key <- gsub("[^A-Za-z0-9_.-]", "-", shape_key)
  exact <- substr(digest::digest(inputs), 1, 16)
  folder <- file.path(recordings_folder, name)
  file <- file.path(folder, sprintf("%s__%s.rds", shape_key, exact))

  if (recording) {
    value <- expression
    dir.create(folder, recursive = TRUE, showWarnings = FALSE)
    # written under another name, then renamed: a worker that stops halfway
    # leaves no broken recording
    partial <- tempfile(tmpdir = folder, fileext = ".partial")
    saveRDS(value, partial)
    file.rename(partial, file)
    return(value)
  }

  # the dry run
  if (file.exists(file)) {
    return(readRDS(file))
  }
  recorded <- list.files(folder, pattern = "[.]rds$")
  same_shape <- recorded[startsWith(recorded, paste0(shape_key, "__"))]
  if (length(same_shape) == 0) {
    stop(
      "Dry run: no recording of ", shape_key, " (", folder, "). Record them with a ",
      "smoke test: VALIDATION_SMOKE=1 VALIDATION_RECORD=1 Rscript run_all.R",
      call. = FALSE
    )
  }
  if (!isTRUE(getOption(paste0("validation_replay_warned_", name)))) {
    message(
      "Dry run: ", name, " called with inputs the recording run did not have; ",
      "using recordings of the same shape (the design or a data step changed ",
      "since the recordings were made)"
    )
    options(stats::setNames(list(TRUE), paste0("validation_replay_warned_", name)))
  }
  # the same recording for the same inputs, different ones for different inputs
  pick <- strtoi(substr(exact, 1, 7), 16L) %% length(same_shape) + 1
  readRDS(file.path(folder, same_shape[[pick]]))
}


## ---- The seams --------------------------------------------------------------------------

## Where this file is sourced: the pipeline's functions are there
overlay_env <- environment()

## Replaces function `name` (if it is defined here, and not replaced already)
## by make(original)
replace_function <- function(name, make) {
  if (!exists(name, envir = overlay_env, inherits = FALSE)) return(invisible())
  original <- get(name, envir = overlay_env)
  if (isTRUE(attr(original, "replayed"))) return(invisible())
  replacement <- make(original)
  attr(replacement, "replayed") <- TRUE
  assign(name, replacement, envir = overlay_env)
}

## The dry run's results files go to cache/dry_results/, never over the smoke
## test's, and are marked as dry. Done here, not in engine/results/results_files.R, so a
## normal run sees save_study_results_file() unchanged and a finished store's
## results steps stay valid: the original writes the file in a scratch
## folder, and it is moved from there.
if (dry) {
  replace_function("save_study_results_file", function(original) {
    function(study, tables) {
      # the tables first, while still in the project folder: they may read
      # per-dataset files (R arguments are evaluated when first used)
      force(tables)
      project <- getwd()
      scratch <- tempfile("dry_results_")
      dir.create(scratch)
      on.exit({
        setwd(project)
        unlink(scratch, recursive = TRUE)
      }, add = TRUE)
      setwd(scratch)
      written <- original(study, tables)
      setwd(project)

      results <- readRDS(file.path(scratch, written))
      results$setup$commit <- tryCatch(
        system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE, stderr = FALSE),
        error = function(e) NA_character_
      )
      results$setup$dry <- TRUE
      folder <- file.path("cache", "dry_results", "studies")
      dir.create(folder, recursive = TRUE, showWarnings = FALSE)
      file <- file.path(folder, basename(written))
      saveRDS(results, file)
      file
    }
  })
}

## The project's seams (validation/engine_settings/dry_run_seams.R): the expensive calls, replaced
## by versions that record or replay them, and what the dry run skips
sys.source(file.path("validation", "engine_settings", "dry_run_seams.R"), envir = overlay_env)
if (dry) {
  for (name in names(skipped_in_dry_run)) {
    replace_function(name, function(original) skipped_in_dry_run[[name]])
  }
}
