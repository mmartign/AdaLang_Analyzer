# Notes on the precision corpus

`precision_corpus.tsv` has one row per case, with the rule, the fixture, the
expected outcome and a note. This file keeps the longer account of the
campaigns that built part of the corpus: what each group of cases
targets in the check's own logic, and what was found while writing them.
It itemizes 233 cases; the cases added since are described by their `note`
column alone. `README.md` has the current size and coverage of the corpus.

- 12 threshold boundary cases: the six checks with a configurable numeric
  threshold — `Cyclomatic_Complexity`, `Deep_Nesting`, `Too_Many_Parameters`,
  `Long_Line`, `Generic_Instantiation_Limit`, `Dependency_Limit` — each with
  an "exactly at the default threshold" fixture that must stay clean and a
  "threshold plus one" fixture that must fire. Every boundary value in the
  corpus was confirmed against the built analyzer's own diagnostic message
  (e.g. "cyclomatic complexity 11 exceeds threshold 10"), not derived from
  reading the check's source and assuming it is correct.
- 9 regression-negative cases, folded in from the "Precision regression
  index" in `README.md`: `Library_Level_Initialization`, `No_Compiler_Extensions`,
  `Uninitialized_Read`, `Wrong_Parameter_Mode`, `Dead_Store` (twice, on two
  distinct fixtures), `Redundant_Boolean_Comparison`, `Repeated_Statement`,
  and `Overwritten_Assignment`, each on the existing fixture the index
  already pointed at. Only rows that map cleanly to one rule and one
  checked-in fixture were folded in this way; the remaining index rows
  reference the analyzer's own source or a bounded `--verify`
  proof-obligation outcome rather than a `Rule_Kind` finding on a
  `tests/*.adb` fixture, and stay prose-only rather than force an uncertain
  mapping into a gate (see that index for which).
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
  `docs/src/gnatcheck-rule-comparison.md`'s `null_paths` row): a case alternative
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
  `docs/src/gnatcheck-rule-comparison.md`'s `null_paths` row): an elsif branch whose
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
  every other pragma unaffected. See the 2026-08-29 Ada_Drivers_Library
  GNATcheck run (in the Git history of
  `benchmarks/ada_drivers_library/`) for the run that found it and
  `quality/known_analysis_issues.tsv`'s `FP-059` for the full trace, including confirming each of the 5 fixtures would fail
  against the pre-fix binary by toggling the fix off and re-running.

## Items once listed as open

Two items formerly listed here -- a project-scale corpus of real Ada code to
estimate precision beyond hand-constructed fixtures, and an independent-oracle
comparison against another tool on the subset of checks with real overlap --
now have a first data point: `benchmarks/sparknacl/` compares `--verify`
against GNATprove, per obligation, on a real, fully-proved SPARK library (see
`benchmarks/README.md`). Treat that as a first data point, not a closed question: it should be
re-run as the analyzer changes and extended to other corpora, the same way
the external-corpus findings are.
