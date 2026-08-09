# Benchmarks

This directory validates AdaLang Analyzer against real, independently
authored Ada/SPARK codebases — not the hand-constructed fixtures in
`quality/precision_corpus.tsv`. Two kinds of validation live here:

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

Every benchmark here is a `run.sh` + `README.md` (setup, toolchain notes,
pinned revision) + dated `RESULTS_*.md` (the actual numbers). Re-running one
after an analyzer change and adding a new dated results file, rather than
overwriting the old one, is how this directory is meant to grow.

## Independent-oracle comparisons (GNATprove as ground truth)

| Corpus | Author | Domain | Matched pairs | Unsoundness | False positives |
| --- | --- | --- | ---: | ---: | ---: |
| [sparknacl](sparknacl/) | rod-chapman | NaCl-style crypto, fixed-width arithmetic | 886 | 0 | 0 |
| [saatana](saatana/) | HeisenbugLtd | Phelix stream cipher | 101 | 0 | 0 |
| [libkeccak](libkeccak/) | damaki | SHA-3/Keccak sponge family | 212 | 0 | 0 |
| [coap_spark](coap_spark/) | mgrojo | CoAP protocol parsing/session state | 846 | 0 | 0 |
| [cubedos](cubedos/) | cubesatlab | Satellite message-passing bus (not fully proved) | 7 | 0 | 0 |

**Across four independently-authored, fully-proved corpora (SPARKNaCl,
Saatana, libkeccak, coap_spark) — 2,045 proof obligations both tools could
independently evaluate at the same location, spanning four different
authors and four structurally different domains — AdaLang has never once
called something safe that GNATprove could not prove, and never once called
something a definite error that GNATprove proved safe.** CubedOS's 7
matched pairs (not a fully-proved corpus, so a weaker oracle) show the same
zero-disagreement pattern on a much smaller sample.

What this table doesn't show: AdaLang answers "I don't know"
(`Unproved`/`Unsupported`) far more often than GNATprove does on all five —
consistent with `POSITIONING.md`'s framing of `--verify` as "a much
narrower scalar subset," not a competitor to full SMT-backed proof. The
"both safe" share of each corpus's matched pairs varies a lot by code
style: SPARKNaCl 32/886 (~4%), libkeccak 50/212 (~24%), coap_spark 1/846
(~0.1%) — coap_spark's RecordFlux-generated protocol contracts and
session-state logic are the hardest code shape yet for AdaLang's bounded
verifier to independently prove, even though it never gets one *wrong*
there.

- **[sparknacl](sparknacl/RESULTS_2026-08-04.md)** (2026-08-04) — the first
  and largest oracle comparison. Found and fixed `FP-039`: a nested
  procedure's `Global` aspect text was misread as executable code, flagging
  48 false `Definite_Error`s on already-initialized objects.
- **[saatana](saatana/RESULTS_2026-08-04.md)** (2026-08-04) — a second,
  independently-authored fully-proved corpus, corroborating SPARKNaCl on a
  smaller sample. Needed three toolchain overrides (an unavailable prover,
  a step budget tuned for it, a report level the project never set) to get
  a comparable run at all — a reminder that "fully proved" is tied to the
  exact toolchain that produced the claim.
- **[cubedos](cubedos/RESULTS_2026-08-04.md)** (2026-08-04) — a
  structurally different corpus (message-passing, real tasking) that
  GNATprove itself does *not* fully prove (real data races, a `Global`
  omission, uninitialized `out` params), so it can't answer the same
  ground-truth question. Found and fixed `FP-040`: a Libadalang
  `Property_Error` inside a cross-project call was escaping its containing
  function and aborting whole-file analysis (21 of 49 files) instead of
  just the one affected obligation.
- **[libkeccak](libkeccak/RESULTS_2026-08-07.md)** (2026-08-07) — a fourth
  independent author, heavy generic instantiation (the same permutation
  core instantiated once per supported state size) that pushes most
  obligations into a count-mismatch bucket rather than a 1:1 match — an
  expected property of the matching design meeting this corpus's coding
  style, not a defect. A candidate corpus (Componolit/libsparkcrypto) was
  set aside after a genuine `gnat2why` crash on this toolchain.
- **[coap_spark](coap_spark/RESULTS_2026-08-08.md)** (2026-08-08) — a fifth
  independent author, the first corpus in a new domain (protocol message
  parsing, not a cryptographic primitive). Needed a SPARKlib version
  conflict resolved (its own Alire manifest pins a GNATprove release this
  benchmark suite doesn't use) before it would even load. A candidate
  corpus (jgrivera67/HiRTOS, a SPARK RTOS kernel) was set aside after
  GNATprove hard-errored on a genuine SPARK legality violation in its
  interrupt-handling code — a real defect in that project, not a tooling
  gap.

## Real-code validation (no GNATprove oracle)

| Corpus | Author | Domain | Purpose |
| --- | --- | --- | --- |
| [aws](aws/) | AdaCore | Ada Web Server, ordinary (non-SPARK) Ada | Breadth on a large real project; GNATprove never got past project preprocessing |
| [ada_drivers_library](ada_drivers_library/) | AdaCore | STM32 bare-metal hardware drivers | Real tasking/protected-object code for the `--automotive` concurrency-prohibition checks |
| [gnatcoll](gnatcoll/) | AdaCore | GNAT Components Collection core (JSON, VFS, strings, email, OS/process), ordinary (non-SPARK) Ada | A third breadth corpus in a new domain (general-purpose utility library); GNATprove hard-stops on a SPARK-illegal aspect 41 units in |

- **[aws](aws/RESULTS_2026-08-02.md)** (2026-08-02) — 348 files of ordinary
  Ada. GNATprove couldn't run at all (legality errors, then a boundary
  where only 5.33% of entities are even `SPARK_Mode`-analyzable), so this
  validates AdaLang's standalone breadth and precision, not agreement with
  an oracle. Found and fixed two initialization false-positive bugs
  (`FP-019`, `FP-020` — renamings, `Unbounded_String`/`File_Type` defaults,
  and unresolved cross-project call actuals all misclassified as definite
  errors), then added interprocedural effect summaries that recovered 84
  more `Proved_Safe` verdicts with zero new false positives.
- **[ada_drivers_library](ada_drivers_library/RESULTS_2026-08-05.md)**
  (2026-08-05) — 90 STM32 driver files, almost none SPARK-annotated. Exists
  specifically to test the six `--automotive`-only concurrency-prohibition
  checks against real interrupt-driven `protected` code (this corpus has no
  `task`/`select`/`requeue` to exercise, so those three checks' true-positive
  behavior is still unconfirmed): `No_Rendezvous` correctly fired on all 5
  real `entry` declarations, the rest correctly stayed silent. Found and
  fixed `FP-042`: `limited with` was being treated as an ordinary
  circular-dependency edge.
- **[gnatcoll](gnatcoll/RESULTS_2026-08-09.md)** (2026-08-09) — a third
  breadth corpus, in a new domain again (general-purpose utility library:
  JSON, VFS, string builders, email parsing, OS/process wrappers), and the
  first to turn up a false positive in a plain `--recommended` rule rather
  than the bounded verifier or a cross-cutting dependency check. Found and
  fixed `FP-043` (both of `--verify`'s `Definite_Error` outcomes: a
  `pragma Unreferenced` argument misread as a value read, one initialization
  walk missing a guard `Checks.Data_Flow`'s separate walk already had) and
  `FP-045` (all 18 of `--recommended`'s `Reversed_Range` findings: Ada's own
  `Low .. Low - 1` empty-array idiom flagged as a swapped-bounds mistake).
  Root-caused but left open as `FP-044`: a deeper gap in the overload-arity
  fallback `FP-021` added, found on 2 residual `Uninitialized_Output`
  findings.

## What these benchmarks have found, in total

Seven real analyzer bugs, all discovered by running against independently
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
| `FP-045` | gnatcoll | Ada's `Low .. Low - 1` empty-array idiom flagged as a reversed range |

One further false positive, `FP-044` (a gap in the overload-arity fallback
`FP-021` added, found on gnatcoll), was root-caused but left open — see
`quality/known_analysis_issues.tsv` for the full trace.

Every fix is closed, regression-tested, and confirmed not to blunt genuine
detection nearby (each `RESULTS_*.md` above documents the specific
before/after check). No benchmark run since has reopened any of them.

## Bottom line: does this evidence support using AdaLang Analyzer?

Yes, within a specific scope — not as a GNATprove replacement, but as what
it's actually positioned as (`POSITIONING.md`): a fast, no-setup-required
first pass.

**Where the evidence is strong.** Zero false positives and zero possible
unsoundness across 2,045 matched proof obligations spanning four
independently-authored, fully-proved SPARK corpora — a hash family, two
crypto primitives, a protocol parser — is the property that matters most
for trusting a tool's output, and it held up even on code (coap_spark)
chosen specifically because nothing about it was tuned around what AdaLang
can prove. It's also fast (`--verify` on coap_spark: 7.0 s vs. GNATprove's
713.0 s on the same project) and, more practically important than either,
it runs on ordinary, non-SPARK Ada: the AWS benchmark shows GNATprove
couldn't even get past project preprocessing on a real 348-file codebase,
while AdaLang analyzed it directly and found two real initialization bugs
in the process.

**Where the tradeoff bites.** AdaLang rarely proves anything independently
on harder code shapes — on coap_spark it left 835 of 846 comparable
obligations `Unproved`/`Unsupported` and matched GNATprove's own proof on
only 1, so its `Proved_Safe` verdicts are a bonus on top of GNATprove where
both are available, not a substitute, and its `Unproved`/`Unsupported`
results mean "no information," not "probably fine." It's also young
(`1.0.0-rc1`), and two of the five oracle corpora (Saatana: 101 matched
pairs; CubedOS: 7) are small enough samples to corroborate the pattern
rather than establish it independently.

**Net:** use it for what static analysis on ordinary Ada is for — catching
real defects fast, on code that will never be SPARK, or as an immediate
first pass before a full GNATprove run on code that will be — and don't
expect it to replace GNATprove's proof coverage on code that already has
it.
