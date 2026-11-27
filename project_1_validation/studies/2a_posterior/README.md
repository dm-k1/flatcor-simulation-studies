# 2a: posterior

## Question

Is the posterior computed correctly? Simulation-based calibration (Talts et al., 2018): draw the parameters from the prior, data from them, and fit; if the posterior is right, the rank of each true value among its posterior draws is uniform.

## Design

The design, what is expected and why: [study 2a in `validation_tests.md`](../../docs/validation_tests.md#2a-is-the-posterior-computed-correctly). `design.R` holds the six cells (prior by setting), the data from the prior, the Stan iterations, and how many fits are needed.

## Code

- `design.R`: the six cells (prior by setting), the data from the prior, the Stan iterations, and how many fits are needed.
- `steps.R`: the pipeline steps: the SBC fits, one batch per setting, and the results file.
- `code.R`: one SBC dataset and its fit, a batch of them, the rank summaries and the divergences.

## Run it

From the repository's root (its README, "Running a project"):

```bash
VALIDATION_SMOKE=1 Rscript run_all.R project_1_validation 2a   # a small corner first
Rscript run_all.R project_1_validation 2a
```

This runs the steps whose names end in `_2a` (`targets::tar_make(names = ends_with("_2a"))`, in `engine/full_run.R`).

## Output

In [`results/`](../../results/):

- `studies/study_2a.rds`: the study's results.
- `per_dataset/`: `study_2a_sbc_fits.csv`, `study_2a_sbc_diagnostics.csv`, every fit's rows and diagnostics (columns: [`per_dataset/README.md`](../../results/per_dataset/README.md)).

## Status

Run for real in [`real-run-1a-2b`](https://github.com/dm-k1/flatcor-simulation-studies/tree/real-run-1a-2b) (studies 1a, 1b, 2a, 2b), and in the full run of [`v2-results`](https://github.com/dm-k1/flatcor-simulation-studies/tree/v2-results) (run v2-real-2, all six studies). How the run was made: [`results/RUNS.md`](../../results/RUNS.md).
