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
loop-variant operations. `--verify` adds the length check of an array
given to a target, and three obligations about a subprogram as a whole:
termination, where SPARK requires it, and the data dependencies and flow
dependencies its `Global` and `Depends` aspects state.

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

## Verification boundary

The exact boundary of `--verify` -- the obligations it raises, what each is
proved from, the expressions and control flow it follows, and what is
outside it -- is specified in one place, the
[supported verification subset](supported-verification-subset.md). It is
not repeated here, so that the two documents cannot drift apart.

Three properties of that boundary decide what a result may be taken to
mean:

- **An incomplete graph proves nothing.** The verifier works on a
  control-flow graph that represents entry, normal exit, and exceptional
  exit separately. A transfer the graph cannot represent is an
  `Unsupported_Node` and makes the graph incomplete, and no `Proved_Safe`
  status may be derived from an incomplete graph.
- **Exceptional flow is over-approximated.** Executable expressions and
  declaration elaboration that may perform an Ada run-time check have
  conservative implicit exceptional edges. A handler dispatcher connects to
  every handler that could conservatively apply; a catch-all handler
  prevents direct propagation from that dispatcher, while exceptions raised
  inside a handler propagate to the enclosing scope.
- **A loop is never assumed to converge.** The verifier consumes a complete
  graph with a terminating work list. A bound that a loop keeps moving is
  widened and then given up, and a final iteration guard conservatively
  havocs the state rather than assuming convergence. For a supported
  leading invariant, preservation is checked in a separate generic
  one-iteration VC, and a second pass uses the invariant as a loop summary
  only after initialization and preservation both discharge.

The supported subset must be defined semantically and tested by construct. A
source-level profile name alone is not enough.

## Verification evidence

The statuses above rest on gates that run as part of the repository gate
(`sh tests/run_all.sh`):

- **Regression corpus** (`tests/run_verification.sh`). Positive,
  definite-error, inconclusive, unreachable, unsupported, loop,
  initialization, solver-unavailable, solver-proved, solver-refuted and
  VC-unsupported cases, with the outcome and provenance of each obligation
  pinned.
- **GNATprove differential** (`tests/run_gnatprove_differential.sh`). On a
  clean corpus, GNATprove must analyze every unit and prove every generated
  check, and an AdaLang `Definite_Error` or `Unsupported` result is
  rejected. AdaLang may remain `Unproved` there, where GNATprove's stronger
  VC generation and automated provers succeed. A broken corpus provides the
  opposite oracle: GNATprove must retain at least one failed check and may
  not skip any unit. The gate reports an explicit skip when GNATprove is
  not installed.
- **Verification mutations** (`tests/run_verification_mutations.sh`).
  Seeded defects or conservative boundary cases guard every enumerated
  obligation family; none may become `Proved_Safe` unexpectedly.
- **Seeded defects** (`tests/run_seeded_defects.sh`). Whole probe programs
  under `tests/seeded_defects/`, in which every marked check fails or holds
  by construction. A `Proved_Safe` or `Unreachable` result on a marked
  defect is rejected, and the outcome of every marked line is pinned.
- **Proof-path evidence** (`tests/run_proof_path_evidence.sh`). Every
  source-level `Record_Proved_Safe` producer is inventoried and mapped to
  method-specific routes. The routes are organised by obligation kind and
  method, and go on to the sub-boundaries within them: individual
  operators and scalar types, branch and case joins, exception-handler
  edges, discriminant checks, joins beyond the first conditional, composite
  and access values, contracts on a separate spec, bounds and membership,
  and the objects that always hold a value. Each route has positive and
  adversarial evidence, while solver-dependent routes also exercise
  unsupported translation and unavailable solvers. The gate compares the
  manifest with stable `proof-path` source tags, so a new unreviewed proof
  producer fails the repository gate.

The manifests behind these gates are in `quality/`, and
[`quality/README.md`](https://github.com/mmartign/AdaLang_Analyzer/blob/main/quality/README.md)
describes each. The current size of each corpus is stated once, in the
"Build" section of the
[project README](https://github.com/mmartign/AdaLang_Analyzer#build).
Confirmed false-safe results are governed by the release-blocking response
process in the [false-safe response policy](false-safe-response.md).

Before broadening the supported subset or making a stronger product claim,
the project still needs:

1. Proof paths for what the supported subset still leaves `Unproved` or
   `Unsupported` by construction; the
   [supported verification subset](supported-verification-subset.md) names
   each of them.
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
