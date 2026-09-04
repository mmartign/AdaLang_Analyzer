# EN 50128 Rail Compliance Matrix

## Status and intended use

This matrix describes the checks enabled by the current `--automotive`
preset and relates them to the safety-oriented Ada language subset defined
by SPARK and to the high-integrity restrictions annex of the Ada Reference
Manual, organized under CENELEC EN 50128:2011 ("Railway applications --
Communication, signalling and processing systems -- Software requirements
for railway control and protection systems") technique vocabulary:
structured and modular programming, strong typing, defensive programming,
control-flow and data-flow analysis, and boundary value analysis, among
others.

It is the same 74-rule `--automotive` preset already described in
[AUTOMOTIVE_ADA_COMPLIANCE_MATRIX.md](AUTOMOTIVE_ADA_COMPLIANCE_MATRIX.md),
re-partitioned under a different, EN-50128-flavored set of section
headings rather than a second, independently derived rule selection: both
standards converge on the same restricted, deterministic, strongly-typed
Ada subset and the same static analysis techniques (control-flow analysis,
data-flow analysis, boundary value analysis) as safety-relevant practice.

It is a non-normative engineering aid. It is **not**:

- An EN 50128 Annex A conformance matrix, or a claim that any check
  implements a specific EN 50128 table entry, clause, or technique
  recommendation (HR/R/M/NR) to the letter.
- A SPARK Reference Manual conformance matrix.
- A substitute for GNATprove, a licensed copy of EN 50128, or a qualified/
  certified toolchain.
- Evidence that a clean analysis proves the absence of a defect.
- Tool-classification (EN 50128 Clause 6.7, T1/T2/T3), tool-qualification,
  compiler-validation, or target-validation evidence.
- A Software Integrity Level (SIL) assessment. EN 50128 defines SIL 0-4
  with per-technique recommendations that vary by level; this matrix and
  the underlying `--automotive` preset are flat and unleveled, the same
  design already used for ISO 26262 in this project (see
  `AUTOMOTIVE_ADA_COMPLIANCE_MATRIX.md`) -- a project must independently
  decide which of the checks below are mandatory, highly recommended, or
  merely applicable at its required SIL.

The comparison baseline is the same open-access Ada/SPARK material
`AUTOMOTIVE_ADA_COMPLIANCE_MATRIX.md` uses -- the **Ada Reference Manual,
Annex H, "High Integrity Systems"** and the **SPARK Reference Manual** /
**SPARK User's Guide** -- not EN 50128 itself, which is a paywalled
CENELEC standard. No EN 50128 clause, table, or technique-identifier
number is cited anywhere in this document; the section headings below are
AdaLang's own paraphrase of publicly discussed EN 50128 technique
categories (structured programming, defensive programming, static
analysis, and so on), not a reproduction of the standard's normative text
or numbering. A project that needs a clause-by-clause EN 50128 mapping
must build it separately against its own licensed copy of the standard;
this document does not attempt it, and a clean `--automotive` run is not
evidence toward it.

The authoritative preset is `Enable_Automotive_Preset` in
`src/adalang_analyzer-cli.adb`; the objective grouping below is
`EN_50128_Objectives` in `src/adalang_analyzer-compliance_mapping.adb`,
generated as a report via `--compliance-report=en50128`. It currently
enables 74 checks.

## How to read the matrix

The alignment labels measure similarity of safety intent, not standards
coverage, and carry the same meaning as in
`AUTOMOTIVE_ADA_COMPLIANCE_MATRIX.md`:

- **Restriction** — the check enforces, or closely mirrors, a specific Ada
  Reference Manual rule.
- **SPARK** — the check enforces a SPARK subset legality rule, or addresses
  a concern SPARK's flow analysis or proof engine would otherwise raise.
- **Practice** — the check encodes a general high-integrity coding
  practice; good discipline, not itself a normative Annex H restriction
  identifier or SPARK Reference Manual rule.

None of the three labels means sound, complete, qualified, or SPARK-verified.
The limitations column is part of every mapping and must not be omitted
from an assessment.

## Preset rule matrix

Rules are grouped into the same ten categories `EN_50128_Objectives`
reports, each phrased as an EN 50128 Annex A technique family. Every one of
the 74 `--automotive` rules appears in exactly one category below.

### Structured and modular programming (15 rules)

| AdaLang check | Safety objective | Related Ada RM / SPARK guidance | Alignment | Important limitation or complementary evidence |
|---|---|---|---|---|
| `No_Goto` | Keep control flow structured and locally reviewable. | SPARK subset: `goto` statements are excluded from the SPARK language subset. | SPARK | Prohibits all Ada `goto` statements; does not assess other forms of control-flow complexity. |
| `No_Label` | Keep control flow structured and avoid vestigial jump targets. | General coding practice; closely related to `No_Goto`. | Practice | Detects Ada label declarations (`<<Name>>`); it does not evaluate whether any particular use is otherwise justified. |
| `No_Multiple_Return` | Keep subprogram exit points singular and easy to audit. | General coding practice; single-entry/single-exit discipline behind structured programming. | Practice | Counts explicit `return` statements per subprogram body; it does not evaluate whether multiple returns are already well-isolated. |
| `No_Abort` | Avoid asynchronous interruption at unpredictable program points. | Ada RM Annex H restriction identifier `No_Abort_Statements` (D.7). | Restriction | Covers Ada task abort, not platform interrupts, signals, or cancellation implemented outside Ada syntax. |
| `No_Raise` | Avoid explicit exceptional transfers of control. | SPARK verification: an explicit `raise` requires proof that the raise point is unreachable, or an explicit exceptional-contract. | SPARK | Covers explicit `raise`; implicit language-defined exceptions and exceptions raised by callees need separate analysis. |
| `No_Access_To_Subp_Def` | Keep call targets statically identifiable. | Ada RM Annex H restriction identifier `No_Access_Subprograms` (D.7). | Restriction | Detects access-to-subprogram type definitions; imported callbacks and other dynamic call mechanisms require review. |
| `No_Recursion` | Keep stack usage and call behavior bounded and analyzable. | Ada RM Annex H restriction identifier `No_Recursion` (D.7). | Restriction | Detects direct recursion; mutually recursive call cycles require a whole-program call-graph assessment. |
| `Non_Short_Circuit_Condition` | Prevent unintended evaluation and side effects in conditions. | General coding practice; relates to SPARK's requirement that expression evaluation be free of order-dependent side effects. | Practice | Applies to selected controlling conditions; not a complete expression side-effect or evaluation-order analysis. |
| `No_Tasking` | Avoid unbounded scheduling and synchronization complexity. | Ada RM Annex H restriction identifier `No_Tasking` (D.7). | Restriction | Detects Ada task declarations; interrupts, runtime-created threads, foreign concurrency need review. |
| `No_Rendezvous` | Avoid blocking task-entry synchronization. | Ravenscar tasking profile (Ada RM D.13). | Restriction | Covers entries and accept statements; other blocking protocols handled only where separately modeled. |
| `No_Select` | Avoid timing-dependent and asynchronous selection. | Ravenscar tasking profile (D.13) and Annex H restriction identifier `No_Select_Statements` (D.7). | Restriction | Covers Ada select forms; external event multiplexing and runtime services are not assessed. |
| `No_Requeue` | Keep entry queue behavior and control transfer explicit. | Ravenscar tasking profile (D.13) and Annex H restriction identifier `No_Requeue_Statements` (D.7). | Restriction | Applies to Ada requeue statements only. |
| `No_Asynchronous_Transfer` | Avoid interruption of normal execution at difficult-to-review points. | Ravenscar tasking profile (D.13). | Restriction | Covers asynchronous select/abortable parts; hardware interrupts and foreign cancellation require system-level controls. |
| `No_Dispatching_Call` | Keep runtime call targets bounded and reviewable. | Ada RM Annex H restriction identifier `No_Dispatch` (D.7). | Restriction | Detects semantically resolved dispatching and access-to-subprogram calls; unresolved or imported dispatch mechanisms require review. |
| `No_Classwide_Type` | Prevent open-ended sets of runtime types. | Relates to Annex H restriction identifier `No_Dispatch` (D.7). | Restriction | Applies to uses of `T'Class`; not a complete object-oriented design or hierarchy review. |

### Strong typing and storage discipline (8 rules)

| AdaLang check | Safety objective | Related Ada RM / SPARK guidance | Alignment | Important limitation or complementary evidence |
|---|---|---|---|---|
| `No_Unchecked_Conversion` | Prevent representation reinterpretation that bypasses the type system. | Ada RM 13.12.1 `pragma Restrictions (No_Dependence => Ada.Unchecked_Conversion)`. | Restriction | Detects semantic instantiations of `Ada.Unchecked_Conversion`; interfacing code needs separate review. |
| `No_Unchecked_Access` | Prevent an accessibility-bypassing access value from outliving its designated object. | Ada RM Annex H restriction identifier `No_Unchecked_Access` (D.7). | Restriction | Detects every use of `'Unchecked_Access`; other access-safety concerns remain separate. |
| `No_Dynamic_Allocation` | Keep memory consumption, allocation failure, and execution time bounded. | Ada RM Annex H restriction identifier `No_Allocators` (D.7). | Restriction | Detects Ada allocators; custom pools, imported allocators, container internals need project controls. |
| `Restricted_Access_Type` | Reduce aliasing, ownership, lifetime, and nullability hazards. | Combines Annex H restriction identifiers `No_Unchecked_Access`, `No_Local_Allocators`, `No_Anonymous_Allocators` (D.7) with SPARK's ownership model. | Restriction | Prohibits a broad class of Ada access-to-object definitions; access values from libraries/interfaces need separate control. |
| `No_Explicit_Dereference` | Avoid access checks and obscure object identity at dereference sites. | SPARK's ownership-based access-type model. | SPARK | Covers explicit `.all`; implicit dereference, interfacing, and library abstractions need additional assessment. |
| `No_Unchecked_Deallocation` | Prevent dangling references, double release, and use after free. | Ada RM 13.12.1 `pragma Restrictions (No_Dependence => Ada.Unchecked_Deallocation)`. | Restriction | Detects semantic instantiations of the unchecked facility; foreign deallocators outside its scope. |
| `Aliasing_Between_Parameters` | Prevent ambiguous updates through aliased actual parameters. | SPARK legality rule against aliasing between formal parameters. | SPARK | Detects the same object/component passed to selected writable formals; general points-to analysis is not provided. |
| `No_Controlled_Type` | Avoid hidden initialization, adjustment, and finalization control flow. | SPARK legality rule: `Ada.Finalization` controlled types are excluded from the SPARK subset. | SPARK | Detects derivation from Ada controlled types; other implicit finalization needs assessment. |

### Defensive programming: initialization and data flow (7 rules)

| AdaLang check | Safety objective | Related Ada RM / SPARK guidance | Alignment | Important limitation or complementary evidence |
|---|---|---|---|---|
| `Complete_Initialization` | Require explicit initial values for objects and record components. | SPARK's default full-initialization policy (Bronze level). | SPARK | Not proof that the chosen value is valid or that later reads are initialized. |
| `Uninitialized_Read` | Detect scalar locals whose first use is a read. | SPARK flow analysis: use-before-initialization is a core Bronze-level diagnostic. | SPARK | Limited to supported scalar local flow; arrays, records, aliases, calls need stronger analysis. |
| `Uninitialized_Output` | Ensure outputs are defined on every normal return path. | SPARK flow analysis: every mode-out global/parameter fully initialized (Bronze level). | SPARK | Intraprocedural normal-return analysis; exceptional termination limits the conclusion. |
| `Dead_Store` | Detect values assigned but never used. | SPARK flow analysis: Bronze-level "statement has no effect" diagnostics. | SPARK | Intraprocedural; aliasing, calls, exceptional paths can reduce precision. |
| `Overwritten_Assignment` | Detect values overwritten before use. | SPARK flow analysis: Bronze-level ineffective-assignment diagnostics. | SPARK | Intraprocedural and conservative; not a complete all-path def-use proof. |
| `Shadowed_Declaration` | Prevent confusing reuse of identifiers in nested scopes. | General high-integrity coding practice. | Practice | Focuses on declarations hiding enclosing subprogram declarations. |
| `Function_Side_Effect` | Make state changes explicit in interfaces and call sites. | SPARK legality rule: a SPARK function must not have side effects on global state. | SPARK | Detects assignments to visible external state; effects through aliases or unknown calls may escape analysis. |

### Boundary value and scalar run-time-error classes (12 rules)

| AdaLang check | Safety objective | Related Ada RM / SPARK guidance | Alignment | Important limitation or complementary evidence |
|---|---|---|---|---|
| `Floating_Equality` | Avoid fragile equality decisions on floating-point results. | General numeric-verification practice; SPARK/GNATprove floating-point proof support is limited. | Practice | Flags equality/inequality on floating operands; not numerical stability or error-bound evidence. |
| `Division_By_Zero` | Prevent erroneous division, remainder, and modulus operations. | SPARK/GNATprove division-check verification condition (Gold level). | SPARK | Reports statically detectable zero divisors; clean result does not prove every dynamic divisor nonzero. |
| `Reversed_Range` | Prevent invalid or accidentally null ranges. | SPARK/GNATprove range-check verification condition (Gold level). | SPARK | Covers statically evaluable reversed ranges; dynamic bounds need further evidence. |
| `Self_Assignment` | Detect ineffective or mistaken assignments. | General coding practice. | Practice | Covers the same object through simple renames; deeper alias equivalence is outside the rule. |
| `Contradictory_Condition` | Detect Boolean expressions that cannot have the intended result. | General coding practice; informally overlaps with proof-engine satisfiability diagnostics. | Practice | Recognizes selected contradictory forms; not a general satisfiability proof. |
| `Known_Precondition_Failure` | Prevent calls known to violate their contracts. | SPARK/GNATprove precondition verification condition (Gold level). | SPARK | Reports only preconditions shown false by the bounded abstract state. |
| `Known_Postcondition_Failure` | Detect implementations known to violate declared results. | SPARK/GNATprove postcondition verification condition (Gold level). | SPARK | Reports only postconditions shown false in the supported subset. |
| `Known_Assertion_Failure` | Detect safety assumptions known not to hold. | SPARK/GNATprove assertion verification condition (Gold level). | SPARK | Covers supported assertion forms when statically false. |
| `Known_Range_Check_Failure` | Prevent values known to violate subtype bounds. | SPARK/GNATprove range-check verification condition (Gold level). | SPARK | Finds provable failures in supported assignments/initializations/conversions. |
| `Known_Index_Check_Failure` | Prevent array accesses known to be out of bounds. | SPARK/GNATprove index-check verification condition (Gold level). | SPARK | Reports provably invalid supported indices; not an exhaustive bounds proof. |
| `Known_Overflow_Failure` | Prevent integer operations known to exceed their base type. | SPARK/GNATprove overflow-check verification condition (Gold level). | SPARK | Reports provable overflow in the supported scalar model. |
| `Known_Discriminant_Check_Failure` | Prevent accesses known to select an absent variant component. | SPARK/GNATprove discriminant-check verification condition (Gold level). | SPARK | Supports statically known literal or enumeration discriminants only. |

### Control-flow and data-flow analysis (7 rules)

| AdaLang check | Safety objective | Related Ada RM / SPARK guidance | Alignment | Important limitation or complementary evidence |
|---|---|---|---|---|
| `Infinite_Loop` | Require intentional and reviewable loop termination behavior. | Relates to SPARK's `Loop_Variant` termination-evidence requirement. | Practice | Detects a syntactic class of unconditional loops; does not prove general termination. |
| `Constant_Condition` | Expose invariant decisions and accidentally disabled behavior. | General coding practice; GNATprove emits related diagnostics for some cases. | Practice | Reports statically evident constants; more complex semantic constants can remain undetected. |
| `Unreachable_Code` | Remove code that cannot execute and may conceal mistakes. | General coding practice; GNATprove's flow analysis emits related diagnostics. | Practice | Primarily detects statements after unconditional transfers; not exhaustive reachability analysis. |
| `Unreachable_Branch` | Expose conditional behavior that cannot execute. | General coding practice; GNATprove flow analysis emits related diagnostics. | Practice | Detects branches excluded by supported static conditions. |
| `Unreachable_Case_Alternative` | Prevent dead or incorrectly specified case choices. | General coding practice; informally overlaps with GNATprove flow/proof diagnostics. | Practice | Covers statically dominated choices. |
| `Overlapping_Case_Ranges` | Keep selection alternatives mutually exclusive and reviewable. | General coding practice. | Practice | Applies to statically evaluable integer choices. |
| `Missing_Loop_Variant` | Require termination evidence for annotated proof loops. | SPARK `Loop_Variant` aspect, used by GNATprove to prove loop termination. | SPARK | Applies only when a loop already has a `Loop_Invariant`. |

### Fault detection and exception handling (4 rules)

| AdaLang check | Safety objective | Related Ada RM / SPARK guidance | Alignment | Important limitation or complementary evidence |
|---|---|---|---|---|
| `Exception_Swallowed` | Prevent broad exception handlers from silently discarding failures. | General high-integrity practice; a handler that exists but discards the failure. | Practice | Detects empty or null-only `when others` handlers; logging/recovery adequacy needs review. |
| `Exception_Propagation` | Contain failure paths at explicit interface boundaries. | Ada RM Annex H restriction identifier `No_Exception_Propagation` (D.7, H.4). | Restriction | Uses conservative summaries of explicit exceptions. |
| `Potentially_Blocking_Operation` | Avoid blocking while holding protected synchronization state. | Ada RM 9.5.1's definition of a potentially blocking operation. | Restriction | Covers selected direct and transitively summarized blocking operations; scheduling/WCET evidence remain external. |
| `Library_Level_Initialization` | Avoid hidden, fallible, or order-dependent elaboration work. | Ada RM 10.2 elaboration-order rules. | Restriction | Reports calls in library-level initializers; complete elaboration-order correctness needs other evidence. |

### Formal specification and information flow (6 rules)

| AdaLang check | Safety objective | Related Ada RM / SPARK guidance | Alignment | Important limitation or complementary evidence |
|---|---|---|---|---|
| `SPARK_Mode` | Prevent silent, unreviewed departure from the analyzable SPARK subset. | The `SPARK_Mode` aspect/pragma is the language-defined switch between full Ada and SPARK. | SPARK | Detects regions that explicitly set `SPARK_Mode => Off`; code never brought into SPARK is not reported. |
| `Missing_Global_Contract` | Require declared global effects for every subprogram that has them. | SPARK `Global` aspect completeness rule (Bronze level). | SPARK | Subprograms with no global access need no contract and are not reported. |
| `Global_Contract_Mismatch` | Ensure declared global effects match implementation behavior. | SPARK `Global` aspect legality and flow-analysis rule (Bronze level). | SPARK | Requires applicable SPARK `Global` contracts and supported effect inference. |
| `Missing_Depends_Contract` | Require declared information-flow contracts for every subprogram that has outputs. | SPARK `Depends` aspect completeness rule (Bronze level). | SPARK | Does not validate the relation once one is present. |
| `Incomplete_Depends_Contract` | Declare all outputs in information-flow contracts. | SPARK `Depends` aspect completeness rule (Bronze level). | SPARK | Checks selected omissions; does not by itself validate the complete dependency relation. |
| `Depends_Contract_Mismatch` | Keep declared input-to-output dependencies consistent with code. | SPARK `Depends` aspect consistency rule (Bronze level). | SPARK | Based on supported inferred data/control flow; indirect or unsupported effects need other evidence. |

### Maintainability and reviewability bounds (10 rules)

| AdaLang check | Safety objective | Related Ada RM / SPARK guidance | Alignment | Important limitation or complementary evidence |
|---|---|---|---|---|
| `Magic_Number` | Make numeric assumptions named, reviewable, and traceable. | General high-integrity coding practice. | Practice | Allows selected conventional literals; does not determine whether a constant has a justified value or unit. |
| `Cyclomatic_Complexity` | Bound the number of independent control-flow paths requiring review and test. | General coding practice. | Practice | Uses a configurable structural count; threshold and any deviation need project justification. |
| `Deep_Nesting` | Keep control structure locally understandable and testable. | General coding practice. | Practice | Uses a configurable nesting threshold; does not measure semantic or architectural complexity. |
| `Naming_Convention` | Require identifiers to communicate intent. | General coding practice. | Practice | Currently rejects mainly one-character identifiers outside limited exceptions. |
| `Generic_Instantiation_Limit` | Bound compile-time abstraction and unit complexity. | General coding practice; SPARK permits generics subject to restrictions on formal parts. | Practice | A configurable count is a local project policy, not proof each instantiation is safe. |
| `Dependency_Limit` | Bound coupling and keep compilation units reviewable. | General coding practice. | Practice | Counts `with` dependencies; not a semantic coupling or architecture-conformance measure. |
| `Circular_Package_Dependency` | Prevent cyclic architectural dependencies. | General coding practice; Ada's elaboration-order rules (RM 10.2) depend on an acyclic `with` structure. | Practice | Incomplete project inputs and indirect runtime dependencies can hide cycles. |
| `Missing_Overriding_Indicator` | Make inherited-operation replacement explicit. | Ada RM 8.3.1 `overriding_indicator` syntax. | Practice | Covers primitive overriding declarations; does not validate behavioral substitutability. |
| `Redundant_Type_Conversion` | Expose mistaken or misleading conversions. | General coding practice. | Practice | Detects no-effect conversions only. |
| `No_Compiler_Extensions` | Keep the language subset portable and compiler behavior controlled. | General portability practice grounded in the Ada RM's definition of a conforming, standard-defined program. | Practice | Detects selected implementation-defined pragmas; compiler switches and runtime need a separate configuration record. |

### Target-sensitive constructs require review (3 rules)

| AdaLang check | Safety objective | Related Ada RM / SPARK guidance | Alignment | Important limitation or complementary evidence |
|---|---|---|---|---|
| `Address_Clause` | Isolate absolute-address dependencies and hardware coupling. | General target-review practice; SPARK requires hardware-visible objects with explicit addresses to carry `Volatile`/`Async_Readers`/`Async_Writers` aspects. | Practice | Reports address representation clauses; linker placement, overlays, and target memory maps require review. |
| `Volatile_Atomic_Consistency` | Make hardware-visible access and synchronization policy explicit. | SPARK Reference Manual rules for `Volatile`, `Async_Readers`, `Async_Writers`, `Effective_Reads`, `Effective_Writes` aspects. | SPARK | Requiring atomic/full access does not validate memory ordering, device protocol, or target implementation. |
| `Representation_Clause_Policy` | Force target-specific review of explicit object representation. | General target-review practice. | Practice | Intentionally emits a review finding; ABI, size, alignment, and endianness must be verified externally. |

### Deviation control (2 rules)

| AdaLang check | Safety objective | Related Ada RM / SPARK guidance | Alignment | Important limitation or complementary evidence |
|---|---|---|---|---|
| `Suppression_Without_Rationale` | Ensure every inline analyzer deviation has a reviewable reason. | General deviation-control practice. | Practice | Checks inline analyzer suppressions only; baselines still need an external rationale, owner, approval, scope, and expiry record. |
| `No_Runtime_Check_Suppression` | Preserve Ada range, overflow, index, discriminant, access, and other run-time defenses. | Ada RM 11.5 `pragma Suppress`/`Unsuppress`. | SPARK | Detects `Suppress`, GNAT `Suppress_All`, and ignored/off check policies; compiler switches and configuration pragmas still require separate evidence. |

## Coverage summary

The preset has useful concentration in the areas EN 50128 Annex A names as
software design, implementation, and static verification techniques:

- Structured, modular, and deterministic control flow.
- Strong typing and storage/aliasing discipline (no dynamic allocation,
  unchecked conversion, or ambiguous aliasing).
- Defensive programming: explicit initialization and freedom from
  selected data-flow anomalies.
- Boundary value analysis for selected scalar run-time-error classes.
- Control-flow and data-flow analysis (dead/unreachable/contradictory
  constructs).
- Fault detection: exception handling, blocking-operation containment,
  and elaboration discipline.
- Formal specification and information-flow contracts, where SPARK is used.
- Maintainability and reviewability bounds.
- Target-sensitive constructs flagged for mandatory review.

This makes `--automotive` (reported here as `en50128`) a credible
**high-integrity Ada policy and defect screen** usable ahead of, or
alongside, an EN 50128 software verification and validation process. It
does not make the preset a certified or qualified verification tool, a
substitute for formal methods or GNATprove, or evidence that any SIL's
required technique set has been fully satisfied.

## Gap register

The following gaps prevent a standards-coverage or compliance claim under
EN 50128. "Not applicable" must be justified by the project rather than
inferred merely because Ada differs from another language.

| Gap | Current status | Recommended project or product action |
|---|---|---|
| Directive-by-directive mapping to EN 50128 | No normative mapping to the licensed EN 50128 text exists in this document; the categories above are AdaLang's own paraphrase. | Have competent reviewers classify every applicable EN 50128 technique as covered, manually enforced, or not applicable, against a licensed copy of the standard, for the required SIL. |
| SIL-dependent technique selection | The preset and this matrix are flat and unleveled; EN 50128's own technique recommendations (HR/R/M/NR) vary by SIL. | Determine the project's required SIL and select the subset of checks/manual controls that technique table actually requires or recommends at that level. |
| Formal methods and diverse programming | Not attempted; this analyzer performs static analysis and bounded scalar verification only. | Use GNATprove (formal proof) and/or an independently developed diverse implementation where EN 50128 recommends or requires them at the applicable SIL. |
| Complete run-time error analysis | Only supported known failures or bounded obligations are classified. | Use GNATprove to reach the applicable SPARK verification level for components that require it, plus qualified tests, reviews, and target evidence. |
| Structural coverage and dynamic testing | Not provided. | Supply unit/integration tests, requirements-based tests, structural coverage, and target execution evidence as required by the project's V&V plan. |
| Tool classification and confidence (EN 50128 Clause 6.7) | No T1/T2/T3 tool classification or confidence assessment is supplied. | Perform the applicable tool-classification and confidence assessment; document failure modes, detection controls, version pinning, and qualification needs. |
| Independent validation corpus | Rule fixtures test expected findings and clean cases; see the "Independent validation corpus" row of `AUTOMOTIVE_ADA_COMPLIANCE_MATRIX.md` for detail (shared corpus, same preset). | Extend boundary/negative coverage; add project-scale and cross-version regression tests. |
| Compliance reporting | `--compliance-report=en50128` (paired with `--automotive`) generates a per-objective evidence report (mapped checks, enabled/open/baselined status per objective, inline-suppression rationale trail, baseline-matched findings, and unsupported activities). The categories are the non-normative grouping above, not a clause-by-clause mapping to the licensed standard. `--compliance-report-format=json` produces the same content as a machine-readable document. | Revisit `en50128` with a clause-level mapping only if reviewed against a licensed copy of the standard by a qualified reviewer. |

See `AUTOMOTIVE_ADA_COMPLIANCE_MATRIX.md`'s own gap register for the
remaining gaps common to the shared `--automotive` rule set (numeric type
model, alias/access-value analysis, bitwise/representation behavior,
exception completeness, termination and stack bounds, restricted runtime
configuration, library and third-party component status, generated and
externally developed code, requirements traceability) -- they apply here
identically and are not repeated.

## Minimum defensible workflow

A project may use this matrix as the starting point for an EN 50128
software-technique assessment:

1. Freeze the AdaLang version, compiler, runtime, target, project scenario,
   preset contents, and analyzer configuration.
2. Determine the required Software Integrity Level and the EN 50128 Annex A
   technique recommendations that apply at that level; this requires a
   licensed copy of the standard.
3. Review every applicable technique for Ada and mixed-language
   applicability, using the categories above as a starting inventory.
4. Replace conceptual concern areas with approved rule identifiers and
   enforcement methods.
5. Record every unsupported or partially supported technique as a manual,
   formal-methods, proof, test, compiler, or process obligation.
6. Control deviations with rationale, risk analysis, approval, scope, and
   expiry.
7. Retain analyzer diagnostics, skipped/unsupported results, baselines,
   manual reviews, GNATprove proof reports, tests, target evidence, and
   component status.
8. Perform the tool classification and confidence assessment EN 50128
   Clause 6.7 requires for the analyzer's role in the V&V process.

Only the resulting project evidence -- not invocation of `--automotive` or
generation of an `en50128` compliance report -- can support a compliance or
safety argument under EN 50128.
