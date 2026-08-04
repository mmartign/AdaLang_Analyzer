# CubedOS comparison benchmark

This benchmark compares AdaLang Analyzer's `--verify` bounded-scalar proof
obligations against GNATprove's `--mode=prove` results, per obligation (same
file, line, and check kind), on a pinned revision of
[cubesatlab/cubedos](https://github.com/cubesatlab/cubedos) — a SPARK/Ada
flight-software message-passing framework for CubeSat spacecraft.

Unlike `benchmarks/sparknacl/`, **CubedOS is not a fully-proved corpus.**
GNATprove's own `--mode=prove --level=4` run on unmodified `cubedos.gpr`
reports real, currently-unresolved `medium`/`high` findings (tasking data
races on a shared `Message_Manager.Mailboxes` state, uninitialized `out`
parameters, unproved range/precondition checks). That means GNATprove is not
a trustworthy oracle here the way it is for SPARKNaCl, and this benchmark's
value is different: it is a second, structurally distinct real SPARK corpus
(message-passing and XDR marshalling, rather than SPARKNaCl's cryptographic
arithmetic) to diversify the obligation shapes `--verify` is exercised
against, not a repeat of SPARKNaCl's "does AdaLang ever disagree with a
fully-proved oracle" question.

**This run also surfaced a new, currently open analyzer limitation, `FP-040`
(see `quality/known_analysis_issues.tsv`).** `--verify`'s proof-obligation
finalization pass hits Libadalang's own `Property_Error` ("undetermined
CallExpr kind", occasionally "dereferencing a null access") on 21 of
CubedOS's 49 analyzed files, falling back conservatively per file. This is
not FP-029 (which needs `gnatls` missing from `PATH` to trigger, and has a
different error signature) — `gnatls` was present throughout this run. The
practical effect: `--verify`'s reported obligation count (44, project-wide)
is a real undercount, not a representative sample, so the comparison numbers
below should be read as "what limited signal is available at this revision,"
not as a coverage measurement of `--verify` against CubedOS's actual proof
surface.

## Pinned source

- cubesatlab/cubedos: `c402301000a5a92237e0f7ab106186a48273cf24`

Clone the corpus from the AdaLang Analyzer repository root:

```sh
git clone https://github.com/cubesatlab/cubedos.git \
  /private/tmp/adalang-cubedos-benchmark
git -C /private/tmp/adalang-cubedos-benchmark checkout \
  c402301000a5a92237e0f7ab106186a48273cf24
```

No submodule checkout is needed: `ADL` (Ada_Drivers_Library) is only used by
the hardware-specific sample projects under `samples/`, not by
`src/cubedos.gpr`, which this benchmark analyzes unmodified.

## AUnit dependency

Unlike SPARKNaCl, CubedOS's own `src/cubedos.gpr` `with`s `aunit.gpr` (its
`check/` subtree is an AUnit test suite exercising the core library). Rather
than modify the pinned corpus or add `aunit` to this repository's own
`alire.toml` as a permanent dependency, `run.sh` resolves it through a
throwaway local Alire crate it creates under the results directory
(`benchmark-results/cubedos/aunit_provider/`), and adds that crate's
resolved `GPR_PROJECT_PATH` entry to the environment before analysis. This
step runs in a plain, not-yet-`alr exec`'d shell, before `run.sh` re-execs
itself into this repository's own Alire environment for its GNAT toolchain
(`gnatls`, needed for the same `FP-029` reason `benchmarks/sparknacl/`
documents) — `alr` refuses to nest two different toolchain pins in one
process, so the two steps cannot be combined.

Run the benchmark:

```sh
CUBEDOS_ROOT=/private/tmp/adalang-cubedos-benchmark sh benchmarks/cubedos/run.sh
```

`run.sh` verifies the pinned revision, then runs:

- AdaLang `--verify` against `cubedos.gpr`, `--format=json`;
- GNATprove `--mode=prove --output=oneline` against the same project.
  `cubedos.gpr` declares an empty `package Prove` (no pinned level/prover/
  timeout, unlike SPARKNaCl's own tuned settings), so this benchmark picks
  `--level=4 --prover=z3,cvc5,altergo --timeout=60` explicitly, matching
  SPARKNaCl's configuration for methodological consistency across both
  corpora rather than reusing an unset default;
- `compare.awk` (identical to `benchmarks/sparknacl/compare.awk`) over both
  outputs, writing `comparison.txt` to the results directory (default
  `benchmark-results/cubedos/`, override with `RESULTS_DIR`).

## Matching design

Same as `benchmarks/sparknacl/`: obligations are matched by
`(basename(file), line, normalized check kind)`, count-mismatched locations
are reported separately rather than guessed, and `compare.awk`'s five
per-pair buckets and two coverage-only counts have the same meaning. See
`benchmarks/sparknacl/README.md` for the full design description.

One difference in interpretation: because CubedOS is not fully proved,
bucket 5 ("both flag a problem") is an *expected* outcome here, not a red
flag the way it would be on SPARKNaCl — it just means both tools agree the
location is unresolved, which is the honest state of the code.

## Caveats

- **FP-040 dominates this revision's numbers** (see above); re-run after any
  fix to get a comparison that reflects `--verify`'s real proof-obligation
  coverage on this corpus.
- GNATprove version, solver versions, and exact message wording are recorded
  in each dated `RESULTS_*.md` for reproducibility.
- The AUnit-resolution step depends on Alire's `aunit` crate remaining
  resolvable at `aunit = "*"`; if that ever breaks, pin an explicit version
  in the throwaway crate's `alire.toml` template in `run.sh`.

See the latest `RESULTS_*.md` in this directory for recorded runs.
