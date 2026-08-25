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

### Scope observation, not a defect: `--verify` on real code

The original 2026-08-01 run classified 4687 bounded scalar obligations: 0
`Proved_Safe`, 0 `Definite_Error`, 4643 `Unproved`, 44 `Unsupported`. This
was the documented scope boundary made visible at scale, not a hidden bug:
98% of `range-check` obligations failed because the abstract domain is
non-relational (it tracks each variable's own interval independently and
cannot represent a relationship like `X <= Y`), and most
`initialization-check` obligations failed because Tokeneer is built almost
entirely from private-child packages and cross-procedure calls, so
initialization facts were conservatively discarded (`Flow_Havoc_All`) at
every call boundary the (then intraprocedural-only) analysis couldn't see
through.

Interprocedural effect summaries (shipped 2026-08-02) plus `FP-027`–`FP-030`
changed this substantially. A re-run against the same checkout (7938
obligations, more kinds now tracked) went from 0 to 1661 `Proved_Safe`
before `FP-031` was found and fixed (see below), settling at 1538
`Proved_Safe` afterward, 1 `Definite_Error`, 6034 `Unproved`, 365
`Unsupported`. `initialization-check` alone reached 1379 `Proved_Safe` /
3543 `Unproved` / 196 `Unsupported` out of 5118 — the interprocedural payoff
net of `FP-031`'s correction (below). `range-check` improved more modestly
(0 → 102 `Proved_Safe` out of 1738, after `FP-034`), since it depends on the
still-unaddressed non-relational-domain gap, not interprocedural scope;
"the current non-relational range domain is inconclusive" remains the
single largest imprecision reason across the whole run (1505 occurrences).
Closing that gap remains validated roadmap input (a relational abstract
domain), not a bug-fix-sized change.

### Confirmed analyzer mistake (fixed): FP-010

One residual `Uninitialized_Output` finding after the `FP-007` fix:
`auditlog.adb`'s `SetFileDetails` writes its `LogFileEntries` array via
`for I in LogFileIndexT loop LogFileEntries (I) := NumberEntries; end loop;`
— `LogFileIndexT` is exactly `LogFileEntries`'s own index subtype, so the
loop necessarily visits every index. `Same_Parameter`'s coarse whole-object
treatment of indexed writes (from `FP-007`) couldn't distinguish "wrote one
element" from "wrote every element"; fixed by adding
`Loop_Covers_Index_Range`, which recognizes exactly two provably-complete
iteration shapes (a bare subtype mark matching the array's index subtype,
or `Param'Range`) without needing bound arithmetic. Full detail in `FP-010`
in `quality/known_analysis_issues.tsv`. Verified with
`uninitialized_output_array_loop_subtype_clean.adb`.

### Confirmed analyzer mistakes (fixed): FP-031–FP-038 — CFG fixed-point staleness

The 2026-08-04 re-run above surfaced `Definite_Error` on two obligations in
a codebase AdaCore describes as fully verified — `enrolment.adb`'s `pragma
Loop_Invariant (CertNo >= 2);` and `msgproc.adb`'s read of `ValFin` after a
dynamically-bounded `for` loop. Neither was a real bug in Tokeneer: both
trace to the same mechanism in `Verify_Subprogram`'s CFG worklist fixed
point, which can visit a merge point once *before* a loop's back edge has
fed its contribution in, record an outcome from that intermediate,
not-yet-converged state, and never correct it — `Proof_Obligations.
Register_At`'s `Replaces` function treats `Definite_Error`/`Proved_Safe` as
terminal once recorded for a stable ID, which is sound across two
independent analyses but not across two visits of the same in-progress
fixed point. The same staleness mechanism turned out to affect every
proof-obligation kind, each fixed the same way — a `Final` parameter
threaded to the live recording call, and a `Finalize_*` helper in
`Finalize_Node` that replays the check against the fully-converged state
after the fixed point drains, superseding any premature live recording:

- **`FP-031`** (`initialization-check`, `msgproc.adb`): fixing this also
  corrected 123 *other* obligations elsewhere in the corpus that were stuck
  at a spurious `Proved_Safe` from the same mechanism (1661 → 1538
  `Proved_Safe`, all 123 moving to the honest `Unproved`) — confirming the
  bug ran in both directions, not just the alarming one. Regression:
  `tests/verification_loop_stale_initialization.adb`.
- **`FP-032`** (`assertion-check`, `enrolment.adb`'s `Loop_Invariant`): the
  real corpus case couldn't confirm the fix directly (no GNAT toolchain on
  PATH here means that file's semantic resolution already reports
  `Unproved` via a different method regardless — see `FP-029` in the
  Certyflie section below); confirmed instead with a synthetic fixture in
  `FP-034`'s shape.
- **`FP-033`** (`precondition-check`): one complication beyond the others —
  a single call with a `Pre` contract is live-recorded under *two* distinct
  stable IDs (once against the whole call, once against just the callee
  name), both independently stale, so the fix replays both. The real
  corpus has zero `precondition-check` obligations, so only the synthetic
  fixture confirms this one.
- **`FP-034`** (`range-check`): demonstrated the dangerous direction
  directly on real code — Tokeneer's `range-check` `Proved_Safe` count fell
  from 105 to 102 (all three moving to the honest `Unproved`) once fixed.
- **`FP-035`/`FP-036`/`FP-037`** (`index-check`, `division-by-zero-check`,
  `integer-overflow-check`): same mechanism, same fix shape. Tokeneer's
  `index-check` and `division-by-zero` counts were unchanged (no case in
  the corpus hit the staleness window); `integer-overflow`'s `Proved_Safe`
  fell from 13 to 6 — 3 to the honest `Unproved`, and 4 phantom obligations
  (created by the old, unguarded replay path for non-integer `Bin_Op`
  nodes) disappeared entirely.
- **`FP-038`** (separate bug, found while designing `FP-034`'s fix):
  `Report.Report_Violation_At`, the ordinary-findings counterpart to
  `Register_At`, had no deduplication at all, so a real violation could be
  reported once per CFG re-visit. Tokeneer's `--recommended --spark` count
  fell from 652 to 631 once fixed, all 21 in `Non_Short_Circuit_Condition`
  (`clock.adb`'s 10-term `and`-chained range guard, reported 9 times for
  the identical location — a second, unrelated root cause: every nested
  `Bin_Op` in a left-associative chain shares the same `Sloc_Range.Start`).

Full detail, mechanisms, and regression fixtures for all eight are in
`quality/known_analysis_issues.tsv`.

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
sharing the same parameter count/modes, differing only in `Value`'s type,
each forwarding its own `out` parameter purely positionally to another
overload of the same name. `Call.P_Call_Params` needs one fully precise
overload resolution for the whole call and returns nothing when that
fails, which happens here even via the usual imprecise fallback. Fixed by
adding a position-based fallback (`Callee_Formal_At_Position`) for purely
positional actuals: resolve just the callee name, then pair the Nth actual
to the Nth formal by literal position. Regression:
`uninitialized_output_overloaded_forward_clean.adb`.

### Confirmed analyzer mistake (fixed): FP-009

The remaining 3 `Uninitialized_Output` findings in `cubedos-lib-xdr.adb`
(after `FP-008`) write a scalar `out` parameter unconditionally inside a
`for I in 1 .. 3 loop`. Every loop kind was deliberately treated as "might
not execute at all," a reasonable default for loops that can `exit` or
whose range isn't statically known to be non-empty — but a `for` loop with
statically non-empty bounds and no early exit always executes at least
once. Fixed by special-casing `Ada_For_Loop_Stmt`: when the range is
statically non-empty and the body contains no `exit`/`return`/`raise`/
`goto`, the body's own computed initialization result is trusted instead
of discarded. `while`/plain loops, and any `for` loop with an early exit,
remain conservatively unresolved. Regressions:
`uninitialized_output_static_loop_clean.adb` and
`uninitialized_output_static_loop_early_exit.adb` (the early-exit sibling
still correctly flags). Full root-cause and fix detail for both FP-008 and
FP-009 is in `quality/known_analysis_issues.tsv`.

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

### `--verify` / GNATprove comparison and a fixed issue: FP-040

Extending the CubedOS investigation to `--verify`'s bounded scalar proof
obligations (full `src/cubedos.gpr`, 49 files) and comparing against
GNATprove `--mode=prove --level=4` (mirroring `benchmarks/sparknacl/`'s
methodology; detail in `benchmarks/cubedos/README.md` and
`benchmarks/cubedos/RESULTS_2026-08-25.md`) surfaced a real analyzer bug:
`Finalize_Node` called several Libadalang properties directly outside any
`begin`/`exception` block, so a `Property_Error` — `Call_Expr.P_Kind`
genuinely fails for a call whose callee is declared in a separate `with`'d
GNAT project, an upstream Libadalang resolution limit — escaped and
aborted the whole file instead of just that one obligation, on 21 of the
49 analyzed files. Fixed by wrapping each branch's property access in its
own `begin`/`exception` block so a failure now skips only that node's own
obligations. Effect on this run: whole-file aborts went from 21/49 to 0,
and reported proof obligations rose from 44 to 680 (`Proved_Safe` 2 to 16)
with no verdict changing for an obligation already reported — the fix only
affects whether an obligation gets registered at all. Full detail in
`FP-040` in `quality/known_analysis_issues.tsv`; regression:
`tests/verification_cross_project/`.

CubedOS is not a fully-proved corpus (unlike SPARKNaCl): GNATprove itself
reports real, unresolved findings on unmodified `cubedos.gpr` (tasking
data races, a missing `Global` aspect, uninitialized `out` parameters),
making it a weaker oracle than SPARKNaCl. Only 7 of 680 AdaLang obligations
had a matched GNATprove counterpart at this revision (all "both flag a
problem," zero unsoundness or false positives) — too small a sample to add
confidence beyond SPARKNaCl's own 886-pair result; this run's real
contribution was `FP-040` itself.

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

### Confirmed analyzer mistakes (fixed): FP-011, FP-012, FP-013

Three related `Uninitialized_Output` false positives in `aws-server-push.adb`,
all rooted in Ada write-shapes `Same_Parameter`/`Statement_Writes_Parameter`
did not recognize:

- **`FP-011`**: `protected body Waiter_Information` writes each of its `Info`
  procedure's four out parameters qualified by the enclosing subprogram's own
  name (`Info.Size := ...;`, per RM 8.3, needed because the protected object
  has same-named private components that would otherwise shadow the
  parameters). `Same_Parameter`'s prefix-unwrap loop checked the prefix
  (`Info`, the qualifier) against the tracked parameter instead of the suffix
  (`Size`, the actual parameter). Fixed by recognizing this shape explicitly:
  suffix matches the parameter, prefix resolves to the nearest enclosing
  subprogram/entry body. Regression: `uninitialized_output_own_name_qualifier_guard.adb`.
- **`FP-012`**: the outer wrapper `Info` forwards its four out parameters by
  *named* actual to the protected `Info`. A formal typed `Ada.Calendar.Time`
  on the call made Libadalang's per-actual resolution fail for every actual,
  not just that one — a Libadalang limitation. The existing FP-008
  position-based fallback only covered positional actuals; fixed by adding
  `Callee_Formal_By_Name`, the named-actual counterpart.
- **`FP-013`**: `Unregister_Clients`'s `Queue : out Tables.Map` is initialized
  by a parameterless prefixed call, `Queue.Clear;` — a bare `Dotted_Name`
  with no `Call_Expr` node, which `Statement_Writes_Parameter` didn't inspect
  at all (the same shape already handled for `Wrong_Parameter_Mode`/
  `Dead_Store` elsewhere, but not in this separate write-recognition path).
  Fixed by adding an `Ada_Dotted_Name` branch reusing `Same_Parameter`'s
  existing prefix-unwrap. Regression: `uninitialized_output_prefixed_clear_clean.adb`.

Together these three dropped `aws-server-push.adb`'s `Uninitialized_Output`
count from 16 to 3. The remaining 2 are genuine AWS bugs, not analyzer
mistakes — `Get_Data`'s `Data` is only written inside a `while` loop that can
see zero iterations, and `Send`'s `Queue` has an early `return;` bypassing
its later `Queue.Clear;` — both real paths to an uninitialized `out`
parameter on return, left open as out of this project's scope. Full
root-cause and fix detail for FP-011–FP-013 is in `quality/known_analysis_issues.tsv`.

### Confirmed analyzer mistake (fixed): FP-014

The corpus's largest remaining category, `Wrong_Parameter_Mode` (126
findings), was extremely concentrated: 70 of 126 were in `aws-config-set.adb`,
a package of single-field setters each writing exactly one element of an
`in out` parameter's array (`O.P (Key).Pos_Value := Value;`) while leaving
every other element untouched. The mode-change recommendation's write
detection unwrapped any depth of nested selector/index to credit the whole
object as written — correct for `Dead_Store`/`Uninitialized_Output`'s
coarser "touched at all" question, but wrong for recommending `out`: a
partial write inherently depends on the untouched parts already holding a
meaningful prior value. Fixed by adding `Parameter_Is_Wholly_Written`,
used only to gate the "use mode out" recommendation, requiring the write
target be the parameter itself with no nested selector/index; `Dead_Store`
and `Uninitialized_Output` are unaffected. `Wrong_Parameter_Mode` findings
dropped from 126 to 54. Regressions: `wrong_parameter_mode_partial_write_clean.adb`,
`wrong_parameter_mode_partial_write_guard.adb`.

### Confirmed analyzer mistake (fixed): FP-015

`Uninitialized_Read` flagged `Last := Fixed.Index (Data (First .. Data'Last), VDel);`
as reading `Last` before its own initializing assignment. The expression
contains `Data'Last`, an attribute designator that Libadalang parses as an
`Ada_Identifier` node syntactically but resolves to no declaration;
`Matches_Declaration` fell back to a plain spelling comparison on
resolution failure, and "Last" matched the unrelated local variable by
text alone. `First`/`Last` are two of the most common bounds-tracking
variable names — exactly the attributes they collide with — so this was a
broad class, not a one-off. Fixed by an early check in `Matches_Declaration`:
an identifier that is specifically the `F_Attribute` child of an
`Attribute_Ref` never matches any declaration (a genuine reference used as
an attribute *prefix*, e.g. `Last'Size`, is unaffected). `Uninitialized_Read`
findings dropped from 39 to 35; being shared infrastructure, the fix also
helps `Dead_Store` and other data-flow checks on future corpora.
Regressions: `uninitialized_read_attribute_designator_clean.adb`,
`uninitialized_read_attribute_designator_guard.adb`.

The other 5 `Uninitialized_Read` findings in the same file were a second,
distinct bug (closed later as `FP-017`, below): a nested function reading
locals that are initialized by a call textually *after* the nested
function's own declaration, but only ever actually invoked after that call
— `First_Access`'s plain pre-order AST walk had no notion of a nested
subprogram body being a declaration (elaborated, not executed, at its
textual position) rather than a statement.

### Confirmed analyzer mistake (fixed): FP-016

13 of `Dead_Store`'s 23 findings were in `aws-http2-stream.adb`, all on a
renaming: `Info : Error_Details renames Self.Error_Detail;`, where `Self`
is an `in out` parameter. A write to `Info` is really a write to
`Self.Error_Detail`, observable after return — never a locally dead
store. But `Info`'s declaration is textually nested inside the
subprogram, so `Is_Local_To_Subprogram` (a purely lexical-scope test)
considered it local regardless of what it renamed, and `Ultimate_Object`
(which already resolves simple renamings like `Y renames X;`) only
followed a renamed object that was itself a bare identifier, not one
reached through a selected component like `Self.Error_Detail`. Fixed by
adding `Renames_Nonlocal_Object`: walks the renamed object down through
any depth of selected/indexed component or dereference to its base
identifier, and disqualifies the declaration from `Dead_Store` whenever
that base isn't local to the enclosing subprogram. `Dead_Store` findings
dropped from 23 to 10. Regressions:
`dead_store_renaming_of_parameter_field_clean.adb`,
`dead_store_renaming_of_parameter_field_guard.adb`.

### Confirmed analyzer mistake (fixed): FP-017

Closed the nested-subprogram-ordering bug left open under `FP-015`:
`First_Access`'s pre-order AST walk had no notion of actual call order,
so a read inside a nested subprogram body declared earlier than a later
initializing statement was mistaken for happening before it, even though
the nested body is only ever invoked afterwards. Fixed by skipping
recursion into any `Ada_Subp_Body`/`Ada_Entry_Body` child during the walk
— a nested body is a declaration, elaborated but not executed at its own
textual position. This trades away detecting a genuine read through a
nested body invoked *before* initialization for not flagging the common,
correct case. `Uninitialized_Read` findings dropped from 35 to 29.
Regressions: `uninitialized_read_nested_subprogram_order_clean.adb`,
`uninitialized_read_nested_subprogram_order_guard.adb`.

Fixing this exposed a second, previously-masked finding at
`aws-net-acceptors.adb:274` (`Error` in `Acceptors.Get`, genuinely
initialized by a call through a nested generic instantiation that
`Call_Writes_Declaration` fails to resolve through) — a distinct root
cause in the same family as `FP-008`/`FP-012`, closed by `FP-019` below.

### Confirmed analyzer mistake (fixed): FP-018

`Uninitialized_Read`'s write-detection relied solely on Libadalang's
per-actual resolution, the same mechanism already proven (twice: `FP-008`,
`FP-012`) to fail on an otherwise-unambiguous call for a *different*
check's write detection, which already had a lenient callee-name fallback.
`Uninitialized_Read` never received the equivalent fallback. Fixed by
adding `Callee_Formal_At_Position`, `Callee_Formal_By_Name`, and
`Formal_Mode` to `Checks.Data_Flow` (duplicating, not sharing, the
equivalent `SPARK_Readiness` functions, per this project's convention for
narrow leaf-level helpers), used the same way `Statement_Writes_Parameter`
already does. One instance disappeared corpus-wide
(`aws-session.adb`'s `Get_Value`). The `aws-net-acceptors.adb` finding
that prompted this investigation needed a deeper fix; closed by `FP-019`.
Regressions: `uninitialized_read_positional_forward_clean.adb`,
`uninitialized_read_positional_forward_guard.adb`.

### Confirmed analyzer mistake (fixed): FP-019

Reducing the 273-file invocation to six real AWS files
(`aws-net-acceptors.adb`/`.ads`, `aws-net-generic_sets.adb`/`.ads`,
`aws-net.ads`, `aws.ads`) showed that explicitly supplying the root and
parent specs made *every* available formal-resolution path fail for the
nested generic calls involved (per-actual resolution, whole-callee
resolution, the called-subprogram spec, and the instantiated package
prefix) — no declaration-reconstruction fallback was possible, since the
semantic links themselves were unavailable. `First_Access` previously
returned `No_Access` for such an unresolved call and kept scanning,
reaching a later real read and wrongly declaring it "before every write."
Fixed by adding a terminal `Unknown_Access` result: an unresolved simple
actual stops the definite first-access search instead of being silently
skipped (resolved `in`/`out`/`in out` actuals are unaffected). On the
original 273-file invocation, all three `aws-net-acceptors.adb` false
positives disappeared and `Uninitialized_Read` findings fell from 28 to 4
(total findings 275 to 251). Full detail for FP-016–FP-019 is in
`quality/known_analysis_issues.tsv`.

## Ada Drivers Library (AdaCore/Ada_Drivers_Library)

- **Source**: `AdaCore/Ada_Drivers_Library` on GitHub, a large collection of
  embedded hardware drivers (sensors, displays, radios, storage) for STM32
  and other microcontrollers. Deliberately chosen to fill a gap the prior
  corpora didn't cover: hardware-register-facing, volatile/`Import`-overlay
  embedded code, distinct from Tokeneer's proof style, Simple Components'
  and AWS's general-purpose libraries, and CubedOS's small SPARK framework.
- **Method**: most `.gpr` files in this repository are board- or demo-
  specific and require a cross-compilation runtime (ZFP/SFP) this
  environment doesn't have configured, the same obstacle previously hit
  with Muen and AWS. `hal/src` (the target-independent hardware-abstraction
  interfaces) and `components/src` (portable sensor/display/radio drivers
  built only against those interfaces, no board-specific runtime) together
  form a self-contained, `-P`-less source set: `adalang_analyzer
  --recommended -v hal/src/*.ad? components/src/**/*.ad?` (133 files, via a
  file list, not shell-expanded positional arguments -- the same
  reproducibility note as AWS's invocation).
- **Baseline run**: 1322 violations. Largest categories: `Wrong_Parameter_Mode`
  (58), `Dead_Store` (56), `Uninitialized_Output` (131), `Unused_Parameter`
  (28), `Unused_Variable` (23), `Uninitialized_Read` (20).

### Confirmed analyzer mistakes (fixed): FP-021–FP-024

Four false positives, found and fixed in sequence as each unblocked the
next residual finding:

- **`FP-021`** (`Uninitialized_Output`, 111 of 131 findings, concentrated in
  `components/src/radio/hm11/hm11.adb`): a public procedure with two
  same-named overloads, the wider one (a `System.Address`-typed formal)
  forwarding an `out` parameter positionally to the narrower one.
  Libadalang's imprecise-fallback resolution resolved the call back to the
  *enclosing*, narrower overload itself rather than the callee actually
  invoked, so even the existing FP-008 position-based fallback ran out of
  formals before reaching the sought position. Fixed by adding
  `Callee_Candidate_By_Arity`: when the resolved callee's spec doesn't
  contain a formal at the sought position, search every same-named
  candidate visible at the call site for one whose total formal count
  matches the call's actual count. `Uninitialized_Output` fell from 131 to
  74 (the residual 74 are a different, genuine shape — a result only
  assigned inside a status-guarded branch). Regressions:
  `uninitialized_output_overload_arity_fallback_clean.adb`,
  `..._guard.adb`.
- **`FP-022`** (`Uninitialized_Read`, 12 of 20 findings): a local declared
  with the `Import` aspect as an overlay onto a buffer already populated
  externally (DMA, a prior driver call) needs no explicit initializer, but
  the `Uninitialized_Read` gate checked only for a default expression,
  renaming, and scalar-ness — unlike `Dead_Store`/`Overwritten_Assignment`,
  which already exempt `Volatile`/`Atomic`/`Address`-aspected declarations.
  Fixed by adding the same existing exemption to this gate.
  `Uninitialized_Read` fell from 20 to 8. Regressions:
  `uninitialized_read_import_overlay_clean.adb`, `..._guard.adb`.
- **`FP-023`** (`Uninitialized_Read`, 7 of the remaining 8): a function
  with an `out`-mode formal called for its return value inside a larger
  expression rather than as its own statement. `First_Access`'s
  assignment-statement case correctly excluded the out-actual from being
  read, but returned unconditionally without ever falling through to the
  generic child recursion that would recognize the nested call as a write,
  so the write was silently dropped and a later, unrelated mention was
  misreported as the first access. Fixed by recursing `First_Access` into
  the RHS whenever neither the read nor simple-write case matches.
  `Uninitialized_Read` fell from 8 to 1. Regressions:
  `uninitialized_read_function_out_actual_clean.adb`, `..._guard.adb`.
- **`FP-024`** (`Uninitialized_Read`, the last residual finding): a named
  actual's own designator (e.g. `LSB => Buffer (0)`) happened to share its
  spelling with an unrelated local variable `LSB`; the generic recursive
  walk over a `Param_Assoc` visited the designator alongside the actual
  expression, and `Matches_Declaration`'s spelling-based fallback (the
  same tradeoff as `FP-015`) matched it by text. Fixed by an early check
  in `Matches_Declaration`, mirroring `FP-015`'s attribute-designator one:
  an identifier that is the `F_Designator` child of a `Param_Assoc` never
  matches a declaration. `Uninitialized_Read` fell from 1 to 0.
  Regressions: `uninitialized_read_named_actual_designator_clean.adb`,
  `..._guard.adb`.

Full root-cause and fix detail for all four is in
`quality/known_analysis_issues.tsv`.

### Spot-checked, not fixed: `Wrong_Parameter_Mode` and `Dead_Store` (open)

With `Uninitialized_Output`/`Uninitialized_Read` false positives closed out,
the corpus's other two large categories were sampled rather than
exhaustively verified, per this project's usual methodology:

- `Wrong_Parameter_Mode` (58 findings, top file
  `components/src/motion/l3gd20/l3gd20.adb`, 29 findings, all "`This` is
  only read; use mode in"): `L3GD20`'s `This : in out Three_Axis_Gyroscope`
  convention is applied uniformly across the type's whole primitive set,
  but its private `Read`/`Write` helpers take `This` by mode `in`, so a
  method like `Sleep` that only calls `Read`/`Write` genuinely never
  mutates `This` -- a real, if minor, mode-tightening opportunity, not an
  analyzer mistake. Matches the true-positive `Wrong_Parameter_Mode`
  pattern already documented for Simple Components.
- `Dead_Store` (56 findings, top file
  `components/src/radio/nrf24l01p/nrf24l01p.adb`, 15 findings, all on a
  single multi-output `Get_Status (This, TX_Full, Max_TX, TX_Sent,
  RX_Resived, Pipe);` call): several callers only care about one or two of
  `Get_Status`'s five reported outputs and discard the rest into locals
  that are genuinely never read again in that subprogram -- exactly what
  `Dead_Store` is defined to find, not an analyzer mistake.

No action taken on either beyond this sampling; not filed as known issues,
since the analyzer's behavior here appears correct.

## Certyflie (AdaCore/Certyflie)

- **Source**: `AdaCore/Certyflie` on GitHub, the Ada/SPARK flight controller
  for the Crazyflie nano quadcopter. Deliberately chosen to fill a gap none
  of the prior corpora covered: real Ravenscar-style concurrency (`task`
  bodies, `protected` objects with entries and barriers) and generic
  package instantiation (`Pid`, instantiated once per control axis),
  distinct from every earlier corpus's mostly sequential control/data-flow
  shapes.
- **Method**: `cf_ada_spark.gpr` targets `arm-eabi` with a cross-compilation
  runtime this environment doesn't have configured, the same obstacle
  already hit with Muen/AWS/Ada_Drivers_Library. `src` (the flight-control
  logic: PID controller, stabilizer, commander, parameter/log subsystems,
  `tasks.ads`) and `crazyflie_support/src` (the self-contained CRTP/
  syslink/radio-link protocol layer, including all the tasking- and
  protected-object-bearing files) together are `-P`-less and mostly
  self-contained; `Ada_Drivers_Library` (a submodule, populated for this
  run) supplies `hal/src` and the two motion-sensor components
  (`mpu9250`, `ak8963`) actually `with`ed. The board-specific STM32 driver
  stack (`STM32.Board`, `STM32.GPIO`, ...) that `crazyflie_support` also
  `with`s was deliberately *not* pulled in, the same scoping choice already
  made for the Ada_Drivers_Library corpus itself: `adalang_analyzer
  --recommended -v` over 87 files, via a file list (not shell-expanded
  positional arguments, the same reproducibility note as AWS's and Ada_
  Drivers_Library's invocations).
- **Baseline run**: 74 violations. Largest categories: `Dead_Store` (33),
  `Uninitialized_Output` (5), `Uninitialized_Read` (7), `Wrong_Parameter_Mode`
  (7), `Infinite_Loop` (8).

### Confirmed analyzer mistake (fixed): FP-028

4 of the 7 `Uninitialized_Read` findings, in three files, shared one
shape: a local (e.g. `Has_Succeed : Boolean;`) immediately named in a
`pragma Unreferenced` (to suppress an unrelated "never read" warning,
since it's only ever written, never read, elsewhere in the body), then
assigned later. `Matches_Declaration` resolved the pragma argument
identifier back to the local's own declaration — correctly, since a
pragma argument really does denote the entity it names — with nothing to
distinguish "merely named by a compiler directive" from "read here."
Fixed by an early check in `Matches_Declaration`, gated on the enclosing
pragma's name: an identifier that is the argument of `pragma
Unreferenced`, `Unmodified`, or `Warnings` never matches a declaration (a
bare-identifier condition under an *executable* pragma like `Assert` is
unaffected). `Uninitialized_Read` fell from 7 to 3. Regressions:
`uninitialized_read_pragma_unreferenced_clean.adb`, `..._guard.adb`.

### Confirmed analyzer mistake (fixed): FP-030

The remaining 3 `Uninitialized_Read` findings, in
`Stabilizer_Alt_Hold_Update`, flagged variables that were each genuinely
written by a plain assignment earlier in the same branch — the write
should have ended `First_Access`'s search before it ever reached the
reported read. Root-caused with temporary instrumentation: essentially
every identifier in that subprogram triggered the same `FP-029`
`Property_Error` (below) inside `Referenced_Declaration`, silently
swallowed by a blanket `when others` handler. `First_Access`'s
write-detection relied solely on exact declaration identity with no
fallback, so once resolution failed for any name in the subprogram, every
later plain-identifier *write* went undetected — while its sibling
read-detection path already tolerated the same failure through a
spelling-based fallback, so reads kept firing while writes silently
stopped being recognized. Fixed by giving write-detection the same
spelling-based fallback read-detection already had.
`Uninitialized_Read` fell from 3 to 0. No fixture: this exact
write-then-read shape resisted several synthetic reproduction attempts,
the same difficulty documented for `FP-018`/`FP-019`. Full detail for
`FP-028`/`FP-030` is in `quality/known_analysis_issues.tsv`.

While attempting one of those reproductions (a generic package with
`Float`-ranged formal parameters used directly in a nested subtype
declaration), a separate, still-unconfirmed potential false positive
turned up and was not pursued further: `Uninitialized_Read` fired on a
generic's own formal parameters where they appear in a subtype range
inside the generic's visible part (e.g. `subtype T_Val is Float range
LOW_LIMIT .. HIGH_LIMIT;`) — a generic formal object is always given a
value by instantiation, never by a statement in the generic's own text,
so treating it as an uninitialized local looks like a defect. Not filed
as a known issue (no confirmed root cause); worth a dedicated look in a
future pass.

### Root-caused (not locally fixable): FP-029

Four `dereferencing a null access` skip messages, all inside
`crazyflie_support/src/types.ads`'s block of ordinary `subtype T_IntNN is
Interfaces.IntegerNN;` declarations. Reduced to a minimal single-file
case and traced (via temporary symbolic backtrace) to an upstream
Libadalang defect: resolving the privacy/"next part" of a plain subtype
of an externally `with`'d package's scalar type, inside the
`Subtype_Decl_P_Get_Type` → ... → `Base_Type_Decl_P_Next_Part` chain in
vendored `libadalang-implementation.adb`, reachable from two structurally
unrelated analyses (interprocedural summary registration and an
unrelated discriminant-access check) — confirming the gap is shared, not
specific to either check's own logic, and that there is no fix available
on this side of the Libadalang boundary. Both call sites already contain
it correctly (skip and log, keep going), but the net effect is a real
coverage gap: no interprocedural summary is registered, and the
discriminant check silently doesn't run, for any subprogram whose profile
mentions such a subtype. Filed as `FP-029` (open; false-negative-shaped,
no local fix possible) in `known_analysis_issues.tsv`. Covered by
`external_subtype_signature_match_robustness.adb` and a CLI-robustness
check in `run_cli_robustness.sh` confirming the run still completes
rather than aborting.

### Spot-checked, not fixed (open)

The remaining categories were sampled rather than exhaustively verified,
per this project's usual methodology, and appear to be genuine findings
rather than analyzer mistakes:

- `Infinite_Loop` (8 findings, e.g. `crazyflie_system.adb`'s `System_Loop`
  and `Last_Chance_Handler`): periodic Ravenscar task/handler bodies of the
  form `loop delay until Next_Period; ...; end loop;` with no exit --
  genuinely infinite by design, correctly identified as such.
- `Empty_Loop` (2 findings, both in `crazyflie_support/src/io.adb`):
  `while not STM32.USARTs.Rx_Ready (USART) loop null; end loop;`, a
  standard embedded busy-wait poll of a hardware-facing function with an
  empty body -- the loop body is, textually, exactly what the check is
  defined to find.
- `Wrong_Parameter_Mode` (7 findings, 4 in `free_fall.adb` alone, all "this
  parameter is only read; use mode in"): the same true-positive
  mode-tightening pattern already documented for Simple Components and
  Ada_Drivers_Library's `L3GD20`.
- `Function_Side_Effect` (3 findings, `crazyflie_support/src/imu.adb`):
  the same nested-callback-mutating-an-enclosing-local shape already
  documented as a legitimate true positive for Simple Components.

No action taken on any of these beyond this sampling; not filed as known
issues, since the analyzer's behavior here appears correct.

### GNATprove comparison: not usable as an oracle for this corpus

A direct GNATprove run on Certyflie was attempted, to compare against a
tool with real formal-verification meaning rather than only AdaLang's own
bounded `--verify` mode. It could not be completed: Certyflie and its
`Ada_Drivers_Library` submodule were written against a ~2018-2020 GNAT
toolchain, and the modern Alire-packaged toolchain hits a chain of
incompatibilities (renamed runtime profiles, a GPR-ordering restriction
current GPR2-based tooling rejects, and finally a genuine Ada legality
error in unrelated FAT-filesystem middleware that GNATprove's whole-project
model still has to elaborate even though this study only cares about the
flight-control logic). This is a real, still-relevant difference between
the two tools worth keeping in mind when reading this corpus's results:
AdaLang Analyzer's Libadalang foundation tolerates a deliberately scoped,
incomplete file set well enough to still produce useful findings;
GNATprove's whole-project, fully-elaborated model does not, and an
8-year-old embedded project needs real toolchain-currency work before
GNATprove can even start here — independent of anything about the SPARK
content of the flight-control code itself. No GNATprove oracle comparison
exists for this corpus as a result.

## Relational precision work for `--verify` (2026-08-11 – 2026-08-13)

The Tokeneer section above names "the current non-relational range domain
is inconclusive" as the largest imprecision reason in that corpus. This
section records a measurement-driven investigation into extending
`VC_Prover`'s existing dual-solver (CVC5/Z3) bridge to cover more of that
gap, rather than building speculatively: each step measured a hypothesis
against real corpora (mainly Tokeneer and a smaller, structurally different
corpus, `project_bias`) before committing to the next one. `Decide_Bounds`
and `Decide_Nonzero` (containment/excluded-point goals against the interval
domain's own `Abstract_Range`) were added to `VC_Prover` as reusable
building blocks; a throwaway shadow-instrumentation run showed a naive
"query the solver on every `Unproved` obligation" fallback would recover at
most ~7% of any one obligation kind, because 68-94% of such queries never
even reach the solver — `VC_Prover.Symbolic_State` has already discarded
the relevant term by the time the query is built. (Zero `VC_Refuted`
results occurred in that measurement, so the soundness half of the
question was clean; it was pure lost precision, not risk.)

Instrumented diagnostics (`Dump_Symbolic_Diagnostics`, kept in the tree,
`ADALANG_VERIFY_SYMBOLIC_DIAGNOSTICS`-gated) isolated *why* terms get
discarded: not `Join`'s own whole-state havoc or `Include_Root` poisoning
(both zero occurrences), but `Assign`/`Assume` failing to translate an
expression into an SMT term in the first place — the dominant untranslated
AST kinds on Tokeneer being `Ada_Dotted_Name` (record-component access,
39%), `Ada_Identifier` (26%), and `Ada_Attribute_Ref`; on `project_bias`,
`Ada_Membership_Expr` (`X in ...`, 50%). Each gap was then closed and
re-measured in turn:

- **`Ada_Membership_Expr` support** in `Boolean_Term` (range/value/`not in`
  membership tests): shipped, confirmed correct on a synthetic case, but
  zero corpus payoff — Tokeneer's dominant membership shape is a
  subtype-mark alternative and `project_bias`'s is attribute-bounded
  (`'First .. 'Last`), neither translatable yet, which motivated the next
  two items.
- **`Ada_Attribute_Ref` support** (`'First`/`'Last`/`'Length`) in
  `Integer_Term`, plus subtype-mark membership alternatives resolving
  through the existing `Type_Range`/`Array_Index_Range` helpers (promoted
  from `Flow_Interp` to the shared `Flow_Eval` layer): shipped, and this is
  the one step that moved a corpus for real — Tokeneer's `provedSafe` rose
  from 1623 to 1741 (+7.3% of the whole run). `project_bias` didn't move:
  its arrays carry a per-*object* constraint that `Array_Index_Range`
  (type-level resolution only) can't see, a pre-existing limitation shared
  with the already-shipped index-check machinery, not a regression.
- **Enum-sort support** (`Enum_Sort`, keyed on declaration-order position,
  equality/membership only): shipped, confirmed correct on synthetic cases,
  but zero net `provedSafe` movement on either corpus — investigation found
  `VC_Prover.Assign` was already silently mistyping enum-to-enum
  assignments as `Boolean_Sort` (a pre-existing, not newly introduced,
  guard weakness in `Boolean_Term`'s `Ada_Identifier` case), so the new
  `Enum_Sort` binding on a comparison's literal side collided with the
  variable's wrong sort and stayed `Unsupported` either way. Fixed properly
  as **declaration-resolved scalar sorts**: `VC_Prover` now resolves a
  scalar's sort from its actual Libadalang type declaration up front
  (`Bool`/`Int`/`Enum_Sort`) instead of guessing via `Boolean_Term`-first.
  Regression-covered; real-corpus re-measurement was left to the next step.
- **`Ada_Dotted_Name` (record-component) support** in `Integer_Term`:
  shipped, confirmed sound on five synthetic cases (including that two
  different objects' same-named field resolve to distinct symbols, and a
  truly uninitialized object's field correctly stays `Unproved`) and
  confirmed non-regressing against a fully-proved oracle (SPARKNaCl) in
  addition to the two tracked corpora — every `compare.awk` bucket
  byte-identical, zero unsoundness, zero false positives, on all three.
  Corpus payoff was real but tiny at the mechanism level (Tokeneer's
  `Ada_Dotted_Name` translation failures: 2295 → 2269) and zero at the
  `provedSafe` level, because the new case only resolves a plain-identifier
  prefix (not a nested `A.B.C` selector, common in Tokeneer's own
  package-qualified global state) and requires the prefix object to be
  locally `Flow_Initialization`-true (which a package-level global never
  is, since the interpreter's flow state is scoped to one subprogram).
- **`Inlined_Call_Term` object-identity substitution** (added by the
  repository owner, not this investigation): fixed a related gap where
  inlining an expression function with a record-typed formal (e.g.
  Tokeneer's own `IsPresent (TheAdmin : T) return Boolean is
  (TheAdmin.RolePresent in ...)`) manufactured a meaningless fresh symbol
  for the whole record instead of threading the caller's actual object
  identity through. Verified correct and sound (an adversarial
  write-then-assert case correctly stays `Unproved`; the three-corpus
  before/after comparison stayed byte-identical, zero unsoundness). Fixes
  the project's own named blocking example, but — like the step above —
  produced zero measured `provedSafe` movement on the tracked corpora;
  tracing exactly which obligations it should have unblocked was not
  completed in this pass.

**Net effect**: Tokeneer's `--verify` `provedSafe` moved from 1623 to 1741
(+7.3%) over the course of this work, essentially all of it from the
`Ada_Attribute_Ref` step; every other shipped improvement is real, tested,
and sound, but its payoff on the two/three corpora tracked here specifically
is nil for corpus-specific reasons disclosed above (enum-typed membership
without a resolvable comparison shape, nested selectors, non-local
`Flow_Initialization` scope, and an inlining case not yet traced to a
specific obligation). All of the above shipped to the codebase (not
reverted); the shadow-query scaffolding used for the very first measurement
was reverted, leaving only `Decide_Bounds`/`Decide_Nonzero` behind as
currently-unused `VC_Prover` entry points for future work in this
direction.
