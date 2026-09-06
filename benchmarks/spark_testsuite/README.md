# SPARK testsuite comparison benchmark

This benchmark compares AdaLang Analyzer's `--verify` bounded-scalar proof
obligations against GNATprove's `--mode=prove` results, per obligation (same
file, line, and check kind), over a **curated subset of the AdaCore SPARK
testsuite** — the `testsuite/gnatprove/tests/` tree of
[AdaCore/spark2014](https://github.com/AdaCore/spark2014), pinned to the
`fsf-16` branch that matches this benchmark suite's GNATprove (FSF 16.1.0).

Unlike the single-project oracle corpora (`benchmarks/sparknacl/`,
`benchmarks/libkeccak/`, …), the SPARK testsuite is ~4,200 tiny,
single-purpose regression tests rather than one coherent codebase. Its value
here is **construct diversity**: 124 hand-picked units spread across scalar
range, overflow, index, division, length, discriminant, initialization,
loop-invariant and loop-variant obligations — far more distinct shapes than
six real projects reach — not another large matched-pair count. Most units
leave AdaLang's bounded verifier at `Unproved`/`Unsupported`; the property
this corpus tests is that across that wide spread it never disagrees with
GNATprove on safety.

## Why a subset, and why a per-test loop

A bulk import does not fit the existing benchmark machinery:

- **`compare.awk` matches on `(basename(file), line, kind)`**, not full path.
  The testsuite reuses filenames (`main.adb`, `p.ads`, `test.adb`) across
  thousands of directories; matched globally they collide. Run per test
  directory, basenames are unique again and the shared comparator is used
  **unchanged**, with no source edits.
- **AdaLang analyzes one project's own `Source_Dirs`**; the testsuite has one
  (generated) project per test directory.
- **The testsuite is heterogeneous.** `*__flow*` tests target flow analysis,
  `ug__*` tests run a fixed command, many `test.py` tests carry custom logic,
  and a large fraction deliberately expect `medium`/`high` results. Only the
  slice that exercises `--verify`'s actual obligation surface is useful as an
  oracle.

`run.sh` therefore loops `MANIFEST.tsv`: for each unit it reconstructs the
testsuite's own default project, runs both tools, and runs `compare.awk`
once; `aggregate.awk` then sums the buckets across all units.

## The two manifest classes

| class | meaning | what a disagreement means |
| --- | --- | --- |
| `clean` (90) | GNATprove's committed `test.out` proves **every** check | full oracle: an AdaLang `definite-error` here is a false positive; an AdaLang `proved-safe` GNATprove could not prove is possible unsoundness |
| `weak` (34) | `test.out` carries a deliberate `medium`/`high` of a **scalar** kind | unsoundness tripwire: AdaLang must never report `proved-safe` at a location GNATprove flags `medium`/`high` |

## Selection criteria

`select_candidates.py` then `pick_manifest.py` (both in this directory, run
against `SPARK2014_ROOT/testsuite/gnatprove/tests`) produce `MANIFEST.tsv`.
Selection is by **obligation kind**, read from each unit's own sources and
its committed `test.out` — never from how AdaLang scores it, so the oracle
value is not curated away.

Excluded: `*__flow*`; `ug__*`; any dir with `test.py`, its own `.gpr`, a
`proof/` session dir, or no `test.out`; `test.yaml` carrying `large`,
`replay`, `session_opt`, `contains_manual_proof`, `sparklib`, `do_flow` or
`codepeer`; baselines containing a compile/legality `error:`; units that
`with` a heavy library unit whose obligations AdaLang cannot model (formal
containers, big numbers, bounded/unbounded strings, `Ada.Numerics`);
baselines with no scalar obligation at all or dominated by out-of-scope
checks (pointers, tasking, termination); and a handful over 12 source files
or 900 lines.

Kept units are then ranked for kind diversity and small size, capped per
kind-signature, and split `clean` / `weak`.

## Pinned source

- AdaCore/spark2014: branch `fsf-16`, commit
  `42554fc241fcd1fdf08d3a2feccb3f86912acbc0` (see `SPARK2014_REVISION`).

The `fsf-16` branch is the one whose `test.out` baselines are maintained
against the FSF 16 GNATprove release this benchmark suite uses, so a unit
classified `clean` from its baseline is genuinely fully proved at this
toolchain. The baselines themselves are **not** consulted at run time —
`run.sh` compares live GNATprove against live AdaLang — they only drive the
`clean` / `weak` split during manifest curation.

Clone the corpus from the AdaLang Analyzer repository root:

```sh
git clone --branch fsf-16 --single-branch https://github.com/AdaCore/spark2014.git \
  /private/tmp/adalang-spark-testsuite-benchmark
git -C /private/tmp/adalang-spark-testsuite-benchmark checkout \
  42554fc241fcd1fdf08d3a2feccb3f86912acbc0
```

No build and no submodules are needed — the units are analyzed from source.

## Running

```sh
SPARK2014_ROOT=/private/tmp/adalang-spark-testsuite-benchmark \
  sh benchmarks/spark_testsuite/run.sh
```

`run.sh` re-execs itself under `alr exec` (for `gnatls` on `PATH` — the same
`FP-029` rationale as the other benchmarks), verifies the pinned revision,
then for every `MANIFEST.tsv` unit:

- copies the unit's `*.ad[bs]` (and its own `test.adc`, if any) into
  `benchmark-results/spark_testsuite/work/<unit>/`;
- writes `test.gpr` (and a default `test.adc` if the unit ships none) —
  reproduced **verbatim** from the testsuite's own
  `lib/python/test_support.py:generate_project_file`: `-gnatws -gnatdk
  -gnatd.k -gnat2022`, local configuration pragmas `SPARK_Mode (On)`,
  `Profile (Ravenscar)`, `Partition_Elaboration_Policy (Sequential)`;
- runs AdaLang `--verify -q --no-config --format=json`;
- runs GNATprove `--mode=prove -f -q --output=oneline --prover=z3,cvc5,altergo
  --steps=16000 --timeout=60 --report=statistics` (dropping the testsuite
  default's `colibri`, which is not in this toolchain's prover bundle —
  identical to `benchmarks/coap_spark/run.sh`);
- **scopes GNATprove's log to the unit's own source basenames** before
  comparison (see "Matching design");
- runs `compare.awk` → `benchmark-results/spark_testsuite/per-test/<unit>.txt`.

`aggregate.awk` sums the per-unit buckets, split by class, into
`comparison.txt`. `run.sh` exits non-zero if any unit shows possible
unsoundness or a false positive.

Override `RESULTS_DIR`, `ANALYZER`, `GNATPROVE`, or `MANIFEST` (to run a
subset) via the environment.

## Matching design

Same core as `benchmarks/sparknacl/`: obligations are matched by
`(basename(file), line, normalized check kind)`, count-mismatched locations
are reported separately rather than guessed, and `compare.awk`'s five
per-pair buckets and two coverage-only counts keep their meaning. See
`benchmarks/sparknacl/README.md` for the full description.

Two things are specific to this corpus:

- **Per-unit invocation.** `compare.awk` runs once per test directory, so its
  `basename` matching only ever sees one unit's (unique) filenames.
  `aggregate.awk` then adds up counts — it never re-matches across units, so
  cross-unit basename collisions cannot affect the totals.
- **GNATprove output scoping.** GNATprove analyzes the full project closure
  (runtime generics, `with`ed library units); AdaLang analyzes only the
  project's declared sources. `run.sh` keeps only GNATprove messages whose
  file basename is one of the unit's own sources before handing the log to
  `compare.awk` — otherwise a unit that instantiates, say,
  `Ada.Strings.Bounded` contributes hundreds of one-sided "GNATprove-only"
  obligations from `a-strbou.ads` that say nothing about agreement. This is
  the same `-P` scope asymmetry `benchmarks/coap_spark/README.md` documents.

## Caveats

- **Low matched-pair yield is expected**, unit by unit. Many units leave
  AdaLang entirely at `Unproved`/`Unsupported` (contracts, quantifiers,
  relaxed-initialization), so the `clean` column's "both safe" count is
  small relative to the obligations parsed — the signal is the **zero**s in
  buckets 3 and 4 across a wide construct spread, not the matched count.
- **`test.yaml` prover/steps/opt tweaks are ignored.** Units keep their
  place in the manifest for the obligation kinds they exercise; `run.sh`
  uses one uniform invocation. Units whose `test.yaml` requested more than
  `--steps=16000` were excluded during curation.
- GNATprove version, solver versions and message wording are recorded in
  each dated `RESULTS_*.md`.
- The GNATprove message-text substring matching in `compare.awk` is a
  heuristic against observed wording, not a stable API — see
  `benchmarks/sparknacl/README.md`'s caveat.

See the latest `RESULTS_*.md` in this directory for recorded runs.
