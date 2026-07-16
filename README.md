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
| Assignment | `Self_Assignment` | Reliability | Medium | Reports assignments whose target and value are the same expression. |
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
`Dead_Store` follows resolved simple-object assignments in source order,
`Overwritten_Assignment` stays within one statement list, and the case checks
compare statically evaluable integer literals and ranges. These boundaries keep
findings predictable without requiring whole-program control-flow analysis.
`No_Recursion` and `Function_Side_Effect` are likewise scoped conservatively:
`No_Recursion` only recognizes calls written with an explicit call syntax, and
`Function_Side_Effect` only flags assignments through a simple identifier
destination, to avoid false positives from unresolved or complex constructs.

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
./bin/adalang_analyzer -checks='*' -P adalang_analyzer.gpr
```

`-P<project>.gpr` and `-P <project>.gpr` are both accepted, and any file
names given on the command line are analyzed together with the project's
sources. This is a lightweight, best-effort project reader rather than a
full GPR implementation: it understands literal `for Source_Dirs use (...)`,
`for Source_Files use (...)`, `for Excluded_Source_Files use (...)` (and its
`Locally_Removed_Files` alias) attributes, recursive source directories
written with a trailing `**`, and project extension via `extends "..."`
(the extending project's sources take priority over same-named files
inherited from the base project). Scenario variables, `case` statements,
and sources pulled in through `with` of other project files are not
evaluated.

Useful options include:

```text
-h, --help       Show command help
-version         Show the version
-P<project>.gpr  Analyze the sources of a GNAT project file
-list-checks     List all available checks
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
