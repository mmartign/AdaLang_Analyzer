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
way elsewhere in the same file) disappeared, nothing new appeared.

### Confirmed analyzer mistake (fixed): FP-012

Checking whether FP-011 had left a related gap open in the same file
surfaced a second, distinct false positive at the very next residual
finding: the *outer*, ordinary (non-protected) wrapper procedure `Info`
(distinct from the protected body's own `Info` above) forwards its four
out parameters by named actual to `Waiter_Information.Info (Size => Size,
Max_Size => Max_Size, Max_Size_DT => Max_Size_DT, Counter => Counter)` — an
otherwise perfectly ordinary out-actual-forwarding call, the kind this
analysis already recognizes elsewhere. Bisecting a synthetic reproduction
down from the real shape (two closer, hand-written syntheses that dropped
the `Ada.Calendar.Time`-typed `Max_Size_DT` formal both failed to reproduce
it) isolated the trigger precisely: a formal typed `Ada.Calendar.Time` on
an otherwise-unambiguous protected-operation call is, on its own, enough to
make Libadalang's own per-actual resolution (`Assoc.P_Get_Params`) fail to
classify *every* actual in the call, not just that one formal — a
Libadalang limitation, not investigated further here. The existing FP-008
fallback (`Callee_Formal_At_Position`, resolving just the callee name and
pairing by position when the precise resolution fails) only ever applied
to purely positional actuals; a *named* actual hitting this same
resolution gap had no fallback at all and was silently never recognized as
a write.

Fixed by adding `Callee_Formal_By_Name`, the named-actual counterpart to
`Callee_Formal_At_Position`: the same lenient callee-name-only resolution,
matching the actual's designator against a formal by name instead of by
position. A guard fixture confirms a named actual naming a genuinely `in`
formal on a callee hitting the same resolution gap isn't mistaken for
writing an unrelated `out` parameter that's never actually forwarded.

With both FP-011 and FP-012 fixed, `aws-server-push.adb`'s
`Uninitialized_Output` count drops from 16 to 6; the remaining findings
were not investigated further this pass.

### Confirmed analyzer mistake (fixed): FP-013

Re-cloning `AdaCore/aws` fresh and re-running the same `--recommended` scan
over `src/core`, `src/extended`, `src/http2` (still 273 files) to continue
where the previous pass left off found upstream had moved on in the
interim: only 3 of the 6 previously-residual `Uninitialized_Output`
findings in `aws-server-push.adb` still existed (`Get_Data`'s `Data`,
`Send`'s `Queue`, `Unregister_Clients`'s `Queue`); the other 3 were gone,
presumably resolved by unrelated upstream changes to the file rather than
anything on this project's side.

Investigating the 3 survivors: `Unregister_Clients`'s `Queue : out
Tables.Map` is initialized by a single unconditional `Queue.Clear;`
right at the top of the body — a parameterless prefixed procedure call
(`Object.Operation;`), which Libadalang represents as a bare `Dotted_Name`
with no `Call_Expr` node at all. `Adalang_Analyzer.SPARK_Readiness.
Statement_Writes_Parameter` (the write-recognition function behind
`Uninitialized_Output`) only ever inspected `Ada_Call_Expr` call
statements, so this call was invisible to it — the exact same shape
already fixed for `Wrong_Parameter_Mode` and `Dead_Store` in
`Adalang_Analyzer.Checks.Declarations.Parameter_Is_Written` (see
`quality/README.md`'s precision regression index), but left open in the
separate `SPARK_Readiness` write-recognition path `Uninitialized_Output`
actually uses.

Fixed by adding an `Ada_Dotted_Name` branch to `Statement_Writes_Parameter`
that reuses `Same_Parameter` directly on the call node: `Same_Parameter`'s
own prefix-unwrap loop (added for FP-011) already walks a `Dotted_Name`
down past its suffix to its prefix before comparing identifiers, which is
exactly what's needed here too, so no new unwrap logic was required. Like
every other call-based write this function already recognizes, the
callee's own body is not verified to actually initialize the parameter —
only that the parameter is the controlling actual of a mutator-shaped
call — consistent with how `Wrong_Parameter_Mode`/`Dead_Store` already
treat this shape. A guard fixture (a second, unrelated out parameter left
untouched by the same call) confirms the fix does not spill a write credit
onto the wrong parameter.

Confirmed against the real file by diffing `aws-server-push.adb`'s own
`Uninitialized_Output` output before and after the fix: exactly the
`Unregister_Clients` finding disappeared, nothing new appeared, and the
corpus-wide total dropped from 372 to 371.

The other 2 survivors were reviewed and are **not** analyzer mistakes:
`Get_Data`'s `Data : out Stream_Element_Array` is written only inside a
`while` loop over `Holder.Chunks`, so an empty chunk list reaches the
normal return with `Data` never assigned; `Send`'s `Queue : out Tables.Map`
has an early `return;` (unmatched `Group_Id`) that bypasses the later
`Queue.Clear;` entirely. Both are real paths to an uninitialized `out`
parameter on a normal return, not analyzer false positives, and are left
open (not filed as known issues, since the analyzer's behavior here is
correct — they would need upstream AWS review to resolve, which is out of
scope for this project).

Covered by `uninitialized_output_prefixed_clear_clean.adb` (clean) and
`uninitialized_output_prefixed_clear_guard.adb` (still flags the
unrelated-parameter case).

### Confirmed analyzer mistake (fixed): FP-014

With the `Uninitialized_Output` findings in `aws-server-push.adb`
resolved, the corpus's largest remaining category — `Wrong_Parameter_Mode`
at 126 findings — turned out to be extremely concentrated: 70 of the 126
were in a single file, `aws-config-set.adb`, all with the identical shape:

```ada
procedure Accept_Queue_Size (O : in out Object; Value : Positive) is
begin
   O.P (Accept_Queue_Size).Pos_Value := Value;
end Accept_Queue_Size;
```

`AWS.Config.Set` is a package of single-field setters, one per
configuration key, each writing exactly one element of `Object`'s
many-element parameter array (`O.P`) while leaving every other
configuration value untouched. `Wrong_Parameter_Mode`'s write-detection
(`Adalang_Analyzer.Checks.Declarations.Parameter_Is_Written`) delegates
its `Assign_Stmt` case to `Write_Target_Contains_Parameter`, which
deliberately unwraps any depth of nested selector/index to credit the
base object as written — correct for `Dead_Store` and `Uninitialized_
Output`'s coarser "was this touched at all" questions, but wrong for a
mode-change recommendation: Ada's `out` mode formally disclaims any need
for the parameter's incoming value, while a write to only part of it
(`O.P (Accept_Queue_Size).Pos_Value`, one of dozens of independent
elements) inherently depends on every untouched part already holding a
meaningful prior value — precisely why these procedures are declared
`in out`, not `out`, in the first place.

Fixed by adding `Parameter_Is_Wholly_Written`: identical to `Parameter_
Is_Written` (same call-forwarding and parameterless-prefixed-mutator
cases, unchanged, from the `FP-013`-adjacent fix already in that
function) except its `Assign_Stmt` case requires the destination to be
the parameter itself (`Parameter_Name_Matches`, no unwrap) rather than
any nested selector/index reaching down into it. Used only to gate the
"is only written; use mode out" recommendation in `Analyze_Subprogram`;
the "is only read; use mode in" recommendation, `Dead_Store`, and
`Uninitialized_Output` all keep using the original, unchanged `Parameter_
Is_Written`/`Write_Target_Contains_Parameter`, so their behavior is
unaffected.

Confirmed against the real corpus: `Wrong_Parameter_Mode` findings dropped
from 126 to 54 — all 70 in `aws-config-set.adb`, plus 2 more of the
identical shape found elsewhere in the same corpus
(`AWS.Net.Generic_Sets.Set_Data`'s `Set.Set (Index).Data := Data;`,
`AWS.Client.HTTP_Utils.Decrement_Authentication_Attempt`'s `Counter
(Level) := @ - 1;`, both single-element writes into a larger array
parameter) — with no new findings appearing anywhere in the corpus.

Covered by `wrong_parameter_mode_partial_write_clean.adb` (clean) and
`wrong_parameter_mode_partial_write_guard.adb` (a direct, whole-object
assignment must still be flagged).

### Confirmed analyzer mistake (fixed): FP-015

Moving on to `Uninitialized_Read` (39 findings, no single file
concentrated like the previous two categories): the top file,
`aws-headers-values.adb` (6 findings), included one that stood out —
flagged at the variable's own initializing assignment:

```ada
Last  : Natural;
begin
   Last := Fixed.Index (Data (First .. Data'Last), VDel);
```

`Last := Fixed.Index (...)` is `Last`'s first and only prior mention —
its own initializing write — yet the analyzer reported it as a *read*.
The expression also contains `Data'Last`, an **attribute designator**:
syntactically an identifier (Libadalang parses the "Last" naming the
attribute as an `Ada_Identifier` node), but never a reference to any
declaration. `Adalang_Analyzer.Checks.Data_Flow.Matches_Declaration` —
shared read/write-detection infrastructure used by `Uninitialized_Read`,
`Dead_Store`, and other data-flow checks — first attempts semantic
resolution, then falls back to a plain spelling comparison whenever that
fails. Libadalang's resolution correctly returns null for the attribute
designator, which fed straight into that fallback: its spelling ("Last")
matched the unrelated local variable `Last` by pure text, misclassifying
the whole statement as a read of it before that same statement's write
was even considered. `First` and `Last` are two of the most common
variable names for tracking string/array bounds — exactly the standard
attributes they collide with — so this was a broad, easy-to-hit class,
not a one-off.

Reproduced in isolation before changing anything:

```ada
procedure Repro_Last (Data : String) is
   Last : Natural;
begin
   Last := Ada.Strings.Fixed.Index (Data (Data'First .. Data'Last), "x");
end Repro_Last;
```

flagged `Uninitialized_Read` on `Last`; renaming the variable to
`Position` (same shape, no colliding attribute) produced no finding,
confirming the collision was the cause.

Fixed by adding an early check in `Matches_Declaration`: an identifier
that is specifically the `F_Attribute` child of its parent `Attribute_
Ref` (not merely appearing somewhere inside one, so a genuine reference
used as an attribute *prefix* — e.g. `Last'Size` where `Last` really is
the tracked variable — is unaffected) never matches any declaration,
returning `False` before the spelling fallback ever runs.

Confirmed against the real corpus: `Uninitialized_Read` findings dropped
from 39 to 35 — `aws-headers-values.adb`, `aws-log.adb`,
`aws-config-ini.adb`, `aws-config-utils.adb`, one each — with no new
findings appearing anywhere and no change to any other check's totals in
this corpus (though the fix, being in shared infrastructure, should also
help `Dead_Store` and the other checks that call `Matches_Declaration` on
future corpora).

The other 5 `Uninitialized_Read` findings in `aws-headers-values.adb`
turned out to be a second, distinct bug, not yet fixed: `Split`'s nested
function `To_Set` declares locals (`Name_First`, `Name_Last`, `Value_
First`, `Value_Last`) that are fully initialized by a call to `Next_Value`
(all four are its `out`-mode formals) before `To_Set`'s own nested
function `Element` — which reads them as up-level references — is ever
invoked; `Element`'s body, however, is textually declared *before* that
`Next_Value` call, and `Data_Flow.First_Access`'s plain pre-order AST walk
has no special case for a nested subprogram body being a declaration
(elaborated, not executed, at its textual position) rather than a
statement, so it finds the read inside `Element`'s body before it reaches
the initializing call. The same shape affects `Split` itself over `First`
(read inside `To_Set`, which textually precedes `Split`'s own initializing
assignment to `First`). Left open for a future pass — the fix requires
`First_Access` to distinguish a nested subprogram's declaration position
from its actual call sites, a materially different traversal than the
attribute-designator fix above.

Covered by `uninitialized_read_attribute_designator_clean.adb` (clean)
and `uninitialized_read_attribute_designator_guard.adb` (a genuine
attribute-prefix reference to the tracked variable must still be
flagged).

### Confirmed analyzer mistake (fixed): FP-016

Checking `Dead_Store` (23 findings) next found the same kind of
concentration as `Wrong_Parameter_Mode` earlier: 13 of the 23 were in a
single file, `aws-http2-stream.adb`, all reported on assignments
immediately followed by `return;` inside a large `case` statement:

```ada
   Info : Error_Details renames Self.Error_Detail;
   --  ...
begin
   Error := C_No_Error;
   Info  := Error_No_Details;
   --  ...
   if Self.Id /= 0 and then Self.Id mod 2 = 0 then
      Error := C_Protocol_Error;
      Info  := Error_Stream_Id_Even;
      return;
```

`Received_Frame`'s `Error` parameter is genuinely `out` mode, so its
final writes before `return` were never a problem — `Dead_Store` only
ever considers `Ada_Object_Decl`s, and `Error`'s declaration is a
`Param_Spec`, which the check already excludes correctly. `Info`,
though, is a **renaming**: `Info : Error_Details renames Self.
Error_Detail;`, where `Self` is an `in out` parameter. A write to `Info`
is really a write to `Self.Error_Detail`, observable by the caller after
return (and by other code that reads `Self.Error_Detail` directly
elsewhere) — never a locally dead store. But `Info`'s own declaration
*is* textually nested inside `Received_Frame`, so `Adalang_Analyzer.
Checks.Control_Flow.Is_Local_To_Subprogram` — a purely lexical-scope test
— considered it local regardless of what it renamed. Compounding this,
`Data_Flow.Ultimate_Object` (the existing mechanism that already resolves
simple renamings like `Y renames X;` back to `X`'s own declaration, used
via `Assigned_Declaration` to figure out what a bare `Info := ...;`
statement actually writes) only ever followed a renamed object that was
itself a bare identifier — never one reached through a selected
component like `Self.Error_Detail`. So `Info := ...;` resolved to
`Info`'s own renaming declaration rather than to `Self`, and the write
looked, from `Dead_Store`'s point of view, exactly like a write to an
ordinary, purely local variable named `Info` that just happened to never
be read again by that name.

Fixed by adding `Renames_Nonlocal_Object` in `Checks.Control_Flow`: walks
the renamed object down through any depth of selected/indexed component
or dereference — the same coarse, "whichever depth of nesting, only the
base object matters" treatment already used elsewhere in this project
(e.g. `Same_Parameter`) — to its base identifier, and disqualifies a
declaration from `Dead_Store` whenever that base is not itself local to
the enclosing subprogram. A renaming of a genuinely local object's field
(`Y : F renames Local_Var.Field;`) is unaffected, since its base *is*
local.

Confirmed against the real corpus: `Dead_Store` findings dropped from 23
to 10 — all 13 in `aws-http2-stream.adb`, exactly the ones on `Info :=
...;` assignments — with no new findings appearing anywhere.

Covered by `dead_store_renaming_of_parameter_field_clean.adb` (clean) and
`dead_store_renaming_of_parameter_field_guard.adb` (a renaming of a
genuinely local object's field must still be flagged).

### Confirmed analyzer mistake (fixed): FP-017

Returning to the nested-subprogram-ordering bug diagnosed but left open
under FP-015 — `Data_Flow.First_Access`'s plain pre-order AST walk has no
notion of actual call order, so a read inside a nested subprogram body
declared earlier than a later initializing statement of the enclosing
subprogram was mistaken for happening before it, even though the nested
body is only ever actually invoked afterwards:

```ada
function To_Set return Set is
   Name_First  : Positive;
   Name_Last   : Natural;
   Value_First : Positive;
   Value_Last  : Natural;

   function Element return Data is    --  declared here, reads the four
   begin                              --  locals as up-level references
      ...
   end Element;

begin
   ...
   Next_Value                         --  initializes all four via its
     (Header_Value, First,            --  own out-mode formals -- but
      Name_First, Name_Last,          --  only runs *after* Element's
      Value_First, Value_Last);       --  declaration, textually
   return Element & To_Set;           --  Element is only ever *called*
end To_Set;                           --  here, after Next_Value
```

Fixed by skipping recursion into any child node of kind `Ada_Subp_Body` or
`Ada_Entry_Body` during `First_Access`'s walk: a nested subprogram or
entry body is a declaration, elaborated but not executed at its own
textual position, so a read or write inside it does not happen "here" the
way a statement does. This trades away detecting a genuine read through a
nested body invoked *before* the tracked variable's initialization
(unrecognized here, not soundly ruled out) for not flagging the common,
correct case — the same bias toward fewer false positives already
established throughout this project.

(While implementing this, an early version called `.Kind` on a loop
child before checking whether `Node.Child (I)` was null — Libadalang can
return a null node for a sparse list slot — which raised inside
`First_Access` and surfaced as a generic "skipping checks: null node
argument" message instead of a finding. Caught by the guard fixture below
before it was committed; fixed by checking `Is_Null` first.)

Confirmed against the real corpus: `Uninitialized_Read` findings dropped
from 35 (the count after FP-015/FP-016) to 29 — the 5 `aws-headers-
values.adb` findings left open under FP-015 are gone (`To_Set`'s four
locals plus `Split`'s own `First`), plus 2 more of the identical shape in
other files (`aws-net-acceptors.adb`, `aws-url-set.adb`).

One previously-hidden, unrelated finding was exposed in the process, at
`aws-net-acceptors.adb:274` (`Error` in `Acceptors.Get`) — **not** fixed
in this pass, left open: `Ready, Error : Boolean;` are genuinely
initialized by `Sets.Is_Read_Ready (Acceptor.Set, Acceptor.Index, Ready,
Error);`, a positional call to a procedure instantiated from a *nested*
generic (`package Sets is new Generic_Sets (Socket_Data_Type);` inside
the generic package `AWS.Net.Acceptors`, `Socket_Data_Type` itself the
outer generic's own formal type). Before this fix, the scan never reached
this call at all — it stopped earlier, at the very read this fix
resolves, inside the nested function `Accept_Listening`. With that
resolved, the scan now reaches the real initializing call, but
`Data_Flow.Call_Writes_Declaration` (and `Call_Reads_Simple_Actual`)
apparently fail to resolve the formal mode through this generic-of-a-
generic instantiation (both silently return `False` via their own
`exception when others` handlers, with no diagnostic — confirmed no `-v`
skip message is emitted for this file), so the call registers as neither
a read nor a write and the scan continues to the next real access, a
genuine read a few lines later, misreporting *that* as the first one.
This is not a regression from this fix — `Error` was already misreported
before it, just at a different, also-wrong location (masked by the
now-fixed ordering bug) — but is a distinct root cause (a Libadalang
resolution-fragility case in the same family as `FP-008`/`FP-012`, for a
different check's write-detection path that lacks their lenient,
callee-name-only fallback) and needs its own investigation, left for a
future pass.

Covered by `uninitialized_read_nested_subprogram_order_clean.adb` (clean)
and `uninitialized_read_nested_subprogram_order_guard.adb` (a genuine,
direct read in the enclosing subprogram's own statements, near an
unrelated nested subprogram, must still be flagged).

### Confirmed analyzer mistake (fixed): FP-018

Following up on the `aws-net-acceptors.adb:274` finding FP-017 exposed
(`Error` misreported as read-before-assignment, even though `Sets.
Is_Read_Ready (Acceptor.Set, Acceptor.Index, Ready, Error);` genuinely
initializes it): building a minimal, isolated reproduction of *that exact
file* proved surprisingly resistant — several attempts at recreating its
nested-generic-instantiation shape (`package Sets is new Generic_Sets
(Socket_Data_Type);` inside the generic package `AWS.Net.Acceptors`)
stayed clean. Running the real file standalone (outside the 273-file
batch) was clean too, confirming the batch context itself matters to
Libadalang's resolution behavior here — a materially harder thing to
isolate than any earlier finding this pass.

Rather than keep guessing at the trigger, the question was reframed:
`Uninitialized_Read`'s write-detection (`Call_Writes_Declaration`,
`Call_Reads_Simple_Actual` in `Checks.Data_Flow`) relies solely on
Libadalang's `Assoc.P_Get_Params (Imprecise_Fallback => True)` — the
*exact* per-actual resolution mechanism already proven, twice, to fail on
an otherwise-unambiguous call (`FP-008`: heavy overload; `FP-012`: a
formal typed `Ada.Calendar.Time`) for a *different* check's write
detection (`SPARK_Readiness.Statement_Writes_Parameter`, behind
`Uninitialized_Output`), which already has a lenient fallback for exactly
this. `Uninitialized_Read`'s own detection never received the same
fallback. Reusing the already-confirmed `FP-012` trigger directly against
`Uninitialized_Read` (not `aws-net-acceptors.adb` at all) reproduced a
clean, reliable, in-isolation failure:

```ada
Waiter_Information.Info (S, M, D, C);   --  D : Ada.Calendar.Time
if C = 0 then                           --  falsely "read before assigned"
```

confirming the same resolution gap independently affects this check too,
without needing to pin down `aws-net-acceptors.adb`'s own specific
trigger.

Fixed by adding `Callee_Formal_At_Position`, `Callee_Formal_By_Name`, and
`Formal_Mode` to `Checks.Data_Flow` — duplicating, not sharing, the
equivalent functions already in `SPARK_Readiness` (this project's
established style for this kind of narrow, leaf-level helper) — and using
them in `Call_Writes_Declaration`/`Call_Reads_Simple_Actual` exactly as
`Statement_Writes_Parameter` already does: whenever `P_Get_Params`
resolves no formal at all for a given actual, fall back to resolving just
the callee name and pairing by position or designator.

Confirmed against the real corpus: one instance disappeared —
`aws-session.adb`'s `Get_Value`, where `Found` is genuinely initialized by
`Get_Node (Sessions, SID, Node, Found);` — with no new findings appearing
anywhere.

The `aws-net-acceptors.adb` finding that prompted this investigation remained
open after `FP-018`: it only reproduced in the full 273-file batch
context, and even `Callee_Formal_At_Position`'s own callee-name
resolution (`Call.F_Name.P_Referenced_Decl`) apparently still fails
there — a different, deeper layer of the same general problem. It is closed
by `FP-019` below.

Covered by `uninitialized_read_positional_forward_clean.adb` (clean) and
`uninitialized_read_positional_forward_guard.adb` (a variable never
forwarded at all, at the same resolution-fragile callee shape, must still
be flagged).

### Confirmed analyzer mistake (fixed): FP-019

The original 273-file invocation was reproduced and reduced to six real AWS
files: `aws-net-acceptors.adb`/`.ads`, `aws-net-generic_sets.adb`/`.ads`,
`aws-net.ads`, and `aws.ads`. The acceptor body is clean alone; explicitly
supplying the root and parent specs changes Libadalang's provider state and
makes every available formal-resolution path fail for the nested generic
calls. This includes per-actual `P_Get_Params`, whole-callee resolution, the
called-subprogram specification, and the instantiated package prefix, so
another declaration-reconstruction fallback would depend on semantic links
that are themselves unavailable.

`First_Access` previously returned `No_Access` for that unresolved call and
continued scanning. It then reached `Error`, `Count`, or `Success` later and
claimed the read definitely happened before every write, even though each
object had already been passed to a call that may write it. The correction
adds a terminal `Unknown_Access` result: an unresolved simple actual stops the
definite first-access search. Resolved `in` actuals still return
`Read_Access`; resolved `out` actuals return `Write_Access`; and resolved
`in out` actuals retain their read-before-write behavior.

The minimized AWS trigger is clean after the fix. On the exact original
273-file invocation, all three `aws-net-acceptors.adb` false positives
disappeared and `Uninitialized_Read` findings fell from 28 to 4 (total
findings from 275 to 251). The local clean/guard pair reproduces the semantic
boundary without depending on AWS: an unresolved call followed by a read is
clean, while passing the same uninitialized shape to a resolved `in` formal
is still flagged.
