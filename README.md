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

Useful options include:

```text
-h, --help       Show command help
-version         Show the version
-list-checks     List all available checks
-checks=<list>   Enable or disable a comma-separated set of checks
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
