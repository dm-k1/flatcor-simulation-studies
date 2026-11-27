# 3b: default criteria

## Question

Do the Bayes factors meet the default-prior criteria? These are the criteria of Bayarri, Berger, Forte and García-Donato (2012); invariance is study 1b.

## Design

The design, what is expected and why: [study 3b in `validation_tests.md`](../../docs/validation_tests.md#3b-do-the-bayes-factors-meet-the-default-prior-criteria). `design.R` holds the checks 3b.1 to 3b.9: the formula checks, the rates, the prior's draws, and k growing with n.

## Code

- `design.R`: the checks 3b.1 to 3b.9: the formula checks, the rates, the prior's draws, and k growing with n.
- `steps.R`: the pipeline steps: the formula checks, the rates, the growing-k datasets, the intrinsic draws, and the results file.
- `code.R`: one Bayes factor per check, the slopes and medians for each criterion, and the intrinsic draws.

## Run it

From the repository's root (its README, "Running a project"):

```bash
VALIDATION_SMOKE=1 Rscript run_all.R project_1_validation 3b   # a small corner first
Rscript run_all.R project_1_validation 3b
```

This runs the steps whose names end in `_3b` (`targets::tar_make(names = ends_with("_3b"))`, in `engine/full_run.R`). It also runs 3a's part B (`needs` in `design.R`), for the shortfall of the reported error.

## Output

In [`results/`](../../results/):

- `studies/study_3b.rds`: the study's results.
- `per_dataset/`: `study_3b_formula.csv`, `study_3b_rates.csv`, `study_3b_growing_k.csv`, `study_3b_intrinsic_draws.csv.gz`, the rows of each check (columns: [`per_dataset/README.md`](../../results/per_dataset/README.md)).

## Status

Run for real in [`real-run-3a-3b`](https://github.com/dm-k1/flatcor-simulation-studies/tree/real-run-3a-3b) (studies 3a, 3b), and in the full run of [`v2-results`](https://github.com/dm-k1/flatcor-simulation-studies/tree/v2-results) (run v2-real-2, all six studies). How the run was made: [`results/RUNS.md`](../../results/RUNS.md).
