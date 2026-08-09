# gnatcoll-core benchmark

This benchmark runs AdaLang Analyzer's `--recommended`, `--spark`, and
`--verify` presets against a pinned
[AdaCore/gnatcoll-core](https://github.com/AdaCore/gnatcoll-core) (GPL-3.0-
or-later WITH GCC-exception-3.1, actively maintained): the GNAT Components
Collection's core module, `core/gnatcoll_core.gpr` plus its
`minimal/gnatcoll_minimal.gpr` dependency (235 files, ~64,300 lines).
Deliberately a different domain from every prior corpus here: a
general-purpose utility library (JSON, VFS/paths, string builders, email
parsing, process/OS wrappers, config parsing), not a cryptographic
primitive, a protocol parser, a message bus, or a hardware driver tree.
Like `benchmarks/aws/`, this is real-code validation, not a GNATprove
oracle comparison: `gnatcoll-core` sets `SPARK_Mode` nowhere in its own
sources, so there is no independently-verified ground truth to compare
against, and (as recorded below) GNATprove itself does not get past flow
analysis on the unmodified project.

## Pinned source

- AdaCore/gnatcoll-core: `9f6ffb394793b0ac098fb1e9b206a659680788b3`

Clone the corpus from the AdaLang Analyzer repository root:

```sh
git clone https://github.com/AdaCore/gnatcoll-core.git \
  /private/tmp/adalang-gnatcoll-benchmark
git -C /private/tmp/adalang-gnatcoll-benchmark checkout \
  9f6ffb394793b0ac098fb1e9b206a659680788b3
```

No separate setup/build step is required beyond what `run.sh` itself does:
unlike `benchmarks/aws/`, `gnatcoll_core.gpr`'s own dependency
(`gnatcoll_minimal.gpr`) is checked into the same repository, generated
config projects (`core/config/gnatcoll_core_constants.gpr`,
`minimal/config/gnatcoll_minimal_constants.gpr`) are already committed, and
no Alire-published dependency needs to be resolved first.

Run the benchmark:

```sh
GNATCOLL_ROOT=/private/tmp/adalang-gnatcoll-benchmark \
  sh benchmarks/gnatcoll/run.sh
```

On a non-Darwin host, set `GNATCOLL_OS` to the value gnatcoll-core's own
`gnatcoll.gpr` expects (for example `unix`); `run.sh` defaults it from
`uname -s`. Unlike `benchmarks/aws/`, no derived/excluded diagnostic
project is needed here: the boundary GNATprove hits is reported directly
by the unmodified project.

## Why `GPR_PROJECT_PATH` is set explicitly

`gnatcoll_core.gpr` writes `with "gnatcoll_minimal.gpr";` with no directory
prefix, so it resolves through project-path search rather than a relative
path. This repository's own Alire environment already depends on a
released `gnatcoll` crate (it sits underneath Libadalang in the dependency
graph), so an installed `gnatcoll_minimal.gpr` is already on
`GPR_PROJECT_PATH` by the time `run.sh` executes under `alr exec`. Without
taking care of this, the pinned checkout's `core/gnatcoll_core.gpr` could
silently resolve against that *different*, already-installed `minimal`
project instead of the pinned revision's own -- `run.sh` prepends the
pinned checkout's own `minimal/` and `minimal/config/` directories to
`GPR_PROJECT_PATH` before invoking either tool, so the pinned sources are
what is actually analyzed and built.

`run.sh` verifies the pinned revision, builds the project with `gprbuild`
(confirming it is genuinely buildable, ordinary Ada -- not a claim this
benchmark otherwise depends on, since AdaLang only has to parse and check
the sources, the same as every other benchmark here), then runs:

- AdaLang `--recommended`, `--spark`, and `--verify` against
  `core/gnatcoll_core.gpr`;
- GNATprove `--mode=flow` against the same project (best-effort: skipped,
  not failed, if no `gnatprove` executable is found);
- machine-readable JSON summaries and POSIX timing files, written to
  `benchmark-results/gnatcoll/` (override with `RESULTS_DIR`).

See [RESULTS_2026-08-09.md](RESULTS_2026-08-09.md) for the first recorded
run.
