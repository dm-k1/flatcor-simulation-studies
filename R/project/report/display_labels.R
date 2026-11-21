## =====================================================================
##  How the notebook names things: each study's question, the priors and
##  the columns of the tables (R/project/report/notebook.R)
## =====================================================================

## The question each study answers, one per cell of the table in
## docs/working/REDESIGN.md: heading (1 prior sampling, 2 posterior
## estimation, 3 Bayes factors) and row (a: computed correctly, b: behaves
## like a default)
study_questions <- c(
  "1a" = "Does the software draw the prior it claims?",
  "1b" = "Is the Bayes factor invariant to the units and coding of the predictors?",
  "2a" = "Is the posterior computed correctly (simulation-based calibration)?",
  "2b" = "How close are the posterior estimates to a known truth?",
  "3a" = "Are the Bayes factors right (calibration; bridge sampling's error)?",
  "3b" = "Do the Bayes factors meet the default-prior criteria?"
)

## Names in the data as they are written in the text
prior_labels <- c(
  flat_partial_r = "flat partial r",
  flat_r = "flat R",
  flat_r_squared = "flat R-squared"
)
column_labels <- c(
  k = "*k*", n = "*n*", q = "*q*", p_value = "*p*", mcse = "MCSE",
  n_sim = "*n*<sub>sim</sub>", chi_square = "*χ*²", z = "*z*",
  largest_abs_z = "Largest |*z*|", est = "Estimate"
)
abbreviations <- c(
  se = "SE", mcse = "MCSE", sd = "SD", mc = "MC", ks = "KS", ess = "ESS",
  bf = "BF", jzs = "JZS"
)
