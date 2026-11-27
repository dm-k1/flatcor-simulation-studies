# 1a: prior sampling

## Question

Does the software draw the prior it claims? flatcor's Stan model, with the data switched off, should draw exactly the prior.

## Design

The design, what is expected and why: [study 1a in `validation_tests.md`](../../docs/validation_tests.md#1a-does-the-software-draw-the-prior-it-claims). `design.R` holds the nine settings (prior by predictor design), the percentiles compared, and how many draws are needed.

## Code

- `design.R`: the nine settings (prior by predictor design), the percentiles compared, and how many draws are needed.
- `steps.R`: the pipeline steps: each setting's prior draws, the prior as a recipe (a second route), their comparison, and the results file.
- `code.R`: drawing each setting's prior, drawing the recipe, and comparing both with the expected distribution.

## Run it

From the repository's root (its README, "Running a project"):

```bash
VALIDATION_SMOKE=1 Rscript run_all.R project_1_validation 1a   # a small corner first
Rscript run_all.R project_1_validation 1a
```

This runs the steps whose names end in `_1a` (`targets::tar_make(names = ends_with("_1a"))`, in `engine/full_run.R`).

## Output

In [`results/`](../../results/):

- `studies/study_1a.rds`: the study's results.
- `per_dataset/`: `study_1a_prior_draws.csv.gz`, `study_1a_recipe_draws.csv.gz`, `study_1a_settings.csv`, the draws and each setting's run (columns: [`per_dataset/README.md`](../../results/per_dataset/README.md)).

## Status

Run for real in [`real-run-1a-2b`](https://github.com/dm-k1/flatcor-simulation-studies/tree/real-run-1a-2b) (studies 1a, 1b, 2a, 2b), and in the full run of [`v2-results`](https://github.com/dm-k1/flatcor-simulation-studies/tree/v2-results) (run v2-real-2, all six studies). How the run was made: [`results/RUNS.md`](../../results/RUNS.md).
