# gnatcoll-core: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Third run of the GNATcheck oracle comparison (see
`benchmarks/sparknacl/RESULTS_gnatcheck_2026-08-19.md` and
`benchmarks/aws/RESULTS_gnatcheck_2026-08-19.md` for the first two), and
the second on ordinary, non-SPARK, real-world Ada. Ran clean end-to-end
with no crash (unlike the AWS run, which hit an unidentified stack
overflow near the end) — the first run so far that completed without
needing a completeness caveat. Confirms both of AWS's headline findings on
an independent, structurally different corpus (a general-purpose utility
library rather than a web server), and surfaces one new reporting-location
variant AWS's smaller sample didn't expose.

## Environment

- Corpus: AdaCore/gnatcoll-core at `9f6ffb394793b0ac098fb1e9b206a659680788b3`
  (`GNATCOLL_REVISION`), 235 `.adb`/`.ads` files under `core/` and
  `minimal/`; 154 files actually analyzed by AdaLang under
  `core/gnatcoll_core.gpr` (the rest are withed but out of the project's
  own source list, or not visited under the mapped-rule subset).
- AdaLang Analyzer: commit `8cb0553be2bb5c041cf2ec3a5271b8b52cad1a44`.
- GNATcheck: `gnatcheck 27.0w`, same from-source local build as the prior
  two runs (see `project_gnatcheck_acquisition.md`).
- Rule map / comparator: `benchmarks/gnatcheck_rule_map.tsv` /
  `benchmarks/gnatcheck_compare.awk`, unchanged. `recursive_subprograms`/
  `No_Recursion` excluded as in every prior run.
- Reproduce: `GNATCOLL_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/gnatcoll/run_gnatcheck.sh`.

## Run completeness: clean, no crash

`gnatcheck.status` is `1` (findings emitted, not an error). Unlike AWS,
this run did not hit the unidentified stack-overflow crash class near the
end — the full mapped-rule set ran to completion on this corpus. This is
the first GNATcheck-oracle run in this series with no completeness caveat
at all.

## Totals (31 AdaLang rules / 34 GNATcheck rules)

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 1870 | |
| &nbsp;&nbsp;matched by GNATcheck | 1044 | 55.8% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 826 | 44.2% |
| GNATcheck findings (mapped rules) | 2665 | |
| &nbsp;&nbsp;matched by AdaLang | 1042 | 39.1% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 1623 | 60.9% |

Full per-rule table: `benchmark-results/gnatcoll/gnatcheck-comparison.txt`
from the run this document reports (not committed — `benchmark-results/`
is git-ignored; re-run the script to regenerate it).

As with AWS, the raw totals overstate genuine disagreement. Investigating
the largest gaps shows most of the shortfall repeats AWS's own two
explained effects, plus one new variant of the reporting-location pattern.

## Finding 1 (confirms AWS): spec/body reporting-location mismatch, `Too_Many_Parameters`/`maximum_parameters`

`Too_Many_Parameters`: 23 AdaLang findings, 0 matched. `maximum_parameters`:
197 GNATcheck findings, 0 matched. Same root cause as AWS's Finding 1,
confirmed directly: e.g. `gnatcoll-arg_lists.ads:111:14` is where GNATcheck
flags a 5-parameter subprogram's **specification**; AdaLang's matching
finding for the corresponding body is elsewhere. GNATcheck's
`maximum_parameters` consistently fires at the `.ads` declaration line
across the sampled findings (`gnatcoll-asserts.ads:57`, `:77`, `:130`,
`:143`, ...); AdaLang fires at the `.adb` body. Same effect, same
conclusion as AWS: both tools substantively agree these subprograms have
too many parameters, the comparator's exact-line matching just can't
reconcile a spec/body split.

## Finding 2 (new variant): subprogram-level vs. statement-level reporting granularity, `No_Multiple_Return`/`improper_returns`

`No_Multiple_Return`: 333 AdaLang findings, 0 matched. `improper_returns`:
669 GNATcheck findings, 0 matched — both mapped rules' single largest
unmatched pair in this run. Investigated directly:
`gnatcoll-arg_lists.adb`'s nested `function Process (A : String) return
Argument_Type` (declared at line 85, containing two `return` statements at
lines 94 and 166-ish) gets **one** AdaLang finding at line 85 (`"subprogram
has 2 return statements"` — reported once, at the subprogram's own
declaration line) and **one** GNATcheck finding at line 94 (`"extra return
statement"` — reported at the location of each return beyond the first,
not at the subprogram header). This is a reporting-*granularity*
difference, not a spec/body split (both are in the same file): AdaLang
summarizes "this subprogram has N returns" once per subprogram; GNATcheck
reports once per excess return statement. Neither convention is wrong, and
both tools agree Process has multiple returns — but `(file, line, rule)`
matching treats "line 85" and "line 94" as unrelated locations, so this
entire rule pair reads as 0% matched even where both tools agree in
substance. This is a distinct pattern from AWS's Finding 1 spec/body split
and from Finding 1 above (which is also present here for
`Too_Many_Parameters`), worth folding into the same "line-granularity
matching can't reconcile a reporting-convention difference" caveat family
in a future `gnatcheck_compare.awk` follow-up.

## Finding 3 (confirms AWS Finding 3, already resolved): `Missing_Global_Contract` fires on code with zero `SPARK_Mode` markings

121 AdaLang findings, 0 GNATcheck matches (`spark_procedures_without_globals`
found 0 here too). `grep -rl SPARK_Mode` across `core/` and `minimal/`
returns no matches — gnatcoll-core, like AWS, sets `SPARK_Mode` nowhere.
This is the exact same behavior AWS's run already investigated and
confirmed intentional (the "readiness" framing — flagging what a Global
contract would need to say if SPARK were adopted, not a compliance check
gated on adoption having already happened; see AWS's
`RESULTS_gnatcheck_2026-08-19.md` Finding 3 for the full investigation and
the `-list-checks` wording fix already applied). No new investigation
needed here; this is corroborating evidence the behavior is consistent
across a second, independently-authored corpus, not a new gap.

## What matched cleanly

`Magic_Number`/`numeric_literals`: AdaLang 493, GNATcheck 578, 97%
AdaLang-side match — the strongest pair again, consistent with both prior
runs (91% sparknacl, 89% AWS). `No_Access_To_Subp_Def`/`subprogram_access`:
95% AdaLang-side match (39 AdaLang findings, all but 2 matched) — close to
AWS's 100%, the second strongest direct-match rule across all three runs.
`Exception_Swallowed`/`silent_exception_handlers` and
`Empty_Exception_Handler` both show 100% AdaLang-side match at small
volume, consistent with the pattern of small, well-defined direct-match
rules agreeing cleanly. `Naming_Convention`/`min_identifier_length`:
69%/66% — same loop-index/parameter-name split documented in sparknacl and
AWS, at yet another sample size, no new surprises.
`Cyclomatic_Complexity`/`metrics_cyclomatic_complexity` shows the same
default-threshold-gap shape as sparknacl and AWS: 100% AdaLang-side match
but only 34% GNATcheck-side (GNATcheck reports 202 to AdaLang's 69 — most
of the extra 133 are subprograms in the threshold band GNATcheck's default
reaches and AdaLang's doesn't), not a logic disagreement.

## Caveats

- **Line-granularity matching** (see sparknacl's and AWS's `RESULTS_*.md`)
  applies here too, and Finding 2 above is a new demonstration of it: a
  subprogram-vs-statement reporting-granularity split is just as invisible
  to `(file, line, rule)` matching as AWS's spec/body split, even within a
  single file.
- Same rule-map caveats as the prior two runs: `No_Pragma`/
  `Forbidden_Pragmas` excluded, rule pairs are name-level matches from
  `GNATCHECK_RULE_COMPARISON.md`, not proven semantic equivalence.
- **Resolved (2026-08-19, follow-up session).** `Address_Clause`/its three
  GNATcheck counterparts originally showed 5 AdaLang findings, 6 GNATcheck
  findings, zero overlap in either direction. Investigated directly: five
  of the six were a reporting-location convention difference already
  established for other rule pairs (GNATcheck's
  `address_specifications_for_local_objects` reports at the object
  declaration's own line — e.g. `gnatcoll-email-utils.adb:1514` — AdaLang
  at the `for X'Address use ...;` clause's line a few lines later, e.g.
  `:1517`) — not a bug. The sixth, `gnatcoll-os-fs.adb:166`
  (`Result : T with Import, Convention => Ada, Address => Buffer'Address;`),
  was a genuine miss: that address specification uses aspect syntax
  (`with ..., Address => ...;`), which `Address_Clause` never handled,
  only the `for X'Address use ...;` clause form. Fixed in
  `src/adalang_analyzer-checks.adb` (logged as `FP-054` in
  `quality/known_analysis_issues.tsv`), with two new precision-corpus
  regression cases. Re-running this corpus post-fix: the previously-missed
  finding now appears at the exact same line GNATcheck reports, turning a
  total miss into an exact match; the other five remain an unresolved
  reporting-location caveat (not this fix's target).
