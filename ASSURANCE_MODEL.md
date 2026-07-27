# AdaLang Analyzer Assurance Model

## Purpose

This document defines what conclusions may be drawn from AdaLang Analyzer
results. It separates current finding semantics from the proposed
verification-obligation model so that future features cannot silently
strengthen product claims without supplying the necessary evidence.

The core rule is:

> Absence of an AdaLang finding is not evidence that the corresponding defect
> or run-time error is absent unless an implemented verification mode
> explicitly reports that obligation as proved safe.

## Scope of an analysis result

An AdaLang result is meaningful only with its analysis context:

- Analyzer version and build.
- Enabled checks and selected profile.
- Input files and project scenario variables.
- Project and unit-provider configuration.
- Target and compiler assumptions, where relevant.
- Suppressions and accepted baselines.
- Diagnostics about files, units, nodes, or constructs that were skipped.

Changing any of these inputs can change the result. A baseline suppresses the
effect of an accepted finding on the exit status; it does not establish that
the underlying code is safe.

## Current assurance classes

Every current result belongs to one of the following conceptual classes.
These classes document strength of evidence; they are not yet serialized as a
field in every output format.

### Policy finding

A policy finding means that the source matches the documented syntactic or
semantic condition for an enabled rule.

Examples include restricted constructs, complexity thresholds, naming rules,
and mandatory review of representation clauses.

It establishes:

- The enabled rule's matching condition was observed at the reported source
  location.

It does not establish:

- That the program is defective.
- That code without the finding complies with an external standard.
- That all instances were found outside the rule's documented scope.

### Defect finding

A defect finding means that the analyzer identified a suspicious or erroneous
condition using the rule's documented analysis.

Examples include dead stores, swallowed exceptions, contradictory
conditions, and selected call or aliasing problems.

It establishes:

- The implementation found evidence satisfying the rule's reporting
  condition.

It does not establish:

- Exhaustive detection of that defect category.
- Feasibility of every reported path unless the rule explicitly guarantees
  it.
- Absence of the defect when no finding is emitted.

### Known-failure finding

A `Known_*_Failure` finding means that the current abstract state was precise
enough to establish failure for the values represented at that program point.
Current examples cover selected preconditions, postconditions, assertions,
range checks, index checks, overflow checks, and discriminant checks.

It establishes:

- The analyzer derived a state that satisfies the check's documented
  definite-failure reporting condition.

It does not establish:

- That every concrete execution reaches the operation.
- That every possible failure is found.
- That a silent operation is safe.
- That partially overlapping or unknown values were proved safe.
- A formal proof equivalent to GNATprove or Polyspace.

### Readiness finding

A readiness finding identifies a construct, missing contract, contract
mismatch, data-flow issue, or unsupported pattern likely to obstruct SPARK
analysis or a project assurance objective.

It establishes:

- A documented readiness condition was observed.

It does not establish:

- SPARK legality.
- Successful GNATprove flow analysis or proof.
- Compliance with an assurance standard.

## Current analysis foundations

The current implementation combines several analyses with different
precision boundaries:

- Libadalang parsing and semantic resolution.
- Local AST pattern and property checks.
- Intraprocedural data-flow analyses.
- A bounded flow state containing exact integer values, Boolean values, and
  non-relational integer ranges.
- Branch-sensitive interpretation of selected structured statements.
- One-pass conservative loop interpretation after invalidating modified
  state.
- Contract lookup and limited transfer of simple precondition and
  postcondition facts.
- Fixed-point propagation of a small number of monotone interprocedural
  effects, such as may-raise and may-block.
- Separate SPARK dependency inference with conservative fallbacks.

These mechanisms support useful findings but do not constitute exhaustive
path exploration or verification-condition generation.

## Conservative fallback and skipped analysis

The implementation uses several fallback strategies when it lacks sufficient
semantic information:

- Values become unknown.
- Individual bindings or the complete flow state are invalidated.
- Precision-dependent findings are suppressed.
- Unsupported statement forms clear tracked state.
- Some bodies or blocks with exception handlers are skipped by the
  flow-sensitive interpreter.
- Fixed-size internal structures may stop recording additional facts.

These strategies are intended to avoid deriving findings from stale facts.
They also create false negatives. Consequently, a clean current analysis
cannot be treated as a safety proof.

Skipped or degraded analysis should be visible in verbose diagnostics and,
where it affects an assurance claim, in structured output. Silent degradation
is acceptable only for ordinary best-effort finding modes, never for a future
verification mode.

## Finding outcomes versus verification outcomes

Current rules answer questions such as:

> Can this analysis establish a violation here?

A verifier must instead answer:

> For every represented execution reaching this operation, can the selected
> error be shown to be absent?

Those questions require different result models. Findings and proof
obligations must therefore remain separate, even when they refer to the same
source operation.

For example, the current analyzer can report division by zero when the
denominator is known to be zero. A future obligation for the same division
would classify whether zero is impossible, inevitable, possible, or unknown.

## Verification-obligation model

The data types, stable-ID generation, and per-run registry described in this
section are implemented in `Adalang_Analyzer.Proof_Obligations`. Enabled
checks enumerate their applicable division, integer-overflow, range, index,
selected discriminant, assertion, precondition, and postcondition operations.
Existing known-failure evidence produces `Definite_Error`; other enumerated
outcomes produce `Unproved`. A later flow-sensitive observation can refine an
earlier `Unproved` result to `Definite_Error`, but cannot downgrade it.

This is deliberately not an exhaustive verification mode. `Unproved` includes
both genuinely indeterminate operations and operations that may look safe but
for which the current assurance model does not permit a `Proved_Safe` claim.
Unsupported constructs, skipped exception-bearing bodies, unresolved semantic
boundaries, and operations outside enabled checks still limit coverage.
Reports label this boundary as
`enumerated outcomes in current analysis scope; not exhaustive`. SARIF
proof-obligation reporting is also not yet connected.

Each obligation should contain at least:

- A stable identifier.
- Obligation kind.
- Source location and associated operation.
- Supported-language classification.
- Assumptions and contracts used.
- Relevant abstract values or ranges.
- Result status.
- Analysis method and precision level.
- Explanation, including the source of imprecision.
- Analyzer version and configuration fingerprint.

### Proposed statuses

#### `Proved_Safe`

The analyzer established, for the documented supported semantics and
assumptions, that the selected error cannot occur on any represented
non-erroneous execution reaching the operation.

This status may be emitted only when:

- The operation and all relevant predecessor behavior are within the
  documented supported subset.
- No assurance-relevant analysis was silently skipped.
- Calls and global effects have sound models.
- The underlying abstract transfer and decision procedure support the claim.
- Validation tests cover the obligation kind and language constructs.

`Proved_Safe` is property-specific. It does not prove the entire statement,
subprogram, or program correct.

#### `Definite_Error`

The analyzer established that the selected error occurs whenever the
represented reachable operation executes, under the documented assumptions.

If the analysis only establishes that an error occurs for some values or
paths, the status must be `Unproved`, accompanied by the potential-error
evidence. It must not be called definite.

#### `Unproved`

The analyzer could not establish absence or inevitability of the selected
error. This includes:

- A mixture of safe and unsafe represented values.
- Loss of precision from joins, loops, calls, or widening.
- Timeout or resource limits.
- Missing environmental constraints.

`Unproved` is not a defect verdict. It is a review obligation and must explain
why the result remained inconclusive.

#### `Unreachable`

The analyzer established that no represented execution reaches the
operation. This status depends on the same scope and assumptions as
`Proved_Safe`; it is not a general statement that the source can never execute
under another build or environment.

#### `Unsupported`

The obligation depends on language semantics or program behavior outside the
implemented assurance boundary. Examples may include unsupported aliasing,
tasking, dispatching, exceptional control flow, or target-specific behavior.

An unsupported obligation must never be silently converted to
`Proved_Safe`.

## Initial verification boundary

A credible first verification mode should be deliberately narrow:

- Scalar integer and Boolean objects.
- Structured sequential control flow.
- Integer division, overflow, subtype range, and array index obligations.
- Assertions and simple preconditions and postconditions.
- Statically modeled arrays and subtype bounds.
- Loops whose behavior can be covered by fixed-point analysis or explicit
  supported invariants.

The initial excluded or explicitly unsupported set should include:

- General access types and points-to reasoning.
- Tasking, protected objects, and concurrent interference.
- Dispatching and class-wide behavior.
- Floating-point proof.
- Unchecked conversion and target-dependent representation.
- Unmodeled exception paths.
- Calls without sound effect summaries.

The supported subset must be defined semantically and tested by construct. A
source-level profile name alone is not enough.

## Evidence required before a proof claim

Before enabling `Proved_Safe` in a release, the project should have:

1. A written supported-language and property specification.
2. A control-flow model covering every supported transfer of control.
3. Sound abstract transfer definitions for the claimed properties.
4. Explicit models for calls, globals, initialization, and exceptional exits.
5. Termination and widening arguments for fixed-point computation.
6. Positive, negative, inconclusive, unreachable, and unsupported tests.
7. Mutation and seeded-defect tests designed to detect false-safe results.
8. Differential evaluation against GNATprove or another independent verifier
   on a compatible corpus.
9. Stable obligation identifiers and complete structured reporting.
10. A documented review process for any discovered false-safe result.

Testing cannot prove the analyzer sound, but it is necessary evidence that the
implementation conforms to its specified analysis.

## Confidence hierarchy

The intended hierarchy is:

```text
Policy/quality finding
        |
        v
Best-effort semantic defect finding
        |
        v
Known-failure finding
        |
        v
Explicit verification obligation
        |
        +-- Proved_Safe
        +-- Definite_Error
        +-- Unproved
        +-- Unreachable
        `-- Unsupported
```

Moving downward in this hierarchy requires stronger implementation evidence
and more explicit reporting. Enabling more checks does not by itself move a
result to a stronger assurance class.

## Standards and certification

Automotive and DO-178C profiles select checks that can support project
verification activities. They do not:

- Determine standard applicability.
- Establish compliance.
- Replace requirements, testing, coverage, configuration management, or
  quality-assurance evidence.
- Qualify AdaLang Analyzer as a verification tool.

Projects seeking certification credit must define how analyzer outputs are
used, assess the consequences of tool errors, and perform any qualification
activities required by the applicable standard.

## Change control

Any change that strengthens a result from a finding to a proof claim must
update:

- This assurance model.
- The supported-subset specification.
- Result schemas and user documentation.
- Regression and differential tests.
- Versioning or compatibility notes where existing result interpretation
  changes.

Implementation changes may improve precision by converting `Unproved` results
to `Proved_Safe` or `Definite_Error`. They must not hide unsupported behavior
or weaken the conditions required for a proof status.
