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
- **GNATcheck oracle comparison**: for the ~32 AdaLang rules with a
  direct/close GNATcheck counterpart (`GNATCHECK_RULE_COMPARISON.md`),
  GNATcheck's own findings on the same corpus become ground truth — an
  AdaLang finding with no matching GNATcheck finding at the same
  `(file, line)` is a potential false positive, and vice versa a potential
  false negative. Unlike the proof-obligation comparison above, this is
  matching two independently-implemented rule linters against each other,
  not verification results.

Every benchmark here is a `run.sh` + `README.md` (setup, toolchain notes,
pinned revision) + dated `RESULTS_*.md` (the actual numbers). Re-running one
after an analyzer change and adding a new dated results file, rather than
overwriting the old one, is how this directory is meant to grow.

## Independent-oracle comparisons (GNATprove as ground truth)

| Corpus | Author | Domain | Matched pairs | Unsoundness | False positives |
| --- | --- | --- | ---: | ---: | ---: |
| [sparknacl](sparknacl/) | rod-chapman | NaCl-style crypto, fixed-width arithmetic | 890 | 0 | 0 |
| [saatana](saatana/) | HeisenbugLtd | Phelix stream cipher | 101 | 0 | 0 |
| [libkeccak](libkeccak/) | damaki | SHA-3/Keccak sponge family | 212 | 0 | 0 |
| [coap_spark](coap_spark/) | mgrojo | CoAP protocol parsing/session state | 853 | 0 | 0 |
| [tokeneer](tokeneer/) | AdaCore/NSA | Access-control system (identification station) | 221 | 0 | 0 |
| [cubedos](cubedos/) | cubesatlab | Satellite message-passing bus (not fully proved) | 7 | 0 | 0 |

(Matched-pair counts as of each corpus's latest re-run — see the dated
`RESULTS_*.md` files below; several moved after `Ada_Membership_Expr`/
`Ada_Attribute_Ref` support landed in `VC_Prover` on 2026-08-11.)

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
style: SPARKNaCl 37/890 (~4%), Tokeneer 15/221 (~7%), libkeccak 50/212
(~24%), coap_spark 1/853 (~0.1%) — coap_spark's RecordFlux-generated
protocol contracts and session-state logic are the hardest code shape yet
for AdaLang's bounded verifier to independently prove, even though it
never gets one *wrong* there. coap_spark's `Proved_Safe` count did jump
substantially in the 2026-08-11 re-run (+283, the largest single-corpus
movement any fix has produced in this directory) — almost entirely outside
the strict matched-pair set, since it resolves obligation shapes
(buffer-length-bounded loops, protocol-field membership tests) that often
don't have a directly comparable GNATprove message at the same location;
see `coap_spark/RESULTS_2026-08-11.md`'s own re-run section for the full
breakdown.

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
- **All five re-run 2026-08-11** to validate `FP-047` (new `/`, `mod`,
  `rem` support in `Adalang_Analyzer.VC_Prover`'s SMT bridge, added after
  investigating why `coap_spark`'s own "both safe" rate was so low). Every
  matched-pair bucket and both risk buckets (possible unsoundness, false
  positive) came back bit-identical to each corpus's prior baseline on all
  five — **[sparknacl](sparknacl/RESULTS_2026-08-11.md)**,
  **[saatana](saatana/RESULTS_2026-08-04.md)** (re-run, identical, no new
  dated file), **[libkeccak](libkeccak/RESULTS_2026-08-07.md)** (re-run,
  negligible noise-level wobble, no new dated file),
  **[cubedos](cubedos/RESULTS_2026-08-11.md)**, and
  **[coap_spark](coap_spark/RESULTS_2026-08-11.md)** itself, whose "both
  safe" rate stayed exactly 1/846 ≈ 0.1% — `FP-047` targeted `/`/`mod`/
  `rem`, but `coap_spark`'s actual stuck shape (`RFLX_Types.Fits_Into`'s
  `Value < 2 ** Size` precondition) needs exponentiation, deliberately left
  out of that fix's scope. `sparknacl` and `cubedos` each show a small,
  unmatched-pool obligation-count drop versus their prior baseline, traced
  (confirmed for `aws`, plausible but not independently re-confirmed for
  `sparknacl`/`cubedos`) to `FP-046`, an unrelated fix that landed in this
  same window — not to `FP-047`.
- **[tokeneer](tokeneer/RESULTS_2026-08-13.md)** (2026-08-13) — this
  project's oldest external corpus (first used before this benchmark
  directory's own `run.sh` convention existed; see
  `quality/external_corpus_findings.md` for that longer history), brought
  into this directory's reproducible-comparison shape for the first time.
  Also its largest yet by proof-obligation count (6,697 AdaLang
  obligations, 120 files). `test.gpr` sets no GNATprove `--report` switch
  of its own, the same gap `saatana` and `coap_spark` hit, fixed the same
  way (`--report=statistics` added on the command line).

## Real-code validation (no GNATprove oracle)

| Corpus | Author | Domain | Purpose |
| --- | --- | --- | --- |
| [aws](aws/) | AdaCore | Ada Web Server, ordinary (non-SPARK) Ada | Breadth on a large real project; GNATprove never got past project preprocessing; also the corpus with genuine unrestricted `select`/`requeue`/`abort` for the `--automotive` concurrency-prohibition checks |
| [ada_drivers_library](ada_drivers_library/) | AdaCore | STM32 bare-metal hardware drivers | Real Ravenscar `protected`-object code for the `--automotive` concurrency-prohibition checks (no `select`/`requeue`/`abort` — see aws) |
| [gnatcoll](gnatcoll/) | AdaCore | GNAT Components Collection core (JSON, VFS, strings, email, OS/process), ordinary (non-SPARK) Ada | A third breadth corpus in a new domain (general-purpose utility library); GNATprove hard-stops on a SPARK-illegal aspect 41 units in |
| [project_bias](project_bias/) | EliAvila10 | Bias-free cryptographic random streams | Small SPARK corpus emphasizing floating-point contracts, quantified array predicates, OS/C bindings, and entropy-buffer clearing; GNATprove reports one flow error, so it is not a fully-proved oracle |

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
  `task`/`select`/`requeue` to exercise, so three of those checks'
  true-positive behavior was left unconfirmed here): `No_Rendezvous`
  correctly fired on all 5 real `entry` declarations, the rest correctly
  stayed silent. Found and fixed `FP-042`: `limited with` was being treated
  as an ordinary circular-dependency edge.
- **[aws](aws/RESULTS_2026-08-09.md)** (2026-08-09) — a re-run of the same
  348-file AWS corpus, this time also under `--automotive`, closing the gap
  `ada_drivers_library` left open: AWS's own core server code (not its
  regression tests) genuinely uses `select`/`requeue`/`abort` in ordinary,
  unrestricted tasking (`aws-net-acceptors.adb`, `aws-server.adb`,
  `aws-session.adb`, `aws-server-push.adb`, `aws-smtp-server.adb`, and
  others), and `No_Select` (9), `No_Requeue` (4), `No_Abort` (1), and
  `No_Rendezvous` (34) all fired correctly on it, spot-checked against the
  real source. Also surfaced one new, not-yet-fixed `--verify`
  initialization false positive distinct from the already-fixed `FP-011`
  (same self-qualified-out-parameter shape, but in `--verify`'s own,
  separate initialization-tracking engine, which never got `FP-011`'s fix).
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
  Also root-caused and fixed at the mechanism level, `FP-044`: a deeper gap
  in the overload-arity fallback `FP-021` added, found on 2 residual
  `Uninitialized_Output` findings; the two findings that found it persist
  regardless, since they sit behind a separate, still-open Property_Error
  (the same general class as `FP-029`) that keeps the fixed code path from
  ever being reached for them in this environment.
- **[project_bias](project_bias/RESULTS_2026-08-11.md)** (2026-08-11) — a
  compact SPARK cryptographic-random-stream corpus with code shapes not
  otherwise prominent in the suite: floating-point functional contracts,
  quantified predicates, OS entropy bindings, and explicit buffer clearing.
  AdaLang completed all three preset lanes and conservatively recovered from
  one Libadalang `CallExpr` property failure. GNATprove proved 925 checks or
  flow properties but also reported three resource-limited checks and one
  missing-`Global` flow error, so this revision belongs in real-code
  validation rather than the independent-oracle totals. Its first run also
  identified focused review targets around package constants, contract-only
  parameter reads, and security-motivated dead stores; none is recorded as a
  confirmed analyzer defect without manual adjudication.
- **[aws](aws/RESULTS_2026-08-11.md)** (2026-08-11) — a third re-run of the
  same 348-file corpus, part of a sweep validating `FP-047` (new `/`,
  `mod`, `rem` SMT support). `--recommended`/`--spark`/`--automotive` and
  every `--automotive` concurrency-check count came back bit-identical to
  2026-08-09; `--verify`'s `Proved_Safe` count is also bit-identical
  (5,702), so `FP-047` was a clean no-op on this corpus. The four
  `Definite_Error` false positives 2026-08-09 had flagged as "newly found,
  not yet fixed" are gone, confirming the separately-landed `FP-046` fix
  closed them (also confirmed and re-run: **[gnatcoll](gnatcoll/RESULTS_2026-08-09.md)**
  and **[ada_drivers_library](ada_drivers_library/RESULTS_2026-08-05.md)**,
  both bit-identical to their prior baseline, no new dated files needed).
- **[project_bias](project_bias/RESULTS_2026-08-13.md)** (2026-08-13) — a
  long same-day chain of re-runs, all driven by one recurring shape in the
  corpus's own loops: `if Rnd_Buffer (Rnd_Len) in Unbiased then Chain_Len
  := Chain_Len + 1; ... end if;`, a one-sided branch inside a
  dynamically-bounded loop. Five successive fixes (leading-invariant
  pragma-order tolerance, one-level `if`/`else` branch-merge support,
  array-element-write tolerance, symbolic `'Length` for unconstrained
  array parameters, and a dynamic-subtype base-range fallback) were each
  independently real, regression-tested, and zero-regression on every
  other corpus re-checked alongside them — and each still left this
  corpus's own `Proved_Safe` count unmoved, precisely diagnosed each time
  as blocked one layer further in. The eventual payoff came from two more
  fixes the same day: representing a loop-merge's disagreeing branch
  values as an SMT `ite` over the branch's own condition (or an anonymous
  placeholder selector when that condition itself doesn't translate,
  e.g. an array-indexed read) instead of discarding them into an
  unconstrained fresh symbol, plus a genuine, previously-undiscovered bug
  the first fix's own precision gain exposed: `VC.Assume` bailing to a
  totally empty symbolic state on *one* untranslatable leading invariant
  was silently discarding every fact already assumed from a loop's
  *other*, independently provable leading invariants, in both places a
  loop's invariants are assumed one at a time
  (`Apply_Loop_Invariants`/`Prove_Header`, `flow_interp.adb`). Fixing that
  finally let the `ite`-encoded merge use the loop guard the way it was
  designed to. Net for the file: `Proved_Safe` 400 → 425 (+25),
  `Definite_Error` 0 throughout, matched-GNATprove-pair buckets showing
  zero possible unsoundness and zero false positives at every step along
  the way — a case study in a fix chain where most individual steps
  measure zero on the corpus that motivated them, right up until the one
  that finds what was actually blocking all of them.

## New-check corpus validation (2026-08-17)

Ten checks landed the same day (`Integer_Division_Before_Multiplication`,
`No_Unchecked_Access`, `Duplicate_With_Clause`, `Excessive_Shift_Amount`,
`Reraise_Discards_Occurrence`, `Duplicate_Exception_Choice`,
`Succ_Pred_Boundary_Overflow`, `Redundant_If_Boolean_Return`,
`Redundant_Final_Return`, `Entry_Barrier_Side_Effect`), validated only
against synthetic `quality/precision_corpus.tsv` fixtures and a clean
self-analysis run at the time. Before deciding whether any belonged in
`--recommended`, all ten were run (isolated via `-checks="-*,<the ten
names>"`) against every corpus in this directory — the seven SPARK/oracle
corpora above plus the three real-code ones (aws, gnatcoll,
ada_drivers_library) — ~950 files total, no `-P`/build step required for
any of them beyond what each corpus's own entry above already documents.

Nine of the ten found nothing anywhere, SPARK or not. `No_Unchecked_Access`
was the exception: 48 hits, all in the three non-SPARK corpora (gnatcoll
24, aws 21, ada_drivers_library 3) and zero in any SPARK corpus — expected,
since `'Unchecked_Access` is not legal in `SPARK_Mode => On` code. A sample
was spot-checked directly against source; all genuine (the check is a
literal attribute-name match, so it cannot misfire). `Redundant_Final_Return`
(1, gnatcoll) and `Redundant_If_Boolean_Return` (1, aws — a textbook `if X
in [...] then return True; else return False; end if;` in
`AWS.Utils.Is_Ada_Reserved_Word`) were each genuine but too sparse, alone,
to draw a signal from.

The run also caught `Reraise_Discards_Occurrence` misfiring on
`aws-config-utils.adb`'s `Value` function: `raise Constraint_Error with
Error_Context & "unrecognized option " & Item;` inside a `when
Constraint_Error =>` handler with no other choices. The check's own
rationale (naming the caught exception loses the original message/
traceback) doesn't apply here — the `with`-message deliberately *replaces*
the message with better diagnostic context before re-propagating, a
legitimate idiom distinct from the accidental-loss bare `raise Foo;` shape
the check exists to catch. Fixed same-session as `FP-051` (see table
below): the check now exempts any raise with a non-null `F_Error_Message`.

`No_Unchecked_Access` is structurally identical to two already-shipped
checks, `No_Unchecked_Conversion` and `No_Unchecked_Deallocation`: all
three flag every instance of a construct that is sometimes genuinely
necessary, not a defect pattern with a low false-positive rate to tune.
Both siblings are deliberately excluded from `--recommended` (see the
comment on `Enable_Recommended_Preset`, `adalang_analyzer-cli.adb`) and
instead live in `--spark`, `--automotive`, and DO-178C Level A/B — profiles
where a restricted-construct policy is actually in force. Despite the
corpus signal, `No_Unchecked_Access` was placed the same way as its
siblings, not added to `--recommended`, to keep that established
recommended/profile boundary intact; see `AUTOMOTIVE_ADA_COMPLIANCE_MATRIX.md`
and `DO178C_COMPLIANCE_MATRIX.md` for its entries in those matrices.

## Older-check corpus validation: Duplicate_Subprogram, Assertion_Side_Effect (2026-08-17)

Two more checks had never been run against an external corpus at all --
only self-analysis (17 findings on this project's own source for
`Duplicate_Subprogram`, reviewed by hand at the time; zero for
`Assertion_Side_Effect`, which needs the rare combination of an assertion
condition calling a function with an out/in-out parameter). Both were run
in isolation against the same ten corpora as the sweep above.

`Assertion_Side_Effect` again found nothing anywhere -- the combination it
targets is narrow enough that ten real corpora, SPARK and not, still don't
contain an example. No change from this.

`Duplicate_Subprogram` found 394 findings across nine of the ten corpora
(zero only in saatana): sparknacl 10, project_bias 9, tokeneer 9, gnatcoll
68, libkeccak 14, cubedos 13, coap_spark 132, ada_drivers_library 27, aws
112. Every single one, in every corpus, is a *cross-file* match (never two
duplicate bodies in the same file) -- a different profile than the
same-file pair `precision_duplicate_subprogram_finding.adb` exercises, and
the reason this corpus run was worth doing even though the check already
had a synthetic positive fixture.

Investigating the volume rather than assuming it was noise:

- coap_spark's 132 is 129 findings inside `generated/rflx-*.adb`
  (RecordFlux-generated protocol code) and only 3 in hand-written source.
  The generated ones are technically correct -- the bodies genuinely are
  identical -- but not something a developer would act on: the fix would
  be to the code generator's template, not the generated output. The 3
  hand-written findings (`coap_spark-client_session.adb`/
  `coap_spark-server_session.adb`'s `Read`/`Write`, `secure_server.adb`/
  `coap_secure.adb`'s `Update`) are genuine extraction candidates.
- gnatcoll's 68 and aws's 112 split roughly 2:1 into same-name pairs
  (parallel Unix/Windows implementations of the same operation, e.g.
  `gnatcoll-io-remote-unix.adb`/`gnatcoll-io-remote-windows.adb`'s
  `Read_Whole_File`) and different-name pairs. The latter turned out to be
  a real, useful pattern on inspection, not noise: gnatcoll's
  `Is_Symbolic_Link`/`Is_Readable`/`Is_Writable`/`Is_Directory`/
  `Is_Regular_File`/`Change_Dir`/`Make_Dir` (all in
  `gnatcoll-io-remote-unix.adb`) share the identical three-statement
  `Exec.Execute_Remotely (Args, Status); Free (Args); return Status;`
  body -- the check's own disclosed limitation ("local declarations not
  compared") is exactly why they match: the actual differentiating shell
  command (`"test"`/`"-L"` vs `"-r"` vs `"cd"`, ...) lives in each
  function's own declarative part, which the check deliberately doesn't
  compare. That's not a false positive; it's the check surfacing a real
  "these could be one helper parameterized by the shell command" shape,
  exactly what the disclaimer in every finding's message already warns a
  reader to go check.
- ada_drivers_library's 27 are, all 27 of them, matches between two files
  that share a simple name in different directories -- this corpus's
  per-chip-family driver layout (`crc_stm32f4/stm32-crc.adb` vs
  `crc_stm32f7/stm32-crc.adb`, each providing its own implementation for
  the same nominal package). This is where **FP-052** was found: the
  "matches X at Y" half of the message rendered the matched location via
  `Ada.Directories.Simple_Name`, dropping the directory, so two files
  sharing a basename produced a message reading as if a body had been
  reported as a duplicate of itself ("`stm32-crc.adb:72` ... identical to
  ... `stm32-crc.adb:72`"). The underlying detection was correct the whole
  time -- both chip variants' `Update_CRC` genuinely are byte-identical --
  only the citation was ambiguous. Fixed by reporting the matched
  location's full filename instead of its simple name; covered by
  `tests/run_clone_detection.sh`'s cross-file pair (two files both named
  `shared_body.adb`, in `tests/duplicate_subprogram_cross_file/variant_a/`
  and `variant_b/`).

No false-positive class turned up in `Duplicate_Subprogram` itself across
any of the ten corpora -- every sampled finding, in every corpus, pointed
at a real, explainable duplication. That's a materially stronger basis
than the original self-analysis-only evidence it shipped with.

## GNATcheck oracle comparison

Tracked as an open item in `AUTOMOTIVE_ADA_COMPLIANCE_MATRIX.md`'s gap
register ("independent-oracle (e.g. GNATcheck) tests with measured
false-positive and false-negative results") and prepared for at the
rule-name level in `GNATCHECK_RULE_COMPARISON.md`, which found 18 direct
and 14 close AdaLang/GNATcheck rule-name matches from documentation alone,
explicitly *not* a substitute for running both tools. This section is that
run. GNATcheck has no Alire package and no prebuilt download — the binary
used here was built entirely from source (no AdaCore account/license), a
real multi-hour undertaking on its own; see `project_gnatcheck_acquisition.md`
in this session's memory for the full recipe and every macOS-specific
workaround it needed. It exists only on the machine it was built on, is
not committed anywhere, and reproducing a run elsewhere means rebuilding
it first.

Shared infrastructure for every corpus's GNATcheck lane:
`benchmarks/gnatcheck_rule_map.tsv` (the rule-pair map, expanded from
`GNATCHECK_RULE_COMPARISON.md`'s tables to 39 individual pairs across 31
AdaLang rules) and `benchmarks/gnatcheck_compare.awk` (the comparator,
matching on `(basename(file), line, rule pair)` — same line-granularity
convention as the GNATprove `compare.awk`). Each corpus adds its own
`run_gnatcheck.sh`, following the same pinned-revision-verification
pattern as its GNATprove `run.sh`.

| Corpus | AdaLang findings | Matched by GNATcheck | GNATcheck findings | Matched by AdaLang |
| --- | ---: | ---: | ---: | ---: |
| [sparknacl](sparknacl/RESULTS_gnatcheck_2026-08-19.md) | 1557 | 1334 (85.7%) | 1758 | 1334 (75.9%) |
| [aws](aws/RESULTS_gnatcheck_2026-08-19.md) | 6288 | 3294 (52.4%) | 11356 | 3283 (28.9%) |
| [gnatcoll-core](gnatcoll/RESULTS_gnatcheck_2026-08-19.md) | 1870 | 1044 (55.8%) | 2665 | 1042 (39.1%) |
| [ada_drivers_library](ada_drivers_library/RESULTS_gnatcheck_2026-08-19.md) | 849 | 367 (43.2%) | 943 | 367 (38.9%) |
| [cubedos](cubedos/RESULTS_gnatcheck_2026-08-19.md) | 182 | 156 (85.7%) | 617 | 156 (25.3%) |
| [coap_spark](coap_spark/RESULTS_gnatcheck_2026-08-19.md) | 779 | 641 (82.3%) | 7629 | 641 (8.4%) |
| [libkeccak](libkeccak/RESULTS_gnatcheck_2026-08-19.md) | 1460 | 1224 (83.8%) | 1354 | 1224 (90.4%) |
| [saatana](saatana/RESULTS_gnatcheck_2026-08-19.md) | 157 | 96 (61.1%) | 120 | 96 (80.0%) |
| [project_bias](project_bias/RESULTS_gnatcheck_2026-08-19.md) | 225 | 165 (73.3%) | 263 | 165 (62.7%) |
| [tokeneer](tokeneer/RESULTS_gnatcheck_2026-08-19.md) | 596 | 444 (74.5%) | 1602 | 425 (26.5%) |

All ten corpora tracked by `benchmarks/README.md`'s GNATprove comparison
now have a GNATcheck-oracle counterpart run; this pass is complete.
(GNATcheck's own findings show real run-to-run variance on this from-source
build — see each corpus's caveats section; treat exact counts as
approximate, the qualitative findings below as the reliable part.)

**Recurring crash class, now seen on 6 of 10 corpora — reads as a build
defect, not a per-corpus issue.** The `STORAGE_ERROR: stack overflow`
("unparsable worker output") first seen on `aws` recurred on
`ada_drivers_library`, `cubedos`, `libkeccak` (twice), `saatana`, and
`project_bias` — independent of corpus size (it hit `saatana`'s ~1,200-line,
5-unit corpus exactly as it hit the multi-thousand-line real-code corpora),
domain, or SPARK-vs-ordinary-Ada status. `gnatcoll-core`, `coap_spark`, and
`tokeneer` are the only clean runs. Every occurrence lets the batch continue
(consistent with a single parallel worker crashing, not the whole invocation
aborting), and the exact triggering rule/file has never been isolated from
the interleaved parallel output across any of the six occurrences. Worth
tracking as a quality issue in the from-source GNATcheck build itself
(`project_gnatcheck_acquisition.md`), separate from any AdaLang/GNATcheck
rule-logic question.

**Two open items surfaced by this pass, needing a maintainer decision or
follow-up:**
1. `cubedos`'s `Exception_Propagation` found **zero** findings on task
   bodies GNATcheck's `exception_propagation_from_tasks` flags 8 times, on
   genuinely `SPARK_Mode (On)` code — unlike the AWS/gnatcoll-core
   `Exception_Propagation` gap (which is *broader* than GNATcheck by
   design), this looks like the opposite: a possible real coverage miss
   specific to `task body` constructs. Not yet root-caused; see
   [cubedos's results](cubedos/RESULTS_gnatcheck_2026-08-19.md#finding-worth-maintainer-attention-exception_propagation-finds-nothing-on-task-bodies-gnatcheck-flags).
2. `coap_spark/README.md`'s documented SPARKlib `GPR_PROJECT_PATH` override
   no longer works as written on this machine's current `alr`/`gpr2`
   (directory-less `with` resolution now checks the with-ing project's own
   directory before `GPR_PROJECT_PATH`, so the pinned checkout's own
   `sparklib.gpr` always wins regardless of ordering) — worked around for
   this GNATcheck run only by relocating the throwaway clone's own
   `sparklib.gpr`, but `coap_spark/run.sh` (the GNATprove comparison) was
   not touched and likely hits the same failure unmodified now; see
   [coap_spark's results](coap_spark/RESULTS_gnatcheck_2026-08-19.md#environment-fix-required-beyond-what-readmemd-documents).

- **[sparknacl](sparknacl/RESULTS_gnatcheck_2026-08-19.md)** (2026-08-19) —
  the first real run. `recursive_subprograms` (paired with `No_Recursion`)
  reliably crashes this from-source GNATcheck build with a native stack
  overflow doing whole-program call-graph analysis, even at the maximum
  `ulimit -s` macOS allows; excluded from this and future runs until
  resolved. Investigated the three largest divergences directly against
  source rather than just reporting the numbers: AdaLang's
  `Non_Short_Circuit_Condition` is deliberately scoped to executable
  statement conditions and doesn't examine `Pre =>`/`Post =>` contract
  aspects the way GNATcheck's `non_short_circuit_operators` does (99% of
  this run's GNATcheck-only findings); `Naming_Convention` and
  `min_identifier_length` check different, only partially-overlapping
  populations of "short identifier" (AdaLang exempts loop indices,
  GNATcheck doesn't; GNATcheck doesn't flag short parameter names, AdaLang
  does); and `maximum_parameters`'/`metrics_cyclomatic_complexity`'s
  GNATcheck-only findings are almost entirely a default-threshold gap (3
  vs. AdaLang's 6 for parameter count), not a logic difference. On the
  large, non-threshold-configurable `Magic_Number`/`numeric_literals`
  pair, the two independently-implemented tools agreed at 91% — the
  strongest positive signal in this run. Only one corpus so far, and a
  small, disciplined SPARK one at that (many direct-match rules, e.g.
  `No_Goto`/`No_Abort`, show zero violations on either side here); a
  real-code corpus (`aws`, `ada_drivers_library`) is the natural next run
  to actually exercise them.
- **[aws](aws/RESULTS_gnatcheck_2026-08-19.md)** (2026-08-19) — the first
  real-code run, and it needed a real infrastructure fix first: the
  GNATcheck runtime environment's own `GPR_PROJECT_PATH` was shadowing
  AWS's real `gnatcoll_core`/`xmlada` dependencies with gnatcheck's
  headers-stripped internal build of the same names, breaking project
  loading outright; fixed by running the AdaLang lane before sourcing
  that environment and appending (not prepending) its paths for the
  GNATcheck lane — a durable fix, not an AWS-specific workaround. Once
  working, this corpus surfaced two effects the rule-name-level comparison
  didn't predict, not the same-flavor scope nuances sparknacl found:
  (1) `Too_Many_Parameters`/`maximum_parameters` both agree, per spot check,
  on which subprograms have too many parameters — they just cite the
  *specification* line (GNATcheck) vs. the *body* line (AdaLang) when a
  subprogram has both, which line-exact matching can't reconcile, so the
  pair's "0% matched" headline is a comparator-design artifact, not a
  detection disagreement; (2) `Exception_Propagation` checks *every*
  subprogram lacking an exception boundary, while its three mapped
  GNATcheck rules are scoped narrowly to callback/`Export`/task
  boundaries only — confirmed against both checks' own descriptions, a
  real scope-breadth gap the "Close" label undersold, not a
  reporting-location artifact. Also found: `Missing_Global_Contract` (and
  six sibling checks sharing the same gating function) fires on ordinary
  Ada with **zero** `SPARK_Mode` markings anywhere in the corpus, because
  `Effective_SPARK_Enabled`'s fallback treats "no SPARK_Mode found
  anywhere in the ancestor chain" as SPARK-enabled by default. A follow-up
  session investigated changing this and confirmed it's intentional, not a
  bug: `tests/run_bug_findings.sh` has a dedicated regression proving the
  `--spark` preset is meant to fire on unmarked code too (a "readiness"
  check nudging ordinary Ada toward SPARK adoption, not a check restricted
  to code that already adopted it) — see the results file for the full
  trail, including two reverted code-change attempts before this was
  confirmed. `-list-checks` wording for the four checks that overclaimed
  "SPARK subprograms" was corrected; no behavior changed. What matched
  cleanly, at real-code
  volume: `Naming_Convention`/`min_identifier_length` reproduced sparknacl's
  loop-index/parameter-name split; `Magic_Number`/`numeric_literals` held
  at 89% (vs. sparknacl's 91%); `No_Access_To_Subp_Def`/`subprogram_access`
  matched 100% (112/112) — the cleanest direct-match result in either run.
- **[gnatcoll-core](gnatcoll/RESULTS_gnatcheck_2026-08-19.md)** (2026-08-19)
  — second ordinary-Ada, real-code corpus; ran clean end-to-end with no
  crash. Confirmed both of AWS's headline findings independently (the
  spec-vs-body `Too_Many_Parameters`/`maximum_parameters` split; the
  zero-`SPARK_Mode` `Missing_Global_Contract` behavior, already established
  as intentional) and surfaced a new variant: `No_Multiple_Return`/
  `improper_returns` shows the same "both tools agree, comparator can't see
  it" shape as the spec/body split, but from reporting *granularity*
  instead — AdaLang reports once per subprogram, GNATcheck once per excess
  `return` statement, so even findings in the *same file* land on unrelated
  lines. `Magic_Number`/`numeric_literals` held its usual ~97% AdaLang-side
  agreement.
- **[ada_drivers_library](ada_drivers_library/RESULTS_gnatcheck_2026-08-19.md)**
  (2026-08-19) — first embedded/driver corpus, and the first that needed a
  real methodology adaptation before GNATcheck could run at all: this
  driver subtree has no single project file GNATcheck can load (six
  mutually-exclusive board-variant directory pairs redeclare the same
  package basename, which a GNAT project closure can't contain
  simultaneously, unlike Libadalang's file-list provider which AdaLang
  uses here). Fixed by hand-partitioning the 90 files into two disjoint
  synthetic GPR projects, verified exact against a flat file listing. Two
  `STORAGE_ERROR` crashes occurred (see the recurring-crash note above);
  `Dependency_Limit`/`too_many_dependencies` reads as uninformative on this
  corpus for both tools, since the driver subtree intentionally excludes
  units it `with`s, breaking dependency counting generically.
- **[cubedos](cubedos/RESULTS_gnatcheck_2026-08-19.md)** (2026-08-19) —
  first corpus with its own project-embedded GNATcheck rule configuration
  (`cubedos.gpr`'s `package Check`), which silently changed several rules'
  effective results until suppressed with `--ignore-project-switches` to
  keep this run's rule set consistent with every other corpus. Otherwise
  confirmed the established spec/body and threshold-gap effects, plus
  surfaced the `Exception_Propagation`/task-body gap noted above.
- **[coap_spark](coap_spark/RESULTS_gnatcheck_2026-08-19.md)** (2026-08-19)
  — second fully-SPARK corpus, and the largest by GNATcheck finding volume
  (7,629). Needed the environment fix noted above before either lane could
  load the project at all. Produced the series' first 100%/100% match at
  real volume — `No_Goto`/`goto_statements`, 136/136 — on RecordFlux's
  generated `goto`-heavy state-dispatch code, and a new rule-pair variant:
  `Missing_Global_Contract` doesn't fire when a subprogram has an explicit
  `Depends` aspect (from which `Global` is inferable) even without an
  explicit `Global` aspect, while GNATcheck's `spark_procedures_without_
  globals` still requires `Global` explicitly.
- **[libkeccak](libkeccak/RESULTS_gnatcheck_2026-08-19.md)** (2026-08-19) —
  third SPARK corpus, and the best-agreeing run of the entire series: 83.8%
  AdaLang-side / 90.4% GNATcheck-side, both series highs. `Magic_Number`/
  `numeric_literals` reached 100% GNATcheck-side match at four-figure
  volume (1054/1054) — the first rule pair in the series to hit 100% in
  that direction at real scale.
- **[saatana](saatana/RESULTS_gnatcheck_2026-08-19.md)** (2026-08-19) — the
  smallest corpus in the series (~1,200 lines), included specifically to
  test whether the recurring crash class was scale-dependent; it wasn't
  (see above). Second-best GNATcheck-side match rate (80.0%) despite the
  small sample.
- **[project_bias](project_bias/RESULTS_gnatcheck_2026-08-19.md)**
  (2026-08-19) — a floating-point-heavy entropy engine; gave two rule pairs
  their first large, clean two-way matches in the series:
  `Floating_Equality`/`float_equality_checks` (31/31) and
  `Redundant_Boolean_Comparison`/`redundant_boolean_expressions` (14/14).
- **[tokeneer](tokeneer/RESULTS_gnatcheck_2026-08-19.md)** (2026-08-19) —
  tenth and final run of this pass; a mature, fully-GNATprove-verified
  security-critical system, and one of only three clean (no-crash) runs.
  `Exception_Swallowed` and `Empty_Exception_Handler` both matched 100%
  (19/19) at real volume, and `Non_Short_Circuit_Condition` reached 89% —
  the best showing for that pair on hand-written (non-generated) code in
  the series.

## What these benchmarks have found, in total

Ten real analyzer bugs, all discovered by running against independently
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

`FP-044`'s own two originating findings (gnatcoll-buffer.adb's
`Current_Text_Position`) persist despite the fix, unlike every other row
above: they sit behind a separate, still-open Property_Error (`FP-029`'s
general class) that keeps the fixed code path from ever being reached for
them in this environment — see `quality/known_analysis_issues.tsv` for the
full trace.

Every fix is closed, regression-tested, and confirmed not to blunt genuine
detection nearby (each `RESULTS_*.md` above documents the specific
before/after check). No benchmark run since has reopened any of them.

## Bottom line: does this evidence support using AdaLang Analyzer?

Yes, within a specific scope — not as a GNATprove replacement, but as what
it's actually positioned as (`POSITIONING.md`): a fast, no-setup-required
first pass.

**Where the evidence is strong.** Zero false positives and zero possible
unsoundness across 2,056 matched proof obligations spanning four
independently-authored, fully-proved SPARK corpora — a hash family, two
crypto primitives, a protocol parser — is the property that matters most
for trusting a tool's output, and it held up even on code (coap_spark)
chosen specifically because nothing about it was tuned around what AdaLang
can prove. It's also fast (`--verify` on coap_spark: 7.0 s vs. GNATprove's
713.0 s on the same project) and, more practically important than either,
it runs on ordinary, non-SPARK Ada: the AWS benchmark shows GNATprove
couldn't even get past project preprocessing on a real 348-file codebase,
while AdaLang analyzed it directly and found two real initialization bugs
in the process. gnatcoll-core repeats the same pattern in a third,
unrelated domain (a general-purpose utility library, not a web server or
crypto primitive): GNATprove hard-stops on a SPARK-illegal aspect 41 units
into the project, while AdaLang completed a full pass and, in the process,
found and fixed two more real false positives (`FP-043`, `FP-045`).

**Where the tradeoff bites.** AdaLang rarely proves anything independently
on harder code shapes — on coap_spark it left 842 of 853 comparable
obligations `Unproved`/`Unsupported` and matched GNATprove's own proof on
only 1, so its `Proved_Safe` verdicts are a bonus on top of GNATprove where
both are available, not a substitute, and its `Unproved`/`Unsupported`
results mean "no information," not "probably fine." It's also young
(`1.0.0-rc1`), and two of the five oracle corpora (Saatana: 101 matched
pairs; CubedOS: 7) are small enough samples to corroborate the pattern
rather than establish it independently.

**Not every real-code run finds something new.** project_bias's first pass
(17 files, floating-point entropy contracts, quantified array predicates,
C/Windows entropy bindings) completed all three preset lanes cleanly, with
zero `--recommended`/`--spark` rule false positives — a useful negative
data point against reading the eight-bug table above (scoped to exactly
those lint-style checks) as evidence that every corpus run turns up a
defect in them. A later same-day return to the same corpus did surface a
real `--verify`-side bug (see the 2026-08-13 bullet above), but only after
five prior, individually-real, individually-zero-payoff-on-this-corpus
fixes and direct experimentation on the corpus's own source — not
something the corpus's own first pass, or either rule lane, ever flagged
on its own. Its 27 GNATprove-matched pairs also showed zero disagreement
throughout, unaffected by any of that same-day work, but the corpus isn't
a fully-proved oracle (GNATprove itself leaves three step-limited checks
and one flow error unresolved there), so that sample is both too small
and too weak an oracle to add to the 2,056-obligation total above; it
corroborates without counting.

**Net:** use it for what static analysis on ordinary Ada is for — catching
real defects fast, on code that will never be SPARK, or as an immediate
first pass before a full GNATprove run on code that will be — and don't
expect it to replace GNATprove's proof coverage on code that already has
it.
