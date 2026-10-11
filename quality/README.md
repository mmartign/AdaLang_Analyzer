# Quality evidence

This directory keeps the small, reviewable evidence used by the routine
quality gate.

`recommended.baseline` contains the 147 findings accepted after reviewing
the analyzer's own sources with `--recommended`. Duplicate fingerprints are
intentional: the baseline records occurrences, not only unique shapes. The
gate fails when a new non-baselined finding appears; removing an old finding
does not fail the gate.

`recommended_preset_notes.md` keeps the history of that baseline: why each
check joined `--recommended`, what its validation found, and why the
baseline was regenerated when it was.

`known_analysis_issues.tsv` is the registry of confirmed analyzer mistakes.
An open false-positive or false-negative entry contributes to the release
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
probes found the eleven false-safes fixed in 1.6.1 (`FP-086`-`FP-094`,
`FP-097`, `FP-098`), which the GNATprove-oracle corpora could not show: on
code that is proved correct, a bogus proof agrees with the oracle.

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

The corpus has 617 cases, for 266 of the 302 checks, and 229 of those
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

`precision_corpus_notes.md` describes, group by group, what 233 of the
cases target and what was found while writing them.

Still open:

- Cases for the checks above that a single fixture can express.
- Cross-version stability: re-running the same corpus across analyzer
  releases and tracking whether previously stable results change.

## Precision regression index

Each precision correction has an executable regression:

| Corrected mechanism | Regression evidence |
| --- | --- |
| Static attributes are not elaboration calls | `automotive_state_clean.ads`, run by `run_automotive.sh`; also `Library_Level_Initialization` in `precision_corpus.tsv` |
| Generated configuration pragmas are not authored extensions | `run_automotive.sh` generated-config check; also `No_Compiler_Extensions` in `precision_corpus.tsv` |
| A pure `out` actual initializes its variable | `uninitialized_read_clean.adb`, run by `run_bug_findings.sh`; also `Uninitialized_Read` in `precision_corpus.tsv` |
| A parameterless prefixed mutator writes its prefix | `parameter_mode_clean.adb`, run by `run_bug_findings.sh`; also `Wrong_Parameter_Mode` and `Dead_Store` in `precision_corpus.tsv`; also `Uninitialized_Output` in `precision_corpus.tsv` (`uninitialized_output_prefixed_clear_clean.adb`/`_guard.adb`, the write-recognition path `SPARK_Readiness.Statement_Writes_Parameter` uses independently of `Checks.Declarations.Parameter_Is_Written`) |
| Failure-path `out` initialization is not an overwritten assignment | Numeric-literal self-check in `run_recommended.sh` (not folded into `precision_corpus.tsv`: the fixture is the analyzer's own source, not a `tests/*.adb` file) |
| State captured by a nested verifier pass is not a dead store | Flow-interpreter self-check in `run_recommended.sh` (not folded: same reason) |
| Required cleanup status outputs are consumed | VC-prover self-check in `run_recommended.sh` (not folded: same reason) |
| Direct outer `out`-to-`out` forwarding is a write, not a read | `verification_diff_modular_call.adb`, run by `run_verification.sh` and `run_gnatprove_differential.sh` (not folded: this is a bounded `--verify` proof-obligation outcome, not a `Rule_Kind` finding) |
| A same-named enumeration literal is not `Standard.True`/`Standard.False` | `redundant_boolean_comparison_clean.adb`; also `Redundant_Boolean_Comparison` in `precision_corpus.tsv` |
| A write to a Volatile/Atomic/Address-clause object is observable on its own, independent of a later Ada-level read or a repeated identical write | `volatile_register_writes_clean.adb`; also `Repeated_Statement`, `Overwritten_Assignment`, and `Dead_Store` (case `regression-negative-volatile`) in `precision_corpus.tsv` |
| A write to only a selected/indexed component of a parameter does not justify recommending mode `out` -- it depends on every untouched part already holding a meaningful prior value | `wrong_parameter_mode_partial_write_clean.adb`/`_guard.adb`; also `Wrong_Parameter_Mode` in `precision_corpus.tsv` (`Checks.Declarations.Parameter_Is_Wholly_Written`, used only to gate the "use mode out" recommendation; `Dead_Store` and `Uninitialized_Output` still use the original, coarser write detection) |
| An attribute designator (the "Last" naming the attribute in `Data'Last`) is syntactically an identifier but never refers to a declaration, and must not be mistaken for a reference to an unrelated local variable of the same spelling | `uninitialized_read_attribute_designator_clean.adb`/`_guard.adb`; also `Uninitialized_Read` in `precision_corpus.tsv` (`Checks.Data_Flow.Matches_Declaration`, shared by every check built on that module, not only `Uninitialized_Read`) |
| A renaming of part of a longer-lived parameter or global (`Info : T renames Self.Field;`) is not local, even though its own declaration is textually nested inside the subprogram | `dead_store_renaming_of_parameter_field_clean.adb`/`_guard.adb`; also `Dead_Store` in `precision_corpus.tsv` (`Checks.Control_Flow.Renames_Nonlocal_Object`) |
| A nested subprogram or entry body is a declaration -- elaborated, not executed, at its own textual position -- so a read or write inside it does not happen "here" the way a statement does; it only happens when the nested body is actually called | `uninitialized_read_nested_subprogram_order_clean.adb`/`_guard.adb`; also `Uninitialized_Read` in `precision_corpus.tsv` (`Checks.Data_Flow.First_Access` skips recursing into `Ada_Subp_Body`/`Ada_Entry_Body` children) |
| Libadalang's per-actual resolution (`P_Get_Params`) can fail to classify an actual even on an otherwise-unambiguous call (heavy overload; a formal typed `Ada.Calendar.Time`); every write/read detector built on it needs the same lenient callee-name-only, pair-by-position-or-designator fallback, not just the first one that hit it | `uninitialized_read_positional_forward_clean.adb`/`_guard.adb`; also `Uninitialized_Read` in `precision_corpus.tsv` (`Checks.Data_Flow.Call_Writes_Declaration`/`Call_Reads_Simple_Actual`, alongside the original fix in `SPARK_Readiness.Statement_Writes_Parameter` for `FP-008`/`FP-012`) |
| When every formal-resolution path fails for a simple call actual, the call may have initialized that object; a later read is unknown, not definitely before every write. Resolved input actuals remain reads | `uninitialized_read_unresolved_call_clean.adb`/`_guard.adb`; also `Uninitialized_Read` in `precision_corpus.tsv` (`Checks.Data_Flow.First_Access` returns `Unknown_Access` at the unresolved call boundary) |
| `--verify`'s CFG worklist fixed point can record an obligation from an intermediate, not-yet-converged state (typically before a loop's back edge has propagated); a later, fully-converged recording for the same location must be able to correct it, not just refine an `Unproved` result | `verification_loop_stale_initialization.adb`, run by `run_verification.sh` (not folded: this is a bounded `--verify` proof-obligation outcome, not a `Rule_Kind` finding); see `FP-031` in `known_analysis_issues.tsv` for the `Proof_Obligations.Register_At` `Final` mechanism this introduced |
| A `Rule_Kind` violation reported from a live check `Verify_Subprogram`'s CFG fixed point can call more than once for the same AST node (the ordinary-findings counterpart to the `--verify` obligation staleness above) must be counted once per (file, line, column, rule, message), not once per re-visit | `verification_loop_stale_range_check.adb`, run by `run_verification.sh` (not folded: exercises the `--verify`-specific CFG-revisit mechanism, not a plain `Rule_Kind` boundary); see `FP-038` in `known_analysis_issues.tsv` for the `Report.Report_Violation_At` `Already_Reported` deduplication this introduced |
| A range-check whose target value is written inside a dynamically-bounded loop must not be recorded `Proved_Safe` from the CFG fixed point's pre-convergence state (before the loop's back edge propagates a later out-of-range write); the converged state's honest `Unproved` must be able to correct it | `verification_loop_stale_range.adb`, run by `run_verification.sh` (not folded: a bounded `--verify` proof-obligation outcome, not a `Rule_Kind` finding); see `FP-034` in `known_analysis_issues.tsv` for the `Check_Value_Range`/`Finalize_Range_Check` `Final` replay this introduced, reusing FP-031's mechanism |
| The same pre-convergence staleness as `FP-034`, for an array index instead of an assignment's range | `verification_loop_stale_index.adb`, run by `run_verification.sh`; see `FP-035` in `known_analysis_issues.tsv` (`Check_Index_Range`/`Finalize_Index_Check`) |
| The same pre-convergence staleness as `FP-034`, for a division's divisor instead of an assignment's range | `verification_loop_stale_division.adb`, run by `run_verification.sh`; see `FP-036` in `known_analysis_issues.tsv` (`Check_Division_By_Zero`/`Finalize_Division_Check`) |
| The same pre-convergence staleness as `FP-034`, for an arithmetic operation's overflow bound instead of an assignment's range | `verification_loop_stale_overflow.adb`, run by `run_verification.sh`; see `FP-037` in `known_analysis_issues.tsv` (`Check_Integer_Overflow`/`Finalize_Overflow_Check`) |
| The same pre-convergence staleness as `FP-034`/`FP-031`, for a `pragma Assert`/`Loop_Invariant`/`Loop_Variant` condition's `Interpret_Proof_Pragma` recording instead of a range check | `verification_loop_stale_assert.adb`, run by `run_verification.sh`; see `FP-032` in `known_analysis_issues.tsv` (`Check_Proof_Pragma_Assertion`/`Finalize_Assertion_Check`) |
| The same pre-convergence staleness as `FP-032`, for a call's precondition (`Check_Call_Precondition`) instead of a pragma condition; recorded under two distinct stable IDs per call (the whole call, and just the callee name), both needing their own replay | `verification_loop_stale_precondition.adb`, run by `run_verification.sh`; see `FP-033` in `known_analysis_issues.tsv` (`Finalize_Precondition_Check`) |
| Every nested `Bin_Op` in a left-associative chain of plain `and`/`or` operators shares the same `Sloc_Range.Start` (the leftmost operand's position), so a chain of N operators must still report once, not N-1 times | `non_short_circuit_chain_findings.adb`, run by `run_bug_findings.sh` (not folded: the fixture's expected count is 1, not a `precision_corpus.tsv`-expressible clean/finding boundary); also fixed by `FP-038`'s `Already_Reported` deduplication, independent root cause |
| A scalar named only in a nested subprogram declaration's `Global` aspect (a contract, never executed at that textual position) is not a read of the outer object, even though `Finalize_Node`'s whole-body walk shared one CFG position -- positioned before the object's real initializing assignment -- for the entire declaration, aspect included | `verification_global_aspect_reference_clean.adb`/`_guard.adb`, run by `run_verification.sh` (not folded: a bounded `--verify` proof-obligation outcome, not a `Rule_Kind` finding); see `FP-039` in `known_analysis_issues.tsv` (`Finalize_Node`'s new `Ada_Aspect_Spec` exclusion) |
| A "limited with" imposes no "elaborate before" requirement and is Ada's own sanctioned way for two units to reference each other's types without a real circular elaboration dependency, so it must not contribute a `Circular_Package_Dependency` graph edge the way an ordinary/private with does | `circular_dependency_limited_with_a.ads`/`_b.ads`, run by `run_circular_dependencies.sh` (not folded into `precision_corpus.tsv`: `Circular_Package_Dependency` is a whole-program check that needs both cycle members on one command line, the same reason its original findings/clean fixtures are not folded either); see `FP-042` in `known_analysis_issues.tsv` (edges are now built by walking `Compilation_Unit.F_Prelude`'s own `With_Clause` nodes and skipping any with `F_Has_Limited`, instead of the aggregated `P_Withed_Units`, which does not distinguish limited from ordinary) |

When another precision bug is fixed, add or extend a fixture and add its row
here in the same change.

## External corpus findings

`external_corpus_findings.md` records validation runs against real Ada/SPARK
code the project did not write (as opposed to the hand-constructed precision
corpus above) — what was run, what was found, and the fix and regression
test for anything confirmed as a real analyzer mistake (folded into
`known_analysis_issues.tsv`). `benchmarks/README.md` carries the current
GNATprove- and GNATcheck-oracle comparison numbers for all eleven tracked
corpora (sparknacl, saatana, libkeccak, coap_spark, tokeneer, cubedos, aws,
ada_drivers_library, gnatcoll, project_bias, spark_testsuite) — see that
file for current matched-obligation counts, unsoundness/false-positive
totals, and each corpus's own dated `RESULTS_*.md`. Do not duplicate those
numbers here; they change with every re-run.

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
