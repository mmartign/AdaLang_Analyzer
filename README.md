# adalang_analyzer

`adalang_analyzer` is an independent command-line static analysis tool for Ada
source code maintained by [Spazio IT](https://spazioit.com/). It parses Ada and
reports rule violations with source locations, explanations, and remediation
guidance.

The project's current competitive scope and permitted product claims are
defined in [POSITIONING.md](POSITIONING.md). The meaning and limitations of
analysis results, including the boundary between ordinary findings and bounded
proof statuses, are defined in
[ASSURANCE_MODEL.md](ASSURANCE_MODEL.md).

## Relationship to Libadalang and AdaCore

- **Engine:** This tool is built on top of
  [Libadalang](https://github.com/AdaCore/libadalang), the open-source semantic
  engine developed by AdaCore.
- **Lineage:** The codebase is a derivative of AdaCore's open-source
  `libadalang-tools` repository.
- **Disclaimer:** This is an independent project maintained solely by Spazio
  IT. It is not endorsed, sponsored, or officially supported by AdaCore.
  “Libadalang” and “AdaCore” are trademarks of AdaCore.

## Checks

The analyzer currently provides the following checks:

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
| Exception handling | `Exception_Swallowed` | Reliability | High | Reports empty or null-only `when others` handlers. |
| Complexity | `Cyclomatic_Complexity` | Maintainability | Medium | Reports subprograms exceeding the configured complexity threshold. |
| Control flow | `Constant_Condition` | Reliability | Medium | Reports conditions that are statically always true or false. |
| Control flow | `Unreachable_Code` | Maintainability | Medium | Reports statements following an unconditional transfer of control. |
| Arithmetic | `Division_By_Zero` | Reliability | Blocker | Reports statically detectable division, `mod`, or `rem` by zero. |
| Arithmetic | `Reversed_Range` | Reliability | Medium | Reports static ranges whose lower bound exceeds their upper bound. |
| Assignment | `Self_Assignment` | Reliability | Medium | Reports assignments whose target and value designate the same object, including through simple renames. |
| Expression | `Same_Operand` | Reliability | Medium | Reports suspicious binary expressions with identical operands. |
| Conditional | `Duplicate_Condition` | Reliability | Medium | Reports repeated conditions in an `if`/`elsif` chain. |
| Style | `Null_Statement` | Maintainability | Low | Reports executable `null` statements. |
| Exception handling | `Empty_Exception_Handler` | Reliability | High | Reports handlers containing no substantive statements. |
| Control flow | `Unreachable_Branch` | Reliability | Medium | Reports branches excluded by earlier static conditions. |
| Conditional | `Contradictory_Condition` | Reliability | High | Reports expressions such as `X and not X` or `X or not X`. |
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
| Complexity | `Deep_Nesting` | Maintainability | Medium | Reports subprograms exceeding the configured nesting-depth threshold. |
| Data flow | `Unused_Variable` | Maintainability | Low | Reports local objects that are never referenced. |
| Style | `Empty_If_Body` | Maintainability | Low | Reports if statements with no elsif/else whose body has no effect. |
| Style | `Unnecessary_Else_After_Return` | Maintainability | Low | Reports else parts made redundant by an earlier unconditional return/raise/exit. |
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
| SPARK | `Known_Range_Check_Failure` | Reliability | High | Reports values provably outside an assignment, initialization, or conversion subtype. |
| SPARK | `Known_Index_Check_Failure` | Reliability | High | Reports array indices provably outside the corresponding index subtype. |
| SPARK | `Known_Overflow_Failure` | Reliability | High | Reports integer arithmetic provably outside the operation's base type. |
| Case analysis | `Identical_Case_Alternative` | Reliability | Medium | Reports adjacent case alternatives with identical bodies. |
| Expression | `Redundant_Type_Conversion` | Maintainability | Low | Reports explicit type conversions whose operand already has the target subtype. |
| Style | `Missing_Overriding_Indicator` | Maintainability | Medium | Reports primitive subprograms that override an inherited operation without the `overriding` keyword. |
| Exception handling | `Handler_Order` | Reliability | High | Reports a `when others` handler that precedes, and thereby shadows, a more specific handler in the same list. |
| Data flow | `Aliasing_Between_Parameters` | Reliability | High | Reports calls that pass the same object or component as two actual parameters when at least one corresponding formal is written. |
| SPARK | `Missing_Loop_Variant` | Maintainability | Medium | Reports loops with a `Loop_Invariant` pragma but no `Loop_Variant` pragma. |
| SPARK | `Known_Discriminant_Check_Failure` | Reliability | High | Reports accesses to a variant-part component that a statically known discriminant constraint provably excludes. |
| SPARK | `Potentially_Blocking_Operation` | Reliability | High | Reports entry calls, delay statements, and calls transitively reaching them from a protected operation. |
| Automotive | `No_Dynamic_Allocation` | Reliability | High | Reports allocators. |
| Automotive | `Restricted_Access_Type` | Reliability | High | Reports access-to-object type definitions. |
| Automotive | `No_Explicit_Dereference` | Reliability | High | Reports explicit `.all` dereferences. |
| Automotive | `No_Unchecked_Deallocation` | Reliability | High | Reports semantic instantiations of `Ada.Unchecked_Deallocation`. |
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
| Automotive | `Naming_Convention` | Maintainability | Low | Reports one-character identifiers except loop indices and enumeration literals. |
| Automotive | `No_Compiler_Extensions` | Maintainability | High | Reports implementation-defined pragmas, including extension-enabling pragmas. |
| Automotive | `No_Runtime_Check_Suppression` | Reliability | High | Reports `Suppress`, `Suppress_All`, and check policies that ignore or disable Ada run-time checks. |
| DO-178C support | `Missing_Requirement_Trace` | Reliability | High | Reports subprogram bodies without a nearby low-level requirement identifier. |
| DO-178C support | `Malformed_Requirement_Trace` | Maintainability | Medium | Reports requirement annotations with no identifier. |
| DO-178C support | `Suppression_Without_Rationale` | Maintainability | High | Reports analyzer suppressions that do not record a reviewable rationale. |

Run `adalang_analyzer -list-checks` to see the authoritative list together
with a description and guidance for every check.

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
`--format=json`/`--compliance-report`, which always include the full
per-obligation data regardless of verbosity.

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

The same state is used for two common Ada run-time proof obligations. Integer
initializations, assignments, and type conversions are compared with resolved
subtype bounds, and array subscripts are compared with the resolved index type
for each dimension. Findings are emitted only when the value's entire known
range lies outside the permitted range; unknown or partially overlapping
ranges remain silent.

Integer arithmetic is also checked against the resolved base type of the
operation. This models Ada's overflow check separately from the subtype check
performed by a later assignment and avoids reporting both obligations for the
same definitely overflowing expression.

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
preservation never feeds downstream proofs. Invariants after executable loop
statements, branched loop bodies, nested-loop preservation, variants, and
termination VCs remain `Unproved`. These fallbacks trade precision for
soundness and never create a speculative proof.

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
profile. It covers allocation and access use; unchecked deallocation; tasking,
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

See the [Automotive Ada Compliance Matrix](AUTOMOTIVE_ADA_COMPLIANCE_MATRIX.md)
for a non-normative rule-by-rule mapping to the Ada Reference Manual's Annex H
high-integrity restrictions and SPARK Reference Manual guidance, limitations,
and remaining compliance gaps.

### DO-178C verification-support profiles

Select a software level with:

```sh
./bin/adalang_analyzer --do178c=A -P adalang_analyzer.gpr
```

Levels A and B enable the strictest source, flow, exception, initialization,
coupling, traceability, and suppression-rationale checks. Level C retains the
high-confidence runtime, flow, and traceability checks without the additional
A/B coding restrictions. Level D enables only the core high-confidence defect
checks and does not imply source-code traceability objectives. Later
`-checks`, `+R`, and `-R` switches can refine any profile.

The selected profile and its external structural-coverage objective are
recorded in JSON and SARIF:

| Level | Recorded coverage objective |
|-------|-----------------------------|
| A | MC/DC |
| B | Decision coverage |
| C | Statement coverage |
| D | None |

AdaLang Analyzer does not measure structural coverage. Coverage data must come
from an appropriate target-aware coverage workflow such as GNATcoverage.

Associate a subprogram body with a low-level requirement by placing this
annotation on its declaration line or within the three immediately preceding
lines:

```ada
--  do-178c: req LLR-FLIGHT-CONTROL-042
procedure Update_Control_Surface is
begin
   ...
end Update_Control_Surface;
```

Rule suppressions used with the A/B profiles require an explicit rationale:

```ada
null;  --  adalang-analyzer: ignore Null_Statement -- rationale: empty state
```

Place `rationale:` on the suppression line. The analyzer currently associates
requirement annotations with bodies in the same source file; project-wide
requirements databases and test/coverage import remain separate lifecycle
evidence.

These profiles support verification activities; they do not determine or
claim DO-178C compliance. DO-178C also covers planning, requirements, design,
testing, configuration management, quality assurance, certification liaison,
and lifecycle evidence. Projects taking certification credit from analyzer
results must separately assess tool qualification under DO-330. See
[FAA AC 20-115D](https://www.faa.gov/regulations_policies/advisory_circulars/index.cfm/go/document.information/documentID/1032046).

### Compliance reporting

```sh
./bin/adalang_analyzer --do178c=A --compliance-report=do178c \
  --compliance-report-output=compliance.md -P adalang_analyzer.gpr

./bin/adalang_analyzer --automotive --compliance-report=iso26262 \
  --compliance-report-output=compliance.md -P adalang_analyzer.gpr
```

Writes a Markdown, per-objective evidence report to
`--compliance-report-output` (or standard output if omitted), for either
`do178c` (paired with a `--do178c=<level>` run) or `iso26262` (paired with an
`--automotive` run). For each objective it lists the mapped checks, whether
they were enabled this run, and this run's open and baselined findings
against them; it also lists every inline suppression recorded this run
together with its rationale, every finding matched against `--baseline`
(which currently carries no rationale of its own), and the verification
activities this analyzer does not automate at all (structural coverage,
requirements-based or dynamic testing, object-code or run-time-error proof
beyond the supported subset, tool qualification).

An unrecognized standard fails the invocation rather than silently producing
no report. Objective labels are AdaLang's own paraphrase: for `do178c`, of
publicly discussed DO-178C Annex A Table A-5 activities; for `iso26262`, of
the same general safety themes already summarized non-normatively in
[AUTOMOTIVE_ADA_COMPLIANCE_MATRIX.md](AUTOMOTIVE_ADA_COMPLIANCE_MATRIX.md).
Neither cites the respective standard's normative text or official
numbering, and the report states this. Like the profiles above, this report
is verification-support evidence, not a compliance determination.

## Requirements

- [Alire](https://alire.ada.dev/) and a GNAT Ada toolchain;
- optionally, the Alire `gnatprove` package for scalar VC discharge and
  GNATprove differential tests;
- macOS with the Apple Command Line Tools for the current development
  configuration;
- the dependencies declared in `alire.toml`, which Alire resolves during the
  build.

## Build

From the repository root:

```sh
alr build
```

The executable is produced under `bin/`.

Run the complete repository gate:

```sh
sh tests/run_all.sh
```

The gate builds the current sources and runs all regression, reporting,
quality, model, performance, and verification suites. Its differential stage
runs 16 clean and 5 deliberately broken units through GNATprove when that tool
is installed and reports an explicit skip otherwise.

## Usage

Enable every check for one or more Ada source files:

```sh
./bin/adalang_analyzer -checks='*' src/main.adb
```

Select individual checks or disable checks from a broader selection:

```sh
./bin/adalang_analyzer \
  -checks='*, -No_Pragma, -Null_Statement' src/*.adb
```

Checks can also be toggled with `+R<check>` and `-R<check>` switches:

```sh
./bin/adalang_analyzer \
  +RNo_Goto +RDivision_By_Zero src/main.adb
```

Analyze the sources declared by a GNAT project file instead of listing
files individually:

```sh
alr exec -- ./bin/adalang_analyzer -checks='*' -P adalang_analyzer.gpr
```

`-P<project>.gpr` and `-P <project>.gpr` are both accepted, and any file
names given on the command line are analyzed together with the project's
sources. Project files are evaluated with GPR2, including scenario variables,
`case` statements, naming rules, source exclusions, recursive source
directories, and project extension. The visible Ada sources of the root
project are analyzed. As with `gprbuild`, imported project files and the Ada
toolchain must be discoverable through the GPR environment. For an Alire
workspace, run the analyzer through `alr exec --` as above; otherwise configure
`GPR_PROJECT_PATH` and the GPR2 knowledge base for the target toolchain.

Set a scenario variable with `-X<name>=<value>` or `-X <name>=<value>`,
repeatable for more than one variable, the same as `gprbuild`. Without an
explicit `-X`, a scenario variable still falls back to its project-file
default or an OS environment variable of the same name; `-X` is how to
override either of those for one invocation, e.g. in a CI matrix that
analyzes the same project under more than one scenario:

```sh
./bin/adalang_analyzer -checks='*' -X BUILD_MODE=release -P adalang_analyzer.gpr
```

Useful options include:

```text
-h, --help       Show command help
-version         Show the version
-P<project>.gpr  Analyze the sources of a GNAT project file
-X<name>=<value> Set a project scenario variable (repeatable)
-list-checks     List all available checks
--recommended    Enable low-noise defect checks for routine local and CI use
--spark          Enable a proof-focused preset (later check switches refine it)
--verify         Classify bounded scalar proof obligations
--automotive     Enable the strict automotive Ada preset
--do178c=<level> Enable DO-178C verification support for level A, B, C, or D
-checks=<list>   Enable or disable a comma-separated set of checks
--format=<name>  Select text, JSON, or SARIF output (default: text)
--output=<file>  Write a JSON or SARIF report to a file
--baseline=<file>
                 Treat matching stable finding fingerprints as existing
--write-baseline=<file>
                 Write this run's finding fingerprints for later comparison
--compliance-report=<standard>
                 Write a per-objective evidence report ('do178c' or 'iso26262')
--compliance-report-output=<file>
                 Destination for --compliance-report (default: stdout)
-complexity-threshold=<n>
                 Set the Cyclomatic_Complexity limit (default: 10)
-nesting-threshold=<n>
                 Set the Deep_Nesting limit (default: 4)
-parameter-threshold=<n>
                 Set the Too_Many_Parameters limit (default: 6)
-line-length-threshold=<n>
                 Set the Long_Line limit (default: 120)
-generic-threshold=<n>
                 Set the Generic_Instantiation_Limit (default: 10)
-dependency-threshold=<n>
                 Set the Dependency_Limit (default: 20)
-v, -verbose     Print files as they are parsed; required in text format to
                 list per-proof-obligation detail lines
-q, -quiet       Suppress the final summary
--config=<file>  Use this config file instead of auto-discovery
--no-config      Disable auto-discovery of adalang_analyzer.cfg
--               Treat all remaining arguments as file names
```

The command exits unsuccessfully when it finds a violation or cannot process
the requested input, which makes it suitable for scripts and CI checks. A
finding that matches `--baseline` remains visible in JSON or SARIF output as an
existing result, but it does not contribute to the exit status. Fingerprints
exclude line and column numbers, so inserting unrelated lines does not turn an
existing finding into a new one.

For routine analysis, start with the recommended preset:

```sh
./bin/adalang_analyzer --recommended -P my_project.gpr
```

It enables defect-oriented control-flow, data-flow, handler, duplication,
known run-time failure, and unused-data checks. It intentionally excludes
coding-style rules, restricted-construct policies, mandatory SPARK contracts,
and DO-178C traceability rules. Select `--spark`, `--automotive`, or
`--do178c=<level>` when those stronger project policies actually apply.

### Project configuration file

Rather than reconstructing the same multi-flag invocation by hand on every
run, a team can check a config file into version control and let it be
picked up automatically. If a file named `adalang_analyzer.cfg` exists in
the current working directory, it is read before the real command line is
parsed. Its content is exactly the long-form flags described above, one or
more per line:

```text
# adalang_analyzer.cfg
--do178c=B
-checks=+Magic_Number,-No_Goto
-complexity-threshold=15
-P my_project.gpr
```

Blank lines and lines whose first non-blank character is `#` are comments,
the same convention used by `--baseline` files. There is no separate
key/value grammar: any flag the command line accepts also works here, so a
newly added flag needs no config-file-specific support.

The config file's flags are treated as if they were typed first on the
command line, and the real command-line flags are processed afterward. A
real flag therefore overrides whatever the config file set, exactly as two
occurrences of the same flag override each other in sequence today; it does
not merge with a preset. For example, a config file selecting individual
checks combined with `--spark` on the real command line does not run both
sets together, the same way giving `-checks=...` followed by `--spark` on
the command line alone would not.

Use `--config=<file>` to load a specific file instead of relying on
auto-discovery (an explicit path that does not exist is a hard error), or
`--no-config` to skip auto-discovery entirely and fall back to whatever the
real command line alone specifies.

For CI systems that consume SARIF:

```sh
./bin/adalang_analyzer -checks='*' --format=sarif \
  --output=adalang.sarif --baseline=adalang.baseline src/*.adb
```

JSON and SARIF reports include an `analysisConfiguration` manifest containing
the analyzer version, selected preset, exact enabled-rule set, configurable
thresholds, project and scenario inputs, config and baseline paths, analyzed
files, and the number of skipped checks. This records the effective
configuration after all config-file and command-line refinements; the preset
name alone is not treated as sufficient evidence.

Create or deliberately refresh the baseline after reviewing the complete
finding set:

```sh
./bin/adalang_analyzer -checks='*' \
  --write-baseline=adalang.baseline src/*.adb
```

Run the structured-output regression alongside the bug-finding suite:

```sh
sh tests/run_recommended.sh
sh tests/run_recommended_gate.sh
sh tests/run_quality_metrics.sh
sh tests/run_reporting.sh
sh tests/run_control_flow_graph_model.sh
sh tests/run_automotive.sh
sh tests/run_automotive_evidence.sh
sh tests/run_do178c.sh
sh tests/run_cli_robustness.sh
sh tests/run_config_file.sh
sh tests/run_circular_dependencies.sh
sh tests/run_performance_smoke.sh
```

The performance smoke test scans the analyzer's own sources with every check
and uses a deliberately generous 15-second default ceiling to catch accidental
algorithmic regressions rather than normal machine-to-machine variation.
Override it with `ADALANG_MAX_SMOKE_SECONDS` on controlled benchmark workers.

JSON reports include proof-obligation details alongside ordinary findings.
These are separate evidence channels: finding baselines affect violations but
do not suppress or alter proof obligations.

## Commercial Value & Professional Services

AdaLang Analyzer is developed and maintained by
[Spazio IT](https://spazioit.com/), a company with deep expertise in
safety-critical and high-integrity Ada/SPARK systems.

### Why Organizations Choose AdaLang Analyzer

- **Cost-effective daily static analysis** — fast, lightweight, and easy to
  integrate into CI pipelines, reducing reliance on expensive proprietary
  tools for routine checks.
- **Strong safety & certification focus** — designed with ASIL, DO-178C, and
  EN 50128 workflows in mind. Helps catch issues early that complicate formal
  verification with GNATprove.
- **SPARK readiness** — checks effective `SPARK_Mode`, `Global` access modes,
  inferred `Depends` relations, definite output initialization, and known
  contract failures before the more expensive proof stage.
- **Customizable & transparent** — fully open source (GPL), with clear rule
  classifications and remediation guidance. Easy to extend or integrate into
  your toolchain.

### Professional Services from Spazio IT

We offer commercial support and services around AdaLang Analyzer, including:

- **Enterprise support & maintenance contracts**
- **Custom rule development** tailored to your coding standards or
  certification needs
- **Tool qualification** assistance for DO-178C / ISO 26262 (TCL3) and
  similar standards
- **SPARK adoption consulting** — gap analysis, proof readiness reviews, and
  verification workflow optimization
- **Training workshops** on static analysis, formal methods, and best
  practices with Ada/SPARK

Whether you need a lightweight daily checker or full support for a
certification campaign, Spazio IT can help you maximize the value of AdaLang
Analyzer in your environment.

**Contact us** at [info@spazioit.com](mailto:info@spazioit.com) for a demo,
pilot project, or consultation.

## Contributing

Bug reports and focused pull requests are welcome. See
[CONTRIBUTING.md](CONTRIBUTING.md) for the basic contribution workflow.

## License

This project is distributed under the
[GNU General Public License, version 3 or later](LICENSE)
(`GPL-3.0-or-later`). Files inherited from AdaCore retain their original
copyright and license notices.

Libadalang is a separate dependency distributed under the Apache License 2.0
with LLVM Exceptions (`Apache-2.0 WITH LLVM-exception`). Its license does not
replace or alter this project's GPL license.
