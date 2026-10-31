# Tokeneer comparison benchmark

This benchmark compares AdaLang Analyzer's `--verify` bounded-scalar proof
obligations against GNATprove's `--mode=prove` results, per obligation
(same file, line, and check kind), on a pinned revision of the SPARK 2014
port of the NSA-released Tokeneer ID Station, part of the
[AdaCore/spark2014](https://github.com/AdaCore/spark2014) test suite
(`testsuite/gnatprove/tests/tokeneer`) — AdaCore describes it as fully
verified with SPARK 2014, and an empty-of-findings default-report-level
GNATprove run against the pinned revision (see below) confirms it: no
failed checks, only advisory `info`/`warning` messages unrelated to proof
outcomes.

As with every benchmark here, this is not an equivalence claim: AdaLang's
bounded mode uses CFG fixed-point abstract interpretation over a narrower
scalar subset, not GNATprove's verification-condition/prover pipeline (see
`docs/src/positioning.md`).

## Pinned source

- AdaCore/spark2014: `a97467e91a16409c866434fcc7a5f553bbd98b8a`

The full `spark2014` repository is large; a sparse checkout of just the
Tokeneer subdirectory is enough:

```sh
git clone --filter=blob:none --no-checkout \
  https://github.com/AdaCore/spark2014.git \
  /private/tmp/adalang-tokeneer-benchmark
cd /private/tmp/adalang-tokeneer-benchmark
git sparse-checkout init --cone
git sparse-checkout set testsuite/gnatprove/tests/tokeneer
git checkout a97467e91a16409c866434fcc7a5f553bbd98b8a
```

No separate build/setup step is needed: `test.gpr` is a self-contained
project with no external `with` dependencies. GNATprove is resolved the
same way `benchmarks/sparknacl/run.sh` resolves it (`GNATPROVE` env var,
then `PATH`, then `~/.alire/bin/gnatprove`).

`run.sh` re-execs itself under this repository's own `alr exec`, for the
same `gnatls`-on-`PATH` / `FP-029` reason documented in
`benchmarks/sparknacl/README.md`.

Run the benchmark:

```sh
TOKENEER_ROOT=/private/tmp/adalang-tokeneer-benchmark sh benchmarks/tokeneer/run.sh
```

`run.sh` verifies the pinned revision, then runs:

- AdaLang `--verify` against `test.gpr`, `--format=json`;
- GNATprove `--mode=prove --output=oneline` against the same project, using
  `test.gpr`'s own `Prove` package switches (`--function-sandboxing=off`,
  `--proof-warnings=on`, `--level=2`) plus `--report=statistics` added on
  the command line — `test.gpr` sets no `--report` switch of its own, which
  leaves GNATprove's default of reporting only failed checks: confirmed
  empirically on this pinned revision, 31 messages total (14 advisory
  `info` notices about inlining/unconstrained-return contextual analysis,
  the rest `unreachable branch` warnings — zero pass/fail proof-result
  lines at all) without `--report=statistics`, versus thousands of `info:
  ... proved` lines with it. The same gap `benchmarks/saatana/` and
  `benchmarks/coap_spark/` hit and fixed the same way;
- `benchmarks/compare.awk` over both outputs, writing `comparison.txt` to the results
  directory (default `benchmark-results/tokeneer/`, override with
  `RESULTS_DIR`).

## Matching design

Identical to `benchmarks/sparknacl/README.md`'s "Matching design" section:
AdaLang's `--verify --format=json` obligations and GNATprove's
`--output=oneline` messages are matched by `(basename(file), line,
normalized check kind)`, not auto-paired when either side has more than one
obligation in the same bucket, and sorted into the same five per-pair
buckets (both safe / AdaLang conservative / possible AdaLang unsoundness /
AdaLang false positive / both flag a problem) plus the two coverage-only
counts. See that file for the full description.

## Caveats

- Same GNATprove message-text substring matching caveat as every other
  benchmark here: a heuristic against observed wording, not a stable
  GNATprove API.
- GNATprove version, solver versions, and exact message wording are
  recorded in each dated `RESULTS_*.md` for reproducibility.

See the latest `RESULTS_*.md` in this directory for recorded runs.
