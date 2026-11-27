# Project 1: the validation. Do flatcor's three priors work?

The validation of [flatcor](https://github.com/dm-k1/flatcor), an R package
for objective Bayes factors and estimation in linear regression: whether each
of its three default priors works correctly within the Bayesian framework.
The argument for the priors, the priors and their derivations, and the paper
are in [flatcor-paper](https://github.com/dm-k1/flatcor-paper).

> The results in `results/` are those of the full v2 run (tag
> [`v2-results`](https://github.com/dm-k1/flatcor-simulation-studies/tree/v2-results));
> the results reported in the paper are at tag
> [`v1-results`](https://github.com/dm-k1/flatcor-simulation-studies/tree/v1-results).

## The three priors

| | What is flat | Implied $R^2$ | One coefficient's prior |
|---|---|---|---|
| **joint flat partial r** (`prior = "joint_partial_r"`) | every valid correlation matrix of $(y, x_1 \ldots x_k)$ | Beta($k/2$, 1), grows with $k$ | a flat partial correlation, for every $k$ |
| **flat R** (`prior = "flat_r"`) | the multiple correlation $R$ | Beta(½, 1), for every $k$ | its share of the flat total; narrows as $k$ grows |
| **flat R²** (`prior = "flat_r_squared"`) | $R^2$ | Beta(1, 1), for every $k$ | its share of the flat total; narrows as $k$ grows |

Project 1 tests the three priors with $R^2$ ~ Beta($a$, 1). The fourth prior, independent flat partial r, was added later and is tested in project 2.

All three are $R^2$ ~ Beta($a$, 1) with $a$ = $k/2$, ½ or 1, and divide the
total over the predictors without preference. As a density on the
coefficients:

```
P(beta) = P(total) x P(this combination | total) x unit conversion
          R^2 ~ Beta(a, 1)     every split equally likely   noise units -> data units
```

flatcor does everything with one Stan model, the same for the three priors:
it draws the prior, gives the posterior, and gives the Bayes factor between
any two linear models, from each model's marginal likelihood estimated by
bridge sampling. Why these three, and why the default is joint flat partial r: the
paper's repository.

## The validation

What someone needs to trust that each prior works within the Bayesian
framework: three things for every prior, each checked in two ways, with
checks the field already uses.

| | 1. Prior sampling | 2. Posterior estimation | 3. Bayes factors |
|---|---|---|---|
| **a. Computed correctly?** | 1a: the prior draws against the exact prior | 2a: simulation-based calibration | 3a: calibration of the Bayes factor; bridge sampling's error |
| **b. Behaves like a default?** | 1b: invariance | 2b: estimation against a known truth | 3b: the Bayarri et al. (2012) criteria |

Every study reports its estimates against what is expected, with their Monte
Carlo errors; nothing is judged pass or fail per row.

> **TO REFRESH from the full run:** a short summary of the six studies'
> results for each prior (the figures: a separate private repository).

## Reading order

Background, in [flatcor-paper](https://github.com/dm-k1/flatcor-paper):
[the three priors](https://github.com/dm-k1/flatcor-paper/blob/main/docs/2_the_four_priors.md)
(part 2: the family $R^2 \sim$ Beta($a$, 1), what each keeps flat and
expects, how the total is divided, what the package computes) and
[their derivations](https://github.com/dm-k1/flatcor-paper/blob/main/docs/appendix/A_derivations.md)
(appendix A: the density factor by factor, the Stan model, the Bayes factors
and the g-prior forms behind them, the default-prior criteria). The table
above is enough to follow the validation. In this repository:

| | Document | What it is |
|---|---|---|
| 1 | [`docs/validation_tests.md`](docs/validation_tests.md) | **What the validation tests**: per study its design, what is tested, what is expected and why, with what Monte Carlo error and how many datasets, and the data sets |
| 2 | a separate private repository | **The results**, shown: per study its question, its estimates against what is expected, and figures (a separate repository that reads this one's results files) |

Working notes: [`docs/notes/`](docs/notes/) (the plan of the redesign, the
run-time estimate).

## Names used

| Name used | Means | Also appears as |
|---|---|---|
| **total** | the explained variance $R^2$ of the whole model (flat R keeps its square root $R$ flat) | "shared total" |
| **shape** $a$ | the first parameter of $R^2 \sim$ Beta($a$, 1): $k/2$, ½ or 1 | `r_squared_shape` (Stan), `prior_shape()` |
| **share** | the fraction of the total that one predictor gets; Beta(½, (k−1)/2) for every $a$ | $c^2$ (squared alignment, appendix A section 7), $B$ (appendix A section 8) |
| **noise units**, $f$ | an effect divided by the noise SD $\sigma$; $f^2$ is Cohen's $f^2$ | |
| **Bayes factor for a term** | the model with the term against the model without it, each with its own prior | |
| **references** | JZS default (Cauchy, scale 0.354) and Zellner–Siow (scale 1) | |

## Using the priors: what to watch out for

- **Choosing the prior.** Without `prior =`, flatcor uses joint flat partial r and
  says so once per session. What each prior assumes:
  [`2_the_four_priors.md`](https://github.com/dm-k1/flatcor-paper/blob/main/docs/2_the_four_priors.md) (in flatcor-paper).
- **Shrinkage at small $n$.** With several predictors and a small sample, the
  prior pulls estimates towards zero (study 2b shows how much).
- **Leaving the null model.** Against the intercept-only model, evidence for
  the null grows like $a \log n$: ½ log n for flat R and log n for flat
  R-squared, whatever the number of predictors, and $\tfrac k2 \log n$ for
  joint flat partial r.
- **Under joint flat partial r the claimed $R^2$ grows with $k$.** The median is .63
  with 3 predictors and .87 with 10, so a large model with a modest fit is
  penalised.
- **Flat R-squared with one predictor is not Jeffreys' prior.** Its prior on
  $r$ has density $|r|$, which gives little weight to correlations near zero.
- **Information consistency needs $n \ge k + 3$**, for all three priors.
- **Bayes factors are estimates.** Each comes with a Monte Carlo error
  (bridge sampling's approximate error, which can be optimistic), and models
  up to about 90 predictors stay within the sizes bridge sampling has been
  shown to work for.
- **Scope.** Linear regression with a normal outcome, an intercept and fixed
  effects (continuous predictors, factors tested as one block, interactions,
  polynomials, splines). Not supported: group-level effects, other families,
  distributional models, models without an intercept.

## Running it

From the repository's root (its README, "Running a project"):

```bash
VALIDATION_SMOKE=1 Rscript run_all.R project_1_validation   # a corner of every study, about 10 minutes
Rscript run_all.R project_1_validation                      # the studies
Rscript run_all.R project_1_validation 3a                   # one study
```

The results go to [`results/`](results/): each study's results
(`results/studies/study_<study>.rds`) and every dataset's rows
(`results/per_dataset/`). The figures and the notebook that show them live
in a separate private repository.

## What's where

Paths in this project's code are relative to this folder; `engine/` is the
repository's engine, next to it.

| Path | What it is |
|---|---|
| `settings/` | This project's answers to the engine: its settings (the package under test, the packages every step loads, the cores a batch keeps busy), the stopping rule, and the dry run's seams |
| `shared/` | What the studies share: flatcor's Stan model (`flatcor_models.R`), the comparison methods and the data generators (`data/`; what each is and which study needs it: `docs/validation_tests.md`, "The data sets") |
| `studies/` | The six studies, one folder each: `design.R` (the design, and what the study declares), `code.R` and `steps.R` (its pipeline steps). A new study is a new folder; no other file changes |
| `results/` | Each study's metrics and setup, `studies/study_<study>.rds` (layer 2); every dataset's numbers and everything else computed, `per_dataset/` (layer 1, its README lists the files and columns); the record of runs, `RUNS.md` |
| `docs/` | What the validation tests (`validation_tests.md`), and notes (`notes/`: the plan of the redesign, the run-time estimate) |
