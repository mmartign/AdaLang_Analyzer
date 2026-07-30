# Automotive Ada Compliance Matrix

## Status and intended use

This matrix describes the checks enabled by the current `--automotive` preset
and relates them to language-independent safety objectives commonly addressed
by automotive coding standards.

It is a non-normative engineering aid. It is **not**:

- A MISRA C compliance matrix.
- A claim that a check implements any numbered MISRA directive or rule.
- A substitute for a licensed copy of the applicable standard.
- Evidence that a clean analysis proves the absence of a defect.
- Tool-qualification, compiler-validation, or target-validation evidence.

The comparison baseline is the safety intent of MISRA C:2023, without
reproducing or assigning its licensed rule text. Compliance-process
expectations are taken from the publicly available
[MISRA Compliance:2020](https://www.misra.org.uk/app/uploads/2021/06/MISRA-Compliance-2020.pdf).
A project making a standards claim must replace the concern-area column with a
reviewed, directive-by-directive mapping prepared against its licensed
standard.

The authoritative preset is `Enable_Automotive_Preset` in
`src/adalang_analyzer-cli.adb`. It currently enables 58 checks.

## How to read the matrix

The alignment labels measure similarity of safety intent, not standards
coverage:

- **Strong** — the Ada check directly enforces a restriction or detects a
  defect class with a close language-independent automotive rationale.
- **Partial** — the check addresses part of the objective, is deliberately
  bounded, or reports only defects that it can establish.
- **Ada-specific** — the check addresses an automotive concern created by Ada
  semantics and has no useful one-to-one C equivalent.

“Strong” does not mean sound, complete, qualified, or MISRA compliant. The
limitations column is part of every mapping and must not be omitted from an
assessment.

## Preset rule matrix

| # | AdaLang check | Safety objective | Closest MISRA C concern area | Alignment | Important limitation or complementary evidence |
|---:|---|---|---|---|---|
| 1 | `No_Goto` | Keep control flow structured and locally reviewable. | Control-flow restrictions | Strong | Prohibits all Ada `goto` statements; does not assess other forms of control-flow complexity. |
| 2 | `No_Abort` | Avoid asynchronous interruption at unpredictable program points. | Predictable execution and control flow | Ada-specific | Covers Ada task abort, not platform interrupts, signals, or cancellation implemented outside Ada syntax. |
| 3 | `No_Raise` | Avoid explicit exceptional transfers of control. | Predictable error handling | Partial | Covers explicit `raise`; implicit language-defined exceptions and exceptions raised by callees need separate analysis. |
| 4 | `No_Access_To_Subp_Def` | Keep call targets statically identifiable. | Indirect calls and function pointers | Strong | Detects access-to-subprogram type definitions; imported callbacks and other dynamic call mechanisms require review. |
| 5 | `No_Unchecked_Conversion` | Prevent representation reinterpretation that bypasses the type system. | Casts, object representation, and type safety | Strong | Detects semantic instantiations of `Ada.Unchecked_Conversion`; interfacing code and other unchecked facilities remain separate concerns. |
| 6 | `Floating_Equality` | Avoid fragile equality decisions on floating-point results. | Floating-point expressions | Strong | Flags equality and inequality on floating operands; it does not establish numerical stability, error bounds, or target conformance. |
| 7 | `Magic_Number` | Make numeric assumptions named, reviewable, and traceable. | Readability and maintainability | Partial | Allows selected conventional literals and does not determine whether a named constant has a justified value or unit. |
| 8 | `Dead_Store` | Detect values assigned but never used. | Data-flow anomalies | Partial | Intraprocedural analysis; aliasing, calls, exceptional paths, and unsupported constructs can reduce precision. |
| 9 | `Overwritten_Assignment` | Detect values overwritten before use. | Data-flow anomalies | Partial | Intraprocedural and conservative; it is not a complete all-path def-use proof. |
| 10 | `Shadowed_Declaration` | Prevent confusing reuse of identifiers in nested scopes. | Identifier uniqueness and visibility | Partial | Focuses on declarations hiding enclosing subprogram declarations; it is not a project-wide uniqueness policy. |
| 11 | `Infinite_Loop` | Require intentional and reviewable loop termination behavior. | Loop termination and control flow | Partial | Detects a syntactic class of unconditional loops; it neither proves general termination nor validates scheduling loops as intentional. |
| 12 | `Constant_Condition` | Expose invariant decisions and accidentally disabled behavior. | Invariant controlling expressions | Partial | Reports statically evident constants; more complex semantic constants can remain undetected. |
| 13 | `Unreachable_Code` | Remove code that cannot execute and may conceal mistakes. | Unreachable code | Partial | Primarily detects statements after unconditional transfers; it is not exhaustive path-reachability analysis. |
| 14 | `Division_By_Zero` | Prevent erroneous division, remainder, and modulus operations. | Arithmetic run-time safety | Partial | Reports statically detectable zero divisors; a clean finding result does not prove every dynamic divisor nonzero. |
| 15 | `Reversed_Range` | Prevent invalid or accidentally null ranges. | Bounds and range correctness | Strong | Covers statically evaluable reversed Ada ranges; dynamic bounds and whether a null range is intentional require further evidence. |
| 16 | `Self_Assignment` | Detect ineffective or mistaken assignments. | Assignment correctness | Strong | Covers the same object through simple renames; deeper alias equivalence is outside the rule. |
| 17 | `Contradictory_Condition` | Detect Boolean expressions that cannot have the intended result. | Boolean expressions and controlling conditions | Partial | Recognizes selected contradictory forms; it is not a general satisfiability proof for arbitrary conditions. |
| 18 | `No_Recursion` | Keep stack usage and call behavior bounded and analyzable. | Recursion prohibition | Partial | Detects direct recursion; mutually recursive call cycles require a whole-program call-graph assessment. |
| 19 | `Non_Short_Circuit_Condition` | Prevent unintended evaluation and side effects in conditions. | Evaluation order, side effects, and logical operators | Strong | Applies to selected controlling conditions; it does not perform a complete expression side-effect or evaluation-order analysis. |
| 20 | `Address_Clause` | Isolate absolute-address dependencies and hardware coupling. | Pointer/address use and implementation-defined behavior | Strong | Reports address representation clauses; imported addresses, linker placement, overlays, and target memory maps require review. |
| 21 | `Function_Side_Effect` | Make state changes explicit in interfaces and call sites. | Side effects in expressions and functions | Partial | Detects assignments to visible external state; effects through aliases, imported code, volatile hardware, or unknown calls may escape analysis. |
| 22 | `Global_Contract_Mismatch` | Ensure declared global effects match implementation behavior. | Interface side effects and data dependencies | Ada-specific | Requires applicable SPARK `Global` contracts and supported effect inference; absence of a contract is not reported by this enabled check. |
| 23 | `Incomplete_Depends_Contract` | Declare all outputs in information-flow contracts. | Interface completeness and data dependencies | Ada-specific | Checks selected omissions in SPARK `Depends`; it does not by itself validate the complete dependency relation. |
| 24 | `Depends_Contract_Mismatch` | Keep declared input-to-output dependencies consistent with code. | Data-flow and interface consistency | Ada-specific | Based on supported inferred data and control flow; indirect, concurrent, imported, or unsupported effects need other evidence. |
| 25 | `Uninitialized_Output` | Ensure outputs are defined on every normal return path. | Initialization and output parameters | Partial | Intraprocedural normal-return analysis; exceptional termination and unsupported constructs limit the conclusion. |
| 26 | `Known_Precondition_Failure` | Prevent calls known to violate their contracts. | Interface constraints and defensive programming | Partial | Reports only preconditions shown false by the bounded abstract state; “no finding” does not prove a precondition. |
| 27 | `Known_Postcondition_Failure` | Detect implementations known to violate declared results. | Interface contracts and functional consistency | Partial | Reports only postconditions shown false in the supported subset; it is not a general postcondition proof. |
| 28 | `Known_Assertion_Failure` | Detect safety assumptions known not to hold. | Assertions and run-time checks | Partial | Covers supported assertion forms when statically false; unresolved assertions require proof, test, or review. |
| 29 | `Known_Range_Check_Failure` | Prevent values known to violate subtype bounds. | Integer ranges, conversions, and arithmetic safety | Partial | Finds provable failures in supported assignments, initializations, and conversions; it does not prove all range checks safe. |
| 30 | `Known_Index_Check_Failure` | Prevent array accesses known to be out of bounds. | Array bounds | Partial | Reports provably invalid supported indices; it is not an exhaustive bounds proof. |
| 31 | `Known_Overflow_Failure` | Prevent integer operations known to exceed their base type. | Integer overflow and arithmetic conversions | Partial | Reports provable overflow in the supported scalar model; target arithmetic assumptions and all other operations need complementary analysis. |
| 32 | `Aliasing_Between_Parameters` | Prevent ambiguous updates through aliased actual parameters. | Pointer aliasing and side effects | Strong | Detects the same object or component passed to selected writable formals; general points-to and overlapping-storage analysis is not provided. |
| 33 | `Potentially_Blocking_Operation` | Avoid blocking while holding protected synchronization state. | Concurrency and predictable execution | Ada-specific | Covers selected direct and transitively summarized Ada blocking operations; scheduling and WCET evidence remain external. |
| 34 | `No_Dynamic_Allocation` | Keep memory consumption, allocation failure, and execution time bounded. | Dynamic memory allocation | Strong | Detects Ada allocators; custom pools, imported allocators, container internals, and start-up-only allocation need project controls. |
| 35 | `Restricted_Access_Type` | Reduce aliasing, ownership, lifetime, and nullability hazards. | Pointer use and object lifetime | Strong | Prohibits a broad class of Ada access-to-object definitions; access values introduced through libraries or interfaces require separate control. |
| 36 | `No_Explicit_Dereference` | Avoid access checks and obscure object identity at dereference sites. | Pointer dereference and validity | Strong | Covers explicit `.all`; implicit dereference, interfacing, and library abstractions need additional assessment. |
| 37 | `No_Unchecked_Deallocation` | Prevent dangling references, double release, and use after free. | Deallocation and pointer lifetime | Strong | Detects semantic instantiations of the Ada unchecked facility; foreign deallocators and custom storage management are outside its scope. |
| 38 | `No_Tasking` | Avoid unbounded scheduling and synchronization complexity. | Concurrency restriction | Ada-specific | Detects Ada task declarations; interrupts, runtime-created threads, foreign concurrency, and the execution environment need review. |
| 39 | `No_Rendezvous` | Avoid blocking task-entry synchronization. | Concurrency and blocking | Ada-specific | Covers entries and accept statements; other blocking protocols are handled only where separately modeled. |
| 40 | `No_Select` | Avoid timing-dependent and asynchronous selection. | Deterministic control flow and concurrency | Ada-specific | Covers Ada select forms; external event multiplexing and runtime services are not assessed. |
| 41 | `No_Requeue` | Keep entry queue behavior and control transfer explicit. | Deterministic control flow and concurrency | Ada-specific | Applies to Ada requeue statements only. |
| 42 | `No_Asynchronous_Transfer` | Avoid interruption of normal execution at difficult-to-review points. | Predictable control flow | Ada-specific | Covers asynchronous select/abortable parts; hardware interrupts and foreign cancellation require system-level controls. |
| 43 | `Exception_Propagation` | Contain failure paths at explicit interface boundaries. | Error handling and control flow | Partial | Uses conservative summaries of explicit exceptions; it is not a complete analysis of all language-defined or imported exceptions. |
| 44 | `No_Dispatching_Call` | Keep runtime call targets bounded and reviewable. | Indirect calls and dynamic dispatch | Strong | Detects semantically resolved dispatching and access-to-subprogram calls; unresolved or imported dispatch mechanisms require review. |
| 45 | `No_Classwide_Type` | Prevent open-ended sets of runtime types. | Type-system predictability and indirect behavior | Ada-specific | Applies to uses of `T'Class`; it does not replace a complete object-oriented design or hierarchy review. |
| 46 | `No_Controlled_Type` | Avoid hidden initialization, adjustment, and finalization control flow. | Object lifetime and implicit operations | Ada-specific | Detects derivation from Ada controlled types; other implicit finalization and library-managed resources need assessment. |
| 47 | `Complete_Initialization` | Require explicit initial values for objects and record components. | Initialization | Strong | A syntactic/semantic initialization policy is not proof that the chosen value is valid or that later reads are initialized. |
| 48 | `Uninitialized_Read` | Detect scalar locals whose first use is a read. | Use-before-initialization | Partial | Limited to supported scalar local flow; arrays, records, aliases, calls, exceptional paths, and unsupported constructs can require stronger analysis. |
| 49 | `Volatile_Atomic_Consistency` | Make hardware-visible access and synchronization policy explicit. | Volatile access and shared state | Partial | Requiring atomic or full access does not validate memory ordering, device protocol, address mapping, or target implementation. |
| 50 | `Representation_Clause_Policy` | Force target-specific review of explicit object representation. | Object representation and implementation-defined behavior | Partial | Intentionally emits a review finding; ABI, size, alignment, endianness, bit order, and compiler behavior must be verified externally. |
| 51 | `Library_Level_Initialization` | Avoid hidden, fallible, or order-dependent elaboration work. | Start-up initialization and order dependencies | Ada-specific | Reports calls in library-level initializers; complete Ada elaboration-order correctness and runtime start-up behavior need other evidence. |
| 52 | `Redundant_Type_Conversion` | Expose mistaken or misleading conversions. | Casts and type conversions | Partial | Detects no-effect conversions only; it does not implement a comprehensive Ada numeric-conversion or dimensional-type policy. |
| 53 | `Missing_Overriding_Indicator` | Make inherited-operation replacement explicit. | Interface consistency and type safety | Ada-specific | Covers primitive overriding declarations; it does not validate behavioral substitutability or inherited contracts. |
| 54 | `Generic_Instantiation_Limit` | Bound compile-time abstraction and unit complexity. | Translation-unit complexity | Partial | A configurable count is a local project policy, not evidence that each instantiation is safe or understandable. |
| 55 | `Dependency_Limit` | Bound coupling and keep compilation units reviewable. | Module dependencies and architecture | Partial | Counts `with` dependencies; it does not measure semantic coupling, architecture conformance, or external libraries. |
| 56 | `Circular_Package_Dependency` | Prevent cyclic architectural dependencies. | Module architecture and dependency control | Strong | Uses analyzed `with` relationships; incomplete project inputs and indirect runtime dependencies can hide cycles. |
| 57 | `Naming_Convention` | Require identifiers to communicate intent. | Identifier clarity | Partial | Currently rejects mainly one-character identifiers outside limited exceptions; it is not a configurable project naming standard. |
| 58 | `No_Compiler_Extensions` | Keep the language subset portable and compiler behavior controlled. | Language extensions and implementation-defined behavior | Strong | Detects selected implementation-defined pragmas; compiler switches, predefined environment, runtime library, and all implementation-defined behavior need a configuration record. |

## Coverage summary

The preset has useful concentration in these areas:

- Restricted and deterministic control flow.
- Dynamic storage, access values, aliasing, and object lifetime.
- Initialization and selected data-flow anomalies.
- Selected known run-time failures for scalar Ada.
- Exception, concurrency, dispatch, and elaboration restrictions.
- SPARK contracts and Ada-specific information-flow controls.
- Target-sensitive constructs that must receive manual review.

This makes `--automotive` a credible **high-integrity Ada policy and defect
screen**, especially when used before GNATprove or another stronger
verification activity. It does not make the preset a MISRA implementation.

## Gap register

The following gaps prevent a standards-coverage or compliance claim. “Not
applicable” must be justified by the project rather than inferred merely
because Ada differs from C.

| Gap | Current status | Recommended project or product action |
|---|---|---|
| Licensed directive-by-directive applicability | No normative mapping exists. | Select the required standard edition; have competent reviewers classify every directive as applicable, covered, manually enforced, or not applicable. |
| Guideline classification and enforcement method | AdaLang rules use their own quality and severity taxonomy. | Record required/advisory status, decidability, enforcement method, owner, evidence, and deviation policy in a controlled project matrix. |
| Comprehensive numeric type model | Selected conversions and known range/overflow failures are checked. | Define an Ada numeric policy covering universal literals, root types, fixed point, modular types, narrowing, dimensional types, rounding, and target representation. |
| Complete run-time error analysis | Only supported known failures or bounded obligations are classified. | Use GNATprove, qualified tests, reviews, and target evidence for required absence-of-error claims. |
| General alias and access-value analysis | Selected same-actual aliasing and restrictive access rules exist. | Add whole-program points-to, lifetime, nullness, overlapping-object, and imported-interface controls where access types are permitted. |
| Expression side effects and evaluation | Selected conditions and visible function writes are checked. | Add a comprehensive expression evaluation and side-effect policy, including calls, volatile objects, and compiler-defined ordering assumptions. |
| Bitwise, shift, representation, and endian behavior | Representation clauses trigger review. | Add explicit rules and target tests for modular operations, shifts, bit order, unchecked representation, overlays, packing, and endian conversion. |
| Floating- and fixed-point model | Only floating equality is restricted. | Document permitted types and operations, rounding, exceptional values, accuracy budgets, target model, and test tolerances. |
| Exception completeness | Explicit raises and summarized propagation are partially covered. | Define permitted exceptions and boundaries; combine restrictions, proof, last-chance-handler behavior, and fault-injection tests. |
| Termination and stack bounds | Direct recursion and a narrow infinite-loop pattern are checked. | Analyze mutual recursion, loop termination, maximum call depth, task stacks, secondary stack, and WCET. |
| Restricted runtime and compiler configuration | Source pragmas are partially checked. | Baseline compiler version and switches, language mode, restrictions profile, runtime library, binder/linker switches, warnings, and target configuration. |
| Standard and third-party libraries | Dependencies are counted, not approved by behavior. | Maintain an approved-component inventory with versions, usage constraints, provenance, qualification status, and known deviations. |
| Generated and externally developed code | No component-status compliance record exists. | Classify generated, reused, C, assembly, runtime, and binary-only components and define their acceptance evidence. |
| Preprocessing and C translation concerns | Not applicable to authored Ada source, but may apply to mixed-language components. | Mark as justified not applicable for Ada only after reviewing the complete build and foreign-language boundary. |
| Deviations and suppressions | Baselines and suppressions exist, but `Suppression_Without_Rationale` is not part of `--automotive`. | Enable rationale enforcement, define deviation authority and expiry, and generate a deviation report tied to rule, location, risk, and verification. |
| Requirements and bidirectional traceability | Automotive preset does not enable the DO-178C trace checks. | Use the project lifecycle toolchain to trace requirements, design, code, analysis findings, tests, and safety requirements. |
| Structural coverage and dynamic testing | Not provided. | Supply unit/integration tests, requirements-based tests, structural coverage where required, robustness tests, and target execution evidence. |
| Tool confidence and qualification | No qualification artifacts are supplied. | Perform the applicable tool-confidence assessment and validation; document failure modes, detection controls, version pinning, and qualification needs. |
| Independent validation corpus | Rule fixtures test expected findings and clean cases. | Add seeded, boundary, negative, project-scale, cross-version, and independent oracle tests with measured false-positive and false-negative results. |
| Compliance reporting | Text, JSON, SARIF, and baselines exist, but no compliance summary exists. | Generate a controlled report containing configuration, analyzed scope, skipped constructs, results, deviations, manual obligations, and evidence references. |

## Minimum defensible workflow

A project may use this matrix as the starting point for an automotive Ada
coding-standard assessment:

1. Freeze the AdaLang version, compiler, runtime, target, project scenario,
   preset contents, and analyzer configuration.
2. Select the applicable safety and coding standards and obtain the licensed
   normative documents.
3. Review every standard directive for Ada and mixed-language applicability.
4. Replace conceptual concern areas with approved directive identifiers and
   enforcement methods.
5. Record every unsupported or partially supported objective as a manual,
   proof, test, compiler, or process obligation.
6. Control deviations with rationale, risk analysis, approval, scope, and
   expiry.
7. Retain analyzer diagnostics, skipped/unsupported results, baselines, manual
   reviews, proof reports, tests, target evidence, and component status.
8. Assess tool confidence and perform any validation or qualification required
   by the governing lifecycle standard.

Only the resulting project evidence—not invocation of `--automotive`—can
support a compliance or safety argument.
