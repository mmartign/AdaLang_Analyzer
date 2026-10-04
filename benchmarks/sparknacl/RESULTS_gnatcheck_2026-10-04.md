# SPARKNaCl: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Current results, refreshed 2026-10-04. This file replaces the earlier dated runs, which remain in the Git history. The refresh adds the rule pairs of the 167 opt-in coding-standard checks (153 of them run here; the other 14 report nothing until configured and are not in the rule map). The pairs that were already compared on 2026-09-24 are run again; the analyzer now also resolves names through imported projects (`FP-102`), which can change their numbers too.

## Environment

- Corpus: pinned at `49e3bddf092561ce2b74c134a35acff91a2da9a4` (`SPARKNACL_REVISION`), unchanged.
- AdaLang Analyzer: 1.7.0 plus the unreleased coding-standard checks (branch `gnatcheck-rule-parity`).
- GNATcheck: the same from-source build as prior runs; one pass with the plain `-r` rules, then one pass per column-4 option line of `benchmarks/gnatcheck_rule_map.tsv` (`benchmarks/gnatcheck_rule_args.awk`).
- Reproduce: `SPARKNACL_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/sparknacl/run_gnatcheck.sh` (see this directory's README for
  any setup step).
- GNATcheck worker crashes ("unparsable worker output"): each GNATcheck invocation was repeated until it finished without a crash; the plain rules were run in batches of at most 25 where one pass over all of them kept crashing. Across the attempts logged for this corpus, 2 invocations were repeated. The accepted log has no crash and no GNATcheck error line.

## Totals

| | 2026-10-04, all pairs | 2026-10-04, pairs of 2026-09-24 | 2026-09-24 |
| --- | ---: | ---: | ---: |
| AdaLang findings | 5527 | 1986 | 1986 |
| &nbsp;&nbsp;matched by GNATcheck | 5293 (95.8%) | 1752 (88.2%) | 1752 (88.2%) |
| GNATcheck findings | 5737 | 2196 | 2196 |
| &nbsp;&nbsp;matched by AdaLang | 5293 (92.3%) | 1752 (79.8%) | 1752 (79.8%) |

Every pair of 2026-09-24 has the same numbers as then.

## Coding-standard checks

The 153 new pairs, counted over all files: 3541 AdaLang findings, 3541 matched by GNATcheck (100.0%); 3541 GNATcheck findings, 3541 matched by AdaLang (100.0%). 57 of the 153 checks have a finding from one tool or the other on this corpus.

The two tools do not analyse the same set of files (see the notes below), so the same pairs are also counted over the files both analysed: 3541 AdaLang findings and 3541 GNATcheck findings, 3541 at the same file and line; 0 AdaLang-only, 0 GNATcheck-only.

- Every finding of the new checks is reported by both tools at the same file and line.

## Duplicate branches

`Identical_Branches` + `Identical_Case_Alternative`: 0 findings, 0 matched by GNATcheck's `duplicate_branches` (n/a); `duplicate_branches`: 0 findings, 0 matched (n/a). With GNATcheck's default thresholds (4 statements / 14 tokens) this pair had 0 GNATcheck findings on every corpus.

## Per AdaLang rule

| AdaLang rule | Match | Findings | AdaLang-only | Matched |
| --- | --- | ---: | ---: | ---: |
| Abstract_Type_Declaration | direct | 0 | 0 | n/a |
| Access_To_Local_Object | direct | 0 | 0 | n/a |
| Ada05_Formal_Package | direct | 0 | 0 | n/a |
| Ada_2022_In_Ghost_Code | direct | 0 | 0 | n/a |
| Address_Clause | close | 0 | 0 | n/a |
| Address_Of_Non_Volatile_Object | direct | 0 | 0 | n/a |
| Aliasing_Between_Parameters | direct | 0 | 0 | n/a |
| Anonymous_Access_Type | direct | 0 | 0 | n/a |
| Anonymous_Array_Type | direct | 0 | 0 | n/a |
| Anonymous_Subtype | direct | 410 | 0 | 100.0% |
| Array_Slice | direct | 217 | 0 | 100.0% |
| Binary_Case_Statement | direct | 0 | 0 | n/a |
| Bit_Record_Without_Layout | direct | 0 | 0 | n/a |
| Boolean_Relational_Operator | direct | 14 | 0 | 100.0% |
| Complex_Inlined_Subprogram | direct | 3 | 0 | 100.0% |
| Concurrent_Interface | direct | 0 | 0 | n/a |
| Conditional_Expression | direct | 37 | 0 | 100.0% |
| Constant_Condition | close | 0 | 0 | n/a |
| Constant_Overlay | direct | 0 | 0 | n/a |
| Constructor | direct | 0 | 0 | n/a |
| Cyclomatic_Complexity | direct | 3 | 2 | 33.3% |
| Dead_Store | close | 11 | 11 | 0.0% |
| Declaration_In_Block | close | 39 | 0 | 100.0% |
| Deep_Inheritance_Hierarchy | direct | 0 | 0 | n/a |
| Deep_Library_Hierarchy | direct | 0 | 0 | n/a |
| Deep_Nesting | direct | 0 | 0 | n/a |
| Deeply_Nested_Generic | direct | 0 | 0 | n/a |
| Deeply_Nested_Instantiation | direct | 0 | 0 | n/a |
| Default_Parameter | direct | 0 | 0 | n/a |
| Default_Value_For_Record_Component | direct | 0 | 0 | n/a |
| Dependency_Limit | direct | 0 | 0 | n/a |
| Deriving_From_Predefined_Type | direct | 0 | 0 | n/a |
| Direct_Call_To_Primitive | direct | 0 | 0 | n/a |
| Discriminated_Record | direct | 0 | 0 | n/a |
| Downward_View_Conversion | direct | 0 | 0 | n/a |
| Duplicate_Boolean_Operand | close | 0 | 0 | n/a |
| Duplicate_Condition | direct | 0 | 0 | n/a |
| Duplicate_With_Clause | direct | 0 | 0 | n/a |
| Empty_Else_Body | close | 0 | 0 | n/a |
| Empty_Elsif_Body | close | 0 | 0 | n/a |
| Empty_Exception_Handler | direct | 0 | 0 | n/a |
| Empty_If_Body | close | 0 | 0 | n/a |
| Empty_Then_Body | close | 0 | 0 | n/a |
| End_Of_Line_Comment | direct | 127 | 0 | 100.0% |
| Enumeration_Range_In_Case_Statement | direct | 0 | 0 | n/a |
| Enumeration_Representation_Clause | direct | 0 | 0 | n/a |
| Essential_Complexity | direct | 1 | 0 | 100.0% |
| Exception_As_Control_Flow | direct | 0 | 0 | n/a |
| Exception_Propagation | close | 0 | 0 | n/a |
| Exception_Swallowed | close | 0 | 0 | n/a |
| Exit_From_Conditional_Loop | direct | 4 | 0 | 100.0% |
| Exit_Without_Loop_Name | direct | 8 | 0 | 100.0% |
| Expanded_Loop_Exit_Name | direct | 0 | 0 | n/a |
| Explicit_Full_Discrete_Range | direct | 3 | 0 | 100.0% |
| Explicit_Inlining | direct | 5 | 0 | 100.0% |
| Expression_Function | direct | 5 | 0 | 100.0% |
| Final_Package | direct | 0 | 0 | n/a |
| Fixed_Equality | direct | 0 | 0 | n/a |
| Floating_Equality | direct | 0 | 0 | n/a |
| Function_Out_Parameter | direct | 0 | 0 | n/a |
| Function_Style_Procedure | direct | 49 | 0 | 100.0% |
| Generic_In_Out_Object | direct | 0 | 0 | n/a |
| Generic_In_Subprogram | direct | 0 | 0 | n/a |
| Global_Variable | direct | 0 | 0 | n/a |
| Identical_Branches | direct | 0 | 0 | n/a |
| Identical_Case_Alternative | close | 0 | 0 | n/a |
| Implicit_In_Mode | direct | 9 | 0 | 100.0% |
| Implicit_Small | direct | 0 | 0 | n/a |
| Improperly_Located_Instantiation | direct | 0 | 0 | n/a |
| Incomplete_Representation_Specification | direct | 0 | 0 | n/a |
| Infinite_Loop | close | 0 | 0 | n/a |
| Library_Level_Initialization | close | 0 | 0 | n/a |
| Library_Level_Subprogram | direct | 0 | 0 | n/a |
| Local_Instantiation | direct | 0 | 0 | n/a |
| Local_Package | direct | 0 | 0 | n/a |
| Local_Use_Clause | direct | 0 | 0 | n/a |
| Logical_SLOC | direct | 6 | 0 | 100.0% |
| Long_Line | direct | 0 | 0 | n/a |
| Lowercase_Keyword | direct | 0 | 0 | n/a |
| Magic_Number | close | 945 | 88 | 90.7% |
| Maximum_Expression_Complexity | direct | 173 | 0 | 100.0% |
| Maximum_Identifier_Length | direct | 26 | 0 | 100.0% |
| Maximum_Lines | direct | 0 | 0 | n/a |
| Maximum_Out_Parameters | direct | 1 | 0 | 100.0% |
| Maximum_Subprogram_Lines | direct | 0 | 0 | n/a |
| Membership_For_Validity | direct | 39 | 0 | 100.0% |
| Membership_Test | direct | 198 | 0 | 100.0% |
| Misnamed_Controlling_Parameter | direct | 0 | 0 | n/a |
| Misplaced_Representation_Item | direct | 0 | 0 | n/a |
| Missing_Global_Contract | close | 3 | 3 | 0.0% |
| Missing_Overriding_Indicator | direct | 0 | 0 | n/a |
| Multiple_Protected_Entries | direct | 0 | 0 | n/a |
| Naming_Convention | close | 595 | 120 | 79.8% |
| Nested_Path | direct | 0 | 0 | n/a |
| Nested_Subprogram | direct | 44 | 0 | 100.0% |
| No_Abort | direct | 0 | 0 | n/a |
| No_Access_To_Subp_Def | direct | 0 | 0 | n/a |
| No_Block_Statement | direct | 40 | 0 | 100.0% |
| No_Closing_Name | direct | 0 | 0 | n/a |
| No_Controlled_Type | direct | 0 | 0 | n/a |
| No_Explicit_Real_Range | direct | 0 | 0 | n/a |
| No_Goto | direct | 0 | 0 | n/a |
| No_Inherited_Classwide_Pre | direct | 0 | 0 | n/a |
| No_Multiple_Return | direct | 2 | 2 | 0.0% |
| No_Pragma | close | 418 | 0 | 100.0% |
| No_Recursion | direct | 0 | 0 | n/a |
| No_Scalar_Storage_Order | direct | 0 | 0 | n/a |
| No_Use_Package_Clause | direct | 11 | 0 | 100.0% |
| Non_Component_In_Barrier | direct | 0 | 0 | n/a |
| Non_Constant_Overlay | direct | 0 | 0 | n/a |
| Non_Qualified_Aggregate | direct | 95 | 0 | 100.0% |
| Non_SPARK_Attribute | direct | 124 | 0 | 100.0% |
| Non_Short_Circuit_Condition | direct | 1 | 0 | 100.0% |
| Non_Tagged_Derived_Type | direct | 2 | 0 | 100.0% |
| Non_Visible_Exception | direct | 0 | 0 | n/a |
| Nonoverlay_Address_Specification | direct | 0 | 0 | n/a |
| Not_Imported_Overlay | direct | 0 | 0 | n/a |
| Null_Case_Alternative | close | 0 | 0 | n/a |
| Null_Statement | direct | 0 | 0 | n/a |
| Number_Declaration | direct | 48 | 0 | 100.0% |
| Numeric_Format | direct | 153 | 0 | 100.0% |
| Numeric_Indexing | direct | 485 | 0 | 100.0% |
| Object_Declaration_Out_Of_Order | direct | 0 | 0 | n/a |
| Object_Of_Anonymous_Type | direct | 0 | 0 | n/a |
| One_Construct_Per_Line | direct | 0 | 0 | n/a |
| One_Tagged_Type_Per_Package | direct | 0 | 0 | n/a |
| Operator_Renaming | direct | 0 | 0 | n/a |
| Others_In_Aggregate | direct | 1 | 0 | 100.0% |
| Others_In_Case_Statement | direct | 0 | 0 | n/a |
| Others_In_Exception_Handler | direct | 0 | 0 | n/a |
| Out_Parameter_Read_In_Exception_Handler | direct | 0 | 0 | n/a |
| Outbound_Protected_Assignment | direct | 0 | 0 | n/a |
| Outer_Loop_Exit | direct | 0 | 0 | n/a |
| Outside_Reference_From_Subprogram | direct | 182 | 0 | 100.0% |
| Overloaded_Operator | direct | 5 | 0 | 100.0% |
| Overly_Nested_Scope | direct | 0 | 0 | n/a |
| Overwritten_Assignment | close | 0 | 0 | n/a |
| Parameters_Out_Of_Order | direct | 164 | 0 | 100.0% |
| Pos_On_Enumeration_Type | direct | 19 | 0 | 100.0% |
| Positional_Component | direct | 24 | 0 | 100.0% |
| Positional_Defaulted_Generic_Parameter | direct | 0 | 0 | n/a |
| Positional_Defaulted_Parameter | direct | 0 | 0 | n/a |
| Positional_Generic_Parameter | direct | 2 | 0 | 100.0% |
| Positional_Parameter | direct | 381 | 0 | 100.0% |
| Predefined_Numeric_Type | direct | 15 | 0 | 100.0% |
| Predicate_Testing | direct | 11 | 0 | 100.0% |
| Printable_ASCII | direct | 0 | 0 | n/a |
| Profile_Discrepancy | direct | 1 | 0 | 100.0% |
| Quantified_Expression | direct | 118 | 0 | 100.0% |
| Raising_External_Exception | direct | 0 | 0 | n/a |
| Raising_Predefined_Exception | direct | 0 | 0 | n/a |
| Redundant_Boolean_Comparison | close | 0 | 0 | n/a |
| Redundant_Type_Conversion | close | 0 | 0 | n/a |
| Relative_Delay | direct | 0 | 0 | n/a |
| Renaming_Declaration | direct | 4 | 0 | 100.0% |
| Representation_Specification | direct | 4 | 0 | 100.0% |
| Same_Logic | direct | 0 | 0 | n/a |
| Same_Operand | direct | 0 | 0 | n/a |
| Self_Assignment | close | 0 | 0 | n/a |
| Separate_Numeric_Error_Handler | direct | 0 | 0 | n/a |
| Separate_Unit | direct | 10 | 0 | 100.0% |
| Single_Value_Enumeration_Type | direct | 0 | 0 | n/a |
| Size_Attribute_For_Type | direct | 15 | 0 | 100.0% |
| Specific_Parent_Type_Invariant | direct | 0 | 0 | n/a |
| Specific_Pre_Post | direct | 0 | 0 | n/a |
| Specific_Type_Invariant | direct | 0 | 0 | n/a |
| Suspicious_Equality | direct | 0 | 0 | n/a |
| Too_Many_Generic_Dependencies | direct | 0 | 0 | n/a |
| Too_Many_Parameters | direct | 1 | 1 | 0.0% |
| Too_Many_Parents | direct | 0 | 0 | n/a |
| Too_Many_Primitives | direct | 0 | 0 | n/a |
| Trailing_Whitespace | direct | 0 | 0 | n/a |
| Unchecked_Address_Conversion | direct | 0 | 0 | n/a |
| Unchecked_Conversion_As_Actual | direct | 0 | 0 | n/a |
| Uncommented_Begin | direct | 117 | 0 | 100.0% |
| Uncommented_Begin_In_Package_Body | direct | 0 | 0 | n/a |
| Uncommented_End_Record | direct | 0 | 0 | n/a |
| Unconditional_Exit | direct | 2 | 0 | 100.0% |
| Unconstrained_Array_Return | direct | 4 | 0 | 100.0% |
| Unconstrained_Array_Type | direct | 6 | 0 | 100.0% |
| Uninitialized_Global_Variable | direct | 0 | 0 | n/a |
| Uninitialized_Output | close | 7 | 7 | 0.0% |
| Universal_Range | direct | 5 | 0 | 100.0% |
| Unnamed_Block_Or_Loop | direct | 63 | 0 | 100.0% |
| Unnamed_Exit | direct | 0 | 0 | n/a |
| Unused_Parameter | close | 0 | 0 | n/a |
| Unused_Variable | close | 0 | 0 | n/a |
| Unused_With_Clause | close | 0 | 0 | n/a |
| Use_Array_Slice | direct | 0 | 0 | n/a |
| Use_Case_Statement | direct | 1 | 0 | 100.0% |
| Use_For_Loop | direct | 0 | 0 | n/a |
| Use_For_Of_Loop | direct | 4 | 0 | 100.0% |
| Use_If_Expression | direct | 1 | 0 | 100.0% |
| Use_Membership | direct | 1 | 0 | 100.0% |
| Use_Range | direct | 5 | 0 | 100.0% |
| Use_Record_Aggregate | direct | 0 | 0 | n/a |
| Use_Simple_Loop | direct | 0 | 0 | n/a |
| Use_While_Loop | direct | 0 | 0 | n/a |
| Variable_Scoping | direct | 0 | 0 | n/a |
| Visible_Component | direct | 0 | 0 | n/a |
| Volatile_Object_Without_Address | direct | 0 | 0 | n/a |
| Wrong_Parameter_Mode | close | 0 | 0 | n/a |

## Per GNATcheck rule

| GNATcheck rule | Findings | GNATcheck-only | Matched |
| --- | ---: | ---: | ---: |
| `abort_statements` | 0 | 0 | n/a |
| `abstract_type_declarations` | 0 | 0 | n/a |
| `access_to_local_objects` | 0 | 0 | n/a |
| `ada05_formal_packages` | 0 | 0 | n/a |
| `ada_2022_in_ghost_code` | 0 | 0 | n/a |
| `address_attribute_for_non_volatile_objects` | 0 | 0 | n/a |
| `address_specifications_for_initialized_objects` | 0 | 0 | n/a |
| `address_specifications_for_local_objects` | 0 | 0 | n/a |
| `anonymous_access` | 0 | 0 | n/a |
| `anonymous_arrays` | 0 | 0 | n/a |
| `anonymous_subtypes` | 410 | 0 | 100.0% |
| `at_representation_clauses` | 0 | 0 | n/a |
| `binary_case_statements` | 0 | 0 | n/a |
| `bit_records_without_layout_definition` | 0 | 0 | n/a |
| `blocks` | 40 | 0 | 100.0% |
| `boolean_negations` | 0 | 0 | n/a |
| `boolean_relational_operators` | 14 | 0 | 100.0% |
| `calls_outside_elaboration` | 0 | 0 | n/a |
| `complex_inlined_subprograms` | 3 | 0 | 100.0% |
| `concurrent_interfaces` | 0 | 0 | n/a |
| `conditional_expressions` | 37 | 0 | 100.0% |
| `constant_overlays` | 0 | 0 | n/a |
| `constructors` | 0 | 0 | n/a |
| `controlled_type_declarations` | 0 | 0 | n/a |
| `declarations_in_blocks` | 39 | 0 | 100.0% |
| `deep_inheritance_hierarchies` | 0 | 0 | n/a |
| `deep_library_hierarchy` | 0 | 0 | n/a |
| `deeply_nested_generics` | 0 | 0 | n/a |
| `deeply_nested_instantiations` | 0 | 0 | n/a |
| `default_parameters` | 0 | 0 | n/a |
| `default_values_for_record_components` | 0 | 0 | n/a |
| `deriving_from_predefined_type` | 0 | 0 | n/a |
| `direct_calls_to_primitives` | 0 | 0 | n/a |
| `discriminated_records` | 0 | 0 | n/a |
| `downward_view_conversions` | 0 | 0 | n/a |
| `duplicate_branches` | 0 | 0 | n/a |
| `end_of_line_comments` | 127 | 0 | 100.0% |
| `enumeration_ranges_in_case_statements` | 0 | 0 | n/a |
| `enumeration_representation_clauses` | 0 | 0 | n/a |
| `exception_propagation_from_callbacks` | 0 | 0 | n/a |
| `exception_propagation_from_export` | 0 | 0 | n/a |
| `exception_propagation_from_tasks` | 0 | 0 | n/a |
| `exceptions_as_control_flow` | 0 | 0 | n/a |
| `exit_statements_with_no_loop_name` | 8 | 0 | 100.0% |
| `exits_from_conditional_loops` | 4 | 0 | 100.0% |
| `expanded_loop_exit_names` | 0 | 0 | n/a |
| `explicit_full_discrete_ranges` | 3 | 0 | 100.0% |
| `explicit_inlining` | 5 | 0 | 100.0% |
| `expression_functions` | 5 | 0 | 100.0% |
| `final_package` | 0 | 0 | n/a |
| `fixed_equality_checks` | 0 | 0 | n/a |
| `float_equality_checks` | 0 | 0 | n/a |
| `forbidden_pragmas` | 418 | 0 | 100.0% |
| `function_out_parameters` | 0 | 0 | n/a |
| `function_style_procedures` | 49 | 0 | 100.0% |
| `generic_in_out_objects` | 0 | 0 | n/a |
| `generics_in_subprograms` | 0 | 0 | n/a |
| `global_variables` | 0 | 0 | n/a |
| `goto_statements` | 0 | 0 | n/a |
| `implicit_in_mode_parameters` | 9 | 0 | 100.0% |
| `implicit_small_for_fixed_point_types` | 0 | 0 | n/a |
| `improper_returns` | 6 | 6 | 0.0% |
| `improperly_located_instantiations` | 0 | 0 | n/a |
| `incomplete_representation_specifications` | 0 | 0 | n/a |
| `library_level_subprograms` | 0 | 0 | n/a |
| `local_instantiations` | 0 | 0 | n/a |
| `local_packages` | 0 | 0 | n/a |
| `local_use_clauses` | 0 | 0 | n/a |
| `lowercase_keywords` | 0 | 0 | n/a |
| `max_identifier_length` | 26 | 0 | 100.0% |
| `maximum_expression_complexity` | 173 | 0 | 100.0% |
| `maximum_lines` | 0 | 0 | n/a |
| `maximum_out_parameters` | 1 | 0 | 100.0% |
| `maximum_parameters` | 27 | 27 | 0.0% |
| `maximum_subprogram_lines` | 0 | 0 | n/a |
| `membership_for_validity` | 39 | 0 | 100.0% |
| `membership_tests` | 198 | 0 | 100.0% |
| `metrics_cyclomatic_complexity` | 9 | 8 | 11.1% |
| `metrics_essential_complexity` | 1 | 0 | 100.0% |
| `metrics_lsloc` | 6 | 0 | 100.0% |
| `min_identifier_length` | 680 | 205 | 69.9% |
| `misnamed_controlling_parameters` | 0 | 0 | n/a |
| `misplaced_representation_items` | 0 | 0 | n/a |
| `multiple_entries_in_protected_definitions` | 0 | 0 | n/a |
| `nested_paths` | 0 | 0 | n/a |
| `nested_subprograms` | 44 | 0 | 100.0% |
| `no_closing_names` | 0 | 0 | n/a |
| `no_explicit_real_range` | 0 | 0 | n/a |
| `no_inherited_classwide_pre` | 0 | 0 | n/a |
| `no_scalar_storage_order_specified` | 0 | 0 | n/a |
| `non_component_in_barriers` | 0 | 0 | n/a |
| `non_constant_overlays` | 0 | 0 | n/a |
| `non_qualified_aggregates` | 95 | 0 | 100.0% |
| `non_short_circuit_operators` | 191 | 190 | 0.5% |
| `non_spark_attributes` | 124 | 0 | 100.0% |
| `non_tagged_derived_types` | 2 | 0 | 100.0% |
| `non_visible_exceptions` | 0 | 0 | n/a |
| `nonoverlay_address_specifications` | 0 | 0 | n/a |
| `not_imported_overlays` | 0 | 0 | n/a |
| `null_paths` | 0 | 0 | n/a |
| `number_declarations` | 48 | 0 | 100.0% |
| `numeric_format` | 153 | 0 | 100.0% |
| `numeric_indexing` | 485 | 0 | 100.0% |
| `numeric_literals` | 857 | 0 | 100.0% |
| `object_declarations_out_of_order` | 0 | 0 | n/a |
| `objects_of_anonymous_types` | 0 | 0 | n/a |
| `one_construct_per_line` | 0 | 0 | n/a |
| `one_tagged_type_per_package` | 0 | 0 | n/a |
| `operator_renamings` | 0 | 0 | n/a |
| `others_in_aggregates` | 1 | 0 | 100.0% |
| `others_in_case_statements` | 0 | 0 | n/a |
| `others_in_exception_handlers` | 0 | 0 | n/a |
| `out_parameter_read_in_exception_handler` | 0 | 0 | n/a |
| `outbound_protected_assignments` | 0 | 0 | n/a |
| `outer_loop_exits` | 0 | 0 | n/a |
| `outside_references_from_subprograms` | 182 | 0 | 100.0% |
| `overloaded_operators` | 5 | 0 | 100.0% |
| `overly_nested_control_structures` | 0 | 0 | n/a |
| `overly_nested_scopes` | 0 | 0 | n/a |
| `overriding_indicators` | 0 | 0 | n/a |
| `parameters_aliasing` | 0 | 0 | n/a |
| `parameters_out_of_order` | 164 | 0 | 100.0% |
| `pos_on_enumeration_types` | 19 | 0 | 100.0% |
| `positional_actuals_for_defaulted_generic_parameters` | 0 | 0 | n/a |
| `positional_actuals_for_defaulted_parameters` | 0 | 0 | n/a |
| `positional_components` | 24 | 0 | 100.0% |
| `positional_generic_parameters` | 2 | 0 | 100.0% |
| `positional_parameters` | 381 | 0 | 100.0% |
| `potential_parameters_aliasing` | 0 | 0 | n/a |
| `predefined_numeric_types` | 15 | 0 | 100.0% |
| `predicate_testing` | 11 | 0 | 100.0% |
| `printable_ascii` | 0 | 0 | n/a |
| `profile_discrepancies` | 1 | 0 | 100.0% |
| `quantified_expressions` | 118 | 0 | 100.0% |
| `raising_external_exceptions` | 0 | 0 | n/a |
| `raising_predefined_exceptions` | 0 | 0 | n/a |
| `recursive_subprograms` | 0 | 0 | n/a |
| `redundant_boolean_expressions` | 0 | 0 | n/a |
| `redundant_null_statements` | 0 | 0 | n/a |
| `relative_delay_statements` | 0 | 0 | n/a |
| `renamings` | 4 | 0 | 100.0% |
| `representation_specifications` | 4 | 0 | 100.0% |
| `same_logic` | 0 | 0 | n/a |
| `same_operands` | 0 | 0 | n/a |
| `same_tests` | 0 | 0 | n/a |
| `separate_numeric_error_handlers` | 0 | 0 | n/a |
| `separates` | 10 | 0 | 100.0% |
| `silent_exception_handlers` | 0 | 0 | n/a |
| `simple_loop_statements` | 3 | 3 | 0.0% |
| `single_value_enumeration_types` | 0 | 0 | n/a |
| `size_attribute_for_types` | 15 | 0 | 100.0% |
| `slices` | 217 | 0 | 100.0% |
| `spark_procedures_without_globals` | 5 | 5 | 0.0% |
| `specific_parent_type_invariant` | 0 | 0 | n/a |
| `specific_pre_post` | 0 | 0 | n/a |
| `specific_type_invariants` | 0 | 0 | n/a |
| `style_checks:M` | 0 | 0 | n/a |
| `style_checks:b` | 0 | 0 | n/a |
| `subprogram_access` | 0 | 0 | n/a |
| `suspicious_equalities` | 0 | 0 | n/a |
| `too_many_dependencies` | 0 | 0 | n/a |
| `too_many_generic_dependencies` | 0 | 0 | n/a |
| `too_many_parents` | 0 | 0 | n/a |
| `too_many_primitives` | 0 | 0 | n/a |
| `trivial_exception_handlers` | 0 | 0 | n/a |
| `unassigned_out_parameters` | 0 | 0 | n/a |
| `unchecked_address_conversions` | 0 | 0 | n/a |
| `unchecked_conversions_as_actuals` | 0 | 0 | n/a |
| `uncommented_begin` | 117 | 0 | 100.0% |
| `uncommented_begin_in_package_bodies` | 0 | 0 | n/a |
| `uncommented_end_record` | 0 | 0 | n/a |
| `unconditional_exits` | 2 | 0 | 100.0% |
| `unconstrained_array_returns` | 4 | 0 | 100.0% |
| `unconstrained_arrays` | 6 | 0 | 100.0% |
| `uninitialized_global_variables` | 0 | 0 | n/a |
| `universal_ranges` | 5 | 0 | 100.0% |
| `unnamed_blocks_and_loops` | 63 | 0 | 100.0% |
| `unnamed_exits` | 0 | 0 | n/a |
| `use_array_slices` | 0 | 0 | n/a |
| `use_case_statements` | 1 | 0 | 100.0% |
| `use_for_loops` | 0 | 0 | n/a |
| `use_for_of_loops` | 4 | 0 | 100.0% |
| `use_if_expressions` | 1 | 0 | 100.0% |
| `use_memberships` | 1 | 0 | 100.0% |
| `use_package_clauses` | 11 | 0 | 100.0% |
| `use_ranges` | 5 | 0 | 100.0% |
| `use_record_aggregates` | 0 | 0 | n/a |
| `use_simple_loops` | 0 | 0 | n/a |
| `use_while_loops` | 0 | 0 | n/a |
| `variable_scoping` | 0 | 0 | n/a |
| `visible_components` | 0 | 0 | n/a |
| `volatile_objects_without_address_clauses` | 0 | 0 | n/a |
| `warnings:c.always` | 0 | 0 | n/a |
| `warnings:f` | 0 | 0 | n/a |
| `warnings:k.mode` | 0 | 0 | n/a |
| `warnings:m.never` | 0 | 0 | n/a |
| `warnings:m.overwritten` | 0 | 0 | n/a |
| `warnings:r.conversion` | 0 | 0 | n/a |
| `warnings:r.self` | 0 | 0 | n/a |
| `warnings:r.with` | 0 | 0 | n/a |
| `warnings:u.object` | 0 | 0 | n/a |
| `warnings:u.unit` | 0 | 0 | n/a |

## Known, explained differences

- Matching is on `(file basename, line, rule pair)`; rule pairs are name-level matches, not proven semantic equivalence (`docs/src/gnatcheck-rule-comparison.md`).
- `null_paths` family (`Empty_*_Body`, `Null_Case_Alternative`): GNATcheck reports at the empty statement, AdaLang at the branch or alternative.
- `No_Multiple_Return`/`improper_returns` differ in granularity (per subprogram vs. per return); `Too_Many_Parameters`/`maximum_parameters` report spec vs. body and use different default thresholds; `Missing_Global_Contract` deliberately also fires outside `SPARK_Mode`.
- `Identical_Branches`/`Identical_Case_Alternative` vs. `duplicate_branches` (run with `min_stmt=1,min_size=1`, matched on the line GNATcheck names as the duplicate): AdaLang compares adjacent branches only, so GNATcheck's non-adjacent pairs stay GNATcheck-only; GNATcheck reports one pair per `if`/`case`, so the later members of a run of identical adjacent branches stay AdaLang-only.
- The two tools analyse different file sets: AdaLang takes the sources of the root project, GNATcheck the closure it loads. The shared-file figures above leave out findings in files only one tool analysed.
