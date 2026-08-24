# CubedOS: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Second run, part of the 2026-08-24 batch re-run across all ten corpora
following the `Empty_Then_Body`/`Empty_Else_Body` addition and the `FP-059`
fix (see `benchmarks/ada_drivers_library/RESULTS_gnatcheck_2026-08-24.md`).

## Environment

- Corpus: cubesatlab/cubedos at `c402301000a5a92237e0f7ab106186a48273cf24`
  (`CUBEDOS_REVISION`), unchanged from the 2026-08-19 run.
- AdaLang Analyzer / GNATcheck / rule map: same as
  `ada_drivers_library/RESULTS_gnatcheck_2026-08-24.md`.
- Reproduce: `CUBEDOS_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/cubedos/run_gnatcheck.sh`.

## Reproduction gotcha: do not pre-wrap this script in your own `alr exec`

Unlike every other corpus's `run_gnatcheck.sh`, CubedOS's own script has
real setup logic (resolving `aunit.gpr` through a throwaway local Alire
crate) inside its `if [ "${ALIRE:-}" != "True" ]` guard, not just the bare
re-exec every other script's guard contains. Invoking it as `alr exec -- sh
benchmarks/cubedos/run_gnatcheck.sh` (the pattern that works for every other
corpus in this batch) sets `ALIRE=True` *before* the script's own guard
runs, so the script's own re-exec check evaluates false and the whole aunit
setup block is silently skipped — the first attempt this way failed at
GNATcheck project-loading with `imported project file "aunit.gpr" not
found`, and produced a spurious 0-finding, 0.0%-match "comparison" instead
of erroring loudly. Fixed by invoking the script directly in a plain shell
(`sh benchmarks/cubedos/run_gnatcheck.sh`, no `alr exec` wrapper) and
letting it perform its own internal re-exec, as documented in its own
header comment. Not a script bug — the script already documents this
constraint; this was a reproduction mistake worth recording so it isn't
repeated.

## Totals

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 182 | |
| &nbsp;&nbsp;matched by GNATcheck | 149 | 81.9% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 33 | 18.1% |
| GNATcheck findings (mapped rules) | 491 | |
| &nbsp;&nbsp;matched by AdaLang | 149 | 30.3% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 342 | 69.7% |

Close to the 2026-08-19 run (85.7%/25.3% then), within this build's known
run-to-run variance.

## `Empty_Then_Body`/`Empty_Else_Body`/`Empty_Elsif_Body`/`Null_Case_Alternative` results

All four report **0 findings** on this corpus, both sides — consistent with
the 2026-08-19 run's `Empty_If_Body`/`Empty_Elsif_Body` also showing 0/0
here.

## Caveats

Same caveats as the 2026-08-19 run apply unchanged (project-embedded rule
configuration required `--ignore-project-switches`; `Exception_Propagation`
finding nothing on task bodies is explained, not a bug, see the
2026-08-19 run).
