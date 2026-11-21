# How these results were made

The record of the real run behind the files in this folder: which run made
each file, with what software, on which machine, and what happened on the
way. What the studies test and why is in
[`docs/validation_tests.md`](../docs/validation_tests.md). The results of v1,
reported in the paper, are at tag
[`v1-results`](https://github.com/dm-k1/flatcor-validation/tree/v1-results);
how they were made is in that tag's copy of this file.

## The files

Every file here comes from one run, **v2-real-2** (commit 094e95e, flatcor
a0d2ac9, root seed 0, not a smoke test), 21 November 2026:

| Files | Made by |
|---|---|
| `studies/study_*.rds` (all six studies) | the pipeline (`run_all.R`) |
| `per_dataset/` (one or more files per study, see its README; the `_variables` and `_chains` files are attached to the release of tag `v2-results`) | the pipeline, as each study's last step before its metrics |
| `figures/*.png` (all nine) | `make_figures.R` from the results files, at the end of the same run |

Each results file records its own commit, flatcor commit, R and CmdStan
versions, root seed and finishing time (`readRDS(file)$setup`).

## Software

The machine ran the container image
`ghcr.io/dm-k1/flatcor-validation:env-c4893495cf21`, the image of this
commit's environment (`cluster/image_tag.sh`: a fingerprint of
`cluster/Dockerfile`, `cluster/Dockerfile.dockerignore` and `renv.lock`),
built by `.github/workflows/image.yml`.

| | Version |
|---|---|
| R | 4.6.1 |
| CmdStan | 2.40.0 (cmdstanr 0.9.0) |
| flatcor | 2.2.0.9000, commit a0d2ac9 |
| bridgestan | 2.9.0 |
| bridgesampling | 1.2-1 |
| BayesFactor | 0.9.12-4.8 |
| SBC | 0.5.0.0 |
| targets / crew / mirai | 1.12.0 / 1.3.3 / 2.7.4 |
| posterior | 1.7.0 |
| dplyr / data.table | 1.2.1 / 1.18.6.1 |
| everything else | `renv.lock` |

Every worker uses one BLAS thread (`_targets.R`).

## The run

**v2-real-2** (all studies; commit 094e95e), 21 November 2026, 15:42–19:00
UTC, about 3.3 hours. On one spot m7a.48xlarge in Stockholm (AWS EC2, Amazon
Linux 2023; AMD EPYC Zen 4, 192 cores), with `Rscript run_all.R` inside the
image (`cluster/aws/user-data.sh`). Every piece of work runs Stan's 4 chains;
the machine ran (192 − 1) / 4 = 47 pieces at once. The store of finished
pieces was copied to S3 every 15 minutes; AWS did not take the machine back,
so nothing was computed twice.

The run went in rounds (core hours so far, budget 2,500):

- Round 1: 250.9.
- Round 2: 550.9, for the cells short of their targets in 2b, 3a, 3a's
  repeated runs, 3b's rates and 3b with growing *k*.
- Round 3: 553.5 (2b, 3a, 3b growing *k*).
- Round 4: 553.7 (2b). After it every cell had reached its targets.

553.7 core hours in all (a piece's duration × 4 cores). An earlier attempt
the same day (v2-real, commit de6f1ec) stopped after ten minutes with a full
disk: flatcor kept every fit's CSV files until the worker ended; flatcor
a0d2ac9 deletes them once read. None of its pieces is used here.

**Compared with v1.** The rules for how many datasets are the same as v1's
(467b18d), and with root seed 0 every dataset and every Stan seed is the
same as in v1. v2 made exactly v1's datasets in every study (the same rows
in `per_dataset/`). Of the log Bayes factors of 3b, all but 8 of 11,100
(growing *k*) and 85 of 5,170 (rates) agree with v1's to within 10⁻⁶; the
largest difference is 0.015, at most 2.3 times bridge sampling's reported
error for that dataset (about 0.006). v2 computes bridge sampling's log
densities through BridgeStan.

## How much

| Study | Datasets | Stan fits (flatcor) | Other Bayesian computations |
|---|---|---|---|
| 1a | — (the prior only) | 9 | — |
| 1b | 150 | 1,500 | — |
| 2a | 786 | 786 | — |
| 2b | 13,700 | 41,100 | 27,400 (JZS, Zellner–Siow) |
| 3a part A | 1,250 | 2,500 | — |
| 3a part B | 560 (5 runs each) | 5,600 | — |
| 3b.1, 3b.2 | 21 | 42 | — |
| 3b rates | 5,170 | 10,340 | — |
| 3b growing *k* | 11,040 | 18,080 | about 4,000 (JZS, Zellner–Siow) |
| **total** | **about 32,700** | **about 80,000** | **about 31,000** |

A Bayes factor is two Stan fits and bridge sampling: about 21,000 in all.

## Reproducing

The same commit on the same family of processor gives identical tables (in a
test of a multi-machine setup, a smoke run on one machine and on several gave
the same 32 tables). Across processor families, Stan's floating-point
arithmetic can differ in the last digits, and a sampler carries that into
different draws. An earlier run of 1a–2b in a GitHub codespace (AMD Zen 3,
commit b75a082, not part of these results) gave an identical 1a, and for 1b,
2a and 2b the same conclusions, with numbers that differ within their Monte
Carlo error.
