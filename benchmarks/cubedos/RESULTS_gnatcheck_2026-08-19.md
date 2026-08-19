# CubedOS: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Fifth run of the GNATcheck oracle comparison (after sparknacl, aws,
gnatcoll-core, ada_drivers_library). First SPARK corpus with real tasking
(`Message_Manager` mailboxes, per-module task bodies) since
ada_drivers_library's non-SPARK drivers, and the first run to hit a
project-embedded GNATcheck rule configuration that had to be explicitly
overridden to keep the comparison consistent with every other corpus here.

## Environment

- Corpus: cubesatlab/cubedos at `c402301000a5a92237e0f7ab106186a48273cf24`
  (`CUBEDOS_REVISION`), 69 `.adb`/`.ads` files under `src/` (65 got at
  least one GNATcheck finding; AdaLang's own `--checks=` lane reports 49
  analyzed files, matching the `FP-040` undercount already documented for
  `--verify` in `benchmarks/cubedos/README.md` — the rule-checking lane
  used here is a different code path from `--verify`, so this number is
  reported for context, not claimed as independently confirming or
  contradicting FP-040).
- AdaLang Analyzer: commit `8cb0553be2bb5c041cf2ec3a5271b8b52cad1a44`.
- GNATcheck: `gnatcheck 27.0w`, same from-source local build as prior runs.
- Rule map / comparator: `benchmarks/gnatcheck_rule_map.tsv` /
  `benchmarks/gnatcheck_compare.awk`, unchanged. `recursive_subprograms`/
  `No_Recursion` excluded as in every prior run.
- Reproduce: `CUBEDOS_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/cubedos/run_gnatcheck.sh`.

## Methodology fix required: `cubedos.gpr`'s own embedded GNATcheck rule file

`src/cubedos.gpr` declares `package Check use Default_Switches ("ada")
use ("-rules", "-from=cubedos-rules.txt")`, which GNATcheck loads
automatically from any `-P` invocation unless told not to. Several of its
rule names (`too_many_dependencies`, `metrics_cyclomatic_complexity`,
`improper_returns`, `maximum_parameters`, `overly_nested_control_
structures`, `goto_statements`, `null_paths`, plus `style_checks`/
`identifier_casing` variants not in the shared rule map) collided with
this benchmark's own command-line `-r` flags, producing "cannot add rule
instance ... already instantiated" errors and (empirically, from a
before/after count comparison) actually changing several rules' effective
configuration/results, not just producing cosmetic noise — e.g.
`maximum_parameters` findings dropped from 68 to 43 once fixed. Fixed by
adding `--ignore-project-switches` to the GNATcheck invocation, so this
run's rule set is exactly `gnatcheck_rule_map.tsv`'s, with no
CubedOS-specific configuration mixed in — the same reasoning
`benchmarks/cubedos/run.sh`'s GNATprove lane already applies by picking an
explicit `--level=4` rather than `cubedos.gpr`'s unset default `Prove`
package. This is the first corpus in the series with its own
project-embedded GNATcheck configuration; none of the prior four had one.

## Run completeness: one crash, run otherwise complete

`gnatcheck.status` is `2`. One `STORAGE_ERROR: stack overflow`
(`"unparsable worker output"`), same crash class as AWS and
ada_drivers_library, occurring at the very start of the captured output
(before any violation lines) rather than near the end — consistent with a
single early worker crash in a parallel batch, not a run-ending abort:
processing continued afterward for all 65 files with recorded findings
(651 total lines in `gnatcheck.txt`). The exact crashing file/rule remains
unidentified, same open problem as the two prior occurrences.

## Totals (31 AdaLang rules / 34 GNATcheck rules)

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 182 | |
| &nbsp;&nbsp;matched by GNATcheck | 156 | 85.7% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 26 | 14.3% |
| GNATcheck findings (mapped rules) | 617 | |
| &nbsp;&nbsp;matched by AdaLang | 156 | 25.3% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 461 | 74.7% |

Full per-rule table: `benchmark-results/cubedos/gnatcheck-comparison.txt`
from the run this document reports (not committed — `benchmark-results/`
is git-ignored; re-run the script to regenerate it).

CubedOS's small size (69 files) makes its AdaLang-side match rate (85.7%)
the highest of any corpus so far, but the raw GNATcheck-side rate is
dominated by the same threshold/reporting-convention effects already
documented on the prior three real-code corpora.

## Resolved: `Exception_Propagation` finds nothing on task bodies GNATcheck flags — explained, not a bug

`Exception_Propagation`: **0** AdaLang findings on this corpus at all.
`exception_propagation_from_tasks`: **8** GNATcheck findings, all
unmatched — e.g. `cubedos-time_server-messages.adb:169:14` and `:289:14`,
inside `task body Send_Tick_Messages`, a real Ravenscar task body with a
`delay until` loop calling `Series_Database.Next_Ticks` (a protected
operation). This file has `pragma SPARK_Mode (On)` at line 7, so the
earlier AWS-established SPARK-readiness-default explanation doesn't apply
here — the code genuinely is SPARK-enabled and the check is still silent.

**Root-caused by reading the check's implementation**
(`src/adalang_analyzer-checks.adb` `Analyze_Automotive_Call`/
`Has_Exception_Boundary`, `src/adalang_analyzer-subprogram_summaries.adb`
`Callee_May_Raise`/`Scan_Effects`) and the actual `cubedos` source, not
just the numbers:

1. `Has_Exception_Boundary` is walked correctly for this call — `task body
   Send_Tick_Messages` (declared directly in the package body's top-level
   declarative part, not nested in a block) has no exception handler of
   its own, and the walk-up correctly finds none, so this is not what
   suppresses the finding.
2. `Exception_Propagation`'s own report message is explicit about its
   scope: *"call may propagate an **explicitly raised** exception"* — it
   fires only when the callee is proven, by tracing an `Ada_Raise_Stmt`
   directly or transitively through AdaLang's own call-graph summaries
   (`Callee_May_Raise` → `Summaries(...).May_Raise`, built by
   `Scan_Effects`/`Complete`), not on any theoretically-possible runtime
   exception (`Constraint_Error` and friends).
3. **`grep -rn "raise\b" src/` across this entire corpus (excluding
   gnatcheck's own build artifacts) returns zero matches** — there is no
   `raise` statement anywhere in cubedos's own source, at any depth,
   including `Next_Ticks`'s own body and its full call chain
   (`Route_Message`, `Tick_Reply_Encode`, `Unchecked_Send`, `Send`, all
   checked directly, no `raise` in any of them). AdaLang's `Exception_
   Propagation` is therefore correctly silent: there is nothing explicitly
   raised anywhere in the analyzed sources for it to trace.

GNATcheck's `exception_propagation_from_tasks` is evidently **not** scoped
to explicit raises the same way — it fires on all 8 of these calls despite
zero explicit `raise` statements existing in the corpus, meaning it must be
flagging task-body calls more conservatively (e.g. on any call lacking a
local handler, or including implicit/runtime-check exceptions), a
fundamentally broader definition of "propagation risk" for task bodies
specifically. This is the same "different tools, different definition of
what counts as inadequately guarded" family as AWS's `Exception_
Propagation`-vs-narrow-GNATcheck-rules finding and coap_spark's `Depends`-
without-`Global` finding — not a coverage bug, a genuine, now-confirmed
scope difference, and this comparison's "Close" label for this pairing
(`GNATCHECK_RULE_COMPARISON.md`) undersells the gap in the same way AWS's
Finding 2 already established for the non-task-specific counterparts.

**Side discovery during this investigation, since fixed**: `Has_
Exception_Boundary`'s walk-up stopped at `Ada_Subp_Body` but had no
equivalent stop for `Ada_Task_Body`. This did not cause this corpus's
gap (see point 1 above — the walk from a task body declared directly in a
package body's declarative part never reaches a sibling scope's `Handled_
Stmts`, so it correctly returned `False` regardless), but it was a real,
separately-realizable soundness gap: a task body declared inside a nested
`declare` block, itself inside a subprogram/task/package's own guarded
statement part, would have its walk-up continue past the task body into
that lexically-enclosing scope and find its handler — incorrectly treating
it as a boundary, even though a task executes on its own thread of control
and an enclosing subprogram's handler can never catch an exception raised
during the task's own independent execution. Not exercised by any corpus
in this series (no task bodies nested in blocks were found), but confirmed
directly with a minimal fixture reproducing exactly this shape before
fixing it. Fixed in `src/adalang_analyzer-checks.adb`'s
`Has_Exception_Boundary` (stop at `Ada_Task_Body` the same way it already
stopped at `Ada_Subp_Body`), with a new precision-corpus regression pair
(`tests/precision_exception_propagation_task_guard.adb` /
`_task_clean.adb`, wired into `quality/precision_corpus.tsv`) confirming
both the fix and that it doesn't overreach. Logged as
`FP-053` in `quality/known_analysis_issues.tsv`.

## Confirms prior runs' explained effects

**Default-threshold gap, `Too_Many_Parameters`/`maximum_parameters` (0 vs.
43, all in the 4-5-parameter band).** Sampled directly:
`ada_containers-aunit_lists.ads:87` (4 params), `aunit-run.adb:37` (5
params) — all below AdaLang's 7+ default, all above GNATcheck's 4+ default,
same shape as sparknacl/AWS/gnatcoll-core, not re-investigated further.
Many of the affected files are AUnit's own bundled test framework sources
(pulled in because `--ignore-project-switches` still analyzes
`cubedos.gpr`'s full `check`/`modules` source dirs, same project either
tool is given), not CubedOS's own flight code specifically.

**Strongest matches**: `Magic_Number`/`numeric_literals` 97% AdaLang-side
(104/107, highest of any corpus so far) and `Naming_Convention`/
`min_identifier_length` 93% AdaLang-side — both consistent with, and
slightly stronger than, the pattern established on all four prior corpora.

## Caveats

- ~~`Exception_Propagation` finding above is a real open question, not yet
  investigated to a root cause~~ — **resolved** (see "Resolved:
  `Exception_Propagation`..." above): root-caused to a genuine, confirmed
  scope difference between the two tools, not an analyzer defect. This
  caveat was left stale from before that section was written.
- **`--ignore-project-switches` changes this run's methodology slightly
  from a "real CubedOS CI GNATcheck invocation"** — deliberate, for
  cross-corpus consistency (see above), but means this run does not
  reflect what CubedOS's own `cubedos-rules.txt` would report.
- **Run completeness not independently re-confirmed** (one early crash,
  processing appears to have continued normally afterward, not re-run to
  verify).
- **Line-granularity matching** and **rule pairs are name-level, not
  proven-semantically-equivalent** — same caveats as every prior run.
- Per `benchmarks/cubedos/README.md`, this corpus is **not fully proved**
  by GNATprove either, unlike sparknacl — that caveat is specific to the
  `--verify`/GNATprove comparison, not this GNATcheck rule-oracle one, but
  is worth keeping in mind when interpreting CubedOS results generally.
