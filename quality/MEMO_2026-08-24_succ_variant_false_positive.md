# Memo: `'Succ`/`'Pred` false `Definite_Error` on loop-variant progress

**Date:** 2026-08-24
**Status:** Root-caused, not fixed. Tracked as `FP-061` in `quality/known_analysis_issues.tsv` (open).
**Priority pick for the next session** — chosen over further branch-shape work (see "Why this over more `--verify` feature work" below).

## The bug, in one line

`--verify` reports `Definite_Error` — a *proven* violation — on an ordinary `'Succ`-based loop
counter that plainly makes progress and that real GNATprove proves cleanly. It is a false
positive in the tool's strongest claim category.

## Reproduction (11 lines, no external corpus needed)

```ada
procedure Integer_Variant_Control is
   subtype Small_Index is Integer range 0 .. 14;
   Key_Index : Small_Index := 1;
begin
   while Key_Index < 14 loop
      pragma Loop_Variant (Increases => Key_Index);
      Key_Index := Small_Index'Succ (Key_Index);
   end loop;
end Integer_Variant_Control;
```

```sh
./bin/adalang_analyzer --verify -q --format=json --output=/tmp/x.json <file above>
# proofObligations[kind=loop-variant].status == "definite-error"
```

Confirmed as a genuine false positive: `gnatprove -P <project-wrapping-the-file-above>
--mode=prove -f -q --output=oneline` returns **zero findings** (exit 0, no output) on the
identical source.

### Isolating what actually triggers it

| Variant | Result |
|---|---|
| `Small_Index'Succ (Key_Index)` (the reproduction above) | `definite-error` (false) |
| Same shape, `Interfaces.Integer_32`-derived subtype instead of `Integer` | `definite-error` (false) — **not type-specific** |
| Same shape, `Key_Index := Key_Index + 1` instead of `'Succ` | `unproved` (safe, conservative) |
| `'Succ` used in an ordinary (non-loop-variant) assignment + `pragma Assert` | `unproved` (safe) — the false-*positive* shape is specific to the before/after **comparison** in variant-progress, not to `'Succ` translation on its own |

So: it's `'Succ`/(presumably)`'Pred` specifically, not the underlying integer type, and not a
general translation bug — only the loop-variant-progress comparison turns the translation gap
into a wrong *positive* claim instead of a safe `Unproved`.

## How it was found

Surfaced while re-verifying the elsif-chain loop-invariant-preservation fix (this session's
other work) against 8 real-world corpora. `sparknacl-aes.adb:714,743` (the AES256/AES128
`Cipher` procedures' round-key loops) both hit this. Confirmed present already at commit
`0b9bb93` (immediately before this session's elsif work) via an isolated same-checkout binary
comparison — **not caused by anything landed this session**. Full detail:
`benchmarks/sparknacl/RESULTS_2026-08-13.md`, "Follow-up re-verification" section, "Aside."

## Root cause (read directly from the code, not guessed)

1. `Adalang_Analyzer.VC_Prover.Integer_Term`'s `Ada_Attribute_Ref` case
   (`src/adalang_analyzer-vc_prover.adb`, ~line 1017) only translates `'First`/`'Last`/`'Length`.
   `'Succ`/`'Pred` correctly fall to `Mark_Unsupported` — this part is fine.
2. `VC.Assign` (~line 1730): when the RHS fails to translate (`not Context.Supported`), it
   returns `Havoc` — **the empty `Symbolic_State`**, discarding *every* prior binding, root, and
   assumption, not just the one being assigned. This is the same fallback used everywhere in
   `VC.Assign` for any unsupported RHS; it's a blunt instrument by design elsewhere, but it has a
   sharp edge here.
3. `Decide_Variant_Progress` (~line 2623) then calls `Integer_Term` on the bare variant
   expression (`Key_Index`, not the `'Succ(...)` form) in both the **before** state (still has
   whatever bindings existed pre-assignment) and the **after** state (now `Havoc`, zero
   bindings). With no binding in either, both independently fall through to `Symbol_For`'s
   "plain root, no binding" case — which names the root purely from the object's own identity
   (`Root_Name`), **not** from which state snapshot it's being evaluated in. `Before_Term` and
   `After_Term` end up as the *literal same SMT symbol*.
4. The goal built for `Increases` is `"(> " & After_Term & " " & Before_Term & ")"` — which is
   now `(> X X)`, a tautological contradiction. The solver correctly reports it UNSAT (the goal
   can never hold) — but the engine reads "goal UNSAT" as "the variant is definitely violated"
   (`Definite_Error`), not as "translation collapsed the two sides into the same unconstrained
   placeholder, this should be `Unsupported`."

This is a translation-completeness gap (step 1) compounding with an overly-blunt failure mode
(step 2) that specifically manifests as a false *positive* only in the before/after-comparison
shape of variant-progress checking (step 3–4) — not in any one-shot `Decide`/`Decide_Bounds`
call, which is presumably why nothing caught it until a before/after comparison happened to hit
an unsupported RHS.

## Candidate fixes for tomorrow (not mutually exclusive — I'd do both)

**1. Root fix — teach `Integer_Term` to translate `'Succ`/`'Pred`.**
Add a case alongside the existing `'First`/`'Last`/`'Length` handling: for a discrete scalar
prefix type, `T'Succ(X)` → `(+ <term for X> 1)`, `T'Pred(X)` → `(- <term for X> 1)`. This is the
higher-value direction: it doesn't just remove a false positive, it turns a large, common class
of loop-counter idioms (`I := T'Succ(I);`, standard in SPARK-style code) into genuine new
`Proved_Safe` results — plausibly higher real-world payoff than this session's elsif/case work,
which measured zero impact across the same 8 corpora (see
`benchmarks/*/RESULTS_*.md`'s "Follow-up re-verification" sections). Watch for: base-range
resolution on the prefix type (reuse the existing multi-hop-subtype base-range logic already
built for overflow checks, don't re-derive it), and whether a bounds/overflow check is needed on
the `+1`/`-1` itself (probably yes, mirroring how ordinary `+`/`-` are already checked).

**2. Defensive guard — detect the collapse, don't feed a tautology to the solver.**
In `Decide_Variant_Progress` (and audit `Mark_Preservation`, the loop-invariant-preservation
path, for the same shape — not observed to reproduce there yet, but this reproduction's loop has
no `Loop_Invariant` to test it against), check `Before_Term = After_Term` as plain string/term
equality before building the goal; if equal, return `Unsupported`/`Unknown` rather than asking
the solver. Cheap, and defends against the same failure pattern recurring for *any* future
not-yet-supported attribute or expression form on a variant/invariant target, not just `'Succ`.

**Either fix needs**: a regression fixture (mirror `verification_loop_variant_increases.adb`'s
style, with `'Succ` instead of `+1`), added to `run_verification.sh` and the `gnatprove`
differential suite (this exact shape is trivially real-`gnatprove`-provable — confirmed above),
plus closing `FP-061` in `quality/known_analysis_issues.tsv` once verified.

## Why this over more `--verify` feature work

This session's elsif-chain and `case`-statement extensions to loop-invariant preservation, once
properly isolated (same-checkout, prior-commit-vs-current-commit comparison, not diffed against
stale dated snapshots), moved **zero** obligations across all 8 real-world corpora checked
(~72,700 combined proof obligations) — the branch shapes those extensions target simply don't
occur in this corpus set. A second sequential conditional or multi-choice `case` extension would
likely see the same pattern. This `'Succ` gap, by contrast, is a real false positive already
confirmed live in a real corpus, plausibly common (loop counters advanced via `'Succ` are a
standard idiom), and cheap to reproduce/verify. Better expected value for the next session than
continuing to build unproven branch-shape coverage.
