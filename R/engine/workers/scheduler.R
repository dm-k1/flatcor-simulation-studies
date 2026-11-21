## =====================================================================
##  The queue: every expensive batch of work, each cell's rounds on its own
##  (run_all.R runs it; the rule itself is in R/engine/workers/batches.R)
##
##  Every cell goes through its own rounds. (A "cell" here is what a
##  quantity is computed over: one cell of the design, or the cells of a
##  slope over n together.) Its batches of work go into the queue; as soon as
##  the last of them is back, the cell is judged on its own results, and if
##  a quantity is short of its target, its next batch goes into the queue
##  at once. No cell waits for another, so the workers stay busy until the
##  last cell is done. The parts that run once go into the queue first, so
##  they run alongside, not after. Which parts there are, each study declares
##  in its design.R (R/engine/study_form.R).
##
##  The results are the same as with rounds over all cells at once: a
##  dataset's numbers come from its name (R/engine/seeds.R), and a
##  cell's verdict only from its own results, so when a cell is judged
##  changes nothing.
##
##  The budget: a batch that would take the run past it is not started. The
##  cell is then reported as short of its target, with what its next batch
##  would cost; the researcher decides (raise the budget and start again,
##  or report the cell as short). docs/validation_tests.md, "How many datasets".
##
##  Each finished batch is saved in the store (R/engine/workers/batches.R,
##  run_batch()), so a run that stops continues where it was, and the
##  pipeline reads the batches afterwards instead of computing them again.
## =====================================================================


## ---- Running batches ---------------------------------------------------------------

## What a queue worker does with a batch: it loads the validation's code the
## first time (R/engine/workers/worker_setup.R, code_files()) and then runs the batch
## (run_batch(), R/engine/workers/batches.R). `task`: list(design, batch, store, files).
run_task <- function(task) {
  if (!exists("run_batch", envir = globalenv())) {
    for (file in task$files) sys.source(file, envir = globalenv())
  }
  if (!exists("worker_model", envir = globalenv())) {
    assign("worker_model", batch_model(), envir = globalenv())
  }
  run_batch(task$design, task$batch, task$store, get("worker_model", envir = globalenv()))
}

## The queue: `workers` R processes (crew), each running one batch at a time;
## or, with workers = 0 (the dry run), every batch in this process, at once.
##   push(task)   adds a batch
##   busy()       whether batches are still out
##   next_done()  waits for a batch to finish and returns its task with
##                its seconds; stops the run if the batch failed
##   stop()       ends the workers
start_queue <- function(workers) {
  # the batches pushed and not yet handed back
  out <- new.env()
  out$tasks <- list()

  if (workers == 0) {
    return(list(
      push = function(task) {
        task$seconds <- run_task(task)
        out$tasks <- c(out$tasks, list(task))
      },
      busy = function() length(out$tasks) > 0,
      next_done = function() {
        task <- out$tasks[[1]]
        out$tasks <- out$tasks[-1]
        task
      },
      stop = function() invisible()
    ))
  }

  controller <- crew::crew_controller_local(
    workers = workers,
    # keep each worker's loaded code from one batch to the next
    reset_globals = FALSE,
    # a log per worker (its R output, including Stan's own messages), for
    # finding out why a batch of work failed
    options_local = crew::crew_options_local(log_directory = file.path("cache", "logs", "workers"))
  )
  controller$start()
  list(
    push = function(task) {
      name <- paste(task$design, batch_id(task$batch))
      out$tasks[[name]] <- task
      controller$push(
        command = run_task(task),
        data = list(task = task),
        globals = list(run_task = run_task),
        packages = step_packages,
        name = name
      )
    },
    busy = function() length(out$tasks) > 0,
    next_done = function() {
      repeat {
        finished <- controller$pop()
        if (!is.null(finished)) break
        controller$wait(mode = "one", seconds_timeout = 60)
      }
      if (!identical(finished$status, "success")) {
        stop(
          "A batch of work failed (", finished$name, "): ", finished$error,
          "\nThe workers' logs are in cache/logs/workers/.",
          call. = FALSE
        )
      }
      task <- out$tasks[[finished$name]]
      out$tasks[[finished$name]] <- NULL
      task$seconds <- finished$result[[1]]
      task
    },
    stop = function() controller$terminate()
  )
}


## ---- Judging a cell ---------------------------------------------------------------

## The cells of a design: per cell, the rows of the plan it covers
## (the rows that share the values of `by`, as in next_plan())
cells_of <- function(plan, by) split(seq_len(nrow(plan)), do.call(paste, plan[by]))

## A table as the per-dataset file gives it back (write_per_dataset(), then
## read_per_dataset(), R/engine/report/per_dataset_files.R): a cell is judged on exactly
## the numbers its study's results are computed from. Text columns stay text:
## read alone, a cell's column of only "true" would come back as TRUE, where
## the study's whole file, with other values in it, keeps it as text (and a
## bootstrap's stream is named after those values).
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

## The plan after judging one cell of a design: the cell's rows get the
## datasets it is estimated to lack (next_plan(), R/engine/workers/batches.R), or
## stay as they are when it has reached its targets. The cell is judged on
## its own results only: the tables of its study (design$table) computed
## from its own finished batches.
judge_cell <- function(design, plan, rows, store, one_batch) {
  batches <- batches_of_plan(plan[rows, , drop = FALSE], design$batch_size)
  results <- bind_batches(lapply(seq_len(nrow(batches)), function(i) {
    read_batch(design$name, batches[i, ], store)$rows
  }))
  columns <- c(design$by, "mcse", "target_mcse", "reached")
  tables <- design$table(as_read_back(results))
  table <- do.call(rbind, lapply(tables, function(t) as.data.frame(t)[columns]))
  next_plan(plan, table, design$by, design$batch_size, one_batch = one_batch)
}


## ---- The queue's run ----------------------------------------------------------------

## Runs the batches of `once` (per part that runs once, its batches), and
## every cell of `designs` (the parts that run in rounds, R/engine/study_form.R,
## each with its `name`) to its targets or to the budget. `workers`: as in start_queue().
## `spent_elsewhere`: core hours the pipeline's own steps have cost so far
## (a run that continues). `one_extension`: at most one extra batch per cell
## (the smoke test, which tests the step, not the numbers).
run_rounds <- function(designs, once, store, budget_core_hours, workers, spent_elsewhere,
                       one_extension = FALSE) {
  queue <- start_queue(workers)
  on.exit(queue$stop())
  files <- code_files()

  # what changes while the queue runs, in one place
  run <- new.env()
  run$plans <- lapply(designs, function(design) {
    read_plan(design$name, store, design$cells, design$first_datasets)
  })
  # every batch's seconds, per design or part: those saved before (a run
  # that continues) and those that come back
  run$seconds <- lapply(c(names(designs), names(once)), function(name) {
    saved <- list.files(file.path(store, "batches", name), "[.]rds$", full.names = TRUE)
    vapply(saved, function(file) readRDS(file)$seconds, numeric(1), USE.NAMES = FALSE)
  })
  names(run$seconds) <- c(names(designs), names(once))
  run$out <- list()        # per cell: the expected core hours of each batch out
  run$extended <- character(0)
  run$short <- list()      # per cell its next batch did not fit: what it would cost

  # core hours: every batch keeps cores_per_batch cores busy (R/project/engine_settings/settings.R)
  spent <- function() spent_elsewhere + sum(unlist(run$seconds)) * cores_per_batch / 3600
  out_cost <- function() sum(unlist(run$out))
  per_dataset <- function(name) {
    if (length(run$seconds[[name]]) == 0) return(0)
    mean(run$seconds[[name]]) * cores_per_batch / 3600 / designs[[name]]$batch_size
  }
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
    not_run(name, batches_of_plan(plan, designs[[name]]$batch_size))
  }
  # `key`: the cell; NA for a batch that runs once
  push_batches <- function(name, key, batches) {
    cell <- paste(name, key)
    for (i in seq_len(nrow(batches))) {
      cost <- if (is.na(key)) 0 else (batches$to[i] - batches$from[i] + 1) * per_dataset(name)
      run$out[[cell]] <- c(run$out[[cell]], cost)
      batch <- batch_row(batches, i)
      queue$push(list(design = name, key = key, batch = batch, store = store, files = files))
    }
  }

  # a cell with no batches out: run what its plan still lacks (a run that
  # continues), or judge it and start its next batch
  next_step <- function(name, key) {
    design <- designs[[name]]
    cell <- paste(name, key)
    rows <- cells_of(run$plans[[name]], design$by)[[key]]
    missing <- cell_not_run(name, rows)
    if (nrow(missing) > 0) return(push_batches(name, key, missing))

    plan_next <- judge_cell(design, run$plans[[name]], rows, store, one_batch = one_extension)
    added <- sum(plan_next$datasets[rows] - run$plans[[name]]$datasets[rows])
    if (added == 0 || (one_extension && cell %in% run$extended)) {
      datasets <- sum(run$plans[[name]]$datasets[rows])
      return(message(sprintf("%s: done, %d datasets", cell, datasets)))
    }
    cost <- added * per_dataset(name)
    if (spent() + out_cost() + cost > budget_core_hours) {
      run$short[[cell]] <- cost
      return(message(sprintf("%s: next batch (%.1f core hours) not started: budget", cell, cost)))
    }
    message(sprintf("%s: %d more datasets", cell, added))
    run$extended <- c(run$extended, cell)
    run$plans[[name]]$datasets[rows] <- plan_next$datasets[rows]
    write_plan(run$plans[[name]], name, store)
    push_batches(name, key, cell_not_run(name, rows))
  }

  # the batches that run once first, then every cell; each finished batch
  # may complete its cell's batch
  for (name in names(once)) push_batches(name, NA, not_run(name, once[[name]]))
  for (name in names(designs)) {
    for (key in names(cells_of(run$plans[[name]], designs[[name]]$by))) next_step(name, key)
  }
  while (queue$busy()) {
    task <- queue$next_done()
    cell <- paste(task$design, task$key)
    run$seconds[[task$design]] <- c(run$seconds[[task$design]], task$seconds)
    run$out[[cell]] <- run$out[[cell]][-1]
    if (length(run$out[[cell]]) > 0) next
    if (is.na(task$key)) {
      message(sprintf("%s: done", task$design))
    } else {
      next_step(task$design, task$key)
    }
  }

  if (length(run$short) == 0) {
    message(sprintf("Every cell is done. %.1f core hours so far.", spent()))
  } else {
    message(sprintf(
      paste(
        "%.1f core hours so far. %d cells did not start their next batch: together",
        "about %.1f core hours, more than the %.1f left of the budget of %.1f. To run",
        "them, raise the budget (VALIDATION_BUDGET_CORE_HOURS) and start again; to stop",
        "here, the cells short of a target are marked in their study's results (column",
        "reached)."
      ),
      spent(), length(run$short), sum(unlist(run$short)),
      max(0, budget_core_hours - spent()), budget_core_hours
    ))
  }
  invisible(run$plans)
}
