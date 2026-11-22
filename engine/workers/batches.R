## =====================================================================
##  Batches: a cell's plan, its batches, and running, saving and reading one
##
##  A cell's plan is how many datasets it has been given so far; its
##  batches are those datasets cut in groups of batch_size, one task for a
##  worker each. The scheduler (engine/workers/scheduler.R) runs them and
##  saves each as it finishes; the pipeline (engine/pipeline/pipeline_steps.R)
##  reads them back. Plans and batches are files in the targets store, so a
##  fresh start deletes them with the store.
## =====================================================================


## ---- The plan ------------------------------------------------------------------------

## An .rds file, not .csv: it keeps every column's type, and a batch is the
## same batch only if its cell's values are identical (2 is not 2L)
plan_file <- function(part, store) file.path(store, "plans", paste0(part, ".rds"))

## The plan of a part: its cells, each with the number of datasets so far.
## Without a plan file (a first start, or a timing run), every cell has its
## first datasets.
read_plan <- function(part, store, cells, first_datasets) {
  file <- plan_file(part, store)
  if (file.exists(file)) {
    return(readRDS(file))
  }
  data.frame(cells, datasets = first_datasets, stringsAsFactors = FALSE)
}

write_plan <- function(plan, part, store) {
  dir.create(dirname(plan_file(part, store)), recursive = TRUE, showWarnings = FALSE)
  saveRDS(plan, plan_file(part, store))
}

## The batches of a plan: one row per cell and batch, with the cell's
## columns and the first and last replication of the batch. Batches are cut
## from 1 in steps of batch_size, so more datasets only add rows: the
## batches already done stay done.
batches_of_plan <- function(plan, batch_size) {
  rows <- lapply(seq_len(nrow(plan)), function(i) {
    starts <- seq(1, plan$datasets[i], by = batch_size)
    cell <- plan[rep(i, length(starts)), setdiff(names(plan), "datasets"), drop = FALSE]
    cell$from <- starts
    cell$to <- pmin(starts + batch_size - 1, plan$datasets[i])
    cell
  })
  batches <- do.call(rbind, rows)
  rownames(batches) <- NULL
  batches
}

## Row i of a table of batches, as targets hands a step one row of it (the
## same row names), so a batch is the same object in the scheduler and in
## the pipeline
batch_row <- function(batches, i) vctrs::vec_slice(batches, i)


## ---- One batch -------------------------------------------------------------------------

## The work of one batch: its rows, from the work function its part declares
## (engine/study_form.R). The scheduler and the pipeline's steps both call
## this, so a batch is the same work wherever it runs. Every draw that
## matters has a seed of its own already (engine/seeds.R), but a package
## may seed its own draws with set.seed() (flatcor does, for bridge
## sampling), which draws with whichever generator R has set. So a batch
## starts as targets starts a step: seeded, with R's default generator. The
## seed's name starts with "piece", the word for a batch when the seeds were
## fixed: changing it would change every number. `model`: what batch_model()
## gives (<project>/settings/settings.R).
batch_work <- function(part, batch, model = NULL) {
  set.seed(
    seed_of("piece", part, batch_id(batch)),
    kind = "default", normal.kind = "default", sample.kind = "default"
  )
  declared_parts[[part]]$work(batch, model)
}

## The datasets in a batch (1 for a batch of a part that runs once without
## replications, such as one setting's draws)
datasets_in <- function(batch) if (is.null(batch$to)) 1 else batch$to - batch$from + 1

## A batch's name: a hash of its cell's values and its replications (types
## included: 2 is not 2L, as in the plan)
batch_id <- function(batch) digest::digest(as.list(batch))

## Where the scheduler saves a finished batch: in the store, so a fresh
## start deletes it with the store
batch_file <- function(part, batch, store) {
  file.path(store, "batches", part, paste0(batch_id(batch), ".rds"))
}

## The scheduler's run of one batch: its rows, seconds and datasets, saved
## under another name and then renamed, so a worker that stops halfway
## leaves no broken batch. Returns the seconds.
run_batch <- function(part, batch, store, model = NULL) {
  started <- Sys.time()
  rows <- batch_work(part, batch, model)
  seconds <- as.numeric(difftime(Sys.time(), started, units = "secs"))
  file <- batch_file(part, batch, store)
  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  partial <- tempfile(tmpdir = dirname(file), fileext = ".partial")
  saveRDS(list(rows = rows, seconds = seconds, datasets = datasets_in(batch)), partial)
  file.rename(partial, file)
  seconds
}

## A finished batch (list(rows, seconds, datasets)), or NULL if it has not run
read_batch <- function(part, batch, store) {
  file <- batch_file(part, batch, store)
  if (file.exists(file)) readRDS(file) else NULL
}

## A batch's rows in the pipeline's step: the scheduler's, read back, or, if
## the scheduler has not run it (a plain tar_make(), a timing run), computed
## here
batch_rows <- function(part, batch, model = NULL) {
  finished <- read_batch(part, batch, targets::tar_path_store())
  if (!is.null(finished)) return(finished$rows)
  batch_work(part, batch, model)
}
