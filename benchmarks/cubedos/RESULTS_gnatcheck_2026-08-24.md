# CubedOS: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Re-run 2026-08-29, part of a full ten-corpus refresh ahead of a version
bump (see `benchmarks/ada_drivers_library/RESULTS_gnatcheck_2026-08-24.md`
for the batch's shared methodology).

## Environment

- Corpus: cubesatlab/cubedos at `c402301000a5a92237e0f7ab106186a48273cf24`
  (`CUBEDOS_REVISION`), unchanged.
- AdaLang Analyzer: commit `c43415f`.
- GNATcheck / rule map: same as
  `ada_drivers_library/RESULTS_gnatcheck_2026-08-24.md`.
- Reproduce: `CUBEDOS_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/cubedos/run_gnatcheck.sh`.

## Reproduction gotcha: do not pre-wrap this script in your own `alr exec`

Still applies unchanged — see the 2026-08-24 run for the full explanation.
This run invoked the script directly in a plain shell as documented.

## First attempt crashed at the start; retry succeeded

The first attempt hit the recurring `STORAGE_ERROR: stack overflow`
(`gnatcheck: error: unparsable worker output`) crash class in its first
five lines, though processing continued afterward (561 `gnatcheck.txt`
lines produced). A second, unmodified re-run completed with zero
internal-issue lines; its totals are used below.

## Totals

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 182 | |
| &nbsp;&nbsp;matched by GNATcheck | 157 | 86.3% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 25 | 13.7% |
| GNATcheck findings (mapped rules) | 653 | |
| &nbsp;&nbsp;matched by AdaLang | 157 | 24.0% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 496 | 76.0% |

AdaLang's own finding count is unchanged from the 2026-08-24 run (182).
GNATcheck's own finding count moved further than usual this time (491 →
653, matched-pair count 149 → 157) — within the range of this from-source
build's already-documented run-to-run variance (see
`benchmarks/README.md`'s "GNATcheck oracle comparison" section), but a
larger swing than most other corpora in this batch showed. Not
investigated further per this refresh's scope (see the corpus's own
`RESULTS_2026-08-25.md` and `README.md` for the `FP-040` obligation-count
caveat that already governs how much weight to put on this corpus's
numbers generally).

## `Empty_Then_Body`/`Empty_Else_Body`/`Empty_Elsif_Body`/`Null_Case_Alternative` results

All four still report **0 findings** on this corpus, both sides —
unchanged from every prior run.

## Caveats

Same caveats as prior runs apply unchanged (project-embedded rule
configuration required `--ignore-project-switches`; `Exception_Propagation`
finding nothing on task bodies is explained, not a bug).
