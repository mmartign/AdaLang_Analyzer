# AdaLang Analyzer Assurance Model

## Purpose

This document defines what conclusions may be drawn from AdaLang Analyzer
results. It separates ordinary finding semantics from the bounded
verification-obligation model so features cannot silently strengthen product
claims without supplying the necessary evidence.

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

The implementation combines several analyses with different precision
boundaries:

- Libadalang parsing and semantic resolution.
- Local AST pattern and property checks.
- Intraprocedural data-flow analyses.
- A dynamically sized flow state containing exact integer values, Boolean
  values, initialization state, and non-relational integer ranges.
- Branch-sensitive interpretation of selected structured statements.
- A separate verification interpreter with work-list fixed-point propagation
  and interval widening at loop headers.
- A scalar SMT-LIB verification-condition backend requiring matching CVC5 and
  Z3 UNSAT results before accepting an external proof or refutation.
- A conservative symbolic CFG state carrying substitutions and path
  assumptions through straight-line code and branch edges.
- Contract lookup and limited transfer of simple precondition and
  postcondition facts.
- Fixed-point propagation of monotone interprocedural effects: may-raise,
  may-block, formal reads/writes, and direct or transitive nonlocal writes.
- Conservative all-path recognition of simple formal initialization on every
  normal return, consumed only for complete resolved call boundaries.
- Separate SPARK dependency inference with conservative fallbacks.

These mechanisms support useful findings but do not constitute exhaustive
path exploration or verification-condition generation.

## Conservative fallback and skipped analysis

Ordinary finding mode uses several best-effort fallback strategies when it
lacks sufficient semantic information:

- Values become unknown.
- Individual bindings or the complete flow state are invalidated.
- Precision-dependent findings are suppressed.
- Unsupported statement forms clear tracked state.
- Some bodies or blocks with exception handlers are skipped by the
  flow-sensitive interpreter.

These strategies are intended to avoid deriving findings from stale facts.
They also create false negatives. Consequently, a clean current analysis
cannot be treated as a safety proof.

Verification mode uses a stricter rule: an incomplete control-flow graph or
unsupported semantic boundary classifies affected obligations as
`Unsupported`. Loss of abstract precision within the supported boundary
produces `Unproved`. Neither case may silently produce `Proved_Safe`.

## Finding outcomes versus verification outcomes

Current rules answer questions such as:

> Can this analysis establish a violation here?

A verifier must instead answer:

> For every represented execution reaching this operation, can the selected
> error be shown to be absent?

Those questions require different result models. Findings and proof
obligations must therefore remain separate, even when they refer to the same
source operation.

For example, the analyzer can report division by zero when the denominator is
known to be zero. `--verify` additionally classifies the corresponding
obligation as safe, erroneous, inconclusive, unreachable, or unsupported.

## Verification-obligation model

`Adalang_Analyzer.Proof_Obligations` implements the data types, stable-ID
generation, and per-run registry. Enabled checks enumerate applicable
division, integer-overflow, range, index, selected discriminant,
initialization, assertion, precondition, postcondition, loop-invariant, and
loop-variant operations.

Without `--verify`, known-failure evidence produces `Definite_Error` and other
enumerated outcomes produce `Unproved`. With `--verify`, the CFG fixed-point
interpreter may additionally produce `Proved_Safe`, `Unreachable`, and
`Unsupported`. Overlapping passes are combined conservatively so a later
unsupported or reachable result cannot leave an earlier false-safe result in
the registry.

This remains deliberately bounded verification, not exhaustive Ada
verification. Structured text, JSON, and SARIF reports expose the boundary,
including unsupported-translation reason codes, blocking expressions, and
expression-function inline paths where available.

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

### Statuses

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

## Implemented verification boundary

The `--verify` boundary is deliberately narrow:

- Scalar integer and Boolean objects.
- Structured sequential control flow.
- Integer division, overflow, subtype range, and array index obligations.
- Scalar initialization obligations.
- Assertions and simple preconditions and postconditions.
- Statically modeled arrays and subtype bounds.
- Loops analyzed by work-list fixed-point iteration with interval widening,
  plus inductive initialization/preservation VCs and invariant summaries for
  leading invariants over straight-line scalar loop bodies.
- Calls whose analyzed bodies have complete conservative state-effect
  summaries, plus resolved SPARK calls with explicit global effects and
  structurally non-aliased simple writable actuals for relational contract
  transfer.
- Side-effect-free scalar obligations over initialized integer and Boolean
  objects, including assertions, contracts, selected run-time checks, and
  leading loop invariants, with `+`, `-`, `*`, comparisons, equality, and
  Boolean connectives.
- Relational entry preconditions, branch-local predicates, straight-line
  scalar assignments, simple actual-to-formal precondition substitution, and
  identical symbolic values that reach a join from every predecessor.
- Relational facts carried across a loop and into its exit when every leading
  invariant is proved initially and after one generic iteration.

### Control-flow and abstract interpretation

`Adalang_Analyzer.Control_Flow_Graph` now builds a reusable control-flow graph
for the sequential statement subset. It represents entry, normal exit, and
exceptional exit separately, and includes:

- Sequential statement and declaration elaboration order.
- `if`/`elsif`/`else` and `case` alternatives.
- `while`, `for`, and unconditional loops, including back and exit edges.
- Unnamed `exit` and `exit when`, return, explicit raise, and re-raise.
- Nested begin/declare blocks and conservative exception-handler dispatch.
- Conservative implicit exceptional edges for executable expressions and
  declaration elaboration that may perform an Ada run-time check.

The exceptional graph is intentionally an over-approximation. A handler
dispatcher connects to every handler that could conservatively apply; a
catch-all handler prevents direct propagation from that dispatcher, while
exceptions raised inside a handler propagate to the enclosing scope.

Unsupported transfers such as `goto`, extended return, tasking statements,
and named exits are represented by `Unsupported_Node` and make the graph
incomplete. No `Proved_Safe` status may be derived from an incomplete graph.
The verifier consumes a complete graph with a terminating work list. After
repeated growth at a loop header, moving interval bounds widen to infinity;
a final iteration guard conservatively havocs the state rather than assuming
convergence. For a supported leading invariant, preservation is checked in a
separate generic one-iteration VC. A second pass uses the invariant as a loop
summary only after initialization and preservation both discharge.

The excluded or explicitly unsupported set includes:

- General access types and points-to reasoning.
- Tasking, protected objects, and concurrent interference.
- Dispatching and class-wide behavior.
- Floating-point proof.
- Unchecked conversion and target-dependent representation.
- Unmodeled exception paths.
- Calls without sound effect summaries or with unsupported writable aliasing.
- VC translations for exponentiation, aggregates, modular conversions,
  statement-bodied, impure, or dispatching calls, division/remainder without
  a provably nonzero divisor, and expressions whose Ada semantics are not yet
  encoded exactly.
- Conflicting symbolic values at joins, exceptional edges, and calls without
  relational postconditions.
- Loop invariants placed after executable statements, preservation paths with
  branches, nested loops, calls, or unsupported transfers, and loop
  termination/variant VCs.

The supported subset must be defined semantically and tested by construct. A
source-level profile name alone is not enough.

## Verification evidence and remaining work

The regression corpus includes positive, definite-error, inconclusive,
unreachable, unsupported, loop, modular-call, initialization, more-than-64
binding, solver-unavailable, solver-proved, solver-refuted, and
VC-unsupported cases, plus assignment-chain, branch-predicate, merge,
call-havoc, relational pre/postcondition, and loop-cutoff symbolic cases.
The loop corpus also includes a relational invariant that proves a
subprogram postcondition and a deliberately unpreserved invariant that must
leave the postcondition unproved.
`tests/run_gnatprove_differential.sh` also runs a compatible corpus through
GNATprove when GNATprove is installed and explicitly reports a skip when it is
not. The clean differential corpus currently contains 17 units, including
dedicated arithmetic, conditional, modular-call, array, loop, and relational
run-time-check cases. An eight-unit broken corpus provides the opposite oracle:
GNATprove must retain at least one failed check and may not skip any unit. The
differential gate requires GNATprove to analyze every clean-corpus unit and
prove every generated check, and rejects an AdaLang `Definite_Error` or
`Unsupported` result on that clean corpus. It deliberately allows AdaLang to
remain `Unproved` where GNATprove's stronger VC generation and automated
provers succeed. `tests/run_verification_mutations.sh` independently guards
all 12 enumerated obligation families with seeded defects or conservative
boundary cases; none may become `Proved_Safe` unexpectedly.

The exact current proof boundary is specified in
`SUPPORTED_VERIFICATION_SUBSET.md`. Confirmed false-safe results are governed
by the release-blocking response process in `FALSE_SAFE_RESPONSE.md`.

Before broadening the supported subset or making a stronger product claim,
the project still needs:

1. Expansion of the seeded mutation campaign beyond its current one-or-more
   cases per obligation family to every proof-producing semantic boundary.
2. A larger routinely executed differential corpus beyond the current clean
   and broken units.
3. Broader unsupported-provenance coverage for the remaining expression and
   control-flow classes.
4. Independent review and versioned approval of the supported-subset
   specification before stronger product claims are made.

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
