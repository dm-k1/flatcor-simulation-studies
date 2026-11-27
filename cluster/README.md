# Running the validation elsewhere, and how long it takes

The validation is one pipeline ([`_targets.R`](../_targets.R)); `Rscript
run_all.R` runs it, up to the results files. It saves every
finished batch as it goes, so it can run anywhere a run may stop (a laptop, Colab, a cloud
machine) and continue where it was, as long as the project folder (with its
`_targets/<project>/` store) survives and flatcor stays the same: `run_all.R` refuses
to continue with another flatcor commit than the run started with.
`VALIDATION_FRESH=1 Rscript run_all.R <project>` starts from scratch. This folder
holds what helps with that: a container image with the exact environment,
the run-time estimate, and how to run it on a cluster.

## The container image

`cluster/Dockerfile` builds R 4.6.1, the packages of `renv.lock` and CmdStan
2.40.0. GitHub Actions ([`.github/workflows/image.yml`](../.github/workflows/image.yml))
builds it whenever the environment changes, runs the whole pipeline in smoke
mode inside it, and only then publishes it as
`ghcr.io/dm-k1/flatcor-validation:env-<fingerprint>`. The fingerprint is a
hash of the three files the image is built from (the Dockerfile, its ignore
file and `renv.lock`); [`image_tag.sh`](image_tag.sh) prints it for the
checkout you are in, so every commit finds the image of its own environment,
whatever the branch. That build's smoke test counts for the check on every
push (`check.yml` skips its own when an image build tested the same code),
and whatever runs inside the image in CI first waits for an image build still
running ([`ci/wait_for_image.sh`](../ci/wait_for_image.sh)). To run the
validation in it, from the project folder:

```bash
docker run --rm -v "$PWD":/project "ghcr.io/dm-k1/flatcor-validation:$(cluster/image_tag.sh)"
```

Without the image, `renv::restore()` installs the same packages; CmdStan comes
from `cmdstanr::install_cmdstan()`.

## How long it takes

The estimate is the run itself, stopped after its first round: every cell
runs its first datasets and is judged by the stopping rule, which then asks
for what the cell is estimated to lack. With `VALIDATION_FIRST_ROUND=1` the
run plans those datasets without running them, prints what they are
expected to cost (core hours per part, per study and in all, and hours on
its workers), and stops:

```bash
VALIDATION_FIRST_ROUND=1 Rscript run_all.R project_1_validation   # the first round, then the estimate
Rscript run_all.R project_1_validation                            # later: continues where it stopped
```

Nothing is lost: the first round's batches are kept, so the run without
`VALIDATION_FIRST_ROUND` continues from them. The first round is the least
the run needs anyway; a cell may still ask for more once its next datasets
are back, so read the estimate as a likely figure, not a maximum.

## On a cluster

The run uses one machine with many cores: the pipeline starts a worker for
every 4 cores it is given (each batch runs Stan's 4 chains in parallel)
and keeps every finished batch in `_targets/<project>/`. On a cluster that is
one job on one node, resubmitted until the pipeline is done. (Several nodes
would need crew's cluster controllers instead; not set up.)

The workers stay busy until the end. Every batch goes through the
scheduler ([`engine/workers/scheduler.R`](../engine/workers/scheduler.R)):
each cell is judged as soon as its own batch is done and, if it needs more
datasets, its next batch goes out at once, without waiting for the other
cells. When what the run has spent plus what it still expects to cost is
more than its budget, it stops and reports what is left (as the first
round does, above; `Rscript engine/run_time/remaining_time.R` shows the same
from outside, at any moment). The
parts that run once (1a, 2a, 3b.1 and 3b.2) go out first and run
alongside. Then the pipeline runs once, in minutes: every study's results,
from the finished batches.

**1. The project, at the commit to run.** Clone it onto storage that survives
between jobs (your home or project space, not a node's local scratch):

```bash
git clone https://github.com/dm-k1/flatcor-simulation-studies.git
cd flatcor-simulation-studies
```

**2. The image, as an Apptainer file.** Clusters seldom allow Docker, but
Apptainer (formerly Singularity) runs the same image. Pull it once; the
`.sif` file is then fixed for the whole run:

```bash
apptainer pull flatcor-validation.sif "docker://ghcr.io/dm-k1/flatcor-validation:$(cluster/image_tag.sh)"
```

**3. A job script**, here for SLURM (`run_validation.sbatch`, next to the
project; adjust the partition, cores, memory and time to the cluster):

```bash
#!/bin/bash
#SBATCH --job-name=flatcor-validation
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=33
#SBATCH --mem=66G                  # 2 GB per core
#SBATCH --time=5-00:00:00
#SBATCH --output=cache/logs/slurm-%j.log

cd "$SLURM_SUBMIT_DIR"
apptainer exec --bind "$PWD":/project --pwd /project flatcor-validation.sif \
  Rscript run_all.R project_1_validation
```

```bash
mkdir -p cache/logs          # SLURM opens the log before the script runs
sbatch run_validation.sbatch
```

- **Cores.** The pipeline uses the job's allocation (`--cpus-per-task`), not
  all cores of the node (`parallelly::availableCores()`, in
  `worker_count()` in `engine/workers/worker_setup.R`),
  and starts (cores - 1) / 4 workers, rounded down: one core is for the
  pipeline itself. So ask for 4 × workers + 1: 33 cores give 8 workers,
  where 32 would give 7 and leave 3 idle.
- **Memory.** Not measured yet for a full run. Bayes factor fits no longer
  keep per-observation draws, so a worker needs well under a gigabyte for
  most batches; 2 GB per core is a safe start. After the first job,
  `sacct -j <job id> --format=MaxRSS,Elapsed` shows what it used.
- **Time.** The run-time estimate gives the core hours; divided by the cores,
  that is the wall time, longer than most clusters allow for one job. When a
  job reaches its limit, submit the same script again: the pipeline
  continues where it was. It refuses to continue with another flatcor than
  the run started with (the image fixes flatcor, so this only happens with a
  new `.sif`), and `VALIDATION_FRESH=1` (as `apptainer exec --env
  VALIDATION_FRESH=1 ...`) starts from scratch.
- **Afterwards.** The results are in the project's `results/studies/` (one
  file per study) and `results/per_dataset/`. Copy them back and commit them; the
  docs read them from there.

A SLURM array script was here until 17 November 2026 (in the git history);
one job on one node replaces it.

## On AWS

[`aws/user-data.sh`](aws/user-data.sh) runs the validation on one EC2 spot
instance (Amazon Linux 2023), given to it as user data with eight values
filled in: the S3 bucket, a name for the run, smoke test or not, where to
download the code from and which commit of it (or a branch), the project,
the studies, and a safety cutoff in hours; the script itself names no
repository and no branch, and a value left unfilled stops it at once,
saying which. It installs Docker, downloads the code at that commit,
runs `run_all.R` in the published image (only the simulation), copies the
results and logs to `s3://<bucket>/<run name>/`, and shuts down. Launched
with shutdown behaviour
"terminate", the instance then deletes itself.

AWS can take a spot instance back at any moment, its disk included. A real
run therefore copies the pipeline's store to `s3://<bucket>/<run name>/store`
every 15 minutes, and a new instance launched with the same run name first
copies it back and continues from there. An interruption costs at most 15
minutes of work.

[`aws/keep_running.sh`](aws/keep_running.sh), run in the background on your
own computer, launches that new instance: every 2 minutes it checks the
run's instance, and when it is gone and the run's log in S3 does not say
the run finished, it launches the fleet again (at most 12 times). When the
log says `run_all.R` stopped on an error in the code (status 1, "Execution
halted"), it stops instead and shows the end of the log, since a new
instance would stop on the same error.

The instance needs a role that may read and write the bucket. With 32 cores
the pipeline runs 7 workers.
