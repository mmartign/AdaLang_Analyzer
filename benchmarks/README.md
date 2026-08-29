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

**Across five independently-authored, fully-proved corpora (SPARKNaCl,
Saatana, libkeccak, coap_spark, Tokeneer) — 2,277 proof obligations both
tools could independently evaluate at the same location, spanning five
different authors/origins and five structurally different domains —
AdaLang has never once called something safe that GNATprove could not
prove, and never once called something a definite error that GNATprove
proved safe.** CubedOS's 7 matched pairs (not a fully-proved corpus, so a
weaker oracle) show the same zero-disagreement pattern on a much smaller
sample.

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
| [sparknacl](sparknacl/RESULTS_gnatcheck_2026-08-29.md) | 1557 | 1334 (85.7%) | 1778 | 1334 (75.0%) |
| [aws](aws/RESULTS_gnatcheck_2026-08-29.md) | 6343 | 3335 (52.6%) | 11617 | 3325 (28.6%) |
| [gnatcoll-core](gnatcoll/RESULTS_gnatcheck_2026-08-29.md) | 1891 | 979 (51.8%) | 2191 | 977 (44.6%) |
| [ada_drivers_library](ada_drivers_library/RESULTS_gnatcheck_2026-08-29.md) | 859 | 378 (44.0%) | 1087 | 378 (34.8%) |
| [cubedos](cubedos/RESULTS_gnatcheck_2026-08-29.md) | 182 | 157 (86.3%) | 653 | 157 (24.0%) |
| [coap_spark](coap_spark/RESULTS_gnatcheck_2026-08-29.md) | 784 | 641 (81.8%) | 7629 | 641 (8.4%) |
| [libkeccak](libkeccak/RESULTS_gnatcheck_2026-08-29.md) | 1460 | 1224 (83.8%) | 1355 | 1224 (90.3%) |
| [saatana](saatana/RESULTS_gnatcheck_2026-08-29.md) | 158 | 96 (60.8%) | 129 | 96 (74.4%) |
| [project_bias](project_bias/RESULTS_gnatcheck_2026-08-29.md) | 225 | 168 (74.7%) | 299 | 168 (56.2%) |
| [tokeneer](tokeneer/RESULTS_gnatcheck_2026-08-29.md) | 599 | 444 (74.1%) | 1602 | 425 (26.5%) |

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

## What these benchmarks have found, in total

Twelve real analyzer bugs, all discovered by running against independently
authored code no one on this project wrote or reviewed for analyzer
blind spots — the value external-corpus validation is meant to deliver
(`quality/external_corpus_findings.md`), each fixed with a regression test:

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
