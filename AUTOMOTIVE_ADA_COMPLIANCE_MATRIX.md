# Automotive Ada Compliance Matrix

## Status and intended use

This matrix describes the checks enabled by the current `--automotive` preset
and relates them to the safety-oriented Ada language subset defined by SPARK
and to the high-integrity restrictions annex of the Ada Reference Manual.

It is a non-normative engineering aid. It is **not**:

- A SPARK Reference Manual conformance matrix.
- A claim that a check implements any specific Ada Annex H restriction
  identifier or SPARK legality rule to the letter.
- A substitute for GNATprove, a licensed copy of an applicable standard, or a
  qualified/certified toolchain.
- Evidence that a clean analysis proves the absence of a defect.
- Tool-qualification, compiler-validation, or target-validation evidence.

The comparison baseline is:

- The **Ada Reference Manual, Annex H, "High Integrity Systems"**, together
  with the partition-wide `pragma Restrictions` identifiers defined in 13.12.1,
  the tasking restrictions in D.7, the Ravenscar tasking profile in D.13, and
  the safety and security restrictions in H.4. Annex H is part of the
  international Ada standard (ISO/IEC 8652) and its text is published without
  charge at [ada-auth.org](http://www.ada-auth.org/standards/ada12.html).
- The **SPARK Reference Manual** and **SPARK User's Guide**
  ([docs.adacore.com](https://docs.adacore.com/spark2014-docs/html/lrm/)),
  which define the SPARK language subset (the Ada constructs SPARK excludes)
  and the Stone/Bronze/Silver/Gold/Platinum verification levels used to
  describe how much has been established about a program.

Clause numbers below are given for orientation against the Ada 2012/2022
Reference Manual; confirm against the specific edition a project adopts, since
numbering has shifted slightly across revisions.

The baseline compares to Ada and SPARK guidance rather than to a C coding
standard because AdaLang analyzes Ada, not C: mapping an Ada tool's checks
onto MISRA C's concern areas said more about MISRA C than about the checks
themselves. The Ada-native baseline above is a closer fit, and unlike MISRA C,
it requires no licensed standard to consult. A project that also needs a
MISRA C, AUTOSAR C++, ISO 26262, or EN 50128 mapping must build that mapping
separately against the licensed text of that standard; this document does not
attempt it, and a clean `--automotive` run is not evidence toward it.

The authoritative preset is `Enable_Automotive_Preset` in
`src/adalang_analyzer-cli.adb`. It currently enables 71 checks.

## How to read the matrix

The alignment labels measure similarity of safety intent, not standards
coverage:

- **Restriction** — the check enforces, or closely mirrors, a specific Ada
  Reference Manual rule: an Annex H / D.7 `pragma Restrictions` identifier,
  the Ravenscar profile (D.13), or another core RM rule (such as 9.5.1's
  definition of a potentially blocking operation).
- **SPARK** — the check enforces a SPARK subset legality rule, or addresses a
  concern that GNATprove's flow analysis or proof engine would otherwise
  raise at a specific SPARK verification level (Bronze: initialization and
  data-flow soundness; Gold: absence of run-time errors).
- **Practice** — the check encodes a general high-integrity coding practice.
  It is good discipline, and often improves the odds of a clean SPARK
  analysis or Annex H compliance argument, but it is not itself a normative
  Annex H restriction identifier or SPARK Reference Manual rule.

None of the three labels means sound, complete, qualified, or SPARK-verified.
The limitations column is part of every mapping and must not be omitted from
an assessment.

## Preset rule matrix

| # | AdaLang check | Safety objective | Related Ada RM / SPARK guidance | Alignment | Important limitation or complementary evidence |
|---:|---|---|---|---|---|
| 1 | `No_Goto` | Keep control flow structured and locally reviewable. | SPARK subset: `goto` statements are excluded from the SPARK language subset. | SPARK | Prohibits all Ada `goto` statements; does not assess other forms of control-flow complexity. |
| 2 | `No_Abort` | Avoid asynchronous interruption at unpredictable program points. | Ada RM Annex H restriction identifier `No_Abort_Statements` (D.7). | Restriction | Covers Ada task abort, not platform interrupts, signals, or cancellation implemented outside Ada syntax. |
| 3 | `No_Raise` | Avoid explicit exceptional transfers of control. | SPARK verification: an explicit `raise` requires proof that the raise point is unreachable, or an explicit exceptional-contract, to keep proof of the absence of run-time errors meaningful. | SPARK | Covers explicit `raise`; implicit language-defined exceptions and exceptions raised by callees need separate analysis. |
| 4 | `No_Access_To_Subp_Def` | Keep call targets statically identifiable. | Ada RM Annex H restriction identifier `No_Access_Subprograms` (D.7). | Restriction | Detects access-to-subprogram type definitions; imported callbacks and other dynamic call mechanisms require review. |
| 5 | `No_Unchecked_Conversion` | Prevent representation reinterpretation that bypasses the type system. | Ada RM 13.12.1 `pragma Restrictions (No_Dependence => Ada.Unchecked_Conversion)`; SPARK requires each unchecked conversion instance to be independently justified. | Restriction | Detects semantic instantiations of `Ada.Unchecked_Conversion`; interfacing code and other unchecked facilities remain separate concerns. |
| 6 | `Floating_Equality` | Avoid fragile equality decisions on floating-point results. | General numeric-verification practice; SPARK/GNATprove floating-point proof support is limited, which makes equality-sensitive floating comparisons a recognized soft spot for both SPARK proof and high-integrity guidance. | Practice | Flags equality and inequality on floating operands; it does not establish numerical stability, error bounds, or target conformance. |
| 7 | `Magic_Number` | Make numeric assumptions named, reviewable, and traceable. | General high-integrity coding practice; no Annex H restriction identifier or SPARK legality rule addresses numeric-literal naming. | Practice | Allows selected conventional literals and does not determine whether a named constant has a justified value or unit. |
| 8 | `Dead_Store` | Detect values assigned but never used. | SPARK flow analysis: related to GNATprove's Bronze-level "statement has no effect" data-flow diagnostics. | SPARK | Intraprocedural analysis; aliasing, calls, exceptional paths, and unsupported constructs can reduce precision. |
| 9 | `Overwritten_Assignment` | Detect values overwritten before use. | SPARK flow analysis: related to GNATprove's Bronze-level ineffective-assignment diagnostics. | SPARK | Intraprocedural and conservative; it is not a complete all-path def-use proof. |
| 10 | `Shadowed_Declaration` | Prevent confusing reuse of identifiers in nested scopes. | General high-integrity coding practice; not addressed by Annex H or the SPARK Reference Manual. | Practice | Focuses on declarations hiding enclosing subprogram declarations; it is not a project-wide uniqueness policy. |
| 11 | `Infinite_Loop` | Require intentional and reviewable loop termination behavior. | Relates to SPARK's `Loop_Variant` termination-evidence requirement (see `Missing_Loop_Variant`); Annex H has no restriction identifier for unconditional loops as such. | Practice | Detects a syntactic class of unconditional loops; it neither proves general termination nor validates scheduling loops as intentional. |
| 12 | `Constant_Condition` | Expose invariant decisions and accidentally disabled behavior. | General coding practice; GNATprove's flow and proof engine emits related diagnostics for some statically decided conditions, but this is not a distinct SPARK legality rule. | Practice | Reports statically evident constants; more complex semantic constants can remain undetected. |
| 13 | `Unreachable_Code` | Remove code that cannot execute and may conceal mistakes. | General coding practice; GNATprove's flow analysis emits related "unreachable code" diagnostics in some supported cases. | Practice | Primarily detects statements after unconditional transfers; it is not exhaustive path-reachability analysis. |
| 14 | `Division_By_Zero` | Prevent erroneous division, remainder, and modulus operations. | SPARK/GNATprove division-check verification condition, part of the Gold (absence of run-time errors) verification level. | SPARK | Reports statically detectable zero divisors; a clean finding result does not prove every dynamic divisor nonzero. |
| 15 | `Reversed_Range` | Prevent invalid or accidentally null ranges. | SPARK/GNATprove range-check verification condition (Gold level). | SPARK | Covers statically evaluable reversed Ada ranges; dynamic bounds and whether a null range is intentional require further evidence. |
| 16 | `Self_Assignment` | Detect ineffective or mistaken assignments. | General coding practice; no Annex H or SPARK-specific rule addresses self-assignment. | Practice | Covers the same object through simple renames; deeper alias equivalence is outside the rule. |
| 17 | `Contradictory_Condition` | Detect Boolean expressions that cannot have the intended result. | General coding practice; informally overlaps with what GNATprove's proof engine would flag as an unsatisfiable condition, but is not a distinct SPARK rule. | Practice | Recognizes selected contradictory forms; it is not a general satisfiability proof for arbitrary conditions. |
| 18 | `No_Recursion` | Keep stack usage and call behavior bounded and analyzable. | Ada RM Annex H restriction identifier `No_Recursion` (D.7). | Restriction | Detects direct recursion; mutually recursive call cycles require a whole-program call-graph assessment. |
| 19 | `Non_Short_Circuit_Condition` | Prevent unintended evaluation and side effects in conditions. | General coding practice; relates to SPARK's requirement that expression evaluation be free of order-dependent side effects, but is not itself a named SPARK rule. | Practice | Applies to selected controlling conditions; it does not perform a complete expression side-effect or evaluation-order analysis. |
| 20 | `Address_Clause` | Isolate absolute-address dependencies and hardware coupling. | General target-review practice; SPARK requires hardware-visible objects with explicit addresses to carry `Volatile`/`Async_Readers`/`Async_Writers` aspects (see `Volatile_Atomic_Consistency`). | Practice | Reports address representation clauses; imported addresses, linker placement, overlays, and target memory maps require review. |
| 21 | `Function_Side_Effect` | Make state changes explicit in interfaces and call sites. | SPARK legality rule: a SPARK function must not have side effects on global state; state-changing operations must be expressed as procedures. | SPARK | Detects assignments to visible external state; effects through aliases, imported code, volatile hardware, or unknown calls may escape analysis. |
| 22 | `Global_Contract_Mismatch` | Ensure declared global effects match implementation behavior. | SPARK `Global` aspect legality and flow-analysis rule (Bronze level). | SPARK | Requires applicable SPARK `Global` contracts and supported effect inference; absence of a contract is not reported by this enabled check. |
| 23 | `Incomplete_Depends_Contract` | Declare all outputs in information-flow contracts. | SPARK `Depends` aspect completeness rule (Bronze level). | SPARK | Checks selected omissions in SPARK `Depends`; it does not by itself validate the complete dependency relation. |
| 24 | `Depends_Contract_Mismatch` | Keep declared input-to-output dependencies consistent with code. | SPARK `Depends` aspect consistency rule (Bronze level). | SPARK | Based on supported inferred data and control flow; indirect, concurrent, imported, or unsupported effects need other evidence. |
| 25 | `Uninitialized_Output` | Ensure outputs are defined on every normal return path. | SPARK flow analysis: every mode-out global and parameter must be fully initialized on every normal return path (Bronze level). | SPARK | Intraprocedural normal-return analysis; exceptional termination and unsupported constructs limit the conclusion. |
| 26 | `Known_Precondition_Failure` | Prevent calls known to violate their contracts. | SPARK/GNATprove precondition verification condition (Gold level). | SPARK | Reports only preconditions shown false by the bounded abstract state; "no finding" does not prove a precondition. |
| 27 | `Known_Postcondition_Failure` | Detect implementations known to violate declared results. | SPARK/GNATprove postcondition verification condition (Gold level). | SPARK | Reports only postconditions shown false in the supported subset; it is not a general postcondition proof. |
| 28 | `Known_Assertion_Failure` | Detect safety assumptions known not to hold. | SPARK/GNATprove assertion verification condition (Gold level). | SPARK | Covers supported assertion forms when statically false; unresolved assertions require proof, test, or review. |
| 29 | `Known_Range_Check_Failure` | Prevent values known to violate subtype bounds. | SPARK/GNATprove range-check verification condition (Gold level). | SPARK | Finds provable failures in supported assignments, initializations, and conversions; it does not prove all range checks safe. |
| 30 | `Known_Index_Check_Failure` | Prevent array accesses known to be out of bounds. | SPARK/GNATprove index-check verification condition (Gold level). | SPARK | Reports provably invalid supported indices; it is not an exhaustive bounds proof. |
| 31 | `Known_Overflow_Failure` | Prevent integer operations known to exceed their base type. | SPARK/GNATprove overflow-check verification condition (Gold level). | SPARK | Reports provable overflow in the supported scalar model; target arithmetic assumptions and all other operations need complementary analysis. |
| 32 | `Aliasing_Between_Parameters` | Prevent ambiguous updates through aliased actual parameters. | SPARK legality rule: SPARK forbids aliasing between formal parameters (and between parameters and globals) that could make evaluation order-dependent. | SPARK | Detects the same object or component passed to selected writable formals; general points-to and overlapping-storage analysis is not provided. |
| 33 | `Potentially_Blocking_Operation` | Avoid blocking while holding protected synchronization state. | Ada RM 9.5.1's normative definition of a potentially blocking operation, which a protected operation must not invoke. | Restriction | Covers selected direct and transitively summarized Ada blocking operations; scheduling and WCET evidence remain external. |
| 34 | `No_Dynamic_Allocation` | Keep memory consumption, allocation failure, and execution time bounded. | Ada RM Annex H restriction identifier `No_Allocators` (D.7). | Restriction | Detects Ada allocators; custom pools, imported allocators, container internals, and start-up-only allocation need project controls. |
| 35 | `Restricted_Access_Type` | Reduce aliasing, ownership, lifetime, and nullability hazards. | Combines Annex H restriction identifiers `No_Unchecked_Access`, `No_Local_Allocators`, and `No_Anonymous_Allocators` (D.7) with SPARK's ownership-based access-type model. | Restriction | Prohibits a broad class of Ada access-to-object definitions; access values introduced through libraries or interfaces require separate control. |
| 36 | `No_Explicit_Dereference` | Avoid access checks and obscure object identity at dereference sites. | SPARK's ownership-based access-type model constrains dereference patterns (borrowing/observing); Annex H has no dedicated restriction identifier for explicit `.all`. | SPARK | Covers explicit `.all`; implicit dereference, interfacing, and library abstractions need additional assessment. |
| 37 | `No_Unchecked_Deallocation` | Prevent dangling references, double release, and use after free. | Ada RM 13.12.1 `pragma Restrictions (No_Dependence => Ada.Unchecked_Deallocation)`; SPARK's ownership model manages deallocation without this generic instantiation. | Restriction | Detects semantic instantiations of the Ada unchecked facility; foreign deallocators and custom storage management are outside its scope. |
| 38 | `No_Tasking` | Avoid unbounded scheduling and synchronization complexity. | Ada RM Annex H restriction identifier `No_Tasking` (D.7). | Restriction | Detects Ada task declarations; interrupts, runtime-created threads, foreign concurrency, and the execution environment need review. |
| 39 | `No_Rendezvous` | Avoid blocking task-entry synchronization. | Ravenscar tasking profile (Ada RM D.13, `pragma Profile (Ravenscar)`), which excludes rendezvous served by `accept`/`select` from high-integrity tasking. | Restriction | Covers entries and accept statements; other blocking protocols are handled only where separately modeled. |
| 40 | `No_Select` | Avoid timing-dependent and asynchronous selection. | Ravenscar tasking profile (D.13) and Annex H restriction identifier `No_Select_Statements` (D.7). | Restriction | Covers Ada select forms; external event multiplexing and runtime services are not assessed. |
| 41 | `No_Requeue` | Keep entry queue behavior and control transfer explicit. | Ravenscar tasking profile (D.13) and Annex H restriction identifier `No_Requeue_Statements` (D.7). | Restriction | Applies to Ada requeue statements only. |
| 42 | `No_Asynchronous_Transfer` | Avoid interruption of normal execution at difficult-to-review points. | Ravenscar tasking profile (D.13), which excludes asynchronous select and abortable parts from high-integrity tasking. | Restriction | Covers asynchronous select/abortable parts; hardware interrupts and foreign cancellation require system-level controls. |
| 43 | `Exception_Propagation` | Contain failure paths at explicit interface boundaries. | Ada RM Annex H restriction identifier `No_Exception_Propagation` (D.7, H.4). | Restriction | Uses conservative summaries of explicit exceptions; it is not a complete analysis of all language-defined or imported exceptions. |
| 44 | `No_Dispatching_Call` | Keep runtime call targets bounded and reviewable. | Ada RM Annex H restriction identifier `No_Dispatch` (D.7). | Restriction | Detects semantically resolved dispatching and access-to-subprogram calls; unresolved or imported dispatch mechanisms require review. |
| 45 | `No_Classwide_Type` | Prevent open-ended sets of runtime types. | Relates to Annex H restriction identifier `No_Dispatch` (D.7); class-wide types are the mechanism through which dynamic dispatch is expressed. | Restriction | Applies to uses of `T'Class`; it does not replace a complete object-oriented design or hierarchy review. |
| 46 | `No_Controlled_Type` | Avoid hidden initialization, adjustment, and finalization control flow. | SPARK legality rule: types derived from `Ada.Finalization` controlled types are excluded from the SPARK subset because `Initialize`/`Adjust`/`Finalize` introduce implicit control flow. | SPARK | Detects derivation from Ada controlled types; other implicit finalization and library-managed resources need assessment. |
| 47 | `Complete_Initialization` | Require explicit initial values for objects and record components. | SPARK flow analysis: SPARK's default full-initialization policy for objects and record components (Bronze level). | SPARK | A syntactic/semantic initialization policy is not proof that the chosen value is valid or that later reads are initialized. |
| 48 | `Uninitialized_Read` | Detect scalar locals whose first use is a read. | SPARK flow analysis: use-before-initialization is a core Bronze-level flow-soundness diagnostic. | SPARK | Limited to supported scalar local flow; arrays, records, aliases, calls, exceptional paths, and unsupported constructs can require stronger analysis. |
| 49 | `Volatile_Atomic_Consistency` | Make hardware-visible access and synchronization policy explicit. | SPARK Reference Manual rules for `Volatile`, `Async_Readers`, `Async_Writers`, `Effective_Reads`, and `Effective_Writes` aspects. | SPARK | Requiring atomic or full access does not validate memory ordering, device protocol, address mapping, or target implementation. |
| 50 | `Representation_Clause_Policy` | Force target-specific review of explicit object representation. | General target-review practice; neither Annex H nor the SPARK Reference Manual mandates a review policy for representation clauses. | Practice | Intentionally emits a review finding; ABI, size, alignment, endianness, bit order, and compiler behavior must be verified externally. |
| 51 | `Library_Level_Initialization` | Avoid hidden, fallible, or order-dependent elaboration work. | Ada RM 10.2 elaboration-order rules and the `Preelaborate`/`Pure` categorization pragmas used to keep elaboration predictable. | Restriction | Reports calls in library-level initializers; complete Ada elaboration-order correctness and runtime start-up behavior need other evidence. |
| 52 | `Redundant_Type_Conversion` | Expose mistaken or misleading conversions. | General coding practice; no Annex H or SPARK rule addresses no-effect conversions. | Practice | Detects no-effect conversions only; it does not implement a comprehensive Ada numeric-conversion or dimensional-type policy. |
| 53 | `Missing_Overriding_Indicator` | Make inherited-operation replacement explicit. | Ada RM 8.3.1 `overriding_indicator` syntax, mandatory in some contexts and recommended more broadly as high-integrity practice. | Practice | Covers primitive overriding declarations; it does not validate behavioral substitutability or inherited contracts. |
| 54 | `Generic_Instantiation_Limit` | Bound compile-time abstraction and unit complexity. | General coding practice; the SPARK Reference Manual permits generics subject to restrictions on formal parts, but sets no instantiation-count policy. | Practice | A configurable count is a local project policy, not evidence that each instantiation is safe or understandable. |
| 55 | `Dependency_Limit` | Bound coupling and keep compilation units reviewable. | General coding practice; not addressed by Annex H or the SPARK Reference Manual. | Practice | Counts `with` dependencies; it does not measure semantic coupling, architecture conformance, or external libraries. |
| 56 | `Circular_Package_Dependency` | Prevent cyclic architectural dependencies. | General coding practice; Ada's elaboration-order rules (RM 10.2) depend on an acyclic `with` structure, though the RM sets no dependency-count or cycle policy beyond what elaboration requires. | Practice | Uses analyzed `with` relationships; incomplete project inputs and indirect runtime dependencies can hide cycles. |
| 57 | `Naming_Convention` | Require identifiers to communicate intent. | General coding practice; not addressed by Annex H or the SPARK Reference Manual. | Practice | Currently rejects mainly one-character identifiers outside limited exceptions; it is not a configurable project naming standard. |
| 58 | `No_Compiler_Extensions` | Keep the language subset portable and compiler behavior controlled. | General portability practice grounded in the Ada RM's definition of a conforming, standard-defined program; both high-integrity Ada and SPARK guidance require staying within standard, non-implementation-defined constructs. | Practice | Detects selected implementation-defined pragmas; compiler switches, predefined environment, runtime library, and all implementation-defined behavior need a configuration record. |
| 59 | `Unreachable_Branch` | Expose conditional behavior that cannot execute. | General coding practice; GNATprove's flow analysis emits related diagnostics for some statically excluded branches. | Practice | Detects branches excluded by supported static conditions; it is not exhaustive path-reachability analysis. |
| 60 | `Unreachable_Case_Alternative` | Prevent dead or incorrectly specified case choices. | General coding practice; informally overlaps with GNATprove flow/proof diagnostics for dominated choices. | Practice | Covers statically dominated choices; dynamic semantic constraints and unsupported expressions require other evidence. |
| 61 | `Overlapping_Case_Ranges` | Keep selection alternatives mutually exclusive and reviewable. | General coding practice; the underlying case-exhaustiveness requirement is enforced by core Ada legality rules, but overlap between explicit choices is not itself an Annex H or SPARK rule. | Practice | Applies to statically evaluable integer choices; it does not validate every dynamic or representation-dependent selection. |
| 62 | `Exception_Swallowed` | Prevent broad exception handlers from silently discarding failures. | General high-integrity practice; relates to Annex H's `No_Exception_Propagation` intent (see `Exception_Propagation`) but addresses a different failure mode — a handler that exists but discards the failure. | Practice | Detects empty or null-only `when others` handlers; logging, recovery adequacy, and externally implemented handlers require review. |
| 63 | `Missing_Loop_Variant` | Require termination evidence for annotated proof loops. | SPARK `Loop_Variant` aspect, used by GNATprove to prove loop termination. | SPARK | Applies only when a loop already has a `Loop_Invariant`; it does not require or prove termination for every loop. |
| 64 | `Known_Discriminant_Check_Failure` | Prevent accesses known to select an absent variant component. | SPARK/GNATprove discriminant-check verification condition (Gold level). | SPARK | Supports statically known literal or enumeration discriminants; it is not a complete discriminant-safety proof. |
| 65 | `Cyclomatic_Complexity` | Bound the number of independent control-flow paths requiring review and test. | General coding practice; not addressed by Annex H or the SPARK Reference Manual. | Practice | Uses a configurable structural count; the threshold and any deviation need project justification. |
| 66 | `Deep_Nesting` | Keep control structure locally understandable and testable. | General coding practice; not addressed by Annex H or the SPARK Reference Manual. | Practice | Uses a configurable nesting threshold; it does not measure semantic or architectural complexity. |
| 67 | `No_Runtime_Check_Suppression` | Preserve Ada range, overflow, index, discriminant, access, and other run-time defenses. | Ada RM 11.5 `pragma Suppress`/`Unsuppress`; suppressing a check removes exactly the run-time defense that SPARK's Gold-level absence-of-run-time-errors proof is meant to discharge by proof instead. | SPARK | Detects `Suppress`, GNAT `Suppress_All`, and ignored/off check policies; compiler switches, configuration pragmas, runtime builds, and other check-removal mechanisms still require configuration evidence. |
| 68 | `Suppression_Without_Rationale` | Ensure every inline analyzer deviation has a reviewable reason. | General deviation-control practice; not itself an Annex H restriction identifier or SPARK Reference Manual rule. | Practice | Checks inline analyzer suppressions only; baselines still need an external rationale, owner, approval, scope, and expiry record. |
| 69 | `SPARK_Mode` | Prevent silent, unreviewed departure from the analyzable SPARK subset. | SPARK Reference Manual: the `SPARK_Mode` aspect/pragma is the language-defined switch between the full Ada and SPARK subsets. | SPARK | Detects regions that explicitly set `SPARK_Mode` to `Off`; code that was never brought into `SPARK_Mode => On` in the first place is not reported by this check. |
| 70 | `Missing_Global_Contract` | Require declared global effects for every subprogram that has them. | SPARK `Global` aspect completeness rule (Bronze level); pairs with `Global_Contract_Mismatch`, which checks consistency once a contract exists. | SPARK | Reports subprograms that access global state without an explicit `Global` contract; subprograms with no global access need no contract and are not reported. |
| 71 | `Missing_Depends_Contract` | Require declared information-flow contracts for every subprogram that has outputs. | SPARK `Depends` aspect completeness rule (Bronze level); pairs with `Depends_Contract_Mismatch` and `Incomplete_Depends_Contract`, which check consistency and partial omission once a contract exists. | SPARK | Reports subprograms with outputs but no explicit `Depends` contract; it does not validate the relation once one is present. |

## Coverage summary

The preset has useful concentration in these areas:

- Restricted and deterministic control flow, largely mirroring Annex H
  restriction identifiers and the Ravenscar tasking profile.
- Dynamic storage, access values, aliasing, and object lifetime.
- Initialization and selected data-flow anomalies, largely mirroring SPARK's
  Bronze-level flow-analysis concerns.
- Selected known run-time failures for scalar Ada, largely mirroring SPARK's
  Gold-level (absence of run-time errors) proof obligations.
- Exception, concurrency, dispatch, and elaboration restrictions.
- SPARK contracts and Ada-specific information-flow controls.
- Target-sensitive constructs that must receive manual review.

This makes `--automotive` a credible **high-integrity Ada policy and defect
screen**, especially when used before GNATprove or another stronger
verification activity. It does not make the preset a certified SPARK
toolchain, a substitute for GNATprove verification, or evidence of having
reached a specific SPARK verification level without actually running
GNATprove.

## Gap register

The following gaps prevent a standards-coverage or compliance claim. "Not
applicable" must be justified by the project rather than inferred merely
because Ada differs from C.

| Gap | Current status | Recommended project or product action |
|---|---|---|
| Directive-by-directive mapping to an external standard | Annex H and the SPARK Reference Manual are open-access and used as the comparison baseline above, but a project may still need MISRA C, AUTOSAR C++, ISO 26262, or EN 50128 coverage. No normative mapping to those licensed standards exists in this document. | Select the required standard edition; have competent reviewers classify every directive as applicable, covered, manually enforced, or not applicable. |
| Guideline classification and enforcement method | AdaLang rules use their own quality and severity taxonomy. | Record required/advisory status, decidability, enforcement method, owner, evidence, and deviation policy in a controlled project matrix. |
| Comprehensive numeric type model | Selected conversions and known range/overflow failures are checked. | Define an Ada numeric policy covering universal literals, root types, fixed point, modular types, narrowing, dimensional types, rounding, and target representation. |
| Complete run-time error analysis | Only supported known failures or bounded obligations are classified. | Use GNATprove to reach the applicable SPARK verification level (Bronze through Platinum) for the components that require it, plus qualified tests, reviews, and target evidence for required absence-of-error claims. |
| General alias and access-value analysis | Selected same-actual aliasing and restrictive access rules exist. | Add whole-program points-to, lifetime, nullness, overlapping-object, and imported-interface controls where access types are permitted; or adopt SPARK's ownership model for the components that need proof-grade aliasing freedom. |
| Expression side effects and evaluation | Selected conditions and visible function writes are checked. | Add a comprehensive expression evaluation and side-effect policy, including calls, volatile objects, and compiler-defined ordering assumptions. |
| Bitwise, shift, representation, and endian behavior | Representation clauses trigger review. | Add explicit rules and target tests for modular operations, shifts, bit order, unchecked representation, overlays, packing, and endian conversion. |
| Floating- and fixed-point model | Only floating equality is restricted. | Document permitted types and operations, rounding, exceptional values, accuracy budgets, target model, and test tolerances; note that SPARK's floating-point proof support is itself limited. |
| Exception completeness | Explicit raises and summarized propagation are partially covered. | Define permitted exceptions and boundaries; combine restrictions, proof (or explicit `Exceptional_Cases` contracts), last-chance-handler behavior, and fault-injection tests. |
| Termination and stack bounds | Direct recursion, a narrow infinite-loop pattern, and missing variants on already annotated loops are checked. | Analyze mutual recursion, general loop termination (`Loop_Variant` proof for the rest), maximum call depth, task stacks, secondary stack, and WCET. |
| Restricted runtime and compiler configuration | Source pragmas are partially checked. | Baseline compiler version and switches, language mode, restrictions profile, runtime library, binder/linker switches, warnings, and target configuration. |
| Standard and third-party libraries | Dependencies are counted, not approved by behavior. | Maintain an approved-component inventory with versions, usage constraints, provenance, qualification status, and known deviations. |
| Generated and externally developed code | No component-status compliance record exists. | Classify generated, reused, C, assembly, runtime, and binary-only components and define their acceptance evidence. |
| Preprocessing and C translation concerns | Not applicable to authored Ada source, but may apply to mixed-language components. | Mark as justified not applicable for Ada only after reviewing the complete build and foreign-language boundary. |
| Deviations and suppressions | Inline analyzer suppressions require a rationale; baseline entries do not carry controlled deviation metadata. | Define deviation authority and expiry, and generate a deviation report tied to rule, location, risk, and verification. |
| Requirements and bidirectional traceability | Automotive preset does not enable the DO-178C trace checks. | Use the project lifecycle toolchain to trace requirements, design, code, analysis findings, tests, and safety requirements. |
| Structural coverage and dynamic testing | Not provided. | Supply unit/integration tests, requirements-based tests, structural coverage where required, robustness tests, and target execution evidence. |
| Tool confidence and qualification | No qualification artifacts are supplied. | Perform the applicable tool-confidence assessment and validation; document failure modes, detection controls, version pinning, and qualification needs. |
| Independent validation corpus | Rule fixtures test expected findings and clean cases. `quality/precision_corpus.tsv` additionally verifies boundary behavior (exactly-at-threshold vs. threshold-plus-one) for the six checks with a configurable numeric threshold, plus nine regression-negative cases folded in from the project's precision regression index, each value confirmed against the built analyzer's own output. | Extend boundary/negative coverage to checks without a numeric threshold; add project-scale, cross-version, and independent-oracle (e.g. GNATcheck) tests with measured false-positive and false-negative results. |
| Compliance reporting | `--compliance-report=<do178c\|iso26262>` generates a Markdown, per-objective evidence report (mapped checks, enabled/open/baselined status per objective, inline-suppression rationale trail, baseline-matched findings, and unsupported activities). The `iso26262` categories are the non-normative grouping below, not a clause-by-clause mapping to the licensed standard. Markdown only; a machine-readable (JSON/SARIF) form remains open. | Add a structured export format for tooling that consumes the report programmatically; revisit `iso26262` with a clause-level mapping only if reviewed against a licensed copy of the standard by a qualified reviewer. |

## Minimum defensible workflow

A project may use this matrix as the starting point for a high-integrity Ada
coding-standard assessment:

1. Freeze the AdaLang version, compiler, runtime, target, project scenario,
   preset contents, and analyzer configuration.
2. Select the applicable safety and coding standards. Annex H and the SPARK
   Reference Manual are open-access; any additional external standard (MISRA
   C, AUTOSAR C++, ISO 26262, EN 50128) requires its own licensed normative
   text.
3. Review every applicable rule for Ada and mixed-language applicability.
4. Replace conceptual concern areas with approved rule identifiers and
   enforcement methods.
5. Record every unsupported or partially supported objective as a manual,
   proof, test, compiler, or process obligation.
6. Control deviations with rationale, risk analysis, approval, scope, and
   expiry.
7. Retain analyzer diagnostics, skipped/unsupported results, baselines, manual
   reviews, GNATprove proof reports, tests, target evidence, and component
   status.
8. Assess tool confidence and perform any validation or qualification required
   by the governing lifecycle standard.

Only the resulting project evidence—not invocation of `--automotive`—can
support a compliance or safety argument.
