# coap_spark: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Re-run 2026-08-29, part of a full ten-corpus refresh ahead of a version
bump (see `benchmarks/ada_drivers_library/RESULTS_gnatcheck_2026-08-24.md`
for the batch's shared methodology). Clean run, no crashes.

## Environment

- Corpus: mgrojo/coap_spark at `2fa345b8c70d621287b932aee7ea39b3520a5adf`
  (`COAP_SPARK_REVISION`) with the `libs/wolfssl` submodule initialized,
  unchanged.
- SPARKlib: a standalone `alr get sparklib=16.1.0` deployment
  (`COAP_SPARK_SPARKLIB`), per `README.md`'s documented environment fix.
- AdaLang Analyzer: commit `c43415f`.
- GNATcheck / rule map: same as
  `ada_drivers_library/RESULTS_gnatcheck_2026-08-24.md`.
- Reproduce: `COAP_SPARK_ROOT=<checkout> COAP_SPARK_SPARKLIB=<sparklib
  crate> GNATCHECK_ENV=<env.sh> benchmarks/coap_spark/run_gnatcheck.sh`.

## Totals

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 784 | |
| &nbsp;&nbsp;matched by GNATcheck | 641 | 81.8% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 143 | 18.2% |
| GNATcheck findings (mapped rules) | 7629 | |
| &nbsp;&nbsp;matched by AdaLang | 641 | 8.4% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 6988 | 91.6% |

Bit-identical to the 2026-08-24 run in every field.

## `Null_Case_Alternative` results: same benign reporting-location gap as gnatcoll-core/AWS

Still 5 findings, 0% GNATcheck-side match, all in RecordFlux-generated
state-dispatch code — unchanged from every prior run, the same
reporting-location convention difference documented in full in
`gnatcoll/RESULTS_gnatcheck_2026-08-24.md`, not a new bug.
`Empty_Then_Body`/`Empty_Else_Body`/`Empty_Elsif_Body` still show 0/0.

## Caveats

Same caveats as prior runs apply unchanged (line-granularity matching;
this corpus's `min_identifier_length`/`non_short_circuit_operators`
near-total mismatch on RecordFlux-generated code).
