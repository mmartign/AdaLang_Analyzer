# Quality evidence

This directory keeps the small, reviewable evidence used by the routine
quality gate.

`recommended.baseline` contains the 22 findings accepted after reviewing the
analyzer's own sources with `--recommended`. Duplicate fingerprints are
intentional: the baseline records occurrences, not only unique shapes. The
gate fails when a new non-baselined finding appears; removing an old finding
does not fail the gate.

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
sh tests/run_precision_corpus.sh
```

`automotive_rule_evidence.tsv` maps every check enabled by `--automotive` to a
positive and clean invocation. `run_automotive_evidence.sh` fails if the
implemented preset, the Automotive Ada Compliance Matrix, and this manifest
do not contain the same rule set, or if any mapped fixture stops producing
the expected result.

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

Current coverage (24 cases):

- 12 threshold boundary cases: the six checks with a configurable numeric
  threshold — `Cyclomatic_Complexity`, `Deep_Nesting`, `Too_Many_Parameters`,
  `Long_Line`, `Generic_Instantiation_Limit`, `Dependency_Limit` — each with
  an "exactly at the default threshold" fixture that must stay clean and a
  "threshold plus one" fixture that must fire. Every boundary value in the
  corpus was confirmed against the built analyzer's own diagnostic message
  (e.g. "cyclomatic complexity 11 exceeds threshold 10"), not derived from
  reading the check's source and assuming it is correct.
- 9 regression-negative cases, folded in from the "Precision regression
  index" below: `Library_Level_Initialization`, `No_Compiler_Extensions`,
  `Uninitialized_Read`, `Wrong_Parameter_Mode`, `Dead_Store` (twice, on two
  distinct fixtures), `Redundant_Boolean_Comparison`, `Repeated_Statement`,
  and `Overwritten_Assignment`, each on the existing fixture the index
  already pointed at. Only rows that map cleanly to one rule and one
  checked-in fixture were folded in this way; the remaining index rows
  reference the analyzer's own source or a bounded `--verify`
  proof-obligation outcome rather than a `Rule_Kind` finding on a
  `tests/*.adb` fixture, and stay prose-only rather than force an uncertain
  mapping into a gate (see the index below for which).
- 3 boundary/negative cases for checks with no numeric threshold, targeting
  constructs the check's own implementation already special-cases:
  `Missing_Overriding_Indicator` on a same-named primitive with a different
  profile (an overload, not an override, so it needs no keyword — expected
  `clean`); `Uninitialized_Read` on a record variable read before its first
  assignment (only scalar declarations are checked — expected `clean`); and
  `Wrong_Parameter_Mode` on a parameter used only as an array index inside a
  write destination (writing `Values (Idx)` writes `Values`, not `Idx`, so
  `Idx` is read-only and must still be flagged — expected `finding`). Each
  outcome was confirmed against the built analyzer, not assumed from reading
  the check's source.

This is a starting corpus, not a complete one. Still open, in roughly
increasing order of effort:

- More boundary/negative cases for checks without a numeric threshold (e.g.
  suspicious-but-legitimate constructs that resemble a violation without
  being one) — the 3 added so far only cover 3 of the roughly 80 remaining
  checks.
- A project-scale corpus of real (non-synthetic) Ada code with a manually
  reviewed sample, to estimate precision beyond hand-constructed fixtures.
- Cross-version stability: re-running the same corpus across analyzer
  releases and tracking whether previously stable results change.
- Independent-oracle comparison against another tool (e.g. GNATcheck) on the
  subset of checks with real overlap.

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
| Every nested `Bin_Op` in a left-associative chain of plain `and`/`or` operators shares the same `Sloc_Range.Start` (the leftmost operand's position), so a chain of N operators must still report once, not N-1 times | `non_short_circuit_chain_findings.adb`, run by `run_bug_findings.sh` (not folded: the fixture's expected count is 1, not a `precision_corpus.tsv`-expressible clean/finding boundary); also fixed by `FP-038`'s `Already_Reported` deduplication, independent root cause |

When another precision bug is fixed, add or extend a fixture and add its row
here in the same change.

## External corpus findings

`external_corpus_findings.md` records validation runs against real Ada/SPARK
code the project did not write (as opposed to the hand-constructed precision
corpus above), starting with a 120-file Tokeneer run that produced three
confirmed, fixed false positives (`FP-004`, `FP-005`, `FP-006` in
`known_analysis_issues.tsv`) and a quantified scope observation about
`--verify`'s non-relational, intraprocedural limits on real code.

`benchmarks/aws/` adds the reproducible project-scale comparison against a
pinned AdaCore/aws revision. It records AdaLang's ordinary, SPARK-readiness,
and bounded-verification coverage; GNATprove's unmodified-project boundary;
and the precision issue found by manually reviewing AdaLang `Definite_Error`
outcomes, including its fix and pinned-corpus validation.

## Differential corpus

The GNATprove differential gate contains 16 clean and 5 deliberately broken
units. Five clean units are added for the current development release:

- Bounded arithmetic and assignment chaining.
- Conditional range refinement.
- Modular contract transfer.
- Indexed array access.
- Relational loop invariants.

The modular-call case now exercises direct forwarding from an outer `out`
parameter to a nested `out` parameter. It is the regression for closed issue
`FP-001` and must remain free of a definite initialization error.

Run it with `sh tests/run_gnatprove_differential.sh`. The script rejects
`Definite_Error` or `Unsupported` AdaLang results on the clean corpus and
requires GNATprove to prove all 16 clean units. It also requires GNATprove to
find failures in every unit of the broken corpus.
