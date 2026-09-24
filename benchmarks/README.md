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
| [sparknacl](sparknacl/) | rod-chapman | NaCl-style crypto, fixed-width arithmetic | 890 | 0 | 0 |
| [saatana](saatana/) | HeisenbugLtd | Phelix stream cipher | 101 | 0 | 0 |
| [libkeccak](libkeccak/) | damaki | SHA-3/Keccak sponge family | 212 | 0 | 0 |
| [coap_spark](coap_spark/) | mgrojo | CoAP protocol parsing/session state | 853 | 0 | 0 |
| [tokeneer](tokeneer/) | AdaCore/NSA | Access-control system (identification station) | 221 | 0 | 0 |
| [cubedos](cubedos/) | cubesatlab | Satellite message-passing bus (not fully proved) | 7 | 0 | 0 |
| [spark_testsuite](spark_testsuite/) | AdaCore | SPARK regression testsuite — 124 curated micro-tests, run per unit (90 fully-proved oracle + 34 deliberately-broken tripwire) | 428 | 0 | 0 |

**Across five independently-authored, fully-proved corpora (SPARKNaCl,
Saatana, libkeccak, coap_spark, Tokeneer) — 2,277 proof obligations both
tools could independently evaluate at the same location, spanning five
different authors/origins and five structurally different domains —
AdaLang has never once called something safe that GNATprove could not
prove, and never once called something a definite error that GNATprove
proved safe.** CubedOS's 7 matched pairs (not a fully-proved corpus, so a
weaker oracle) show the same zero-disagreement pattern on a much smaller
sample.

The `spark_testsuite` corpus is structurally different — 124 curated
single-purpose regression tests from the AdaCore SPARK testsuite, each
analyzed on its own generated project and compared individually (the
testsuite reuses filenames across thousands of directories, so a global
`(basename, line, kind)` match is not possible). Its 428 matched pairs
span nine scalar obligation kinds across far more distinct code shapes than
the six real projects reach; its value is that breadth, not the count. It
also carries 34 deliberately-broken units where GNATprove's own `medium`/
`high` verdict is the tripwire — AdaLang never once answered one of those
`proved-safe`. See `spark_testsuite/RESULTS_2026-09-06.md`. The first run
of this corpus found two analyzer defects (`FP-064`, `FP-065`), both fixed
with regression tests before it landed.

What this table doesn't show: AdaLang answers "I don't know"
(`Unproved`/`Unsupported`) far more often than GNATprove does on all six —
consistent with `POSITIONING.md`'s framing of `--verify` as "a much
narrower scalar subset," not a competitor to full SMT-backed proof. The
"both safe" share of each corpus's matched pairs varies a lot by code
style: sparknacl 56/890 (~6%), tokeneer 25/221 (~11%), libkeccak 55/212
(~26%), coap_spark 5/853 (~0.6%) — coap_spark's RecordFlux-generated
protocol contracts and session-state logic remain the hardest code shape
for AdaLang's bounded verifier to independently prove, even though it
never gets one *wrong* there.

## Real-code validation (no GNATprove oracle)

| Corpus | Author | Domain | Purpose |
| --- | --- | --- | --- |
| [aws](aws/) | AdaCore | Ada Web Server, ordinary (non-SPARK) Ada | Breadth on a large real project; GNATprove never gets past a pre-existing legality error; also the corpus with genuine unrestricted `select`/`requeue`/`abort` for the `--automotive` concurrency-prohibition checks |
| [ada_drivers_library](ada_drivers_library/) | AdaCore | STM32 bare-metal hardware drivers | Real Ravenscar `protected`-object code for the `--automotive` concurrency-prohibition checks (no `select`/`requeue`/`abort` — see aws) |
| [gnatcoll](gnatcoll/) | AdaCore | GNAT Components Collection core (JSON, VFS, strings, email, OS/process), ordinary (non-SPARK) Ada | A third breadth corpus in a new domain (general-purpose utility library); GNATprove hard-stops on a SPARK-illegal aspect 41 units in |
| [project_bias](project_bias/) | EliAvila10 | Bias-free cryptographic random streams | Small SPARK corpus emphasizing floating-point contracts, quantified array predicates, OS/C bindings, and entropy-buffer clearing; GNATprove reports one flow error, so it is not a fully-proved oracle (27 matched pairs, 0 unsoundness, 0 false positives — corroborates without counting toward the table above) |

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
| [sparknacl](sparknacl/RESULTS_gnatcheck_2026-09-24.md) | 1986 | 1752 (88.2%) | 2196 | 1752 (79.8%) |
| [aws](aws/RESULTS_gnatcheck_2026-09-24.md) | 6701 | 3635 (54.2%) | 12991 | 3625 (27.9%) |
| [gnatcoll-core](gnatcoll/RESULTS_gnatcheck_2026-09-24.md) | 2108 | 1269 (60.2%) | 2943 | 1267 (43.1%) |
| [ada_drivers_library](ada_drivers_library/RESULTS_gnatcheck_2026-09-24.md) | 860 | 425 (49.4%) | 1136 | 425 (37.4%) |
| [cubedos](cubedos/RESULTS_gnatcheck_2026-09-24.md) | 304 | 258 (84.9%) | 862 | 258 (29.9%) |
| [coap_spark](coap_spark/RESULTS_gnatcheck_2026-09-24.md) | 3066 | 2092 (68.2%) | 10094 | 2092 (20.7%) |
| [libkeccak](libkeccak/RESULTS_gnatcheck_2026-09-24.md) | 1852 | 1629 (88.0%) | 1941 | 1629 (83.9%) |
| [saatana](saatana/RESULTS_gnatcheck_2026-09-24.md) | 204 | 134 (65.7%) | 167 | 134 (80.2%) |
| [project_bias](project_bias/RESULTS_gnatcheck_2026-09-24.md) | 387 | 295 (76.2%) | 440 | 295 (67.0%) |
| [tokeneer](tokeneer/RESULTS_gnatcheck_2026-09-24.md) | 772 | 611 (79.1%) | 1851 | 592 (32.0%) |

Each corpus keeps one current results file, `RESULTS_gnatcheck_2026-09-24.md`
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

Twenty-nine real analyzer bugs, all discovered by running against
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
unsoundness across 2,277 matched proof obligations spanning five
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
on harder code shapes — on coap_spark it leaves 848 of 853 comparable
obligations `Unproved`/`Unsupported` and matches GNATprove's own proof on
only 5, so its `Proved_Safe` verdicts are a bonus on top of GNATprove
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
