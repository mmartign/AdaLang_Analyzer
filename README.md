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

| Category | Check | Purpose |
|----------|-------|---------|
| Restricted construct | `No_Goto` | Reports `goto` statements. |
| Restricted construct | `No_Abort` | Reports asynchronous task aborts. |
| Restricted construct | `No_Raise` | Reports explicit `raise` statements. |
| Restricted construct | `No_Exit` | Reports loop `exit` statements. |
| Restricted construct | `No_Label` | Reports statement labels. |
| Restricted construct | `No_Pragma` | Reports pragmas. |
| Restricted construct | `No_Access_To_Subp_Def` | Reports access-to-subprogram type definitions. |
| Safety | `No_Unchecked_Conversion` | Reports instantiations of `Ada.Unchecked_Conversion`. |
| Numerical safety | `Floating_Equality` | Reports `=` and `/=` applied to floating-point operands. |
| Maintainability | `Magic_Number` | Reports unexplained numeric literals other than 0, 1, and -1 outside named constant declarations. |
| Data flow | `Unused_Parameter` | Reports subprogram parameters that are never referenced. |
| Data flow | `Dead_Store` | Reports assignments whose value is never read later in the subprogram. |
| Data flow | `Overwritten_Assignment` | Reports assignments overwritten before an intervening read. |
| Scope | `Shadowed_Declaration` | Reports local objects hiding declarations in enclosing subprograms. |
| Case analysis | `Unreachable_Case_Alternative` | Reports choices wholly covered by an earlier case alternative. |
| Case analysis | `Overlapping_Case_Ranges` | Reports intersecting statically evaluable integer choices. |
| Control flow | `Infinite_Loop` | Reports unconditional loops without an exit, return, or raise. |
| Expression | `Duplicate_Boolean_Operand` | Reports repeated boolean operands and double negations. |
| Exception handling | `Exception_Swallowed` | Reports empty or null-only `when others` handlers. |
| Complexity | `Cyclomatic_Complexity` | Reports subprograms exceeding the configured complexity threshold. |
| Control flow | `Constant_Condition` | Reports conditions that are statically always true or false. |
| Control flow | `Unreachable_Code` | Reports statements following an unconditional transfer of control. |
| Arithmetic | `Division_By_Zero` | Reports statically detectable division, `mod`, or `rem` by zero. |
| Arithmetic | `Reversed_Range` | Reports static ranges whose lower bound exceeds their upper bound. |
| Assignment | `Self_Assignment` | Reports assignments whose target and value are the same expression. |
| Expression | `Same_Operand` | Reports suspicious binary expressions with identical operands. |
| Conditional | `Duplicate_Condition` | Reports repeated conditions in an `if`/`elsif` chain. |
| Style | `Null_Statement` | Reports executable `null` statements. |
| Exception handling | `Empty_Exception_Handler` | Reports handlers containing no substantive statements. |
| Control flow | `Unreachable_Branch` | Reports branches excluded by earlier static conditions. |
| Conditional | `Contradictory_Condition` | Reports expressions such as `X and not X` or `X or not X`. |
| Conditional | `Identical_Branches` | Reports adjacent conditional branches with identical bodies. |
| Assignment | `Repeated_Statement` | Reports identical consecutive assignments. |
| Expression | `Ineffective_Operation` | Reports operations containing an identity operand that has no effect. |
| Expression | `Constant_Result_Operation` | Reports operations forced to a constant by an absorbing operand. |
| Control flow | `Empty_Loop` | Reports loops containing no substantive statements. |

Run `adalang_analyzer -list-checks` to see the authoritative list together
with a description and guidance for every check.

The data-flow checks are intraprocedural and deliberately conservative.
`Dead_Store` follows resolved simple-object assignments in source order,
`Overwritten_Assignment` stays within one statement list, and the case checks
compare statically evaluable integer literals and ranges. These boundaries keep
findings predictable without requiring whole-program control-flow analysis.

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
