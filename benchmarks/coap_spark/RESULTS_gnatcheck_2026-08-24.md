# coap_spark: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Second run, part of the 2026-08-24 batch re-run across all ten corpora
following the `Empty_Then_Body`/`Empty_Else_Body` addition and the `FP-059`
fix (see `benchmarks/ada_drivers_library/RESULTS_gnatcheck_2026-08-24.md`).

## Environment

- Corpus: mgrojo/coap_spark at `2fa345b8c70d621287b932aee7ea39b3520a5adf`
  (`COAP_SPARK_REVISION`) with the `libs/wolfssl` submodule initialized,
  unchanged from the 2026-08-19 run.
- SPARKlib: a standalone `alr get sparklib=16.1.0` deployment
  (`COAP_SPARK_SPARKLIB`), per README.md's documented environment fix.
- AdaLang Analyzer / GNATcheck / rule map: same as
  `ada_drivers_library/RESULTS_gnatcheck_2026-08-24.md`.
- Reproduce: `COAP_SPARK_ROOT=<checkout> COAP_SPARK_SPARKLIB=<sparklib
  crate> GNATCHECK_ENV=<env.sh> benchmarks/coap_spark/run_gnatcheck.sh`.
  Clean run, no crashes.

## Totals

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 784 | |
| &nbsp;&nbsp;matched by GNATcheck | 641 | 81.8% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 143 | 18.2% |
| GNATcheck findings (mapped rules) | 7629 | |
| &nbsp;&nbsp;matched by AdaLang | 641 | 8.4% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 6988 | 91.6% |

Matches the 2026-08-19 run almost exactly (82.3%/8.4% then).

## `Null_Case_Alternative` results: same benign reporting-location gap as gnatcoll-core/AWS

`Empty_Then_Body`/`Empty_Else_Body`/`Empty_Elsif_Body` all show 0/0 on this
corpus. `Null_Case_Alternative` shows 5 findings, 0% GNATcheck-side match —
all 5 are in RecordFlux-generated state-dispatch code
(`generated/rflx-coap_client-session-fsm.adb`,
`generated/rflx-coap_server-main_loop-fsm.adb`). Confirmed each has a
matching GNATcheck `null_paths` finding one line below (e.g. AdaLang's
`:824:10` vs. GNATcheck's `:825:13`) — the same reporting-location
convention difference documented in full in
`gnatcoll/RESULTS_gnatcheck_2026-08-24.md`, not a new bug.

## Caveats

Same caveats as the 2026-08-19 run apply unchanged (line-granularity
matching; this corpus's `min_identifier_length`/`non_short_circuit_operators`
near-total mismatch on RecordFlux-generated code, already explained there).
