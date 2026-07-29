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

Run the evidence checks with:

```sh
sh tests/run_recommended_gate.sh
sh tests/run_quality_metrics.sh
```

## Precision regression index

Each precision correction has an executable regression:

| Corrected mechanism | Regression evidence |
| --- | --- |
| Static attributes are not elaboration calls | `automotive_state_clean.ads`, run by `run_automotive.sh` |
| Generated configuration pragmas are not authored extensions | `run_automotive.sh` generated-config check |
| A pure `out` actual initializes its variable | `uninitialized_read_clean.adb`, run by `run_bug_findings.sh` |
| A parameterless prefixed mutator writes its prefix | `parameter_mode_clean.adb`, run by `run_bug_findings.sh` |
| Failure-path `out` initialization is not an overwritten assignment | Numeric-literal self-check in `run_recommended.sh` |
| State captured by a nested verifier pass is not a dead store | Flow-interpreter self-check in `run_recommended.sh` |
| Required cleanup status outputs are consumed | VC-prover self-check in `run_recommended.sh` |
| Direct outer `out`-to-`out` forwarding is a write, not a read | `verification_diff_modular_call.adb`, run by `run_verification.sh` and `run_gnatprove_differential.sh` |

When another precision bug is fixed, add or extend a fixture and add its row
here in the same change.

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
