## =====================================================================
##  The studies a smoke test runs when some studies of a project changed
##
##    Rscript ci/smoke_studies.R <project> 3a    prints, as its last line,  3a 1b 3b
##
##  The changed studies, and every study with a part that needs one of
##  their parts (`needs`, engine/study_form.R), and so on: a change to a
##  part another study uses can break that study's results. The parts the
##  changed studies need themselves run anyway (engine/full_run.R).
##  The smoke job (check.yml) runs Rscript run_all.R <project> with these
##  studies; ci/smoke_selection.sh says which studies changed.
## =====================================================================
arguments <- commandArgs(trailingOnly = TRUE)
Sys.setenv(PROJECT = arguments[1])
source(file.path("engine", "load_code.R"))
load_code()

studies <- arguments[-1]
repeat {
  their_parts <- names(Filter(function(part) part$study %in% studies, declared_parts))
  users <- Filter(function(part) any(part$needs %in% their_parts), declared_parts)
  more <- union(studies, vapply(users, `[[`, "", "study"))
  if (length(more) == length(studies)) break
  studies <- more
}
cat(studies, "\n")
