#!/bin/sh
## =====================================================================
##  What the smoke test of this push runs (the smoke job, check.yml)
##
##  It compares this commit with the last one on the same branch that
##  passed the Check workflow, and prints one line per project to test:
##    project_1_validation           the whole project
##    project_1_validation 1a 3b     only these studies (and what uses them:
##                                   ci/smoke_studies.R adds that)
##  Nothing printed: nothing the pipeline reads changed.
##
##  What a changed file sets off:
##    project_X/studies/<code>_*/...   that study of project X
##    any other file in project_X/     all of project X (shared/, settings/, ...)
##    any file outside project_*/      every project (engine/, _targets.R,
##                                     run_all.R, renv.lock, ci/, cluster/, ...)
##  Never: each project's docs/, every .md file, .github/, cluster/aws/,
##  .lintr (the files the pipeline never reads). No passed Check run on the
##  branch, or its commit not in this clone: every project.
##
##  ci/smoke_selection.sh              compare with the last passed Check run
##  ci/smoke_selection.sh <commit>     compare with that commit (to try it out)
##  Needs GH_TOKEN, GITHUB_REPOSITORY and GITHUB_REF_NAME (set in Actions),
##  unless a commit is given.
## =====================================================================
set -e

every_project() {
  for project in project_*/; do echo "${project%/}"; done
}

base=$1
if [ -z "$base" ]; then
  base=$(gh run list -R "$GITHUB_REPOSITORY" --workflow check.yml \
    --branch "$GITHUB_REF_NAME" --status success --limit 1 \
    --json headSha -q '.[0].headSha // empty')
fi
if [ -z "$base" ] || ! git cat-file -e "$base^{commit}" 2>/dev/null; then
  echo "No passed Check run on this branch to compare with: every project" >&2
  every_project
  exit 0
fi
echo "Compared with $base, the last commit that passed the Check workflow" >&2

# what a changed file sets off: "shared", "<project>" or "<project>/<study code>"
kind_of_change() {
  project=${1%%/*}
  case "$1" in
    project_*/studies/*/*)
      folder=${1#"$project"/studies/}
      folder=${folder%%/*}
      # a study folder that is gone: test the whole project
      if [ -d "$project/studies/$folder" ]; then
        echo "$project/${folder%%_*}"
      else
        echo "$project"
      fi
      ;;
    project_*/*) echo "$project" ;;
    *) echo "shared" ;;
  esac
}

changes=$(
  git diff --name-only "$base" HEAD -- . ':!project_*/docs' ':!*.md' ':!.github' \
    ':!cluster/aws' ':!.lintr' |
    while read -r file; do kind_of_change "$file"; done | sort -u
)

if echo "$changes" | grep -qx "shared"; then
  every_project
  exit 0
fi
for project in $(every_project); do
  if echo "$changes" | grep -qx "$project"; then
    echo "$project"
  else
    studies=$(echo "$changes" | grep "^$project/" | sed "s|^$project/||" | tr '\n' ' ')
    if [ -n "$studies" ]; then echo "$project ${studies% }"; fi
  fi
done
