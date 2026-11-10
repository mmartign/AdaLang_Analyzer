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
  direct/close GNATcheck counterpart
  (`docs/src/gnatcheck-rule-comparison.md`),
  GNATcheck's own findings on the same corpus become ground truth — an
  AdaLang finding with no matching GNATcheck finding at the same
  `(file, line)` is a potential false positive, and vice versa a potential
  false negative. Unlike the proof-obligation comparison above, this is
  matching two independently-implemented rule linters against each other,
  not verification results.

Every benchmark here is a `run.sh` + `README.md` (setup, toolchain notes,
pinned revision) + a dated `RESULTS_*.md` (the actual numbers, latest run
only — see `git log` for prior snapshots). The GNATprove corpora share one
matcher, `compare.awk`.

## Independent-oracle comparisons (GNATprove as ground truth)

| Corpus | Author | Domain | Matched pairs | Both safe | Unsoundness | False positives |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| [sparknacl](sparknacl/) | rod-chapman | NaCl-style crypto, fixed-width arithmetic | 1,264 | 932 | 1 | 0 |
| [saatana](saatana/) | HeisenbugLtd | Phelix stream cipher | 185 | 103 | 0 | 0 |
| [libkeccak](libkeccak/) | damaki | SHA-3/Keccak sponge family | 253 | 212 | 0 | 0 |
| [coap_spark](coap_spark/) | mgrojo | CoAP protocol parsing/session state | 3,196 | 2,422 | 0 | 0 |
| [tokeneer](tokeneer/) | AdaCore/NSA | Access-control system (identification station) | 446 | 270 | 0 | 0 |
| [cubedos](cubedos/) | cubesatlab | Satellite message-passing bus (not fully proved) | 10 | 0 | 0 | 0 |
| [spark_testsuite](spark_testsuite/) | AdaCore | SPARK regression testsuite — 124 curated micro-tests, run per unit (90 fully-proved oracle + 34 deliberately-broken tripwire) | 688 | 311 | 0 | 0 |

These are the figures of release 1.13.5 (run of 2026-11-10 against the
GNATprove output of 2026-10-02). A matched pair is a
`(file, line, check kind)` at which each tool has exactly one obligation;
"both safe" is the number of pairs AdaLang proves too.

**Across five independently-authored, fully-proved corpora (SPARKNaCl,
Saatana, libkeccak, coap_spark, Tokeneer) — 5,226 proof obligations both
tools could independently evaluate at the same location, spanning five
different authors/origins and five structurally different domains —
AdaLang has called safe one check that GNATprove could not prove, and
never once called something a definite error that GNATprove proved
safe.** That check holds: it is the preservation of a loop invariant in
`sparknacl-sign.adb` (line 604), on which GNATprove's provers reach their
step limit, the loop's body writing no element the invariant speaks of
but one it sets to 0. CubedOS's 10 matched pairs (not a fully-proved corpus, so a
weaker oracle) show the same zero-disagreement pattern on a much smaller
sample.

The `spark_testsuite` corpus is structurally different — 124 curated
single-purpose regression tests from the AdaCore SPARK testsuite, each
analyzed on its own generated project and compared individually (the
testsuite reuses filenames across thousands of directories, so a global
`(basename, line, kind)` match is not possible). Its 651 matched pairs
span far more distinct code shapes than the six real projects reach; its
value is that breadth, not the count. It
also carries 34 deliberately-broken units where GNATprove's own `medium`/
`high` verdict is the tripwire — AdaLang never once answered one of those
`proved-safe`. See `spark_testsuite/RESULTS_2026-11-01.md`.

What the two zero columns don't show:

- **AdaLang answers "I don't know" (`Unproved`/`Unsupported`) far more
  often than GNATprove does**, on every corpus — consistent with
  `docs/src/positioning.md`'s framing of `--verify` as "a much narrower
  scalar subset," not a competitor to full SMT-backed proof. On the five
  fully proved corpora the "both safe" share of the matched pairs runs from
  47% on Saatana to 81% on libkeccak, and is 67% on coap_spark, whose
  RecordFlux-generated protocol contracts and session-state logic hold
  nearly half of what is left of the gap. The next section measures that
  distance on every check, not only the paired ones.
- **A false-safe on code that is proved correct**: there a bogus proof
  agrees with the oracle. The seeded-defect probes and the deliberately
  broken differential corpus exist for that (`quality/README.md`,
  "Verification mutation campaign").

### How much of what GNATprove proves does `--verify` prove?

The table above only counts places where both tools have exactly one
obligation of a kind, which is the right sample for asking whether they
ever disagree and the wrong one for asking how far apart they are.
[`GNATPROVE_GAP_LEDGER.md`](GNATPROVE_GAP_LEDGER.md)
takes every check GNATprove proves on the five fully proved corpora, 15,043
of them once the repeats for generic instances are merged, and records
what AdaLang does with each:

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| Proves it | 10,963 | 72.9% |
| Has the obligation, leaves it unproved | 2,800 | 18.6% |
| Has the obligation, calls it unsupported | 31 | 0.2% |
| Has the obligation, finds the code never reached | 1 | 0.0% |
| Has no obligation of that kind at that place | 690 | 4.6% |
| Has no obligation of that kind at all | 350 | 2.3% |
| Raises nothing in that file | 208 | 1.4% |

Since 1.8.3 the analyzer does this accounting itself when it is given the
log of a GNATprove run (`--gnatprove-log`): it reports GNATprove's verdict
on each check beside its own result, and on these corpora that leaves none
of the 15,043 unaccounted for -- 10,963 proved by AdaLang too, 2,832 with
GNATprove's verdict alone on an obligation AdaLang has, 1,248 with
GNATprove's verdict alone and no AdaLang obligation. The first figure is
the only one that is AdaLang's.

What is left, and why:

- **Unproved (2,800).** AdaLang has the obligation and does not decide it.
  The ledger gives the reason it reports for each, per corpus.
- **Unsupported (31).** The obligation is in a subprogram `--verify`
  leaves outside the verified subset, almost all for a dispatching call;
  29 of them are in coap_spark.
- **No obligation (1,248).** Memory leaks, which AdaLang does not have;
  the discriminant check of a component of an aggregate, and predicate
  checks at the default value of a type, at an allocator and at a
  component of an aggregate, where it raises none yet; and range, index and precondition
  checks at places it does not yet look.

In the other direction AdaLang proves one of the 22 checks GNATprove
leaves unproved there, the `sparknacl-sign.adb` preservation above, which
holds, and reports no definite error on a check GNATprove proves. `benchmarks/gnatprove_gap_ledger.py` regenerates
the ledger from the lanes' results. How the figure got to 10,963, release
by release, is in `CHANGELOG.md` (1.8.1 to 1.13.5), with the analyzer faults
that the work turned up on the way (`FP-104`, `FP-106` to `FP-122`,
`FP-124` to `FP-131`, `FP-133` to `FP-142`).

## Real-code validation (no GNATprove oracle)

| Corpus | Author | Domain | Purpose |
| --- | --- | --- | --- |
| [aws](aws/) | AdaCore | Ada Web Server, ordinary (non-SPARK) Ada | Breadth on a large real project; GNATprove never gets past a pre-existing legality error; also the corpus with genuine unrestricted `select`/`requeue`/`abort` for the `--automotive` concurrency-prohibition checks |
| [ada_drivers_library](ada_drivers_library/) | AdaCore | STM32 bare-metal hardware drivers | Real Ravenscar `protected`-object code for the `--automotive` concurrency-prohibition checks (no `select`/`requeue`/`abort` — see aws) |
| [gnatcoll](gnatcoll/) | AdaCore | GNAT Components Collection core (JSON, VFS, strings, email, OS/process), ordinary (non-SPARK) Ada | A third breadth corpus in a new domain (general-purpose utility library); GNATprove hard-stops on a SPARK-illegal aspect 41 units in |
| [project_bias](project_bias/) | EliAvila10 | Bias-free cryptographic random streams | Small SPARK corpus emphasizing floating-point contracts, quantified array predicates, OS/C bindings, and entropy-buffer clearing; GNATprove reports one flow error, so it is not a fully-proved oracle (43 matched pairs, 0 unsoundness, 0 false positives — corroborates without counting toward the table above) |

## GNATcheck oracle comparison

GNATcheck has no Alire package and no prebuilt download; the binary used
here was built from source and exists only on the machine it was built on.
Shared infrastructure for every corpus's GNATcheck lane: `benchmarks/gnatcheck_rule_map.tsv` (the rule-pair map) and
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
checks (the other 17 coding-standard checks report nothing until configured
and are not in the rule map).

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

GNATcheck worker crashes are frequent with about 185 plain rules in one
invocation, to the point of never completing on the larger corpora. For
these results each GNATcheck invocation was repeated until it finished
without a crash, and the plain rules were run in batches of at most 25
(split further when a batch kept crashing); no rule had to be left out.
The runner scripts in this directory do not do this themselves yet.

Each corpus keeps one current results file, `RESULTS_gnatcheck_2026-10-05.md`
(earlier runs are in the Git history), with per-rule tables for both
tools and the known, explained differences. GNATcheck's
`Duplicate_Branches` ignores branches under 4 statements or 14 tokens by
default, so it runs here with `min_stmt=1,min_size=1` and, like
`Same_Tests`, is matched on the line it names as the duplicate (the one
AdaLang reports). Across the ten corpora, GNATcheck confirms 26 of AdaLang's
50 `Identical_Branches`/`Identical_Case_Alternative` findings; every other
one is a later member
of a run of identical adjacent branches, which GNATcheck reports once per
construct (20 of them in a single coap_spark lookup-style case
expression).

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

## Compiler-warning and style-check pairs

GNATcheck's `Warnings` and `Style_Checks` rules pass GNAT's own compiler
warnings and `-gnaty` style checks through, tagged by switch letter
(`[warnings:u]`, `[style_checks:M]`). That makes GNAT's front end an
independent oracle for twelve more AdaLang checks: `Unused_With_Clause`,
`Unused_Variable`, `Unused_Parameter`, `Wrong_Parameter_Mode`,
`Overwritten_Assignment`, `Dead_Store`, `Redundant_Type_Conversion`,
`Self_Assignment`, `Duplicate_With_Clause`, `Constant_Condition`,
`Long_Line` and `Trailing_Whitespace`. `No_Pragma` (`Forbidden_Pragmas:ALL`)
and `Missing_Overriding_Indicator` (`Overriding_Indicators`) run in the same
lane.

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
- GNATcheck runs in separate passes: the plain rules with `-r`, then one
  pass for the compiler-driven options and one for each other option. In a
  single invocation these options make this from-source GNATcheck's workers
  overflow their stack and drop thousands of findings on 8 of the 10
  corpora. Every corpus was retried until its output contained no
  worker-crash line.
- On Ada_Drivers_Library, GNATcheck cannot compile the units (its variant
  projects lack dependencies such as `stm32_svd.ads`), so the compiler-
  driven pairs have no GNAT side there; that corpus says nothing about
  them either way.

Cross-corpus totals for these pairs:

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

The differences are the policy choices and coverage gaps in the "Reading"
column, not defects.

## What these benchmarks have found

Running against independently authored code keeps finding analyzer mistakes
that no hand-written fixture exposed. Each confirmed one is registered in
`quality/known_analysis_issues.tsv`, with its status and regression test.

## Bottom line: does this evidence support using AdaLang Analyzer?

Yes, within a specific scope — not as a GNATprove replacement, but as what
it's actually positioned as (`docs/src/positioning.md`): a fast,
no-setup-required
first pass.

**Where the evidence is strong.** Zero false positives and zero possible
unsoundness across 5,199 matched proof obligations spanning five
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

**Where the tradeoff bites.** AdaLang proves 73% of what GNATprove proves
on those corpora (10,963 of 15,043 checks), from 64% on Saatana (235 of
367) to 79% on Tokeneer (1,678 of 2,114), so its `Proved_Safe`
verdicts are a bonus on top of GNATprove where both are available, not a
substitute, and its `Unproved`/`Unsupported` results mean "no information,"
not "probably fine." Saatana (162 matched pairs) and CubedOS (6, and not
fully proved) are small enough samples to corroborate the pattern rather
than establish it independently.

**Net:** use it for what static analysis on ordinary Ada is for — catching
real defects fast, on code that will never be SPARK, or as an immediate
first pass before a full GNATprove run on code that will be — and don't
expect it to replace GNATprove's proof coverage on code that already has
it.
