# Checks

AdaLang Analyzer's 127 checks fall into five broad groups:

- **Defect detection** — control-flow, data-flow, expression, case/
  conditional, exception-handling, arithmetic, assignment, and complexity
  checks that flag likely or definite runtime and logic defects.
- **SPARK readiness** — `Global`/`Depends` contract checks and known
  precondition/postcondition/assertion/range/index/overflow/discriminant/
  enum-val/value-conversion failures that anticipate what a later
  GNATprove pass will need.
- **Bounded verification** — `--verify`'s scalar proof-obligation
  classification (a mode, not a rule in the table below; see the following
  sections).
- **Safety profiles** — the `Automotive` and `DO-178C support` checks behind
  `--automotive` and `--do178c=<level>`.
- **Style & maintainability** — restricted-construct policies, style, and
  naming checks.

Run `./bin/adalang_analyzer -list-checks` for the authoritative catalog and
guidance shipped by the current binary.

<details>
<summary><strong>Browse all 127 checks</strong></summary>

<br>

| Category | Check | Software Quality | Severity | Purpose |
|----------|-------|-------------------|----------|---------|
| Restricted construct | `No_Goto` | Maintainability | Medium | Reports `goto` statements. |
| Restricted construct | `No_Abort` | Reliability | High | Reports asynchronous task aborts. |
| Restricted construct | `No_Raise` | Maintainability | Low | Reports explicit `raise` statements. |
| Restricted construct | `No_Exit` | Maintainability | Low | Reports loop `exit` statements. |
| Restricted construct | `No_Label` | Maintainability | Low | Reports statement labels. |
| Restricted construct | `No_Pragma` | Maintainability | Low | Reports pragmas. |
| Restricted construct | `No_Access_To_Subp_Def` | Maintainability | Medium | Reports access-to-subprogram type definitions. |
| Safety | `No_Unchecked_Conversion` | Security | High | Reports instantiations of `Ada.Unchecked_Conversion`. |
| Safety | `No_Unchecked_Access` | Security | High | Reports uses of the `'Unchecked_Access` attribute. |
| Numerical safety | `Floating_Equality` | Reliability | Medium | Reports `=` and `/=` applied to floating-point operands. |
| Maintainability | `Magic_Number` | Maintainability | Low | Reports unexplained numeric literals other than 0, 1, and -1 outside named constant declarations. |
| Data flow | `Unused_Parameter` | Maintainability | Low | Reports subprogram parameters that are never referenced. |
| Data flow | `Wrong_Parameter_Mode` | Maintainability | Medium | Reports `in out` parameters that are only read or only written. |
| Data flow | `Dead_Store` | Maintainability | Medium | Reports assignments whose value is never read later in the subprogram. |
| Data flow | `Overwritten_Assignment` | Reliability | Medium | Reports assignments overwritten before an intervening read. |
| Data flow | `Uninitialized_Read` | Reliability | High | Reports scalar local variables with no initial value whose first use is a read. |
| Data flow | `Inefficient_String_Concatenation` | Reliability | Medium | Reports a string variable rebuilt with `&` inside a loop. |
| Scope | `Shadowed_Declaration` | Reliability | Medium | Reports local objects hiding declarations in enclosing subprograms. |
| Case analysis | `Unreachable_Case_Alternative` | Reliability | Medium | Reports choices wholly covered by an earlier case alternative. |
| Case analysis | `Overlapping_Case_Ranges` | Reliability | High | Reports intersecting statically evaluable integer choices. |
| Control flow | `Infinite_Loop` | Reliability | High | Reports unconditional loops without an exit, return, or raise. |
| Expression | `Duplicate_Boolean_Operand` | Reliability | Medium | Reports repeated boolean operands and double negations. |
| Expression | `Redundant_Abs` | Maintainability | Low | Reports `abs` applied to an operand that is itself an `abs` expression. |
| Expression | `Redundant_Unary_Minus` | Maintainability | Low | Reports unary negation applied to an operand that is itself a unary negation. |
| Exception handling | `Exception_Swallowed` | Reliability | High | Reports empty or null-only `when others` handlers. |
| Complexity | `Cyclomatic_Complexity` | Maintainability | Medium | Reports subprograms exceeding the configured complexity threshold. |
| Control flow | `Constant_Condition` | Reliability | Medium | Reports conditions that are statically always true or false. |
| Control flow | `Unreachable_Code` | Maintainability | Medium | Reports statements following an unconditional transfer of control. |
| Arithmetic | `Division_By_Zero` | Reliability | Blocker | Reports statically detectable division, `mod`, or `rem` by zero. |
| Arithmetic | `Integer_Division_Before_Multiplication` | Reliability | Medium | Reports integer multiplications whose left operand is an unparenthesized integer division. |
| Arithmetic | `Excessive_Shift_Amount` | Reliability | High | Reports `Interfaces` shift/rotate calls whose static amount is not less than the operand type's bit width. |
| Arithmetic | `Known_Negative_Shift_Amount_Failure` | Reliability | High | Reports `Interfaces` shift/rotate calls whose static amount is negative. |
| Arithmetic | `Known_Negative_Exponent_Failure` | Reliability | High | Reports `**` exponentiations on an integer base whose static exponent is negative. |
| Arithmetic | `Succ_Pred_Boundary_Overflow` | Reliability | Blocker | Reports `'Succ` applied to `'Last` or `'Pred` applied to `'First` of the same scalar type. |
| Arithmetic | `Reversed_Range` | Reliability | Medium | Reports static ranges whose lower bound exceeds their upper bound. |
| Assignment | `Self_Assignment` | Reliability | Medium | Reports assignments whose target and value designate the same object, including through simple renames. |
| Expression | `Same_Operand` | Reliability | Medium | Reports suspicious binary expressions with identical operands. |
| Conditional | `Duplicate_Condition` | Reliability | Medium | Reports repeated conditions in an `if`/`elsif` chain. |
| Duplication | `Duplicate_With_Clause` | Maintainability | Low | Reports with clauses naming a unit already with'd in the same context clause. |
| Style | `Null_Statement` | Maintainability | Low | Reports executable `null` statements. |
| Style | `Redundant_Final_Return` | Maintainability | Low | Reports a bare `return;` as the last statement of a procedure body. |
| Exception handling | `Empty_Exception_Handler` | Reliability | High | Reports handlers containing no substantive statements. |
| Exception handling | `Duplicate_Exception_Choice` | Maintainability | Low | Reports an exception handler whose own choice list names the same exception more than once. |
| Control flow | `Unreachable_Branch` | Reliability | Medium | Reports branches excluded by earlier static conditions. |
| Conditional | `Contradictory_Condition` | Reliability | High | Reports expressions such as `X and not X` or `X or not X`. |
| Conditional | `Contradictory_Range_Condition` | Reliability | High | Reports `and`/`and then` conditions combining two relational comparisons on the same expression whose statically known bounds cannot both hold. |
| Conditional | `Identical_Branches` | Reliability | Medium | Reports adjacent conditional branches with identical bodies. |
| Assignment | `Repeated_Statement` | Reliability | Medium | Reports identical consecutive assignments. |
| Expression | `Ineffective_Operation` | Maintainability | Low | Reports operations containing an identity operand that has no effect. |
| Expression | `Constant_Result_Operation` | Reliability | Medium | Reports operations forced to a constant by an absorbing operand. |
| Control flow | `Empty_Loop` | Reliability | Medium | Reports loops containing no substantive statements. |
| Restricted construct | `No_Recursion` | Reliability | High | Reports subprograms that call themselves directly. |
| Restricted construct | `No_Multiple_Return` | Maintainability | Low | Reports subprograms with more than one return statement. |
| Control flow | `Non_Short_Circuit_Condition` | Reliability | High | Reports plain `and`/`or` used in an if/elsif/exit-when/while condition. |
| Safety | `Address_Clause` | Security | High | Reports address representation clauses. |
| Complexity | `Too_Many_Parameters` | Maintainability | Medium | Reports subprograms exceeding the configured parameter-count threshold. |
| Complexity | `Swappable_Parameters` | Reliability | Medium | Reports adjacent parameters sharing a mode and a resolved type, which a positional call could transpose undetected. |
| Complexity | `Deep_Nesting` | Maintainability | Medium | Reports subprograms exceeding the configured nesting-depth threshold. |
| Data flow | `Unused_Variable` | Maintainability | Low | Reports local objects that are never referenced. |
| Style | `Empty_If_Body` | Maintainability | Low | Reports if statements with no elsif/else whose body has no effect. |
| Style | `Empty_Elsif_Body` | Maintainability | Low | Reports elsif branches with no substantive statements. |
| Style | `Empty_Then_Body` | Maintainability | Low | Reports an empty then branch even when an elsif or else follows. |
| Style | `Empty_Else_Body` | Maintainability | Low | Reports else parts with no substantive statements. |
| Style | `Null_Case_Alternative` | Maintainability | Low | Reports case alternatives with no substantive statements. |
| Style | `Unnecessary_Else_After_Return` | Maintainability | Low | Reports else parts made redundant by an earlier unconditional return/raise/exit. |
| Style | `Redundant_If_Boolean_Return` | Maintainability | Low | Reports an if statement whose then and else branches each return only an opposite boolean literal. |
| Data flow | `Function_Side_Effect` | Reliability | High | Reports functions that assign to state outside their own parameters and locals. |
| Expression | `Redundant_Boolean_Comparison` | Maintainability | Low | Reports equality/inequality comparisons against the literal `True`/`False`. |
| Style | `Long_Line` | Maintainability | Low | Reports source lines longer than the configured threshold. |
| Style | `Trailing_Whitespace` | Maintainability | Low | Reports source lines with trailing spaces or tabs. |
| SPARK | `SPARK_Mode` | Reliability | High | Reports regions that explicitly set `SPARK_Mode` to `Off`. |
| SPARK | `Missing_Global_Contract` | Maintainability | Medium | Reports subprograms that access global state without an explicit `Global` contract. |
| SPARK | `Global_Contract_Mismatch` | Reliability | High | Reports actual global reads or writes that an existing `Global` contract does not permit. |
| SPARK | `Missing_Depends_Contract` | Maintainability | Medium | Reports subprograms with outputs but no explicit `Depends` contract. |
| SPARK | `Incomplete_Depends_Contract` | Reliability | High | Reports writable parameters or global outputs omitted from `Depends`. |
| SPARK | `Depends_Contract_Mismatch` | Reliability | High | Compares inferred data and control flow with declared `Depends` input-to-output relations. |
| SPARK | `Uninitialized_Output` | Reliability | High | Reports `out` parameters not demonstrably initialized on every normal return path. |
| SPARK | `Known_Precondition_Failure` | Reliability | High | Reports calls whose actual values make a precondition false. |
| SPARK | `Known_Postcondition_Failure` | Reliability | High | Reports bodies whose resulting state makes their postcondition false. |
| SPARK | `Known_Assertion_Failure` | Reliability | High | Reports assertion pragmas whose condition is statically false at that program point. |
| SPARK | `Assertion_Side_Effect` | Reliability | Medium | Reports assertion pragmas whose condition calls a function with an out or in out parameter. |
| Tasking | `Entry_Barrier_Side_Effect` | Reliability | Medium | Reports protected entry barrier conditions that call a function with an out or in out parameter. |
| SPARK | `Known_Range_Check_Failure` | Reliability | High | Reports values provably outside an assignment, initialization, or conversion subtype. |
| SPARK | `Known_Index_Check_Failure` | Reliability | High | Reports array indices provably outside the corresponding index subtype. |
| SPARK | `Known_Overflow_Failure` | Reliability | High | Reports integer arithmetic provably outside the operation's base type. |
| Case analysis | `Identical_Case_Alternative` | Reliability | Medium | Reports adjacent case alternatives with identical bodies. |
| Expression | `Redundant_Type_Conversion` | Maintainability | Low | Reports explicit type conversions whose operand already has the target subtype. |
| Style | `Missing_Overriding_Indicator` | Maintainability | Medium | Reports primitive subprograms that override an inherited operation without the `overriding` keyword. |
| Exception handling | `Handler_Order` | Reliability | High | Reports a `when others` handler that precedes, and thereby shadows, a more specific handler in the same list. |
| Exception handling | `Reraise_Discards_Occurrence` | Reliability | Medium | Reports an exception handler's last statement re-raising the same single exception it caught by name instead of a bare `raise;`. |
| Data flow | `Aliasing_Between_Parameters` | Reliability | High | Reports calls that pass the same object or component as two actual parameters when at least one corresponding formal is written. |
| SPARK | `Missing_Loop_Variant` | Maintainability | Medium | Reports loops with a `Loop_Invariant` pragma but no `Loop_Variant` pragma. |
| SPARK | `Known_Discriminant_Check_Failure` | Reliability | High | Reports accesses to a variant-part component that a statically known discriminant constraint provably excludes. |
| SPARK | `Known_Enum_Val_Failure` | Reliability | High | Reports `'Val` attribute calls whose statically known argument is outside the enumeration type's literal positions. |
| SPARK | `Known_Value_Conversion_Failure` | Reliability | High | Reports `'Value` attribute calls whose static string literal argument can never denote a value of the prefix integer or enumeration type. |
| SPARK | `Potentially_Blocking_Operation` | Reliability | High | Reports entry calls, delay statements, and calls transitively reaching them from a protected operation. |
| Automotive | `No_Dynamic_Allocation` | Reliability | High | Reports allocators. |
| Automotive | `Restricted_Access_Type` | Reliability | High | Reports access-to-object type definitions. |
| Automotive | `No_Explicit_Dereference` | Reliability | High | Reports explicit `.all` dereferences. |
| Automotive | `No_Unchecked_Deallocation` | Security | High | Reports semantic instantiations of `Ada.Unchecked_Deallocation`. |
| Automotive | `No_Tasking` | Reliability | High | Reports task declarations. |
| Automotive | `No_Rendezvous` | Reliability | High | Reports entry declarations and accept statements. |
| Automotive | `No_Select` | Reliability | High | Reports selective, timed, conditional, and asynchronous select forms. |
| Automotive | `No_Requeue` | Reliability | High | Reports requeue statements. |
| Automotive | `No_Asynchronous_Transfer` | Reliability | High | Reports asynchronous select/abortable-part constructs. |
| Automotive | `Exception_Propagation` | Reliability | High | Reports calls that may propagate a direct or transitive explicit exception when the enclosing subprogram has no handler boundary. |
| Automotive | `No_Dispatching_Call` | Reliability | High | Reports semantically resolved dispatching calls. |
| Automotive | `No_Classwide_Type` | Reliability | High | Reports class-wide subtype marks. |
| Automotive | `No_Controlled_Type` | Reliability | High | Reports derivation from controlled or limited-controlled types. |
| Automotive | `Complete_Initialization` | Reliability | High | Reports objects and record components without explicit initialization. |
| Automotive | `Volatile_Atomic_Consistency` | Reliability | High | Reports volatile declarations lacking an atomic or full-access policy. |
| Automotive | `Representation_Clause_Policy` | Reliability | Medium | Requires every explicit representation clause to receive target-specific review. |
| Automotive | `Library_Level_Initialization` | Reliability | High | Reports library-level initializers containing calls. |
| Automotive | `Generic_Instantiation_Limit` | Maintainability | Medium | Reports units exceeding the configured generic-instantiation limit. |
| Automotive | `Dependency_Limit` | Maintainability | Medium | Reports units exceeding the configured with-clause limit. |
| Automotive | `Circular_Package_Dependency` | Maintainability | Medium | Reports groups of analyzed units whose with clauses form a dependency cycle. |
| Duplication | `Duplicate_Subprogram` | Maintainability | Medium | Reports subprogram bodies, anywhere in the analyzed project, textually identical to another subprogram's. |
| Automotive | `Naming_Convention` | Maintainability | Low | Reports one-character identifiers except loop indices and enumeration literals. |
| Automotive | `No_Compiler_Extensions` | Maintainability | High | Reports implementation-defined pragmas, including extension-enabling pragmas. |
| Automotive | `No_Runtime_Check_Suppression` | Reliability | High | Reports `Suppress`, `Suppress_All`, and check policies that ignore or disable Ada run-time checks. |
| DO-178C support | `Missing_Requirement_Trace` | Reliability | High | Reports subprogram bodies without a nearby low-level requirement identifier. |
| DO-178C support | `Malformed_Requirement_Trace` | Maintainability | Medium | Reports requirement annotations with no identifier. |
| DO-178C support | `Suppression_Without_Rationale` | Maintainability | High | Reports analyzer suppressions that do not record a reviewable rationale. |
| Safety | `Use_After_Free` | Security | High | Reports a local access object read after `Ada.Unchecked_Deallocation` frees it, with no intervening assignment. |
| Safety | `Double_Free` | Security | High | Reports a local access object passed to `Ada.Unchecked_Deallocation` a second time, with no intervening assignment. |
| Data flow | `Unclosed_File_Handle` | Reliability | Medium | Reports a local `Ada.Text_IO`/`Ada.Streams.Stream_IO` file opened with `Open`/`Create` and not demonstrably closed on every normal-return or exception-handler path. |
| Data flow | `Unused_With_Clause` | Maintainability | Low | Reports a with clause naming a unit never referenced elsewhere in the file. |

</details>

<details>
<summary><strong>Read the analysis and bounded-verification model</strong></summary>

<br>

Every check also carries a SonarQube-style classification: a **Software
Quality** it primarily affects (`Security`, `Reliability`, or
`Maintainability`) and a **Severity** (`Blocker`, `High`, `Medium`, or
`Low`). This is the analyzer's own judgment applying SonarQube's Clean
Code taxonomy to Ada constructs, not an imported SonarQube ruleset. The
classification is not just documentation — the tool surfaces it at
runtime:

- `-list-checks` prints each check's classification next to its name,
  e.g. `No_Recursion [Reliability/High] - ...`.
- Every reported violation includes a `quality:` line, e.g.
  `quality: Reliability (High)`.
- The end-of-run summary breaks violations down both by check (with its
  classification) and with dedicated "Violations by software quality"
  and "Violations by severity" rollups.

Diagnostics can also carry analysis-specific explanations and evidence.
Text output prints these as `why:` and `evidence:` lines when the producing
check supplies them. JSON findings expose `explanation` and `evidence`
fields, and SARIF results preserve both values in their `properties` object.
This is initially populated for contradictory conditions and selected
assertion, contract, range, index, overflow, and division-by-zero findings;
other checks retain their existing message and rule guidance while they are
migrated incrementally. In text output, individual proof obligations are only
listed with `-v`; without it, only the aggregate total and per-status counts
are printed. Running with `-v` prints each obligation's location, method,
explanation, abstract-state evidence, and source of imprecision. Tooling that
parses the text report for individual proof obligations must pass `-v`, or use
JSON/SARIF, which always include the full per-obligation data regardless of
verbosity. When scalar VC translation is unsupported, the obligation also
records a stable `reasonCode`, the exact `blockingExpression`, and an
`inlinePath` such as `Outer -> Inner` when the blocker occurs inside one or
more inlined expression functions. These appear as `reason:`, `blocked at:`,
and `inline path:` in verbose text; JSON exposes them directly on each proof
obligation, and SARIF carries the proof-obligation array in the run's
`properties` object. This provenance is preserved for assertions,
preconditions, postconditions, leading loop-invariant initialization and
preservation, and scalar range, index, integer-overflow, and division-by-zero
obligations whenever VC translation is attempted.

The data-flow checks are intraprocedural and deliberately conservative.
`Dead_Store` follows resolved simple-object and array-component assignments in
source order, while `Overwritten_Assignment` stays within one statement list.
Textually equal dynamic components such as `Arr (I)` are equated only while no
intervening assignment or potentially mutating call changes `I`. The case
checks compare statically evaluable integer literals and ranges. These
boundaries keep findings predictable without requiring whole-program
control-flow analysis. Calls with resolved `out` formal parameters are treated
as writes to simple local-object actuals, so an output value that is never
consumed can be reported as a dead store. An `in out` actual also consumes its
incoming value and is not reduced to a pure-output dead store. Simple object
renames are resolved to their underlying declaration. Explicit access
dereferences remain outside the tracked target model because soundly equating
them requires points-to/alias analysis.
`No_Recursion` and `Function_Side_Effect` are likewise scoped conservatively:
`No_Recursion` only recognizes calls written with an explicit call syntax, and
`Function_Side_Effect` only flags assignments through a simple identifier
destination, to avoid false positives from unresolved or complex constructs.

A separate reusable control-flow graph models the structured sequential
subset used by `--verify`. It distinguishes normal and
exceptional exits, represents conditional and case branches, loop back and
exit edges, returns, raises, nested begin/declare blocks, and exception
handlers.
Implicit exceptions are conservatively over-approximated so later proof
analysis can remove infeasible exceptional edges without having to recover
missing paths. Unsupported transfers remain explicit and make the graph
incomplete. The verification interpreter propagates an abstract state to a
fixed point over this graph and applies interval widening at loop headers.

SPARK contracts participate in the flow-sensitive pass. A `Pre` aspect
narrows the abstract state at subprogram entry, and resolved formal-to-actual
parameter mappings allow a call with statically incompatible arguments to be
reported as a `Known_Precondition_Failure`. A `Post` aspect is evaluated using
the state established by the body, and facts it establishes for simple `out`
and `in out` parameters are transferred back to the caller. A postcondition
that the body makes statically false is reported as a
`Known_Postcondition_Failure`.

Assertion obligations are checked in the same abstract state. This covers
`Assert`, `Assert_And_Cut`, `Check`, and `Loop_Invariant` pragmas; a successful
assertion narrows the following state, while `Assume` narrows it without
creating an obligation. This mirrors useful local proof behavior from
GNATprove while remaining limited to conditions the abstract domain can
decide.

The same state is used for common Ada run-time proof obligations. Integer
initializations, assignments, and type conversions are compared with resolved
subtype bounds, and array subscripts are compared with the resolved index type
for each dimension. When interval reasoning is inconclusive in verification
mode, the scalar VC backend receives the expression, permitted bounds, and
path-sensitive symbolic state. It can prove containment, refute it, or retain
an unproved result with explicit unsupported-translation provenance.

Integer arithmetic is also checked against the resolved base type of the
operation. This models Ada's overflow check separately from the subtype check
performed by a later assignment and avoids reporting both obligations for the
same definitely overflowing expression. Division-by-zero obligations use the
same fallback to prove that a divisor is nonzero or refute that condition when
abstract ranges alone cannot decide it.

Division, integer arithmetic, range checks, index checks, selected discriminant
checks, assertions, preconditions, and postconditions reached by the
corresponding enabled checks are also recorded in a proof-obligation registry.
Text output summarizes their statuses, and JSON output includes both
`proofSummary` and `proofObligations`. Normal analysis records known failures
as `Definite_Error` and unresolved obligations as `Unproved`.

`--verify` enables a deliberately bounded scalar verification pass. Within a
complete supported control-flow and semantic boundary it classifies every
enumerated obligation as `Proved_Safe`, `Definite_Error`, `Unproved`, or
`Unreachable`. If that boundary is incomplete, affected obligations are
`Unsupported`; they are never silently treated as safe. `Proved_Safe` applies
only to that individual operation under the reported assumptions. It is not a
claim that a subprogram or program is correct, and this mode is not a
replacement for GNATprove.

The supported verification core is structured sequential integer and Boolean
code, statically bounded array indexing, initialization tracking, and simple
assertion, precondition, and postcondition facts. Calls to bodies present in
the analyzed source set use conservative interprocedural summaries for formal
writes, definite initialization on every normal return, and transitive
nonlocal writes. A summary is trusted only when its complete transitive call
boundary resolves; otherwise unknown effects retain the existing conservative
invalidation. Relational contract transfer still requires SPARK mode, an
explicit `Global` aspect, and non-aliased simple writable actuals. Access types
and explicit dereference, dispatching/class-wide behavior, tasking and
protected operations, floating-point proof, generic subprogram instantiations,
and unsupported transfers such as `goto` are outside the proof boundary.

For assertions that remain unknown after abstract interpretation, `--verify`
also has a small scalar verification-condition backend. It translates
side-effect-free integer/Boolean formulas using literals, initialized
variables, `+`, `-`, `*`, comparisons, equality, and Boolean connectives to
SMT-LIB. Current exact values and interval bounds become assumptions. A
`Proved_Safe` or `Definite_Error` external-prover result is accepted only when
both CVC5 and Z3 independently return the same UNSAT conclusion. Missing
solvers, timeouts, disagreement, uninitialized operands, division/remainder,
calls, or unsupported syntax remain `Unproved`.

The backend locates `cvc5` and `z3` on `PATH` or in Alire's standard
GNATprove installation. `ADALANG_CVC5` and `ADALANG_Z3` can select explicit
executables. Solver calls have a two-second limit each and never pass source
text through a shell.

The CFG verifier also carries a symbolic state beside the interval state.
Straight-line assignments are retained as symbolic substitutions, relational
subprogram preconditions and branch conditions become path assumptions, and
simple actual-to-formal substitutions feed call-precondition VCs. At a CFG
join, an identical symbolic assignment from every predecessor survives;
conflicting assignments receive a fresh unconstrained merge symbol. Calls
without a relational postcondition, exceptional edges, and unsupported writes
clear symbolic facts.

Leading `Loop_Invariant` pragmas now form inductive cut points for straight-line
scalar loop bodies. The verifier separately proves initialization from the
non-back-edge input and preservation for one generic iteration. Only when both
VCs succeed does a second CFG pass replace the loop fixed point with an
invariant summary, cut the back edge, and use the invariant plus the negated
loop condition for post-loop and subprogram-postcondition proofs. Failed
preservation never feeds downstream proofs. A single leading `Loop_Variant`
with `Increases` or `Decreases` is also checked across that generic iteration:
the value must move strictly in the declared direction and remain within its
static scalar bounds; decreasing variants must additionally be nonnegative at
the iteration entry. Invariants after executable loop statements, multiple or
non-leading variants, and branched, nested, call-containing, or otherwise
unsupported iteration paths remain `Unproved`. These fallbacks trade precision
for soundness and never create a speculative proof.

Effective `SPARK_Mode` inherited through a declaration is respected by these
contract checks. The SPARK-readiness pass separately compares semantic global
reads and writes with `Global` modes, follows the declared global effects of
resolved callees, checks that every writable formal or declared global output
has a `Depends` association, and performs branch-sensitive definite
initialization for scalar `out` parameters. It also infers input-to-output
information flow for explicit `Depends` contracts. Expression data flow,
conditional control flow, loop and exit conditions, normal-return paths,
exception handlers, global state, and resolved calls with dependency summaries
all participate. This detects missing and demonstrably extra edges, incorrect
`null` associations, omitted self-dependencies (`=>+`), incomplete input
coverage, and output dependencies on `Proof_In` state.

Missing explicit `Global` and `Depends` contracts are selectable
maintainability findings: SPARK permits tools to synthesize defaults, but
explicit contracts make review and regression checking substantially
stronger.

For abstract execution, `Global` contracts distinguish read-only `Input` and
`Proof_In` state from `Output` and `In_Out` state that a call may modify,
avoiding the previous loss of all global facts. The readiness checks are
conservative for component-level assignment targets, aliasing, unresolved
calls, dispatching, and exceptional prefixes. Dependency sets reach a fixed
point through loops; at unsupported boundaries the analyzer suppresses
precision-dependent "extra edge" findings while retaining conservative
"may depend" information. These checks establish inexpensive flow properties;
they do not generate verification conditions or replace GNATprove.

`Division_By_Zero` and `Constant_Condition` are additionally strengthened by a
flow-sensitive abstract-execution pass that tracks both a variable's known
integer value and its known boolean value across straight-line code,
`if`/`elsif`/`else` and `case` branches, declare blocks, and loops. A loop
havocs every variable its body assigns before interpreting the body once, so
a value known before the loop is never wrongly assumed to survive a
reassignment that happens later in the same loop body. A `case` statement
whose selector is statically known interprets only the one alternative it
actually matches, rather than joining every alternative, so an assignment
made in that single live branch is not diluted away at the merge point the
way it would be if two disagreeing branches were joined. An `if` expression
whose condition itself resolves is folded to its live branch's value the
same way. This lets both checks catch cases only reachable through an
earlier assignment or a resolved conditional, not just literal constants,
e.g. `X := 0; ... Y := 10 / X;`, `Flag := True; ... if Flag then ...`, or
`case Selector is when 5 => D := 0; when others => D := 2; end case; ...
Y := 10 / D;` when `Selector` is known to be 5.

Alongside each variable's exact known value, the same pass tracks a
best-effort *range* it is known to stay within, independently bounded from
below and/or above (unlike the exact-value domain, which is all-or-nothing).
A comparison against `if`/`elsif`/`while` narrows that range for the
branch(es) where the comparison is known to hold or not hold, including
through `not`, `and`/`and then`, and `or`/`or else`, so `if X > 0 then if
X >= 1 then ...` proves the inner condition constant even when `X`'s exact
value is never known. A `for` loop's own control variable is seeded from its
`Low .. High` bounds the same way, so `for I in 1 .. N loop if I > 0 then
...` is provably true on every iteration despite `I` changing each pass.
Range narrowing only ever tightens a bound it can prove, and joining two
branches unions rather than intersects their ranges, so an unresolvable or
unrelated comparison simply leaves the range as wide (and the check as
silent) as it already was.

The pass conservatively stops tracking at constructs it does not model
(`select`, `accept`, `goto` targets) and for subprogram or declare-block
bodies with their own exception handlers.

Four further checks strengthen the SPARK-readiness layer without attempting
proof. `Aliasing_Between_Parameters` walks each call's actual parameters
alongside their resolved formal modes and reports two actuals that are
textually the same object or component when at least one of the
corresponding formals is written — the same anti-aliasing legality rule
GNATprove enforces, checked here by simple structural comparison rather than
points-to analysis. `Missing_Loop_Variant` flags a loop that carries a
`Loop_Invariant` pragma without a matching `Loop_Variant`, since GNATprove
needs the latter to prove termination. `Known_Discriminant_Check_Failure`
resolves a selected component's variant part and the accessing object's own
discriminant constraint (when it is a literal or enumeration-literal
constant) and reports an access to a component that constraint provably
excludes, the same way a `case` statement with a statically known selector is
resolved to its one live alternative. `Potentially_Blocking_Operation` reports
a `delay` statement or entry call in a protected procedure or function. Before
the checking pass, a compact call-summary registry propagates blocking and
raising effects to a fixed point, so calls that transitively reach a blocking
operation are also reported. The same registry records incoming formal reads,
body-observed formal writes, all-path normal-return initialization, and direct
or transitive writes to nonlocal objects. Ordinary data-flow checks and
`--verify` use those effects to retain unaffected facts and initialize simple
`out` actuals only when every normal return writes the corresponding formal.
Nested subprogram bodies remain independently summarized rather than being
mistaken for direct execution by their parent. The summaries store monotone
effects rather than paths or complete states to keep the pass bounded; any
unresolved transitive call makes state effects incomplete and restores the
unknown-call fallback.

The `--automotive` preset combines these checks into a deliberately strict Ada
profile. It covers allocation and access use; unchecked conversion,
deallocation, and access; tasking,
rendezvous, select, requeue, and asynchronous transfer; exception handling and
escape; dispatching, class-wide, access-to-subprogram, controlled, and
finalization features; initialization; volatile/atomic use; representation
clauses; library elaboration; numeric operations and conversions; unreachable
selection logic; loop evidence; complexity and nesting; shadowing and naming;
generic/dependency limits; implementation-defined pragmas; run-time-check
suppression; and analyzer-suppression rationale. It is a strict superset of
`--spark`: it also requires an explicit `Global` and `Depends` contract on
every subprogram that needs one, and flags any region that explicitly leaves
the SPARK subset via `SPARK_Mode => Off`.

The preset is an engineering aid, not a claim of official MISRA or AUTOSAR
conformance. MISRA and AUTOSAR rule applicability, documented deviations,
compiler configuration, target representation evidence, traceability, and
tool-qualification evidence remain project responsibilities. In particular,
`Representation_Clause_Policy` creates a mandatory review finding rather than
pretending that a source-only analyzer can validate every target ABI, and
exception/dispatch summaries are conservative rather than full CodePeer-style
path proofs.

See the [Automotive Ada Compliance Matrix](automotive-compliance-matrix.md)
for a non-normative rule-by-rule mapping to the Ada Reference Manual's Annex H
high-integrity restrictions and SPARK Reference Manual guidance, limitations,
and remaining compliance gaps. The same `--automotive` rule set is also read
under EN 50128 (rail) verification-support vocabulary; see the
[EN 50128 Rail Compliance Matrix](en50128-rail-compliance-matrix.md).

</details>

