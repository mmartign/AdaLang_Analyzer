# Configuration and usage reference

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
alr exec -- ./bin/adalang_analyzer -checks='*' -X BUILD_MODE=release -P adalang_analyzer.gpr
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
--compliance-report-format=<markdown|json>
                 Representation for --compliance-report (default: markdown)
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
alr exec -- ./bin/adalang_analyzer --recommended -P my_project.gpr
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
key/value grammar: ordinary analyzer flags and positional arguments use the
same syntax as the command line. Tokens are separated by spaces or tabs;
shell-style quoting and escaping are not supported. The options that select
configuration behavior, `--config` and `--no-config`, must be given on the
real command line because they are processed before the configuration file
is loaded.

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

### Output formats

`--format=<name>` selects `text` (default, human-readable), `json`, or
`sarif`. JSON and SARIF carry the same underlying data — ordinary findings,
`--verify` proof obligations and their summary, and an
`analysisConfiguration` manifest recording exactly what ran (version,
preset, enabled rules, thresholds, analyzed files) — while SARIF additionally
follows the schema CI code-scanning integrations expect. Only JSON/SARIF, or
plain text run with `-v`, include full per-obligation proof detail; plain
text without `-v` prints only the aggregate summary.

For CI systems that consume SARIF:

```sh
./bin/adalang_analyzer -checks='*' --format=sarif \
  --output=adalang.sarif --baseline=adalang.baseline src/*.adb
```

SonarQube users can consume these results directly through
[SonarAdaPlugin](https://github.com/mmartign/SonarAdaPlugin), a SonarQube
Server extension for Ada that runs AdaLang Analyzer (or imports its JSON
report) and publishes findings as SonarQube issues alongside AdaControl and
GNATtest results.

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
sh tests/run_verification.sh
sh tests/run_verification_mutations.sh
sh tests/run_proof_path_evidence.sh
sh tests/run_gnatprove_differential.sh
sh tests/run_performance_smoke.sh
```

The performance smoke test scans the analyzer's own sources with every check
and uses a deliberately generous 15-second default ceiling to catch accidental
algorithmic regressions rather than normal machine-to-machine variation.
Override it with `ADALANG_MAX_SMOKE_SECONDS` on controlled benchmark workers.

JSON reports include proof-obligation details alongside ordinary findings.
These are separate evidence channels: finding baselines affect violations but
do not suppress or alter proof obligations.
