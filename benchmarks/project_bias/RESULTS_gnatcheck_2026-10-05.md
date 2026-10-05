# project_bias: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Current results, refreshed 2026-10-05. This file replaces the earlier dated runs, which remain in the Git history. It covers the rule pairs of the 175 opt-in coding-standard checks (158 of them run here; the other 17 report nothing until configured and are not in the rule map), five of them added since the 2026-10-04 run: `Use_Clause`, `Unavailable_Body_Call`, `Deeply_Nested_Inlining`, `Integer_Type_As_Enumeration` and `Same_Instantiation`. The pairs that were already compared on 2026-09-24 are run again; since then the analyzer resolves names through imported projects (`FP-102`) and applies a project's preprocessing switches (`FP-103`), which can change their numbers too.

## Environment

- Corpus: pinned at `bb83565322eba9a0bd59ccda607edcdc0a1bd381` (`PROJECT_BIAS_REVISION`), unchanged.
- AdaLang Analyzer: 1.8.0 plus the unreleased changes listed in `CHANGELOG.md`.
- GNATcheck: the same from-source build as prior runs; one pass with the plain `-r` rules, then one pass per column-4 option line of `benchmarks/gnatcheck_rule_map.tsv` (`benchmarks/gnatcheck_rule_args.awk`).
- Reproduce: `PROJECT_BIAS_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/project_bias/run_gnatcheck.sh` (see this directory's README for
  any setup step).
- GNATcheck worker crashes ("unparsable worker output"): each GNATcheck invocation was repeated until it finished without a crash; the plain rules were run in batches of at most 25 where one pass over all of them kept crashing. Across the attempts logged for this corpus, 2 invocations were repeated. The accepted log has no crash and no GNATcheck error line. The five rules added on 2026-10-05 were run one rule per invocation and appended to it; the analyzer side was then run again against the whole log.

## Totals

| | 2026-10-05, all pairs | 2026-10-05, pairs of 2026-09-24 | 2026-09-24 |
| --- | ---: | ---: | ---: |
| AdaLang findings | 1846 | 387 | 387 |
| &nbsp;&nbsp;matched by GNATcheck | 1752 (94.9%) | 295 (76.2%) | 295 (76.2%) |
| GNATcheck findings | 1897 | 440 | 440 |
| &nbsp;&nbsp;matched by AdaLang | 1752 (92.4%) | 295 (67.0%) | 295 (67.0%) |

Every pair of 2026-09-24 has the same numbers as then.

## Coding-standard checks

The 158 new pairs, counted over all files: 1459 AdaLang findings, 1457 matched by GNATcheck (99.9%); 1457 GNATcheck findings, 1457 matched by AdaLang (100.0%). 54 of the 158 checks have a finding from one tool or the other on this corpus.

The two tools do not analyse the same set of files (see the notes below), so the same pairs are also counted over the files both analysed: 1459 AdaLang findings and 1459 GNATcheck findings, 1459 at the same file and line; 0 AdaLang-only, 0 GNATcheck-only.

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
| Anonymous_Subtype | direct | 311 | 0 | 100.0% |
| Array_Slice | direct | 11 | 0 | 100.0% |
| Binary_Case_Statement | direct | 1 | 0 | 100.0% |
| Bit_Record_Without_Layout | direct | 0 | 0 | n/a |
| Boolean_Relational_Operator | direct | 14 | 0 | 100.0% |
| Complex_Inlined_Subprogram | direct | 0 | 0 | n/a |
| Concurrent_Interface | direct | 0 | 0 | n/a |
| Conditional_Expression | direct | 34 | 0 | 100.0% |
| Constant_Condition | close | 0 | 0 | n/a |
| Constant_Overlay | direct | 0 | 0 | n/a |
| Constructor | direct | 0 | 0 | n/a |
| Cyclomatic_Complexity | direct | 3 | 0 | 100.0% |
| Dead_Store | close | 17 | 17 | 0.0% |
| Declaration_In_Block | close | 5 | 0 | 100.0% |
| Deep_Inheritance_Hierarchy | direct | 0 | 0 | n/a |
| Deep_Library_Hierarchy | direct | 0 | 0 | n/a |
| Deep_Nesting | direct | 2 | 2 | 0.0% |
| Deeply_Nested_Generic | direct | 0 | 0 | n/a |
| Deeply_Nested_Inlining | direct | 0 | 0 | n/a |
| Deeply_Nested_Instantiation | direct | 0 | 0 | n/a |
| Default_Parameter | direct | 1 | 0 | 100.0% |
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
| End_Of_Line_Comment | direct | 20 | 0 | 100.0% |
| Enumeration_Range_In_Case_Statement | direct | 0 | 0 | n/a |
| Enumeration_Representation_Clause | direct | 0 | 0 | n/a |
| Essential_Complexity | direct | 3 | 0 | 100.0% |
| Exception_As_Control_Flow | direct | 0 | 0 | n/a |
| Exception_Propagation | close | 0 | 0 | n/a |
| Exception_Swallowed | close | 0 | 0 | n/a |
| Exit_From_Conditional_Loop | direct | 3 | 0 | 100.0% |
| Exit_Without_Loop_Name | direct | 0 | 0 | n/a |
| Expanded_Loop_Exit_Name | direct | 0 | 0 | n/a |
| Explicit_Full_Discrete_Range | direct | 20 | 0 | 100.0% |
| Explicit_Inlining | direct | 0 | 0 | n/a |
| Expression_Function | direct | 0 | 0 | n/a |
| Final_Package | direct | 0 | 0 | n/a |
| Fixed_Equality | direct | 0 | 0 | n/a |
| Floating_Equality | direct | 31 | 0 | 100.0% |
| Function_Out_Parameter | direct | 0 | 0 | n/a |
| Function_Style_Procedure | direct | 0 | 0 | n/a |
| Generic_In_Out_Object | direct | 0 | 0 | n/a |
| Generic_In_Subprogram | direct | 0 | 0 | n/a |
| Global_Variable | direct | 2 | 0 | 100.0% |
| Identical_Branches | direct | 0 | 0 | n/a |
| Identical_Case_Alternative | close | 0 | 0 | n/a |
| Implicit_In_Mode | direct | 53 | 0 | 100.0% |
| Implicit_Small | direct | 0 | 0 | n/a |
| Improperly_Located_Instantiation | direct | 1 | 0 | 100.0% |
| Incomplete_Representation_Specification | direct | 0 | 0 | n/a |
| Infinite_Loop | close | 0 | 0 | n/a |
| Integer_Type_As_Enumeration | direct | 0 | 0 | n/a |
| Library_Level_Initialization | close | 4 | 4 | 0.0% |
| Library_Level_Subprogram | direct | 1 | 0 | 100.0% |
| Local_Instantiation | direct | 1 | 0 | 100.0% |
| Local_Package | direct | 0 | 0 | n/a |
| Local_Use_Clause | direct | 27 | 0 | 100.0% |
| Logical_SLOC | direct | 1 | 0 | 100.0% |
| Long_Line | direct | 11 | 0 | 100.0% |
| Lowercase_Keyword | direct | 0 | 0 | n/a |
| Magic_Number | close | 155 | 42 | 72.9% |
| Maximum_Expression_Complexity | direct | 121 | 0 | 100.0% |
| Maximum_Identifier_Length | direct | 17 | 0 | 100.0% |
| Maximum_Lines | direct | 0 | 0 | n/a |
| Maximum_Out_Parameters | direct | 15 | 0 | 100.0% |
| Maximum_Subprogram_Lines | direct | 0 | 0 | n/a |
| Membership_For_Validity | direct | 1 | 0 | 100.0% |
| Membership_Test | direct | 111 | 0 | 100.0% |
| Misnamed_Controlling_Parameter | direct | 0 | 0 | n/a |
| Misplaced_Representation_Item | direct | 0 | 0 | n/a |
| Missing_Global_Contract | close | 3 | 3 | 0.0% |
| Missing_Overriding_Indicator | direct | 0 | 0 | n/a |
| Multiple_Protected_Entries | direct | 0 | 0 | n/a |
| Naming_Convention | close | 9 | 2 | 77.8% |
| Nested_Path | direct | 19 | 0 | 100.0% |
| Nested_Subprogram | direct | 7 | 0 | 100.0% |
| No_Abort | direct | 0 | 0 | n/a |
| No_Access_To_Subp_Def | direct | 0 | 0 | n/a |
| No_Block_Statement | direct | 7 | 0 | 100.0% |
| No_Closing_Name | direct | 0 | 0 | n/a |
| No_Controlled_Type | direct | 0 | 0 | n/a |
| No_Explicit_Real_Range | direct | 0 | 0 | n/a |
| No_Goto | direct | 0 | 0 | n/a |
| No_Inherited_Classwide_Pre | direct | 0 | 0 | n/a |
| No_Multiple_Return | direct | 4 | 4 | 0.0% |
| No_Pragma | close | 115 | 0 | 100.0% |
| No_Recursion | direct | 0 | 0 | n/a |
| No_Scalar_Storage_Order | direct | 0 | 0 | n/a |
| No_Use_Package_Clause | direct | 28 | 0 | 100.0% |
| Non_Component_In_Barrier | direct | 0 | 0 | n/a |
| Non_Constant_Overlay | direct | 0 | 0 | n/a |
| Non_Qualified_Aggregate | direct | 107 | 0 | 100.0% |
| Non_SPARK_Attribute | direct | 74 | 0 | 100.0% |
| Non_Short_Circuit_Condition | direct | 0 | 0 | n/a |
| Non_Tagged_Derived_Type | direct | 0 | 0 | n/a |
| Non_Visible_Exception | direct | 0 | 0 | n/a |
| Nonoverlay_Address_Specification | direct | 0 | 0 | n/a |
| Not_Imported_Overlay | direct | 0 | 0 | n/a |
| Null_Case_Alternative | close | 0 | 0 | n/a |
| Null_Statement | direct | 0 | 0 | n/a |
| Number_Declaration | direct | 0 | 0 | n/a |
| Numeric_Format | direct | 27 | 0 | 100.0% |
| Numeric_Indexing | direct | 9 | 0 | 100.0% |
| Object_Declaration_Out_Of_Order | direct | 0 | 0 | n/a |
| Object_Of_Anonymous_Type | direct | 0 | 0 | n/a |
| One_Construct_Per_Line | direct | 0 | 0 | n/a |
| One_Tagged_Type_Per_Package | direct | 0 | 0 | n/a |
| Operator_Renaming | direct | 0 | 0 | n/a |
| Others_In_Aggregate | direct | 0 | 0 | n/a |
| Others_In_Case_Statement | direct | 1 | 0 | 100.0% |
| Others_In_Exception_Handler | direct | 1 | 0 | 100.0% |
| Out_Parameter_Read_In_Exception_Handler | direct | 2 | 2 | 0.0% |
| Outbound_Protected_Assignment | direct | 0 | 0 | n/a |
| Outer_Loop_Exit | direct | 0 | 0 | n/a |
| Outside_Reference_From_Subprogram | direct | 7 | 0 | 100.0% |
| Overloaded_Operator | direct | 0 | 0 | n/a |
| Overly_Nested_Scope | direct | 0 | 0 | n/a |
| Overwritten_Assignment | close | 0 | 0 | n/a |
| Parameters_Out_Of_Order | direct | 34 | 0 | 100.0% |
| Pos_On_Enumeration_Type | direct | 16 | 0 | 100.0% |
| Positional_Component | direct | 0 | 0 | n/a |
| Positional_Defaulted_Generic_Parameter | direct | 0 | 0 | n/a |
| Positional_Defaulted_Parameter | direct | 3 | 0 | 100.0% |
| Positional_Generic_Parameter | direct | 0 | 0 | n/a |
| Positional_Parameter | direct | 4 | 0 | 100.0% |
| Predefined_Numeric_Type | direct | 120 | 0 | 100.0% |
| Predicate_Testing | direct | 3 | 0 | 100.0% |
| Printable_ASCII | direct | 0 | 0 | n/a |
| Profile_Discrepancy | direct | 0 | 0 | n/a |
| Quantified_Expression | direct | 90 | 0 | 100.0% |
| Raising_External_Exception | direct | 0 | 0 | n/a |
| Raising_Predefined_Exception | direct | 0 | 0 | n/a |
| Redundant_Boolean_Comparison | close | 14 | 0 | 100.0% |
| Redundant_Type_Conversion | close | 0 | 0 | n/a |
| Relative_Delay | direct | 1 | 0 | 100.0% |
| Renaming_Declaration | direct | 0 | 0 | n/a |
| Representation_Specification | direct | 5 | 0 | 100.0% |
| Same_Instantiation | direct | 0 | 0 | n/a |
| Same_Logic | direct | 0 | 0 | n/a |
| Same_Operand | direct | 0 | 0 | n/a |
| Self_Assignment | close | 0 | 0 | n/a |
| Separate_Numeric_Error_Handler | direct | 0 | 0 | n/a |
| Separate_Unit | direct | 0 | 0 | n/a |
| Single_Value_Enumeration_Type | direct | 0 | 0 | n/a |
| Size_Attribute_For_Type | direct | 0 | 0 | n/a |
| Specific_Parent_Type_Invariant | direct | 0 | 0 | n/a |
| Specific_Pre_Post | direct | 0 | 0 | n/a |
| Specific_Type_Invariant | direct | 0 | 0 | n/a |
| Suspicious_Equality | direct | 0 | 0 | n/a |
| Too_Many_Generic_Dependencies | direct | 0 | 0 | n/a |
| Too_Many_Parameters | direct | 0 | 0 | n/a |
| Too_Many_Parents | direct | 0 | 0 | n/a |
| Too_Many_Primitives | direct | 0 | 0 | n/a |
| Trailing_Whitespace | direct | 0 | 0 | n/a |
| Unavailable_Body_Call | direct | 4 | 0 | 100.0% |
| Unchecked_Address_Conversion | direct | 0 | 0 | n/a |
| Unchecked_Conversion_As_Actual | direct | 0 | 0 | n/a |
| Uncommented_Begin | direct | 27 | 0 | 100.0% |
| Uncommented_Begin_In_Package_Body | direct | 0 | 0 | n/a |
| Uncommented_End_Record | direct | 0 | 0 | n/a |
| Unconditional_Exit | direct | 1 | 0 | 100.0% |
| Unconstrained_Array_Return | direct | 1 | 0 | 100.0% |
| Unconstrained_Array_Type | direct | 1 | 0 | 100.0% |
| Uninitialized_Global_Variable | direct | 0 | 0 | n/a |
| Uninitialized_Output | close | 0 | 0 | n/a |
| Universal_Range | direct | 32 | 0 | 100.0% |
| Unnamed_Block_Or_Loop | direct | 4 | 0 | 100.0% |
| Unnamed_Exit | direct | 0 | 0 | n/a |
| Unused_Parameter | close | 0 | 0 | n/a |
| Unused_Variable | close | 0 | 0 | n/a |
| Unused_With_Clause | close | 1 | 0 | 100.0% |
| Use_Array_Slice | direct | 0 | 0 | n/a |
| Use_Case_Statement | direct | 0 | 0 | n/a |
| Use_Clause | direct | 28 | 0 | 100.0% |
| Use_For_Loop | direct | 0 | 0 | n/a |
| Use_For_Of_Loop | direct | 2 | 0 | 100.0% |
| Use_If_Expression | direct | 0 | 0 | n/a |
| Use_Membership | direct | 0 | 0 | n/a |
| Use_Range | direct | 20 | 0 | 100.0% |
| Use_Record_Aggregate | direct | 0 | 0 | n/a |
| Use_Simple_Loop | direct | 0 | 0 | n/a |
| Use_While_Loop | direct | 0 | 0 | n/a |
| Variable_Scoping | direct | 0 | 0 | n/a |
| Visible_Component | direct | 0 | 0 | n/a |
| Volatile_Object_Without_Address | direct | 0 | 0 | n/a |
| Wrong_Parameter_Mode | close | 18 | 18 | 0.0% |

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
| `anonymous_subtypes` | 311 | 0 | 100.0% |
| `at_representation_clauses` | 0 | 0 | n/a |
| `binary_case_statements` | 1 | 0 | 100.0% |
| `bit_records_without_layout_definition` | 0 | 0 | n/a |
| `blocks` | 7 | 0 | 100.0% |
| `boolean_negations` | 0 | 0 | n/a |
| `boolean_relational_operators` | 14 | 0 | 100.0% |
| `calls_outside_elaboration` | 0 | 0 | n/a |
| `complex_inlined_subprograms` | 0 | 0 | n/a |
| `concurrent_interfaces` | 0 | 0 | n/a |
| `conditional_expressions` | 34 | 0 | 100.0% |
| `constant_overlays` | 0 | 0 | n/a |
| `constructors` | 0 | 0 | n/a |
| `controlled_type_declarations` | 0 | 0 | n/a |
| `declarations_in_blocks` | 5 | 0 | 100.0% |
| `deep_inheritance_hierarchies` | 0 | 0 | n/a |
| `deep_library_hierarchy` | 0 | 0 | n/a |
| `deeply_nested_generics` | 0 | 0 | n/a |
| `deeply_nested_inlining` | 0 | 0 | n/a |
| `deeply_nested_instantiations` | 0 | 0 | n/a |
| `default_parameters` | 1 | 0 | 100.0% |
| `default_values_for_record_components` | 0 | 0 | n/a |
| `deriving_from_predefined_type` | 0 | 0 | n/a |
| `direct_calls_to_primitives` | 0 | 0 | n/a |
| `discriminated_records` | 0 | 0 | n/a |
| `downward_view_conversions` | 0 | 0 | n/a |
| `duplicate_branches` | 0 | 0 | n/a |
| `end_of_line_comments` | 20 | 0 | 100.0% |
| `enumeration_ranges_in_case_statements` | 0 | 0 | n/a |
| `enumeration_representation_clauses` | 0 | 0 | n/a |
| `exception_propagation_from_callbacks` | 0 | 0 | n/a |
| `exception_propagation_from_export` | 0 | 0 | n/a |
| `exception_propagation_from_tasks` | 0 | 0 | n/a |
| `exceptions_as_control_flow` | 0 | 0 | n/a |
| `exit_statements_with_no_loop_name` | 0 | 0 | n/a |
| `exits_from_conditional_loops` | 3 | 0 | 100.0% |
| `expanded_loop_exit_names` | 0 | 0 | n/a |
| `explicit_full_discrete_ranges` | 20 | 0 | 100.0% |
| `explicit_inlining` | 0 | 0 | n/a |
| `expression_functions` | 0 | 0 | n/a |
| `final_package` | 0 | 0 | n/a |
| `fixed_equality_checks` | 0 | 0 | n/a |
| `float_equality_checks` | 31 | 0 | 100.0% |
| `forbidden_pragmas` | 115 | 0 | 100.0% |
| `function_out_parameters` | 0 | 0 | n/a |
| `function_style_procedures` | 0 | 0 | n/a |
| `generic_in_out_objects` | 0 | 0 | n/a |
| `generics_in_subprograms` | 0 | 0 | n/a |
| `global_variables` | 2 | 0 | 100.0% |
| `goto_statements` | 0 | 0 | n/a |
| `implicit_in_mode_parameters` | 53 | 0 | 100.0% |
| `implicit_small_for_fixed_point_types` | 0 | 0 | n/a |
| `improper_returns` | 34 | 34 | 0.0% |
| `improperly_located_instantiations` | 1 | 0 | 100.0% |
| `incomplete_representation_specifications` | 0 | 0 | n/a |
| `integer_types_as_enum` | 0 | 0 | n/a |
| `library_level_subprograms` | 1 | 0 | 100.0% |
| `local_instantiations` | 1 | 0 | 100.0% |
| `local_packages` | 0 | 0 | n/a |
| `local_use_clauses` | 27 | 0 | 100.0% |
| `lowercase_keywords` | 0 | 0 | n/a |
| `max_identifier_length` | 17 | 0 | 100.0% |
| `maximum_expression_complexity` | 121 | 0 | 100.0% |
| `maximum_lines` | 0 | 0 | n/a |
| `maximum_out_parameters` | 15 | 0 | 100.0% |
| `maximum_parameters` | 17 | 17 | 0.0% |
| `maximum_subprogram_lines` | 0 | 0 | n/a |
| `membership_for_validity` | 1 | 0 | 100.0% |
| `membership_tests` | 111 | 0 | 100.0% |
| `metrics_cyclomatic_complexity` | 24 | 21 | 12.5% |
| `metrics_essential_complexity` | 3 | 0 | 100.0% |
| `metrics_lsloc` | 1 | 0 | 100.0% |
| `min_identifier_length` | 47 | 40 | 14.9% |
| `misnamed_controlling_parameters` | 0 | 0 | n/a |
| `misplaced_representation_items` | 0 | 0 | n/a |
| `multiple_entries_in_protected_definitions` | 0 | 0 | n/a |
| `nested_paths` | 19 | 0 | 100.0% |
| `nested_subprograms` | 7 | 0 | 100.0% |
| `no_closing_names` | 0 | 0 | n/a |
| `no_explicit_real_range` | 0 | 0 | n/a |
| `no_inherited_classwide_pre` | 0 | 0 | n/a |
| `no_scalar_storage_order_specified` | 0 | 0 | n/a |
| `non_component_in_barriers` | 0 | 0 | n/a |
| `non_constant_overlays` | 0 | 0 | n/a |
| `non_qualified_aggregates` | 107 | 0 | 100.0% |
| `non_short_circuit_operators` | 0 | 0 | n/a |
| `non_spark_attributes` | 74 | 0 | 100.0% |
| `non_tagged_derived_types` | 0 | 0 | n/a |
| `non_visible_exceptions` | 0 | 0 | n/a |
| `nonoverlay_address_specifications` | 0 | 0 | n/a |
| `not_imported_overlays` | 0 | 0 | n/a |
| `null_paths` | 0 | 0 | n/a |
| `number_declarations` | 0 | 0 | n/a |
| `numeric_format` | 27 | 0 | 100.0% |
| `numeric_indexing` | 9 | 0 | 100.0% |
| `numeric_literals` | 125 | 12 | 90.4% |
| `object_declarations_out_of_order` | 0 | 0 | n/a |
| `objects_of_anonymous_types` | 0 | 0 | n/a |
| `one_construct_per_line` | 0 | 0 | n/a |
| `one_tagged_type_per_package` | 0 | 0 | n/a |
| `operator_renamings` | 0 | 0 | n/a |
| `others_in_aggregates` | 0 | 0 | n/a |
| `others_in_case_statements` | 1 | 0 | 100.0% |
| `others_in_exception_handlers` | 1 | 0 | 100.0% |
| `out_parameter_read_in_exception_handler` | 0 | 0 | n/a |
| `outbound_protected_assignments` | 0 | 0 | n/a |
| `outer_loop_exits` | 0 | 0 | n/a |
| `outside_references_from_subprograms` | 7 | 0 | 100.0% |
| `overloaded_operators` | 0 | 0 | n/a |
| `overly_nested_control_structures` | 1 | 1 | 0.0% |
| `overly_nested_scopes` | 0 | 0 | n/a |
| `overriding_indicators` | 0 | 0 | n/a |
| `parameters_aliasing` | 0 | 0 | n/a |
| `parameters_out_of_order` | 34 | 0 | 100.0% |
| `pos_on_enumeration_types` | 16 | 0 | 100.0% |
| `positional_actuals_for_defaulted_generic_parameters` | 0 | 0 | n/a |
| `positional_actuals_for_defaulted_parameters` | 3 | 0 | 100.0% |
| `positional_components` | 0 | 0 | n/a |
| `positional_generic_parameters` | 0 | 0 | n/a |
| `positional_parameters` | 4 | 0 | 100.0% |
| `potential_parameters_aliasing` | 0 | 0 | n/a |
| `predefined_numeric_types` | 120 | 0 | 100.0% |
| `predicate_testing` | 3 | 0 | 100.0% |
| `printable_ascii` | 0 | 0 | n/a |
| `profile_discrepancies` | 0 | 0 | n/a |
| `quantified_expressions` | 90 | 0 | 100.0% |
| `raising_external_exceptions` | 0 | 0 | n/a |
| `raising_predefined_exceptions` | 0 | 0 | n/a |
| `recursive_subprograms` | 0 | 0 | n/a |
| `redundant_boolean_expressions` | 14 | 0 | 100.0% |
| `redundant_null_statements` | 0 | 0 | n/a |
| `relative_delay_statements` | 1 | 0 | 100.0% |
| `renamings` | 0 | 0 | n/a |
| `representation_specifications` | 5 | 0 | 100.0% |
| `same_instantiations` | 0 | 0 | n/a |
| `same_logic` | 0 | 0 | n/a |
| `same_operands` | 0 | 0 | n/a |
| `same_tests` | 0 | 0 | n/a |
| `separate_numeric_error_handlers` | 0 | 0 | n/a |
| `separates` | 0 | 0 | n/a |
| `silent_exception_handlers` | 2 | 2 | 0.0% |
| `simple_loop_statements` | 0 | 0 | n/a |
| `single_value_enumeration_types` | 0 | 0 | n/a |
| `size_attribute_for_types` | 0 | 0 | n/a |
| `slices` | 11 | 0 | 100.0% |
| `spark_procedures_without_globals` | 0 | 0 | n/a |
| `specific_parent_type_invariant` | 0 | 0 | n/a |
| `specific_pre_post` | 0 | 0 | n/a |
| `specific_type_invariants` | 0 | 0 | n/a |
| `style_checks:M` | 11 | 0 | 100.0% |
| `style_checks:b` | 0 | 0 | n/a |
| `subprogram_access` | 0 | 0 | n/a |
| `suspicious_equalities` | 0 | 0 | n/a |
| `too_many_dependencies` | 4 | 4 | 0.0% |
| `too_many_generic_dependencies` | 0 | 0 | n/a |
| `too_many_parents` | 0 | 0 | n/a |
| `too_many_primitives` | 0 | 0 | n/a |
| `trivial_exception_handlers` | 0 | 0 | n/a |
| `unassigned_out_parameters` | 0 | 0 | n/a |
| `unavailable_body_calls` | 4 | 0 | 100.0% |
| `unchecked_address_conversions` | 0 | 0 | n/a |
| `unchecked_conversions_as_actuals` | 0 | 0 | n/a |
| `uncommented_begin` | 27 | 0 | 100.0% |
| `uncommented_begin_in_package_bodies` | 0 | 0 | n/a |
| `uncommented_end_record` | 0 | 0 | n/a |
| `unconditional_exits` | 1 | 0 | 100.0% |
| `unconstrained_array_returns` | 1 | 0 | 100.0% |
| `unconstrained_arrays` | 1 | 0 | 100.0% |
| `uninitialized_global_variables` | 0 | 0 | n/a |
| `universal_ranges` | 32 | 0 | 100.0% |
| `unnamed_blocks_and_loops` | 4 | 0 | 100.0% |
| `unnamed_exits` | 0 | 0 | n/a |
| `use_array_slices` | 0 | 0 | n/a |
| `use_case_statements` | 0 | 0 | n/a |
| `use_clauses` | 28 | 0 | 100.0% |
| `use_for_loops` | 0 | 0 | n/a |
| `use_for_of_loops` | 2 | 0 | 100.0% |
| `use_if_expressions` | 0 | 0 | n/a |
| `use_memberships` | 0 | 0 | n/a |
| `use_package_clauses` | 28 | 0 | 100.0% |
| `use_ranges` | 20 | 0 | 100.0% |
| `use_record_aggregates` | 0 | 0 | n/a |
| `use_simple_loops` | 0 | 0 | n/a |
| `use_while_loops` | 0 | 0 | n/a |
| `variable_scoping` | 0 | 0 | n/a |
| `visible_components` | 0 | 0 | n/a |
| `volatile_objects_without_address_clauses` | 0 | 0 | n/a |
| `warnings:c.always` | 14 | 14 | 0.0% |
| `warnings:f` | 0 | 0 | n/a |
| `warnings:k.mode` | 0 | 0 | n/a |
| `warnings:m.never` | 0 | 0 | n/a |
| `warnings:m.overwritten` | 0 | 0 | n/a |
| `warnings:r.conversion` | 0 | 0 | n/a |
| `warnings:r.self` | 0 | 0 | n/a |
| `warnings:r.with` | 0 | 0 | n/a |
| `warnings:u.object` | 0 | 0 | n/a |
| `warnings:u.unit` | 1 | 0 | 100.0% |

## Known, explained differences

- Matching is on `(file basename, line, rule pair)`; rule pairs are name-level matches, not proven semantic equivalence (`docs/src/gnatcheck-rule-comparison.md`).
- `null_paths` family (`Empty_*_Body`, `Null_Case_Alternative`): GNATcheck reports at the empty statement, AdaLang at the branch or alternative.
- `No_Multiple_Return`/`improper_returns` differ in granularity (per subprogram vs. per return); `Too_Many_Parameters`/`maximum_parameters` report spec vs. body and use different default thresholds; `Missing_Global_Contract` deliberately also fires outside `SPARK_Mode`.
- `Identical_Branches`/`Identical_Case_Alternative` vs. `duplicate_branches` (run with `min_stmt=1,min_size=1`, matched on the line GNATcheck names as the duplicate): AdaLang compares adjacent branches only, so GNATcheck's non-adjacent pairs stay GNATcheck-only; GNATcheck reports one pair per `if`/`case`, so the later members of a run of identical adjacent branches stay AdaLang-only.
- The two tools analyse different file sets: AdaLang takes the sources of the root project, GNATcheck the closure it loads. The shared-file figures above leave out findings in files only one tool analysed.
