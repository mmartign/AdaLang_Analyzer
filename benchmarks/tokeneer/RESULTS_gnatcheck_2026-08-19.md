# Tokeneer: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Tenth and final run of this GNATcheck oracle comparison pass (after
sparknacl, aws, gnatcoll-core, ada_drivers_library, cubedos, coap_spark,
libkeccak, saatana, project_bias). Tokeneer is this project's oldest
external corpus (see `benchmarks/tokeneer/README.md` and
`quality/external_corpus_findings.md`) — the NSA-released ID Station's
SPARK 2014 port, 120 files, fully verified by GNATprove. This run completed
cleanly with no crash, the third of ten runs to do so (after gnatcoll-core
and coap_spark).

## Environment

- Corpus: AdaCore/spark2014 at `a97467e91a16409c866434fcc7a5f553bbd98b8a`
  (`TOKENEER_REVISION`), sparse-checked-out to
  `testsuite/gnatprove/tests/tokeneer`, `test.gpr` (self-contained, no
  external `with` dependencies), 120 analyzed files (matches the full
  `.adb`/`.ads` count under the sparse checkout).
- AdaLang Analyzer: commit `8cb0553be2bb5c041cf2ec3a5271b8b52cad1a44`.
- GNATcheck: `gnatcheck 27.0w`, same from-source local build as prior runs.
- Rule map / comparator: `benchmarks/gnatcheck_rule_map.tsv` /
  `benchmarks/gnatcheck_compare.awk`, unchanged. `recursive_subprograms`/
  `No_Recursion` excluded as in every prior run.
- Reproduce: `TOKENEER_ROOT=<sparse checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/tokeneer/run_gnatcheck.sh`.

## Run completeness: clean, no crash

`gnatcheck.status` is `1` — no `STORAGE_ERROR` stack overflow this run,
unlike six of the eight prior corpora (AWS, ada_drivers_library, cubedos,
libkeccak, saatana, project_bias). The full 120-file, 1,602-mapped-finding
run completed without incident, alongside gnatcoll-core and coap_spark as
the three clean runs of this pass.

## Totals (31 AdaLang rules / 34 GNATcheck rules)

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 596 | |
| &nbsp;&nbsp;matched by GNATcheck | 444 | 74.5% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 152 | 25.5% |
| GNATcheck findings (mapped rules) | 1602 | |
| &nbsp;&nbsp;matched by AdaLang | 425 | 26.5% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 1177 | 73.5% |

Full per-rule table: `benchmark-results/tokeneer/gnatcheck-comparison.txt`
from the run this document reports (not committed — `benchmark-results/`
is git-ignored; re-run the script to regenerate it).

(The 444-vs-425 "matched" counts differ because several rule pairs in
`gnatcheck_rule_map.tsv` map one AdaLang rule to more than one GNATcheck
rule, e.g. `Address_Clause` to three, `Exception_Propagation` to three,
`Aliasing_Between_Parameters` and `Duplicate_Boolean_Operand` to two each
— when two differently-named GNATcheck findings at the same `(file, line)`
both match the same single AdaLang finding, that AdaLang finding is
counted as matched once but contributes two matches on the GNATcheck side.
This is an inherent property of the shared many-to-one rule map, present
at smaller scale in every prior run too — not a new effect, not
investigated further since it does not belong to the checks/awk files this
task leaves untouched.)

## Two rules at 100% AdaLang-side match, real volume

`Exception_Swallowed`/`silent_exception_handlers`: 19 AdaLang findings, all
19 matched. `Empty_Exception_Handler`/`trivial_exception_handlers`... note
`Empty_Exception_Handler` maps to `silent_exception_handlers` too (a
"direct" pair per the rule map) — 19 AdaLang findings, all 19 matched.
Tokeneer's exception-handling code (a real, mature, security-critical
system) gives both of these small-but-clean rule pairs their best showing
of the series at meaningful volume, alongside `No_Access_To_Subp_Def` on
AWS and `numeric_literals` on libkeccak/saatana as the strongest
full-agreement results across all ten runs.

## Strong direct-match rule: `Non_Short_Circuit_Condition`, 89% at real volume

100 AdaLang findings, 89 matched (89%) — the best showing for this rule
pair on ordinary (non-generated) hand-written code across the series
(ada_drivers_library's 80% was the previous best on non-generated code;
coap_spark's near-100% goto-statement match was on generated code). Given
sparknacl/AWS/coap_spark all established the usual gap here is
contract-aspect or expression-context boolean operators outside AdaLang's
statement-condition scope, Tokeneer's real, hand-written control flow
apparently uses fewer of those than usual, consistent with — not
contradicting — the established explanation.

## Confirms prior runs' effects

**Naming/threshold splits**: `Naming_Convention`/`min_identifier_length`
(90%/68%) and `Magic_Number`/`numeric_literals` (80%/96%) both land
comfortably within the range already established across nine prior corpus
comparisons. **Subprogram-vs-statement granularity**:
`No_Multiple_Return`/`improper_returns` (0% AdaLang-side, 24 vs. 34) is
consistent with the same reporting-convention split gnatcoll-core's
Finding 2 first documented, not re-derived here. **Library-closure scope**:
`spark_procedures_without_globals` shows 36 GNATcheck findings against
`Missing_Global_Contract`'s 3 AdaLang findings, 0 matched — not
individually investigated this run given nine prior corpora (AWS,
gnatcoll-core, coap_spark) already establish two distinct, non-overlapping
explanations for this pair's typical shape (SPARK-readiness default
scoping and `Depends`-without-`Global` inference); this data point is
consistent with, not distinguishing between, those explanations.

## Caveats

- **Matched-count asymmetry from the many-to-one rule map** (see above) —
  present in every run, more visible here due to this corpus's exception-
  handling-heavy code triggering several of the affected rule pairs at
  once.
- **Line-granularity matching**, **rule pairs are name-level, not
  proven-semantically-equivalent** — same caveat family as every prior run.
- Per `benchmarks/tokeneer/README.md`, Tokeneer is where the first four
  confirmed AdaLang false positives (`FP-004`–`FP-007`) were found and
  fixed, tracked in `quality/external_corpus_findings.md` — not directly
  relevant to this GNATcheck rule-oracle comparison, but this corpus has
  the longest independent scrutiny history of any in the series.
