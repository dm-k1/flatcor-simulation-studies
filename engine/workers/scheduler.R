## =====================================================================
##  The scheduler: hands out every batch of every part the studies declare,
##  asks the stopping rule, and keeps the budget (full_run() runs it)
##
##  Every cell goes its own way. (A "cell" here is what a quantity is
##  computed over: one cell of the design, or the cells of a slope over n
##  together.) Its batches wait in line for a free worker; as soon as the
##  last of them is back, the cell is judged on its own results by the
##  project's stopping rule (next_plan(), <project>/settings/stopping_rule.R),
##  and if a quantity is short of its target, the datasets it lacks join the
##  line at once. No cell waits for another, so the workers stay busy until
##  the last cell is done. The parts that run once join the line first, so
##  they run alongside. Which parts there are, each study declares in its
##  design.R (engine/study_form.R).
##
##  The results do not depend on when a cell is judged: a dataset's numbers
##  come from its name (engine/seeds.R), and a cell's verdict only from
##  its own results.
##
##  The estimate and the budget. Every finished batch records its seconds,
##  so each part's core hours per dataset are known as the run goes. What
##  the run still expects to cost is every asked-for dataset not yet done
##  (the stopping rule asks for all a cell is estimated to lack at once),
##  times its part's hours per dataset. After every finished batch the
##  scheduler compares what has been spent plus what it expects with the
##  budget. If that is more, the run stops: no batch waiting in line starts,
##  the running ones finish and are saved, and it reports what is left per
##  part. The researcher then raises the budget or changes a target, and
##  starts again: the run continues where it was.
##  docs/validation_tests.md, "How many datasets".
##
##  Each finished batch is saved in the store (run_batch(),
##  engine/workers/batches.R), so a run that stops continues where it
##  was, and the pipeline reads the batches afterwards instead of computing
##  them again.
## =====================================================================


## ---- The workers ------------------------------------------------------------------

## What a worker does with a batch: it loads the validation's code the first
## time (code_files(), engine/load_code.R) and then runs the batch
## (run_batch(), engine/workers/batches.R). `task`: list(part, batch, store, files).
run_task <- function(task) {
  if (!exists("run_batch", envir = globalenv())) {
    for (file in task$files) sys.source(file, envir = globalenv())
  }
  if (!exists("worker_model", envir = globalenv())) {
    assign("worker_model", batch_model(), envir = globalenv())
  }
  run_batch(task$part, task$batch, task$store, get("worker_model", envir = globalenv()))
}

## The workers: `workers` R processes (crew), each running one batch at a
## time; or, with workers = 0 (the dry run), one batch at a time in this
## process.
##   size         how many batches can run at once
##   start(task)  starts a batch
##   next_done()  waits for a batch to finish and returns its task with its
##                seconds; stops the run if the batch failed
##   stop()       ends the workers
start_workers <- function(workers) {
  if (workers == 0) {
    done <- new.env()
    return(list(
      size = 1,
      start = function(task) {
        task$seconds <- run_task(task)
        done$task <- task
      },
      next_done = function() done$task,
      stop = function() invisible()
    ))
  }

  running <- new.env()
  controller <- crew::crew_controller_local(
    workers = workers,
    # keep each worker's loaded code from one batch to the next
    reset_globals = FALSE,
    # a log per worker (its R output, including Stan's own messages), for
    # finding out why a batch failed
    options_local = crew::crew_options_local(log_directory = file.path("cache", "logs", "workers"))
  )
  controller$start()
  list(
    size = workers,
    start = function(task) {
      name <- paste(task$part, batch_id(task$batch))
      assign(name, task, envir = running)
      controller$push(
        command = run_task(task),
        data = list(task = task),
        globals = list(run_task = run_task),
        packages = step_packages,
        name = name
      )
    },
    next_done = function() {
      repeat {
        finished <- controller$pop()
        if (!is.null(finished)) break
        controller$wait(mode = "one", seconds_timeout = 60)
      }
      if (!identical(finished$status, "success")) {
        stop(
          "A batch failed (", finished$name, "): ", finished$error,
          "\nThe workers' logs are in cache/logs/workers/.",
          call. = FALSE
        )
      }
      task <- get(finished$name, envir = running)
      rm(list = finished$name, envir = running)
      task$seconds <- finished$result[[1]]
      task
    },
    stop = function() controller$terminate()
  )
}


## ---- Judging a cell ---------------------------------------------------------------

## The cells of a part: per cell, the rows of the plan it covers
## (the rows that share the values of `by`, as in next_plan())
cells_of <- function(plan, by) split(seq_len(nrow(plan)), do.call(paste, plan[by]))

## A table as the per-dataset file gives it back (write_per_dataset(), then
## read_per_dataset(), engine/results/per_dataset_files.R): a cell is
## judged on exactly the numbers its study's results are computed from.
## Text columns stay text: read alone, a cell's column of only "true" would
## come back as TRUE, where the study's whole file, with other values in
## it, keeps it as text (and a bootstrap's stream is named after those
## values).
as_read_back <- function(table) {
  file <- tempfile(fileext = ".csv")
  on.exit(unlink(file))
  table <- as.data.frame(table)
  table <- table[setdiff(names(table), c("variables", "chains"))]
  data.table::fwrite(table, file)
  text <- names(table)[vapply(table, is.character, logical(1))]
  as.data.frame(data.table::fread(
    file, na.strings = c("", "NA"), colClasses = list(character = text)
  ))
}

## The plan after judging one cell of a part: the cell's rows get the
## datasets it is estimated to lack (next_plan(), the project's stopping
## rule), or stay as they are when it has reached its targets. The cell is
## judged on its own results only: the tables of its study (part$table)
## computed from its own finished batches.
judge_cell <- function(part, plan, rows, store, one_batch) {
  batches <- batches_of_plan(plan[rows, , drop = FALSE], part$batch_size)
  results <- bind_batches(lapply(seq_len(nrow(batches)), function(i) {
    read_batch(part$name, batches[i, ], store)$rows
  }))
  columns <- c(part$by, "mcse", "target_mcse", "reached")
  tables <- part$table(as_read_back(results))
  table <- do.call(rbind, lapply(tables, function(t) as.data.frame(t)[columns]))
  next_plan(plan, table, part$by, part$batch_size, one_batch = one_batch)
}


## ---- The scheduler's run ----------------------------------------------------------

## A number with one decimal, for the messages
one_decimal <- function(x) format(round(x, 1), nsmall = 1)

## Runs the batches of `once` (per part that runs once, its batches), and
## every cell of `until_target` (the parts that run until their targets
## are reached, engine/study_form.R, each with its `name`) to its
## targets, unless the budget stops the run. `workers`: as in
## start_workers(). `spent_elsewhere`: core hours the pipeline's own steps
## have cost so far (a run that continues). `one_extension`: at most one
## extra batch per cell (the smoke test, which tests the step, not the
## numbers). Returns TRUE when every cell is done, FALSE when the budget
## stopped the run.
run_parts <- function(until_target, once, store, budget_core_hours, workers, spent_elsewhere,
                      one_extension = FALSE) {
  pool <- start_workers(workers)
  on.exit(pool$stop())
  files <- code_files()
  parts <- c(names(until_target), names(once))

  # what changes while the scheduler runs, in one place
  run <- new.env()
  run$plans <- lapply(until_target, function(part) {
    read_plan(part$name, store, part$cells, part$first_datasets)
  })
  # per part, every finished batch's seconds and datasets: those saved
  # before (a run that continues) and those that come back
  run$seconds <- list()
  run$datasets <- list()
  for (name in parts) {
    saved <- lapply(
      list.files(file.path(store, "batches", name), "[.]rds$", full.names = TRUE), readRDS
    )
    run$seconds[[name]] <- vapply(saved, `[[`, numeric(1), "seconds")
    run$datasets[[name]] <- vapply(saved, function(b) b$datasets %||% NA_real_, numeric(1))
  }
  run$waiting <- list()     # tasks waiting for a free worker, in order
  run$running <- 0
  run$left <- list()        # per cell: its batches not back yet
  run$extended <- character(0)
  run$cells_done <- list()  # per part: how many of its cells are done
  run$stopped <- FALSE
  run$last_status <- Sys.time()

  ## ---- The estimate ----
  # core hours: every batch keeps cores_per_batch cores busy
  # (<project>/settings/settings.R)
  spent <- function() spent_elsewhere + sum(unlist(run$seconds)) * cores_per_batch / 3600
  # a part's core hours per dataset, from its finished batches: the median,
  # so one slow batch does not throw it; unknown (NA) before two are back
  hours_per_dataset <- function(name) {
    per_dataset <- run$seconds[[name]] / run$datasets[[name]]
    per_dataset <- per_dataset[is.finite(per_dataset)]
    if (length(per_dataset) < 2) return(NA_real_)
    stats::median(per_dataset) * cores_per_batch / 3600
  }
  # what every asked-for dataset not yet done is expected to cost, per part
  # (NA for a part whose hours per dataset are not known yet)
  expected_per_part <- function() {
    # every batch not back yet, waiting or running
    tasks <- unlist(unname(run$left), recursive = FALSE)
    datasets <- tapply(
      vapply(tasks, function(task) datasets_in(task$batch), numeric(1)),
      factor(vapply(tasks, `[[`, "", "part"), levels = parts),
      sum, default = 0
    )
    datasets * vapply(parts, hours_per_dataset, numeric(1))
  }
  expected <- function() sum(expected_per_part(), na.rm = TRUE)
  status <- function() {
    cells <- vapply(names(until_target), function(name) {
      length(cells_of(run$plans[[name]], until_target[[name]]$by))
    }, numeric(1))
    done <- sum(unlist(run$cells_done))
    total <- sum(cells)
    n_workers <- max(1, workers)
    spent_hours <- one_decimal(spent())
    expected_hours <- one_decimal(expected())
    clock_hours <- one_decimal(expected() / (n_workers * cores_per_batch))
    unknown <- if (anyNA(expected_per_part())) "; not known yet for some parts" else ""
    cli::cli_alert_info(paste(
      "Status: {done} of {total} cell{?s} done; {spent_hours} core hours spent,",
      "about {expected_hours} more expected ({clock_hours} hours on {n_workers}",
      "worker{?s}){unknown}"
    ))
    run$last_status <- Sys.time()
  }

  ## ---- Handing out batches ----
  # the batches of a table not run yet
  not_run <- function(name, batches) {
    missing <- vapply(seq_len(nrow(batches)), function(i) {
      is.null(read_batch(name, batch_row(batches, i), store))
    }, logical(1))
    vctrs::vec_slice(batches, missing)
  }
  # the batches of a cell's plan not run yet
  cell_not_run <- function(name, rows) {
    plan <- run$plans[[name]][rows, , drop = FALSE]
    not_run(name, batches_of_plan(plan, until_target[[name]]$batch_size))
  }
  # into the line; `key`: the cell, NA for a part that runs once
  add_batches <- function(name, key, batches) {
    cell <- paste(name, key)
    for (i in seq_len(nrow(batches))) {
      task <- list(part = name, key = key, batch = batch_row(batches, i), store = store,
                   files = files)
      run$left[[cell]] <- c(run$left[[cell]], list(task))
      run$waiting <- c(run$waiting, list(task))
    }
  }
  # every free worker gets the next batch in line
  start_waiting <- function() {
    while (!run$stopped && run$running < pool$size && length(run$waiting) > 0) {
      task <- run$waiting[[1]]
      run$waiting <- run$waiting[-1]
      run$running <- run$running + 1
      pool$start(task)
    }
  }

  # a cell with no batches left: run what its plan still lacks (a run that
  # continues), or judge it and add the datasets it lacks
  next_step <- function(name, key) {
    part <- until_target[[name]]
    cell <- paste(name, key)
    rows <- cells_of(run$plans[[name]], part$by)[[key]]
    missing <- cell_not_run(name, rows)
    if (nrow(missing) > 0) return(add_batches(name, key, missing))

    plan_next <- judge_cell(part, run$plans[[name]], rows, store, one_batch = one_extension)
    added <- sum(plan_next$datasets[rows] - run$plans[[name]]$datasets[rows])
    if (added == 0 || (one_extension && cell %in% run$extended)) {
      run$cells_done[[name]] <- (run$cells_done[[name]] %||% 0) + 1
      datasets <- sum(run$plans[[name]]$datasets[rows])
      return(cli::cli_alert_success("{cell}: done, {datasets} dataset{?s}"))
    }
    cli::cli_alert_info("{cell}: {added} more dataset{?s}")
    run$extended <- c(run$extended, cell)
    run$plans[[name]]$datasets[rows] <- plan_next$datasets[rows]
    write_plan(run$plans[[name]], name, store)
    add_batches(name, key, cell_not_run(name, rows))
  }

  ## ---- The run ----
  cli::cli_alert_info("Budget: {budget_core_hours} core hours")
  for (name in names(once)) add_batches(name, NA, not_run(name, once[[name]]))
  for (name in names(until_target)) {
    for (key in names(cells_of(run$plans[[name]], until_target[[name]]$by))) next_step(name, key)
  }
  start_waiting()
  while (run$running > 0) {
    task <- pool$next_done()
    run$running <- run$running - 1
    cell <- paste(task$part, task$key)
    run$seconds[[task$part]] <- c(run$seconds[[task$part]], task$seconds)
    run$datasets[[task$part]] <- c(run$datasets[[task$part]], datasets_in(task$batch))
    back <- vapply(run$left[[cell]], function(t) batch_id(t$batch), "") == batch_id(task$batch)
    run$left[[cell]] <- run$left[[cell]][-which(back)[1]]
    if (length(run$left[[cell]]) == 0 && !run$stopped) {
      if (is.na(task$key)) {
        cli::cli_alert_success("{task$part}: done")
      } else {
        next_step(task$part, task$key)
      }
    }
    if (!run$stopped && spent() + expected() > budget_core_hours) {
      run$stopped <- TRUE
      spent_hours <- one_decimal(spent())
      expected_hours <- one_decimal(expected())
      cli::cli_alert_danger(paste(
        "Stopping: {spent_hours} core hours spent and about {expected_hours} more",
        "expected: more than the budget, {budget_core_hours}."
      ))
      cli::cli_text("No new batch starts; the running ones finish and are saved.")
    }
    if (difftime(Sys.time(), run$last_status, units = "mins") > 10) status()
    start_waiting()
  }

  status()
  if (!run$stopped) {
    cli::cli_alert_success("Every cell is done.")
    return(invisible(TRUE))
  }
  left <- expected_per_part()
  left <- left[is.na(left) | left > 0]
  cli::cli_text("What is left, per part (core hours, NA: not known yet):")
  lines <- sprintf("%-14s %.1f", names(left), left)
  cli::cli_bullets(stats::setNames(lines, rep("*", length(lines))))
  invisible(FALSE)
}
