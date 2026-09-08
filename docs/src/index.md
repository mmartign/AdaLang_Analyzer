# Introduction

AdaLang Analyzer gives Ada teams a practical analysis layer between a compiler
and full formal verification. It works on ordinary Ada, including scoped or
partially complete source sets, and produces reviewable findings with source
locations, rule guidance, explanations, and evidence. When stronger assurance
is justified, its SPARK-readiness checks help teams spend proof effort on the
code that is ready for it.

It is built on [Libadalang](https://github.com/AdaCore/libadalang) and
maintained by [Spazio IT](https://spazioit.com/), and combines curated
checks, bounded scalar verification, safety-oriented profiles, stable
baselines, and text/JSON/SARIF reporting in one open implementation.

## What this site covers

This is the reference and assurance documentation:

- [Configuration and usage reference](configuration.md) — every flag, the
  project configuration file, and the output formats.
- [Checks](checks.md) — the full catalogue of checks with category,
  severity, and purpose.
- **Verification & assurance** — the binding claim vocabulary
  ([positioning](positioning.md)), result semantics
  ([assurance model](assurance-model.md)), the exact
  [verification boundary](supported-verification-subset.md), and the
  [false-safe response policy](false-safe-response.md).
- **Safety & certification support** — the
  [DO-178C profiles](do178c-profiles.md),
  [compliance reporting](compliance-reporting.md), and the non-normative
  automotive / DO-178C / EN 50128 compliance matrices.
- **Comparisons & evidence** — the
  [GNATcheck rule comparison](gnatcheck-rule-comparison.md) and pointers to
  the [benchmark and quality evidence](evidence.md).

## Where to start

New to the tool? The
[project README](https://github.com/mmartign/AdaLang_Analyzer#readme) has the
quick start, build instructions, and the high-level pitch. Come back here for
the details of what each mode does and what its results mean.
