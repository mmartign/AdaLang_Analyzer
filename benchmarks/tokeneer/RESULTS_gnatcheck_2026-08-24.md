# Tokeneer: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Second run, part of the 2026-08-24 batch re-run across all ten corpora
following the `Empty_Then_Body`/`Empty_Else_Body` addition and the `FP-059`
fix (see `benchmarks/ada_drivers_library/RESULTS_gnatcheck_2026-08-24.md`).
Tenth and final run of this batch.

## Environment

- Corpus: AdaCore/spark2014 (sparse checkout on
  `testsuite/gnatprove/tests/tokeneer`) at
  `a97467e91a16409c866434fcc7a5f553bbd98b8a` (`TOKENEER_REVISION`),
  unchanged from the 2026-08-19 run.
- AdaLang Analyzer / GNATcheck / rule map: same as
  `ada_drivers_library/RESULTS_gnatcheck_2026-08-24.md`.
- Reproduce: `TOKENEER_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/tokeneer/run_gnatcheck.sh`. Clean run, no crashes.

## Totals

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 599 | |
| &nbsp;&nbsp;matched by GNATcheck | 444 | 74.1% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 155 | 25.9% |
| GNATcheck findings (mapped rules) | 1602 | |
| &nbsp;&nbsp;matched by AdaLang | 425 | 26.5% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 1177 | 73.5% |

Matches the 2026-08-19 run almost exactly (74.5%/26.5% then).

## `Empty_Else_Body`/`Null_Case_Alternative` results: same benign reporting-location gap

`Empty_Then_Body`/`Empty_Elsif_Body` both show 0/0 on this corpus.
`Empty_Else_Body` shows 1 finding (`userentry.adb:389`, a genuine `else
null;` with no `pragma Assert` involved) and `Null_Case_Alternative` shows
2 (`enclave.adb:1909`, `tokenreader.adb:597`) — 0% GNATcheck-side match for
all three. Each confirmed to have a matching GNATcheck `null_paths` finding
1-2 lines below (`userentry.adb:391`, `enclave.adb:1910`,
`tokenreader.adb:598`) — the same reporting-location convention difference
documented in full in `gnatcoll/RESULTS_gnatcheck_2026-08-24.md`, not a new
bug.

## Batch summary: all ten corpora

This closes the 2026-08-24 batch. Across all ten corpora, the
`null_paths`-family checks (`Empty_If_Body`, `Empty_Elsif_Body`,
`Empty_Then_Body`, `Empty_Else_Body`, `Null_Case_Alternative`) produced 69
findings post-`FP-059`-fix (0 on `ada_drivers_library`, `sparknacl`,
`cubedos`, `libkeccak`, `project_bias`; 40 on `aws`; 20 on `gnatcoll-core`;
5 on `coap_spark`; 1 on `saatana`; 3 here) — every single one confirmed
either a genuine true negative or the same benign reporting-location
convention gap, none a repeat of `FP-059` or any other new bug. One real
bug was found in this batch, on the very first corpus tried
(`ada_drivers_library`'s `pragma Assert (False)` false positive, `FP-059`);
the remaining nine corpora corroborate the fix without surfacing anything
further.

## Caveats

Same caveats as the 2026-08-19 run apply unchanged (line-granularity
matching; `Exception_Swallowed`/`Empty_Exception_Handler` reaching 100%
match at volume, already established, unaffected by this run).
