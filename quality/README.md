# Quality evidence

This directory keeps the small, reviewable evidence used by the routine
quality gate.

`recommended.baseline` contains the 147 findings accepted after reviewing
the analyzer's own sources with `--recommended`. Duplicate fingerprints are
intentional: the baseline records occurrences, not only unique shapes. The
gate fails when a new non-baselined finding appears; removing an old finding
does not fail the gate.

`Use_After_Free`, `Unclosed_File_Handle`, and `Unused_With_Clause` joined
`--recommended` on 2026-08-24: three new checks in the flow-sensitive
defect/hygiene family this project's `GNATCHECK_RULE_COMPARISON.md`
identifies as its actual differentiator (GNATcheck's own unmatched
catalog is mostly deliberate-scope style/naming/OOP-metric rules, not
gaps to close). `Use_After_Free` reuses `Data_Flow.First_Access`
(the same primitive behind `Uninitialized_Read`) anchored on a call to
the procedure an `Ada.Unchecked_Deallocation` instantiation introduces,
rather than a declaration. `Unclosed_File_Handle` is a new structural
interpreter over `Ada.Text_IO`/`Ada.Streams.Stream_IO` `Open`/`Create`/
`Close` calls, modeled directly on `Uninitialized_Output`'s
all-paths-including-exception-handlers `Interpret_Initialization`
pattern (`Spark_Readiness`/`Subprogram_Summaries`). `Unused_With_Clause`
reuses `Duplicate_With_Clause`'s context-clause walk together with a new
semantic "was anything from unit U referenced" primitive
(`Declarations.Any_Reference_To_Unit`), deliberately resolving each name
rather than matching spelling, so a reference reached only through a
`use` clause still counts.

Running the new checks against this project's own self-analysis gate
(`tests/run_recommended_gate.sh`) before release, per this project's
established practice, found and fixed two real false positives in
`Unclosed_File_Handle`, both in the idiomatic "close a file that might
already be closed" pattern -- logged as `FP-060` in
`known_analysis_issues.tsv`: (1) `if Ada.Text_IO.Is_Open (File) then
Ada.Text_IO.Close (File); end if;` (seen in this project's own
`Report.Load_Baseline`), where the interpreter's missing-`else` merge
pessimistically assumed the untaken branch left the file open; and (2)
the more general "opened and closed behind the identical boolean guard"
idiom (seen in `Report.Write_Compliance_Report`'s `if To_File then ...
end if;` pairs), the same defect for a plain condition instead of an
`Is_Open` call. Both are now recognized: the first via a dedicated
`Guards_Is_Open` predicate, the second via a threaded `Open_Guard`
condition-text comparison, so a Close reachable only through the same
textual guard that gated the Open is credited as safe on both branches.
Self-analysis is otherwise clean for all three checks; the two `Merge`/
helper-function `Swappable_Parameters` findings the new code itself
triggers are baselined, consistent with the identical `Merge (Left,
Right : ...)` shape already accepted elsewhere in this codebase (e.g.
`Spark_Readiness`'s own `Init_Result` merge).

`Unclosed_File_Handle`'s v1 scope was deliberately narrow, matching this
project's habit of shipping a check narrow and widening it later
(`Address_Clause`'s `FP-054`/`FP-055` history is the precedent): only
`Ada.Text_IO`/`Ada.Streams.Stream_IO`; an `Open`/`Create` call lexically
inside a loop was skipped entirely (mirroring `Dead_Store`'s own loop
bailout); and a loop appearing *after* the open credited a `Close`
found anywhere in its body without proving the loop executes -- a
false-negative-biased simplification rather than `Uninitialized_
Output`'s heavier array-coverage loop proofs. Both loop gaps were
closed on 2026-08-28: `Interpret_Closure`'s loop case now runs the body
through the same interpreter as a normal statement list, using the
result of one application as the entry state for a second to find a
genuine two-state fixed point (sound here because nothing besides the
single "currently open" flag threads between statements, and `Open_At`
-- the only thing that can force it back to unsafe -- is reached the
same way regardless of the incoming flag), then merges that
"one-or-more-iterations" outcome with the unchanged "zero-iterations"
outcome for `while`/`for` loops (a bare, unconditional `loop` has no
such outcome to merge, since without an internal `exit` its own body
completing normally only repeats it forever). An `exit` statement
anywhere in the body (`Contains_Exit_Statement`) still falls back to
the older, purely textual heuristic rather than reasoning about where
control actually goes. Closing the loop-scoped-open bailout let a
`Direct_IO`/`Sequential_IO` follow-up mentioned in an earlier revision
of this section land too (`Ada.Text_IO`/`Ada.Streams.Stream_IO`'s
generic, per-element-type siblings, resolved the same way
`Ada.Unchecked_Deallocation` is), tracked as closed by
`quality/known_analysis_issues.tsv`'s `FP-062` note on the one
generic-instantiation shape (a bare name reached only through a `use`
clause on the generic itself) that remains an upstream Libadalang
resolution gap rather than a gap in this check. The fixed-point
analysis is deliberately conservative in one further respect, tracked
as the still-open `FP-063`: a `while`/`for` loop is always assumed able
to run zero iterations, with no attempt to prove a range or condition
non-empty, so an open closed unconditionally on every iteration of a
loop that in fact always runs still fires.

Adding `Empty_Then_Body`/`Empty_Else_Body` on 2026-08-24 (see below) required
regenerating `recommended.baseline` even though neither new check produced an
unsuppressed self-analysis finding: `Duplicate_Subprogram`'s own message text
embeds the sibling occurrence's file:line (e.g. "...identical to
'Handles_Others's at src/adalang_analyzer-checks-control_flow.adb:1235"), and
`Stable_Fingerprint` hashes the message verbatim, so inserting the ~19 new
lines above that pair's earlier occurrence in `control_flow.adb` shifted the
referenced line number and therefore the fingerprint -- one baseline entry
changed, none added or removed (confirmed: `--write-baseline` before and
after this change produce baselines of the same length, differing in exactly
one hash). This narrowly contradicted this project's own documented guarantee
(README.md: "Fingerprints exclude line and column numbers, so inserting
unrelated lines does not turn an existing finding into a new one") for the
one check whose message text itself contained a location string. Fixed the
same day in `Adalang_Analyzer.Clone_Detection.Analyze`: the earlier
occurrence's file:line moved out of `Message` (hashed by
`Stable_Fingerprint`) and into `Report_Rule_Violation`'s `Evidence`
parameter (displayed identically, in its own "evidence:" line, but
deliberately excluded from the fingerprint -- the same mechanism every
other check's supplementary detail already uses). Verified directly, not
just by inspection: inserting three unrelated comment lines directly above
the `Handles_Others` pair's earlier occurrence in `control_flow.adb` (so its
reported line moved from 1235 to 1238) reproduced the original bug before
the fix (one baseline mismatch, `Violations : 1`) and produced zero
mismatches after it (`Violations : 0`, `Baseline matches: 138`), toggled
both ways on the same input. `run_clone_detection.sh` now asserts the
location lives in the evidence line, not the message, so this cannot
regress silently again. `recommended.baseline` needed a second regeneration
for this fix itself (same-day, same file-count-unchanged shape as above):
the message wording change ("identical to 'Y's at ..." to "identical to
'Y' ...", with the location now separate) altered the fingerprint of all
17 `Duplicate_Subprogram` self-findings at once, not just the one that
motivated the fix. Logged as `FP-058` in `quality/known_analysis_issues.tsv`
despite not being a check-correctness issue in that file's usual sense (the
underlying finding was always correct) -- a baseline fingerprint-stability
bug that makes an unchanged finding present as if it were new is
functionally a false "new finding" the same way an unbaselined regression
would look, so it is tracked there rather than left undocumented.

`Duplicate_Subprogram` joined `--recommended` on 2026-08-17, growing the
baseline from 121 to 138. External-corpus validation first (all ten
benchmark corpora in `benchmarks/`, ~950 files, run in isolation via
`-checks="-*,Duplicate_Subprogram"`): 394 findings across nine of the ten
corpora, no false-positive class found on inspection anywhere
(cross-platform duplicate implementations, generated protocol code, and a
real "same statement shape, differing only in an uncompared local
declaration" pattern, all genuine). That run also found
and fixed `FP-052`, a message-clarity bug the check's very first external
corpus (AdaCore/Ada_Drivers_Library's per-chip-family driver layout)
happened to trigger. The 17 findings on this project's own source --
unchanged from the count already reviewed and confirmed genuine when the
check was first added (`Effective_SPARK_Enabled`, `Contract_Expression`,
`Formal_Mode`, `Formal_At`, `Is_Parameter_Key`, and others independently
reimplemented, identically, across `SPARK_Readiness`,
`SPARK_Dependency_Analysis`, `Flow_Interp`, and `Checks.Data_Flow`) -- are
baselined rather than extracted, the same call the project made when the
check was first self-analyzed.

`Swappable_Parameters` joined `--recommended` on 2026-08-15, growing the
baseline from 22 to 121 in one jump: 107 of the addition is that one check.
External-corpus validation first (benchmarks against gnatcoll-core and AWS,
~1,700 files combined) showed the check's parameter-name pairs are not
dominated by the trivially-safe `Left`/`Right` idiom this project's own
smaller, keyword-argument-heavy source had suggested -- real risky pairs
turned up (`User`/`Pwd`, `Stdin`/`Stdout`/`Stderr`, `Src`/`Dst`). Reviewing
this project's own 107 before baselining them found one category worth
naming specifically: `Adalang_Analyzer.Control_Flow_Graph`'s `Build_List`/
`Build_Handled`/`Build_Else_Chain` family takes 2-3 same-typed, same-mode
`Continuation`/`Exception_Target`/`Return_Target`/`Outer_Exception`
parameters and is called positionally throughout -- exactly the shape the
check exists to catch, in the CFG builder the bounded verifier depends on.
No misordering was found there on review, so it's baselined rather than
reordered, but it is the strongest real-world confirmation yet that the
check earns its place in `--recommended` rather than just adding volume.
The rest of the 107 fall into two lower-risk, still-legitimate categories:
conventional commutative/comparison-idiom pairs (`Left`/`Right`, `X`/`Y`)
and long keyword-style helper signatures (`Explanation`, `Evidence`,
`Abstract_State`, ...) that are, in this codebase, always called with named
association already, confirmed by spot-checking call sites rather than
assumed.

`known_analysis_issues.tsv` is the registry of confirmed analyzer mistakes.
An open false-positive or false-negative entry contributes to the release
metrics. A zero count means that no confirmed case is currently open; it is
not a claim that the analyzer has zero unknown mistakes.

`release_metrics.csv` records, per release:

- Open confirmed false positives.
- Open confirmed false negatives.
- Supported verification-construct families. This is currently the number of
  explicit `Obligation_Kind` families, each of which can still be classified
  as `Unproved` or `Unsupported`; it is not a whole-program proof claim.
- Reviewed findings in the recommended self-analysis baseline.
- Cases in the precision corpus (see "Precision corpus" below).

Run the evidence checks with:

```sh
sh tests/run_recommended_gate.sh
sh tests/run_quality_metrics.sh
sh tests/run_automotive_evidence.sh
sh tests/run_do178c_evidence.sh
sh tests/run_precision_corpus.sh
sh tests/run_verification_mutations.sh
sh tests/run_proof_path_evidence.sh
```

`automotive_rule_evidence.tsv` maps every check enabled by `--automotive` to a
positive and clean invocation. `run_automotive_evidence.sh` fails if the
implemented preset, the Automotive Ada Compliance Matrix, and this manifest
do not contain the same rule set, or if any mapped fixture stops producing
the expected result.

`do178c_rule_evidence.tsv` is the same pattern for `--do178c`: every check
enabled under any of its four levels maps to a positive and clean invocation.
`run_do178c_evidence.sh` fails under the same conditions as the automotive
gate (preset, `DO178C_COMPLIANCE_MATRIX.md`, and this manifest must agree on
the rule set, and every mapped fixture must still produce the expected
result), plus one DO-178C-specific check the automotive gate has no
equivalent for: `Enable_DO_178C_Preset` enables three tiers (a Core tier at
every level, a Level C tier, and a Level A/B tier), so the gate also confirms
the matrix's per-row "DO-178C level(s)" column agrees with which tier each
rule actually comes from in `src/adalang_analyzer-rules.ads`, not just that
every rule name appears somewhere in the table.

## Verification mutation campaign

`verification_mutations.tsv` records deliberately unsafe proof obligations
and their expected conservative outcomes. `run_verification_mutations.sh`
requires every named obligation to exist, rejects any `Proved_Safe` result,
and also checks the expected `Definite_Error` or `Unproved` classification.
This is a focused false-safe regression gate, complementary to the clean and
broken GNATprove differential corpora.

`proof_path_evidence.tsv` maps every source-tagged `Record_Proved_Safe`
producer to one or more method-specific evidence routes. Its gate checks a
positive proof and an adversarial non-proof for every route. Routes that need
the external solver portfolio must additionally retain `Unproved` outcomes
for both unsupported scalar translation and unavailable solvers. The source
and manifest producer sets must match exactly.

## Precision corpus

`precision_corpus.tsv` is a growing, machine-checked corpus of boundary and
negative cases: fixtures constructed to sit exactly at a check's decision
boundary, with the expected outcome (`clean` or `finding`) recorded
alongside. `run_precision_corpus.sh` runs every row in isolation
(`-checks="-*,<rule>"`) and fails the gate if any fixture's actual outcome
disagrees with the recorded expectation — the corpus size itself is tracked
as `precision_corpus_cases` in `release_metrics.csv`, the same way the other
evidence categories in this directory are tracked, so it can only grow, never
silently shrink, across releases.

Current coverage (302 cases; the tally below itemizes the threshold and
no-threshold boundary/negative campaigns explicitly, and folds in only the
first 9 of the many regression-negative/positive rows added alongside
individual false-positive fixes since — the rest of those rows are cataloged
against their own fix in the "Precision regression index" table below
instead of being re-itemized here):

- 12 threshold boundary cases: the six checks with a configurable numeric
  threshold — `Cyclomatic_Complexity`, `Deep_Nesting`, `Too_Many_Parameters`,
  `Long_Line`, `Generic_Instantiation_Limit`, `Dependency_Limit` — each with
  an "exactly at the default threshold" fixture that must stay clean and a
  "threshold plus one" fixture that must fire. Every boundary value in the
  corpus was confirmed against the built analyzer's own diagnostic message
  (e.g. "cyclomatic complexity 11 exceeds threshold 10"), not derived from
  reading the check's source and assuming it is correct.
- 9 regression-negative cases, folded in from the "Precision regression
  index" below: `Library_Level_Initialization`, `No_Compiler_Extensions`,
  `Uninitialized_Read`, `Wrong_Parameter_Mode`, `Dead_Store` (twice, on two
  distinct fixtures), `Redundant_Boolean_Comparison`, `Repeated_Statement`,
  and `Overwritten_Assignment`, each on the existing fixture the index
  already pointed at. Only rows that map cleanly to one rule and one
  checked-in fixture were folded in this way; the remaining index rows
  reference the analyzer's own source or a bounded `--verify`
  proof-obligation outcome rather than a `Rule_Kind` finding on a
  `tests/*.adb` fixture, and stay prose-only rather than force an uncertain
  mapping into a gate (see the index below for which).
- 16 boundary/negative cases for checks with no numeric threshold, targeting
  constructs the check's own implementation already special-cases:
  `Missing_Overriding_Indicator` on a same-named primitive with a different
  profile (an overload, not an override, so it needs no keyword — expected
  `clean`); `Uninitialized_Read` on a record variable read before its first
  assignment (only scalar declarations are checked — expected `clean`);
  `Wrong_Parameter_Mode` on a parameter used only as an array index inside a
  write destination (writing `Values (Idx)` writes `Values`, not `Idx`, so
  `Idx` is read-only and must still be flagged — expected `finding`);
  `Same_Operand` on `X + X` and `X * X` (excluded as routine, intentional
  identities — expected `clean`) paired with `X - X` at the same
  repeated-operand shape (still flagged, since `-` stays on the
  interesting-operator list — expected `finding`);
  `Inefficient_String_Concatenation` on an `Unbounded_String` accumulator
  rebuilt with `&` inside a loop (deliberately excluded, since the fix is
  "call `Append`", not "switch to `Unbounded_String`" — expected `clean`)
  paired with the same shape on a fixed-bounds `String` target, which has no
  cheaper `&` alternative and must still be flagged (expected `finding`);
  `Shadowed_Declaration` on two sibling `declare`-blocks that each declare
  their own `X` (`Shadows_Enclosing_Declaration` only walks outer scopes, so
  siblings never shadow each other — expected `clean`) paired with a nested
  block's `X` genuinely hiding an enclosing subprogram's own `X` at the same
  declare-block shape (expected `finding`); and `Ineffective_Operation`
  versus `Constant_Result_Operation` at the same literal-operand shape but
  opposite operators and operands — `X + 0` is Ineffective_Operation's
  identity case and not Constant_Result_Operation's (which has no `Plus`
  case at all), while `X * 0` is Constant_Result_Operation's absorbing case
  and not Ineffective_Operation's (whose `Mult` case only fires on a
  literal-one operand), each confirmed clean on the other rule and a finding
  on its own; `Missing_Overriding_Indicator`'s previously-untested positive
  side, a tagged-type primitive that genuinely overrides an inherited
  operation of the same profile without the `overriding` keyword (expected
  `finding`, at the same same-named-primitive shape the existing
  negative-overload case already covers); and `Function_Side_Effect` on a
  function assigning to its own local variable (excluded by
  `Is_Local_To_Subprogram` — expected `clean`) paired with the same
  in-function-body assignment shape targeting a variable declared in the
  enclosing subprogram instead, which is not local to the function and must
  still be flagged (expected `finding`). Each outcome was confirmed against
  the built analyzer, not assumed from reading the check's source.
- 28 further boundary/negative cases across 14 more no-threshold checks,
  each a clean/finding pair confirmed against the built analyzer, targeting
  a specific exclusion in the check's own logic: `Duplicate_Boolean_Operand`
  (a redundant paren still unwraps to detect `not (not X)`, vs. a single
  `not X`); `Self_Assignment` (a rename resolves to the same object as its
  renamed name, e.g. `A_Alias := A;`, vs. two genuinely distinct
  declarations); `Handler_Order` (a `when others` before a specific handler
  makes it unreachable, vs. the ordinary specific-then-others order);
  `Empty_Exception_Handler` vs. `Exception_Swallowed` (the former fires on
  any empty handler, the latter only on an empty `when others`, cross-tested
  on both an empty specific handler and an empty `when others`);
  `Unnecessary_Else_After_Return` (an else is redundant only when the
  then-branch's last statement actually terminates, vs. one that falls
  through to a plain assignment); `Empty_If_Body` (an empty then-body is
  only a no-op when there is no else, since an else makes the statement
  meaningful); `Identical_Branches` (adjacent-only: a then/else pair with
  identical text separated by a distinct elsif is not flagged, vs. two truly
  adjacent identical branches); `Duplicate_Condition` (compares every
  earlier condition in the chain, not just the adjacent one, unlike
  `Identical_Branches`); `Constant_Condition` (a statically-true comparison
  like `5 > 3` vs. one depending on an unconstrained parameter);
  `Overlapping_Case_Ranges` vs. `Unreachable_Case_Alternative` (a partially
  overlapping case range trips the former but not the latter, since it
  remains partly reachable; a fully contained range trips both, cross-tested
  on the same two fixtures); `Magic_Number` (a literal that is itself a
  named constant's own initializer vs. the identical literal initializing an
  ordinary variable); and `No_Multiple_Return` (an outer subprogram's own
  return count excludes a nested subprogram's returns, vs. an outer
  subprogram genuinely returning twice itself).
- 24 further boundary/negative cases across 12 more no-threshold checks,
  each a clean/finding pair confirmed against the built analyzer:
  `Contradictory_Condition` (a redundant paren still unwraps to detect
  `Done and not (Done)`, vs. two distinct operands); `Reversed_Range` (a
  strictly-decreasing static range like `5 .. 1`, vs. equal bounds like
  `5 .. 5`, which is a single-element range, not reversed);
  `Floating_Equality` (a direct `=` on `Float` operands, vs. `Integer`
  operands); `Redundant_Type_Conversion` (converting a value to its own
  exact type, vs. converting to a different subtype of the same base type,
  e.g. `Integer` to `Positive`, which resolves to a different declaration
  despite compatible representation); `Unreachable_Code` (an ordinary
  statement right after a `return`, vs. a label at that position, which is a
  possible entry point and makes everything after it reachable again);
  `Identical_Case_Alternative` (adjacent-only, mirroring
  `Identical_Branches`: two adjacent alternatives with identical bodies, vs.
  a non-adjacent repeat separated by a distinct alternative);
  `Unused_Parameter` (a parameter never referenced, vs. one referenced only
  inside a nested subprogram's own body, an up-level reference that still
  counts as used); `Missing_Global_Contract` and `Missing_Depends_Contract`
  (both only fire when the subprogram actually has something to declare — a
  real global access, or a real output — not merely for lacking the
  contract); `Volatile_Atomic_Consistency` (`Volatile` paired with `Atomic`
  on the same aspect list, vs. `Volatile` alone); `Suppression_Without_
  Rationale` (an `adalang-analyzer: ignore` comment with `rationale:` on the
  same line, vs. without it); and `Aliasing_Between_Parameters` (passing the
  same object to two `in` formals in one call, vs. the same shape with one
  formal `in out`, since the rule only fires when at least one aliased side
  is written).
- 2 cases for `Non_Short_Circuit_Condition`, added alongside its FP-041 fix
  (see `quality/known_analysis_issues.tsv`): a bitwise `and`/`or` on a
  modular type must no longer be told to use `and then`/`or else`, which RM
  4.5.7 restricts to Boolean operands (`clean`), paired with the existing
  chained-Boolean-operand regression fixture confirming genuine Boolean
  operands are still flagged (`finding`).
- 32 further cases across 16 more no-threshold checks that previously had no
  dedicated fixture at all, each confirmed against the built analyzer:
  `Naming_Convention` (a one-character for-loop index or enumeration literal
  is excluded by name, vs. an ordinary one-character object declaration);
  `Address_Clause` vs. `Representation_Clause_Policy` (an attribute-definition
  clause naming `Address` specifically trips the former, but any
  attribute-definition or record-representation clause -- e.g. `for
  Byte'Size use 8;` -- trips the latter, cross-tested on the same fixture,
  plus a clean case with no representation clause at all);
  `No_Unchecked_Conversion` vs. `No_Unchecked_Deallocation` (instantiating
  one of `Ada.Unchecked_Conversion`/`Ada.Unchecked_Deallocation` must not be
  misreported as the other); `No_Controlled_Type` (a type deriving from
  `Ada.Finalization.Controlled`, vs. an ordinary tagged type that does not);
  `Complete_Initialization` (an object declaration with no explicit
  initializer, vs. one with one); `Unused_Variable` (a local never
  referenced anywhere, vs. one referenced only inside a nested subprogram's
  own body, the same up-level-reference shape already covered for
  `Unused_Parameter`); `Missing_Loop_Variant` (a loop with a `Loop_Invariant`
  pragma but no `Loop_Variant` pragma, vs. one with both); `Infinite_Loop`
  (`while True loop` with no exit/return/raise/goto in its body, vs. a
  while-condition that depends on a parameter and so is not statically
  decidable as always-true, regardless of whether the loop can actually
  terminate at runtime); `Empty_Loop` (a loop body containing only a null
  statement, vs. one with a real assignment); `Exception_Propagation` (a call
  to a subprogram that unconditionally raises with no enclosing handler, vs.
  the same call wrapped in its own `exception when ... =>` handler);
  `No_Recursion` (a subprogram calling itself directly, vs. mutual recursion
  through a second subprogram -- `Is_Direct_Recursive_Call` only compares a
  call's target against its own immediately enclosing subprogram, so neither
  side of an A-calls-B-calls-A cycle is a direct self-call); `SPARK_Mode`
  (`pragma SPARK_Mode (Off);`, vs. `(On)`); and `Missing_Requirement_Trace`
  vs. `Malformed_Requirement_Trace` (no `do-178c: req` comment at all trips
  only the former; a `do-178c: req` comment with no identifier after it
  trips both, cross-tested on the same fixture; a comment with a real
  identifier trips neither).
- 46 further cases across the 23 remaining no-threshold checks that
  previously had no dedicated fixture at all (the "mostly simple
  presence-only prohibitions" the note below used to point at), each
  confirmed against the built analyzer: `No_Goto` vs. `No_Label` (a `goto
  Label;` statement is an `Ada_Goto_Stmt`, and its `<<Label>>` target is a
  separate `Ada_Label` node; a named loop's `Outer :`/`exit Outer` is
  neither, cross-tested on the same two fixtures); `No_Abort`, `No_Raise`,
  `No_Exit`, and `No_Requeue` (each real statement kind, vs. an ordinary
  call to a procedure merely *named* `Abort_Operation`/`Raise_Alert`/
  `Exit_Now`/`Requeue_Handler`); `Null_Statement` (a `null;` statement is an
  `Ada_Null_Stmt`, vs. `procedure No_Op is null;`, an `Ada_Null_Subp_Decl`
  declaration that is elaborated, not executed); `No_Access_To_Subp_Def` vs.
  `Restricted_Access_Type` (`access procedure(...)` is an
  `Ada_Access_To_Subp_Def`; `access Integer` is an `Ada_Type_Access_Def`;
  cross-tested on the same two fixtures so each rule's clean case is the
  other's finding); `No_Dynamic_Allocation` (`new Integer'(...)`, vs. a call
  to a function merely named `New_Value`); `No_Explicit_Dereference` (`P.all
  := ...` is an `Ada_Explicit_Deref`, vs. `P.Value := ...`, which reaches the
  same component through prefixed-notation implicit dereference with no
  `.all` token); `No_Classwide_Type` (`Root'Class`, vs. `Root'Size` at the
  same `Attribute_Ref` shape); `No_Tasking` vs. `No_Rendezvous` (a task
  type's entry declaration and its `accept` statement, vs. a protected
  type's ordinary procedure at the same declare-an-operation-in-a-
  concurrent-type shape); `No_Select` vs. `No_Asynchronous_Transfer` (both
  fire on a `select ... then abort ...` statement, but only an ordinary
  `select accept ...; or delay ...;` timed entry call trips `No_Select` and
  not `No_Asynchronous_Transfer`, since it has no `Ada_Then_Abort_Part`,
  cross-tested on the same two fixtures); `Potentially_Blocking_Operation`
  (a `delay` inside a protected operation body, vs. the same statement
  inside an ordinary procedure, since `Check_Potentially_Blocking` only
  scans bodies where `Is_Protected_Operation_Body` is true);
  `No_Dispatching_Call` (calling an overridden primitive through a
  `Root'Class` view, vs. through a specifically-typed object, at the same
  tagged-hierarchy shape); `Division_By_Zero` (`Y / 0`, a statically zero
  divisor, vs. `Y / 1`); `Unreachable_Branch` (`if False then`, vs. a
  condition depending on a parameter); `No_Runtime_Check_Suppression`
  (`pragma Suppress (All_Checks);`, vs. `pragma Check_Policy (Assertion,
  On);`, whose policy argument is `On` rather than `Off`/`Ignore`);
  `No_Pragma` (any pragma, vs. a file with none at all); and
  `Trailing_Whitespace` (a line ending in spaces, vs. a genuinely empty
  line, which the `Line'Length > 0` guard excludes even though both look
  blank).

- 3 cases for `Integer_Division_Before_Multiplication`, added alongside the
  new check: an unparenthesized `A / B * C` on `Integer` operands
  (`finding`), paired with two confirmed-clean exemptions — `(Addr /
  Alignment) * Alignment`, Ada's idiomatic round-down-to-a-multiple pattern
  (the multiplier matches the division's own divisor, so the check exempts
  it as intentional rather than a precision-loss mistake), and the
  identical `A / B * C` shape on `Float` operands, which does not truncate
  the same way and so must not fire.

- 10 cases for four new checks added together: `No_Unchecked_Access` (an
  `'Unchecked_Access` attribute reference, vs. an ordinary `'Access` at the
  same shape); `Duplicate_With_Clause` (a with clause naming a unit already
  with'd earlier in the same context clause, vs. two with clauses naming
  distinct units); `Excessive_Shift_Amount` (`Shift_Left` on an
  `Interfaces.Unsigned_8` value with a static amount of 8, not less than
  the type's 8-bit width, vs. an amount of 7, paired with a third case
  confirming a locally declared function merely *named* `Shift_Left`,
  unrelated to `Interfaces`, is not misidentified regardless of its
  argument); and `Reraise_Discards_Occurrence` (a handler's last statement
  re-raising the single exception it caught by name, vs. a bare `raise;`
  at the same shape, paired with a third case confirming raising a
  *different* exception than the one caught does not fire).

- 12 cases for five more new checks added together: `Duplicate_Exception_Choice`
  (a handler's own choice list naming the same exception twice, "when E1 |
  E1 =>", vs. two distinct exceptions); `Succ_Pred_Boundary_Overflow`
  (`T'Succ (T'Last)` and `T'Pred (T'First)`, both of which always raise
  `Constraint_Error`, vs. an ordinary `T'Succ` applied to an ordinary
  literal rather than the type's own `'Last`); `Redundant_If_Boolean_Return`
  (an if statement returning `True` on the then branch and `False` on the
  else branch, vs. both branches returning the identical literal, and vs.
  both branches returning an integer literal instead of a boolean one);
  `Redundant_Final_Return` (a bare `return;` as a procedure body's own
  last statement, vs. a `return;` inside an if branch, not the body's own
  last statement); and `Entry_Barrier_Side_Effect` (a protected entry
  barrier calling a function with an `in out` parameter, vs. a barrier
  that is a plain boolean component with no call at all).

- 4 cases for `Known_Enum_Val_Failure`, added alongside the new check:
  `Color'Val (5)` on a 3-literal enumeration, whose valid positions are
  `0 .. 2`, must fire (`finding`); `Color'Val (2)`, the last valid
  position, must not fire (boundary-clean); a `'Val` argument that is not
  statically known (a subprogram parameter) must not fire, since the
  check never assumes a value it cannot prove; and `Character'Val (300)`
  must not fire even though 300 is genuinely outside `Character`'s
  `0 .. 255` range — Libadalang synthesizes `Standard.Character`'s (and
  `Wide_Character`'s and `Wide_Wide_Character`'s) literal list as a
  placeholder rather than one node per position, so this check excludes
  those three predefined types entirely rather than risk a false positive
  on every ordinary use of them.

- 6 cases for `Known_Value_Conversion_Failure`, added alongside the new
  check: `Integer'Value ("N/A")` must fire, since `N`, `/`, and the space
  can never appear in a valid Ada numeric literal regardless of the
  target type's range (`finding`); `Integer'Value ("123")` must not fire
  (clean, well-formed); `Color'Value ("Reed")` on a 3-literal enumeration
  must fire, a typo of `"Red"` that names no literal of the type
  (`finding`); `Color'Value ("green")` must not fire, since enumeration
  literal matching is case-insensitive (clean); a `'Value` argument that
  is not a static string literal (a subprogram parameter) must not fire,
  the same "never assume what cannot be proved" discipline as
  `Known_Enum_Val_Failure`; and `Character'Value (...)` must not fire for
  the same `Standard.Character`-modeling reason `Known_Enum_Val_Failure`
  excludes it. The integer-side check deliberately only flags a string
  containing a character that can never appear in any Ada numeral (e.g.
  a stray letter outside `a`-`f`, punctuation, or an embedded space) —
  it does not attempt a full literal-grammar or range check, so a
  malformed-but-superficially-plausible string (say, unbalanced `#`
  delimiters) can still slip through uncaught; that's an accepted
  false-negative gap, not a false-positive risk.

- 3 cases for `Known_Negative_Shift_Amount_Failure`, added alongside the
  new check: `Shift_Left` on an `Interfaces.Unsigned_8` value with a
  static amount of `-1` must fire, since every `Interfaces` shift/rotate
  function's `Amount` parameter is subtype `Natural` (`finding`);
  `Shift_Left` with a static amount of `0` must not fire (clean); and a
  shift amount that is not statically known (a subprogram parameter)
  must not fire. Confirmed by direct compilation (not just documentation)
  that GNAT accepts `Shift_Left (X, -1)` with only a warning, not a
  compile error — it's a genuine runtime `Constraint_Error`, the same
  category as `Division_By_Zero`. This check cannot reuse
  `Excessive_Shift_Amount`'s callee-resolution path: a negative actual
  disqualifies every `Shift_Left` overload from Libadalang's own
  candidate filtering (unlike an in-range-but-too-large amount, which
  still resolves fine), leaving `P_Referenced_Decl` null — confirmed by
  a debug trace showing the qualified-name lookup never runs for the
  negative case. Detected instead from the first actual's own resolved
  type (independent of the call's own resolution) plus a syntactic name
  match on the callee.

- 4 cases for `Known_Negative_Exponent_Failure`, added alongside the new
  check: `2 ** (-1)` on an `Integer` base must fire, since Ada's
  predefined `**` for an integer base takes an exponent of subtype
  `Natural` (`finding`); `2 ** 3` must not fire (clean); `2.0 ** (-1)` on
  a `Float` base must not fire, since a negative exponent is a legal
  reciprocal power for floating-point and fixed-point bases (clean); and
  an exponent that is not statically known (a subprogram parameter) must
  not fire. Also confirmed by direct compilation that GNAT accepts this
  with only a warning. Unlike the shift-amount check, this one reuses the
  exponent's already-computed `Right_Int` value directly (no separate
  evaluation needed) since `Analyze_Binary_Expression` computes it for
  every binary operator up front.

- 4 cases for `Redundant_Abs` and `Redundant_Unary_Minus`, added together
  alongside these two new checks: `abs (abs (X))` must fire (`finding`);
  a single `abs (X)` must not fire (clean); `-(-X)` must fire (`finding`);
  and a single `-X` must not fire (clean).

- 3 cases for `Contradictory_Range_Condition`, added alongside the new
  check: `X > 10 and then X < 5` must fire, since no integer value is
  both greater than 10 and less than 5 (`finding`); `X > 10 and then
  X < 20` must not fire, since the two ranges overlap (clean); and `X >
  10 and then Y < 5` must not fire, since the two comparisons are on
  different expressions and their bounds don't interact (clean). Found
  during implementation, not from documentation alone: the first attempt
  matched on `Ada_Bin_Op` for both comparison sub-expressions and
  silently found nothing, because Libadalang represents a relational
  comparison (`>`, `<`, `=`, ...) as the distinct `Ada_Relation_Op` kind,
  not `Ada_Bin_Op` -- a derived kind that shares `Ada_Bin_Op`'s fields but
  fails an exact `Kind =` test. Fixed by matching the `Ada_Bin_Op_Range`
  subtype, which spans both kinds.

- 3 cases for `Null_Case_Alternative`, added alongside the new check (the
  case-alternative counterpart of `Empty_If_Body`, closing a gap the
  GNATcheck oracle comparison found in `Empty_If_Body`'s own scope -- see
  `GNATCHECK_RULE_COMPARISON.md`'s `null_paths` row): a case alternative
  naming a specific choice whose body is only `null;` must fire
  (`finding`), even while a sibling alternative in the same statement does
  real work; the same shape with a real assignment instead of `null;` must
  not fire (clean); and a catch-all `when others => null;` must not fire
  either (clean) -- found during implementation, not from documentation
  alone: this analyzer's own source uses that exact "explicit no-op default"
  idiom throughout its `Ada_Node_Kind_Type` dispatch code (confirmed by
  running the first, unscoped version of the check against `--recommended`'s
  self-analysis gate, which surfaced 9 genuine instances), so the check
  deliberately does not flag a bare `others` alternative the way GNATcheck's
  broader `null_paths` does.

- 2 cases for `Empty_Elsif_Body`, added alongside the new check (the
  elsif-branch counterpart of `Empty_If_Body`, closing another gap the
  GNATcheck oracle comparison found in `Empty_If_Body`'s own scope -- see
  `GNATCHECK_RULE_COMPARISON.md`'s `null_paths` row): an elsif branch whose
  body is only `null;` must fire (`finding`), even while the earlier then
  branch does real work; the same shape with a real assignment instead of
  `null;` must not fire (clean). One genuine instance of the same
  "deliberate no-op branch" idiom found on `--recommended`'s self-analysis
  gate as `Null_Case_Alternative`'s launch, just spelled with `elsif`
  instead of `case`/`others` (`flow_interp.adb:4244`, a dispatch over CFG
  node kinds where two kinds are deliberately skipped) -- suppressed with
  this codebase's standard inline `adalang-analyzer: ignore` comment rather
  than adding a broader exemption, logged as `FP-057`. Did not (yet) cover a
  bare `if`'s then-branch when an elsif/else is present, or an empty `else`
  branch -- both of those narrower gaps against GNATcheck's `null_paths` are
  now closed by `Empty_Then_Body` and `Empty_Else_Body` below.

- 3 cases for `Empty_Then_Body`, added alongside the new check (the
  then-branch counterpart of `Empty_Elsif_Body`, closing the "bare if's
  then-branch when an elsif/else is present" gap `Empty_Elsif_Body`'s own
  entry above left open): a then branch whose body is only `null;` followed
  by an elsif that does real work must fire (`finding`); the same shape with
  a real assignment in the then branch instead of `null;` must not fire
  (clean); and reusing the exact fixture that is `clean` for `Empty_If_Body`
  (`precision_empty_if_body_with_else_clean.adb`: empty then-body, real
  else) as a third case, expected `finding` here, demonstrates the precise
  scope split between the two checks on one shared file. Four genuine
  instances of the same "deliberate no-op branch" idiom as `Empty_Elsif_Body`'s
  `FP-057` found on `--recommended`'s self-analysis gate
  (`control_flow.adb:43`, `cli.adb:300`, `flow_interp.adb:4357`,
  `subprogram_summaries.adb:402`, each a `then null; elsif/else <real
  work>;` dispatch skipping one case explicitly) -- suppressed the same way
  as `FP-057`, with this codebase's standard inline `adalang-analyzer:
  ignore` comment at each site rather than a broader exemption.

- 2 cases for `Empty_Else_Body`, added alongside the new check (the
  else-branch counterpart of `Empty_If_Body`/`Empty_Elsif_Body`/
  `Empty_Then_Body`, closing the last of the three `null_paths`/
  `Empty_If_Body` scope gaps): an else part whose body is only `null;` must
  fire (`finding`), even while the then branch does real work; the same
  shape with a real assignment instead of `null;` must not fire (clean). No
  self-analysis noise found on `--recommended`'s gate: unlike the then/elsif
  cases, this analyzer's own source has no deliberate-no-op `else null;`
  idiom, so no suppression or `FP-0NN` entry was needed for this check.

- 5 cases added 2026-08-24 as the `FP-059` regression, one per check sharing
  `Has_Substantive_Statement` (`Empty_If_Body`, `Empty_Elsif_Body`,
  `Empty_Then_Body`, `Empty_Else_Body`, `Null_Case_Alternative`): a branch
  or alternative whose body is only `pragma Assert (False);` must not fire
  (clean) -- not found by inspection, but by finally running this
  analyzer's own GNATcheck oracle comparison method against
  `benchmarks/ada_drivers_library/` for `Empty_Then_Body`/`Empty_Else_Body`
  for the first time since they were added, which surfaced a real false
  positive on `stm32-dma2d-interrupt.adb:109`'s `else pragma Assert
  (False); end if;` (a deliberate "must never happen" guard, not filler).
  `Has_Substantive_Statement` had treated every pragma as non-substantive
  filler with no exception, so the same false positive was independently
  confirmed reachable through all five checks by direct construction of one
  fixture per check, not just argued from code inspection -- fixed by
  special-casing `pragma Assert` specifically to count as substantive,
  every other pragma unaffected. See
  `benchmarks/ada_drivers_library/RESULTS_gnatcheck_2026-08-24.md` for the
  run that found it and `quality/known_analysis_issues.tsv`'s `FP-059` for
  the full trace, including confirming each of the 5 fixtures would fail
  against the pre-fix binary by toggling the fix off and re-running.

This is a starting corpus, not a complete one. Still open, in roughly
increasing order of effort:

- More boundary/negative cases for checks without a numeric threshold (e.g.
  suspicious-but-legitimate constructs that resemble a violation without
  being one) — 112 of the 120 `Rule_Kind` values now have at least one
  dedicated fixture, leaving 8 remaining: the seven `Known_*_Failure` checks,
  which only fire under `--verify` and so need a bounded proof-obligation
  fixture rather than a plain `Rule_Kind` boundary (see the "Precision
  regression index" below for how their mechanism is instead covered by
  `run_verification.sh` fixtures); and `Circular_Package_Dependency`, a
  whole-program check that only fires across a `with`-cycle spanning two or
  more files and so cannot be expressed as this manifest's single-fixture
  row (covered instead by `run_circular_dependencies.sh`).
- Cross-version stability: re-running the same corpus across analyzer
  releases and tracking whether previously stable results change.

Two items formerly listed here -- a project-scale corpus of real Ada code to
estimate precision beyond hand-constructed fixtures, and an independent-oracle
comparison against another tool on the subset of checks with real overlap --
now have a first data point: `benchmarks/sparknacl/` compares `--verify`
against GNATprove, per obligation, on a real, fully-proved SPARK library (see
below). Treat that as a first data point, not a closed question: it should be
re-run as the analyzer changes and extended to other corpora, the same way
the external-corpus findings below are.

## Precision regression index

Each precision correction has an executable regression:

| Corrected mechanism | Regression evidence |
| --- | --- |
| Static attributes are not elaboration calls | `automotive_state_clean.ads`, run by `run_automotive.sh`; also `Library_Level_Initialization` in `precision_corpus.tsv` |
| Generated configuration pragmas are not authored extensions | `run_automotive.sh` generated-config check; also `No_Compiler_Extensions` in `precision_corpus.tsv` |
| A pure `out` actual initializes its variable | `uninitialized_read_clean.adb`, run by `run_bug_findings.sh`; also `Uninitialized_Read` in `precision_corpus.tsv` |
| A parameterless prefixed mutator writes its prefix | `parameter_mode_clean.adb`, run by `run_bug_findings.sh`; also `Wrong_Parameter_Mode` and `Dead_Store` in `precision_corpus.tsv`; also `Uninitialized_Output` in `precision_corpus.tsv` (`uninitialized_output_prefixed_clear_clean.adb`/`_guard.adb`, the write-recognition path `SPARK_Readiness.Statement_Writes_Parameter` uses independently of `Checks.Declarations.Parameter_Is_Written`) |
| Failure-path `out` initialization is not an overwritten assignment | Numeric-literal self-check in `run_recommended.sh` (not folded into `precision_corpus.tsv`: the fixture is the analyzer's own source, not a `tests/*.adb` file) |
| State captured by a nested verifier pass is not a dead store | Flow-interpreter self-check in `run_recommended.sh` (not folded: same reason) |
| Required cleanup status outputs are consumed | VC-prover self-check in `run_recommended.sh` (not folded: same reason) |
| Direct outer `out`-to-`out` forwarding is a write, not a read | `verification_diff_modular_call.adb`, run by `run_verification.sh` and `run_gnatprove_differential.sh` (not folded: this is a bounded `--verify` proof-obligation outcome, not a `Rule_Kind` finding) |
| A same-named enumeration literal is not `Standard.True`/`Standard.False` | `redundant_boolean_comparison_clean.adb`; also `Redundant_Boolean_Comparison` in `precision_corpus.tsv` |
| A write to a Volatile/Atomic/Address-clause object is observable on its own, independent of a later Ada-level read or a repeated identical write | `volatile_register_writes_clean.adb`; also `Repeated_Statement`, `Overwritten_Assignment`, and `Dead_Store` (case `regression-negative-volatile`) in `precision_corpus.tsv` |
| A write to only a selected/indexed component of a parameter does not justify recommending mode `out` -- it depends on every untouched part already holding a meaningful prior value | `wrong_parameter_mode_partial_write_clean.adb`/`_guard.adb`; also `Wrong_Parameter_Mode` in `precision_corpus.tsv` (`Checks.Declarations.Parameter_Is_Wholly_Written`, used only to gate the "use mode out" recommendation; `Dead_Store` and `Uninitialized_Output` still use the original, coarser write detection) |
| An attribute designator (the "Last" naming the attribute in `Data'Last`) is syntactically an identifier but never refers to a declaration, and must not be mistaken for a reference to an unrelated local variable of the same spelling | `uninitialized_read_attribute_designator_clean.adb`/`_guard.adb`; also `Uninitialized_Read` in `precision_corpus.tsv` (`Checks.Data_Flow.Matches_Declaration`, shared by every check built on that module, not only `Uninitialized_Read`) |
| A renaming of part of a longer-lived parameter or global (`Info : T renames Self.Field;`) is not local, even though its own declaration is textually nested inside the subprogram | `dead_store_renaming_of_parameter_field_clean.adb`/`_guard.adb`; also `Dead_Store` in `precision_corpus.tsv` (`Checks.Control_Flow.Renames_Nonlocal_Object`) |
| A nested subprogram or entry body is a declaration -- elaborated, not executed, at its own textual position -- so a read or write inside it does not happen "here" the way a statement does; it only happens when the nested body is actually called | `uninitialized_read_nested_subprogram_order_clean.adb`/`_guard.adb`; also `Uninitialized_Read` in `precision_corpus.tsv` (`Checks.Data_Flow.First_Access` skips recursing into `Ada_Subp_Body`/`Ada_Entry_Body` children) |
| Libadalang's per-actual resolution (`P_Get_Params`) can fail to classify an actual even on an otherwise-unambiguous call (heavy overload; a formal typed `Ada.Calendar.Time`); every write/read detector built on it needs the same lenient callee-name-only, pair-by-position-or-designator fallback, not just the first one that hit it | `uninitialized_read_positional_forward_clean.adb`/`_guard.adb`; also `Uninitialized_Read` in `precision_corpus.tsv` (`Checks.Data_Flow.Call_Writes_Declaration`/`Call_Reads_Simple_Actual`, alongside the original fix in `SPARK_Readiness.Statement_Writes_Parameter` for `FP-008`/`FP-012`) |
| When every formal-resolution path fails for a simple call actual, the call may have initialized that object; a later read is unknown, not definitely before every write. Resolved input actuals remain reads | `uninitialized_read_unresolved_call_clean.adb`/`_guard.adb`; also `Uninitialized_Read` in `precision_corpus.tsv` (`Checks.Data_Flow.First_Access` returns `Unknown_Access` at the unresolved call boundary) |
| `--verify`'s CFG worklist fixed point can record an obligation from an intermediate, not-yet-converged state (typically before a loop's back edge has propagated); a later, fully-converged recording for the same location must be able to correct it, not just refine an `Unproved` result | `verification_loop_stale_initialization.adb`, run by `run_verification.sh` (not folded: this is a bounded `--verify` proof-obligation outcome, not a `Rule_Kind` finding); see `FP-031` in `known_analysis_issues.tsv` for the `Proof_Obligations.Register_At` `Final` mechanism this introduced |
| A `Rule_Kind` violation reported from a live check `Verify_Subprogram`'s CFG fixed point can call more than once for the same AST node (the ordinary-findings counterpart to the `--verify` obligation staleness above) must be counted once per (file, line, column, rule, message), not once per re-visit | `verification_loop_stale_range_check.adb`, run by `run_verification.sh` (not folded: exercises the `--verify`-specific CFG-revisit mechanism, not a plain `Rule_Kind` boundary); see `FP-038` in `known_analysis_issues.tsv` for the `Report.Report_Violation_At` `Already_Reported` deduplication this introduced |
| A range-check whose target value is written inside a dynamically-bounded loop must not be recorded `Proved_Safe` from the CFG fixed point's pre-convergence state (before the loop's back edge propagates a later out-of-range write); the converged state's honest `Unproved` must be able to correct it | `verification_loop_stale_range.adb`, run by `run_verification.sh` (not folded: a bounded `--verify` proof-obligation outcome, not a `Rule_Kind` finding); see `FP-034` in `known_analysis_issues.tsv` for the `Check_Value_Range`/`Finalize_Range_Check` `Final` replay this introduced, reusing FP-031's mechanism |
| The same pre-convergence staleness as `FP-034`, for an array index instead of an assignment's range | `verification_loop_stale_index.adb`, run by `run_verification.sh`; see `FP-035` in `known_analysis_issues.tsv` (`Check_Index_Range`/`Finalize_Index_Check`) |
| The same pre-convergence staleness as `FP-034`, for a division's divisor instead of an assignment's range | `verification_loop_stale_division.adb`, run by `run_verification.sh`; see `FP-036` in `known_analysis_issues.tsv` (`Check_Division_By_Zero`/`Finalize_Division_Check`) |
| The same pre-convergence staleness as `FP-034`, for an arithmetic operation's overflow bound instead of an assignment's range | `verification_loop_stale_overflow.adb`, run by `run_verification.sh`; see `FP-037` in `known_analysis_issues.tsv` (`Check_Integer_Overflow`/`Finalize_Overflow_Check`) |
| The same pre-convergence staleness as `FP-034`/`FP-031`, for a `pragma Assert`/`Loop_Invariant`/`Loop_Variant` condition's `Interpret_Proof_Pragma` recording instead of a range check | `verification_loop_stale_assert.adb`, run by `run_verification.sh`; see `FP-032` in `known_analysis_issues.tsv` (`Check_Proof_Pragma_Assertion`/`Finalize_Assertion_Check`) |
| The same pre-convergence staleness as `FP-032`, for a call's precondition (`Check_Call_Precondition`) instead of a pragma condition; recorded under two distinct stable IDs per call (the whole call, and just the callee name), both needing their own replay | `verification_loop_stale_precondition.adb`, run by `run_verification.sh`; see `FP-033` in `known_analysis_issues.tsv` (`Finalize_Precondition_Check`) |
| Every nested `Bin_Op` in a left-associative chain of plain `and`/`or` operators shares the same `Sloc_Range.Start` (the leftmost operand's position), so a chain of N operators must still report once, not N-1 times | `non_short_circuit_chain_findings.adb`, run by `run_bug_findings.sh` (not folded: the fixture's expected count is 1, not a `precision_corpus.tsv`-expressible clean/finding boundary); also fixed by `FP-038`'s `Already_Reported` deduplication, independent root cause |
| A scalar named only in a nested subprogram declaration's `Global` aspect (a contract, never executed at that textual position) is not a read of the outer object, even though `Finalize_Node`'s whole-body walk shared one CFG position -- positioned before the object's real initializing assignment -- for the entire declaration, aspect included | `verification_global_aspect_reference_clean.adb`/`_guard.adb`, run by `run_verification.sh` (not folded: a bounded `--verify` proof-obligation outcome, not a `Rule_Kind` finding); see `FP-039` in `known_analysis_issues.tsv` (`Finalize_Node`'s new `Ada_Aspect_Spec` exclusion) |
| A "limited with" imposes no "elaborate before" requirement and is Ada's own sanctioned way for two units to reference each other's types without a real circular elaboration dependency, so it must not contribute a `Circular_Package_Dependency` graph edge the way an ordinary/private with does | `circular_dependency_limited_with_a.ads`/`_b.ads`, run by `run_circular_dependencies.sh` (not folded into `precision_corpus.tsv`: `Circular_Package_Dependency` is a whole-program check that needs both cycle members on one command line, the same reason its original findings/clean fixtures are not folded either); see `FP-042` in `known_analysis_issues.tsv` (edges are now built by walking `Compilation_Unit.F_Prelude`'s own `With_Clause` nodes and skipping any with `F_Has_Limited`, instead of the aggregated `P_Withed_Units`, which does not distinguish limited from ordinary) |

When another precision bug is fixed, add or extend a fixture and add its row
here in the same change.

## External corpus findings

`external_corpus_findings.md` records validation runs against real Ada/SPARK
code the project did not write (as opposed to the hand-constructed precision
corpus above) — what was run, what was found, and the fix and regression
test for anything confirmed as a real analyzer mistake (folded into
`known_analysis_issues.tsv`). `benchmarks/README.md` carries the current
GNATprove- and GNATcheck-oracle comparison numbers for all ten tracked
corpora (sparknacl, saatana, libkeccak, coap_spark, tokeneer, cubedos, aws,
ada_drivers_library, gnatcoll, project_bias) — see that file for current
matched-obligation counts, unsoundness/false-positive totals, and each
corpus's own dated `RESULTS_*.md`. Do not duplicate those numbers here;
they change with every re-run.

## Differential corpus

The GNATprove differential gate contains 18 clean and 9 deliberately broken
units. The clean corpus includes:

- Bounded arithmetic and assignment chaining.
- Conditional range refinement.
- Modular contract transfer.
- Indexed array access.
- Relational loop invariants.
- Increasing loop variants.

The modular-call case now exercises direct forwarding from an outer `out`
parameter to a nested `out` parameter. It is the regression for closed issue
`FP-001` and must remain free of a definite initialization error.

Run it with `sh tests/run_gnatprove_differential.sh`. The script rejects
`Definite_Error` or `Unsupported` AdaLang results on the clean corpus and
requires GNATprove to prove all 18 clean units. It also requires GNATprove to
find failures in every unit of the broken corpus.
