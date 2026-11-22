# The engine

The engine runs a simulation validation: it runs the studies' work on
parallel workers, reports each study's estimates against what is expected,
and tests itself. It names no study and no package. Another project copies
this folder and the two root scripts (`_targets.R`, `run_all.R`)
unchanged, then writes its own project folder next to the engine,
`project_<n>_<name>/` (`<project>/` below): its settings, what its studies
share, the studies themselves (`<project>/studies/`), and its results and
docs. Several projects can sit side by side; a run names the one it runs
(`Rscript run_all.R <project>`, or `PROJECT=<project>`). The engine
ends at the results files; showing them (figures, a notebook) is not its
concern.

## Words

| Word | Meaning |
|---|---|
| study | One folder in `<project>/studies/`, such as `2b_estimation`; its code is the folder's first two characters (`2b`) |
| part | One kind of work a study runs, declared in its `design.R`. A part runs either until its targets are reached (`part_until_target()`) or once (`part_once()`). A study can have several parts (3a has its calibration and its repeats) |
| cell | One setting of a part's design, such as k = 3, n = 50, ρ = 0.3 |
| batch | A group of datasets of one cell, run as one task by one worker and saved when it finishes |
| plan | For each cell of a part, how many datasets it has been given so far |
| stopping rule | The project's rule that decides, after each batch, whether a cell has enough datasets or how many more it needs |

## How a full run goes

1. `full_run.R` reads every study's parts (`study_form.R`).
2. The scheduler (`workers/scheduler.R`) gives every cell its first batch.
   The workers run the batches (`workers/batches.R`) and save each one.
3. When all of a cell's batches are back, the scheduler asks the stopping
   rule: is the cell done, or how many more datasets does it need? If more,
   the next batch goes out at once, without waiting for other cells or
   studies.
4. After every finished batch, the scheduler estimates what is left: every
   dataset asked for and not yet done, times what a dataset of its part has
   cost so far. If what has been spent plus that estimate is more than the
   budget, the run stops: nothing new starts, and finished batches are
   kept. You then raise the budget or change a target, and start again; the
   run continues where it was.
5. When every cell is done, the pipeline (`pipeline/`, targets) makes each
   study's results from the saved batches. It writes the results files
   (`results/results_files.R`) and the per-dataset files
   (`results/per_dataset_files.R`).
6. `tests/check_results.R` checks those files.

A dataset's random numbers come from its name (`seeds.R`). A cell is judged
only on its own results. So a study gives the same numbers whether it runs
alone or with any other studies, on any number of workers.

## What's where

| Path | What it does |
|---|---|
| `load_code.R` | Which files are loaded, in which order |
| `run_mode.R` | Which kind of run this is (full run, smoke test, dry run, timing run) and where its files go |
| `full_run.R` | A full run from start to finish |
| `study_form.R` | What a study tells the engine about itself |
| `seeds.R` | Every random draw gets a seed from its name |
| `pipeline/pipeline_setup.R` | The targets settings: packages, root seed, workers |
| `pipeline/pipeline_steps.R` | Turns a study's parts into targets steps, and collects every study's `steps.R` |
| `workers/worker_setup.R` | How many workers, and what each inherits |
| `workers/scheduler.R` | Hands out batches, asks the stopping rule, keeps the budget |
| `workers/batches.R` | A cell's plan and batches; runs one batch, saves it, reads it back |
| `results/estimates_vs_expectations.R` | Each estimate against what is expected, in Monte Carlo SEs |
| `results/results_files.R` | Writing a study's results file (layer 2) |
| `results/per_dataset_files.R` | Writing and reading every dataset's rows (layer 1) |
| `tests/` | The four tests (`tests/README.md`) |
| `run_time/` | Before a run: time a study on a share of its datasets (`time_study.R`), and scale that up to the full run (`estimate_run_time.R`). During a run: the time left, per part, per study and in all (`remaining_time.R`) |

## What the project provides

These files are in `<project>/settings/`. The engine reads them by
name.

| File | What it gives the engine |
|---|---|
| `settings.R` | `tested_package`, `step_packages`, `cores_per_batch`, `part_sizes`, `prepare_models()`, `batch_model()`, `project_setup()`, `project_file_functions`, `prepare_workers()` |
| `stopping_rule.R` | `next_plan(plan, table, by, batch_size, one_batch)`: a cell's plan after judging its table |
| `dry_run_seams.R` | `expensive_calls`, `replayed_functions`, `skipped_in_dry_run`, and the replacements the dry run uses |
| `timing_reference.R` | `reference_seconds()`: a fixed task that measures how fast a machine is |

Everything else in `<project>/` is the project's own: what its studies
share (`shared/`, with the data generators in `data/`), its studies, its
results and its docs. The engine loads the code in `settings/`, `shared/`
and `studies/`.

## What a study provides

A study is one folder in `<project>/studies/`:

| File | What it holds |
|---|---|
| `design.R` | The design, and at its end what the study declares: its parts (`declared_parts`), blanks by design (`declared_blanks`), tables empty in the smoke test (`declared_empty_in_smoke`) |
| `code.R` | The functions that compute the study |
| `steps.R` | Its steps in the pipeline, ending in a `list()`. Every step's name ends in `_<study>`, and the results step is `results_<study>` (`format = "file"`) |

A new study is a new folder. No other file changes.
