## =====================================================================
##  The figures, from the results files (after run_all.R)
##
##    Rscript R/project/report/make_figures.R      every study that has a results file
##    Rscript R/project/report/make_figures.R 3a   one study
##    VALIDATION_SMOKE=1 Rscript R/project/report/make_figures.R   the smoke test's (cache/)
##    VALIDATION_DRY=1 Rscript R/project/report/make_figures.R     the dry run's (cache/)
##
##  run_all.R only simulates, so a cloud machine spends its time on the
##  studies alone. The figures are drawn here, on any machine: after a run,
##  or after downloading its results (results/studies/study_<study>.rds).
##  Each study's script in R/project/report/figures/ draws them
##  (R/project/report/read_results.R). Run from the project folder.
## =====================================================================
source(file.path("R", "project", "report", "read_results.R"))
draw_figures(requested = commandArgs(trailingOnly = TRUE))
