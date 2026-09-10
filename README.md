# AdaLang Analyzer

<div align="center">

### Ship safer Ada. Reach stronger verification sooner.

**A transparent, CI-ready static analyzer for ordinary Ada and SPARK-bound
codebases. Find defects, enforce engineering policy, and expose proof-readiness
gaps while they are still inexpensive to fix.**

[![CI](https://github.com/mmartign/AdaLang_Analyzer/actions/workflows/ci.yml/badge.svg)](https://github.com/mmartign/AdaLang_Analyzer/actions/workflows/ci.yml)
[![Version](https://img.shields.io/badge/version-1.5.0-5b4ee5.svg)](CHANGELOG.md)
[![Checks](https://img.shields.io/badge/checks-127-0f766e.svg)](https://mmartign.github.io/AdaLang_Analyzer/checks.html)
[![Docs](https://img.shields.io/badge/docs-site-1f6feb.svg)](https://mmartign.github.io/AdaLang_Analyzer/)
[![License: GPL-3.0-or-later](https://img.shields.io/badge/license-GPL--3.0--or--later-blue.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

[Quick start](#quick-start) · [Capabilities](#one-analyzer-four-high-value-workflows) ·
[Evidence](#evidence-you-can-inspect) · [Safety profiles](#4-safety-and-certification-support) ·
[Documentation](https://mmartign.github.io/AdaLang_Analyzer/) ·
[Commercial support](#commercial-support-from-spazio-it)

</div>

---

AdaLang Analyzer gives Ada teams a practical analysis layer between a compiler
and full formal verification. It works on ordinary Ada, including scoped or
partially complete source sets, and produces reviewable findings with source
locations, rule guidance, explanations, and evidence. When stronger assurance
is justified, its SPARK-readiness checks help teams spend proof effort on the
code that is ready for it.

Built on [Libadalang](https://github.com/AdaCore/libadalang) and maintained by
[Spazio IT](https://spazioit.com/), the analyzer combines **127 curated
checks**, bounded scalar verification, safety-oriented profiles, stable
baselines, and text/JSON/SARIF reporting in one open implementation.

## The business case

Defects found late in a high-integrity program are rarely local: they ripple
through reviews, traceability, tests, proof, and certification evidence.
AdaLang Analyzer moves useful feedback closer to the developer without asking
every file to be SPARK-ready first.

| Engineering pressure | What AdaLang Analyzer contributes |
| --- | --- |
| Expensive late-cycle rework | Finds known runtime failures, suspicious control/data flow, unsafe constructs, and maintainability risks during local development and CI. |
| Inconsistent coding-policy reviews | Turns selected project rules and thresholds into a repeatable, version-controlled quality gate. |
| Difficult SPARK adoption | Highlights contract, dependency, initialization, aliasing, and bounded-proof issues before a full GNATprove campaign. |
| Audit evidence scattered across tools | Emits JSON, SARIF, configuration manifests, stable baselines, and per-objective compliance-support reports. |
| Proprietary analysis that is hard to inspect | Ships its rules, evidence corpus, assurance boundary, and known limitations as reviewable source and documentation. |

## Quick start

Build with [Alire](https://alire.ada.dev/) and analyze a GNAT project with the
curated low-noise preset:

```sh
git clone https://github.com/mmartign/AdaLang_Analyzer.git
cd AdaLang_Analyzer
alr build
alr exec -- ./bin/adalang_analyzer --recommended -P my_project.gpr
```

Create a SARIF quality gate for CI:

```sh
alr exec -- ./bin/adalang_analyzer --recommended -P my_project.gpr \
  --format=sarif --output=adalang.sarif --baseline=adalang.baseline
```

The process exits unsuccessfully for new violations or invalid input. Findings
matched by a reviewed baseline remain visible in structured reports but do not
fail the run, allowing teams to adopt the analyzer incrementally instead of
stopping delivery for existing technical debt.

The [full flag, configuration-file, and output-format reference](https://mmartign.github.io/AdaLang_Analyzer/configuration.html)
lives in the documentation site.

## One analyzer, four high-value workflows

### 1. Daily defect detection

Use `--recommended` for a deliberately low-noise first pass over ordinary Ada.
It covers high-value control-flow, data-flow, exception, duplication,
known-runtime-failure, and unused-data checks without imposing a new style
guide on the team.

### 2. Enforceable engineering policy

Select any combination of 127 checks, tune complexity/nesting/parameter/line
length thresholds, and commit the configuration with the project. Every rule
has a reliability, security, or maintainability classification and a severity
that survives into JSON and SARIF. Browse the full
[checks catalogue](https://mmartign.github.io/AdaLang_Analyzer/checks.html).

### 3. A bridge into SPARK

Use `--spark` and `--verify` to identify missing or inconsistent `Global` and
`Depends` contracts, uninitialized outputs, aliasing risks, known contract or
runtime-check failures, and bounded scalar obligations. Results distinguish
`Proved_Safe`, `Definite_Error`, `Unproved`, `Unreachable`, and `Unsupported`
instead of turning an analysis boundary into a guess.

### 4. Safety and certification support

Use `--automotive` or `--do178c=<A|B|C|D>` for review profiles aimed at
high-integrity development. Generate Markdown or JSON evidence reports that
connect enabled checks, open/baselined findings, suppressions, and explicit
gaps to review objectives. See the
[DO-178C verification-support profiles](https://mmartign.github.io/AdaLang_Analyzer/do178c-profiles.html)
and [compliance reporting](https://mmartign.github.io/AdaLang_Analyzer/compliance-reporting.html).

These profiles support engineering and verification activities; they do not
certify ISO 26262, MISRA, AUTOSAR, or DO-178C compliance by themselves.

## Why teams choose AdaLang Analyzer

- **Useful before full project closure** — analyze ordinary Ada files or a
  scoped project slice when a whole-program proof workflow cannot yet start.
- **Conservative by design** — unsupported proof cases stay unsupported;
  individual safe results never become claims about an entire program.
- **Built for automation** — stable exit behavior, baselines, project scenario
  variables, config files, JSON, and SARIF make rollout practical in CI.
- **Evidence-rich results** — diagnostics can carry `why:` and `evidence:`
  details; structured reports preserve the exact effective configuration.
- **Fits existing quality infrastructure** — consume reports in code-scanning
  systems or publish them to SonarQube through
  [SonarAdaPlugin](https://github.com/mmartign/SonarAdaPlugin).
- **Open and commercially supportable** — inspect the implementation under
  GPL-3.0-or-later, or engage Spazio IT for integration, custom rules,
  qualification assistance, and long-term support.

## Evidence you can inspect

This project treats precision as a release artifact, not a marketing adjective.
Its regression and quality gates include a growing boundary-case corpus,
adversarial verification mutations, proof-path evidence, self-analysis, and
comparisons on independently authored Ada/SPARK projects.

Across **2,277 proof obligations** that AdaLang Analyzer and GNATprove could
both evaluate at the same location in five independently authored,
fully-proved corpora, the recorded comparisons contain:

| Observed result | Count |
| --- | ---: |
| AdaLang called safe where GNATprove did not prove safe | **0** |
| AdaLang called a definite error where GNATprove proved safe | **0** |

This is evidence of precision on AdaLang Analyzer's supported subset, not a
claim of GNATprove-equivalent coverage: AdaLang returns `Unproved` or
`Unsupported` substantially more often. Review the methodology, pinned
revisions, per-corpus results, and limitations in the
[benchmark suite](benchmarks/README.md), and the current release evidence in
[quality/](quality/README.md).

## A deliberate place in the toolchain

```text
Compiler feedback
      │
      ▼
AdaLang Analyzer
  coding policy · defect detection · bounded obligations · SPARK readiness
      │
      ├──► JSON / SARIF / SonarQube / CI quality gates
      │
      ▼
Selected critical SPARK components
      │
      ▼
GNATprove and project-specific verification / qualification activities
```

AdaLang Analyzer does not replace GNATprove, exhaustive whole-program defect
analysis, dynamic testing, coverage measurement, or a certification lifecycle.
`Proved_Safe` applies only to the reported obligation under its reported
assumptions. The binding claim vocabulary is in
[Positioning and approved claims](https://mmartign.github.io/AdaLang_Analyzer/positioning.html);
result semantics are in
[the assurance model](https://mmartign.github.io/AdaLang_Analyzer/assurance-model.html);
and the exact verification boundary is in the
[supported verification subset](https://mmartign.github.io/AdaLang_Analyzer/supported-verification-subset.html).

## Documentation

The full reference and assurance documentation is published as a searchable
site: **<https://mmartign.github.io/AdaLang_Analyzer/>**

- [Configuration and usage reference](https://mmartign.github.io/AdaLang_Analyzer/configuration.html)
  — every flag, the project configuration file, and output formats.
- [Checks catalogue](https://mmartign.github.io/AdaLang_Analyzer/checks.html)
  — all 127 checks with category, severity, and purpose.
- [Positioning and approved claims](https://mmartign.github.io/AdaLang_Analyzer/positioning.html),
  [assurance model](https://mmartign.github.io/AdaLang_Analyzer/assurance-model.html),
  [supported verification subset](https://mmartign.github.io/AdaLang_Analyzer/supported-verification-subset.html),
  [false-safe response policy](https://mmartign.github.io/AdaLang_Analyzer/false-safe-response.html).
- Safety & certification support:
  [DO-178C profiles](https://mmartign.github.io/AdaLang_Analyzer/do178c-profiles.html),
  [compliance reporting](https://mmartign.github.io/AdaLang_Analyzer/compliance-reporting.html),
  and the non-normative
  [automotive](https://mmartign.github.io/AdaLang_Analyzer/automotive-compliance-matrix.html),
  [DO-178C](https://mmartign.github.io/AdaLang_Analyzer/do178c-compliance-matrix.html),
  and [EN 50128](https://mmartign.github.io/AdaLang_Analyzer/en50128-rail-compliance-matrix.html)
  compliance matrices.
- [GNATcheck rule comparison](https://mmartign.github.io/AdaLang_Analyzer/gnatcheck-rule-comparison.html)
  and [benchmark & quality evidence](https://mmartign.github.io/AdaLang_Analyzer/evidence.html).

The site is built with [mdBook](https://rust-lang.github.io/mdBook/) from
[`docs/`](docs/); see [`CONTRIBUTING.md`](CONTRIBUTING.md) for how to preview
it locally. Project history is in [`CHANGELOG.md`](CHANGELOG.md).

## Independence and lineage

AdaLang Analyzer is built on AdaCore's open-source Libadalang semantic engine
and derives from the open-source `libadalang-tools` codebase. It is an
independent project maintained solely by Spazio IT and is not endorsed,
sponsored, or officially supported by AdaCore. “Libadalang” and “AdaCore” are
trademarks of AdaCore.

## Requirements

- [Alire](https://alire.ada.dev/) and a GNAT Ada toolchain;
- optionally, the Alire `gnatprove` package for scalar VC discharge and
  GNATprove differential tests;
- macOS or Linux; CI builds and tests both platforms on every change;
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
runs 18 clean and 9 deliberately broken units through GNATprove when that tool
is installed and reports an explicit skip otherwise. A separate seeded
mutation campaign guards all 12 enumerated obligation families against
false-safe regressions. A proof-path evidence gate maps 23 abstract, flow,
contract-transfer, and external-prover routes to every one of the 17 current
`Proved_Safe` producer sites, including adversarial and solver-boundary cases.

## Commercial support from Spazio IT

Open source is the starting point; successful adoption is the outcome.
[Spazio IT](https://spazioit.com/) helps high-integrity teams turn AdaLang
Analyzer into a dependable part of their engineering lifecycle.

| Engagement | Typical outcome |
| --- | --- |
| Pilot and rollout | Evaluate the analyzer on representative code, tune a low-noise policy, establish a baseline, and integrate CI reporting. |
| Enterprise support | Obtain a maintained support path, issue triage, upgrade guidance, and continuity for long-lived programs. |
| Custom rule development | Encode company, program, or review-board policies directly in the analyzer and its evidence gates. |
| SPARK adoption | Assess proof readiness, prioritize components, improve contracts, and design the handoff into GNATprove. |
| Qualification assistance | Build project-specific plans and evidence for DO-330, DO-178C, ISO 26262 TCL3, and related assurance contexts. |
| Training | Equip developers and reviewers to use static analysis, Ada/SPARK contracts, and formal methods effectively. |

For organizations that prefer a ready-to-run quality platform, AdaLang
Analyzer and SonarAdaPlugin are also available pre-integrated with SonarQube
in Spazio IT's
[SAFe Toolset](https://spazioit.com/pages_en/sol_inf_en/code_quality_en/safe-toolset-en/),
covering C, C++, and Ada workflows for aerospace, defense, automotive,
railway, and industrial programs.

> **Bring a representative codebase. Leave with a concrete adoption plan.**
>
> [Request a demo, pilot, or technical consultation](mailto:info@spazioit.com?subject=AdaLang%20Analyzer%20inquiry)

## Contributing

Bug reports, precision feedback, and focused pull requests are welcome,
including from outside contributors. See [CONTRIBUTING.md](CONTRIBUTING.md)
for the basic contribution workflow and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
for community expectations. Suspected security vulnerabilities should be
reported per [SECURITY.md](SECURITY.md) rather than as a public issue.

## License

This project is distributed under the
[GNU General Public License, version 3 or later](LICENSE)
(`GPL-3.0-or-later`). Files inherited from AdaCore retain their original
copyright and license notices.

Libadalang is a separate dependency distributed under the Apache License 2.0
with LLVM Exceptions (`Apache-2.0 WITH LLVM-exception`). Its license does not
replace or alter this project's GPL license.
