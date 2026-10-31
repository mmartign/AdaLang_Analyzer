# Quality evidence

This directory keeps the small, reviewable evidence used by the routine
quality gate.

`recommended.baseline` contains the 147 findings accepted after reviewing
the analyzer's own sources with `--recommended`. Duplicate fingerprints are
intentional: the baseline records occurrences, not only unique shapes. The
gate fails when a new non-baselined finding appears; removing an old finding
does not fail the gate.

`known_analysis_issues.tsv` is the registry of confirmed analyzer mistakes.
Each row records the mistake, its status and the regression that guards the
fix. An open false-positive or false-negative entry contributes to the release
metrics. A zero count means that no confirmed case is currently open; it is
not a claim that the analyzer has zero unknown mistakes.

`release_metrics.csv` records, per release:

- Open confirmed false positives.
- Open confirmed false negatives.
- Supported verification-construct families. This is currently the number of
  explicit `Obligation_Kind` families, each of which can still be classified
  as `Unproved` or `Unsupported`; it is not a whole-program proof claim.
- Reviewed findings in the recommended self-analysis baseline.
- Cases in the precision corpus (see "Precision corpus" below).

Run the evidence checks with:

```sh
sh tests/run_recommended_gate.sh
sh tests/run_quality_metrics.sh
sh tests/run_automotive_evidence.sh
sh tests/run_do178c_evidence.sh
sh tests/run_corpus_exercise_coverage.sh
sh tests/run_tool_function_evidence.sh
sh tests/run_precision_corpus.sh
sh tests/run_verification_mutations.sh
sh tests/run_seeded_defects.sh
sh tests/run_proof_path_evidence.sh
```

`automotive_rule_evidence.tsv` maps every check enabled by `--automotive` to a
positive and clean invocation. `run_automotive_evidence.sh` fails if the
implemented preset, the Automotive Ada Compliance Matrix, and this manifest
do not contain the same rule set, or if any mapped fixture stops producing
the expected result.

`do178c_rule_evidence.tsv` is the same pattern for `--do178c`: every check
enabled under any of its four levels maps to a positive and clean invocation.
`run_do178c_evidence.sh` fails under the same conditions as the automotive
gate (preset, `docs/src/do178c-compliance-matrix.md`, and this manifest must
agree on
the rule set, and every mapped fixture must still produce the expected
result), plus one DO-178C-specific check the automotive gate has no
equivalent for: `Enable_DO_178C_Preset` enables three tiers (a Core tier at
every level, a Level C tier, and a Level A/B tier), so the gate also confirms
the matrix's per-row "DO-178C level(s)" column agrees with which tier each
rule actually comes from in `src/adalang_analyzer-rules.ads`, not just that
every rule name appears somewhere in the table.

`tool_function_evidence.tsv` widens that pattern from the two profile presets
to the whole `Rule_Kind` catalogue, and adds the two columns a tool-
qualification argument needs on top of a fixture pair: an assurance `class`
(which fixes the effect direction of a tool malfunction -- see the generated
[tool-function validation evidence](../docs/src/tool-qualification-support.md)
page) and an `independent oracle` value recording whether GNATcheck or the
GNATprove differential also cross-checks that check on the benchmark corpora.
`run_tool_function_evidence.sh` fails if the manifest is not exactly the
`Rule_Kind` catalogue (no missing check, no stale row, no duplicate), if a
`class` or `independent oracle` value is outside its vocabulary, if a claimed
oracle is not backed by the corresponding evidence body, if any positive
invocation stops producing a finding or any negative invocation stops being
clean, or if `docs/src/tool-qualification-support.md` is not a byte-exact
regeneration of the manifest by `tests/gen_tool_qualification_doc.sh`. It is
validation evidence, not a qualification argument, and does not by itself
support any tool-classification (EN 50128 §6.7) or qualification claim.

`corpus_exercise_coverage.tsv` complements the hand-built fixtures with
exercise evidence against real code: for every `Rule_Kind` check it records,
derived from `benchmark-results/*/adalang-*.json`, whether a benchmark preset
run enabled it over one of the external corpora, how many corpora did, and
how many findings across how many files it produced there.
`benchmark-results/` is gitignored, so this file is a release snapshot
refreshed by re-running `tests/gen_corpus_exercise_coverage.py` after a local
benchmark run, the same way `benchmarks/*/RESULTS_*.md` are.
`run_corpus_exercise_coverage.sh` always checks the file covers the whole
catalogue with well-formed rows, and additionally regenerates and diffs it
when the benchmark JSON is present locally; a fresh checkout or CI, where
`benchmark-results/` does not exist, passes on the structural checks alone.
A finding count here is not a defect count, and a check not reached by the
corpus presets is not a deficiency -- it is fixture-validated only.

## Verification mutation campaign

`verification_mutations.tsv` records deliberately unsafe proof obligations
and their expected conservative outcomes. `run_verification_mutations.sh`
requires every named obligation to exist, rejects any `Proved_Safe` result,
and also checks the expected `Definite_Error` or `Unproved` classification.
This is a focused false-safe regression gate, complementary to the clean and
broken GNATprove differential corpora.

`tests/seeded_defects/` widens the same idea from one obligation per manifest
row to whole probe programs. Each is written so that a marked check really
fails (`--  BAD`, or `--  BAD:kind` for a kind other than division by zero)
or really holds (`--  OK`). `run_seeded_defects.sh` fails if any marked defect
is reported `Proved_Safe` or `Unreachable`. It also compares the outcome of
every marked line with `seeded_defect_outcomes.tsv`, so a probe that loses
its obligation, or a safe check that stops proving, is noticed; after an
intended change, regenerate that file with
`python3 tests/seeded_defect_check.py --update` and review the diff. These
probes catch what the GNATprove-oracle corpora cannot show: on code that is
proved correct, a bogus proof agrees with the oracle.

`proof_path_evidence.tsv` maps every source-tagged `Record_Proved_Safe`
producer to one or more method-specific evidence routes. Its gate checks a
positive proof and an adversarial non-proof for every route. Routes that need
the external solver portfolio must additionally retain `Unproved` outcomes
for both unsupported scalar translation and unavailable solvers. The source
and manifest producer sets must match exactly.

## Precision corpus

`precision_corpus.tsv` is a growing, machine-checked corpus of boundary and
negative cases: fixtures constructed to sit exactly at a check's decision
boundary, with the expected outcome (`clean` or `finding`) recorded
alongside. `run_precision_corpus.sh` runs every row in isolation
(`-checks="-*,<rule>"`) and fails the gate if any fixture's actual outcome
disagrees with the recorded expectation — the corpus size itself is tracked
as `precision_corpus_cases` in `release_metrics.csv`, the same way the other
evidence categories in this directory are tracked, so it can only grow, never
silently shrink, across releases.

The corpus has 622 cases, for 266 of the 302 checks, and 229 of those
checks have both a clean and a finding case. The 36 checks without a case
include those a single-fixture row cannot express or that another gate
covers:

- five `Known_*_Failure` checks, whose outcomes are pinned by
  `run_verification.sh` fixtures instead;
- `Circular_Package_Dependency`, a whole-program check that needs a
  `with`-cycle across two or more files (`run_circular_dependencies.sh`);
- the three compiler wrappers (`Compiler_Warning`, `Compiler_Style_Check`,
  `Compiler_Restriction`), which need GNAT;
- checks that report nothing until their parameters are set, such as
  `Identifier_Casing` and `Forbidden_Attribute`.

Still open:

- Cases for the checks above that a single fixture can express.
- Cross-version stability: re-running the same corpus across analyzer
  releases and tracking whether previously stable results change.

## Real-code validation

`benchmarks/README.md` carries the GNATprove- and GNATcheck-oracle comparison
numbers for all eleven tracked corpora (sparknacl, saatana, libkeccak,
coap_spark, tokeneer, cubedos, aws, ada_drivers_library, gnatcoll,
project_bias, spark_testsuite), and each corpus's directory its own
`RESULTS_*.md`. Do not duplicate those numbers here; they change with every
re-run.

## Differential corpus

`tests/run_gnatprove_differential.sh` runs a clean and a deliberately
broken corpus through GNATprove. It rejects `Definite_Error` or
`Unsupported` AdaLang results on the clean corpus and requires GNATprove to
prove every clean unit. It also requires GNATprove to find failures in
every unit of the broken corpus. The number of units in each is stated in
the "Build" section of the project `README.md`.

The clean corpus includes:

- Bounded arithmetic and assignment chaining.
- Conditional range refinement.
- Modular contract transfer.
- Indexed array access.
- Relational loop invariants.
- Increasing loop variants.

The modular-call case exercises direct forwarding from an outer `out`
parameter to a nested `out` parameter. It is the regression for closed issue
`FP-001` and must remain free of a definite initialization error.
