# AdaLang Analyzer vs. GNATcheck: rule catalog comparison

This document maps AdaLang Analyzer's 302 checks
(`src/adalang_analyzer-rules.ads`) against GNATcheck's predefined-rule
catalog as described in the [GNATcheck Reference
Manual](https://docs.adacore.com/live/wave/lkql/html/gnatcheck_rm/gnatcheck_rm/predefined_rules.html)
and the [gnatcheck repository](https://github.com/AdaCore/gnatcheck) —
which pairs to compare and why. It is not just documentation-level
groundwork: `benchmarks/README.md`'s "GNATcheck oracle comparison" section
runs both tools against all ten of this project's external validation
corpora, and several of the "Close" annotations below cite specific,
measured findings from that run, including two real AdaLang coverage gaps
it found and fixed (`FP-053`, `FP-054` in
`quality/known_analysis_issues.tsv`).

Rule names and one-line descriptions for GNATcheck come from the reference
manual page; they were not cross-checked against the gnatcheck source, so
edge-case semantics may differ from what's summarized here.

## Summary

Of AdaLang Analyzer's 302 checks:

| Match strength | Count | Meaning |
| --- | --- | --- |
| Direct | 179 | Same check, essentially the same semantics |
| Close | 28 | Same intent, minor scope difference |
| Paired through configuration | 17 | Same check, but it reports nothing until its parameters say what to look for, so the benchmark corpora cannot run it |
| Partial | 17 | Overlaps only through a GNATcheck configurable/generic mechanism (`Restrictions`, `Forbidden_Pragmas`, `Style_Checks`), or covers a narrower/wider case |
| No GNATcheck counterpart | 61 | Nothing in the predefined catalog does this |

Seen from GNATcheck's side: its catalog holds 335 rules, of which 123 are
`kp_*` detectors for known problems in specific GNAT compiler releases and
are out of scope here. Each of the other 212 has an AdaLang counterpart.

175 of the Direct, Close and configuration-paired checks were added
together as opt-in coding-standard checks. None of them belongs to a preset:
each is selected by name, and those with a limit or a list take it from
`-rule-param=<check>.<name>=<value>` (see `configuration.md`). Their scope
follows the behaviour of the GNATcheck rule they are paired with, and each
was compared with GNATcheck, by file and line, on its own fixtures, on the
rest of this repository's test fixtures (about 700 files) and on the
analyzer's own sources. They agree everywhere both tools can resolve the
code, with one deliberate exception (`Declaration_In_Block`, below).

The 158 of them that run without configuration were then run over the ten
external benchmark corpora (`benchmarks/README.md`, "GNATcheck oracle
comparison"). Over the files both tools analysed, GNATcheck reports 93447 of
AdaLang's 93771 findings at the same file and line (99.7%), and AdaLang
reports 99.8% of GNATcheck's 93631. Those runs exposed and led to the fix of
`FP-102` (names were resolved only within the root project) and `FP-103`
(sources that use the preprocessor did not parse). What AdaLang still
misses is mostly in the instances of generic units, which it does not
follow.

## AdaLang rules with a direct or close GNATcheck counterpart

| AdaLang rule | GNATcheck rule(s) | Match |
| --- | --- | --- |
| No_Goto | GOTO_Statements | Direct |
| No_Abort | Abort_Statements | Direct |
| No_Access_To_Subp_Def | Subprogram_Access | Direct |
| Floating_Equality | Float_Equality_Checks | Direct |
| Same_Operand | Same_Operands | Direct |
| Duplicate_Condition | Same_Tests | Direct (GNATcheck flags the first of two identical tests; the lane matches on the line it names, the one AdaLang reports) |
| Null_Statement | Redundant_Null_Statements | Direct (confirmed 2026-09-22 via the AWS corpus's GNATcheck oracle comparison, `FP-066` -- AdaLang originally flagged every `null;` unconditionally, including the sole-statement idiom GNATcheck's own rule exempts (an empty exception handler, a no-op case alternative); fixed to exempt the same sole-statement and labeled-null shapes GNATcheck does, eliminating all 88 of the AWS corpus's false positives) |
| Empty_Exception_Handler | Silent_Exception_Handlers | Direct |
| Identical_Branches | Duplicate_Branches | Direct (confirmed 2026-09-24: the oracle lane runs `Duplicate_Branches` with `min_stmt=1,min_size=1`, since its defaults of 4 statements / 14 tokens hid every pair, and matches on the line GNATcheck names as the duplicate, which is the one AdaLang reports. AdaLang compares adjacent branches only, so GNATcheck's non-adjacent pairs stay GNATcheck-only) |
| No_Recursion | Recursive_Subprograms | Direct |
| No_Multiple_Return | Improper_Returns | Direct |
| Non_Short_Circuit_Condition | Non_Short_Circuit_Operators | Direct |
| Too_Many_Parameters | Maximum_Parameters | Direct |
| Deep_Nesting | Overly_Nested_Control_Structures | Direct (name-level match only; confirmed 2026-09-22 via the GNATcheck oracle comparison that the two report on structurally different terms and will essentially never share an exact `(file, line)` -- GNATcheck's LKQL rule fires on *every* control-structure node whose ancestor chain exceeds its `n` parameter (default 3), so one deeply-nested chain yields several findings, each at that construct's own line; AdaLang instead computes the subprogram's single maximum nesting depth and reports one finding at the subprogram's name line if it exceeds a threshold of 4. Not a bug on either side -- same granularity/location gap as `Too_Many_Parameters`/`No_Multiple_Return` below) |
| Cyclomatic_Complexity | Metrics_Cyclomatic_Complexity | Direct |
| Aliasing_Between_Parameters | Parameters_Aliasing, Potential_Parameters_Aliasing | Direct |
| No_Controlled_Type | Controlled_Type_Declarations | Direct |
| Dependency_Limit | Too_Many_Dependencies | Direct |
| Missing_Overriding_Indicator | Overriding_Indicators | Direct (found 2026-08-19 while cross-checking this document against `gnatcheck --list-rules`'s real output, not available when this comparison was first written; was previously miscategorized as "no GNATcheck counterpart"). Paired in the benchmark lane from 2026-09-23, which found `FP-074`: a body completing a declaration that already says `overriding` was reported |
| No_Pragma | Forbidden_Pragmas | Close (GNATcheck needs an explicit list; AdaLang flags every pragma) |
| Magic_Number | Numeric_Literals | Close |
| Infinite_Loop | Simple_Loop_Statements | Close |
| Duplicate_Boolean_Operand | Same_Operands, Redundant_Boolean_Expressions | Close |
| Exception_Swallowed | Silent_Exception_Handlers, Trivial_Exception_Handlers | Close |
| Address_Clause | At_Representation_Clauses, Address_Specifications_For_* | Close (confirmed 2026-08-19 via `gnatcoll-core`: `Address_Specifications_For_*` mostly agrees but reports at the object declaration's line, not the clause's, so line-exact comparators show 0% despite real agreement. AdaLang previously missed the aspect-syntax form (`with Address => ...;`) and the obsolescent `for X use at ADDR;` form entirely; fixed as `FP-054` and `FP-055` respectively — none of this project's ten corpora happen to exercise the latter, so `FP-055` was confirmed with a minimal reproduction rather than a live corpus finding) |
| Empty_If_Body | Null_Paths | Close (undersells the gap, confirmed 2026-08-19 via `ada_drivers_library`: `Empty_If_Body` is deliberately scoped to plain `if` statements with no `elsif`/`else`, by its own documented description; `Null_Paths` also flags empty `case` alternatives and `if`/`elsif` legs, which `Empty_If_Body` was never designed to see. The case-alternative half of that gap is now covered separately by `Null_Case_Alternative`, and the elsif-branch half by `Empty_Elsif_Body`, both added 2026-08-19) |
| Empty_Elsif_Body | Null_Paths | Close (elsif-branch-specific; added 2026-08-19 to close the `null_paths`/`Empty_If_Body` elsif-branch gap identified above. Confirmed noisy on this analyzer's own source during implementation, same "deliberate no-op branch" idiom as `Null_Case_Alternative`'s `FP-056`, logged as `FP-057` in `quality/known_analysis_issues.tsv` and fixed with an inline suppression rather than a broader exemption, since an elsif chain has no `others`-equivalent to exempt by construction. Did not flag a bare `if`'s then-branch when an elsif/else is present, or an empty `else` branch — those two narrower-still gaps are now closed separately by `Empty_Then_Body` and `Empty_Else_Body`) |
| Empty_Then_Body | Null_Paths | Close (then-branch-specific; closes the "bare if's then-branch when an elsif/else is present" gap left open by `Empty_If_Body` and `Empty_Elsif_Body` above. Same "deliberate no-op branch" idiom found noisy on this analyzer's own source during implementation as `Empty_Elsif_Body`'s `FP-057`; fixed the same way, with four inline suppressions rather than a broader exemption, since a then branch has no `others`-equivalent to exempt by construction either) |
| Empty_Else_Body | Null_Paths | Close (else-branch-specific; closes the last of the three `null_paths`/`Empty_If_Body` scope gaps identified above. No self-analysis noise found: this analyzer's own source has no deliberate-no-op `else null;` idiom, unlike the then/elsif cases) |
| Null_Case_Alternative | Null_Paths | Close (case-alternative-specific; added 2026-08-19 to close the `null_paths`/`Empty_If_Body` case-alternative gap identified above. Two deliberate scope narrowings versus `Null_Paths`: it does not flag empty `if`/`elsif` legs (now `Empty_Elsif_Body`'s/`Empty_Then_Body`'s scope, not this check's); and it does not flag a catch-all `when others => null;`, since that is a common, deliberate Ada idiom, confirmed noisy on this analyzer's own source during implementation and logged as `FP-056` in `quality/known_analysis_issues.tsv` — see `quality/README.md`'s precision-corpus entry for this check) |
| Redundant_Boolean_Comparison | Redundant_Boolean_Expressions, Boolean_Negations | Close |
| Missing_Global_Contract | SPARK_Procedures_Without_Globals | Close (AdaLang deliberately also fires pre-SPARK-adoption, as a readiness check; GNATcheck's rule only examines code already under SPARK_Mode — confirmed intentional) |
| Uninitialized_Output | Unassigned_OUT_Parameters | Close |
| Identical_Case_Alternative | Duplicate_Branches | Close (case-alternative-specific; covers case statements and, since `FP-079`, case expressions; same threshold and matching notes as Identical_Branches) |
| Exception_Propagation | Exception_Propagation_From_Callbacks/Export/Tasks | Close (undersells the gap in both directions, confirmed across two corpora, 2026-08-19: on `aws`, AdaLang is *broader* — it checks every subprogram lacking an exception boundary, not just callback/`Export`/task boundaries, so most of AdaLang's findings have no GNATcheck counterpart at all. On `cubedos`, GNATcheck's task-specific rule is *broader* in a different way — it flags unguarded calls from task bodies without requiring proof of an explicit raise, while AdaLang only fires when it can trace an explicit `raise` transitively through its own call-graph summaries) |
| Library_Level_Initialization | Calls_Outside_Elaboration | Close |
| Naming_Convention | Min_Identifier_Length | Close |
| Duplicate_With_Clause | Warnings (`-gnatwr`, "redundant with clause") | Direct (through GNATcheck's `Warnings` rule, which passes GNAT compiler warnings through; the comparator splits the `-gnatw` letter by message, see `benchmarks/gnatcheck_compare.awk`) |
| Long_Line | Style_Checks (`-gnatyM120`) | Direct (through GNATcheck's `Style_Checks` rule; 120 is AdaLang's default threshold) |
| Trailing_Whitespace | Style_Checks (`-gnatyb`) | Direct (through GNATcheck's `Style_Checks` rule) |
| Unused_With_Clause | Warnings (`-gnatwu`, unreferenced unit) | Close (through GNATcheck's `Warnings` rule, which passes GNAT compiler warnings through; the comparator splits the `-gnatw` letter by message, see `benchmarks/gnatcheck_compare.awk`). Confirmed 2026-09-23 on `gnatcoll-core`: 22 AdaLang findings against one GNAT warning exposed `FP-069` (with clauses of package renamings such as `GNAT.OS_Lib`, of generic instances, and of units whose use-visible names Libadalang fails to resolve), fixed. Enabling this check in the lane also exposed `FP-078`: an unguarded resolution of the with'd unit abandoned whole files (three on AWS), fixed |
| Unused_Variable | Warnings (`-gnatwu`, unreferenced object) | Close (through GNATcheck's `Warnings` rule, which passes GNAT compiler warnings through; the comparator splits the `-gnatw` letter by message, see `benchmarks/gnatcheck_compare.awk`). GNAT exempts objects named like `Dummy`, `Ignored`, `Unused` or `Junk`; AdaLang does not |
| Unused_Parameter | Warnings (`-gnatwf`) | Close (through GNATcheck's `Warnings` rule, which passes GNAT compiler warnings through; the comparator splits the `-gnatw` letter by message, see `benchmarks/gnatcheck_compare.awk`). GNAT also exempts overriding operations, bodies consisting only of `null;` or a `raise`, and formals named like `Dummy`; AdaLang reports each unreferenced formal |
| Wrong_Parameter_Mode | Warnings (`-gnatwk`, "mode could be "in"") | Close (through GNATcheck's `Warnings` rule, which passes GNAT compiler warnings through; the comparator splits the `-gnatw` letter by message, see `benchmarks/gnatcheck_compare.awk`). GNAT reports only an `in out` formal never modified; AdaLang also reports one never read. Establishing this pairing found `FP-076` (writes through a `for ... of` loop element) and `FP-077` (advice to change modes fixed by overriding or by an `'Access` binding) |
| Overwritten_Assignment | Warnings (`-gnatwm`, "value overwritten at line N") | Close (through GNATcheck's `Warnings` rule, which passes GNAT compiler warnings through; the comparator splits the `-gnatw` letter by message, see `benchmarks/gnatcheck_compare.awk`). `FP-067` and `FP-071` were found while establishing this pairing |
| Dead_Store | Warnings (`-gnatwm`, "value never referenced") | Close (through GNATcheck's `Warnings` rule, which passes GNAT compiler warnings through; the comparator splits the `-gnatw` letter by message, see `benchmarks/gnatcheck_compare.awk`). Establishing this pairing found `FP-070`-`FP-073` on `gnatcoll-core` and SPARKNaCl (writes through access-typed locals, up-level reads from nested bodies, `pragma Inspection_Point` key wipes, and variable-index reads after a slice write) and, across the ten corpora, `FP-075` (values stored into deliberately named sinks such as `Dummy` or `Ignored`, which GNAT's own convention exempts) |
| Redundant_Type_Conversion | Warnings (`-gnatwr`, "redundant conversion") | Close (through GNATcheck's `Warnings` rule, which passes GNAT compiler warnings through; the comparator splits the `-gnatw` letter by message, see `benchmarks/gnatcheck_compare.awk`) |
| Self_Assignment | Warnings (`-gnatwr`, "useless assignment of X to itself") | Close (through GNATcheck's `Warnings` rule, which passes GNAT compiler warnings through; the comparator splits the `-gnatw` letter by message, see `benchmarks/gnatcheck_compare.awk`) |
| Constant_Condition | Warnings (`-gnatwc`) | Close (through GNATcheck's `Warnings` rule, which passes GNAT compiler warnings through; the comparator splits the `-gnatw` letter by message, see `benchmarks/gnatcheck_compare.awk`). GNAT's constant-condition warnings cover fewer shapes than AdaLang's flow domain |
| No_Use_Package_Clause | `use_package_clauses` | Direct |
| Others_In_Case_Statement | `others_in_case_statements` | Direct |
| Others_In_Exception_Handler | `others_in_exception_handlers` | Direct |
| Others_In_Aggregate | `others_in_aggregates` | Direct |
| Unnamed_Exit | `unnamed_exits` | Direct |
| Unnamed_Block_Or_Loop | `unnamed_blocks_and_loops` | Direct |
| Implicit_In_Mode | `implicit_in_mode_parameters` | Direct |
| Function_Out_Parameter | `function_out_parameters` | Direct |
| Raising_Predefined_Exception | `raising_predefined_exceptions` | Direct |
| Anonymous_Array_Type | `anonymous_arrays` | Direct |
| Enumeration_Representation_Clause | `enumeration_representation_clauses` | Direct |
| Relative_Delay | `relative_delay_statements` | Direct |
| No_Block_Statement | `blocks` | Direct |
| Global_Variable | `global_variables` | Direct |
| Predefined_Numeric_Type | `predefined_numeric_types` | Direct |
| Abstract_Type_Declaration | `abstract_type_declarations` | Direct |
| Exit_From_Conditional_Loop | `exits_from_conditional_loops` | Direct |
| Expanded_Loop_Exit_Name | `expanded_loop_exit_names` | Direct |
| Conditional_Expression | `conditional_expressions` | Direct |
| Quantified_Expression | `quantified_expressions` | Direct |
| Membership_Test | `membership_tests` | Direct |
| Generic_In_Out_Object | `generic_in_out_objects` | Direct |
| Generic_In_Subprogram | `generics_in_subprograms` | Direct |
| Local_Use_Clause | `local_use_clauses` | Direct |
| Library_Level_Subprogram | `library_level_subprograms` | Direct |
| Multiple_Protected_Entries | `multiple_entries_in_protected_definitions` | Direct |
| Non_Tagged_Derived_Type | `non_tagged_derived_types` | Direct |
| No_Closing_Name | `no_closing_names` | Direct |
| Operator_Renaming | `operator_renamings` | Direct |
| Overloaded_Operator | `overloaded_operators` | Direct |
| Single_Value_Enumeration_Type | `single_value_enumeration_types` | Direct |
| Unconstrained_Array_Type | `unconstrained_arrays` | Direct |
| Unconditional_Exit | `unconditional_exits` | Direct |
| Binary_Case_Statement | `binary_case_statements` | Direct |
| Concurrent_Interface | `concurrent_interfaces` | Direct |
| Anonymous_Access_Type | `anonymous_access` | Direct |
| Renaming_Declaration | `renamings` | Direct |
| Separate_Unit | `separates` | Direct |
| Array_Slice | `slices` | Direct |
| Number_Declaration | `number_declarations` | Direct |
| Local_Package | `local_packages` | Direct |
| Declaration_In_Block | `declarations_in_blocks` | Close (follows GNATcheck's reference manual: a block whose declarative part is empty or holds only pragmas and use clauses is not reported. GNATcheck's implementation reports every `declare` block) |
| Outer_Loop_Exit | `outer_loop_exits` | Direct |
| Exit_Without_Loop_Name | `exit_statements_with_no_loop_name` | Direct |
| Expression_Function | `expression_functions` | Direct (also reports an expression function that is itself a library unit, as GNATcheck does) |
| Size_Attribute_For_Type | `size_attribute_for_types` | Direct |
| Enumeration_Range_In_Case_Statement | `enumeration_ranges_in_case_statements` | Direct |
| Lowercase_Keyword | `lowercase_keywords` | Direct |
| Printable_ASCII | `printable_ascii` | Direct |
| End_Of_Line_Comment | `end_of_line_comments` | Direct |
| Maximum_Lines | `maximum_lines` | Direct |
| Maximum_Identifier_Length | `max_identifier_length` | Direct |
| Numeric_Format | `numeric_format` | Direct |
| Parameters_Out_Of_Order | `parameters_out_of_order` | Direct |
| Maximum_Subprogram_Lines | `maximum_subprogram_lines` | Direct |
| Maximum_Out_Parameters | `maximum_out_parameters` | Direct |
| Default_Parameter | `default_parameters` | Direct |
| Uncommented_Begin | `uncommented_begin` | Direct |
| Uncommented_Begin_In_Package_Body | `uncommented_begin_in_package_bodies` | Direct |
| Uncommented_End_Record | `uncommented_end_record` | Direct |
| Object_Declaration_Out_Of_Order | `object_declarations_out_of_order` | Direct |
| One_Construct_Per_Line | `one_construct_per_line` | Direct |
| Logical_SLOC | `metrics_lsloc` | Direct (the default limit differs: 200 here, 5 in GNATcheck; the benchmark lane runs GNATcheck with 200) |
| Positional_Parameter | `positional_parameters` | Direct |
| Positional_Defaulted_Parameter | `positional_actuals_for_defaulted_parameters` | Direct |
| Positional_Generic_Parameter | `positional_generic_parameters` | Direct |
| Positional_Component | `positional_components` | Direct |
| Non_Qualified_Aggregate | `non_qualified_aggregates` | Direct |
| Nested_Subprogram | `nested_subprograms` | Direct |
| Boolean_Relational_Operator | `boolean_relational_operators` | Direct |
| Fixed_Equality | `fixed_equality_checks` | Direct |
| Unconstrained_Array_Return | `unconstrained_array_returns` | Direct |
| Deriving_From_Predefined_Type | `deriving_from_predefined_type` | Direct |
| Visible_Component | `visible_components` | Direct |
| Object_Of_Anonymous_Type | `objects_of_anonymous_types` | Direct |
| Numeric_Indexing | `numeric_indexing` | Direct |
| Local_Instantiation | `local_instantiations` | Direct |
| Explicit_Inlining | `explicit_inlining` | Direct |
| Pos_On_Enumeration_Type | `pos_on_enumeration_types` | Direct |
| Implicit_Small | `implicit_small_for_fixed_point_types` | Direct |
| Ada05_Formal_Package | `ada05_formal_packages` | Direct |
| Separate_Numeric_Error_Handler | `separate_numeric_error_handlers` | Direct |
| One_Tagged_Type_Per_Package | `one_tagged_type_per_package` | Direct |
| Explicit_Full_Discrete_Range | `explicit_full_discrete_ranges` | Direct |
| Universal_Range | `universal_ranges` | Direct |
| Default_Value_For_Record_Component | `default_values_for_record_components` | Direct |
| Uninitialized_Global_Variable | `uninitialized_global_variables` | Direct |
| Deep_Library_Hierarchy | `deep_library_hierarchy` | Direct |
| Deeply_Nested_Generic | `deeply_nested_generics` | Direct |
| Overly_Nested_Scope | `overly_nested_scopes` | Direct |
| Specific_Type_Invariant | `specific_type_invariants` | Direct |
| Volatile_Object_Without_Address | `volatile_objects_without_address_clauses` | Direct |
| Too_Many_Primitives | `too_many_primitives` | Direct |
| Deep_Inheritance_Hierarchy | `deep_inheritance_hierarchies` | Direct |
| Too_Many_Parents | `too_many_parents` | Direct |
| Specific_Pre_Post | `specific_pre_post` | Direct |
| Constructor | `constructors` | Direct |
| Misnamed_Controlling_Parameter | `misnamed_controlling_parameters` | Direct |
| Non_Component_In_Barrier | `non_component_in_barriers` | Direct |
| Constant_Overlay | `constant_overlays` | Direct |
| Non_Constant_Overlay | `non_constant_overlays` | Direct |
| Nonoverlay_Address_Specification | `nonoverlay_address_specifications` | Direct |
| Not_Imported_Overlay | `not_imported_overlays` | Direct |
| Address_Of_Non_Volatile_Object | `address_attribute_for_non_volatile_objects` | Direct |
| Access_To_Local_Object | `access_to_local_objects` | Direct |
| Bit_Record_Without_Layout | `bit_records_without_layout_definition` | Direct |
| No_Scalar_Storage_Order | `no_scalar_storage_order_specified` | Direct |
| Incomplete_Representation_Specification | `incomplete_representation_specifications` | Direct |
| Misplaced_Representation_Item | `misplaced_representation_items` | Direct |
| Representation_Specification | `representation_specifications` | Direct |
| Unchecked_Address_Conversion | `unchecked_address_conversions` | Direct |
| Unchecked_Conversion_As_Actual | `unchecked_conversions_as_actuals` | Direct |
| Use_Simple_Loop | `use_simple_loops` | Direct |
| Use_While_Loop | `use_while_loops` | Direct |
| Use_For_Loop | `use_for_loops` | Direct |
| Use_Range | `use_ranges` | Direct |
| Use_Membership | `use_memberships` | Direct |
| Use_If_Expression | `use_if_expressions` | Direct |
| Use_Case_Statement | `use_case_statements` | Direct |
| Use_Record_Aggregate | `use_record_aggregates` | Direct (like GNATcheck, only for a simple or expanded object name: `V (I).F := ...` is not considered) |
| Use_For_Of_Loop | `use_for_of_loops` | Direct |
| Use_Array_Slice | `use_array_slices` | Direct |
| Discriminated_Record | `discriminated_records` | Direct |
| Anonymous_Subtype | `anonymous_subtypes` | Direct |
| No_Explicit_Real_Range | `no_explicit_real_range` | Direct |
| Membership_For_Validity | `membership_for_validity` | Direct |
| Positional_Defaulted_Generic_Parameter | `positional_actuals_for_defaulted_generic_parameters` | Direct |
| Deeply_Nested_Instantiation | `deeply_nested_instantiations` | Direct |
| Too_Many_Generic_Dependencies | `too_many_generic_dependencies` | Direct |
| Raising_External_Exception | `raising_external_exceptions` | Direct |
| Final_Package | `final_package` | Direct |
| Direct_Call_To_Primitive | `direct_calls_to_primitives` | Direct |
| Downward_View_Conversion | `downward_view_conversions` | Direct |
| Specific_Parent_Type_Invariant | `specific_parent_type_invariant` | Direct |
| No_Inherited_Classwide_Pre | `no_inherited_classwide_pre` | Direct |
| Non_SPARK_Attribute | `non_spark_attributes` | Direct |
| Nested_Path | `nested_paths` | Direct |
| Essential_Complexity | `metrics_essential_complexity` | Direct |
| Maximum_Expression_Complexity | `maximum_expression_complexity` | Direct |
| Improperly_Located_Instantiation | `improperly_located_instantiations` | Direct |
| Function_Style_Procedure | `function_style_procedures` | Direct |
| Exception_As_Control_Flow | `exceptions_as_control_flow` | Direct |
| Complex_Inlined_Subprogram | `complex_inlined_subprograms` | Direct |
| Ada_2022_In_Ghost_Code | `ada_2022_in_ghost_code` | Direct |
| Same_Logic | `same_logic` | Direct |
| Suspicious_Equality | `suspicious_equalities` | Direct |
| Non_Visible_Exception | `non_visible_exceptions` | Direct |
| Outbound_Protected_Assignment | `outbound_protected_assignments` | Direct |
| Outside_Reference_From_Subprogram | `outside_references_from_subprograms` | Direct |
| Variable_Scoping | `variable_scoping` | Direct |
| Out_Parameter_Read_In_Exception_Handler | `out_parameter_read_in_exception_handler` | Direct |
| Predicate_Testing | `predicate_testing` | Direct |
| Profile_Discrepancy | `profile_discrepancies` | Direct |
| Use_Clause | `use_clauses` | Direct |
| Unavailable_Body_Call | `unavailable_body_calls` | Direct |
| Deeply_Nested_Inlining | `deeply_nested_inlining` | Direct |
| Integer_Type_As_Enumeration | `integer_types_as_enum` | Direct |
| Same_Instantiation | `same_instantiations` | Direct |

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
| Uninitialized_Read | Uninitialized_Global_Variables, Warnings (`-gnatwv`) | GNATcheck's rule is global-scope only; AdaLang's is local scalars. GNAT's `-gnatwv` warning is the closer match but reports at the object's declaration while AdaLang reports at the first read, so a line-exact comparison cannot pair them |
| No_Dynamic_Allocation | Restrictions (`No_Allocators`) | Only via the generic `pragma Restrictions` wrapper rule |
| Restricted_Access_Type | Anonymous_Access | GNATcheck's covers anonymous access types only, not named ones |
| No_Unchecked_Deallocation | Restrictions | No dedicated rule; only via the generic wrapper |
| No_Tasking | Restrictions (`No_Tasking`) | Only via the generic wrapper |
| Complete_Initialization | Default_Values_For_Record_Components | GNATcheck's is record-components only, not all objects |
| Volatile_Atomic_Consistency | Volatile_Objects_Without_Address_Clauses | Related but checks a different consistency condition |
| Representation_Clause_Policy | Representation_Specifications, Misplaced_Representation_Items | Different framing (presence/placement vs. AdaLang's policy-centralization check) |
| Generic_Instantiation_Limit | Too_Many_Generic_Dependencies, Deeply_Nested_Instantiations | Related metrics, different thresholded quantity |
| No_Compiler_Extensions | Forbidden_Pragmas, Forbidden_Aspects, Forbidden_Attributes | Only via explicit configured lists (`Forbidden_Attributes` added 2026-08-19, missed in the original documentation-based pass) |
| No_Runtime_Check_Suppression | Restrictions / Forbidden_Pragmas | Only via generic wrappers, not a dedicated suppression-policy rule |
| Entry_Barrier_Side_Effect | Non_Component_In_Barriers | Related construct (protected entry barrier expressions), different specific defect: GNATcheck flags a barrier referencing something other than a protected-object component, AdaLang flags a barrier calling a function with an `out`/`in out` parameter (found 2026-08-19 while cross-checking this document against `gnatcheck --list-rules`'s real output; was previously miscategorized as "no GNATcheck counterpart") |

## AdaLang rules paired with a GNATcheck rule through configuration

These checks express a project convention that has no default: until their
parameters are set they report nothing, in either tool. The benchmark
corpora therefore cannot exercise them, and
`quality/tool_function_evidence.tsv` records no independent oracle for
them. They were compared with GNATcheck on fixtures, with matching
parameters on both sides, except `Missing_Header` and `Actual_Parameter`,
whose GNATcheck parameters this project's GNATcheck build did not accept on
the command line.

| AdaLang rule | GNATcheck rule | Parameters |
| --- | --- | --- |
| Missing_Header | `headers` | `header` |
| Annotated_Comment | `annotated_comments` | `s` |
| Forbidden_Identifier | `name_clashes` | `forbidden` |
| Forbidden_Aspect | `forbidden_aspects` | `forbidden`, `allowed`, `all` |
| Forbidden_Attribute | `forbidden_attributes` | `forbidden`, `allowed`, `all` |
| Forbidden_Dependence | `no_dependence` | `unit_names` |
| Missing_Others_Handler | `no_others_in_exception_handlers` | `all_handlers`, `subprogram`, `task` |
| Identifier_Casing | `identifier_casing` | `type`, `enum`, `constant`, `exception`, `others`, `exclude` |
| Identifier_Prefixes | `identifier_prefixes` | `type`, `concurrent`, `access`, `class_access`, `subprogram_access`, `derived`, `constant`, `exception`, `enum`, `exclusive` |
| Identifier_Suffixes | `identifier_suffixes` | `type_suffix`, `access_suffix`, `access_access_suffix`, `class_access_suffix`, `class_subtype_suffix`, `constant_suffix`, `renaming_suffix`, `access_obj_suffix`, `interrupt_suffix`, `default` |
| Direct_Equality | `direct_equalities` | `actuals` |
| Call_In_Exception_Handler | `calls_in_exception_handlers` | `subprograms` |
| Actual_Parameter | `actual_parameters` | `forbidden` |
| Side_Effect_Parameter | `side_effect_parameters` | `functions` |
| Compiler_Warning | `warnings` | `options` |
| Compiler_Style_Check | `style_checks` | `options` |
| Compiler_Restriction | `restrictions` | `restrictions` |

`Identifier_Casing`'s `exclude` parameter takes the dictionary inline, as a
comma-separated list, where GNATcheck reads it from a file.

## AdaLang rules with no GNATcheck predefined-rule counterpart

61 of AdaLang's 302 rules do something GNATcheck's predefined catalog does
not attempt at all. They cluster into a few groups:

**Flow-sensitive "provably fails" defect detection** (this is GNATprove/
CodePeer territory, not GNATcheck's syntactic/semantic rule matching):
Known_Precondition_Failure, Known_Postcondition_Failure,
Known_Assertion_Failure, Known_Range_Check_Failure, Known_Index_Check_Failure,
Known_Overflow_Failure, Known_Discriminant_Check_Failure,
Known_Enum_Val_Failure, Known_Value_Conversion_Failure,
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
Unreachable_Case_Alternative,
Overlapping_Case_Ranges, Unreachable_Code,
Division_By_Zero, Integer_Division_Before_Multiplication,
Excessive_Shift_Amount, Known_Negative_Shift_Amount_Failure,
Known_Negative_Exponent_Failure, Reversed_Range,
Contradictory_Condition, Contradictory_Range_Condition,
Repeated_Statement, Ineffective_Operation, Constant_Result_Operation,
Empty_Loop, Unnecessary_Else_After_Return,
Handler_Order.

**Everything else** (no close GNATcheck family at all):
No_Label, Swappable_Parameters,
Assertion_Side_Effect, Shadowed_Declaration,
Inefficient_String_Concatenation,
Circular_Package_Dependency, Duplicate_Subprogram, Missing_Loop_Variant,
Potentially_Blocking_Operation, No_Explicit_Dereference, No_Rendezvous,
No_Select, No_Requeue, No_Asynchronous_Transfer, No_Dispatching_Call,
No_Classwide_Type, No_Unchecked_Access,
Reraise_Discards_Occurrence,
Duplicate_Exception_Choice, Redundant_If_Boolean_Return,
Redundant_Final_Return, Redundant_Abs,
Redundant_Unary_Minus, Use_After_Free, Double_Free, Unclosed_File_Handle.

(`Shadowed_Declaration` is also something GNAT reports as a compiler
warning. The checks that GNAT's warnings do cover -- Unused_Parameter,
Unused_Variable, Unused_With_Clause, Duplicate_With_Clause,
Wrong_Parameter_Mode, Dead_Store, Overwritten_Assignment,
Redundant_Type_Conversion, Self_Assignment, Constant_Condition -- were
listed here until 2026-09-23 and are now paired through GNATcheck's
`Warnings` rule in the table above. `Missing_Overriding_Indicator` was
formerly listed here too, but is a `Direct` match on
`Overriding_Indicators`.)

## GNATcheck rules with no AdaLang Analyzer counterpart

None of GNATcheck's 212 rules (the `kp_*` detectors aside). Three groups
were added last and work differently from the per-unit checks:

- **Rules that compare all sources**, which GNATcheck marks "global
  analysis required". `Unavailable_Body_Call` and `Deeply_Nested_Inlining`
  follow calls into other units as they are met; `Integer_Type_As_Enumeration`
  and `Same_Instantiation` run as a pass over every analyzed source after
  the per-file walk. As with GNATcheck, their answer depends on which
  sources are given: a type used arithmetically only in a file that is not
  analyzed is reported.
- **Compiler wrappers.** `Compiler_Warning`, `Compiler_Style_Check` and
  `Compiler_Restriction` correspond to `warnings`, `style_checks` and
  `restrictions`. Like GNATcheck, AdaLang runs GNAT on the sources for
  semantic checks only and reports the messages the parameters select, so
  they need GNAT (and, with a project file, gprbuild) on the path. Warnings
  that no `-gnatw` switch selects are left out, as GNATcheck leaves them
  out. On Saatana both tools report the same 753 warning and style
  messages; AdaLang reports 7 more, in a specification GNATcheck does not
  compile. For twelve restrictions the two agree on all 688 violations on
  SPARKNaCl and on GNATcheck's 105 on Saatana, where AdaLang reports 2
  more in that same specification. GNATcheck declines some restrictions
  with a warning (`No_Recursion`, `No_Implicit_Loops`); AdaLang passes
  whatever is listed to the compiler. One thing to know when comparing:
  the GNATcheck build used here reports no restriction violation at all
  when the path of the working directory contains upper-case letters.
- **`Use_Clause`**, paired with `use_clauses`; `No_Use_Package_Clause`
  stays paired with `use_package_clauses`.

The 123 `kp_*` rules flag source constructs affected by known problems in
particular GNAT Pro releases. They are specific to that compiler's defect
history and are not attempted.

## Using GNATcheck's names

Every rule name in the tables of this document is accepted where a check
name is: `-checks=positional_parameters`, `+RPositional_Parameters` and
`-rule-param=maximum_parameters.n=6` do what the AdaLang names would. All
212 general-purpose GNATcheck rule names are known. Where one rule is
several AdaLang checks, the rule name selects them all; where a pairing
goes through a `-gnatw` or `-gnaty` letter of GNATcheck's `warnings` or
`style_checks` rule, the check has no rule name of its own and is selected
by its AdaLang name. `quality/check_catalogue_audit.md` lists how each
AdaLang name relates to GNATcheck's and which checks overlap.

## Reading this comparison

Rule coverage is now close to GNATcheck's, but AdaLang Analyzer is not a
drop-in replacement for it and does not claim to be (see `positioning.md`):

- The pairing is by behaviour on the code both tools were run on. On the
  external corpora the two agree on more than 99% of findings in either
  direction, but GNATcheck also reports inside the instances of generic
  units, which AdaLang does not follow, and AdaLang applies the
  preprocessor only when a project file gives the switches: a source with
  preprocessor directives that is named directly on the command line does
  not parse and is not analyzed. Several object-oriented checks still rest
  on few findings.
- GNATcheck's rules are written in LKQL and can be extended without
  rebuilding the tool; AdaLang's are compiled in.
- Where the two tools cannot resolve a unit the same way (a missing
  specification, an unavailable library), they can differ: GNATcheck drops
  a whole unit from a unit-level rule when one name in it fails to resolve.
- Rule parameters use different syntax, and diagnostics are worded
  differently.

In the other direction, 61 AdaLang checks have no GNATcheck counterpart:
the flow-sensitive defect, SPARK-contract-consistency and DO-178C
traceability checks that remain its differentiator (see "AdaLang's
defensible distinction" in `positioning.md`'s GNATcheck section).
