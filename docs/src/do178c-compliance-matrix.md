# DO-178C Compliance Matrix

## Status and intended use

This matrix describes the checks enabled by the current `--do178c=<A|B|C|D>`
verification-support profiles and relates them to DO-178C Annex A Table A-5
(reviews and analyses of source code) activity categories, to the Ada
Reference Manual, and to the SPARK Reference Manual.

It is a non-normative engineering aid. It is **not**:

- A DO-178C Annex A objective-by-objective compliance matrix.
- A claim that a check implements any specific Annex A objective, Ada Annex H
  restriction identifier, or SPARK legality rule to the letter.
- A substitute for GNATprove, a licensed copy of DO-178C, or a
  qualified/certified toolchain.
- Structural coverage, requirements-based testing, or object code
  verification evidence.
- Tool-qualification evidence under DO-330.

The comparison baseline is:

- **DO-178C Annex A Table A-5**, "Verification of Verification Process
  Results — Reviews and Analyses of Source Code." AdaLang paraphrases the
  publicly discussed activity categories from this table (traceability,
  standards conformance, accuracy and consistency, verifiability); it does
  not reproduce the licensed standard's normative text or numbering. A
  project needs its own licensed copy of DO-178C to assess applicability and
  coverage against the actual objective text.
- The **Ada Reference Manual, Annex H, "High Integrity Systems,"** together
  with the partition-wide `pragma Restrictions` identifiers defined in
  13.12.1 and the elaboration-order rules of 10.2. Annex H is part of the
  international Ada standard (ISO/IEC 8652) and its text is published
  without charge at [ada-auth.org](http://www.ada-auth.org/standards/ada12.html).
- The **SPARK Reference Manual** and **SPARK User's Guide**
  ([docs.adacore.com](https://docs.adacore.com/spark2014-docs/html/lrm/)),
  which define the SPARK language subset and the Bronze/Gold verification
  levels this matrix cites.

Clause numbers below are given for orientation against the Ada 2012/2022
Reference Manual; confirm against the specific edition a project adopts.

The authoritative preset is `Enable_DO_178C_Preset` in
`src/adalang_analyzer-cli.adb`, which enables three tiers depending on the
selected level:

| Level | Enables | Structural coverage objective recorded |
|---|---|---|
| D | Core tier only (19 checks) | None |
| C | Core + Level C tier (30 checks) | Statement coverage |
| B | Core + Level C + Level A/B tier (all 46 checks) | Decision coverage |
| A | Core + Level C + Level A/B tier (all 46 checks) | MC/DC |

AdaLang does not measure structural coverage itself; the objective above is
recorded in JSON/SARIF output as metadata for a separate coverage tool such
as GNATcoverage, not evidence that coverage was achieved.

## How to read the matrix

The alignment labels measure similarity of safety intent, not standards
coverage — the same three labels `AUTOMOTIVE_ADA_COMPLIANCE_MATRIX.md` uses,
since 42 of the 46 checks below are shared with the `--automotive` preset and
carry the same underlying Ada/SPARK rationale regardless of which profile
enables them:

- **Restriction** — the check enforces, or closely mirrors, a specific Ada
  Reference Manual rule: an Annex H `pragma Restrictions` identifier or
  another core RM rule (such as 9.5.1's definition of a potentially blocking
  operation, or 11.2's exception-handler selection rule).
- **SPARK** — the check enforces a SPARK subset legality rule, or addresses a
  concern that GNATprove's flow analysis or proof engine would otherwise
  raise at a specific SPARK verification level (Bronze: initialization and
  data-flow soundness; Gold: absence of run-time errors).
- **Practice** — the check encodes a general high-integrity coding practice,
  including AdaLang's own DO-178C traceability-annotation convention. It is
  good discipline, and often improves the odds of a clean SPARK analysis or
  Annex H compliance argument, but it is not itself a normative Annex A
  objective, Annex H restriction identifier, or SPARK Reference Manual rule.

None of the three labels means sound, complete, qualified, or SPARK-verified.
The limitations column is part of every mapping and must not be omitted from
an assessment.

## Preset rule matrix

The "DO-178C level(s)" column lists every level under which
`Enable_DO_178C_Preset` enables the check (see the tier table above); a check
listed only under "A, B" is not enabled at level C or D.

| # | AdaLang check | DO-178C level(s) | Safety objective | Related Ada RM / SPARK guidance | Alignment | Important limitation or complementary evidence |
|---:|---|---|---|---|---|---|
| 1 | `Exception_Swallowed` | A, B, C, D | Prevent broad exception handlers from silently discarding failures. | General high-integrity practice; relates to Annex H's `No_Exception_Propagation` intent (see `Exception_Propagation`) but addresses a different failure mode — a handler that exists but discards the failure. | Practice | Detects empty or null-only `when others` handlers; logging, recovery adequacy, and externally implemented handlers require review. |
| 2 | `Empty_Exception_Handler` | A, B, C, D | Prevent silently discarding a caught exception without any substantive recovery, logging, or re-raise action. | General high-integrity practice; complements `Exception_Swallowed`, which covers the narrower `when others` case specifically -- this check covers any handler, named or `others`, with no substantive body. | Practice | Detects handlers whose entire body is a null statement or comment; a handler that does trivial but real work (e.g. a single logging call) is not reported. |
| 3 | `Handler_Order` | A, B, C, D | Ensure a `when others` handler is never placed before a later handler in the same handled-sequence-of-statements, which would make that later handler unreachable. | Ada RM 11.2's exception-handler selection rule: handlers are tried in textual order, so any `when others` handler ahead of another handler makes the later one dead code. | Restriction | Detects only an earlier `when others` handler shadowing a later one; it does not analyze ordering between two named-exception handlers or ancestor/descendant exception relationships. |
| 4 | `Unreachable_Code` | A, B, C, D | Remove code that cannot execute and may conceal mistakes. | General coding practice; GNATprove's flow analysis emits related "unreachable code" diagnostics in some supported cases. | Practice | Primarily detects statements after unconditional transfers; it is not exhaustive path-reachability analysis. |
| 5 | `Unreachable_Branch` | A, B, C, D | Expose conditional behavior that cannot execute. | General coding practice; GNATprove's flow analysis emits related diagnostics for some statically excluded branches. | Practice | Detects branches excluded by supported static conditions; it is not exhaustive path-reachability analysis. |
| 6 | `Unreachable_Case_Alternative` | A, B, C, D | Prevent dead or incorrectly specified case choices. | General coding practice; informally overlaps with GNATprove flow/proof diagnostics for dominated choices. | Practice | Covers statically dominated choices; dynamic semantic constraints and unsupported expressions require other evidence. |
| 7 | `Division_By_Zero` | A, B, C, D | Prevent erroneous division, remainder, and modulus operations. | SPARK/GNATprove division-check verification condition, part of the Gold (absence of run-time errors) verification level. | SPARK | Reports statically detectable zero divisors; a clean finding result does not prove every dynamic divisor nonzero. |
| 8 | `Reversed_Range` | A, B, C, D | Prevent invalid or accidentally null ranges. | SPARK/GNATprove range-check verification condition (Gold level). | SPARK | Covers statically evaluable reversed Ada ranges; dynamic bounds and whether a null range is intentional require further evidence. |
| 9 | `Self_Assignment` | A, B, C, D | Detect ineffective or mistaken assignments. | General coding practice; no Annex H or SPARK-specific rule addresses self-assignment. | Practice | Covers the same object through simple renames; deeper alias equivalence is outside the rule. |
| 10 | `Contradictory_Condition` | A, B, C, D | Detect Boolean expressions that cannot have the intended result. | General coding practice; informally overlaps with what GNATprove's proof engine would flag as an unsatisfiable condition, but is not a distinct SPARK rule. | Practice | Recognizes selected contradictory forms; it is not a general satisfiability proof for arbitrary conditions. |
| 11 | `Constant_Condition` | A, B, C, D | Expose invariant decisions and accidentally disabled behavior. | General coding practice; GNATprove's flow and proof engine emits related diagnostics for some statically decided conditions, but this is not a distinct SPARK legality rule. | Practice | Reports statically evident constants; more complex semantic constants can remain undetected. |
| 12 | `Known_Precondition_Failure` | A, B, C, D | Prevent calls known to violate their contracts. | SPARK/GNATprove precondition verification condition (Gold level). | SPARK | Reports only preconditions shown false by the bounded abstract state; "no finding" does not prove a precondition. |
| 13 | `Known_Postcondition_Failure` | A, B, C, D | Detect implementations known to violate declared results. | SPARK/GNATprove postcondition verification condition (Gold level). | SPARK | Reports only postconditions shown false in the supported subset; it is not a general postcondition proof. |
| 14 | `Known_Assertion_Failure` | A, B, C, D | Detect safety assumptions known not to hold. | SPARK/GNATprove assertion verification condition (Gold level). | SPARK | Covers supported assertion forms when statically false; unresolved assertions require proof, test, or review. |
| 15 | `Known_Range_Check_Failure` | A, B, C, D | Prevent values known to violate subtype bounds. | SPARK/GNATprove range-check verification condition (Gold level). | SPARK | Finds provable failures in supported assignments, initializations, and conversions; it does not prove all range checks safe. |
| 16 | `Known_Index_Check_Failure` | A, B, C, D | Prevent array accesses known to be out of bounds. | SPARK/GNATprove index-check verification condition (Gold level). | SPARK | Reports provably invalid supported indices; it is not an exhaustive bounds proof. |
| 17 | `Known_Overflow_Failure` | A, B, C, D | Prevent integer operations known to exceed their base type. | SPARK/GNATprove overflow-check verification condition (Gold level). | SPARK | Reports provable overflow in the supported scalar model; target arithmetic assumptions and all other operations need complementary analysis. |
| 18 | `Aliasing_Between_Parameters` | A, B, C, D | Prevent ambiguous updates through aliased actual parameters. | SPARK legality rule: SPARK forbids aliasing between formal parameters (and between parameters and globals) that could make evaluation order-dependent. | SPARK | Detects the same object or component passed to selected writable formals; general points-to and overlapping-storage analysis is not provided. |
| 19 | `Exception_Propagation` | A, B, C, D | Contain failure paths at explicit interface boundaries. | Ada RM Annex H restriction identifier `No_Exception_Propagation` (D.7, H.4). | Restriction | Uses conservative summaries of explicit exceptions; it is not a complete analysis of all language-defined or imported exceptions. |
| 20 | `Missing_Requirement_Trace` | A, B, C | Provide a machine-checkable link from source code back to the low-level requirement it implements, supporting DO-178C Annex A traceability objectives. | General high-integrity practice; DO-178C Annex A Table A-5 requires source code traceable to low-level requirements, but sets no specific annotation syntax -- the `-- do-178c: req <id>` convention is AdaLang's own. | Practice | Flags subprogram bodies with no `req` annotation on the declaration line or the three immediately preceding lines; it does not validate that the cited identifier exists in a requirements database or that the implementation actually satisfies it. |
| 21 | `Malformed_Requirement_Trace` | A, B, C | Catch a requirement-trace comment that names the `do-178c: req` marker but supplies no identifier after it, which `Missing_Requirement_Trace` would otherwise treat as present. | General high-integrity practice; complements `Missing_Requirement_Trace`, which only checks whether the marker exists at all -- this check additionally requires non-empty text after it. | Practice | Detects only an empty identifier after the marker; a present but semantically wrong, misspelled, or stale requirement identifier is not detected. |
| 22 | `Dead_Store` | A, B, C | Detect values assigned but never used. | SPARK flow analysis: related to GNATprove's Bronze-level "statement has no effect" data-flow diagnostics. | SPARK | Intraprocedural analysis; aliasing, calls, exceptional paths, and unsupported constructs can reduce precision. |
| 23 | `Overwritten_Assignment` | A, B, C | Detect values overwritten before use. | SPARK flow analysis: related to GNATprove's Bronze-level ineffective-assignment diagnostics. | SPARK | Intraprocedural and conservative; it is not a complete all-path def-use proof. |
| 24 | `Uninitialized_Output` | A, B, C | Ensure outputs are defined on every normal return path. | SPARK flow analysis: every mode-out global and parameter must be fully initialized on every normal return path (Bronze level). | SPARK | Intraprocedural normal-return analysis; exceptional termination and unsupported constructs limit the conclusion. |
| 25 | `Global_Contract_Mismatch` | A, B, C | Ensure declared global effects match implementation behavior. | SPARK `Global` aspect legality and flow-analysis rule (Bronze level). | SPARK | Requires applicable SPARK `Global` contracts and supported effect inference; absence of a contract is not reported by this enabled check. |
| 26 | `Incomplete_Depends_Contract` | A, B, C | Declare all outputs in information-flow contracts. | SPARK `Depends` aspect completeness rule (Bronze level). | SPARK | Checks selected omissions in SPARK `Depends`; it does not by itself validate the complete dependency relation. |
| 27 | `Depends_Contract_Mismatch` | A, B, C | Keep declared input-to-output dependencies consistent with code. | SPARK `Depends` aspect consistency rule (Bronze level). | SPARK | Based on supported inferred data and control flow; indirect, concurrent, imported, or unsupported effects need other evidence. |
| 28 | `Function_Side_Effect` | A, B, C | Make state changes explicit in interfaces and call sites. | SPARK legality rule: a SPARK function must not have side effects on global state; state-changing operations must be expressed as procedures. | SPARK | Detects assignments to visible external state; effects through aliases, imported code, volatile hardware, or unknown calls may escape analysis. |
| 29 | `No_Recursion` | A, B, C | Keep stack usage and call behavior bounded and analyzable. | Ada RM Annex H restriction identifier `No_Recursion` (D.7). | Restriction | Detects direct recursion; mutually recursive call cycles require a whole-program call-graph assessment. |
| 30 | `Non_Short_Circuit_Condition` | A, B, C | Prevent unintended evaluation and side effects in conditions. | General coding practice; relates to SPARK's requirement that expression evaluation be free of order-dependent side effects, but is not itself a named SPARK rule. | Practice | Applies to selected controlling conditions; it does not perform a complete expression side-effect or evaluation-order analysis. |
| 31 | `Suppression_Without_Rationale` | A, B | Ensure every inline analyzer deviation has a reviewable reason. | General deviation-control practice; not itself an Annex H restriction identifier or SPARK Reference Manual rule. | Practice | Checks inline analyzer suppressions only; baselines still need an external rationale, owner, approval, scope, and expiry record. |
| 32 | `No_Dynamic_Allocation` | A, B | Keep memory consumption, allocation failure, and execution time bounded. | Ada RM Annex H restriction identifier `No_Allocators` (D.7). | Restriction | Detects Ada allocators; custom pools, imported allocators, container internals, and start-up-only allocation need project controls. |
| 33 | `No_Unchecked_Conversion` | A, B | Prevent representation reinterpretation that bypasses the type system. | Ada RM 13.12.1 `pragma Restrictions (No_Dependence => Ada.Unchecked_Conversion)`; SPARK requires each unchecked conversion instance to be independently justified. | Restriction | Detects semantic instantiations of `Ada.Unchecked_Conversion`; interfacing code and other unchecked facilities remain separate concerns. |
| 34 | `No_Unchecked_Access` | A, B | Prevent an accessibility-bypassing access value from outliving its designated object. | Ada RM Annex H restriction identifier `No_Unchecked_Access` (D.7); SPARK does not permit `'Unchecked_Access` in `SPARK_Mode => On` code. | Restriction | Detects every use of the `'Unchecked_Access` attribute; a matching-accessibility-level `'Access` and other access-safety concerns remain separate. |
| 35 | `No_Unchecked_Deallocation` | A, B | Prevent dangling references, double release, and use after free. | Ada RM 13.12.1 `pragma Restrictions (No_Dependence => Ada.Unchecked_Deallocation)`; SPARK's ownership model manages deallocation without this generic instantiation. | Restriction | Detects semantic instantiations of the Ada unchecked facility; foreign deallocators and custom storage management are outside its scope. |
| 36 | `Complete_Initialization` | A, B | Require explicit initial values for objects and record components. | SPARK flow analysis: SPARK's default full-initialization policy for objects and record components (Bronze level). | SPARK | A syntactic/semantic initialization policy is not proof that the chosen value is valid or that later reads are initialized. |
| 37 | `Uninitialized_Read` | A, B | Detect scalar locals whose first use is a read. | SPARK flow analysis: use-before-initialization is a core Bronze-level flow-soundness diagnostic. | SPARK | Limited to supported scalar local flow; arrays, records, aliases, calls, exceptional paths, and unsupported constructs can require stronger analysis. |
| 38 | `No_Dispatching_Call` | A, B | Keep runtime call targets bounded and reviewable. | Ada RM Annex H restriction identifier `No_Dispatch` (D.7). | Restriction | Detects semantically resolved dispatching and access-to-subprogram calls; unresolved or imported dispatch mechanisms require review. |
| 39 | `Missing_Global_Contract` | A, B | Require declared global effects for every subprogram that has them. | SPARK `Global` aspect completeness rule (Bronze level); pairs with `Global_Contract_Mismatch`, which checks consistency once a contract exists. | SPARK | Reports subprograms that access global state without an explicit `Global` contract; subprograms with no global access need no contract and are not reported. |
| 40 | `Missing_Depends_Contract` | A, B | Require declared information-flow contracts for every subprogram that has outputs. | SPARK `Depends` aspect completeness rule (Bronze level); pairs with `Depends_Contract_Mismatch` and `Incomplete_Depends_Contract`, which check consistency and partial omission once a contract exists. | SPARK | Reports subprograms with outputs but no explicit `Depends` contract; it does not validate the relation once one is present. |
| 41 | `Missing_Loop_Variant` | A, B | Require termination evidence for annotated proof loops. | SPARK `Loop_Variant` aspect, used by GNATprove to prove loop termination. | SPARK | Applies only when a loop already has a `Loop_Invariant`; it does not require or prove termination for every loop. |
| 42 | `Potentially_Blocking_Operation` | A, B | Avoid blocking while holding protected synchronization state. | Ada RM 9.5.1's normative definition of a potentially blocking operation, which a protected operation must not invoke. | Restriction | Covers selected direct and transitively summarized Ada blocking operations; scheduling and WCET evidence remain external. |
| 43 | `No_Compiler_Extensions` | A, B | Keep the language subset portable and compiler behavior controlled. | General portability practice grounded in the Ada RM's definition of a conforming, standard-defined program; both high-integrity Ada and SPARK guidance require staying within standard, non-implementation-defined constructs. | Practice | Detects selected implementation-defined pragmas; compiler switches, predefined environment, runtime library, and all implementation-defined behavior need a configuration record. |
| 44 | `Library_Level_Initialization` | A, B | Avoid hidden, fallible, or order-dependent elaboration work. | Ada RM 10.2 elaboration-order rules and the `Preelaborate`/`Pure` categorization pragmas used to keep elaboration predictable. | Restriction | Reports calls in library-level initializers; complete Ada elaboration-order correctness and runtime start-up behavior need other evidence. |
| 45 | `Cyclomatic_Complexity` | A, B | Bound the number of independent control-flow paths requiring review and test. | General coding practice; not addressed by Annex H or the SPARK Reference Manual. | Practice | Uses a configurable structural count; the threshold and any deviation need project justification. |
| 46 | `Deep_Nesting` | A, B | Keep control structure locally understandable and testable. | General coding practice; not addressed by Annex H or the SPARK Reference Manual. | Practice | Uses a configurable nesting threshold; it does not measure semantic or architectural complexity. |

## Rules by DO-178C objective

`--compliance-report=do178c` groups the same 46 checks under five
non-normative objectives (see `src/adalang_analyzer-compliance_mapping.adb`
for the authoritative mapping the report generator actually uses — this
section is a cross-reference for this document, not a second source of
truth):

- **Traceability** — `Missing_Requirement_Trace`, `Malformed_Requirement_Trace`.
- **Standards conformance** — the 16 checks listed above under levels "A, B"
  only (the Level A/B coding-restriction tier in full).
- **Accuracy and consistency** — the 19 Core-tier checks plus `Dead_Store`,
  `Overwritten_Assignment`, `Uninitialized_Output`, `Global_Contract_Mismatch`,
  `Incomplete_Depends_Contract`, `Depends_Contract_Mismatch`,
  `Function_Side_Effect`, `No_Recursion`, and `Non_Short_Circuit_Condition`.
- **Verifiability** — `No_Recursion`, `No_Dispatching_Call`,
  `Potentially_Blocking_Operation`.
- **Deviation control** — `Suppression_Without_Rationale`.

A check can appear under more than one objective (for example `No_Recursion`
is both an accuracy/consistency and a verifiability concern); this is the
same "different cut of the same rules" relationship
`compliance_mapping.adb`'s own header comment describes, not a duplicated
claim.

## Coverage summary

The profile has useful concentration in these areas:

- Selected known run-time failures for scalar Ada, largely mirroring SPARK's
  Gold-level (absence of run-time errors) proof obligations.
- Exception handling completeness and ordering — swallowed exceptions,
  empty handlers, and unreachable handlers.
- Initialization and selected data-flow anomalies, largely mirroring SPARK's
  Bronze-level flow-analysis concerns, at levels A-C.
- SPARK `Global`/`Depends` contract presence and consistency, at levels A-C.
- Source-to-requirement traceability annotations, at levels A-C.
- The strictest Ada Annex H coding restrictions (no dynamic allocation, no
  unchecked conversion/deallocation, no dispatching calls, mandatory
  suppression rationale), at levels A-B only.

This makes `--do178c` a credible **DO-178C source-code verification-support
screen**, especially when used before GNATprove, a requirements-based test
campaign, or a structural coverage tool. It does not make the profile a
qualified DO-178C tool, a substitute for the verification activities it does
not automate, or evidence of having satisfied any specific Annex A objective
without the corresponding project evidence.

## Gap register

The following gaps prevent a DO-178C compliance or objective-satisfaction
claim. "Not applicable" must be justified by the project rather than
inferred merely because a listed activity sounds unrelated to Ada.

| Gap | Current status | Recommended project or product action |
|---|---|---|
| Structural coverage | Not measured. The selected level's expected objective (MC/DC, decision, or statement) is recorded as metadata only. | Use a target-aware coverage workflow such as GNATcoverage; reconcile its results against the recorded objective. |
| Requirements-based testing | Not performed. AdaLang neither generates nor executes tests. | Supply a requirements-based test campaign and retain its evidence separately. |
| Object code verification | Not performed. Source-level analysis only; compiler output is not examined. | Perform object code verification where the applicable DO-178C level requires it. |
| Tool qualification (DO-330) | Not supplied. | Projects taking certification credit from analyzer results must separately assess tool qualification under DO-330; see [FAA AC 20-115D](https://www.faa.gov/regulations_policies/advisory_circulars/index.cfm/go/document.information/documentID/1032046). |
| Project-wide bidirectional traceability | `Missing_Requirement_Trace`/`Malformed_Requirement_Trace` check same-file comment annotations only; there is no requirements database, no traceability from requirement to test, and no cross-file resolution. | Use the project's lifecycle toolchain to trace requirements, design, code, analysis findings, tests, and certification data items bidirectionally. |
| Directive-by-directive Annex A mapping | The categories above are AdaLang's own paraphrase of publicly discussed Annex A Table A-5 activity headings. No normative mapping to the licensed DO-178C text exists in this document. | Have competent reviewers classify every applicable Annex A objective against a licensed copy of DO-178C, for the selected software level. |
| Complete run-time error analysis | Only supported known-failure classes and bounded obligations are classified. | Use GNATprove to reach the applicable SPARK verification level (Bronze through Platinum) for components that require it. |
| Exception-handling completeness | Swallowed handlers, empty handlers, and one class of unreachable handler are checked; implicit language-defined exceptions and exceptions raised by callees are only conservatively summarized. | Define permitted exceptions and boundaries; combine restrictions, proof (or explicit `Exceptional_Cases` contracts), last-chance-handler behavior, and fault-injection tests. |
| Restricted runtime and compiler configuration | Source pragmas are partially checked (`No_Compiler_Extensions`); compiler switches, target configuration, and runtime library selection are not. | Baseline compiler version and switches, language mode, restrictions profile, runtime library, binder/linker switches, and target configuration as project evidence. |
| Standard and third-party libraries | Not evaluated for DO-178C applicability. | Maintain an approved-component inventory with versions, usage constraints, provenance, and qualification status for the selected level. |
| Generated and externally developed code | No component-status compliance record exists. | Classify generated, reused, C, assembly, runtime, and binary-only components and define their acceptance evidence. |
| Deviations and suppressions | `Suppression_Without_Rationale` (levels A-B) requires an inline rationale comment; it does not carry controlled deviation metadata (owner, approval, expiry). | Define deviation authority and expiry, and generate a deviation report tied to rule, location, risk, and verification. |
| Independent validation corpus | Rule fixtures test expected findings and clean cases (`quality/do178c_rule_evidence.tsv`); `quality/precision_corpus.tsv` additionally covers threshold and negative behavior for some of these checks. | Extend boundary/negative coverage; add project-scale and independent-oracle tests with measured false-positive and false-negative results. |
| Compliance reporting | `--compliance-report=do178c` generates a per-objective evidence report. `--compliance-report-format=json` produces the same objectives, suppression trail, baseline-matched findings, and unsupported-activity list as a machine-readable document for tooling (CI gates, dashboards); `markdown` (default) is unchanged. SARIF is deliberately not offered for this report — its result-oriented schema has no natural slot for the objective/evidence structure; see `--format=sarif` for a SARIF rendering of the underlying findings. | None; consume the JSON form, or request additional fields if a specific tooling integration needs them. |
| Tool confidence and qualification | No DO-330 tool-qualification artifact is supplied. | Perform the applicable tool operational requirement (TOR) and tool qualification level (TQL) assessment; document failure modes, detection controls, and version pinning. |

## Minimum defensible workflow

A project may use this matrix as the starting point for a DO-178C
source-code verification-support assessment:

1. Freeze the AdaLang version, compiler, runtime, target, project scenario,
   `--do178c` level, and analyzer configuration.
2. Confirm the selected software level (A/B/C/D) against the project's own
   System Safety Assessment and DO-178C Software Level determination — this
   matrix does not select a level for a project.
3. Review every applicable Annex A objective for the selected level against
   a licensed copy of DO-178C, and replace the conceptual categories above
   with approved objective identifiers and enforcement methods.
4. Record every unsupported or partially supported objective (see the gap
   register) as a manual, proof, test, compiler, or process obligation.
5. Adopt the `-- do-178c: req <id>` annotation convention project-wide if
   source-to-requirement traceability credit is sought, and connect it to
   the project's actual requirements database — the annotation alone is not
   a traceability record.
6. Control deviations with rationale, risk analysis, approval, scope, and
   expiry, beyond the inline `rationale:` text this analyzer checks for.
7. Retain analyzer diagnostics, skipped/unsupported results, baselines,
   manual reviews, GNATprove proof reports, structural coverage results,
   requirements-based test results, and target evidence.
8. Assess tool confidence and perform the DO-330 tool qualification
   activities required by the project's certification basis.

Only the resulting project evidence — not invocation of `--do178c` — can
support a certification liaison argument.
