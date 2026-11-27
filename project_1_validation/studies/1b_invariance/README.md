# 1b: invariance to units and coding

## Question

Is the Bayes factor invariant to units and coding? Rescaling, shifting or recoding the predictors and the outcome should leave it unchanged.

## Design

The design, what is expected and why: [study 1b in `validation_tests.md`](../../docs/validation_tests.md#1b-is-the-bayes-factor-invariant-to-units-and-coding). `design.R` holds the three priors, the ordinary-regression data, the two changes (rescaled, recoded), and how many datasets are needed.

## Code

- `design.R`: the three priors, the ordinary-regression data, the two changes (rescaled, recoded), and how many datasets are needed.
- `steps.R`: the pipeline steps: the log Bayes factors, run in rounds until their targets are reached, the changes, and the results file.
- `code.R`: rescaling and recoding a dataset, the five log Bayes factors of each, and the changes pooled per prior.

## Run it

From the repository's root (its README, "Running a project"):

```bash
VALIDATION_SMOKE=1 Rscript run_all.R project_1_validation 1b   # a small corner first
Rscript run_all.R project_1_validation 1b
```

This runs the steps whose names end in `_1b` (`targets::tar_make(names = ends_with("_1b"))`, in `engine/full_run.R`). A change of one dataset is judged against bridge sampling's error as 3a measures it, so this also runs 3a's part B, the repeated runs (`needs` in `design.R`).

## Output

In [`results/`](../../results/):

- `studies/study_1b.rds`: the study's results.
- `per_dataset/`: `study_1b_log_bayes_factors.csv`, every dataset's log Bayes factors (columns: [`per_dataset/README.md`](../../results/per_dataset/README.md)).

## Status

Run for real in [`real-run-1a-2b`](https://github.com/dm-k1/flatcor-simulation-studies/tree/real-run-1a-2b) (studies 1a, 1b, 2a, 2b), and in the full run of [`v2-results`](https://github.com/dm-k1/flatcor-simulation-studies/tree/v2-results) (run v2-real-2, all six studies). How the run was made: [`results/RUNS.md`](../../results/RUNS.md).
