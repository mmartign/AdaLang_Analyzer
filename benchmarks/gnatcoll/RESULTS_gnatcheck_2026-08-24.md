# gnatcoll-core: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Second run, part of the 2026-08-24 batch re-run across all ten corpora
following the `Empty_Then_Body`/`Empty_Else_Body` addition and the `FP-059`
fix (see `benchmarks/ada_drivers_library/RESULTS_gnatcheck_2026-08-24.md`
for the full writeup of that fix). This is where the batch's other new
finding — benign, not a bug — was first identified.

## Environment

- Corpus: AdaCore/gnatcoll-core at `9f6ffb394793b0ac098fb1e9b206a659680788b3`
  (`GNATCOLL_REVISION`), unchanged from the 2026-08-19 run.
- AdaLang Analyzer / GNATcheck / rule map: same as
  `ada_drivers_library/RESULTS_gnatcheck_2026-08-24.md`.
- Reproduce: `GNATCOLL_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/gnatcoll/run_gnatcheck.sh`. Clean run, no crashes.

## Totals

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 1891 | |
| &nbsp;&nbsp;matched by GNATcheck | 982 | 51.9% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 909 | 48.1% |
| GNATcheck findings (mapped rules) | 2197 | |
| &nbsp;&nbsp;matched by AdaLang | 980 | 44.6% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 1217 | 55.4% |

Close to the 2026-08-19 run (55.8%/39.1% then), within this build's known
run-to-run variance.

## New finding: `null_paths`-family reporting-location convention differs by a few lines — confirmed benign, not a bug

`Empty_Then_Body` (6 findings), `Empty_Else_Body` (1), `Empty_Elsif_Body`
(2), and `Null_Case_Alternative` (11) all showed 0% GNATcheck-side match on
this corpus — 20 findings total, none apparently matched. Investigated each
one directly rather than accepted at face value, given `FP-059` had just
been found this same way on `ada_drivers_library`.

**Not a repeat of `FP-059`.** Every one of the 20 is a genuine empty
branch/alternative (a bare `null;`, sometimes preceded by a comment) — none
involve `pragma Assert` or any other non-obvious content.

**The real explanation: GNATcheck's `null_paths` reports at the empty
statement's own line; AdaLang's whole `Empty_*_Body`/`Null_Case_Alternative`
family reports at the branch/alternative's *start* line** (the `if`/`elsif`/
`else`/`when` keyword, consistent with how `Report_Rule_Violation` is called
with the branch node itself, not its statement list). A multi-line condition
or an intervening comment widens the gap. Examples, confirmed by direct
inspection of the source at both locations:

- `gnatcoll-config.adb:207` (AdaLang, the `if`) vs. `:209:13` (GNATcheck,
  the `null;` two lines down, past a comment).
- `gnatcoll-config.adb:210` (AdaLang, the `elsif`) vs. `:216:13` (GNATcheck,
  the `null;` six lines down, past a three-line multi-line condition).
- `gnatcoll-json.adb:176` (AdaLang, `when ' ' | ASCII.HT | ... =>`) vs.
  `:177:19` (GNATcheck, the `null;` one line down).

Verified systematically, not just by these three samples: every one of the
20 findings has a GNATcheck `null_paths` finding in the *same file* within 5
lines (a small Python cross-check against both tools' raw output, not just
manual spot-checking). This is the same class of finding this project has
already documented and deliberately not "fixed" twice before — the
spec-line-vs-body-line split (`Too_Many_Parameters`/`maximum_parameters`)
and the subprogram-vs-statement granularity split
(`No_Multiple_Return`/`improper_returns`), both first found on this same
corpus's 2026-08-19 run. Both tools agree on *what* is empty; only *where*
they report it about the empty statement's containing branch differs. Not
changed here, for the same reason those weren't: AdaLang's convention
(report at the branch itself, matching `Empty_If_Body`'s original design)
is a deliberate, internally-consistent choice, not an accident to correct
against GNATcheck's different one.

## Caveats

Same caveats as every prior run apply unchanged (line-granularity matching,
rule pairs are name-level matches not proven semantic equivalence).
