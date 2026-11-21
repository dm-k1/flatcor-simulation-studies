## =====================================================================
##  The figures, from the results files (after run_all.R)
##
##    Rscript make_figures.R                     every study that has a results file
##    Rscript make_figures.R 3a                  one study
##    VALIDATION_SMOKE=1 Rscript make_figures.R  the smoke test's figures (cache/)
##    VALIDATION_DRY=1 Rscript make_figures.R    the dry run's figures (cache/)
##
##  run_all.R only simulates, so a cloud machine spends its time on the
##  studies alone. The figures are drawn here, on any machine: after a run,
##  or after downloading its results (results/studies/study_<study>.rds).
##  Each study's figures.R draws them (R/engine/report/figure_files.R).
## =====================================================================
source(file.path("R", "engine", "report", "figure_files.R"))
draw_figures(requested = commandArgs(trailingOnly = TRUE))
