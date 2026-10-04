# AWS: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Current results, refreshed 2026-10-04. This file replaces the earlier dated runs, which remain in the Git history. The refresh adds the rule pairs of the 167 opt-in coding-standard checks (153 of them run here; the other 14 report nothing until configured and are not in the rule map). The pairs that were already compared on 2026-09-24 are run again unchanged.

## Environment

- Corpus: pinned at `02cbd01c2f96c288440415a46bf865616c0ee0f8` (`AWS_REVISION`), unchanged.
- AdaLang Analyzer: 1.7.0 plus the unreleased coding-standard checks (branch `gnatcheck-rule-parity`).
- GNATcheck: the same from-source build as prior runs; one pass with the plain `-r` rules, then one pass per column-4 option line of `benchmarks/gnatcheck_rule_map.tsv` (`benchmarks/gnatcheck_rule_args.awk`).
- Reproduce: `AWS_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/aws/run_gnatcheck.sh` (see this directory's README for
  any setup step).
- GNATcheck worker crashes ("unparsable worker output"): each GNATcheck invocation was repeated until it finished without a crash; the plain rules were run in batches of at most 25 where one pass over all of them kept crashing. Across the attempts logged for this corpus, 16 invocations were repeated. The accepted log has no crash and no GNATcheck error line.

## Totals

| | 2026-10-04, all pairs | 2026-10-04, pairs of 2026-09-24 | 2026-09-24 |
| --- | ---: | ---: | ---: |
| AdaLang findings | 44655 | 6701 | 6701 |
| &nbsp;&nbsp;matched by GNATcheck | 41378 (92.7%) | 3635 (54.2%) | 3635 (54.2%) |
| GNATcheck findings | 124245 | 12991 | 12991 |
| &nbsp;&nbsp;matched by AdaLang | 41368 (33.3%) | 3625 (27.9%) | 3625 (27.9%) |

Every pair of 2026-09-24 has the same numbers as then.

## Coding-standard checks

The 153 new pairs, counted over all files: 37954 AdaLang findings, 37743 matched by GNATcheck (99.4%); 111254 GNATcheck findings, 37743 matched by AdaLang (33.9%). 124 of the 153 checks have a finding from one tool or the other on this corpus.

The two tools do not analyse the same set of files (see the notes below), so the same pairs are also counted over the files both analysed: 37954 AdaLang findings and 39094 GNATcheck findings, 37772 at the same file and line; 182 AdaLang-only, 1322 GNATcheck-only.

- The largest corpus: 348 files analysed by AdaLang, 888 by GNATcheck (which follows the imported `templates_parser`, XML/Ada and runtime-adjacent projects).
- In the shared files 37,772 findings match. The 1,322 GNATcheck-only findings are led by `Predefined_Numeric_Type` (188), `Outside_Reference_From_Subprogram` (171) and `Raising_Predefined_Exception` (34), in units that depend on unresolved imported units.
- The 182 AdaLang-only findings are led by `Outside_Reference_From_Subprogram` (87), `Outbound_Protected_Assignment` (33) and `Out_Parameter_Read_In_Exception_Handler` (14). For the last one the two tools also differ in which handlers they consider, which is a difference in the check and not only in resolution; it has not been run down further.
- This run found and fixed a defect: `Deriving_From_Predefined_Type` reported types derived from any unit under `Ada`, `System` or `Interfaces`; GNATcheck's rule covers only types declared directly in those four packages.

## Duplicate branches

`Identical_Branches` + `Identical_Case_Alternative`: 14 findings, 10 matched by GNATcheck's `duplicate_branches` (71.4%); `duplicate_branches`: 45 findings, 10 matched (22.2%). With GNATcheck's default thresholds (4 statements / 14 tokens) this pair had 0 GNATcheck findings on every corpus.

## Per AdaLang rule

| AdaLang rule | Match | Findings | AdaLang-only | Matched |
| --- | --- | ---: | ---: | ---: |
| Abstract_Type_Declaration | direct | 28 | 0 | 100.0% |
| Access_To_Local_Object | direct | 67 | 0 | 100.0% |
| Ada05_Formal_Package | direct | 2 | 0 | 100.0% |
| Ada_2022_In_Ghost_Code | direct | 440 | 0 | 100.0% |
| Address_Clause | close | 21 | 6 | 71.4% |
| Address_Of_Non_Volatile_Object | direct | 24 | 0 | 100.0% |
| Aliasing_Between_Parameters | direct | 0 | 0 | n/a |
| Anonymous_Access_Type | direct | 29 | 0 | 100.0% |
| Anonymous_Array_Type | direct | 34 | 0 | 100.0% |
| Anonymous_Subtype | direct | 1104 | 0 | 100.0% |
| Array_Slice | direct | 496 | 0 | 100.0% |
| Binary_Case_Statement | direct | 34 | 0 | 100.0% |
| Bit_Record_Without_Layout | direct | 0 | 0 | n/a |
| Boolean_Relational_Operator | direct | 13 | 0 | 100.0% |
| Complex_Inlined_Subprogram | direct | 79 | 4 | 94.9% |
| Concurrent_Interface | direct | 0 | 0 | n/a |
| Conditional_Expression | direct | 125 | 0 | 100.0% |
| Constant_Condition | close | 3 | 3 | 0.0% |
| Constant_Overlay | direct | 5 | 0 | 100.0% |
| Constructor | direct | 70 | 0 | 100.0% |
| Cyclomatic_Complexity | direct | 88 | 0 | 100.0% |
| Dead_Store | close | 42 | 42 | 0.0% |
| Declaration_In_Block | close | 425 | 0 | 100.0% |
| Deep_Inheritance_Hierarchy | direct | 34 | 0 | 100.0% |
| Deep_Library_Hierarchy | direct | 10 | 0 | 100.0% |
| Deep_Nesting | direct | 49 | 49 | 0.0% |
| Deeply_Nested_Generic | direct | 0 | 0 | n/a |
| Deeply_Nested_Instantiation | direct | 0 | 0 | n/a |
| Default_Parameter | direct | 899 | 0 | 100.0% |
| Default_Value_For_Record_Component | direct | 175 | 0 | 100.0% |
| Dependency_Limit | direct | 4 | 4 | 0.0% |
| Deriving_From_Predefined_Type | direct | 17 | 0 | 100.0% |
| Direct_Call_To_Primitive | direct | 1673 | 0 | 100.0% |
| Discriminated_Record | direct | 51 | 0 | 100.0% |
| Downward_View_Conversion | direct | 153 | 0 | 100.0% |
| Duplicate_Boolean_Operand | close | 0 | 0 | n/a |
| Duplicate_Condition | direct | 0 | 0 | n/a |
| Duplicate_With_Clause | direct | 0 | 0 | n/a |
| Empty_Else_Body | close | 2 | 2 | 0.0% |
| Empty_Elsif_Body | close | 2 | 2 | 0.0% |
| Empty_Exception_Handler | direct | 21 | 0 | 100.0% |
| Empty_If_Body | close | 0 | 0 | n/a |
| Empty_Then_Body | close | 7 | 7 | 0.0% |
| End_Of_Line_Comment | direct | 228 | 0 | 100.0% |
| Enumeration_Range_In_Case_Statement | direct | 14 | 0 | 100.0% |
| Enumeration_Representation_Clause | direct | 3 | 0 | 100.0% |
| Essential_Complexity | direct | 115 | 0 | 100.0% |
| Exception_As_Control_Flow | direct | 4 | 0 | 100.0% |
| Exception_Propagation | close | 948 | 948 | 0.0% |
| Exception_Swallowed | close | 11 | 0 | 100.0% |
| Exit_From_Conditional_Loop | direct | 48 | 0 | 100.0% |
| Exit_Without_Loop_Name | direct | 132 | 0 | 100.0% |
| Expanded_Loop_Exit_Name | direct | 0 | 0 | n/a |
| Explicit_Full_Discrete_Range | direct | 2 | 0 | 100.0% |
| Explicit_Inlining | direct | 459 | 0 | 100.0% |
| Expression_Function | direct | 83 | 0 | 100.0% |
| Final_Package | direct | 0 | 0 | n/a |
| Fixed_Equality | direct | 6 | 0 | 100.0% |
| Floating_Equality | direct | 10 | 5 | 50.0% |
| Function_Out_Parameter | direct | 31 | 7 | 77.4% |
| Function_Style_Procedure | direct | 81 | 7 | 91.4% |
| Generic_In_Out_Object | direct | 0 | 0 | n/a |
| Generic_In_Subprogram | direct | 0 | 0 | n/a |
| Global_Variable | direct | 23 | 2 | 91.3% |
| Identical_Branches | direct | 6 | 1 | 83.3% |
| Identical_Case_Alternative | close | 8 | 3 | 62.5% |
| Implicit_In_Mode | direct | 8344 | 0 | 100.0% |
| Implicit_Small | direct | 0 | 0 | n/a |
| Improperly_Located_Instantiation | direct | 135 | 0 | 100.0% |
| Incomplete_Representation_Specification | direct | 5 | 0 | 100.0% |
| Infinite_Loop | close | 5 | 0 | 100.0% |
| Library_Level_Initialization | close | 33 | 33 | 0.0% |
| Library_Level_Subprogram | direct | 6 | 0 | 100.0% |
| Local_Instantiation | direct | 89 | 0 | 100.0% |
| Local_Package | direct | 1 | 0 | 100.0% |
| Local_Use_Clause | direct | 655 | 0 | 100.0% |
| Logical_SLOC | direct | 73 | 0 | 100.0% |
| Long_Line | direct | 0 | 0 | n/a |
| Lowercase_Keyword | direct | 0 | 0 | n/a |
| Magic_Number | close | 680 | 75 | 89.0% |
| Maximum_Expression_Complexity | direct | 845 | 0 | 100.0% |
| Maximum_Identifier_Length | direct | 492 | 0 | 100.0% |
| Maximum_Lines | direct | 0 | 0 | n/a |
| Maximum_Out_Parameters | direct | 11 | 0 | 100.0% |
| Maximum_Subprogram_Lines | direct | 0 | 0 | n/a |
| Membership_For_Validity | direct | 0 | 0 | n/a |
| Membership_Test | direct | 114 | 0 | 100.0% |
| Misnamed_Controlling_Parameter | direct | 919 | 0 | 100.0% |
| Misplaced_Representation_Item | direct | 13 | 1 | 92.3% |
| Missing_Global_Contract | close | 827 | 827 | 0.0% |
| Missing_Overriding_Indicator | direct | 0 | 0 | n/a |
| Multiple_Protected_Entries | direct | 9 | 0 | 100.0% |
| Naming_Convention | close | 2809 | 370 | 86.8% |
| Nested_Path | direct | 127 | 0 | 100.0% |
| Nested_Subprogram | direct | 616 | 18 | 97.1% |
| No_Abort | direct | 1 | 0 | 100.0% |
| No_Access_To_Subp_Def | direct | 112 | 0 | 100.0% |
| No_Block_Statement | direct | 492 | 0 | 100.0% |
| No_Closing_Name | direct | 0 | 0 | n/a |
| No_Controlled_Type | direct | 20 | 5 | 75.0% |
| No_Explicit_Real_Range | direct | 3 | 0 | 100.0% |
| No_Goto | direct | 0 | 0 | n/a |
| No_Inherited_Classwide_Pre | direct | 221 | 0 | 100.0% |
| No_Multiple_Return | direct | 423 | 423 | 0.0% |
| No_Pragma | close | 290 | 0 | 100.0% |
| No_Recursion | direct | 0 | 0 | n/a |
| No_Scalar_Storage_Order | direct | 2 | 0 | 100.0% |
| No_Use_Package_Clause | direct | 383 | 0 | 100.0% |
| Non_Component_In_Barrier | direct | 0 | 0 | n/a |
| Non_Constant_Overlay | direct | 15 | 0 | 100.0% |
| Non_Qualified_Aggregate | direct | 623 | 4 | 99.4% |
| Non_SPARK_Attribute | direct | 1773 | 0 | 100.0% |
| Non_Short_Circuit_Condition | direct | 6 | 0 | 100.0% |
| Non_Tagged_Derived_Type | direct | 30 | 0 | 100.0% |
| Non_Visible_Exception | direct | 0 | 0 | n/a |
| Nonoverlay_Address_Specification | direct | 0 | 0 | n/a |
| Not_Imported_Overlay | direct | 11 | 0 | 100.0% |
| Null_Case_Alternative | close | 31 | 26 | 16.1% |
| Null_Statement | direct | 0 | 0 | n/a |
| Number_Declaration | direct | 74 | 0 | 100.0% |
| Numeric_Format | direct | 286 | 0 | 100.0% |
| Numeric_Indexing | direct | 303 | 0 | 100.0% |
| Object_Declaration_Out_Of_Order | direct | 24 | 0 | 100.0% |
| Object_Of_Anonymous_Type | direct | 18 | 0 | 100.0% |
| One_Construct_Per_Line | direct | 317 | 0 | 100.0% |
| One_Tagged_Type_Per_Package | direct | 7 | 0 | 100.0% |
| Operator_Renaming | direct | 1 | 0 | 100.0% |
| Others_In_Aggregate | direct | 15 | 0 | 100.0% |
| Others_In_Case_Statement | direct | 52 | 0 | 100.0% |
| Others_In_Exception_Handler | direct | 104 | 0 | 100.0% |
| Out_Parameter_Read_In_Exception_Handler | direct | 43 | 43 | 0.0% |
| Outbound_Protected_Assignment | direct | 81 | 33 | 59.3% |
| Outer_Loop_Exit | direct | 2 | 0 | 100.0% |
| Outside_Reference_From_Subprogram | direct | 1242 | 87 | 93.0% |
| Overloaded_Operator | direct | 30 | 0 | 100.0% |
| Overly_Nested_Scope | direct | 0 | 0 | n/a |
| Overwritten_Assignment | close | 6 | 6 | 0.0% |
| Parameters_Out_Of_Order | direct | 1104 | 0 | 100.0% |
| Pos_On_Enumeration_Type | direct | 35 | 0 | 100.0% |
| Positional_Component | direct | 672 | 0 | 100.0% |
| Positional_Defaulted_Generic_Parameter | direct | 15 | 0 | 100.0% |
| Positional_Defaulted_Parameter | direct | 352 | 0 | 100.0% |
| Positional_Generic_Parameter | direct | 156 | 0 | 100.0% |
| Positional_Parameter | direct | 3875 | 0 | 100.0% |
| Predefined_Numeric_Type | direct | 2007 | 0 | 100.0% |
| Predicate_Testing | direct | 2 | 0 | 100.0% |
| Printable_ASCII | direct | 0 | 0 | n/a |
| Profile_Discrepancy | direct | 47 | 0 | 100.0% |
| Quantified_Expression | direct | 16 | 0 | 100.0% |
| Raising_External_Exception | direct | 34 | 0 | 100.0% |
| Raising_Predefined_Exception | direct | 77 | 0 | 100.0% |
| Redundant_Boolean_Comparison | close | 3 | 0 | 100.0% |
| Redundant_Type_Conversion | close | 2 | 2 | 0.0% |
| Relative_Delay | direct | 16 | 0 | 100.0% |
| Renaming_Declaration | direct | 186 | 0 | 100.0% |
| Representation_Specification | direct | 85 | 0 | 100.0% |
| Same_Logic | direct | 1 | 0 | 100.0% |
| Same_Operand | direct | 0 | 0 | n/a |
| Self_Assignment | close | 0 | 0 | n/a |
| Separate_Numeric_Error_Handler | direct | 17 | 0 | 100.0% |
| Separate_Unit | direct | 13 | 0 | 100.0% |
| Single_Value_Enumeration_Type | direct | 1 | 0 | 100.0% |
| Size_Attribute_For_Type | direct | 16 | 0 | 100.0% |
| Specific_Parent_Type_Invariant | direct | 0 | 0 | n/a |
| Specific_Pre_Post | direct | 173 | 0 | 100.0% |
| Specific_Type_Invariant | direct | 0 | 0 | n/a |
| Suspicious_Equality | direct | 0 | 0 | n/a |
| Too_Many_Generic_Dependencies | direct | 0 | 0 | n/a |
| Too_Many_Parameters | direct | 62 | 62 | 0.0% |
| Too_Many_Parents | direct | 0 | 0 | n/a |
| Too_Many_Primitives | direct | 79 | 0 | 100.0% |
| Trailing_Whitespace | direct | 0 | 0 | n/a |
| Unchecked_Address_Conversion | direct | 0 | 0 | n/a |
| Unchecked_Conversion_As_Actual | direct | 3 | 0 | 100.0% |
| Uncommented_Begin | direct | 1320 | 0 | 100.0% |
| Uncommented_Begin_In_Package_Body | direct | 8 | 0 | 100.0% |
| Uncommented_End_Record | direct | 35 | 0 | 100.0% |
| Unconditional_Exit | direct | 61 | 0 | 100.0% |
| Unconstrained_Array_Return | direct | 576 | 3 | 99.5% |
| Unconstrained_Array_Type | direct | 29 | 0 | 100.0% |
| Uninitialized_Global_Variable | direct | 46 | 0 | 100.0% |
| Uninitialized_Output | close | 70 | 66 | 5.7% |
| Universal_Range | direct | 89 | 0 | 100.0% |
| Unnamed_Block_Or_Loop | direct | 559 | 0 | 100.0% |
| Unnamed_Exit | direct | 0 | 0 | n/a |
| Unused_Parameter | close | 61 | 61 | 0.0% |
| Unused_Variable | close | 9 | 9 | 0.0% |
| Unused_With_Clause | close | 5 | 5 | 0.0% |
| Use_Array_Slice | direct | 1 | 0 | 100.0% |
| Use_Case_Statement | direct | 13 | 1 | 92.3% |
| Use_For_Loop | direct | 0 | 0 | n/a |
| Use_For_Of_Loop | direct | 27 | 0 | 100.0% |
| Use_If_Expression | direct | 336 | 0 | 100.0% |
| Use_Membership | direct | 0 | 0 | n/a |
| Use_Range | direct | 5 | 0 | 100.0% |
| Use_Record_Aggregate | direct | 9 | 0 | 100.0% |
| Use_Simple_Loop | direct | 0 | 0 | n/a |
| Use_While_Loop | direct | 7 | 0 | 100.0% |
| Variable_Scoping | direct | 8 | 1 | 87.5% |
| Visible_Component | direct | 21 | 0 | 100.0% |
| Volatile_Object_Without_Address | direct | 0 | 0 | n/a |
| Wrong_Parameter_Mode | close | 24 | 24 | 0.0% |

## Per GNATcheck rule

| GNATcheck rule | Findings | GNATcheck-only | Matched |
| --- | ---: | ---: | ---: |
| `abort_statements` | 1 | 0 | 100.0% |
| `abstract_type_declarations` | 75 | 47 | 37.3% |
| `access_to_local_objects` | 92 | 25 | 72.8% |
| `ada05_formal_packages` | 2 | 0 | 100.0% |
| `ada_2022_in_ghost_code` | 471 | 31 | 93.4% |
| `address_attribute_for_non_volatile_objects` | 31 | 7 | 77.4% |
| `address_specifications_for_initialized_objects` | 1 | 0 | 100.0% |
| `address_specifications_for_local_objects` | 27 | 12 | 55.6% |
| `anonymous_access` | 59 | 30 | 49.2% |
| `anonymous_arrays` | 82 | 48 | 41.5% |
| `anonymous_subtypes` | 2760 | 1656 | 40.0% |
| `at_representation_clauses` | 0 | 0 | n/a |
| `binary_case_statements` | 48 | 14 | 70.8% |
| `bit_records_without_layout_definition` | 3 | 3 | 0.0% |
| `blocks` | 787 | 295 | 62.5% |
| `boolean_negations` | 1 | 1 | 0.0% |
| `boolean_relational_operators` | 21 | 8 | 61.9% |
| `calls_outside_elaboration` | 0 | 0 | n/a |
| `complex_inlined_subprograms` | 172 | 97 | 43.6% |
| `concurrent_interfaces` | 0 | 0 | n/a |
| `conditional_expressions` | 193 | 68 | 64.8% |
| `constant_overlays` | 8 | 3 | 62.5% |
| `constructors` | 110 | 40 | 63.6% |
| `controlled_type_declarations` | 170 | 155 | 8.8% |
| `declarations_in_blocks` | 687 | 262 | 61.9% |
| `deep_inheritance_hierarchies` | 37 | 3 | 91.9% |
| `deep_library_hierarchy` | 10 | 0 | 100.0% |
| `deeply_nested_generics` | 0 | 0 | n/a |
| `deeply_nested_instantiations` | 0 | 0 | n/a |
| `default_parameters` | 1694 | 795 | 53.1% |
| `default_values_for_record_components` | 543 | 368 | 32.2% |
| `deriving_from_predefined_type` | 54 | 37 | 31.5% |
| `direct_calls_to_primitives` | 3162 | 1489 | 52.9% |
| `discriminated_records` | 88 | 37 | 58.0% |
| `downward_view_conversions` | 230 | 77 | 66.5% |
| `duplicate_branches` | 45 | 35 | 22.2% |
| `end_of_line_comments` | 882 | 654 | 25.9% |
| `enumeration_ranges_in_case_statements` | 25 | 11 | 56.0% |
| `enumeration_representation_clauses` | 5 | 2 | 60.0% |
| `exception_propagation_from_callbacks` | 0 | 0 | n/a |
| `exception_propagation_from_export` | 4 | 4 | 0.0% |
| `exception_propagation_from_tasks` | 5 | 5 | 0.0% |
| `exceptions_as_control_flow` | 8 | 4 | 50.0% |
| `exit_statements_with_no_loop_name` | 309 | 177 | 42.7% |
| `exits_from_conditional_loops` | 141 | 93 | 34.0% |
| `expanded_loop_exit_names` | 0 | 0 | n/a |
| `explicit_full_discrete_ranges` | 4 | 2 | 50.0% |
| `explicit_inlining` | 724 | 265 | 63.4% |
| `expression_functions` | 130 | 47 | 63.8% |
| `final_package` | 0 | 0 | n/a |
| `fixed_equality_checks` | 12 | 6 | 50.0% |
| `float_equality_checks` | 17 | 12 | 29.4% |
| `forbidden_pragmas` | 1328 | 1038 | 21.8% |
| `function_out_parameters` | 80 | 56 | 30.0% |
| `function_style_procedures` | 151 | 77 | 49.0% |
| `generic_in_out_objects` | 11 | 11 | 0.0% |
| `generics_in_subprograms` | 0 | 0 | n/a |
| `global_variables` | 24 | 3 | 87.5% |
| `goto_statements` | 2 | 2 | 0.0% |
| `implicit_in_mode_parameters` | 15618 | 7274 | 53.4% |
| `implicit_small_for_fixed_point_types` | 0 | 0 | n/a |
| `improper_returns` | 2840 | 2840 | 0.0% |
| `improperly_located_instantiations` | 312 | 177 | 43.3% |
| `incomplete_representation_specifications` | 7 | 2 | 71.4% |
| `library_level_subprograms` | 9 | 3 | 66.7% |
| `local_instantiations` | 191 | 102 | 46.6% |
| `local_packages` | 4 | 3 | 25.0% |
| `local_use_clauses` | 809 | 154 | 81.0% |
| `lowercase_keywords` | 0 | 0 | n/a |
| `max_identifier_length` | 21311 | 20819 | 2.3% |
| `maximum_expression_complexity` | 1808 | 963 | 46.7% |
| `maximum_lines` | 0 | 0 | n/a |
| `maximum_out_parameters` | 23 | 12 | 47.8% |
| `maximum_parameters` | 689 | 689 | 0.0% |
| `maximum_subprogram_lines` | 0 | 0 | n/a |
| `membership_for_validity` | 0 | 0 | n/a |
| `membership_tests` | 203 | 89 | 56.2% |
| `metrics_cyclomatic_complexity` | 687 | 599 | 12.8% |
| `metrics_essential_complexity` | 306 | 191 | 37.6% |
| `metrics_lsloc` | 166 | 93 | 44.0% |
| `min_identifier_length` | 3722 | 1283 | 65.5% |
| `misnamed_controlling_parameters` | 1872 | 953 | 49.1% |
| `misplaced_representation_items` | 14 | 2 | 85.7% |
| `multiple_entries_in_protected_definitions` | 9 | 0 | 100.0% |
| `nested_paths` | 223 | 96 | 57.0% |
| `nested_subprograms` | 972 | 374 | 61.5% |
| `no_closing_names` | 0 | 0 | n/a |
| `no_explicit_real_range` | 4 | 1 | 75.0% |
| `no_inherited_classwide_pre` | 464 | 243 | 47.6% |
| `no_scalar_storage_order_specified` | 4 | 2 | 50.0% |
| `non_component_in_barriers` | 0 | 0 | n/a |
| `non_constant_overlays` | 19 | 4 | 78.9% |
| `non_qualified_aggregates` | 1202 | 583 | 51.5% |
| `non_short_circuit_operators` | 79 | 73 | 7.6% |
| `non_spark_attributes` | 3602 | 1829 | 49.2% |
| `non_tagged_derived_types` | 84 | 54 | 35.7% |
| `non_visible_exceptions` | 1 | 1 | 0.0% |
| `nonoverlay_address_specifications` | 0 | 0 | n/a |
| `not_imported_overlays` | 13 | 2 | 84.6% |
| `null_paths` | 163 | 158 | 3.1% |
| `number_declarations` | 267 | 193 | 27.7% |
| `numeric_format` | 13146 | 12860 | 2.2% |
| `numeric_indexing` | 746 | 443 | 40.6% |
| `numeric_literals` | 2243 | 1638 | 27.0% |
| `object_declarations_out_of_order` | 30 | 6 | 80.0% |
| `objects_of_anonymous_types` | 54 | 36 | 33.3% |
| `one_construct_per_line` | 996 | 679 | 31.8% |
| `one_tagged_type_per_package` | 28 | 21 | 25.0% |
| `operator_renamings` | 51 | 50 | 2.0% |
| `others_in_aggregates` | 92 | 77 | 16.3% |
| `others_in_case_statements` | 140 | 88 | 37.1% |
| `others_in_exception_handlers` | 156 | 52 | 66.7% |
| `out_parameter_read_in_exception_handler` | 0 | 0 | n/a |
| `outbound_protected_assignments` | 53 | 5 | 90.6% |
| `outer_loop_exits` | 4 | 2 | 50.0% |
| `outside_references_from_subprograms` | 3045 | 1890 | 37.9% |
| `overloaded_operators` | 188 | 158 | 16.0% |
| `overly_nested_control_structures` | 119 | 119 | 0.0% |
| `overly_nested_scopes` | 0 | 0 | n/a |
| `overriding_indicators` | 0 | 0 | n/a |
| `parameters_aliasing` | 11 | 11 | 0.0% |
| `parameters_out_of_order` | 2550 | 1446 | 43.3% |
| `pos_on_enumeration_types` | 129 | 94 | 27.1% |
| `positional_actuals_for_defaulted_generic_parameters` | 26 | 11 | 57.7% |
| `positional_actuals_for_defaulted_parameters` | 818 | 466 | 43.0% |
| `positional_components` | 879 | 207 | 76.5% |
| `positional_generic_parameters` | 386 | 230 | 40.4% |
| `positional_parameters` | 9157 | 5282 | 42.3% |
| `potential_parameters_aliasing` | 0 | 0 | n/a |
| `predefined_numeric_types` | 4363 | 2356 | 46.0% |
| `predicate_testing` | 2 | 0 | 100.0% |
| `printable_ascii` | 250 | 250 | 0.0% |
| `profile_discrepancies` | 143 | 96 | 32.9% |
| `quantified_expressions` | 21 | 5 | 76.2% |
| `raising_external_exceptions` | 153 | 119 | 22.2% |
| `raising_predefined_exceptions` | 146 | 69 | 52.7% |
| `recursive_subprograms` | 0 | 0 | n/a |
| `redundant_boolean_expressions` | 13 | 10 | 23.1% |
| `redundant_null_statements` | 4 | 4 | 0.0% |
| `relative_delay_statements` | 17 | 1 | 94.1% |
| `renamings` | 768 | 582 | 24.2% |
| `representation_specifications` | 276 | 191 | 30.8% |
| `same_logic` | 1 | 0 | 100.0% |
| `same_operands` | 0 | 0 | n/a |
| `same_tests` | 0 | 0 | n/a |
| `separate_numeric_error_handlers` | 48 | 31 | 35.4% |
| `separates` | 37 | 24 | 35.1% |
| `silent_exception_handlers` | 239 | 218 | 8.8% |
| `simple_loop_statements` | 204 | 199 | 2.5% |
| `single_value_enumeration_types` | 1 | 0 | 100.0% |
| `size_attribute_for_types` | 26 | 10 | 61.5% |
| `slices` | 1235 | 739 | 40.2% |
| `spark_procedures_without_globals` | 0 | 0 | n/a |
| `specific_parent_type_invariant` | 0 | 0 | n/a |
| `specific_pre_post` | 229 | 56 | 75.5% |
| `specific_type_invariants` | 0 | 0 | n/a |
| `style_checks:M` | 0 | 0 | n/a |
| `style_checks:b` | 0 | 0 | n/a |
| `subprogram_access` | 169 | 57 | 66.3% |
| `suspicious_equalities` | 0 | 0 | n/a |
| `too_many_dependencies` | 191 | 191 | 0.0% |
| `too_many_generic_dependencies` | 0 | 0 | n/a |
| `too_many_parents` | 0 | 0 | n/a |
| `too_many_primitives` | 134 | 55 | 59.0% |
| `trivial_exception_handlers` | 0 | 0 | n/a |
| `unassigned_out_parameters` | 16 | 12 | 25.0% |
| `unchecked_address_conversions` | 7 | 7 | 0.0% |
| `unchecked_conversions_as_actuals` | 7 | 4 | 42.9% |
| `uncommented_begin` | 2544 | 1224 | 51.9% |
| `uncommented_begin_in_package_bodies` | 16 | 8 | 50.0% |
| `uncommented_end_record` | 84 | 49 | 41.7% |
| `unconditional_exits` | 131 | 70 | 46.6% |
| `unconstrained_array_returns` | 916 | 343 | 62.6% |
| `unconstrained_arrays` | 76 | 47 | 38.2% |
| `uninitialized_global_variables` | 447 | 401 | 10.3% |
| `universal_ranges` | 152 | 63 | 58.6% |
| `unnamed_blocks_and_loops` | 998 | 439 | 56.0% |
| `unnamed_exits` | 0 | 0 | n/a |
| `use_array_slices` | 2 | 1 | 50.0% |
| `use_case_statements` | 46 | 34 | 26.1% |
| `use_for_loops` | 11 | 11 | 0.0% |
| `use_for_of_loops` | 68 | 41 | 39.7% |
| `use_if_expressions` | 648 | 312 | 51.9% |
| `use_memberships` | 9 | 9 | 0.0% |
| `use_package_clauses` | 981 | 598 | 39.0% |
| `use_ranges` | 8 | 3 | 62.5% |
| `use_record_aggregates` | 16 | 7 | 56.2% |
| `use_simple_loops` | 1 | 1 | 0.0% |
| `use_while_loops` | 9 | 2 | 77.8% |
| `variable_scoping` | 24 | 17 | 29.2% |
| `visible_components` | 87 | 66 | 24.1% |
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
| `warnings:u.unit` | 1 | 1 | 0.0% |

## Known, explained differences

- GNATcheck analyzes the whole project closure, so findings in dependency sources (`gnatcoll-*`, `sax-*`, `schema-*`, `dom-*`, `unicode-*`) that AdaLang does not analyze in this benchmark's scope count as GNATcheck-only.
- `Deep_Nesting` vs. `overly_nested_control_structures`: GNATcheck reports every over-nested construct at its own line with threshold 3; AdaLang reports one finding per subprogram at its name with threshold 4, so exact lines essentially never coincide (not a defect).
- Matching is on `(file basename, line, rule pair)`; rule pairs are name-level matches, not proven semantic equivalence (`docs/src/gnatcheck-rule-comparison.md`).
- `null_paths` family (`Empty_*_Body`, `Null_Case_Alternative`): GNATcheck reports at the empty statement, AdaLang at the branch or alternative.
- `No_Multiple_Return`/`improper_returns` differ in granularity (per subprogram vs. per return); `Too_Many_Parameters`/`maximum_parameters` report spec vs. body and use different default thresholds; `Missing_Global_Contract` deliberately also fires outside `SPARK_Mode`.
- `Identical_Branches`/`Identical_Case_Alternative` vs. `duplicate_branches` (run with `min_stmt=1,min_size=1`, matched on the line GNATcheck names as the duplicate): AdaLang compares adjacent branches only, so GNATcheck's non-adjacent pairs stay GNATcheck-only; GNATcheck reports one pair per `if`/`case`, so the later members of a run of identical adjacent branches stay AdaLang-only.
- The two tools analyse different file sets: AdaLang takes the sources of the root project, GNATcheck the closure it loads. The shared-file figures above leave out findings in files only one tool analysed.
- AdaLang resolves names only among the sources of the root project. Units of an imported project stay unresolved here, so checks that need a type or a declaration (positional associations, predefined numeric types, slices, array returns, object-oriented checks) report less than GNATcheck, and checks that ask whether a body has a separate declaration can report a body GNATcheck attributes to its specification. This is a limitation of the analyzer's project support, not of the individual checks; `skippedChecks` in the AdaLang JSON report counts the affected queries.
