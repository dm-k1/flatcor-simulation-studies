## =====================================================================
##  Reading the results: what every figure script (R/project/report/figures/)
##  needs (where a study's results file and per-dataset files are, where its
##  figures go), and drawing them all (make_figures.R calls draw_figures())
##
##  A figure script reads one study's results file, computes nothing, and
##  writes its figures to results/figures/ (cache/ for the smoke test and
##  the dry run, R/engine/run_mode.R).
## =====================================================================

source(file.path("R", "engine", "run_mode.R"))
dir.create(figure_folder, recursive = TRUE, showWarnings = FALSE)

## The results file of a study (results/studies/study_<study>.rds)
read_results <- function(study) {
  readRDS(file.path(results_root, "studies", sprintf("study_%s.rds", study)))
}

## A per-dataset file of a study (results/per_dataset/study_<file>.csv or
## .csv.gz, R/engine/results/per_dataset_files.R)
read_per_dataset_file <- function(file) {
  path <- list.files(
    file.path(results_root, "per_dataset"),
    pattern = sprintf("^study_%s[.]csv([.]gz)?$", file), full.names = TRUE
  )
  stopifnot(length(path) == 1)
  as.data.frame(data.table::fread(path, na.strings = c("", "NA")))
}

## The figure script of every study that has one (R/project/report/figures/<study>.R),
## named by study code
figure_scripts <- function() {
  scripts <- list.files(
    file.path("R", "project", "report", "figures"), pattern = "[.]R$", full.names = TRUE
  )
  names(scripts) <- sub("[.]R$", "", basename(scripts))
  scripts
}

## Runs the figure script of every study in `requested` (all if none) that
## has a results file, each in its own R process. A script that stops is
## an error here, after the others have run.
draw_figures <- function(requested = character(0)) {
  results_folder <- file.path(results_root, "studies")
  scripts <- figure_scripts()
  if (length(requested) > 0) scripts <- scripts[names(scripts) %in% requested]
  failed <- character(0)
  drawn <- 0
  for (study in names(scripts)) {
    script <- scripts[[study]]
    if (!file.exists(file.path(results_folder, sprintf("study_%s.rds", study)))) {
      message(sprintf("%s: no results file for %s in %s, skipped", script, study, results_folder))
      next
    }
    status <- system2(file.path(R.home("bin"), "Rscript"), script)
    message(sprintf("%s: %s", script, if (status == 0) "done" else "stopped (see above)"))
    if (status == 0) drawn <- drawn + 1 else failed <- c(failed, script)
  }
  if (length(failed) > 0) {
    stop("Figure script(s) stopped: ", paste(failed, collapse = ", "), call. = FALSE)
  }
  message(sprintf("Figures: %d script(s) done.", drawn))
}
