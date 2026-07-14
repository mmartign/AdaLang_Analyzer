# adalang_analyzer

`adalang_analyzer` is a command-line static analysis tool for Ada source code.
It uses [Libadalang](https://github.com/AdaCore/libadalang) to parse Ada and
report rule violations with source locations, explanations, and remediation
guidance.

The project is maintained by [Spazio IT](https://spazioit.com/) and is derived
from AdaCore's `libadalang-tools` codebase.

## Checks

The analyzer currently detects:

- discouraged constructs: `No_Goto`, `No_Abort`, `No_Raise`, `No_Exit`,
  `No_Label`, `No_Pragma`, and `No_Access_To_Subp_Def`;
- constant conditions and unreachable code or branches;
- statically detectable division by zero and reversed ranges;
- self-assignments, repeated operands, and duplicate conditions;
- null statements and empty exception handlers.

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

Spazio IT distributes this project under the
[GNU Affero General Public License v3.0](LICENSE) (`AGPL-3.0-only`). Files
inherited from upstream retain their existing copyright and license notices;
GPLv3-covered material may be combined with AGPLv3-covered material under
section 13 of the licenses.
