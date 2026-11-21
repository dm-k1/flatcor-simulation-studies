## =====================================================================
##  The results file of a study: results/studies/study_<cell>.rds
##  (cache/smoke_results/studies/ for the smoke test, cache/timing/results/
##  for a timing run, so neither mixes with real results), with the study's
##  tables and the setup of the run. Whatever shows the results reads only
##  these files.
## =====================================================================

## Writes the file and returns its path (a targets "file" target)
save_study_results_file <- function(study, tables) {
  folder <- file.path(results_root, "studies")
  dir.create(folder, recursive = TRUE, showWarnings = FALSE)
  file <- file.path(folder, sprintf("study_%s.rds", study))

  # where, when and with what the study ran
  or_missing <- function(expression) {
    tryCatch(expression, error = function(e) NA_character_, warning = function(w) NA_character_)
  }
  commit <- or_missing(system2(
    "git", c("rev-parse", "--short", "HEAD"),
    stdout = TRUE, stderr = FALSE
  ))
  # the package under test, in fields named after it (flatcor, flatcor_commit),
  # and what else the project records (project_setup(), <project>/settings/settings.R)
  tested <- list(
    as.character(utils::packageVersion(tested_package)),
    utils::packageDescription(tested_package)$RemoteSha
  )
  names(tested) <- c(tested_package, paste0(tested_package, "_commit"))
  setup <- c(
    list(
      finished = format(Sys.time(), "%Y-%m-%d %H:%M %Z"),
      commit = if (length(commit) == 1) commit else NA_character_,
      R = R.version.string
    ),
    tested,
    project_setup(),
    list(
      machine = paste(Sys.info()[["sysname"]], Sys.info()[["machine"]]),
      root_seed = root_seed, # every random number follows from it (engine/seeds.R)
      smoke = smoke
    )
  )

  saveRDS(list(study = study, tables = tables, setup = setup), file)
  file
}
