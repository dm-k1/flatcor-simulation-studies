## =====================================================================
##  Study 2b in the notebook (validation.ipynb; R/engine/report/notebook_tables.R)
## =====================================================================

## 2b in short: per method and quantity, the mean and the range of the
## estimates over the cells (the full table is under Details)
summary_2b <- function(tables) {
  as.data.frame(tables$estimates) |>
    dplyr::summarise(
      cells = dplyr::n(), mean = mean(estimate), lowest = min(estimate), highest = max(estimate),
      .by = c(quantity, method)
    ) |>
    dplyr::arrange(quantity, method)
}
