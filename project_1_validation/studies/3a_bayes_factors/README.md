# 3a: Bayes factors

## Question

Are the Bayes factors right? Part A checks their calibration; part B measures bridge sampling's error by repeating runs (the parts are in the section linked below).

## Design

The design, what is expected and why: [study 3a in `validation_tests.md`](../../docs/validation_tests.md#3a-are-the-bayes-factors-right). `design.R` holds the six cells (prior by setting), the data from the prior, and how many datasets each part needs.

## Code

- `design.R`: the six cells (prior by setting), the data from the prior, and how many datasets each part needs.
- `steps.R`: the pipeline steps: part A (calibration) and part B (repeated runs), their tables, and the results file.
- `code.R`: one dataset's Bayes factor, the calibration summaries, the repeated-run spread, and the shortfall of the reported error.

## Run it

From the repository's root (its README, "Running a project"):

```bash
VALIDATION_SMOKE=1 Rscript run_all.R project_1_validation 3a   # a small corner first
Rscript run_all.R project_1_validation 3a
```

This runs the steps whose names end in `_3a` (`targets::tar_make(names = ends_with("_3a"))`, in `engine/full_run.R`). Studies 1b and 3b read 3a's `shortfall_3a`, so they run 3a's part B too.

## Output

In [`results/`](../../results/):

- `studies/study_3a.rds`: the study's results.
- `per_dataset/`: `study_3a_calibration.csv`, `study_3a_repeated_runs.csv`, part A's and part B's rows (columns: [`per_dataset/README.md`](../../results/per_dataset/README.md)).

## Status

Run for real in [`real-run-3a-3b`](https://github.com/dm-k1/flatcor-simulation-studies/tree/real-run-3a-3b) (studies 3a, 3b), and in the full run of [`v2-results`](https://github.com/dm-k1/flatcor-simulation-studies/tree/v2-results) (run v2-real-2, all six studies). How the run was made: [`results/RUNS.md`](../../results/RUNS.md).
