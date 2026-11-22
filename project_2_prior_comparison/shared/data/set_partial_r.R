## =====================================================================
##  The data: x1 with a set partial correlation with y given the other
##  predictors (README.md, "The data")
##
##  A cell fixes four things:
##    k                      the predictors, x1 included (x1 ... xk)
##    partial_r              x1's partial correlation with y given x2 ... xk:
##                           the same meaning at every k
##    covariates_r_squared   what x2 ... xk explain of y, on their own (the
##                           R-squared of the model without x1)
##    predictor_correlation  the correlation between every pair of predictors
##
##  The population: standard normal predictors with that correlation, and
##  y = x b + noise, with var(y) = 1. Three facts fix b and the noise:
##    1. x1's partial correlation given the others depends only on its
##       slope b1 and the noise: partial_r^2 = b1^2 v / (b1^2 v + noise^2),
##       with v the variance of x1 left after its regression on the others.
##    2. What the others explain: the variance of y's regression on them,
##       against what is left, var(y | others) = b1^2 v + noise^2.
##    3. Spread evenly: y's regression on the others has the same slope g
##       for each of them. Its variance is g^2 times the sum of their
##       correlation matrix.
##  y's regression on the others is b1 a + b_others, with a x1's regression
##  on them, so b_others = g - b1 a. At k = 1 there are no others: the
##  covariates' R-squared is 0, and x1's partial correlation is its plain one.
##
##  The draws use MASS::mvrnorm() and rnorm(), inside the dataset's own
##  random stream (engine/seeds.R); the population is algebra of the design.
## =====================================================================


## The population of one cell: the predictors' correlation matrix, the
## slopes, the noise SD, and both models' R-squared
population_with_partial_r <- function(k, partial_r, covariates_r_squared, predictor_correlation) {
  stopifnot(k >= 1, abs(partial_r) < 1, covariates_r_squared >= 0, covariates_r_squared < 1)
  if (k == 1) stopifnot(covariates_r_squared == 0)
  correlations <- matrix(predictor_correlation, k, k)
  diag(correlations) <- 1
  noise_sd <- 1

  # x1's regression on the others (a), and the variance it leaves (v)
  others <- seq_len(k)[-1]
  a <- numeric(0)
  if (k > 1) a <- solve(correlations[others, others, drop = FALSE], correlations[others, 1])
  v <- 1 - sum(correlations[1, others] * a)

  # 1. x1's slope, from its partial correlation
  slope_x1 <- sqrt(partial_r^2 / (1 - partial_r^2) / v) * noise_sd
  left_given_others <- slope_x1^2 * v + noise_sd^2

  # 2. and 3. the others' common slope g in y's regression on them, and
  # their slopes in the model
  explained_by_others <- covariates_r_squared / (1 - covariates_r_squared) * left_given_others
  g <- if (k == 1) 0 else sqrt(explained_by_others / sum(correlations[others, others]))
  slopes_others <- g - slope_x1 * a

  # var(y) = 1
  scale <- sqrt(explained_by_others + left_given_others)
  list(
    correlations = correlations,
    slopes = c(slope_x1, slopes_others) / scale,
    noise_sd = noise_sd / scale,
    r_squared = 1 - (noise_sd / scale)^2,
    r_squared_without_x1 = covariates_r_squared
  )
}

## One dataset of n rows from that population, drawn in the stream of its
## name: predictors x1 ... xk and the outcome, with the population
data_with_partial_r <- function(n, k, partial_r, covariates_r_squared, predictor_correlation,
                                name) {
  population <- population_with_partial_r(
    k, partial_r, covariates_r_squared, predictor_correlation
  )
  drawn <- with_stream_of(name, {
    predictors <- MASS::mvrnorm(n, mu = rep(0, k), Sigma = population$correlations)
    predictors <- matrix(predictors, n, k, dimnames = list(NULL, paste0("x", seq_len(k))))
    noise <- rnorm(n, sd = population$noise_sd)
    list(predictors = predictors, noise = noise)
  })
  c(
    list(
      predictors = drawn$predictors,
      outcome = drop(drawn$predictors %*% population$slopes) + drawn$noise
    ),
    population
  )
}
