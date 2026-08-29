# project_bias comparison benchmark

This benchmark runs AdaLang Analyzer's `--recommended`, `--spark`, and
`--verify` presets against a pinned revision of
[EliAvila10/project_bias](https://github.com/EliAvila10/project_bias), then
compares AdaLang's bounded proof outcomes with GNATprove's prove-mode output.
The corpus is a small Apache-2.0 Ada/SPARK cryptographic random-stream engine
that maps operating-system entropy into custom alphabets without modulo bias.

Its useful shapes differ from the existing external corpora: floating-point
entropy calculations and contracts, quantified array predicates, many loop
invariants, C/Windows entropy-provider bindings, localized `SPARK_Mode => Off`
boundaries, and explicit clearing of entropy buffers.

## Classification

This is **real-code validation, not an independent-oracle corpus**. At the
pinned revision, GNATprove reports three unresolved proof checks at the fixed
benchmark budget and one flow error: `Ada.Calendar.Clock_Time` is missing from
`Chain_Test.Gen_Test`'s `Global` aspect. Consequently, a GNATprove non-proof
cannot establish that an AdaLang result is wrong, and this corpus is excluded
from the fully-proved totals in `benchmarks/README.md`.

The upstream README describes the project as fully proved at SPARK Level 4,
but the repository contains neither a CI proof workflow nor a checked-in proof
report that reproduces that claim. The corpus can be promoted to the
independent-oracle table if a future pinned revision has a clean, reproducible
GNATprove run.

## Pinned source

- EliAvila10/project_bias: `bb83565322eba9a0bd59ccda607edcdc0a1bd381`

Clone the corpus from the AdaLang Analyzer repository root:

```sh
git clone https://github.com/EliAvila10/project_bias.git \
  /private/tmp/adalang-project-bias-benchmark
git -C /private/tmp/adalang-project-bias-benchmark checkout \
  bb83565322eba9a0bd59ccda607edcdc0a1bd381
```

Run the benchmark:

```sh
PROJECT_BIAS_ROOT=/private/tmp/adalang-project-bias-benchmark \
  sh benchmarks/project_bias/run.sh
```

The project is Windows-oriented and its linker configuration names a Windows
system DLL. The benchmark intentionally does not build or execute it: AdaLang
and GNATprove can analyze the unmodified project on other hosts without
linking the executable.

`run.sh` verifies the pinned revision, enters this repository's Alire
environment, then runs:

- AdaLang `--recommended`, `--spark`, and `--verify`, with JSON reports and
  compact summaries;
- GNATprove `--mode=prove` with Z3, CVC5, and Alt-Ergo, a 16,000-step limit,
  a 10-second per-check timeout, and statistics reporting;
- the canonical `benchmarks/sparknacl/compare.awk` matcher over AdaLang's
  verify report and GNATprove's oneline report, with a corpus-specific report
  heading supplied through the matcher's `corpus_label` option.

Outputs go to `benchmark-results/project_bias/` by default; override this with
`RESULTS_DIR`.

## Interpretation and caveats

- Obligation matching uses `(basename(file), line, normalized check kind)`.
  Count-mismatched locations are listed for manual review rather than paired
  speculatively. See `benchmarks/sparknacl/README.md` for the full design.
- The generator contains many near-identical procedures for different output
  alphabets. Its roughly 3,600 lines therefore provide less independent
  structural diversity than the raw line count suggests.
- Findings involving package constants, contract-only parameter reads,
  floating equality in formal contracts, or explicit buffer clearing are
  review targets, not automatically accepted analyzer defects or baselines.
- Apache-2.0 permits this pinned external use. The corpus remains an external
  checkout; none of its source is vendored here.

See [RESULTS_2026-08-29.md](RESULTS_2026-08-29.md) for the current recorded run.
