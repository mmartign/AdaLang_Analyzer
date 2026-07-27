# AdaLang Analyzer Positioning

## Purpose

AdaLang Analyzer is an independent, Libadalang-based static analysis tool for
Ada. It combines selectable coding-policy checks, semantic defect detection,
lightweight flow analysis, SPARK-readiness checks, and CI-oriented reporting.

The concise product position is:

> AdaLang Analyzer is a lightweight quality and safety analyzer for ordinary
> Ada that helps teams find defects, enforce project policies, and prepare
> selected code for stronger verification.

AdaLang Analyzer is currently a static analyzer, not a formal prover. A clean
run means that none of the enabled checks emitted a finding for the analyzed
inputs. It does not mean that the program is free of defects or run-time
errors.

This document describes the position of the current `0.1.0-dev` codebase. It
does not promise features that are only proposed in the roadmap.

## Intended users

AdaLang Analyzer is intended for teams that:

- Maintain Ada code that is not entirely within the SPARK subset.
- Want a command-line quality gate with text, JSON, or SARIF results.
- Need project-specific restrictions or safety-oriented review profiles.
- Want early feedback on data flow, contracts, and likely obstacles to proof.
- Need to select critical components for later analysis with GNATprove or
  another verification tool.

It can be used during local development and CI, but its output is supporting
evidence. Any certification credit or tool qualification argument remains a
project responsibility.

## Current capability

The analyzer currently provides:

- Syntactic and semantic coding-policy checks.
- Maintainability, reliability, and security classifications.
- Intraprocedural data-flow and control-flow findings.
- A bounded abstract state for exact integer values, Boolean values, and
  integer ranges.
- Known-failure checks for selected assertions, contracts, and Ada run-time
  checks.
- Separate text and JSON proof-obligation evidence for definite and unproved
  outcomes in the current analysis scope, explicitly labeled as
  non-exhaustive.
- SPARK-readiness analysis for `SPARK_Mode`, `Global`, `Depends`, output
  initialization, aliasing, loop variants, and selected blocking operations.
- Automotive and DO-178C verification-support profiles with explicit
  limitations.
- GNAT project processing, scenario variables, baselines, and text, JSON, and
  SARIF output.

The analyzer does not currently provide:

- Exhaustive analysis of every execution path.
- Verification-condition generation or SMT/theorem-prover integration.
- A proof that enabled run-time checks cannot fail.
- Complete points-to, alias, exception, dispatching, or concurrency analysis.
- Dynamic test generation or test execution.
- Structural coverage measurement.
- A general external rule-definition language.
- Tool-qualification or certification artifacts.

## Relationship to other tools

The products below have different purposes. Comparisons are about workflow
position, not equivalence of check names or raw check counts.

| Tool | Primary purpose | Relationship to AdaLang Analyzer |
| --- | --- | --- |
| GNATcheck | Enforce syntactic and semantic Ada coding rules, including custom LKQL rules | Closest direct overlap. AdaLang has curated built-in policies and some deeper flow-sensitive checks, but does not match GNATcheck's maturity or rule extensibility. |
| GNATtest | Generate AUnit test skeletons, harnesses, and drivers | Complementary. AdaLang neither generates nor executes tests. |
| GNATprove | Check SPARK legality, analyze information flow, and prove selected run-time and contract properties | Downstream verification tool. AdaLang can identify readiness issues and known failures but is not a substitute for GNATprove. |
| Polyspace Bug Finder | Find probable C/C++ defects and coding-rule violations without exhaustive proof | Closest conceptual product category, but it serves a different language and is substantially more mature and broad. |
| Polyspace Code Prover | Classify supported C/C++ operations by exhaustive run-time-error analysis | An aspirational model for obligation reporting, not a current competitor. |
| Polyspace Client/Server for Ada | Use abstract interpretation to verify selected Ada run-time properties | The relevant Polyspace comparison for Ada. AdaLang does not currently offer an equivalent absence-of-error guarantee. |

Official descriptions of these tools are available in the
[GNATcheck Reference Manual](https://docs.adacore.com/live/wave/lkql/html/gnatcheck_rm/gnatcheck_rm/getting_started.html),
[GNATtest User's Guide](https://docs.adacore.com/gnatcoverage-docs/html/gnattest/gnattest_part.html),
[SPARK User's Guide](https://docs.adacore.com/spark2014-docs/html/ug/en/source/how_to_run_gnatprove.html),
[Polyspace Bug Finder and Code Prover comparison](https://www.mathworks.com/help/bugfinder/gs/use-bug-finder-and-code-prover.html),
and [Polyspace Products for Ada](https://www.mathworks.com/products/polyspace-ada.html).

### GNATcheck

GNATcheck is the strongest direct comparator for rule enforcement. It has an
established predefined-rule catalog and an LKQL mechanism for adding rules
without rebuilding the tool. AdaLang Analyzer should not claim general
GNATcheck replacement until it has demonstrated comparable project handling,
rule coverage, configurability, scalability, and diagnostic stability.

AdaLang's defensible distinction is a curated combination of rules,
flow-sensitive defect findings, safety profiles, and SPARK-readiness feedback
in one inspectable implementation.

### GNATtest

GNATtest addresses dynamic testing infrastructure. It is not a static-analysis
competitor. A future integration could use analyzer-derived boundary values or
counterexamples as test inputs, but test generation is outside AdaLang's
current purpose.

### GNATprove

GNATprove performs analyses that carry formal verification meaning for their
documented SPARK scope. AdaLang's similarly named checks report mismatches or
failures that its bounded analyses can establish. They do not reproduce
GNATprove's proof engine.

The intended workflow is:

```text
ordinary Ada
    |
    v
AdaLang Analyzer
  - coding policy
  - likely and definite defects
  - safety-profile findings
  - SPARK-readiness findings
    |
    v
selected critical SPARK components
    |
    v
GNATprove
  - flow analysis
  - run-time-error proof
  - contract proof
```

### Polyspace products

Polyspace Bug Finder and Code Prover primarily target C/C++. The direct Ada
verification comparison is Polyspace Client/Server for Ada.

AdaLang resembles a bug finder in its current reporting objective: produce
actionable findings without claiming exhaustive verification. Polyspace's
red, orange, green, and gray Code Prover classification is useful inspiration
for a future AdaLang verification mode, but AdaLang does not currently emit
equivalent proof statuses.

## Differentiation

AdaLang should compete on:

- Low-friction analysis of ordinary Ada, including code not yet in SPARK.
- A curated bridge from coding policy to flow analysis and proof readiness.
- Transparent implementation and diagnostics.
- CI-friendly, stable, reviewable output.
- Safety-oriented profiles that explicitly distinguish automated findings
  from project and certification evidence.
- Extensibility through normal Ada development and professional rule
  implementation.

AdaLang should not compete on:

- Claims of exhaustive proof.
- Raw rule-count comparisons across different languages.
- Replacing unit testing.
- Certification by tool invocation.
- Equivalence to established commercial verification engines.

## Approved claim vocabulary

The following descriptions accurately characterize the current product:

- "Static analyzer for Ada."
- "Coding-policy and semantic defect checker."
- "Flow-sensitive checks for selected properties."
- "Reports known assertion, contract, and run-time-check failures."
- "Supports SPARK-readiness assessment."
- "Provides automotive and DO-178C verification-support profiles."
- "Suitable for integration into CI."

The following claims must not be made for the current product:

- "Proves the code safe."
- "Proves absence of run-time errors."
- "Exhaustively checks all execution paths."
- "Zero false negatives."
- "Equivalent to GNATprove or Polyspace."
- "Ensures MISRA, AUTOSAR, DO-178C, ISO 26262, or EN 50128 compliance."
- "Qualified verification tool."

Claims such as "sound," "complete," "proved," or "formally verified" require a
documented property, supported language subset, assumptions, analysis method,
and validation argument under the assurance model.

## Strategic direction

The recommended direction is to retain the existing analyzer and add a
bounded verification mode for selected scalar run-time properties. That mode
should report every supported operation as proved safe, definite error,
unproved, unreachable, or unsupported. It must remain separate from ordinary
rule findings.

This direction positions AdaLang between rule checking and full formal proof:
useful on normal Ada, explicit about uncertainty, and able to escalate
critical code to GNATprove or Polyspace for Ada.
