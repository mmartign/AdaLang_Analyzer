# AdaLang Analyzer vs. GNATcheck: rule catalog comparison

This is a **documentation-based** comparison: AdaLang Analyzer's 112 checks
(`src/adalang_analyzer-rules.ads`) mapped against GNATcheck's predefined-rule
catalog as described in the [GNATcheck Reference
Manual](https://docs.adacore.com/live/wave/lkql/html/gnatcheck_rm/gnatcheck_rm/predefined_rules.html)
and the [gnatcheck repository](https://github.com/AdaCore/gnatcheck). No
`gnatcheck` binary was run to produce this table -- getting one built was
attempted and shelved (no Alire package; source build is a 6+ AdaCore-repo
bootstrap prone to version-mismatch failures across the seams). Running both
tools on the same corpus and comparing actual findings remains the open item
tracked in `AUTOMOTIVE_ADA_COMPLIANCE_MATRIX.md`'s roadmap
("independent-oracle (e.g. GNATcheck) tests with measured false-positive and
false-negative results"); this document is the rule-name-level groundwork for
that, not a substitute for it.

Rule names and one-line descriptions for GNATcheck come from the reference
manual page; they were not cross-checked against the gnatcheck source, so
edge-case semantics may differ from what's summarized here.

## Summary

Of AdaLang Analyzer's 112 checks:

| Match strength | Count | Meaning |
| --- | --- | --- |
| Direct | 18 | Same check, essentially the same semantics |
| Close | 14 | Same intent, minor scope difference |
| Partial | 18 | Overlaps only through a GNATcheck configurable/generic mechanism (`Restrictions`, `Forbidden_Pragmas`, `Style_Checks`), or covers a narrower/wider case |
| No GNATcheck counterpart | 62 | Nothing in the predefined catalog does this |

GNATcheck's own catalog runs to roughly 180 predefined rules; large families
of it (identifier casing/prefixes/readability, OOP-depth metrics,
portability, and "prefer modern Ada construct X over Y" style suggestions)
have no AdaLang Analyzer counterpart at all -- see the last section.

## AdaLang rules with a direct or close GNATcheck counterpart

| AdaLang rule | GNATcheck rule(s) | Match |
| --- | --- | --- |
| No_Goto | GOTO_Statements | Direct |
| No_Abort | Abort_Statements | Direct |
| No_Access_To_Subp_Def | Subprogram_Access | Direct |
| Floating_Equality | Float_Equality_Checks | Direct |
| Same_Operand | Same_Operands | Direct |
| Duplicate_Condition | Same_Tests | Direct |
| Null_Statement | Redundant_Null_Statements | Direct |
| Empty_Exception_Handler | Silent_Exception_Handlers | Direct |
| Identical_Branches | Duplicate_Branches | Direct |
| No_Recursion | Recursive_Subprograms | Direct |
| No_Multiple_Return | Improper_Returns | Direct |
| Non_Short_Circuit_Condition | Non_Short_Circuit_Operators | Direct |
| Too_Many_Parameters | Maximum_Parameters | Direct |
| Deep_Nesting | Overly_Nested_Control_Structures | Direct |
| Cyclomatic_Complexity | Metrics_Cyclomatic_Complexity | Direct |
| Aliasing_Between_Parameters | Parameters_Aliasing, Potential_Parameters_Aliasing | Direct |
| No_Controlled_Type | Controlled_Type_Declarations | Direct |
| Dependency_Limit | Too_Many_Dependencies | Direct |
| No_Pragma | Forbidden_Pragmas | Close (GNATcheck needs an explicit list; AdaLang flags every pragma) |
| Magic_Number | Numeric_Literals | Close |
| Infinite_Loop | Simple_Loop_Statements | Close |
| Duplicate_Boolean_Operand | Same_Operands, Redundant_Boolean_Expressions | Close |
| Exception_Swallowed | Silent_Exception_Handlers, Trivial_Exception_Handlers | Close |
| Address_Clause | At_Representation_Clauses, Address_Specifications_For_* | Close |
| Empty_If_Body | Null_Paths | Close |
| Redundant_Boolean_Comparison | Redundant_Boolean_Expressions, Boolean_Negations | Close |
| Missing_Global_Contract | SPARK_Procedures_Without_Globals | Close |
| Uninitialized_Output | Unassigned_OUT_Parameters | Close |
| Identical_Case_Alternative | Duplicate_Branches | Close (case-alternative-specific) |
| Exception_Propagation | Exception_Propagation_From_Callbacks/Export/Tasks | Close |
| Library_Level_Initialization | Calls_Outside_Elaboration | Close |
| Naming_Convention | Min_Identifier_Length | Close |

## AdaLang rules that only partially overlap GNATcheck

These need a GNATcheck configurable/generic mechanism to approximate, or
cover a different-shaped case than the nearest predefined rule.

| AdaLang rule | Nearest GNATcheck mechanism | Why only partial |
| --- | --- | --- |
| No_Raise | Raising_Predefined_Exceptions, Raising_External_Exceptions | GNATcheck restricts specific exception *categories*, not "no raise statement" wholesale |
| No_Exit | Unconditional_Exits | GNATcheck flags unconditional exits specifically, not every exit statement |
| No_Unchecked_Conversion | Unchecked_Conversions_As_Actuals | GNATcheck only flags UC used as an actual parameter, not every instantiation |
| Unreachable_Branch | Null_Paths | Different shape: empty branch body vs. statically-unreachable branch |
| Function_Side_Effect | Side_Effect_Parameters, Outside_References_From_Subprograms | Neither is "function writes to state other than locals/params" specifically |
| Long_Line | Style_Checks (`-gnatyM`) | Only available as a style-switch wrapper, not a standalone configurable rule |
| Trailing_Whitespace | Style_Checks | Same, style-switch wrapper only |
| Uninitialized_Read | Uninitialized_Global_Variables | GNATcheck's version is global-scope only; AdaLang's is local scalars |
| No_Dynamic_Allocation | Restrictions (`No_Allocators`) | Only via the generic `pragma Restrictions` wrapper rule |
| Restricted_Access_Type | Anonymous_Access | GNATcheck's covers anonymous access types only, not named ones |
| No_Unchecked_Deallocation | Restrictions | No dedicated rule; only via the generic wrapper |
| No_Tasking | Restrictions (`No_Tasking`) | Only via the generic wrapper |
| Complete_Initialization | Default_Values_For_Record_Components | GNATcheck's is record-components only, not all objects |
| Volatile_Atomic_Consistency | Volatile_Objects_Without_Address_Clauses | Related but checks a different consistency condition |
| Representation_Clause_Policy | Representation_Specifications, Misplaced_Representation_Items | Different framing (presence/placement vs. AdaLang's policy-centralization check) |
| Generic_Instantiation_Limit | Too_Many_Generic_Dependencies, Deeply_Nested_Instantiations | Related metrics, different thresholded quantity |
| No_Compiler_Extensions | Forbidden_Pragmas, Forbidden_Aspects | Only via explicit configured lists |
| No_Runtime_Check_Suppression | Restrictions / Forbidden_Pragmas | Only via generic wrappers, not a dedicated suppression-policy rule |

## AdaLang rules with no GNATcheck predefined-rule counterpart

62 of AdaLang's 112 rules do something GNATcheck's predefined catalog does
not attempt at all. They cluster into a few groups:

**Flow-sensitive "provably fails" defect detection** (this is GNATprove/
CodePeer territory, not GNATcheck's syntactic/semantic rule matching):
Known_Precondition_Failure, Known_Postcondition_Failure,
Known_Assertion_Failure, Known_Range_Check_Failure, Known_Index_Check_Failure,
Known_Overflow_Failure, Known_Discriminant_Check_Failure,
Succ_Pred_Boundary_Overflow.

**SPARK contract consistency** (Global/Depends contracts checked against
actual code behavior, not just presence):
Global_Contract_Mismatch, Missing_Depends_Contract,
Incomplete_Depends_Contract, Depends_Contract_Mismatch, SPARK_Mode.

**DO-178C-specific, unique to AdaLang's compliance tooling**:
Missing_Requirement_Trace, Malformed_Requirement_Trace,
Suppression_Without_Rationale.

**Dataflow/liveness defects** (dead code and value-flow bugs GNATcheck's
purely syntactic matching doesn't reach):
Dead_Store, Overwritten_Assignment, Unreachable_Case_Alternative,
Overlapping_Case_Ranges, Constant_Condition, Unreachable_Code,
Division_By_Zero, Integer_Division_Before_Multiplication,
Excessive_Shift_Amount, Reversed_Range,
Self_Assignment, Contradictory_Condition,
Repeated_Statement, Ineffective_Operation, Constant_Result_Operation,
Empty_Loop, Unnecessary_Else_After_Return, Redundant_Type_Conversion,
Handler_Order.

**Everything else** (no close GNATcheck family at all):
No_Label, Unused_Parameter, Wrong_Parameter_Mode, Swappable_Parameters,
Assertion_Side_Effect, Shadowed_Declaration,
Missing_Overriding_Indicator, Inefficient_String_Concatenation,
Circular_Package_Dependency, Duplicate_Subprogram, Missing_Loop_Variant,
Potentially_Blocking_Operation, No_Explicit_Dereference, No_Rendezvous,
No_Select, No_Requeue, No_Asynchronous_Transfer, No_Dispatching_Call,
No_Classwide_Type, Unused_Variable, No_Unchecked_Access,
Duplicate_With_Clause, Reraise_Discards_Occurrence,
Duplicate_Exception_Choice, Redundant_If_Boolean_Return,
Redundant_Final_Return, Entry_Barrier_Side_Effect.

(Several of these -- Unused_Parameter, Unused_Variable, Shadowed_Declaration,
Missing_Overriding_Indicator, Dead_Store -- are things GNAT itself reports as
compiler warnings, just not as a GNATcheck rule.)

## GNATcheck rule families with no AdaLang Analyzer counterpart

GNATcheck's predefined catalog has entire families AdaLang does not attempt:

- **Identifier readability/naming**: Identifier_Casing, Identifier_Prefixes,
  Identifier_Suffixes, Max_Identifier_Length, Headers, End_Of_Line_Comments,
  Object_Declarations_Out_Of_Order, One_Construct_Per_Line, Numeric_Format,
  Uncommented_BEGIN(_In_Package_Bodies), Uncommented_End_Record,
  Name_Clashes, Misnamed_Controlling_Parameters. AdaLang has exactly one
  naming rule (Naming_Convention, single-character identifiers).
- **OOP structural metrics**: Deep_Inheritance_Hierarchies, Too_Many_Parents,
  Too_Many_Primitives, Constructors, Visible_Components,
  One_Tagged_Type_Per_Package, Specific_Pre_Post, Specific_Type_Invariants,
  Direct_Calls_To_Primitives, Downward_View_Conversions.
- **Portability**: Bit_Records_Without_Layout_Definition,
  No_Scalar_Storage_Order_Specified, Predefined_Numeric_Types,
  Printable_ASCII, Implicit_SMALL_For_Fixed_Point_Types,
  Incomplete_Representation_Specifications.
- **"Prefer modern Ada construct" style suggestions**: Use_Case_Statements,
  Use_If_Expressions, Use_For_Loops, Use_For_Of_Loops, Use_Ranges,
  Use_Record_Aggregates, Use_Memberships, Use_Array_Slices,
  Use_Simple_Loops, Use_While_Loops, Expression_Functions,
  Conditional_Expressions, Quantified_Expressions.
- **Positional-actual/parameter-ordering style**: Positional_Parameters,
  Positional_Components, Positional_Generic_Parameters,
  Positional_Actuals_For_Defaulted_Parameters,
  Positional_Actuals_For_Defaulted_Generic_Parameters,
  Parameters_Out_Of_Order.
- **Generic policy wrappers** with no fixed AdaLang equivalent because
  AdaLang's rules are individually named rather than configured through one
  umbrella mechanism: `Restrictions` (wraps `pragma Restrictions`),
  `Warnings` (wraps compiler warnings), `Style_Checks` (wraps `-gnaty`
  switches).
- **Everything else with no AdaLang analog**: USE_Clauses,
  USE_PACKAGE_Clauses, Local_USE_Clauses, Renamings, Operator_Renamings,
  Separates, Nested_Subprograms, Local_Packages, Local_Instantiations,
  Anonymous_Arrays, Anonymous_Subtypes, Discriminated_Records,
  Unconstrained_Arrays, Unconstrained_Array_Returns, and roughly 50 more
  narrowly-scoped Feature Usage / Programming Practice rules not itemized
  here (see the reference manual for the full list).

## Reading this comparison

AdaLang Analyzer is not a GNATcheck replacement and does not claim to be
(see `POSITIONING.md`). The rules that don't map are not a coverage gap to
close one-for-one -- most of GNATcheck's unmatched catalog is style/
readability preference (naming conventions, "prefer this Ada 2012+
construct") that AdaLang deliberately doesn't attempt, while most of
AdaLang's unmatched rules are exactly the flow-sensitive and SPARK-contract
checks that are its actual differentiator (see "AdaLang's defensible
distinction" in `POSITIONING.md`'s GNATcheck section). The useful reading is
per-family: where AdaLang has a direct/close match, GNATcheck's version is
almost certainly more mature and configurable; where AdaLang has no match,
that's either intentionally out of scope (naming/readability) or the actual
value proposition (flow-sensitive defects, SPARK contract consistency,
DO-178C traceability).
