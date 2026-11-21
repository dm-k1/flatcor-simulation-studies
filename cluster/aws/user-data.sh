#!/bin/bash
## =====================================================================
##  A project's run on one AWS EC2 instance (Amazon Linux 2023), as user data
##
##  Runs the project in the published image, copies the log and the
##  results to S3, and shuts the instance down; launched with shutdown
##  behaviour "terminate", it then deletes itself. A safety cutoff shuts
##  it down after MAX_HOURS whatever happens. cluster/README.md, "On AWS".
##
##  A spot instance can be taken back by AWS at any moment, and its disk
##  with it. So a real run copies the pipeline's store (every finished
##  piece) to S3 every 15 minutes, and starts by copying back what an
##  earlier instance with the same RUN_NAME left there: launched again
##  after an interruption, it continues where that one was, losing at most
##  15 minutes of work. (The smoke test always starts from scratch.)
##
##  Set per run (the launch command fills them in; a value left as
##  __NAME__ stops the run before anything else, saying which):
##    BUCKET      the S3 bucket for the log and the results
##    RUN_NAME    a folder in the bucket for this run
##    SMOKE       1 for the smoke test, 0 for a real run
##    REPOSITORY  where to download the code from (a git address, as
##                https://github.com/dm-k1/flatcor-validation.git)
##    CHECKOUT    which version of it to run: a commit (or a branch); every
##                machine of a run should run the same commit, so pin one
##    PROJECT     the project folder to run, as project_1_validation
##    STUDIES     the studies to run ("" for all), as for run_all.R
##    MAX_HOURS   the safety cutoff
## =====================================================================
BUCKET="__BUCKET__"
RUN_NAME="__RUN_NAME__"
SMOKE="__SMOKE__"
REPOSITORY="__REPOSITORY__"
CHECKOUT="__CHECKOUT__"
PROJECT="__PROJECT__"
STUDIES="__STUDIES__"
MAX_HOURS="__MAX_HOURS__"

LOG=/var/log/flatcor-run.log
exec > "$LOG" 2>&1
set -x

## every value filled in, or stop here (cluster/aws/keep_running.sh then
## stops too, instead of launching new machines that would stop the same way)
unfilled=""
for name in BUCKET RUN_NAME SMOKE REPOSITORY CHECKOUT PROJECT STUDIES MAX_HOURS; do
  case "${!name}" in __*__) unfilled="$unfilled $name" ;; esac
done
if [ -n "$unfilled" ]; then
  echo "User data not filled in:$unfilled"
  case "$BUCKET" in __*__) ;; *) aws s3 cp "$LOG" "s3://$BUCKET/$RUN_NAME/run.log" --only-show-errors ;; esac
  shutdown -h now
  exit 1
fi

## the safety cutoff, first of all
shutdown -h "+$((MAX_HOURS * 60))"

## whatever happens below: copy the log and the results to S3, then shut down
finish() {
  cd /opt/flatcor-validation 2>/dev/null || true
  results="$PROJECT/results"
  [ "$SMOKE" = "1" ] && results="cache/$PROJECT/smoke_results"
  [ "$SMOKE" = "1" ] || backup_store
  aws s3 sync "$results" "s3://$BUCKET/$RUN_NAME/results" --only-show-errors || true
  aws s3 sync cache/logs "s3://$BUCKET/$RUN_NAME/logs" --only-show-errors || true
  aws s3 cp "$LOG" "s3://$BUCKET/$RUN_NAME/run.log" --only-show-errors || true
  shutdown -h now
}
trap finish EXIT

## the store to S3 (targets writes each piece to a temporary file first and
## then moves it in place, so a copy never holds half a piece)
backup_store() {
  aws s3 sync "_targets/$PROJECT" "s3://$BUCKET/$RUN_NAME/store" \
    --exclude "scratch/*" --only-show-errors || true
}

## Docker, git and the code, from where the launch says, at the version it says
dnf install -y docker git
systemctl start docker
git clone "$REPOSITORY" /opt/flatcor-validation || { echo "Cannot download the code from $REPOSITORY"; exit 1; }
cd /opt/flatcor-validation || exit 1
git checkout --quiet "$CHECKOUT" || { echo "No such commit or branch: $CHECKOUT"; exit 1; }
git log --oneline -1
[ -d "$PROJECT" ] || { echo "No project folder $PROJECT at $CHECKOUT"; exit 1; }

## the image built for this checkout's environment (cluster/image_tag.sh); a
## commit whose environment has no published image stops here
IMAGE="ghcr.io/dm-k1/flatcor-validation:$(cluster/image_tag.sh)"
docker pull "$IMAGE" || { echo "No image for this environment: $IMAGE"; exit 1; }

## a real run: first what an earlier instance of this run left, then a copy
## every 15 minutes while it runs
if [ "$SMOKE" != "1" ]; then
  aws s3 sync "s3://$BUCKET/$RUN_NAME/store" "_targets/$PROJECT" --only-show-errors
  ls "_targets/$PROJECT/meta" 2>/dev/null && echo "continuing from the store in S3"
  while true; do sleep 900; backup_store; done &
fi

## the run
echo "cores: $(nproc)"
# shellcheck disable=SC2086  # STUDIES is a list of words on purpose
docker run --rm -v "$PWD":/project -e VALIDATION_SMOKE="$SMOKE" "$IMAGE" Rscript run_all.R "$PROJECT" $STUDIES
echo "run_all.R exited with status $?"
