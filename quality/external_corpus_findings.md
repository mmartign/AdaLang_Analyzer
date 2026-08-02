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

### Confirmed analyzer mistake (fixed): FP-010

One residual `Uninitialized_Output` finding after the `FP-007` fix:
`auditlog.adb`, `SetFileDetails`, writes its `LogFileEntries` array through
`for I in LogFileIndexT loop LogFileEntries (I) := NumberEntries; end loop;`
rather than by literal index or field name. `LogFileIndexT` is exactly the
index subtype `LogFileEntries` is declared over, so the loop necessarily
visits every index — this is precisely the "bare subtype mark" shape
`Adalang_Analyzer.SPARK_Readiness.Loop_Covers_Index_Range` recognizes (see
FP-010 in `quality/known_analysis_issues.tsv`). Verified with a fixture
reproducing the same subtype-iteration shape
(`uninitialized_output_array_loop_subtype_clean.adb`) rather than a fresh
live re-run of the Tokeneer checkout.

This fix was found while working a step further than originally planned:
special-casing statically bounded scalar loop writes (FP-009) turned out,
on closer inspection, to also silently accept a *partial*-range array loop
as fully initializing (e.g. `for I in 1 .. 2 loop Arr (I) := 0; end loop;`
on a 3-element array), because `Same_Parameter`'s coarse whole-object
treatment of `Arr (I) := ...` (from FP-007) cannot by itself distinguish
"wrote one element" from "wrote every element." Caught by testing that
exact partial-range shape before FP-009 shipped externally, not by an
external report. Closing it properly required doing the array-coverage
reasoning this section previously left open, rather than only narrowing
FP-009 back down — see FP-010's full description in
`quality/known_analysis_issues.tsv` for how the two recognized coverage
shapes (bare subtype mark, `Param'Range`) avoid needing any bound
arithmetic at all.

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
    array-fill pattern documented above (e.g. `block_streams.adb`'s `Read`,
    filling `Item` via `while Last < Item'Last loop Item (Last) := ...; end
    loop;`) — corroborating evidence that the limitation is real and
    recurring, not a Tokeneer-specific artifact, and that the `FP-004`–
    `FP-007` fixes did not need revisiting. Unlike Tokeneer's `SetFileDetails`
    (a `for` loop, now fixed by FP-010), this is a `while` loop bounded by a
    runtime comparison against `Item'Last`, not a `for` loop whose iteration
    domain is provably the whole index range by construction; FP-010
    deliberately only reasons about `for` loops, so this instance remains
    open.
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

### Confirmed analyzer mistake (fixed): FP-009

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

Every loop kind (`for`, `while`, plain `loop`) was deliberately treated as
"might not execute at all" by `Interpret_Initialization` — a reasonable
default for loops that can `exit` or whose range isn't statically known to
be non-empty. But `for I in 1 .. 3` has a *statically* non-empty range and
no `exit`/`return`/`raise`/`goto` before the write, so the write is in fact
unconditional. This is a narrower, more tractable relative of the
already-documented array-loop-coverage limitation (Tokeneer's
`SetFileDetails`, Simple Components' `Read`) — that one needs reasoning
about a loop's bounds against an *array's* full index range; this one only
needs "is this discrete range statically non-empty," with no array
reasoning at all.

Fixed by special-casing `Ada_For_Loop_Stmt` in
`Adalang_Analyzer.SPARK_Readiness.Interpret_Initialization`: when the
iteration range's bounds are statically known (via the existing
`Adalang_Analyzer.Flow_Eval.Choice_Interval`, reused as-is from the
proof-obligation/case-range checks) and non-empty, and the loop body
contains no `exit`/`return`/`raise`/`goto` anywhere (the new
`Contains_Loop_Escape`), the body's own computed `Init_Result` is trusted
instead of discarded, since nothing can leave the loop before finishing a
pass. `while`/plain loops, and any `for` loop that does contain an early
exit, remain conservatively unresolved — deliberately, to avoid trading
this false positive for a false negative on a genuinely conditional write
(e.g. `for I in 1 .. 3 loop if Stop then exit; end if; Value := I; end
loop;` must still be flagged, since the exit can be taken before `Value`
is ever written). Verified with two fixtures faithfully copying the real
type shapes and loop body — `uninitialized_output_static_loop_clean.adb`
(fails pre-fix, passes post-fix) and
`uninitialized_output_static_loop_early_exit.adb` (a sibling with an added
`exit`, confirmed to still fire both before and after the fix) — rather
than a fresh live re-run of the CubedOS checkout itself.

One of the 8 original findings was **not** a false positive:
`cubedos-lib-sorters.adb`'s `Pop_Heap` (`Result : out Element_Type`) has a
body that is literally `null;` — genuinely unimplemented stub code, not yet
written by the CubedOS authors. Correctly flagged.

Expected cumulative effect of the `FP-008` and `FP-009` fixes on the same
CubedOS run (extrapolated from the fixture reproductions above, not a fresh
live re-run of the checkout):

| Check | Before | After |
| --- | --- | --- |
| Total violations | 41 | 34 |
| `Uninitialized_Output` | 8 | 1 (genuine stub) |

## AWS (Ada Web Server, AdaCore/aws)

- **Source**: `AdaCore/aws` on GitHub. The full project (`aws.gpr`) is an
  aggregate requiring its own `make setup` (external variables like
  `TGT_DIR`, plus XMLAda/GNATcoll/OpenSSL availability), which this
  environment doesn't have configured. Rather than build that out, ran
  directly against source files with no `-P`, the same fallback used for
  Muen: `src/core`, `src/extended`, `src/http2` (273 `.ads`/`.adb` files;
  `templates_parser` is an unfetched git submodule and was skipped).
- **Method**: `adalang_analyzer --recommended` over all 273 files at once
  (passed via `xargs` from a file list, not as shell-expanded positional
  arguments — the file count is large enough that it's worth naming the
  invocation shape explicitly for reproducibility).
- **Baseline run**: 382 violations. Largest categories: `Wrong_Parameter_Mode`
  (126), `Uninitialized_Output` (112), `Uninitialized_Read` (39),
  `Dead_Store` (23), `Empty_Exception_Handler` (20).

### Confirmed analyzer mistake (fixed): FP-011

Sampling the `Uninitialized_Output` findings (spot-checked, not exhaustively
verified — same methodology as Simple Components), `aws-server-push.adb`
stood out: its `protected body Waiter_Information` writes each of its `Info`
procedure's four out parameters as `Info.Size := ...;`, `Info.Counter :=
...;`, etc. — using the enclosing procedure's own name (`Info`) to qualify
its own parameters. This is standard Ada (RM 8.3's general unit-name
qualification): `Waiter_Information` (the protected object) has same-named
private components (`Size`, `Counter`, ...), which would otherwise shadow
the parameters for simple-name visibility inside the body, so the codebase's
style consistently disambiguates by prefixing with the *enclosing
subprogram's own name*, not the protected object's. `Same_Parameter`'s
existing prefix-unwrap loop always inspected a `Dotted_Name`'s prefix
(`Info`) and discarded the suffix (`Size`), so it checked the wrong
identifier against the tracked parameter name and concluded it was never
written — even though this is a completely different shape from the
`Param.Field := ...` case `Same_Parameter` already handles (there, the
*prefix* is the tracked object and the *suffix* is one of its fields; here,
the *suffix* is the tracked object and the *prefix* is just a qualifier
naming the enclosing unit).

Fixed by adding a check, ahead of the existing unwrap loop, for exactly this
shape: the suffix matches the tracked parameter's name, and the prefix
resolves to the nearest enclosing `Subp_Body` or `Entry_Body` (the new
`Enclosing_Subprogram_Or_Entry`). This is narrow and additive — it requires
an exact correspondence between the prefix and the specific enclosing
construct, so a genuinely different, same-named entity (e.g. `R.Size :=
...;` where `R` is a different `in out` parameter of a record type with its
own `Size` field) is unaffected; verified with a guard fixture
(`uninitialized_output_own_name_qualifier_guard.adb`) alongside the clean
one. Confirmed against the real file by diffing `aws-server-push.adb`'s own
`Uninitialized_Output` output before and after the fix: exactly the 6
targeted findings (the `Info` procedure's 4 parameters, plus
`Shutdown_If_Empty`'s `Open` and `Get`'s `Queue`, both qualified the same
way elsewhere in the same file) disappeared, nothing new appeared. The
file's remaining 10 `Uninitialized_Output` findings are unrelated — at
least one looks like a distinct, unconfirmed gap (an out parameter forwarded
by name to a *protected object's* operation, e.g. `Waiter_Information.Info
(Size => Size, ...)`, rather than an ordinary subprogram) — not
investigated further this pass.
