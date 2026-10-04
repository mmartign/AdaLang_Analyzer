# coap_spark: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Current results, refreshed 2026-10-04. This file replaces the earlier dated runs, which remain in the Git history. The refresh adds the rule pairs of the 167 opt-in coding-standard checks (153 of them run here; the other 14 report nothing until configured and are not in the rule map). The pairs that were already compared on 2026-09-24 are run again unchanged.

## Environment

- Corpus: pinned at `2fa345b8c70d621287b932aee7ea39b3520a5adf` (`COAP_SPARK_REVISION`), unchanged.
- AdaLang Analyzer: 1.7.0 plus the unreleased coding-standard checks (branch `gnatcheck-rule-parity`).
- GNATcheck: the same from-source build as prior runs; one pass with the plain `-r` rules, then one pass per column-4 option line of `benchmarks/gnatcheck_rule_map.tsv` (`benchmarks/gnatcheck_rule_args.awk`).
- Reproduce: `COAP_SPARK_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/coap_spark/run_gnatcheck.sh` (see this directory's README for
  any setup step).
- GNATcheck worker crashes ("unparsable worker output"): each GNATcheck invocation was repeated until it finished without a crash; the plain rules were run in batches of at most 25 where one pass over all of them kept crashing. Across the attempts logged for this corpus, 9 invocations were repeated. The accepted log has no crash and no GNATcheck error line.

## Totals

| | 2026-10-04, all pairs | 2026-10-04, pairs of 2026-09-24 | 2026-09-24 |
| --- | ---: | ---: | ---: |
| AdaLang findings | 13354 | 3066 | 3066 |
| &nbsp;&nbsp;matched by GNATcheck | 12379 (92.7%) | 2092 (68.2%) | 2092 (68.2%) |
| GNATcheck findings | 43268 | 10094 | 10094 |
| &nbsp;&nbsp;matched by AdaLang | 12379 (28.6%) | 2092 (20.7%) | 2092 (20.7%) |

Every pair of 2026-09-24 has the same numbers as then.

## Coding-standard checks

The 153 new pairs, counted over all files: 10288 AdaLang findings, 10287 matched by GNATcheck (100.0%); 33174 GNATcheck findings, 10287 matched by AdaLang (31.0%). 74 of the 153 checks have a finding from one tool or the other on this corpus.

The two tools do not analyse the same set of files (see the notes below), so the same pairs are also counted over the files both analysed: 10288 AdaLang findings and 10314 GNATcheck findings, 10287 at the same file and line; 1 AdaLang-only, 27 GNATcheck-only.

- The 27 GNATcheck-only findings are in `coap_spark-channel.adb`, `coap_spark-messages*.adb` and one generated session file, at calls into the wolfSSL binding and other units outside the root project, which AdaLang does not resolve (see the notes below).
- The one AdaLang-only finding is `Function_Style_Procedure` on a body whose declaration AdaLang could not resolve.

## Duplicate branches

`Identical_Branches` + `Identical_Case_Alternative`: 22 findings, 2 matched by GNATcheck's `duplicate_branches` (9.1%); `duplicate_branches`: 18 findings, 2 matched (11.1%). With GNATcheck's default thresholds (4 statements / 14 tokens) this pair had 0 GNATcheck findings on every corpus.

## Per AdaLang rule

| AdaLang rule | Match | Findings | AdaLang-only | Matched |
| --- | --- | ---: | ---: | ---: |
| Abstract_Type_Declaration | direct | 0 | 0 | n/a |
| Access_To_Local_Object | direct | 0 | 0 | n/a |
| Ada05_Formal_Package | direct | 0 | 0 | n/a |
| Ada_2022_In_Ghost_Code | direct | 4 | 0 | 100.0% |
| Address_Clause | close | 0 | 0 | n/a |
| Address_Of_Non_Volatile_Object | direct | 0 | 0 | n/a |
| Aliasing_Between_Parameters | direct | 1 | 1 | 0.0% |
| Anonymous_Access_Type | direct | 0 | 0 | n/a |
| Anonymous_Array_Type | direct | 0 | 0 | n/a |
| Anonymous_Subtype | direct | 292 | 0 | 100.0% |
| Array_Slice | direct | 160 | 0 | 100.0% |
| Binary_Case_Statement | direct | 5 | 0 | 100.0% |
| Bit_Record_Without_Layout | direct | 0 | 0 | n/a |
| Boolean_Relational_Operator | direct | 89 | 0 | 100.0% |
| Complex_Inlined_Subprogram | direct | 0 | 0 | n/a |
| Concurrent_Interface | direct | 0 | 0 | n/a |
| Conditional_Expression | direct | 399 | 0 | 100.0% |
| Constant_Condition | close | 1 | 1 | 0.0% |
| Constant_Overlay | direct | 0 | 0 | n/a |
| Constructor | direct | 0 | 0 | n/a |
| Cyclomatic_Complexity | direct | 11 | 0 | 100.0% |
| Dead_Store | close | 0 | 0 | n/a |
| Declaration_In_Block | close | 43 | 0 | 100.0% |
| Deep_Inheritance_Hierarchy | direct | 0 | 0 | n/a |
| Deep_Library_Hierarchy | direct | 0 | 0 | n/a |
| Deep_Nesting | direct | 2 | 2 | 0.0% |
| Deeply_Nested_Generic | direct | 0 | 0 | n/a |
| Deeply_Nested_Instantiation | direct | 0 | 0 | n/a |
| Default_Parameter | direct | 84 | 0 | 100.0% |
| Default_Value_For_Record_Component | direct | 86 | 0 | 100.0% |
| Dependency_Limit | direct | 0 | 0 | n/a |
| Deriving_From_Predefined_Type | direct | 3 | 0 | 100.0% |
| Direct_Call_To_Primitive | direct | 0 | 0 | n/a |
| Discriminated_Record | direct | 14 | 0 | 100.0% |
| Downward_View_Conversion | direct | 0 | 0 | n/a |
| Duplicate_Boolean_Operand | close | 0 | 0 | n/a |
| Duplicate_Condition | direct | 0 | 0 | n/a |
| Duplicate_With_Clause | direct | 0 | 0 | n/a |
| Empty_Else_Body | close | 0 | 0 | n/a |
| Empty_Elsif_Body | close | 0 | 0 | n/a |
| Empty_Exception_Handler | direct | 0 | 0 | n/a |
| Empty_If_Body | close | 0 | 0 | n/a |
| Empty_Then_Body | close | 0 | 0 | n/a |
| End_Of_Line_Comment | direct | 1 | 0 | 100.0% |
| Enumeration_Range_In_Case_Statement | direct | 0 | 0 | n/a |
| Enumeration_Representation_Clause | direct | 9 | 0 | 100.0% |
| Essential_Complexity | direct | 17 | 0 | 100.0% |
| Exception_As_Control_Flow | direct | 0 | 0 | n/a |
| Exception_Propagation | close | 0 | 0 | n/a |
| Exception_Swallowed | close | 0 | 0 | n/a |
| Exit_From_Conditional_Loop | direct | 16 | 0 | 100.0% |
| Exit_Without_Loop_Name | direct | 12 | 0 | 100.0% |
| Expanded_Loop_Exit_Name | direct | 0 | 0 | n/a |
| Explicit_Full_Discrete_Range | direct | 0 | 0 | n/a |
| Explicit_Inlining | direct | 0 | 0 | n/a |
| Expression_Function | direct | 515 | 0 | 100.0% |
| Final_Package | direct | 0 | 0 | n/a |
| Fixed_Equality | direct | 0 | 0 | n/a |
| Floating_Equality | direct | 0 | 0 | n/a |
| Function_Out_Parameter | direct | 0 | 0 | n/a |
| Function_Style_Procedure | direct | 63 | 1 | 98.4% |
| Generic_In_Out_Object | direct | 0 | 0 | n/a |
| Generic_In_Subprogram | direct | 0 | 0 | n/a |
| Global_Variable | direct | 0 | 0 | n/a |
| Identical_Branches | direct | 2 | 1 | 50.0% |
| Identical_Case_Alternative | close | 20 | 19 | 5.0% |
| Implicit_In_Mode | direct | 1548 | 0 | 100.0% |
| Implicit_Small | direct | 0 | 0 | n/a |
| Improperly_Located_Instantiation | direct | 22 | 0 | 100.0% |
| Incomplete_Representation_Specification | direct | 0 | 0 | n/a |
| Infinite_Loop | close | 0 | 0 | n/a |
| Library_Level_Initialization | close | 0 | 0 | n/a |
| Library_Level_Subprogram | direct | 0 | 0 | n/a |
| Local_Instantiation | direct | 16 | 0 | 100.0% |
| Local_Package | direct | 3 | 0 | 100.0% |
| Local_Use_Clause | direct | 132 | 0 | 100.0% |
| Logical_SLOC | direct | 15 | 0 | 100.0% |
| Long_Line | direct | 801 | 801 | 0.0% |
| Lowercase_Keyword | direct | 0 | 0 | n/a |
| Magic_Number | close | 503 | 50 | 90.1% |
| Maximum_Expression_Complexity | direct | 1062 | 0 | 100.0% |
| Maximum_Identifier_Length | direct | 382 | 0 | 100.0% |
| Maximum_Lines | direct | 0 | 0 | n/a |
| Maximum_Out_Parameters | direct | 9 | 0 | 100.0% |
| Maximum_Subprogram_Lines | direct | 0 | 0 | n/a |
| Membership_For_Validity | direct | 0 | 0 | n/a |
| Membership_Test | direct | 93 | 0 | 100.0% |
| Misnamed_Controlling_Parameter | direct | 1 | 0 | 100.0% |
| Misplaced_Representation_Item | direct | 0 | 0 | n/a |
| Missing_Global_Contract | close | 24 | 24 | 0.0% |
| Missing_Overriding_Indicator | direct | 0 | 0 | n/a |
| Multiple_Protected_Entries | direct | 0 | 0 | n/a |
| Naming_Convention | close | 36 | 18 | 50.0% |
| Nested_Path | direct | 3 | 0 | 100.0% |
| Nested_Subprogram | direct | 62 | 0 | 100.0% |
| No_Abort | direct | 0 | 0 | n/a |
| No_Access_To_Subp_Def | direct | 0 | 0 | n/a |
| No_Block_Statement | direct | 43 | 0 | 100.0% |
| No_Closing_Name | direct | 0 | 0 | n/a |
| No_Controlled_Type | direct | 0 | 0 | n/a |
| No_Explicit_Real_Range | direct | 0 | 0 | n/a |
| No_Goto | direct | 136 | 0 | 100.0% |
| No_Inherited_Classwide_Pre | direct | 0 | 0 | n/a |
| No_Multiple_Return | direct | 18 | 18 | 0.0% |
| No_Pragma | close | 1449 | 0 | 100.0% |
| No_Recursion | direct | 0 | 0 | n/a |
| No_Scalar_Storage_Order | direct | 0 | 0 | n/a |
| No_Use_Package_Clause | direct | 11 | 0 | 100.0% |
| Non_Component_In_Barrier | direct | 0 | 0 | n/a |
| Non_Constant_Overlay | direct | 0 | 0 | n/a |
| Non_Qualified_Aggregate | direct | 236 | 0 | 100.0% |
| Non_SPARK_Attribute | direct | 1258 | 0 | 100.0% |
| Non_Short_Circuit_Condition | direct | 23 | 13 | 43.5% |
| Non_Tagged_Derived_Type | direct | 3 | 0 | 100.0% |
| Non_Visible_Exception | direct | 0 | 0 | n/a |
| Nonoverlay_Address_Specification | direct | 0 | 0 | n/a |
| Not_Imported_Overlay | direct | 0 | 0 | n/a |
| Null_Case_Alternative | close | 5 | 5 | 0.0% |
| Null_Statement | direct | 4 | 0 | 100.0% |
| Number_Declaration | direct | 11 | 0 | 100.0% |
| Numeric_Format | direct | 53 | 0 | 100.0% |
| Numeric_Indexing | direct | 37 | 0 | 100.0% |
| Object_Declaration_Out_Of_Order | direct | 2 | 0 | 100.0% |
| Object_Of_Anonymous_Type | direct | 0 | 0 | n/a |
| One_Construct_Per_Line | direct | 2 | 0 | 100.0% |
| One_Tagged_Type_Per_Package | direct | 0 | 0 | n/a |
| Operator_Renaming | direct | 0 | 0 | n/a |
| Others_In_Aggregate | direct | 0 | 0 | n/a |
| Others_In_Case_Statement | direct | 8 | 0 | 100.0% |
| Others_In_Exception_Handler | direct | 1 | 0 | 100.0% |
| Out_Parameter_Read_In_Exception_Handler | direct | 0 | 0 | n/a |
| Outbound_Protected_Assignment | direct | 0 | 0 | n/a |
| Outer_Loop_Exit | direct | 0 | 0 | n/a |
| Outside_Reference_From_Subprogram | direct | 109 | 0 | 100.0% |
| Overloaded_Operator | direct | 8 | 0 | 100.0% |
| Overly_Nested_Scope | direct | 0 | 0 | n/a |
| Overwritten_Assignment | close | 0 | 0 | n/a |
| Parameters_Out_Of_Order | direct | 231 | 0 | 100.0% |
| Pos_On_Enumeration_Type | direct | 1 | 0 | 100.0% |
| Positional_Component | direct | 14 | 0 | 100.0% |
| Positional_Defaulted_Generic_Parameter | direct | 4 | 0 | 100.0% |
| Positional_Defaulted_Parameter | direct | 46 | 0 | 100.0% |
| Positional_Generic_Parameter | direct | 19 | 0 | 100.0% |
| Positional_Parameter | direct | 2268 | 0 | 100.0% |
| Predefined_Numeric_Type | direct | 146 | 0 | 100.0% |
| Predicate_Testing | direct | 0 | 0 | n/a |
| Printable_ASCII | direct | 0 | 0 | n/a |
| Profile_Discrepancy | direct | 0 | 0 | n/a |
| Quantified_Expression | direct | 77 | 0 | 100.0% |
| Raising_External_Exception | direct | 0 | 0 | n/a |
| Raising_Predefined_Exception | direct | 0 | 0 | n/a |
| Redundant_Boolean_Comparison | close | 0 | 0 | n/a |
| Redundant_Type_Conversion | close | 9 | 9 | 0.0% |
| Relative_Delay | direct | 0 | 0 | n/a |
| Renaming_Declaration | direct | 13 | 0 | 100.0% |
| Representation_Specification | direct | 30 | 0 | 100.0% |
| Same_Logic | direct | 7 | 0 | 100.0% |
| Same_Operand | direct | 0 | 0 | n/a |
| Self_Assignment | close | 0 | 0 | n/a |
| Separate_Numeric_Error_Handler | direct | 0 | 0 | n/a |
| Separate_Unit | direct | 0 | 0 | n/a |
| Single_Value_Enumeration_Type | direct | 4 | 0 | 100.0% |
| Size_Attribute_For_Type | direct | 168 | 0 | 100.0% |
| Specific_Parent_Type_Invariant | direct | 0 | 0 | n/a |
| Specific_Pre_Post | direct | 0 | 0 | n/a |
| Specific_Type_Invariant | direct | 0 | 0 | n/a |
| Suspicious_Equality | direct | 0 | 0 | n/a |
| Too_Many_Generic_Dependencies | direct | 0 | 0 | n/a |
| Too_Many_Parameters | direct | 12 | 3 | 75.0% |
| Too_Many_Parents | direct | 0 | 0 | n/a |
| Too_Many_Primitives | direct | 0 | 0 | n/a |
| Trailing_Whitespace | direct | 0 | 0 | n/a |
| Unchecked_Address_Conversion | direct | 0 | 0 | n/a |
| Unchecked_Conversion_As_Actual | direct | 0 | 0 | n/a |
| Uncommented_Begin | direct | 176 | 0 | 100.0% |
| Uncommented_Begin_In_Package_Body | direct | 1 | 0 | 100.0% |
| Uncommented_End_Record | direct | 1 | 0 | 100.0% |
| Unconditional_Exit | direct | 6 | 0 | 100.0% |
| Unconstrained_Array_Return | direct | 30 | 0 | 100.0% |
| Unconstrained_Array_Type | direct | 1 | 0 | 100.0% |
| Uninitialized_Global_Variable | direct | 2 | 0 | 100.0% |
| Uninitialized_Output | close | 1 | 1 | 0.0% |
| Universal_Range | direct | 0 | 0 | n/a |
| Unnamed_Block_Or_Loop | direct | 45 | 0 | 100.0% |
| Unnamed_Exit | direct | 0 | 0 | n/a |
| Unused_Parameter | close | 3 | 3 | 0.0% |
| Unused_Variable | close | 0 | 0 | n/a |
| Unused_With_Clause | close | 1 | 1 | 0.0% |
| Use_Array_Slice | direct | 0 | 0 | n/a |
| Use_Case_Statement | direct | 0 | 0 | n/a |
| Use_For_Loop | direct | 0 | 0 | n/a |
| Use_For_Of_Loop | direct | 0 | 0 | n/a |
| Use_If_Expression | direct | 27 | 0 | 100.0% |
| Use_Membership | direct | 0 | 0 | n/a |
| Use_Range | direct | 2 | 0 | 100.0% |
| Use_Record_Aggregate | direct | 9 | 0 | 100.0% |
| Use_Simple_Loop | direct | 0 | 0 | n/a |
| Use_While_Loop | direct | 0 | 0 | n/a |
| Variable_Scoping | direct | 1 | 0 | 100.0% |
| Visible_Component | direct | 17 | 0 | 100.0% |
| Volatile_Object_Without_Address | direct | 0 | 0 | n/a |
| Wrong_Parameter_Mode | close | 4 | 4 | 0.0% |

## Per GNATcheck rule

| GNATcheck rule | Findings | GNATcheck-only | Matched |
| --- | ---: | ---: | ---: |
| `abort_statements` | 0 | 0 | n/a |
| `abstract_type_declarations` | 0 | 0 | n/a |
| `access_to_local_objects` | 14 | 14 | 0.0% |
| `ada05_formal_packages` | 0 | 0 | n/a |
| `ada_2022_in_ghost_code` | 4 | 0 | 100.0% |
| `address_attribute_for_non_volatile_objects` | 0 | 0 | n/a |
| `address_specifications_for_initialized_objects` | 0 | 0 | n/a |
| `address_specifications_for_local_objects` | 0 | 0 | n/a |
| `anonymous_access` | 0 | 0 | n/a |
| `anonymous_arrays` | 0 | 0 | n/a |
| `anonymous_subtypes` | 933 | 641 | 31.3% |
| `at_representation_clauses` | 0 | 0 | n/a |
| `binary_case_statements` | 5 | 0 | 100.0% |
| `bit_records_without_layout_definition` | 0 | 0 | n/a |
| `blocks` | 220 | 177 | 19.5% |
| `boolean_negations` | 11 | 11 | 0.0% |
| `boolean_relational_operators` | 345 | 256 | 25.8% |
| `calls_outside_elaboration` | 0 | 0 | n/a |
| `complex_inlined_subprograms` | 42 | 42 | 0.0% |
| `concurrent_interfaces` | 0 | 0 | n/a |
| `conditional_expressions` | 747 | 348 | 53.4% |
| `constant_overlays` | 0 | 0 | n/a |
| `constructors` | 5 | 5 | 0.0% |
| `controlled_type_declarations` | 19 | 19 | 0.0% |
| `declarations_in_blocks` | 220 | 177 | 19.5% |
| `deep_inheritance_hierarchies` | 0 | 0 | n/a |
| `deep_library_hierarchy` | 7 | 7 | 0.0% |
| `deeply_nested_generics` | 0 | 0 | n/a |
| `deeply_nested_instantiations` | 10 | 10 | 0.0% |
| `default_parameters` | 176 | 92 | 47.7% |
| `default_values_for_record_components` | 143 | 57 | 60.1% |
| `deriving_from_predefined_type` | 12 | 9 | 25.0% |
| `direct_calls_to_primitives` | 272 | 272 | 0.0% |
| `discriminated_records` | 26 | 12 | 53.8% |
| `downward_view_conversions` | 0 | 0 | n/a |
| `duplicate_branches` | 18 | 16 | 11.1% |
| `end_of_line_comments` | 99 | 98 | 1.0% |
| `enumeration_ranges_in_case_statements` | 0 | 0 | n/a |
| `enumeration_representation_clauses` | 9 | 0 | 100.0% |
| `exception_propagation_from_callbacks` | 0 | 0 | n/a |
| `exception_propagation_from_export` | 0 | 0 | n/a |
| `exception_propagation_from_tasks` | 0 | 0 | n/a |
| `exceptions_as_control_flow` | 0 | 0 | n/a |
| `exit_statements_with_no_loop_name` | 38 | 26 | 31.6% |
| `exits_from_conditional_loops` | 27 | 11 | 59.3% |
| `expanded_loop_exit_names` | 0 | 0 | n/a |
| `explicit_full_discrete_ranges` | 5 | 5 | 0.0% |
| `explicit_inlining` | 170 | 170 | 0.0% |
| `expression_functions` | 690 | 175 | 74.6% |
| `final_package` | 0 | 0 | n/a |
| `fixed_equality_checks` | 1 | 1 | 0.0% |
| `float_equality_checks` | 14 | 14 | 0.0% |
| `forbidden_pragmas` | 2439 | 990 | 59.4% |
| `function_out_parameters` | 7 | 7 | 0.0% |
| `function_style_procedures` | 63 | 1 | 98.4% |
| `generic_in_out_objects` | 0 | 0 | n/a |
| `generics_in_subprograms` | 0 | 0 | n/a |
| `global_variables` | 5 | 5 | 0.0% |
| `goto_statements` | 136 | 0 | 100.0% |
| `implicit_in_mode_parameters` | 5403 | 3855 | 28.7% |
| `implicit_small_for_fixed_point_types` | 0 | 0 | n/a |
| `improper_returns` | 664 | 664 | 0.0% |
| `improperly_located_instantiations` | 249 | 227 | 8.8% |
| `incomplete_representation_specifications` | 0 | 0 | n/a |
| `library_level_subprograms` | 0 | 0 | n/a |
| `local_instantiations` | 111 | 95 | 14.4% |
| `local_packages` | 30 | 27 | 10.0% |
| `local_use_clauses` | 197 | 65 | 67.0% |
| `lowercase_keywords` | 0 | 0 | n/a |
| `max_identifier_length` | 733 | 351 | 52.1% |
| `maximum_expression_complexity` | 2919 | 1857 | 36.4% |
| `maximum_lines` | 0 | 0 | n/a |
| `maximum_out_parameters` | 9 | 0 | 100.0% |
| `maximum_parameters` | 282 | 273 | 3.2% |
| `maximum_subprogram_lines` | 0 | 0 | n/a |
| `membership_for_validity` | 0 | 0 | n/a |
| `membership_tests` | 227 | 134 | 41.0% |
| `metrics_cyclomatic_complexity` | 248 | 237 | 4.4% |
| `metrics_essential_complexity` | 150 | 133 | 11.3% |
| `metrics_lsloc` | 45 | 30 | 33.3% |
| `min_identifier_length` | 1870 | 1852 | 1.0% |
| `misnamed_controlling_parameters` | 281 | 280 | 0.4% |
| `misplaced_representation_items` | 0 | 0 | n/a |
| `multiple_entries_in_protected_definitions` | 0 | 0 | n/a |
| `nested_paths` | 23 | 20 | 13.0% |
| `nested_subprograms` | 242 | 180 | 25.6% |
| `no_closing_names` | 0 | 0 | n/a |
| `no_explicit_real_range` | 2 | 2 | 0.0% |
| `no_inherited_classwide_pre` | 0 | 0 | n/a |
| `no_scalar_storage_order_specified` | 0 | 0 | n/a |
| `non_component_in_barriers` | 0 | 0 | n/a |
| `non_constant_overlays` | 0 | 0 | n/a |
| `non_qualified_aggregates` | 1964 | 1728 | 12.0% |
| `non_short_circuit_operators` | 3231 | 3221 | 0.3% |
| `non_spark_attributes` | 4082 | 2824 | 30.8% |
| `non_tagged_derived_types` | 23 | 20 | 13.0% |
| `non_visible_exceptions` | 0 | 0 | n/a |
| `nonoverlay_address_specifications` | 0 | 0 | n/a |
| `not_imported_overlays` | 0 | 0 | n/a |
| `null_paths` | 14 | 14 | 0.0% |
| `number_declarations` | 25 | 14 | 44.0% |
| `numeric_format` | 78 | 25 | 67.9% |
| `numeric_indexing` | 77 | 40 | 48.1% |
| `numeric_literals` | 509 | 56 | 89.0% |
| `object_declarations_out_of_order` | 3 | 1 | 66.7% |
| `objects_of_anonymous_types` | 0 | 0 | n/a |
| `one_construct_per_line` | 14 | 12 | 14.3% |
| `one_tagged_type_per_package` | 0 | 0 | n/a |
| `operator_renamings` | 74 | 74 | 0.0% |
| `others_in_aggregates` | 8 | 8 | 0.0% |
| `others_in_case_statements` | 8 | 0 | 100.0% |
| `others_in_exception_handlers` | 9 | 8 | 11.1% |
| `out_parameter_read_in_exception_handler` | 0 | 0 | n/a |
| `outbound_protected_assignments` | 0 | 0 | n/a |
| `outer_loop_exits` | 0 | 0 | n/a |
| `outside_references_from_subprograms` | 115 | 6 | 94.8% |
| `overloaded_operators` | 179 | 171 | 4.5% |
| `overly_nested_control_structures` | 0 | 0 | n/a |
| `overly_nested_scopes` | 0 | 0 | n/a |
| `overriding_indicators` | 0 | 0 | n/a |
| `parameters_aliasing` | 0 | 0 | n/a |
| `parameters_out_of_order` | 729 | 498 | 31.7% |
| `pos_on_enumeration_types` | 1 | 0 | 100.0% |
| `positional_actuals_for_defaulted_generic_parameters` | 10 | 6 | 40.0% |
| `positional_actuals_for_defaulted_parameters` | 68 | 22 | 67.6% |
| `positional_components` | 61 | 47 | 23.0% |
| `positional_generic_parameters` | 52 | 33 | 36.5% |
| `positional_parameters` | 7279 | 5011 | 31.2% |
| `potential_parameters_aliasing` | 0 | 0 | n/a |
| `predefined_numeric_types` | 241 | 95 | 60.6% |
| `predicate_testing` | 0 | 0 | n/a |
| `printable_ascii` | 0 | 0 | n/a |
| `profile_discrepancies` | 25 | 25 | 0.0% |
| `quantified_expressions` | 615 | 538 | 12.5% |
| `raising_external_exceptions` | 12 | 12 | 0.0% |
| `raising_predefined_exceptions` | 230 | 230 | 0.0% |
| `recursive_subprograms` | 0 | 0 | n/a |
| `redundant_boolean_expressions` | 19 | 19 | 0.0% |
| `redundant_null_statements` | 4 | 0 | 100.0% |
| `relative_delay_statements` | 0 | 0 | n/a |
| `renamings` | 327 | 314 | 4.0% |
| `representation_specifications` | 110 | 80 | 27.3% |
| `same_logic` | 7 | 0 | 100.0% |
| `same_operands` | 2 | 2 | 0.0% |
| `same_tests` | 0 | 0 | n/a |
| `separate_numeric_error_handlers` | 0 | 0 | n/a |
| `separates` | 0 | 0 | n/a |
| `silent_exception_handlers` | 9 | 9 | 0.0% |
| `simple_loop_statements` | 15 | 15 | 0.0% |
| `single_value_enumeration_types` | 4 | 0 | 100.0% |
| `size_attribute_for_types` | 170 | 2 | 98.8% |
| `slices` | 196 | 36 | 81.6% |
| `spark_procedures_without_globals` | 371 | 371 | 0.0% |
| `specific_parent_type_invariant` | 0 | 0 | n/a |
| `specific_pre_post` | 202 | 202 | 0.0% |
| `specific_type_invariants` | 0 | 0 | n/a |
| `style_checks:M` | 0 | 0 | n/a |
| `style_checks:b` | 5 | 5 | 0.0% |
| `subprogram_access` | 179 | 179 | 0.0% |
| `suspicious_equalities` | 0 | 0 | n/a |
| `too_many_dependencies` | 32 | 32 | 0.0% |
| `too_many_generic_dependencies` | 2 | 2 | 0.0% |
| `too_many_parents` | 0 | 0 | n/a |
| `too_many_primitives` | 0 | 0 | n/a |
| `trivial_exception_handlers` | 0 | 0 | n/a |
| `unassigned_out_parameters` | 0 | 0 | n/a |
| `unchecked_address_conversions` | 0 | 0 | n/a |
| `unchecked_conversions_as_actuals` | 2 | 2 | 0.0% |
| `uncommented_begin` | 645 | 469 | 27.3% |
| `uncommented_begin_in_package_bodies` | 1 | 0 | 100.0% |
| `uncommented_end_record` | 1 | 0 | 100.0% |
| `unconditional_exits` | 18 | 12 | 33.3% |
| `unconstrained_array_returns` | 47 | 17 | 63.8% |
| `unconstrained_arrays` | 17 | 16 | 5.9% |
| `uninitialized_global_variables` | 15 | 13 | 13.3% |
| `universal_ranges` | 1 | 1 | 0.0% |
| `unnamed_blocks_and_loops` | 260 | 215 | 17.3% |
| `unnamed_exits` | 0 | 0 | n/a |
| `use_array_slices` | 0 | 0 | n/a |
| `use_case_statements` | 0 | 0 | n/a |
| `use_for_loops` | 7 | 7 | 0.0% |
| `use_for_of_loops` | 2 | 2 | 0.0% |
| `use_if_expressions` | 61 | 34 | 44.3% |
| `use_memberships` | 0 | 0 | n/a |
| `use_package_clauses` | 128 | 117 | 8.6% |
| `use_ranges` | 7 | 5 | 28.6% |
| `use_record_aggregates` | 10 | 1 | 90.0% |
| `use_simple_loops` | 0 | 0 | n/a |
| `use_while_loops` | 0 | 0 | n/a |
| `variable_scoping` | 3 | 2 | 33.3% |
| `visible_components` | 33 | 16 | 51.5% |
| `volatile_objects_without_address_clauses` | 0 | 0 | n/a |
| `warnings:c.always` | 0 | 0 | n/a |
| `warnings:f` | 0 | 0 | n/a |
| `warnings:k.mode` | 0 | 0 | n/a |
| `warnings:m.never` | 0 | 0 | n/a |
| `warnings:m.overwritten` | 0 | 0 | n/a |
| `warnings:r.conversion` | 0 | 0 | n/a |
| `warnings:r.self` | 0 | 0 | n/a |
| `warnings:r.with` | 0 | 0 | n/a |
| `warnings:u.object` | 1 | 1 | 0.0% |
| `warnings:u.unit` | 2 | 2 | 0.0% |

## Known, explained differences

- `Null_Case_Alternative`'s unmatched findings are in RecordFlux-generated state-dispatch code: GNATcheck's `null_paths` reports at the `null;` statement, AdaLang at the alternative (reporting-location convention).
- `min_identifier_length`/`non_short_circuit_operators` mismatch almost entirely on RecordFlux-generated code; GNATcheck also reports inside the SPARKlib sources in the project closure.
- Matching is on `(file basename, line, rule pair)`; rule pairs are name-level matches, not proven semantic equivalence (`docs/src/gnatcheck-rule-comparison.md`).
- `null_paths` family (`Empty_*_Body`, `Null_Case_Alternative`): GNATcheck reports at the empty statement, AdaLang at the branch or alternative.
- `No_Multiple_Return`/`improper_returns` differ in granularity (per subprogram vs. per return); `Too_Many_Parameters`/`maximum_parameters` report spec vs. body and use different default thresholds; `Missing_Global_Contract` deliberately also fires outside `SPARK_Mode`.
- `Identical_Branches`/`Identical_Case_Alternative` vs. `duplicate_branches` (run with `min_stmt=1,min_size=1`, matched on the line GNATcheck names as the duplicate): AdaLang compares adjacent branches only, so GNATcheck's non-adjacent pairs stay GNATcheck-only; GNATcheck reports one pair per `if`/`case`, so the later members of a run of identical adjacent branches stay AdaLang-only.
- The two tools analyse different file sets: AdaLang takes the sources of the root project, GNATcheck the closure it loads. The shared-file figures above leave out findings in files only one tool analysed.
- AdaLang resolves names only among the sources of the root project. Units of an imported project stay unresolved here, so checks that need a type or a declaration (positional associations, predefined numeric types, slices, array returns, object-oriented checks) report less than GNATcheck, and checks that ask whether a body has a separate declaration can report a body GNATcheck attributes to its specification. This is a limitation of the analyzer's project support, not of the individual checks; `skippedChecks` in the AdaLang JSON report counts the affected queries.
