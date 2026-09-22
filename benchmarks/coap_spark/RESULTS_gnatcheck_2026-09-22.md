# coap_spark: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Re-run 2026-09-22, verifying the `FP-066` fix (`Null_Statement`) across
every corpus this project's GNATcheck oracle comparison covers -- see
`benchmarks/aws/RESULTS_gnatcheck_2026-09-22.md` for the full root-cause
writeup and methodology; this file only records this corpus's numbers.

## Environment

- Corpus: mgrojo/coap_spark at `2fa345b8c70d621287b932aee7ea39b3520a5adf`
  (`COAP_SPARK_REVISION`), with the `wolfssl` submodule, unchanged.
- AdaLang Analyzer: commit including the `FP-066` fix (version 1.5.2).
- Standalone `sparklib=16.1.0` crate (`sparklib_16.1.0_6d13c714`, same hash
  documented in `README.md`), redeployed fresh for this run.
- Reproduce: `COAP_SPARK_ROOT=<checkout> COAP_SPARK_SPARKLIB=<sparklib dir>
  GNATCHECK_ENV=<env.sh> benchmarks/coap_spark/run_gnatcheck.sh`.

## Totals

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 776 | |
| &nbsp;&nbsp;matched by GNATcheck | 626 | 80.7% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 150 | 19.3% |
| GNATcheck findings (mapped rules) | 6545 | |
| &nbsp;&nbsp;matched by AdaLang | 626 | 9.6% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 5919 | 90.4% |

GNATcheck's own finding count moved substantially from the 2026-08-29
baseline (7629 -> 6545); this corpus already carries the largest documented
run-to-run variance of the ten (RecordFlux-generated code, largest project
by GNATcheck finding count), so this is treated as the already-known noise
class, not investigated further.

## `Null_Statement`: FP-066 fix confirmed

Before: 12 findings, 8 unmatched (33%). After: **4 findings, 0 unmatched
(100%)** -- 8 of the 12 were the sole-statement idiom now exempted; the 4
that remain are genuine redundant padding and are now correctly matched by
GNATcheck's own `redundant_null_statements` (which also moved to 0
unmatched, up from 0 matched before -- both sides now agree completely).
AdaLang's total mapped-rule finding count dropped 784 -> 776 accordingly.

## Caveats

Same caveats as prior runs apply unchanged.
