# Benchmarks

This directory validates AdaLang Analyzer against real, independently
authored Ada/SPARK codebases — not the hand-constructed fixtures in
`quality/precision_corpus.tsv`. Three kinds of validation live here:

- **Independent-oracle comparisons**: on a SPARK corpus GNATprove can fully
  prove, GNATprove's verdict becomes a trustworthy ground truth. Each
  obligation both tools evaluate at the same `(file, line, check kind)` is
  compared, sorted into whether the two tools agree, and — most
  importantly — whether AdaLang ever calls something safe that GNATprove
  could not prove (**possible unsoundness**) or calls something a definite
  error that GNATprove proved safe (**false positive**).
- **Real-code validation** where GNATprove can't serve as an oracle (an
  ordinary, non-SPARK codebase; a SPARK corpus with genuine unresolved
  GNATprove findings of its own) — these corpora instead exercise breadth
  (a large real project) or specific checks (concurrency-prohibition rules
  against real tasking code) that synthetic fixtures don't reach.
- **GNATcheck oracle comparison**: for the AdaLang rules with a
  direct/close GNATcheck counterpart (`GNATCHECK_RULE_COMPARISON.md`),
  GNATcheck's own findings on the same corpus become ground truth — an
  AdaLang finding with no matching GNATcheck finding at the same
  `(file, line)` is a potential false positive, and vice versa a potential
  false negative. Unlike the proof-obligation comparison above, this is
  matching two independently-implemented rule linters against each other,
  not verification results.

Every benchmark here is a `run.sh` + `README.md` (setup, toolchain notes,
pinned revision) + a dated `RESULTS_*.md` (the actual numbers, latest run
only — see `git log` for prior snapshots).

## Independent-oracle comparisons (GNATprove as ground truth)

| Corpus | Author | Domain | Matched pairs | Unsoundness | False positives |
| --- | --- | --- | ---: | ---: | ---: |
| [sparknacl](sparknacl/) | rod-chapman | NaCl-style crypto, fixed-width arithmetic | 924 | 0 | 0 |
| [saatana](saatana/) | HeisenbugLtd | Phelix stream cipher | 112 | 0 | 0 |
| [libkeccak](libkeccak/) | damaki | SHA-3/Keccak sponge family | 227 | 0 | 0 |
| [coap_spark](coap_spark/) | mgrojo | CoAP protocol parsing/session state | 1324 | 0 | 0 |
| [tokeneer](tokeneer/) | AdaCore/NSA | Access-control system (identification station) | 284 | 0 | 0 |
| [cubedos](cubedos/) | cubesatlab | Satellite message-passing bus (not fully proved) | 8 | 0 | 0 |
| [spark_testsuite](spark_testsuite/) | AdaCore | SPARK regression testsuite — 124 curated micro-tests, run per unit (90 fully-proved oracle + 34 deliberately-broken tripwire) | 427 | 0 | 0 |

**Across five independently-authored, fully-proved corpora (SPARKNaCl,
Saatana, libkeccak, coap_spark, Tokeneer) — 2,871 proof obligations both
tools could independently evaluate at the same location, spanning five
different authors/origins and five structurally different domains —
AdaLang has never once called something safe that GNATprove could not
prove, and never once called something a definite error that GNATprove
proved safe.** CubedOS's 8 matched pairs (not a fully-proved corpus, so a
weaker oracle) show the same zero-disagreement pattern on a much smaller
sample.

The `spark_testsuite` corpus is structurally different — 124 curated
single-purpose regression tests from the AdaCore SPARK testsuite, each
analyzed on its own generated project and compared individually (the
testsuite reuses filenames across thousands of directories, so a global
`(basename, line, kind)` match is not possible). Its 427 matched pairs
span nine scalar obligation kinds across far more distinct code shapes than
the six real projects reach; its value is that breadth, not the count. It
also carries 34 deliberately-broken units where GNATprove's own `medium`/
`high` verdict is the tripwire — AdaLang never once answered one of those
`proved-safe`. See `spark_testsuite/RESULTS_2026-10-02.md`. The first run
of this corpus found two analyzer defects (`FP-064`, `FP-065`), both fixed
with regression tests before it landed; the 2026-10-02 run found a third
(`FP-100`).

What this table doesn't show: AdaLang answers "I don't know"
(`Unproved`/`Unsupported`) far more often than GNATprove does on all six —
consistent with `POSITIONING.md`'s framing of `--verify` as "a much
narrower scalar subset," not a competitor to full SMT-backed proof. The
"both safe" share of each corpus's matched pairs varies a lot by code
style: sparknacl 79/924 (~9%), tokeneer 30/284 (~11%), libkeccak 76/227
(~33%), coap_spark 8/1324 (~0.6%) — coap_spark's RecordFlux-generated
protocol contracts and session-state logic remain the hardest code shape
for AdaLang's bounded verifier to independently prove, even though it
never gets one *wrong* there.

The 2026-10-02 refresh followed release 1.6.1, which fixed eleven
false-safe results that these comparisons could not show: on code that is
proved correct, a bogus proof agrees with the oracle. Its effect on the
`Proved_Safe` counts goes both ways. Results that rested on unsound
reasoning are withdrawn (the bounds of an array that no declaration fixes,
facts about objects across calls and loops), and what 1.6.1 added proves
more elsewhere: SPARKNaCl 3,913 to 4,584, coap_spark 3,257 to 3,755,
libkeccak 3,026 to 3,318, Saatana 178 to 319, and Tokeneer 2,030 to 2,010,
the one corpus that loses on balance (118 preconditions are no longer
proved). coap_spark's matched pairs rise from 853 to
942 because calls to subprograms completed by expression functions now
have precondition obligations (`FP-096`). The refresh was also the first
run of 1.6.1 on the non-SPARK corpora and on the SPARK testsuite, and found
three defects that release introduced: a `--verify` run time of 39 minutes
on AWS (159 s before, 69 s now) and two false `Definite_Error` results,
`FP-099` and `FP-100`. Each corpus's `RESULTS_2026-10-02.md` has the
details.

### How much of what GNATprove proves does `--verify` prove?

The table above only counts places where both tools have exactly one
obligation of a kind, which is the right sample for asking whether they
ever disagree and the wrong one for asking how far apart they are.
[`GNATPROVE_GAP_LEDGER_2026-10-05.md`](GNATPROVE_GAP_LEDGER_2026-10-05.md)
takes every check GNATprove proves on the five fully proved corpora, 15,043
of them once the repeats for generic instances are merged, and records
what AdaLang does with each:

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| Proves it | 4,299 | 28.6% |
| Has the obligation, leaves it unproved | 6,317 | 42.0% |
| Has the obligation, calls it unsupported | 1,306 | 8.7% |
| Has no obligation of that kind at that place | 1,496 | 9.9% |
| Has no obligation of that kind at all | 1,416 | 9.4% |
| Raises nothing in that file | 209 | 1.4% |

The ledger has already paid for itself several times. Its first run led to
`FP-104`: obligations written in a specification were reported under the
body's file name, so 949 of them could not be paired with GNATprove's
checks. It then showed that the largest group without an AdaLang obligation
was initialization, which GNATprove reports once per object: `--verify` now
checks each `out` parameter at its subprogram's exit, and the ledger sets
GNATprove's one check against all of AdaLang's obligations about the same
object. The next largest group AdaLang could reach was the bounds of a
slice, for which `--verify` now raises a range check where GNATprove does,
and after it the actual parameters, checked against the subtype of their
formal. Preparing that last one turned up three faults in the checks that
were already there (`FP-106` to `FP-108`), two of them false-safes that a
comparison on proved code cannot show: a check AdaLang wrongly proves
agrees with GNATprove there.

The ledger then showed that two fifths of what was still missing was not a
run-time check at all: termination, and the `Global` and `Depends` aspects.
`--verify` now has an obligation for each. Termination is proved from the
body (bounded loops, no recursion, callees that terminate): 990 of
GNATprove's 1,169. A `Global` aspect is proved from an over-approximation
of what the body touches: 595 of 696. A `Depends` aspect has its obligation
and no route to prove it yet. Last, expression functions are verified as
subprograms, and the checks inside preconditions and postconditions are
obligations of their own, which brought in most of what was missing in
specifications.

Before all of this AdaLang proved 433 of the 15,043 checks and had an
obligation for 5,954; with those additions it proved 3,018 and had one for
11,922. What is left without one, 3,121 checks, is mostly kinds AdaLang
does not have (predicate, length, pointer-dereference and discriminant
checks, memory leaks) and range, index and precondition checks at places it
does not yet look.

With an obligation for four checks in five, the question became how many
of them are proved. The largest group that was not was the precondition of
a call, 2,938 checks of which AdaLang proved 24: contracts speak through
functions of records and private objects (`Has_Buffer (Ctx)`), which the
scalar language of the provers could not express. A call to a function of
its arguments is now a term; a procedure call with known effects leaves
what is known of the caller's own scalars; and a callee's postcondition is
assumed after the call. With that AdaLang proved 479 of those
preconditions and 3,536 of the 15,043 checks, 518 more, with the same
obligations. Reading the checks that were there before building on them
turned up three more false-safes (`FP-109` to `FP-111`): a guard that
survived a state-changing call in its own condition, solver symbols named
without their file, and a loop-invariant proof that stepped over the calls
in the loop body.

The next 763 came from asking, check by check, what stood in the way, and
finding it was seldom the proof. Generated code writes every name with its
package in front of it, and such a name was outside the language of the
provers: once `RFLX.CoAP.CoAP_Message.F_Ver` is the literal it names, the
largest corpus has 599 of its 2,294 preconditions proved where it had 391.
A named number was an object with no value, and `Byte'Size` an attribute
nobody knew: with the first its value and the second the eight bits RM
13.3(55) gives it, the divisions by them are proved, 643 of GNATprove's 809
where there were 259.
And a subprogram was given up whole for a loop with a name, for a `goto`
to a label further down or for a quantified loop invariant, none of which
needs more than an edge in the graph: 1,306 checks are unsupported where
2,324 were, none of them in Saatana and two in libkeccak. AdaLang now
proves 4,299 of the 15,043 checks and 687 of the 2,938 preconditions. The
checks read on the way had four more faults: `FP-112`, the prefix of `'Old`
checked in the state at the exit; `FP-113`, modular arithmetic in a bound
that did not wrap; `FP-114`, a definite error recorded from a state that
had not settled; and `FP-115`, an object named `True` taken for the
literal. What keeps the remaining 1,306 outside is an explicit dereference,
an allocator or a generic instantiation in the subprogram; what the
remaining preconditions need is still the definition of the functions
their contracts call and the predicate of the type they are about.

In the other direction the record holds: AdaLang proves none of the 22
checks GNATprove leaves unproved there, and reports no definite error on a
check GNATprove proves. `benchmarks/gnatprove_gap_ledger.py` regenerates
the ledger from the lanes' results.

## Real-code validation (no GNATprove oracle)

| Corpus | Author | Domain | Purpose |
| --- | --- | --- | --- |
| [aws](aws/) | AdaCore | Ada Web Server, ordinary (non-SPARK) Ada | Breadth on a large real project; GNATprove never gets past a pre-existing legality error; also the corpus with genuine unrestricted `select`/`requeue`/`abort` for the `--automotive` concurrency-prohibition checks |
| [ada_drivers_library](ada_drivers_library/) | AdaCore | STM32 bare-metal hardware drivers | Real Ravenscar `protected`-object code for the `--automotive` concurrency-prohibition checks (no `select`/`requeue`/`abort` — see aws) |
| [gnatcoll](gnatcoll/) | AdaCore | GNAT Components Collection core (JSON, VFS, strings, email, OS/process), ordinary (non-SPARK) Ada | A third breadth corpus in a new domain (general-purpose utility library); GNATprove hard-stops on a SPARK-illegal aspect 41 units in |
| [project_bias](project_bias/) | EliAvila10 | Bias-free cryptographic random streams | Small SPARK corpus emphasizing floating-point contracts, quantified array predicates, OS/C bindings, and entropy-buffer clearing; GNATprove reports one flow error, so it is not a fully-proved oracle (31 matched pairs, 0 unsoundness, 0 false positives — corroborates without counting toward the table above) |

## GNATcheck oracle comparison

GNATcheck has no Alire package and no prebuilt download; the binary used
here was built from source and exists only on the machine it was built on
(rebuilding it is a real undertaking on its own — see
`quality/known_analysis_issues.tsv` and this project's own notes for
anyone repeating this). Shared infrastructure for every corpus's GNATcheck
lane: `benchmarks/gnatcheck_rule_map.tsv` (the rule-pair map) and
`benchmarks/gnatcheck_compare.awk` (the comparator, matching on
`(basename(file), line, rule pair)`).

| Corpus | AdaLang findings | Matched by GNATcheck | GNATcheck findings | Matched by AdaLang |
| --- | ---: | ---: | ---: | ---: |
| [sparknacl](sparknacl/RESULTS_gnatcheck_2026-10-05.md) | 5637 | 5403 (95.8%) | 5847 | 5403 (92.4%) |
| [aws](aws/RESULTS_gnatcheck_2026-10-05.md) | 46716 | 42939 (91.9%) | 125491 | 42940 (34.2%) |
| [gnatcoll-core](gnatcoll/RESULTS_gnatcheck_2026-10-05.md) | 23540 | 21620 (91.8%) | 25014 | 21620 (86.4%) |
| [ada_drivers_library](ada_drivers_library/RESULTS_gnatcheck_2026-10-05.md) | 7204 | 6581 (91.4%) | 7300 | 6581 (90.2%) |
| [cubedos](cubedos/RESULTS_gnatcheck_2026-10-05.md) | 2034 | 1891 (93.0%) | 4283 | 1891 (44.2%) |
| [coap_spark](coap_spark/RESULTS_gnatcheck_2026-10-05.md) | 13404 | 12422 (92.7%) | 43529 | 12422 (28.5%) |
| [libkeccak](libkeccak/RESULTS_gnatcheck_2026-10-05.md) | 5511 | 5288 (96.0%) | 5600 | 5288 (94.4%) |
| [saatana](saatana/RESULTS_gnatcheck_2026-10-05.md) | 1089 | 995 (91.4%) | 1028 | 995 (96.8%) |
| [project_bias](project_bias/RESULTS_gnatcheck_2026-10-05.md) | 1846 | 1752 (94.9%) | 1897 | 1752 (92.4%) |
| [tokeneer](tokeneer/RESULTS_gnatcheck_2026-10-05.md) | 6804 | 6620 (97.3%) | 7856 | 6620 (84.3%) |

These totals include the 158 rule pairs of the opt-in coding-standard
checks: 153 added to the lane on 2026-10-04 and five on 2026-10-05 (the
other 17 coding-standard checks report nothing until configured and are not
in the rule map). Each results
file also shows the totals for the pairs that were already compared on
2026-09-24, next to the numbers of that run.

For the coding-standard checks alone, counted over the files both tools
analysed:

| Corpus | AdaLang findings | Matched by GNATcheck | GNATcheck findings | Matched by AdaLang |
| --- | ---: | ---: | ---: | ---: |
| [sparknacl](sparknacl/RESULTS_gnatcheck_2026-10-05.md) | 3651 | 3651 (100.0%) | 3651 | 3651 (100.0%) |
| [aws](aws/RESULTS_gnatcheck_2026-10-05.md) | 39478 | 39358 (99.7%) | 39520 | 39358 (99.6%) |
| [gnatcoll-core](gnatcoll/RESULTS_gnatcheck_2026-10-05.md) | 20357 | 20342 (99.9%) | 20355 | 20342 (99.9%) |
| [ada_drivers_library](ada_drivers_library/RESULTS_gnatcheck_2026-10-05.md) | 6344 | 6157 (97.1%) | 6165 | 6157 (99.9%) |
| [cubedos](cubedos/RESULTS_gnatcheck_2026-10-05.md) | 1623 | 1623 (100.0%) | 1624 | 1623 (99.9%) |
| [coap_spark](coap_spark/RESULTS_gnatcheck_2026-10-05.md) | 10331 | 10330 (100.0%) | 10330 | 10330 (100.0%) |
| [libkeccak](libkeccak/RESULTS_gnatcheck_2026-10-05.md) | 3659 | 3659 (100.0%) | 3659 | 3659 (100.0%) |
| [saatana](saatana/RESULTS_gnatcheck_2026-10-05.md) | 862 | 861 (99.9%) | 861 | 861 (100.0%) |
| [project_bias](project_bias/RESULTS_gnatcheck_2026-10-05.md) | 1459 | 1459 (100.0%) | 1459 | 1459 (100.0%) |
| [tokeneer](tokeneer/RESULTS_gnatcheck_2026-10-05.md) | 6007 | 6007 (100.0%) | 6007 | 6007 (100.0%) |

Across the ten corpora that is 93771 AdaLang findings, of which GNATcheck
reports 93447 (99.7%) at the same file and line, against 93631 GNATcheck
findings (99.8% matched). What remains has these causes, set out in the
results files:

- **Generic instances.** For rules that follow instantiations GNATcheck
  also reports inside the instances of generic units; AdaLang reports on
  the generic's own source only.
- **Ada_Drivers_Library's synthetic projects.** That lane analyses projects
  written for the benchmark, which do not import what the drivers depend
  on, so many names do not resolve there and 187 AdaLang findings are
  unmatched.
- **Checks that depend on the set of sources.**
  `Integer_Type_As_Enumeration` asks whether any source uses a type as a
  number, and GNATcheck loads more sources than AdaLang analyzes (888
  against 348 on AWS): 15 AdaLang findings on AWS, gnatcoll-core and
  coap_spark have no GNATcheck counterpart for that reason.
- **A few checks that still differ on AWS**, chiefly
  `Outside_Reference_From_Subprogram` and
  `Out_Parameter_Read_In_Exception_Handler`, which have not been run down.
- **Different file sets.** GNATcheck analyses the closure it loads, AdaLang
  the root project's sources; the table above counts shared files only.

The first run of these pairs exposed `FP-102`: with a project file,
AdaLang resolved names only among the root project's own sources, so on a
corpus whose root project imports another, everything that depended on an
imported unit went unresolved. Before the fix the same table read 83,101
matched of 92,293 GNATcheck findings (90.0%); gnatcoll-core alone went from
13,007 to 19,903 of 19,916, and CubedOS from 922 to 1,576 of 1,577. The fix
adds the sources of imported projects to the name lookup without analysing
them. It also changes the pairs compared earlier on those corpora, in both
directions: more calls resolve, so checks such as `Dead_Store`,
`Exception_Propagation` and `Missing_Global_Contract` report more, and
`Floating_Equality` now matches GNATcheck where it used to miss. The
analyzer side of the GNATprove comparisons above was re-run after the fix
against the saved 2026-10-02 GNATprove output: still zero possible
unsoundness and zero false positives on every corpus. The single-project
corpora are unchanged; coap_spark gains nine matched pairs (942 to 951)
and CubedOS one (7 to 8), and CubedOS, gnatcoll-core and AWS get verdicts
for obligations that were `Unsupported` before (CubedOS 667 to 32). Each
of those corpora's `RESULTS_2026-10-02.md` has a 2026-10-04 section.

The 2026-10-05 refresh closed a second gap, `FP-103`: a source that uses
the GNAT preprocessor did not parse, so nothing was reported for it. All
271 GNATcheck-only findings on Tokeneer were in four such files; with the
project's preprocessing switches applied, Tokeneer matches on every one of
its 6,007 coding-standard findings.

The run also found four defects in the new checks, all fixed before these
numbers were taken: `Outside_Reference_From_Subprogram` reported inside
generic bodies, `Global_Variable` reported renamings of constants,
`Uninitialized_Global_Variable` reported locals whose scope was not
resolved, and `Deriving_From_Predefined_Type` covered the children of
`Ada`, `System` and `Interfaces`.

GNATcheck worker crashes were frequent with about 185 plain rules in one
invocation, to the point of never completing on the larger corpora. For
this refresh each GNATcheck invocation was repeated until it finished
without a crash, and the plain rules were run in batches of at most 25
(split further when a batch kept crashing); no rule had to be left out.
The runner scripts in this directory do not do this themselves yet.

Each corpus keeps one current results file, `RESULTS_gnatcheck_2026-10-04.md`
(earlier runs are in the Git history), with per-rule tables for both
tools and the known, explained differences. The 2026-09-24 refresh
corrected two harness defects: the Ada_Drivers_Library runner had split
every extra GNATcheck pass at spaces (an indented `IFS`), so the fourteen
pairs added on 2026-09-23 were never checked on that corpus; and
GNATcheck's `Duplicate_Branches` ignores branches under 4 statements or 14
tokens by default, which hid every pair on all ten corpora. It now runs
with `min_stmt=1,min_size=1` and, like `Same_Tests`, is matched on the
line it names as the duplicate (the one AdaLang reports). Across the ten
corpora, GNATcheck confirms 26 of AdaLang's 50 `Identical_Branches`/
`Identical_Case_Alternative` findings; every other one is a later member
of a run of identical adjacent branches, which GNATcheck reports once per
construct (20 of them in a single coap_spark lookup-style case
expression).
Investigating the pair found `FP-079`-`FP-082` (see
`quality/known_analysis_issues.tsv`).

**Reading the "unmatched" gap.** Most of it is not disagreement — it's the
comparator's exact-line matching meeting real, explainable conventions:
GNATcheck cites a subprogram spec line where AdaLang cites the body (or
vice versa) for several rule pairs; some rules differ in reporting
*granularity* (once per subprogram vs. once per violation); default
thresholds differ (e.g. max parameter count); and a handful of rule pairs
have a genuine, documented scope difference (narrower or broader than
their GNATcheck counterpart) rather than a bug — each corpus's own
`RESULTS_gnatcheck_*.md` has the specific breakdown where it matters. On
the large, non-threshold-configurable `Magic_Number` side of that pair,
AdaLang's own findings are matched by GNATcheck 54–97% of the time across
the ten corpora — a wide spread driven mostly by corpus size and style
rather than a threshold difference (both rules use the same "any numeric
literal outside a small allow-list" definition), and still one of the more
consistent positive signals in the series. GNATcheck's own findings show
real run-to-run variance on this from-source build (an intermittent
single-worker stack-overflow crash, not corpus-specific); treat exact
counts as approximate, the qualitative agreement as the reliable part.

## Compiler-warning and style-check pairs (2026-09-23)

GNATcheck's `Warnings` and `Style_Checks` rules pass GNAT's own compiler
warnings and `-gnaty` style checks through, tagged by switch letter
(`[warnings:u]`, `[style_checks:M]`). That makes GNAT's front end an
independent oracle for twelve more AdaLang checks: `Unused_With_Clause`,
`Unused_Variable`, `Unused_Parameter`, `Wrong_Parameter_Mode`,
`Overwritten_Assignment`, `Dead_Store`, `Redundant_Type_Conversion`,
`Self_Assignment`, `Duplicate_With_Clause`, `Constant_Condition`,
`Long_Line` and `Trailing_Whitespace`. `No_Pragma` (`Forbidden_Pragmas:ALL`)
and `Missing_Overriding_Indicator` (`Overriding_Indicators`) were added in
the same refresh: `quality/tool_function_evidence.tsv` already credited
both with a GNATcheck oracle that the benchmark lane never ran, a gap
`tests/run_tool_function_evidence.sh` now rejects.

How it works:

- A fourth rule-map column gives the GNATcheck option that produces a
  tag (`+RWarnings:u`, `+RStyle_Checks:M120`).
  `benchmarks/gnatcheck_rule_args.awk` builds the arguments.
- One `-gnatw` letter covers several diagnostics, so
  `benchmarks/gnatcheck_compare.awk` splits a letter by message before
  pairing (`warnings:u.unit` against `warnings:u.object`; "condition is
  always True/False" against validity-based `-gnatwc` warnings AdaLang does
  not model; a with repeated in one context clause against one repeated
  from the spec). Unpaired messages are ignored.
- GNATcheck runs in separate passes: the original rules with `-r` exactly
  as before, then one pass for the compiler-driven options and one for each
  other option. In a single invocation the new options made this
  from-source GNATcheck's workers overflow their stack and drop thousands
  of findings on 8 of the 10 corpora. Every corpus was then retried until
  its output contained no worker-crash line.
- On Ada_Drivers_Library, GNATcheck cannot compile the units (its variant
  projects lack dependencies such as `stm32_svd.ads`), so the compiler-
  driven pairs have no GNAT side there; that corpus says nothing about
  them either way.

Cross-corpus totals for the new pairs:

| AdaLang rule | AdaLang | AdaLang-only | GNAT | GNAT-only | Reading |
| --- | ---: | ---: | ---: | ---: | --- |
| No_Pragma | 3137 | 8 | 5321 | 2192 | Same pragmas on both sides; the gap is units GNATcheck analyzes and AdaLang does not (dependency projects), and vice versa |
| Long_Line | 826 | 802 | 24 | 0 | All 24 of GNAT's matched; 801 of AdaLang's extra are coap_spark's RecordFlux-generated files, which switch GNAT's line-length check off with `pragma Style_Checks` |
| Unused_With_Clause | 80 | 30 | 57 | 7 | CubedOS keeps withs for elaboration and silences GNAT with `pragma Warnings (Off, ...)`; AdaLang does not honor GNAT's warning pragmas |
| Unused_Parameter | 94 | 83 | 11 | 0 | GNAT exempts overriding operations, `null`/`raise`-only bodies (AWS's SSL stubs) and names like `Dummy` |
| Wrong_Parameter_Mode | 63 | 63 | 0 | 0 | GNAT's `-gnatwk` only reports an `in out` never modified; AdaLang also reports one never read |
| Dead_Store | 106 | 106 | 0 | 0 | GNAT's front end reports useless assignments only in simple straight-line shapes, and none occur in these corpora, so this pair is a weak oracle here; the AdaLang-only findings were triaged by sampling instead |
| Overwritten_Assignment | 9 | 9 | 0 | 0 | As for `Dead_Store` |
| Unused_Variable | 15 | 14 | 64 | 63 | 63 are Tokeneer's unused exception-choice parameters (`when E : others =>`), which `Unused_Variable` does not examine |
| Constant_Condition | 12 | 12 | 22 | 22 | GNAT's are range-aware folds (a subtype-bound `Loop_Invariant`), outside AdaLang's flow domain |
| Redundant_Type_Conversion | 26 | 11 | 19 | 4 | |
| Trailing_Whitespace | 0 | 0 | 5 | 5 | All in coap_spark's `wolfssl` dependency, which AdaLang does not analyze |
| Duplicate_With_Clause | 0 | 0 | 1 | 1 | |
| Missing_Overriding_Indicator, Self_Assignment | 0 | 0 | 0 | 0 | |

Triaging the gaps found twelve analyzer defects, `FP-067`-`FP-078` in
`quality/known_analysis_issues.tsv` (the corpus-found ones are in the table
below; `FP-067` and `FP-068` came from probe fixtures written while
establishing the pairs). All are fixed with regression tests. The remaining
differences are the policy choices and coverage gaps in the "Reading"
column, not defects.

## What these benchmarks have found, in total

Thirty-one real analyzer bugs, all discovered by running against
independently authored code no one on this project wrote or reviewed for
analyzer blind spots — the value external-corpus validation is meant to
deliver (`quality/external_corpus_findings.md`), each fixed, with a
regression test wherever the failure can be reproduced outside the real
corpus (`FP-078`, `FP-080` and `FP-082` need a real Libadalang resolution
failure and are verified on the corpus instead):

| ID | Corpus that found it | Bug |
| --- | --- | --- |
| `FP-019` | aws | Unresolved cross-project call actual misread as a definite prior write |
| `FP-020` | aws | Renamings, `Unbounded_String`/`File_Type` defaults misread as uninitialized |
| `FP-039` | sparknacl | A `Global` aspect's own text misread as an executable read |
| `FP-040` | cubedos | A Libadalang property failure escaped its containing function, aborting whole-file analysis |
| `FP-042` | ada_drivers_library | `limited with` misread as an ordinary circular-dependency edge |
| `FP-043` | gnatcoll | A `pragma Unreferenced` argument misread as a value read, in a second initialization walk `Checks.Data_Flow`'s own guard didn't cover |
| `FP-044` | gnatcoll | A gap in the overload-arity fallback `FP-021` added: a wrong same-named-overload resolution could still be trusted when it coincidentally had a formal at the queried position |
| `FP-045` | gnatcoll | Ada's `Low .. Low - 1` empty-array idiom flagged as a reversed range |
| `FP-051` | aws | `Reraise_Discards_Occurrence` flagged `raise Foo with "<context>";` (a deliberate enrich-and-reraise idiom) the same as a bare `raise Foo;` (accidental occurrence loss) |
| `FP-052` | ada_drivers_library | `Duplicate_Subprogram`'s matched-location message dropped the directory, so two files sharing a simple name in different directories read as a body reported as a duplicate of itself |
| `FP-059` | ada_drivers_library | `Empty_Else_Body` (and, by the same shared helper, `Empty_If_Body`/`Empty_Elsif_Body`/`Empty_Then_Body`/`Null_Case_Alternative`) treated a branch containing only `pragma Assert (False);` as having no effect, the same as a bare `null;` |
| `FP-061` | sparknacl | `'Succ`/`'Pred`-based loop-variant progress collapsed to a tautological SMT goal on an untranslated RHS, misread as a proven `Definite_Error` instead of `Unsupported` |
| `FP-064` | spark_testsuite | `--verify` proved an index into an array *slice* (`Items (1 .. Last) (1)`) safe against the array type's index subtype, missing that the slice bounds `1 .. Last` are empty when `Last = 0` — a possible unsoundness |
| `FP-065` | spark_testsuite | `--verify` reported `pragma Assert (False)` as a definite error on a branch whose guard it could not evaluate, where the branch is in fact unreachable (the guard line itself always raises) |
| `FP-066` | aws | `Null_Statement` flagged every `null;` unconditionally, including the sole-statement idiom (`exception when X => null;`, a no-op case alternative) GNATcheck's own `Redundant_Null_Statements` rule deliberately exempts — found via GNATcheck oracle-comparison triage rather than a fresh run |
| `FP-069` | gnatcoll | `Unused_With_Clause` flagged used withs of package renamings (`GNAT.OS_Lib`), generic instances, and units whose use-visible names Libadalang failed to resolve (22 findings on gnatcoll-core, 2 after) |
| `FP-070` | gnatcoll | `Dead_Store` treated a write through an access-typed local (`S (1) := ...`, the very write `Capitalize` exists to make) as a write to the local |
| `FP-071` | gnatcoll | `Dead_Store`/`Overwritten_Assignment` missed reads by nested subprograms (up-level references) |
| `FP-072` | sparknacl | `Dead_Store` flagged `Sanitize (Key);` key wipes that `pragma Inspection_Point` makes observable |
| `FP-073` | sparknacl | `Dead_Store` treated `Key (I)` as a different component from a written `Key (0 .. 31)` |
| `FP-074` | gnatcoll | `Missing_Overriding_Indicator` flagged a body whose separate declaration already says `overriding` |
| `FP-075` | ada_drivers_library, tokeneer, coap_spark | `Dead_Store`/`Overwritten_Assignment` flagged deliberate sinks (`Dummy := Periph.DR;`, `Success => Ignored`), which GNAT's own convention exempts |
| `FP-076` | ada_drivers_library | `Wrong_Parameter_Mode` missed writes through a `for Pin of Pins` element (`Pin.Set;`) |
| `FP-077` | ada_drivers_library, cubedos | `Wrong_Parameter_Mode` advised changing modes fixed by overriding or by an `'Access` binding (AUnit test routines) |
| `FP-078` | aws | Enabling `Unused_With_Clause` abandoned three whole files on an unguarded Libadalang property error, losing every check's findings there |
| `FP-079` | coap_spark | `Identical_Case_Alternative` checked case statements but never case expressions |
| `FP-080` | cubedos | Twelve helpers resolved names in their declarations, outside their own exception handler; with `Non_Short_Circuit_Condition` enabled, a resolution failure dropped every other check on the `if` statement |
| `FP-081` | gnatcoll | Any call with a positional argument made `Non_Short_Circuit_Condition` and `No_Dispatching_Call` raise on a null child, silently skipping every later check on the statement or call (thousands of locations on gnatcoll-core) |
| `FP-082` | gnatcoll | One check's resolution failure skipped every later check on the same node; each check now has its own handler (114 findings recovered on gnatcoll-core with all checks enabled) |
| `FP-099` | aws | `--verify` reported a read of the `out` actual of a function called in a condition (`if Decode_Bit (Iter, Bit, C) then Result (I) := C;`) as a definite uninitialized read (introduced in 1.6.1) |
| `FP-100` | spark_testsuite | `--verify` reported a second definite error, for the range check, on an initial value whose computation always overflows and so never reaches that check (introduced in 1.6.1) |

`FP-044`'s own two originating findings (gnatcoll-buffer.adb's
`Current_Text_Position`) persist despite the fix, unlike every other row
above: they sit behind a separate, still-open Property_Error (`FP-029`'s
general class) that keeps the fixed code path from ever being reached for
them in this environment — see `quality/known_analysis_issues.tsv` for the
full trace.

Every fix is closed, regression-tested, and confirmed not to blunt genuine
detection nearby. No benchmark run since has reopened any of them.

## Bottom line: does this evidence support using AdaLang Analyzer?

Yes, within a specific scope — not as a GNATprove replacement, but as what
it's actually positioned as (`POSITIONING.md`): a fast, no-setup-required
first pass.

**Where the evidence is strong.** Zero false positives and zero possible
unsoundness across 2,871 matched proof obligations spanning five
independently-authored, fully-proved SPARK corpora — a hash family, two
crypto primitives, a protocol parser, a security-critical access-control
system — is the property that matters most for trusting a tool's output,
and it holds even on code (coap_spark) chosen specifically because nothing
about it was tuned around what AdaLang can prove. It also runs on
ordinary, non-SPARK Ada: the AWS benchmark shows GNATprove can't even get
past a pre-existing legality error on a real 348-file codebase, while
AdaLang analyzes it directly. gnatcoll-core repeats the same pattern in a
third, unrelated domain (a general-purpose utility library, not a web
server or crypto primitive): GNATprove hard-stops on a SPARK-illegal
aspect 41 units into the project, while AdaLang completes a full pass.

**Where the tradeoff bites.** AdaLang rarely proves anything independently
on harder code shapes — on coap_spark it leaves 1,311 of 1,324 comparable
obligations `Unproved`/`Unsupported` and matches GNATprove's own proof on
only 8, so its `Proved_Safe` verdicts are a bonus on top of GNATprove
where both are available, not a substitute, and its
`Unproved`/`Unsupported` results mean "no information," not "probably
fine." Two of the five oracle corpora (saatana: 101 matched pairs;
cubedos: 7) are small enough samples to corroborate the pattern rather
than establish it independently.

**Net:** use it for what static analysis on ordinary Ada is for — catching
real defects fast, on code that will never be SPARK, or as an immediate
first pass before a full GNATprove run on code that will be — and don't
expect it to replace GNATprove's proof coverage on code that already has
it.
