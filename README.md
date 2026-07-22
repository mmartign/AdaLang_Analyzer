# adalang_analyzer

`adalang_analyzer` is an independent command-line static analysis tool for Ada
source code maintained by [Spazio IT](https://spazioit.com/). It parses Ada and
reports rule violations with source locations, explanations, and remediation
guidance.

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
| Exception handling | `Handler_Order` | Reliability | High | Reports a `when others` handler that precedes, and thereby shadows, a more specific handler in the same list. |
| Data flow | `Aliasing_Between_Parameters` | Reliability | High | Reports calls that pass the same object or component as two actual parameters when at least one corresponding formal is written. |
| SPARK | `Missing_Loop_Variant` | Maintainability | Medium | Reports loops with a `Loop_Invariant` pragma but no `Loop_Variant` pragma. |
| SPARK | `Known_Discriminant_Check_Failure` | Reliability | High | Reports accesses to a variant-part component that a statically known discriminant constraint provably excludes. |
| SPARK | `Potentially_Blocking_Operation` | Reliability | High | Reports entry calls and delay statements written directly in a protected procedure or function body. |

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
resolved to its one live alternative. `Potentially_Blocking_Operation` walks
a protected procedure or function body — not descending into a nested
subprogram — and reports a `delay` statement or a call resolving to an entry
declaration, both of which the Ravenscar and SPARK profiles forbid inside a
protected operation because they can block while the protected lock is held.

## Requirements

- [Alire](https://alire.ada.dev/) and a GNAT Ada toolchain;
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

Run the bug-finding regression suite after building:

```sh
sh tests/run_bug_findings.sh
```

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

Useful options include:

```text
-h, --help       Show command help
-version         Show the version
-P<project>.gpr  Analyze the sources of a GNAT project file
-list-checks     List all available checks
--spark          Enable a proof-focused preset (later check switches refine it)
-checks=<list>   Enable or disable a comma-separated set of checks
-complexity-threshold=<n>
                 Set the Cyclomatic_Complexity limit (default: 10)
-nesting-threshold=<n>
                 Set the Deep_Nesting limit (default: 4)
-parameter-threshold=<n>
                 Set the Too_Many_Parameters limit (default: 6)
-line-length-threshold=<n>
                 Set the Long_Line limit (default: 120)
-v, -verbose     Print files as they are parsed
-q, -quiet       Suppress the final summary
--               Treat all remaining arguments as file names
```

The command exits unsuccessfully when it finds a violation or cannot process
the requested input, which makes it suitable for scripts and CI checks.

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
