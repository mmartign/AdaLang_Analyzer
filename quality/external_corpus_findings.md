# External corpus findings

The precision corpus (see `README.md`) is hand-constructed: every fixture was
written to sit at a specific check's decision boundary, so it can only ever
confirm what the fixture's author already anticipated. This file tracks a
different, complementary activity: running the built analyzer against real
Ada/SPARK code the project did not write, to see what surfaces that no
hand-written fixture would have exercised.

Each entry records what was run, what was found, and what (if anything) was
done about it. A finding here is either folded into `known_analysis_issues.tsv`
(if it is a confirmed analyzer mistake) or left as a documented scope
observation (if it accurately reflects a documented limitation rather than a
defect).

## Tokeneer (AdaCore/spark2014 SPARK 2014 port)

- **Source**: `testsuite/gnatprove/tests/tokeneer` from
  `https://github.com/AdaCore/spark2014`, the SPARK 2014 translation of the
  NSA-released Tokeneer ID Station, described by AdaCore as fully verified
  with SPARK 2014. 120 source files.
- **Method**: `adalang_analyzer -P test.gpr --recommended --spark` for
  ordinary findings, and `--verify` for bounded scalar proof obligations.
- **Baseline run**: 1230 violations, 1588/1588 proof obligations unproved.

### Confirmed analyzer mistakes (fixed)

Four false positives were root-caused, fixed, and given regression coverage.
Full detail is in `known_analysis_issues.tsv`; summary:

| Issue | Mistake | Root cause |
| --- | --- | --- |
| `FP-004` | `Global_Contract_Mismatch` and related checks fired inside `SPARK_Mode => Off` scopes | `Effective_SPARK_Enabled` only checked a declaration's own aspect, never walked up to the enclosing scope SPARK_Mode is inherited from |
| `FP-005` | `Uninitialized_Output` flagged parameters that were, in fact, always initialized | A nested subprogram writing an enclosing `out` parameter through its own `Global` contract (not as a passed actual) was not recognized as initializing it |
| `FP-006` | `Depends_Contract_Mismatch`, `Incomplete_Depends_Contract`, `Missing_Depends_Contract` mishandled combined-output syntax `(A, B) => C` | Ada's own aggregate grammar has no comma-separated choice list, so Libadalang parses `(A, B)` as a nested positional aggregate; three independent parsers only recognized a plain-identifier designator |
| `FP-007` | `Uninitialized_Output` flagged composite `out` parameters fully initialized field-by-field or index-by-index | `Same_Parameter` only recognized a plain identifier as referring to the tracked parameter, not a selected component or an indexed/sliced name |

Cumulative effect of all four fixes on the same Tokeneer run:

| Check | Before | After |
| --- | --- | --- |
| Total violations | 1230 | 653 |
| `Missing_Global_Contract` | 50 | 3 |
| `Global_Contract_Mismatch` | 294 | 278 |
| `Missing_Depends_Contract` | 70 | 4 |
| `Incomplete_Depends_Contract` | 266 | 0 |
| `Depends_Contract_Mismatch` | 275 | 153 |
| `Uninitialized_Output` | 61 | 1 |

### Scope observation, not a defect: `--verify` on real code (open)

`--verify` classified 4687 bounded scalar obligations on Tokeneer's real
subprograms: 0 `Proved_Safe`, 0 `Definite_Error`, 4643 `Unproved`, 44
`Unsupported`. Breaking down the `Unproved` obligations by their recorded
`why`/`imprecision` fields (see `-v` output) shows this is not a hidden bug,
but the documented scope boundary made visible at scale:

- **857 of 874 `range-check` obligations (98%)** fail because "the current
  non-relational range domain is inconclusive" — the abstract domain tracks
  each variable's own interval independently and has no way to represent a
  relationship between two variables (`X <= Y`, `X = Y + 1`). This matches
  `ASSURANCE_MODEL.md`'s and `POSITIONING.md`'s own description of the domain
  as non-relational, with only narrow relational support for straight-line
  preconditions.
- **~3234 of the 3111 `initialization-check` obligations' occurrences**
  (obligations can be re-registered as analysis proceeds) fail because "the
  fixed-point state did not discharge this obligation" (1771) or "incoming
  paths disagree or object is external" (1463) — consistent with the
  analyzer's documented intraprocedural scope: Tokeneer is built almost
  entirely from private-child packages and cross-procedure calls (the same
  shape as the `FP-005` pattern above), so most initialization facts are
  conservatively discarded (`Flow_Havoc_All`) at every call boundary the
  analysis cannot see through.
- A further 44 obligations are explicitly tagged "outside bounded
  verification subset" rather than silently miscounted.

**Conclusion**: this is validated roadmap input, not a bug report. Closing
this gap requires either a relational abstract domain or interprocedural
call-effect summaries, both substantial engineering efforts matching
`POSITIONING.md`'s own stated strategic direction ("validation and careful
expansion of that [verify] boundary"), not a bug-fix-sized change. No action
taken here beyond recording the quantified evidence.

### Not yet investigated

- One residual `Uninitialized_Output` finding after the `FP-007` fix:
  `auditlog.adb`, `SetFileDetails`, writes its `LogFileEntries` array through
  `for I in LogFileIndexT loop LogFileEntries (I) := NumberEntries; end loop;`
  rather than by literal index or field name. Confirming that the loop
  covers every index of the array would require reasoning about the loop's
  index bounds against the parameter's own index subtype — a materially
  different, harder problem than recognizing a direct field/index write, and
  deliberately not attempted by the `FP-007` fix (which only widens
  recognition of direct writes, not loop coverage, to avoid trading a false
  positive for an unsound "any loop touching it counts" false negative).
  Left open; not yet triaged as a bug versus an accepted scope boundary.

## Simple Components (Dmitry A. Kazakov)

- **Source**: `alire-project/dak_simple_components` on GitHub, a mirror of
  the SourceForge `simplecomponentsforada` project. Large, mature, non-SPARK
  "ordinary Ada" — a deliberate contrast to Tokeneer's SPARK style, by a
  different author entirely.
- **Method**: `adalang_analyzer -P components.gpr --recommended` (the core
  pure-Ada project; excludes the database/crypto/network binding
  sub-projects). 359 files scanned, 1322 violations.
- **Result: no new confirmed analyzer false positive.** Spot-checked rather
  than exhaustively verified:
  - `Same_Operand`/`Duplicate_Boolean_Operand` caught a real bug in the
    library itself: `unbounded_unsigneds-parallel.adb:99`,
    `if S1.Length > 0 and then S1.Length > 0 then` (almost certainly meant
    to compare two different operands) — a true positive, and useful
    evidence the checks find genuine defects on code the project didn't
    write.
  - The 158 `Uninitialized_Output` findings include the same loop-based
    array-fill pattern documented as open above (e.g.
    `block_streams.adb`'s `Read`, filling `Item` via
    `while Last < Item'Last loop Item (Last) := ...; end loop;`) —
    corroborating evidence that the limitation is real and recurring, not a
    Tokeneer-specific artifact, and that the `FP-004`–`FP-007` fixes did not
    need revisiting.
  - `Function_Side_Effect` (50 findings, sampled `generic_b_tree.adb`):
    nested callback functions mutating an enclosing scope's local via
    closure capture. Looks like a legitimate true positive in every sampled
    case, not a checker defect.
  - `Aliasing_Between_Parameters` (1 finding): `unbounded_unsigneds.adb:3934`,
    `Mul (Q, Q);`, resolves to
    `procedure Mul (Multiplicand : in out Unbounded_Unsigned; Multiplier : Unbounded_Unsigned)`
    — `Multiplicand` is written, `Multiplier` is read, both actuals are the
    same object. A textbook true positive for the exact condition Ada RM
    6.4.1 leaves unspecified, even though squaring in place is very likely
    safe in this particular implementation.

## Muen Separation Kernel (attempted, inconclusive)

- **Source**: `jcdubois/muen` on GitHub (mirror of the codelabs.ch original).
- **Result: not usable as-is.** `kernel/kernel.gpr` depends on several
  packages (`policy`, `crash_audit`, `muen_common`, `muinterrupts`,
  `muschedinfo`, `mutimedevents`) that are not submodules at all — they are
  generated at build time from an XML system-policy definition supplied by a
  downstream integrator, not present in the core kernel repository. Running
  the 56 hand-written kernel sources directly (no `-P`) produced 270 skipped
  locations out of a much smaller finding count, and spot-checking one
  `Uninitialized_Output` finding (`sk-subjects_events.adb`, `Consume_Event`)
  confirmed it was a resolution artifact, not a real issue: the parameter is
  genuinely written via a named-actual call, but the callee's own package
  couldn't be resolved from this partial file set. Getting trustworthy
  signal out of Muen would require populating the `common`/`rts`/
  `build-cfg` submodules and running Muen's own policy-generation tooling
  against an example system — real infrastructure work, not attempted here.

## CubedOS (cubesatlab/cubedos)

- **Source**: `cubesatlab/cubedos` on GitHub, `src/library/cubedlib.gpr` —
  the core framework library (self-contained, no external `with`
  dependencies, unlike the top-level `cubedos.gpr` which needs AUnit).
- **Method**: `adalang_analyzer -P cubedlib.gpr --recommended --spark`.
  20 files scanned, 41 violations, 8 `Uninitialized_Output` findings.

### Confirmed analyzer mistake (fixed): FP-008

6 of the 8 `Uninitialized_Output` findings were false positives sharing one
root cause: `cubedos-lib-xdr.adb` defines a family of `Encode`/`Decode`
overloads (`XDR_Integer`, `XDR_Unsigned`, `XDR_Boolean`, `XDR_Hyper`, ...)
that share the same parameter count and modes, differing only in `Value`'s
type. Each forwards its own `out` parameter (`Last`) purely positionally to
another overload of the same name, e.g.:

```ada
procedure Encode (Value : in XDR_Integer; Data : in out XDR_Array;
                   Position : in XDR_Index_Type; Last : out XDR_Index_Type)
is
begin
   Encode (XDR_Integer_To_Unsigned (Value), Data, Position, Last);
end Encode;
```

`Call.P_Call_Params` demands one fully precise resolution of which overload
is selected for the *whole* call and returns nothing at all when that
fails — which it does here, since the ambiguity is severe enough that even
`Assoc.P_Get_Params (Imprecise_Fallback => True)` (the per-actual fallback
already used elsewhere in the codebase, e.g.
`Adalang_Analyzer.Checks.Data_Flow.Reads_Declaration`) raises rather than
returning empty. Only the more lenient operation of resolving the callee
*name* on its own (`Call.F_Name.P_Referenced_Decl (Imprecise_Fallback =>
True)`) succeeds. Fixed by adding a position-based fallback
(`Callee_Formal_At_Position`) for purely positional actuals: resolve just
the callee, then pair the Nth actual to the Nth formal by literal position.
Reproduced with a 3-overload, 20-line fixture
(`uninitialized_output_overloaded_forward_clean.adb`) faithfully copying the
real type shapes; confirmed to fail pre-fix and pass post-fix.

While fixing this, the analyzer's own self-analysis gate caught a real
style regression in the fix itself: two new `exception when others =>
null;` handlers tripped `Empty_Exception_Handler`/`Exception_Swallowed`.
Replaced with `Log_Verbose_Once` diagnostics, matching the codebase's
existing convention — a small, useful demonstration of the gate doing its
job on new code, not just old code.

### Scope observation, not a defect: static-bounded-loop writes (open)

The remaining `Uninitialized_Output` findings in `cubedos-lib-xdr.adb`
(3, after the `FP-008` fix) write a scalar `out` parameter unconditionally
inside a `for I in 1 .. 3 loop`:

```ada
for I in 1 .. 3 loop
   Temporary_2 := Temporary_1 * 256 + XDR_Unsigned (Data (Position + I));
   Value := Temporary_2;
   Temporary_1 := Value;
end loop;
```

Every loop kind (`for`, `while`, plain `loop`) is deliberately treated as
"might not execute at all" by `Interpret_Initialization` — a documented,
reasonable default for loops that can `exit` or whose range isn't
statically known to be non-empty. But `for I in 1 .. 3` has a *statically*
non-empty range and no `exit`/`return`/`raise` before the write, so the
write is in fact unconditional. This is a narrower, more tractable relative
of the already-documented array-loop-coverage limitation (Tokeneer's
`SetFileDetails`, Simple Components' `Read`) — that one needs reasoning
about a loop's bounds against an *array's* full index range; this one only
needs "is this discrete range statically non-empty," with no array
reasoning at all. Left open rather than folded into `FP-008`, to keep that
fix scoped to the overload-resolution problem it was diagnosed from.

One of the 8 original findings was **not** a false positive:
`cubedos-lib-sorters.adb`'s `Pop_Heap` (`Result : out Element_Type`) has a
body that is literally `null;` — genuinely unimplemented stub code, not yet
written by the CubedOS authors. Correctly flagged.

Cumulative effect of the `FP-008` fix on the same CubedOS run:

| Check | Before | After |
| --- | --- | --- |
| Total violations | 41 | 37 |
| `Uninitialized_Output` | 8 | 4 (1 genuine stub, 3 open static-loop case) |

## Future corpora

AWS (Ada Web Server) remains a candidate, not yet run.
