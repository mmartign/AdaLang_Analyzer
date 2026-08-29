# SPARKNaCl: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Re-run 2026-08-29, part of a full ten-corpus refresh ahead of a version
bump (see `benchmarks/ada_drivers_library/RESULTS_gnatcheck_2026-08-29.md`
for the batch's shared methodology).

## Environment

- Corpus: rod-chapman/SPARKnaCl at `49e3bddf092561ce2b74c134a35acff91a2da9a4`
  (`SPARKNACL_REVISION`), unchanged.
- AdaLang Analyzer: commit `c43415f`.
- GNATcheck / rule map: same as
  `ada_drivers_library/RESULTS_gnatcheck_2026-08-29.md`.
- Reproduce: `SPARKNACL_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/sparknacl/run_gnatcheck.sh`.

## This run completed cleanly on the first attempt

No `STORAGE_ERROR: stack overflow` / "unparsable worker output" crash this
time (unlike the 2026-08-24 run, which needed a retry) — `gnatcheck.txt`
has no internal-issue lines at all.

## Totals

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 1557 | |
| &nbsp;&nbsp;matched by GNATcheck | 1334 | 85.7% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 223 | 14.3% |
| GNATcheck findings (mapped rules) | 1778 | |
| &nbsp;&nbsp;matched by AdaLang | 1334 | 75.0% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 444 | 25.0% |

AdaLang's own finding count is unchanged from the 2026-08-24 run (1557):
none of the rule changes landed since then (`Unclosed_File_Handle`
loop-awareness, `FP-062`/`FP-063`) touch a GNATcheck-mapped rule. The
GNATcheck-side finding count moved from 1629 to 1778 and the matched-pair
count from 1332 to 1334 — consistent with the "known run-to-run variance"
already documented for this from-source GNATcheck build, not a corpus or
AdaLang change.

## `Empty_Then_Body`/`Empty_Else_Body`/`Empty_Elsif_Body`/`Null_Case_Alternative` results

All four still report **0 findings** on this corpus, both sides
(`null_paths` itself: 0 GNATcheck findings too) — unchanged from every
prior run; this small, disciplined SPARK codebase still doesn't contain
the "empty branch/alternative with a real sibling" shape.

## Caveats

Same caveats as every prior run apply unchanged (line-granularity matching,
rule pairs are name-level matches not proven semantic equivalence).
