# The environment for running the package and its validation anywhere:
# the same R, the same packages (renv.lock) and the same CmdStan.
#
# The image holds only the environment; the project folder is mounted when
# the container runs, so results are written straight into it.
#
# GitHub Actions builds, smoke-tests and publishes this image as
# ghcr.io/dm-k1/flatcor-validation (.github/workflows/image.yml;
# cluster/README.md). To build it yourself (20-40
# minutes: packages and CmdStan compile from source):
#   docker build -f cluster/Dockerfile -t flatcor-validation .
# (from the project folder; Docker reads cluster/Dockerfile.dockerignore
# next to this file, which needs BuildKit, the default since Docker 23)
# Run every study, or a selection (see run_all.R):
#   docker run --rm -v "$PWD":/project flatcor-validation
#   docker run --rm -v "$PWD":/project flatcor-validation Rscript run_all.R 1a

# R version as recorded in renv.lock
FROM rocker/r-ver:4.6.1

# System libraries that the R packages compile against (networking; ICU for
# stringi; libuv for fs; GMP and MPFR for Rmpfr; libxml2 for igraph; zlib for
# data.table, whose fwrite writes the .csv.gz files, and pkg-config, through
# which data.table's configure finds zlib: without either, data.table
# compiles without compression and the run stops; the list
# follows the SystemRequirements of the packages in renv.lock) and git (each
# results file records the commit). The image only runs the simulations:
# nothing for figures or a notebook (graphics, fonts, V8, ZeroMQ), which live
# in another repository (a separate private repository).
RUN apt-get update && apt-get install -y --no-install-recommends \
      git curl make cmake g++ \
      libcurl4-openssl-dev libssl-dev libxml2-dev libicu-dev libuv1-dev \
      libgmp-dev libmpfr-dev zlib1g-dev pkg-config \
    && rm -rf /var/lib/apt/lists/*

# CmdStan, the version the validation was last run with, from its release
# (what cmdstanr::install_cmdstan() does too). Before the R packages: it
# needs only the compilers, so a change to renv.lock does not rebuild it.
ENV CMDSTAN_VERSION=2.40.0
RUN mkdir -p /opt/cmdstan \
 && curl -fsSL "https://github.com/stan-dev/cmdstan/releases/download/v${CMDSTAN_VERSION}/cmdstan-${CMDSTAN_VERSION}.tar.gz" \
      | tar -xz -C /opt/cmdstan \
 && make -C /opt/cmdstan/cmdstan-${CMDSTAN_VERSION} build -j"$(nproc)"
ENV CMDSTAN=/opt/cmdstan/cmdstan-${CMDSTAN_VERSION}

# BridgeStan's sources, the version of the bridgestan R package in renv.lock:
# flatcor builds its log density for the Bayes factors with them
# (flatcor_density()). A tiny model is compiled once here, so that BridgeStan's
# own first build (its stanc and bridge code) is in the image and a run needs
# no network for it.
ENV BRIDGESTAN_VERSION=2.9.0
RUN mkdir -p /opt/bridgestan \
 && curl -fsSL "https://github.com/roualdes/bridgestan/releases/download/v${BRIDGESTAN_VERSION}/bridgestan-${BRIDGESTAN_VERSION}.tar.gz" \
      | tar -xz -C /opt/bridgestan \
 && printf 'parameters { real x; }\nmodel { x ~ std_normal(); }\n' > /tmp/first.stan \
 && make -C /opt/bridgestan/bridgestan-${BRIDGESTAN_VERSION} /tmp/first_model.so \
 && rm -f /tmp/first*
ENV BRIDGESTAN=/opt/bridgestan/bridgestan-${BRIDGESTAN_VERSION}

# R packages at the versions in renv.lock, into the image's site library.
# The CRAN packages come ready-built for this Ubuntu from Posit's package
# manager (the same versions, older ones included, compiled by Posit: a
# minute instead of six, and with every feature their system libraries
# allow); cmdstanr comes from the Stan r-universe, SBC and bridgestan from
# R-multiverse, flatcor from GitHub, all built here. flatcor goes last, on
# its own: renv installs in parallel and cannot see a GitHub package's
# dependencies before downloading it, so it once started flatcor before
# them (run 44966708649).
COPY renv.lock /tmp/renv.lock
ARG PACKAGE_REPOS='c(CRAN = "https://p3m.dev/cran/__linux__/noble/latest", RMultiverse = "https://r-multiverse.r-universe.dev")'
RUN Rscript -e 'install.packages("renv", repos = "https://cloud.r-project.org")' \
 && Rscript -e 'renv::restore(lockfile = "/tmp/renv.lock", library = .libPaths()[1], prompt = FALSE, exclude = "flatcor", repos = eval(str2lang(Sys.getenv("PACKAGE_REPOS"))))' \
 && Rscript -e 'renv::restore(lockfile = "/tmp/renv.lock", library = .libPaths()[1], prompt = FALSE, packages = "flatcor", repos = eval(str2lang(Sys.getenv("PACKAGE_REPOS"))))'

# A check right away, so a broken package fails the build here, minutes in,
# not in the smoke test: every package in renv.lock loads (a ready-built
# package missing a system library fails to load), and data.table writes a
# compressed file (it builds without compression when it cannot find zlib)
RUN Rscript -e 'for (p in names(jsonlite::read_json("/tmp/renv.lock")$Packages)) loadNamespace(p)' \
 && Rscript -e 'data.table::fwrite(data.frame(x = 1), tempfile(fileext = ".csv.gz"))'

# git refuses to read a mounted repository owned by another user unless told
RUN git config --system --add safe.directory /project

WORKDIR /project
CMD ["Rscript", "run_all.R"]
