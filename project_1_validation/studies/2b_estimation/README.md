# 2b: estimation

## Question

How close are the estimates to a known truth? How each prior's posterior estimates behave on data with fixed slopes. The references are not guaranteed for a Bayesian estimate, so this study describes.

## Design

The design, what is expected and why: [study 2b in `validation_tests.md`](../../docs/validation_tests.md#2b-how-close-are-the-estimates-to-a-known-truth). `design.R` holds the sixteen cells (k, n, predictor correlation, other slopes), the methods compared, and the Stan draws.

## Code

- `design.R`: the sixteen cells (k, n, predictor correlation, other slopes), the methods compared, and the Stan draws.
- `steps.R`: the pipeline steps: the fits, run until their targets are reached, and the results file.
- `code.R`: fitting every method to one dataset, and the bias, coverage and prediction summaries.

## Run it

From the repository's root (its README, "Running a project"):

```bash
VALIDATION_SMOKE=1 Rscript run_all.R project_1_validation 2b   # a small corner first
Rscript run_all.R project_1_validation 2b
```

This runs the steps whose names end in `_2b` (`targets::tar_make(names = ends_with("_2b"))`, in `engine/full_run.R`).

## Output

In [`results/`](../../results/):

- `studies/study_2b.rds`: the study's results.
- `per_dataset/`: `study_2b_fits.csv`, every fit's row (columns: [`per_dataset/README.md`](../../results/per_dataset/README.md)).

## Status

Run for real in [`real-run-1a-2b`](https://github.com/dm-k1/flatcor-simulation-studies/tree/real-run-1a-2b) (studies 1a, 1b, 2a, 2b), and in the full run of [`v2-results`](https://github.com/dm-k1/flatcor-simulation-studies/tree/v2-results) (run v2-real-2, all six studies). How the run was made: [`results/RUNS.md`](../../results/RUNS.md).
