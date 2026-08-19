# SPARKNaCl comparison benchmark

This benchmark compares AdaLang Analyzer's `--verify` bounded-scalar proof
obligations against GNATprove's `--mode=prove` results, per obligation
(same file, line, and check kind), on a pinned revision of
[rod-chapman/SPARKnaCl](https://github.com/rod-chapman/SPARKnaCl) — a
self-contained, Gold-level-proved SPARK 2014 port of TweetNaCl.

Unlike `benchmarks/aws/`, which only checks aggregate pass/fail because
GNATprove cannot complete a project-wide run on unmodified AWS, this
benchmark aims for a real per-obligation agreement number: since SPARKNaCl is
already fully proved, GNATprove's verdict is a trustworthy oracle, and the
two questions that matter are (1) does AdaLang ever call something
`Proved_Safe` that GNATprove could not prove (a soundness question), and
(2) how often does AdaLang's `Definite_Error` agree with GNATprove's
not-proved verdict (a precision question). It is still not an equivalence
claim: AdaLang's bounded mode uses CFG fixed-point abstract interpretation
over a narrower scalar subset, not GNATprove's verification-condition/prover
pipeline (see `POSITIONING.md`).

## Pinned source

- rod-chapman/SPARKnaCl: `49e3bddf092561ce2b74c134a35acff91a2da9a4`

Clone the corpus from the AdaLang Analyzer repository root:

```sh
git clone https://github.com/rod-chapman/SPARKnaCl.git \
  /private/tmp/adalang-sparknacl-benchmark
git -C /private/tmp/adalang-sparknacl-benchmark checkout \
  49e3bddf092561ce2b74c134a35acff91a2da9a4
```

No separate build/setup step is needed: `sparknacl.gpr` is a self-contained
library project with no external `with` dependencies, and GNATprove is
resolved the same way `benchmarks/aws/run.sh` resolves it (`GNATPROVE` env
var, then `PATH`, then `~/.alire/bin/gnatprove`) rather than through
SPARKNaCl's own `alire.toml`.

`run.sh` re-execs itself under this repository's own `alr exec` (like
`benchmarks/aws/run.sh` does) specifically to put a GNAT toolchain's
`gnatls` on `PATH`. Without it, Libadalang's own runtime source-path lookup
for `with`'d units fails, which triggers `FP-029` (see
`quality/known_analysis_issues.tsv`) on every SPARKNaCl file that subtypes an
`Interfaces` scalar type — nearly all of them, since `SPARKNaCl.I32`/`U32`/
`U64`/etc. all do — and silently drops most proof obligations (observed:
551 obligations parsed without `gnatls` on `PATH` vs. 9,646 with it, on the
same source). This is worth calling out because it is the single largest
lever on this benchmark's numbers, and it is an existing, already-diagnosed
issue rather than one discovered by SPARKNaCl specifically.

Run the benchmark:

```sh
SPARKNACL_ROOT=/private/tmp/adalang-sparknacl-benchmark sh benchmarks/sparknacl/run.sh
```

`run.sh` verifies the pinned revision, then runs:

- AdaLang `--verify` against `sparknacl.gpr`, `--format=json`;
- GNATprove `--mode=prove --output=oneline` against the same project, using
  the `Prove` package switches already authored in `sparknacl.gpr`
  (`--level=4`, `--prover=z3,cvc5,altergo`, `--timeout=60`,
  `--steps=140000`) rather than a weaker ad hoc setting, since that
  configuration is what backs SPARKNaCl's own "fully proved" claim;
- `compare.awk` over both outputs, writing `comparison.txt` to the results
  directory (default `benchmark-results/sparknacl/`, override with
  `RESULTS_DIR`).

## Matching design

AdaLang's `--verify --format=json` obligations and GNATprove's
`--output=oneline` messages are matched by `(basename(file), line,
normalized check kind)` — not column, since the two tools can point at
different sub-tokens of the same logical check. The kind-vocabulary mapping
(AdaLang's `Kind_Name` values from
`src/adalang_analyzer-proof_obligations.adb` → substrings in GNATprove's
message text) is documented at the top of `compare.awk`.

If a bucket has more than one obligation on either side (e.g. two index
checks on the same line), it is **not** auto-paired — `compare.awk` reports
it separately as a count mismatch for manual review, rather than guessing
which one goes with which. This mirrors the project's existing
precision-over-convenience posture (see the `FP-xxx` catalog in
`quality/known_analysis_issues.tsv`).

`compare.awk`'s output has five per-pair buckets:

1. Both safe — AdaLang `proved-safe` + GNATprove proved. Headline agreement.
2. AdaLang conservative — AdaLang `unproved`/`unsupported` + GNATprove
   proved. An expected scope gap, not a defect.
3. **Possible AdaLang unsoundness** — AdaLang `proved-safe` + GNATprove NOT
   proved. On a fully-proved corpus this should be zero; any non-zero count
   is reported with full detail and must be checked against the actual
   source before being trusted.
4. **AdaLang false positive** — AdaLang `definite-error` + GNATprove proved.
   Directly comparable to the existing `FP-xxx` catalog.
5. Both flag a problem — both non-safe. Unexpected on this fully-proved
   corpus; would indicate a fixture-level issue.

Plus two coverage-only counts, not treated as errors: obligations AdaLang
records that have no GNATprove `--mode=prove` counterpart for that kind
(e.g. `initialization-check`, which is a flow-analysis result), and
GNATprove messages whose kind isn't in the mapping table at all (e.g.
length/predicate/tag checks AdaLang doesn't model).

## Caveats

- The GNATprove message-text substring matching (e.g. distinguishing
  `loop-invariant-initialization` from `loop-invariant-preservation` by
  looking for "first iteration" vs. other phrasing) is a heuristic against
  observed wording, not a stable GNATprove API. Spot-check a few matched
  pairs against the source before trusting the aggregate table wholesale.
- GNATprove version, solver versions, and exact message wording are recorded
  in each dated `RESULTS_*.md` for reproducibility.

See the latest `RESULTS_*.md` in this directory for recorded runs.

## GNATcheck oracle lane

`run_gnatcheck.sh` runs a separate comparison: AdaLang's rule findings
against GNATcheck's, for the rule pairs in `benchmarks/gnatcheck_rule_map.tsv`.
Needs `GNATCHECK` or `GNATCHECK_ENV` set (see `benchmarks/README.md`'s
GNATcheck section — there is no Alire package for it, so this is a
separately-built local binary, not something `alr exec` resolves on its
own). See `RESULTS_gnatcheck_2026-08-19.md` for the first run and its
caveats.
