# Project 2: which prior for which situation?

At the n and k of ordinary studies, how do the Bayes factors of
[flatcor](https://github.com/dm-k1/flatcor)'s three priors differ in the
decisions they lead to, against two reference priors and the p-value?

Project 1 showed that the priors are computed correctly and that they
differ. This project shows what that difference does to decisions. It
compares, so only what the run needs is fixed in advance (this file); the
analyses are exploratory and are chosen after the run, from the kept data.
A finding that will carry a claim is confirmed on new data first (stage 2,
below).

It runs on the engine ([`engine/`](../engine/)) like project 1: one study,
[`studies/1a_decisions/`](studies/1a_decisions/).

## The run spec (stage 1)

### The matrix

| Factor | Levels |
|---|---|
| n | 25, 50, 100, 200, 400, 800 |
| k (predictors in the model, x₁ included) | 1, 3, 6, 12 |
| x₁'s true partial correlation, given the other predictors | 0, .05, .1, .2, .3 |
| what the other predictors explain on their own | R² = 0 or .3 |
| correlation between every pair of predictors | 0, .3, .6 |

At k = 1 there are no other predictors, so their R² and correlation mean
nothing there: one cell per n and partial correlation. In all,
6 × 5 × (1 + 3 × 2 × 3) = **570 cells**.

A dataset is named by its stage, its cell's factor values and its
replication (`1a stage 1 n 800 k 12 partial r 0.3 covariates R2 0.3
correlation 0.6 replication 17`), never by a row number, and its random
numbers come from that name and the one `root_seed`
([`engine/seeds.R`](../engine/seeds.R)). So finished datasets keep their
seeds when the matrix grows.

### The data

[`shared/data/set_partial_r.R`](shared/data/set_partial_r.R). The predictors
are standard normal with the cell's correlation (`MASS::mvrnorm()`), and
y = x b + noise, with var(y) = 1. Three facts fix the slopes and the noise:

1. x₁'s partial correlation given the others depends only on its own slope
   and the noise.
2. The others' R² is that of the model without x₁: what they explain of y
   on their own.
3. It is spread evenly: y's regression on the others has the same slope
   for each.

A consequence: with correlated predictors and covariates' R² = 0, the
covariates have small negative slopes in the full model. They explain
nothing on their own, but they are correlated with x₁, so their slopes
cancel what they would otherwise explain through x₁.

### The methods

Every dataset goes to every method (common random numbers):

| Method | How | Cost |
|---|---|---|
| flat partial r, flat R, flat R² | flatcor: both models fitted in Stan, each marginal likelihood by bridge sampling | almost all of it |
| Zellner–Siow (scale 1), JZS (scale √2/4) | BayesFactor, from R², n and k | negligible |
| p-value of x₁'s slope | the OLS fit | none |

The Bayes factor is always for x₁: the model with all k predictors against
the model without x₁ ([`shared/comparison_methods.R`](shared/comparison_methods.R)).

### What is kept per dataset (layer 1)

`results/per_dataset/study_1a_stage1.csv.gz`, one row per dataset and
method; "full" is the model with x₁, "reduced" the model without it.

| Columns | What |
|---|---|
| `dataset`, `stage`, `n`, `k`, `partial_r`, `covariates_r_squared`, `predictor_correlation`, `replication`, `dataset_seed` | The dataset's name, its cell, and the seed its data are drawn with |
| `true_r_squared_full`, `true_r_squared_reduced`, `true_slope_x1` | Its population |
| `r_squared_full`, `r_squared_reduced`, `k_full`, `k_reduced` | Both models' sample R² and numbers of predictors |
| `id`, `method`, `seed` | The row's name (dataset and method), and the seed of its Stan fits and bridge sampling (the reduced model's is seed + 1) |
| `log_BF10`, `error` | The log Bayes factor for x₁ and its approximate Monte Carlo SE |
| `log_ml_full`, `error_full`, `log_ml_reduced`, `error_reduced` | The three priors: each model's log marginal likelihood and bridge sampling's error, so any Bayes factor can be formed afterwards |
| `log_ml_null`, `error_null`, `seconds_null` | The three priors: the intercept-only model's log marginal likelihood (below) |
| `log_bf_intercept_full`, `log_bf_intercept_reduced` (and their `error_`) | The references: each model's log Bayes factor against the intercept-only model |
| `divergent`, `divergent_full`, `divergent_reduced`, `rhat_max_*`, `ess_bulk_min_*`, `ess_tail_min_*`, `bridge_iterations_*` | Stan's and bridge sampling's diagnostics, per model |
| `t_value`, `p_value` | The p-value row: x₁'s t statistic and its two-sided p-value |
| `seconds`, `seconds_sampling_*`, `seconds_bridge_*`, `draws`, `machine` | Run descriptives: seconds per method and per model, posterior draws per model, the machine |

Two more files hold the details of every Stan fit, per k:
`study_1a_stage1_variables_<k>.csv.gz` (every variable's mean, median, sd,
mad, quantiles, R-hat and bulk and tail ESS, per model) and
`study_1a_stage1_chains_<k>.csv.gz` (the sampler per chain). Both join to
the main file by `id`; their column `model` is `a` for the full model, `b`
for the reduced one.

**The intercept-only model** is kept: its marginal likelihood is the same
under the three priors (it has no R²), so it is fitted once per dataset
with flatcor, and the whole model can be tested afterwards (log BF =
`log_ml_full` − `log_ml_null`) without a rerun. flatcor fits it as one of
two models of a Bayes factor, so it costs two fits of a two-parameter model
per dataset; the first is kept. Measured on 22 Nov 2026 (an Apple M-series
laptop, n = 800, k = 12, 10,000 draws per chain): about 7 seconds per
dataset, against about 22 seconds for each of the three priors' Bayes
factors for x₁, so about 10% more per dataset in the slowest cell.

### Stopping

[`settings/stopping_rule.R`](settings/stopping_rule.R) and the study's
[`design.R`](studies/1a_decisions/design.R). Per cell, sequential, as in
project 1:

- **The quantities:** every method's rates. A Bayes factor decides at 10:
  with an effect it *finds the effect* at BF₁₀ ≥ 10 and *misleads* at
  BF₁₀ ≤ 1/10; without one it *confirms the null* at BF₁₀ ≤ 1/10 and
  misleads at BF₁₀ ≥ 10. The p-value decides at α = .05: it finds the effect
  at p < .05, and misleads at p < .05 when there is none.
- **The rule:** a cell stops when the worst rate's Monte Carlo SE is at most
  Δ / 1.96, with **Δ = .10**.
- **The floor:** a rate's SE is computed from (x + 2) / (n + 4)
  (Agresti & Coull, 1998), so 0 of 50 does not stop a cell at once.
- **First round 50, batches of 25, cap 100.** The worst case for one rate
  is 97 datasets, so the cap of 100 (a multiple of the batch size, so
  every batch is full) leaves the rule room to finish. Where the cap binds,
  `decision_rates` marks the rate `capped` and reports the width reached
  (`half_width`).

The results file (`results/studies/study_1a.rds`) holds those rates per
cell, the datasets per cell, and the diagnostics of the three priors.

## Stage 2 (later)

Extra datasets only where more certainty is wanted, chosen after looking at
stage 1. It is a part of its own in the same study (`"1a-stage2"`, as
project 1's 3a has `"3a"` and `"3a-repeats"`), over the chosen cells, with
`stage = "stage 2"`: its datasets get names, and so seeds, of their own,
stage 1's are untouched, and the two are not pooled. Its rule per cell (its
quantities, Δ, cap) is a lookup by the cell's values, with its cap added to
`dataset_caps`. For stage 2 to count as confirmation, its spec (cells,
quantities, Δ, cap and the expected result from stage 1) is committed before
it runs.

## Running it

As project 1 (the repository's [README](../README.md)), naming the project:

```bash
Rscript engine/tests/static_check.R                                         # with PROJECT=project_2_prior_comparison
VALIDATION_SMOKE=1 VALIDATION_RECORD=1 Rscript run_all.R project_2_prior_comparison   # once: record for the dry run
VALIDATION_DRY=1 Rscript run_all.R project_2_prior_comparison               # then after every change
```

### The timing run

Before the real run, the cost comes from a timing run
([`engine/run_time/`](../engine/run_time/)) on the slowest cells: in timing
mode the design keeps only n = 800 and k = 12 (30 cells), 2 or 3 datasets
each. Two fractions, so the estimate can separate a fixed cost from the cost
per dataset:

```bash
PROJECT=project_2_prior_comparison VALIDATION_TIMING=0.04 Rscript engine/run_time/time_study.R 1a
PROJECT=project_2_prior_comparison VALIDATION_TIMING=0.06 Rscript engine/run_time/time_study.R 1a
PROJECT=project_2_prior_comparison Rscript engine/run_time/estimate_run_time.R cache/project_2_prior_comparison/timing
```

The estimate it prints is for those 30 cells, at 50 datasets each. Their
cost per dataset bounds every other cell's, so the full stage 1 costs at most
570 cells × 100 datasets × that cost per dataset.
