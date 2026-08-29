# gnatcoll-core: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Re-run 2026-08-29, part of a full ten-corpus refresh ahead of a version
bump (see `benchmarks/ada_drivers_library/RESULTS_gnatcheck_2026-08-29.md`
for the batch's shared methodology).

## Environment

- Corpus: AdaCore/gnatcoll-core at `9f6ffb394793b0ac098fb1e9b206a659680788b3`
  (`GNATCOLL_REVISION`), unchanged.
- AdaLang Analyzer: commit `c43415f`.
- GNATcheck / rule map: same as
  `ada_drivers_library/RESULTS_gnatcheck_2026-08-29.md`.
- Reproduce: `GNATCOLL_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/gnatcoll/run_gnatcheck.sh`.

## Both attempts hit the same two worker crashes; numbers were identical both times

Both the first attempt and a second, unmodified retry hit the recurring
`STORAGE_ERROR: stack overflow` (`gnatcheck: error: unparsable worker
output`) crash class, in the same two occurrences each time (10 residual
`gnatcheck.txt` lines out of 2328, `gnatcheck.status` 2). Processing
continued after each crash and produced totals bit-identical between the
two attempts — unlike the flakier corpora in this batch, this looks like a
deterministic crash on a specific large/complex file in this corpus rather
than random worker-scheduling flakiness, but it does not change the
recorded numbers, so the second attempt's totals are used below with no
further retry attempted.

## Totals

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 1891 | |
| &nbsp;&nbsp;matched by GNATcheck | 979 | 51.8% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 912 | 48.2% |
| GNATcheck findings (mapped rules) | 2191 | |
| &nbsp;&nbsp;matched by AdaLang | 977 | 44.6% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 1214 | 55.4% |

Essentially unchanged from the 2026-08-24 run (1891/982 (51.9%), 2197/980
(44.6%) then) — the tiny (2-5 finding) deltas are consistent with the two
crashed workers dropping a handful of findings from whatever files they
were analyzing, not a corpus or AdaLang change.

## `null_paths`-family reporting-location convention: unchanged

`Empty_Then_Body` (6), `Empty_Else_Body` (1), `Empty_Elsif_Body` (2), and
`Null_Case_Alternative` (11, one now matched vs. zero before — noise, not
significant) still show the same benign reporting-location gap documented
in full in the 2026-08-24 run (AdaLang reports at the branch/alternative's
start line; GNATcheck's `null_paths` reports at the empty statement's own
line, sometimes several lines away). Confirmed still genuine empty
branches on inspection, not a repeat of `FP-059` or any other bug.

## Caveats

Same caveats as every prior run apply unchanged (line-granularity matching,
rule pairs are name-level matches not proven semantic equivalence).
