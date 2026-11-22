# flatcor-validation: simulation studies of flatcor

Simulation studies of [flatcor](https://github.com/dm-k1/flatcor), an R
package for objective Bayes factors and estimation in linear regression.
The argument for its priors, the priors and their derivations, and the
paper are in [Objective-bayes](https://github.com/dm-k1/Objective-bayes).

> **Branch v2: work in progress.** Code and results here can change at any
> time. `main` holds the last full run (tag
> [`v2-results`](https://github.com/dm-k1/flatcor-validation/tree/v2-results));
> the results reported in the paper are at tag
> [`v1-results`](https://github.com/dm-k1/flatcor-validation/tree/v1-results).

The repository holds an engine, which runs simulation studies on parallel
workers up to their results files, and the projects that use it, each in a
folder of its own:

| Project | What it asks |
|---|---|
| [`project_1_validation/`](project_1_validation/) | Do flatcor's three default priors work within the Bayesian framework? |
| [`project_2_prior_comparison/`](project_2_prior_comparison/) | How do the priors' Bayes factors differ in the decisions they lead to? (stage 1 built, not run) |

The engine ([`engine/`](engine/), its README) names no study and no
package; a project tells it everything it needs (`<project>/settings/`).
A new project is a new folder next to the others.

## Running a project

Restore the environment with `renv::restore()` (it installs flatcor at the
pinned version, with targets, crew and the other packages), or use the
container image of `cluster/Dockerfile`, published by GitHub Actions as
`ghcr.io/dm-k1/flatcor-validation`. Then, naming the project (a project
folder; it may be left out while there is only one, or set as
`PROJECT=<project>`):

```bash
VALIDATION_SMOKE=1 Rscript run_all.R project_1_validation   # first: a corner of every study, about 10 minutes
Rscript run_all.R project_1_validation                      # the studies
Rscript run_all.R project_1_validation 3a                   # one study
VALIDATION_FRESH=1 Rscript run_all.R project_1_validation   # the studies, from scratch
PROJECT=project_1_validation Rscript engine/run_time/remaining_time.R   # during a run, beside it: the time left
```

Each project has its own store (`_targets/<project>/`), its own results
(`<project>/results/`) and its own folder in `cache/` for its smoke test,
dry run and timing runs, so projects never mix.

A run has a budget of 2,500 core hours (`VALIDATION_BUDGET_CORE_HOURS`).
It estimates as it goes what is left: every dataset asked for and not yet
done, times what a dataset of its part has cost so far. When what it has
spent plus that estimate is more than the budget, it stops and reports what
is left per part; raise the budget or change a target, and start again: it
continues where it was.

A run ends at the results files, in the project's `results/`: each study's
results (`studies/`) and every dataset's rows (`per_dataset/`). The
smoke test runs every step on a small part of each design, from scratch,
with its results in `cache/` (never mixed with real ones).

### Figures and the notebook: another repository

This repository ends at the results files. The figures and the notebook
that show project 1's results live in
a separate private repository (a private repository),
which only reads those files; nothing here knows of it.

### Faster checks while working on the code

Two cheaper checks come before the smoke test, for the mistakes that do
not need Stan to show up: a renamed function, a column a later step
expects but an earlier one no longer writes, a results file that is not
made.

```bash
Rscript engine/tests/static_check.R                   # seconds: parses, the pipeline is valid, every function called exists, the rules below
VALIDATION_SMOKE=1 VALIDATION_RECORD=1 Rscript run_all.R project_1_validation # once: the smoke test, recording what Stan and bridge sampling returned
VALIDATION_DRY=1 Rscript run_all.R project_1_validation # then, after every change: the dry run
```

The dry run ([`engine/tests/dry_run.R`](engine/tests/dry_run.R)) is the smoke
test with the calls to Stan and bridge sampling replayed from those
recordings (in `cache/<project>/dry_recordings/`), in one R process, no model
compiled. It changes no study's code: that file is sourced after the
studies, only in a recording run or the dry run, and replaces a few
functions (the seams: flatcor's Bayes factors and fit, 1a's prior draws of a
setting, 2a's SBC fits of a batch) by versions that record or replay the
original. Everything else runs for real: the data, every step, the
hand-overs between them, the scheduler with two batches for each cell, the
results files and the check at the end. Its results go to
`cache/<project>/dry_results/`. It does not test the code inside the seams or whether
the numbers are right: run the smoke test for that, and record again when
flatcor changes. When the design or a data step has changed since the
recording, the dry run replays recordings of the same shape (prior, numbers
of predictors) and says so; when there is none, it stops and says to record
again.

Both rest on three rules for the pipeline's code, which the static check
enforces (it fails, saying which rule and where):

1. Every expensive call (Stan, bridge sampling, SBC) is inside one of the
   seams the project lists in `<project>/settings/dry_run_seams.R`,
   so the dry run can stand in for it. A new expensive step either calls one of them or gets a seam of its
   own there.
2. A step reads and writes files only where it is declared: a study's
   results file, the plans and the scheduler's finished batches (both in
   the store), the recordings. Any other file a
   step needs or makes is a step of its own (`tar_target(..., format =
   "file")`), so targets knows it is there before a step needs it.
3. Every study that declares parts has a step that makes its results file,
   `results_<study>` (`format = "file"`).

Every run ends with a check of its outputs
([`engine/tests/check_results.R`](engine/tests/check_results.R)): a results file
for every study run, all with the run's flatcor; no empty table, no NaN,
Inf or NA in any table, except blanks that are there by design (each study
declares its own, with its reason, in its `design.R`). The smoke test, and so every push,
fails when the check finds a problem; a real run reports it
in its log.

A stopped run continues where it was. It refuses to
continue with another flatcor than the one it started with (each results
file records the flatcor commit), so one results file never mixes two
versions; start from scratch then. (`targets::tar_make()` runs the pipeline
without that check: for working on a single step.)
[`cluster/README.md`](cluster/README.md) describes the container image, how
long the full run takes, and how to run it on a cluster (Apptainer, a SLURM
job, resubmitting until it is done).

Every push, to any branch, is checked automatically
([`.github/workflows/check.yml`](.github/workflows/check.yml)): lintr, the
links, the workflow files, for every project folder the static check, and
the smoke test inside the published image (once per change: a push that
builds a new image is smoke-tested by that build, and the check then skips
it). A push that changes the environment (the Dockerfile, `renv.lock`)
builds and publishes its image first (`image.yml`), on any branch too.

The check's smoke test runs only what changed since the last commit on the
same branch that passed it
([`ci/smoke_selection.sh`](ci/smoke_selection.sh)):

| Changed | Smoke-tested |
|---|---|
| a study's folder, `project_X/studies/<code>_*/` | that study, the parts it needs, and the studies that use its parts ([`ci/smoke_studies.R`](ci/smoke_studies.R)) |
| any other file in `project_X/` (`shared/`, `settings/`, ...) | all of project X |
| any file outside `project_*/` (`engine/`, `_targets.R`, `run_all.R`, `renv.lock`, `ci/`, `cluster/`) | every project |
| only docs: `project_*/docs/`, `*.md`, `.github/`, `cluster/aws/`, `.lintr` | nothing |
| a branch with no passed check yet | every project |

The image build always smoke-tests every project. By hand, a project's
studies run alone as `Rscript run_all.R <project> 1b 3b`.

The smoke test is meant to run the way a real run does, because a bug can
hide anywhere the two differ. So it runs in the same image (the same
packages and CmdStan) and with several workers (3, by pretending to have 16
cores), since workers clashing over shared files only happens with more
than one. Two differences remain, on purpose: a cell gets at most one
more batch after its first (later batches run the same code), and it runs a
corner of each design.

## What's where

| Path | What it is |
|---|---|
| `run_all.R` | Runs a project (only the simulation): every study's batches through the scheduler, each cell until it has enough datasets, then the pipeline for the results (`engine/full_run.R`) |
| `_targets.R` | The pipeline: collects the chosen project's steps |
| `engine/` | The engine, with no study or package named in it, meant to carry over to another project unchanged: the scheduler and its workers, the pipeline steps, the results files, the four tests and the run-time estimate. Its README explains the words it uses, how a run goes, and what a project and a study provide |
| `project_1_validation/` | Project 1, the validation of flatcor's three priors: its settings, studies, results and docs (its README) |
| `cluster/` | The container image, the run-time estimate, and how to run a project on a cluster or AWS |
| `ci/` | Helpers for the checks |
| `.github/workflows/` | The checks on every push (`check.yml`), the image build (`image.yml`) and the run-time estimate, on demand (`timing.yml`) |
| `renv.lock`, `.lintr` | The pinned packages, shared by the projects; the code style |

## Author

D.M. Kloppenburg, University of Amsterdam.

## License

MIT (`LICENSE.md`).
