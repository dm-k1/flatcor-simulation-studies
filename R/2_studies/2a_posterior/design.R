## =====================================================================
##  Study 2a: is the posterior computed correctly?   (heading 2, row a)
##  The design. What is tested, what is expected and why:
##  docs/validation_tests.md, study 2a. The code: code.R.
## =====================================================================


## ---- The design -------------------------------------------------------------------
##   prior (3) × setting (k = 8, n = 60; k = 3, n = 50) = 6 cells,
##   data from the prior (R/1_data/3_from_the_prior.R)
settings_2a <- merge(
  data.frame(prior = c("flat_partial_r", "flat_r", "flat_r_squared")),
  data.frame(k = c(8, 3), n = c(60, 50))
)
if (smoke) settings_2a <- settings_2a[settings_2a$k == 8, ]

iterations_2a <- if (smoke) {
  c(warmup = 300, sampling = 300)
} else {
  c(warmup = 1000, sampling = 1000)
}


## ---- How many (docs/validation_tests.md, "How many datasets") -------------------------
## Δ per quantity: the Monte Carlo SE must be at most Δ / 1.96
deltas_2a <- c(
  "mean scaled rank"             = 0.05,   # 10% of 1/2
  "SD of the scaled rank"        = 0.029,  # 10% of .289
  "chi-square over 20 rank bins" = NA      # an overall check, no Δ of its own
)
## Computed, not measured: the ranks (0-100, thinned) have SD .2915, so the
## mean rank needs (.2915 x 1.96 / .05)^2 = 130.6, so 131 fits per cell; the
## SD of the ranks needs 76
fits_2a <- datasets(131, in_smoke = 10)


## ---- Bookkeeping (no effect on the results) ------------------------------------
batch_size_2a <- if (smoke) 10 else 50   # fits per piece of work, saved as it finishes


## ---- How it runs (R/engine/parts.R) ------------------------------------------
## Run once: a piece is one batch of fits of one setting (every setting with
## every batch, the batches in order within a setting)
pieces_2a <- do.call(rbind, lapply(seq_len(nrow(settings_2a)), function(i) {
  batches <- split_into_batches(fits_2a, batch_size_2a)
  do.call(rbind, lapply(batches, function(batch) {
    cbind(settings_2a[i, , drop = FALSE], from = min(batch), to = max(batch))
  }))
}))
rownames(pieces_2a) <- NULL
declared_parts[["2a"]] <- part_once(
  study = "2a",
  pieces = pieces_2a,
  work = function(piece, model) {
    sbc_batch_2a(piece[names(settings_2a)], replications_of(piece), model)
  }
)

## For the check at the end of a run (R/engine/check_results.R)
declared_blanks[[length(declared_blanks) + 1]] <- list(
  study = "2a", table = "ranks", columns = c("delta", "target_mcse"),
  when = function(t) grepl("chi-square", t$quantity),
  reason = "the chi-square is an overall check, without a target of its own"
)
