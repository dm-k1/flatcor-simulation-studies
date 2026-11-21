# The tests

Four tests check the code, from cheapest to most thorough. None of them
checks whether the validation's numbers are right: that is what the
validation itself reports.

| Test | How to start it | Time | What it catches |
|---|---|---|---|
| Static check | `Rscript engine/tests/static_check.R` | seconds | A file that doesn't parse, an invalid pipeline, a function called that doesn't exist, and code that breaks the three rules below |
| Dry run | `VALIDATION_DRY=1 Rscript run_all.R` | a minute or two | Everything around the expensive calls: every step, every hand-over of a table between steps, the scheduler, every results file, the check at the end |
| Smoke test | `VALIDATION_SMOKE=1 Rscript run_all.R` | about 10 minutes | The whole run for real, on a corner of each design, with several workers and the real expensive calls |
| Check of the results | runs at the end of every run | seconds | A missing results file, an empty table, a NaN, Inf or NA that isn't a declared blank, a results file made with another commit of the package under test |

The smoke test and the dry run are kinds of run (`engine/run_mode.R`):
each has its own store and results in `cache/`, so neither mixes
with a real run. Both always start from scratch.

## The dry run

`dry_run.R` is the smoke test with the expensive calls replayed. They are
recorded once in a real smoke test:

```bash
VALIDATION_SMOKE=1 VALIDATION_RECORD=1 Rscript run_all.R
```

Record again when the package under test changes, or when an expensive call
returns something new. Which calls are expensive, which functions the dry
run replays, and what it skips are the project's choice:
`validation/engine_settings/dry_run_seams.R`.

## The three rules of the static check

1. Every expensive call is inside one of the seams the dry run replays, so
   the dry run can stand in for it.
2. A step reads and writes files only where that's declared: a study's
   results file, the plans and batches in the store, the recordings. Any
   other file a step needs or makes is a step of its own (`format = "file"`).
3. Every study that declares parts has a step that makes its results file,
   `results_<study>` (`format = "file"`).
