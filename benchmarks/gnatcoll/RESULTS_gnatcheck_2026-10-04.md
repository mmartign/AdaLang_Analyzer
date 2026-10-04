# gnatcoll-core: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Current results, refreshed 2026-10-04. This file replaces the earlier dated runs, which remain in the Git history. The refresh adds the rule pairs of the 167 opt-in coding-standard checks (153 of them run here; the other 14 report nothing until configured and are not in the rule map). The pairs that were already compared on 2026-09-24 are run again unchanged.

## Environment

- Corpus: pinned at `9f6ffb394793b0ac098fb1e9b206a659680788b3` (`GNATCOLL_REVISION`), unchanged.
- AdaLang Analyzer: 1.7.0 plus the unreleased coding-standard checks (branch `gnatcheck-rule-parity`).
- GNATcheck: the same from-source build as prior runs; one pass with the plain `-r` rules, then one pass per column-4 option line of `benchmarks/gnatcheck_rule_map.tsv` (`benchmarks/gnatcheck_rule_args.awk`).
- Reproduce: `GNATCOLL_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/gnatcoll/run_gnatcheck.sh` (see this directory's README for
  any setup step).
- GNATcheck worker crashes ("unparsable worker output"): each GNATcheck invocation was repeated until it finished without a crash; the plain rules were run in batches of at most 25 where one pass over all of them kept crashing. Across the attempts logged for this corpus, 7 invocations were repeated. The accepted log has no crash and no GNATcheck error line.

## Totals

| | 2026-10-04, all pairs | 2026-10-04, pairs of 2026-09-24 | 2026-09-24 |
| --- | ---: | ---: | ---: |
| AdaLang findings | 15287 | 2108 | 2108 |
| &nbsp;&nbsp;matched by GNATcheck | 14276 (93.4%) | 1269 (60.2%) | 1269 (60.2%) |
| GNATcheck findings | 24471 | 2943 | 2943 |
| &nbsp;&nbsp;matched by AdaLang | 14274 (58.3%) | 1267 (43.1%) | 1267 (43.1%) |

Every pair of 2026-09-24 has the same numbers as then.

## Coding-standard checks

The 153 new pairs, counted over all files: 13179 AdaLang findings, 13007 matched by GNATcheck (98.7%); 21528 GNATcheck findings, 13007 matched by AdaLang (60.4%). 121 of the 153 checks have a finding from one tool or the other on this corpus.

The two tools do not analyse the same set of files (see the notes below), so the same pairs are also counted over the files both analysed: 13179 AdaLang findings and 19916 GNATcheck findings, 13007 at the same file and line; 172 AdaLang-only, 6909 GNATcheck-only.

- `gnatcoll_core.gpr` imports `gnatcoll_minimal.gpr`, which holds the root `GNATCOLL` packages. AdaLang logged 10,823 skipped checks on this corpus, by far the most of the ten, and GNATcheck analysed 187 files against AdaLang's 154.
- The effect is clearest on `Predefined_Numeric_Type`: 0 AdaLang findings against 1,455, because no declaration that depends on the unresolved parent units could be resolved. Purely syntactic checks agree (`Declaration_In_Block` 187 of 188, the one difference being the documented divergence).
- The 172 AdaLang-only findings are almost all on bodies whose separate declaration was not resolved (`Function_Style_Procedure` 50, `Nested_Subprogram` 50, `Overloaded_Operator` 22, `Function_Out_Parameter` 19).

## Duplicate branches

`Identical_Branches` + `Identical_Case_Alternative`: 8 findings, 8 matched by GNATcheck's `duplicate_branches` (100.0%); `duplicate_branches`: 10 findings, 8 matched (80.0%). With GNATcheck's default thresholds (4 statements / 14 tokens) this pair had 0 GNATcheck findings on every corpus.

## Per AdaLang rule

| AdaLang rule | Match | Findings | AdaLang-only | Matched |
| --- | --- | ---: | ---: | ---: |
| Abstract_Type_Declaration | direct | 29 | 0 | 100.0% |
| Access_To_Local_Object | direct | 2 | 0 | 100.0% |
| Ada05_Formal_Package | direct | 0 | 0 | n/a |
| Ada_2022_In_Ghost_Code | direct | 0 | 0 | n/a |
| Address_Clause | close | 6 | 5 | 16.7% |
| Address_Of_Non_Volatile_Object | direct | 4 | 0 | 100.0% |
| Aliasing_Between_Parameters | direct | 0 | 0 | n/a |
| Anonymous_Access_Type | direct | 6 | 0 | 100.0% |
| Anonymous_Array_Type | direct | 21 | 0 | 100.0% |
| Anonymous_Subtype | direct | 696 | 0 | 100.0% |
| Array_Slice | direct | 9 | 0 | 100.0% |
| Binary_Case_Statement | direct | 7 | 0 | 100.0% |
| Bit_Record_Without_Layout | direct | 0 | 0 | n/a |
| Boolean_Relational_Operator | direct | 0 | 0 | n/a |
| Complex_Inlined_Subprogram | direct | 8 | 0 | 100.0% |
| Concurrent_Interface | direct | 0 | 0 | n/a |
| Conditional_Expression | direct | 58 | 0 | 100.0% |
| Constant_Condition | close | 1 | 1 | 0.0% |
| Constant_Overlay | direct | 2 | 0 | 100.0% |
| Constructor | direct | 16 | 1 | 93.8% |
| Cyclomatic_Complexity | direct | 69 | 0 | 100.0% |
| Dead_Store | close | 9 | 9 | 0.0% |
| Declaration_In_Block | close | 187 | 0 | 100.0% |
| Deep_Inheritance_Hierarchy | direct | 0 | 0 | n/a |
| Deep_Library_Hierarchy | direct | 0 | 0 | n/a |
| Deep_Nesting | direct | 31 | 31 | 0.0% |
| Deeply_Nested_Generic | direct | 0 | 0 | n/a |
| Deeply_Nested_Instantiation | direct | 0 | 0 | n/a |
| Default_Parameter | direct | 554 | 0 | 100.0% |
| Default_Value_For_Record_Component | direct | 141 | 0 | 100.0% |
| Dependency_Limit | direct | 0 | 0 | n/a |
| Deriving_From_Predefined_Type | direct | 0 | 0 | n/a |
| Direct_Call_To_Primitive | direct | 20 | 0 | 100.0% |
| Discriminated_Record | direct | 14 | 0 | 100.0% |
| Downward_View_Conversion | direct | 2 | 0 | 100.0% |
| Duplicate_Boolean_Operand | close | 0 | 0 | n/a |
| Duplicate_Condition | direct | 0 | 0 | n/a |
| Duplicate_With_Clause | direct | 0 | 0 | n/a |
| Empty_Else_Body | close | 1 | 1 | 0.0% |
| Empty_Elsif_Body | close | 4 | 4 | 0.0% |
| Empty_Exception_Handler | direct | 4 | 0 | 100.0% |
| Empty_If_Body | close | 1 | 1 | 0.0% |
| Empty_Then_Body | close | 10 | 10 | 0.0% |
| End_Of_Line_Comment | direct | 109 | 0 | 100.0% |
| Enumeration_Range_In_Case_Statement | direct | 0 | 0 | n/a |
| Enumeration_Representation_Clause | direct | 2 | 0 | 100.0% |
| Essential_Complexity | direct | 114 | 0 | 100.0% |
| Exception_As_Control_Flow | direct | 3 | 0 | 100.0% |
| Exception_Propagation | close | 2 | 2 | 0.0% |
| Exception_Swallowed | close | 2 | 0 | 100.0% |
| Exit_From_Conditional_Loop | direct | 61 | 0 | 100.0% |
| Exit_Without_Loop_Name | direct | 94 | 0 | 100.0% |
| Expanded_Loop_Exit_Name | direct | 0 | 0 | n/a |
| Explicit_Full_Discrete_Range | direct | 1 | 0 | 100.0% |
| Explicit_Inlining | direct | 106 | 0 | 100.0% |
| Expression_Function | direct | 42 | 0 | 100.0% |
| Final_Package | direct | 0 | 0 | n/a |
| Fixed_Equality | direct | 0 | 0 | n/a |
| Floating_Equality | direct | 4 | 0 | 100.0% |
| Function_Out_Parameter | direct | 76 | 19 | 75.0% |
| Function_Style_Procedure | direct | 117 | 50 | 57.3% |
| Generic_In_Out_Object | direct | 7 | 0 | 100.0% |
| Generic_In_Subprogram | direct | 0 | 0 | n/a |
| Global_Variable | direct | 2 | 1 | 50.0% |
| Identical_Branches | direct | 7 | 0 | 100.0% |
| Identical_Case_Alternative | close | 1 | 0 | 100.0% |
| Implicit_In_Mode | direct | 4252 | 0 | 100.0% |
| Implicit_Small | direct | 0 | 0 | n/a |
| Improperly_Located_Instantiation | direct | 84 | 0 | 100.0% |
| Incomplete_Representation_Specification | direct | 0 | 0 | n/a |
| Infinite_Loop | close | 1 | 0 | 100.0% |
| Library_Level_Initialization | close | 0 | 0 | n/a |
| Library_Level_Subprogram | direct | 1 | 0 | 100.0% |
| Local_Instantiation | direct | 44 | 0 | 100.0% |
| Local_Package | direct | 2 | 0 | 100.0% |
| Local_Use_Clause | direct | 118 | 0 | 100.0% |
| Logical_SLOC | direct | 30 | 0 | 100.0% |
| Long_Line | direct | 0 | 0 | n/a |
| Lowercase_Keyword | direct | 0 | 0 | n/a |
| Magic_Number | close | 493 | 13 | 97.4% |
| Maximum_Expression_Complexity | direct | 406 | 0 | 100.0% |
| Maximum_Identifier_Length | direct | 315 | 0 | 100.0% |
| Maximum_Lines | direct | 0 | 0 | n/a |
| Maximum_Out_Parameters | direct | 4 | 2 | 50.0% |
| Maximum_Subprogram_Lines | direct | 0 | 0 | n/a |
| Membership_For_Validity | direct | 0 | 0 | n/a |
| Membership_Test | direct | 44 | 0 | 100.0% |
| Misnamed_Controlling_Parameter | direct | 388 | 0 | 100.0% |
| Misplaced_Representation_Item | direct | 6 | 5 | 16.7% |
| Missing_Global_Contract | close | 121 | 121 | 0.0% |
| Missing_Overriding_Indicator | direct | 0 | 0 | n/a |
| Multiple_Protected_Entries | direct | 0 | 0 | n/a |
| Naming_Convention | close | 630 | 196 | 68.9% |
| Nested_Path | direct | 53 | 0 | 100.0% |
| Nested_Subprogram | direct | 217 | 50 | 77.0% |
| No_Abort | direct | 0 | 0 | n/a |
| No_Access_To_Subp_Def | direct | 39 | 0 | 100.0% |
| No_Block_Statement | direct | 209 | 0 | 100.0% |
| No_Closing_Name | direct | 0 | 0 | n/a |
| No_Controlled_Type | direct | 14 | 9 | 35.7% |
| No_Explicit_Real_Range | direct | 1 | 0 | 100.0% |
| No_Goto | direct | 2 | 0 | 100.0% |
| No_Inherited_Classwide_Pre | direct | 12 | 1 | 91.7% |
| No_Multiple_Return | direct | 333 | 333 | 0.0% |
| No_Pragma | close | 215 | 0 | 100.0% |
| No_Recursion | direct | 0 | 0 | n/a |
| No_Scalar_Storage_Order | direct | 0 | 0 | n/a |
| No_Use_Package_Clause | direct | 294 | 0 | 100.0% |
| Non_Component_In_Barrier | direct | 1 | 1 | 0.0% |
| Non_Constant_Overlay | direct | 4 | 0 | 100.0% |
| Non_Qualified_Aggregate | direct | 192 | 9 | 95.3% |
| Non_SPARK_Attribute | direct | 893 | 0 | 100.0% |
| Non_Short_Circuit_Condition | direct | 0 | 0 | n/a |
| Non_Tagged_Derived_Type | direct | 26 | 0 | 100.0% |
| Non_Visible_Exception | direct | 1 | 0 | 100.0% |
| Nonoverlay_Address_Specification | direct | 0 | 0 | n/a |
| Not_Imported_Overlay | direct | 1 | 0 | 100.0% |
| Null_Case_Alternative | close | 11 | 10 | 9.1% |
| Null_Statement | direct | 1 | 0 | 100.0% |
| Number_Declaration | direct | 25 | 0 | 100.0% |
| Numeric_Format | direct | 56 | 0 | 100.0% |
| Numeric_Indexing | direct | 42 | 0 | 100.0% |
| Object_Declaration_Out_Of_Order | direct | 5 | 0 | 100.0% |
| Object_Of_Anonymous_Type | direct | 16 | 0 | 100.0% |
| One_Construct_Per_Line | direct | 50 | 0 | 100.0% |
| One_Tagged_Type_Per_Package | direct | 4 | 0 | 100.0% |
| Operator_Renaming | direct | 1 | 0 | 100.0% |
| Others_In_Aggregate | direct | 27 | 0 | 100.0% |
| Others_In_Case_Statement | direct | 30 | 0 | 100.0% |
| Others_In_Exception_Handler | direct | 34 | 0 | 100.0% |
| Out_Parameter_Read_In_Exception_Handler | direct | 0 | 0 | n/a |
| Outbound_Protected_Assignment | direct | 6 | 1 | 83.3% |
| Outer_Loop_Exit | direct | 1 | 0 | 100.0% |
| Outside_Reference_From_Subprogram | direct | 24 | 0 | 100.0% |
| Overloaded_Operator | direct | 60 | 22 | 63.3% |
| Overly_Nested_Scope | direct | 0 | 0 | n/a |
| Overwritten_Assignment | close | 2 | 2 | 0.0% |
| Parameters_Out_Of_Order | direct | 788 | 0 | 100.0% |
| Pos_On_Enumeration_Type | direct | 0 | 0 | n/a |
| Positional_Component | direct | 19 | 0 | 100.0% |
| Positional_Defaulted_Generic_Parameter | direct | 0 | 0 | n/a |
| Positional_Defaulted_Parameter | direct | 15 | 0 | 100.0% |
| Positional_Generic_Parameter | direct | 108 | 0 | 100.0% |
| Positional_Parameter | direct | 140 | 0 | 100.0% |
| Predefined_Numeric_Type | direct | 0 | 0 | n/a |
| Predicate_Testing | direct | 0 | 0 | n/a |
| Printable_ASCII | direct | 1 | 0 | 100.0% |
| Profile_Discrepancy | direct | 2 | 0 | 100.0% |
| Quantified_Expression | direct | 5 | 0 | 100.0% |
| Raising_External_Exception | direct | 18 | 0 | 100.0% |
| Raising_Predefined_Exception | direct | 0 | 0 | n/a |
| Redundant_Boolean_Comparison | close | 0 | 0 | n/a |
| Redundant_Type_Conversion | close | 0 | 0 | n/a |
| Relative_Delay | direct | 0 | 0 | n/a |
| Renaming_Declaration | direct | 110 | 0 | 100.0% |
| Representation_Specification | direct | 73 | 0 | 100.0% |
| Same_Logic | direct | 0 | 0 | n/a |
| Same_Operand | direct | 0 | 0 | n/a |
| Self_Assignment | close | 0 | 0 | n/a |
| Separate_Numeric_Error_Handler | direct | 0 | 0 | n/a |
| Separate_Unit | direct | 26 | 0 | 100.0% |
| Single_Value_Enumeration_Type | direct | 0 | 0 | n/a |
| Size_Attribute_For_Type | direct | 2 | 0 | 100.0% |
| Specific_Parent_Type_Invariant | direct | 0 | 0 | n/a |
| Specific_Pre_Post | direct | 0 | 0 | n/a |
| Specific_Type_Invariant | direct | 0 | 0 | n/a |
| Suspicious_Equality | direct | 0 | 0 | n/a |
| Too_Many_Generic_Dependencies | direct | 0 | 0 | n/a |
| Too_Many_Parameters | direct | 23 | 23 | 0.0% |
| Too_Many_Parents | direct | 0 | 0 | n/a |
| Too_Many_Primitives | direct | 21 | 1 | 95.2% |
| Trailing_Whitespace | direct | 0 | 0 | n/a |
| Unchecked_Address_Conversion | direct | 0 | 0 | n/a |
| Unchecked_Conversion_As_Actual | direct | 0 | 0 | n/a |
| Uncommented_Begin | direct | 726 | 0 | 100.0% |
| Uncommented_Begin_In_Package_Body | direct | 7 | 0 | 100.0% |
| Uncommented_End_Record | direct | 18 | 0 | 100.0% |
| Unconditional_Exit | direct | 36 | 0 | 100.0% |
| Unconstrained_Array_Return | direct | 9 | 3 | 66.7% |
| Unconstrained_Array_Type | direct | 27 | 0 | 100.0% |
| Uninitialized_Global_Variable | direct | 5 | 0 | 100.0% |
| Uninitialized_Output | close | 49 | 46 | 6.1% |
| Universal_Range | direct | 19 | 0 | 100.0% |
| Unnamed_Block_Or_Loop | direct | 292 | 0 | 100.0% |
| Unnamed_Exit | direct | 0 | 0 | n/a |
| Unused_Parameter | close | 13 | 13 | 0.0% |
| Unused_Variable | close | 3 | 3 | 0.0% |
| Unused_With_Clause | close | 2 | 2 | 0.0% |
| Use_Array_Slice | direct | 0 | 0 | n/a |
| Use_Case_Statement | direct | 3 | 0 | 100.0% |
| Use_For_Loop | direct | 0 | 0 | n/a |
| Use_For_Of_Loop | direct | 0 | 0 | n/a |
| Use_If_Expression | direct | 181 | 0 | 100.0% |
| Use_Membership | direct | 2 | 0 | 100.0% |
| Use_Range | direct | 3 | 0 | 100.0% |
| Use_Record_Aggregate | direct | 0 | 0 | n/a |
| Use_Simple_Loop | direct | 0 | 0 | n/a |
| Use_While_Loop | direct | 3 | 0 | 100.0% |
| Variable_Scoping | direct | 6 | 6 | 0.0% |
| Visible_Component | direct | 25 | 0 | 100.0% |
| Volatile_Object_Without_Address | direct | 0 | 0 | n/a |
| Wrong_Parameter_Mode | close | 4 | 4 | 0.0% |

## Per GNATcheck rule

| GNATcheck rule | Findings | GNATcheck-only | Matched |
| --- | ---: | ---: | ---: |
| `abort_statements` | 0 | 0 | n/a |
| `abstract_type_declarations` | 39 | 10 | 74.4% |
| `access_to_local_objects` | 9 | 7 | 22.2% |
| `ada05_formal_packages` | 0 | 0 | n/a |
| `ada_2022_in_ghost_code` | 0 | 0 | n/a |
| `address_attribute_for_non_volatile_objects` | 7 | 3 | 57.1% |
| `address_specifications_for_initialized_objects` | 0 | 0 | n/a |
| `address_specifications_for_local_objects` | 6 | 5 | 16.7% |
| `anonymous_access` | 20 | 14 | 30.0% |
| `anonymous_arrays` | 32 | 11 | 65.6% |
| `anonymous_subtypes` | 815 | 119 | 85.4% |
| `at_representation_clauses` | 0 | 0 | n/a |
| `binary_case_statements` | 7 | 0 | 100.0% |
| `bit_records_without_layout_definition` | 3 | 3 | 0.0% |
| `blocks` | 211 | 2 | 99.1% |
| `boolean_negations` | 0 | 0 | n/a |
| `boolean_relational_operators` | 8 | 8 | 0.0% |
| `calls_outside_elaboration` | 0 | 0 | n/a |
| `complex_inlined_subprograms` | 58 | 50 | 13.8% |
| `concurrent_interfaces` | 0 | 0 | n/a |
| `conditional_expressions` | 66 | 8 | 87.9% |
| `constant_overlays` | 2 | 0 | 100.0% |
| `constructors` | 40 | 25 | 37.5% |
| `controlled_type_declarations` | 21 | 16 | 23.8% |
| `declarations_in_blocks` | 190 | 3 | 98.4% |
| `deep_inheritance_hierarchies` | 1 | 1 | 0.0% |
| `deep_library_hierarchy` | 0 | 0 | n/a |
| `deeply_nested_generics` | 0 | 0 | n/a |
| `deeply_nested_instantiations` | 0 | 0 | n/a |
| `default_parameters` | 596 | 42 | 93.0% |
| `default_values_for_record_components` | 157 | 16 | 89.8% |
| `deriving_from_predefined_type` | 17 | 17 | 0.0% |
| `direct_calls_to_primitives` | 1196 | 1176 | 1.7% |
| `discriminated_records` | 20 | 6 | 70.0% |
| `downward_view_conversions` | 59 | 57 | 3.4% |
| `duplicate_branches` | 10 | 2 | 80.0% |
| `end_of_line_comments` | 125 | 16 | 87.2% |
| `enumeration_ranges_in_case_statements` | 5 | 5 | 0.0% |
| `enumeration_representation_clauses` | 2 | 0 | 100.0% |
| `exception_propagation_from_callbacks` | 0 | 0 | n/a |
| `exception_propagation_from_export` | 4 | 4 | 0.0% |
| `exception_propagation_from_tasks` | 0 | 0 | n/a |
| `exceptions_as_control_flow` | 3 | 0 | 100.0% |
| `exit_statements_with_no_loop_name` | 104 | 10 | 90.4% |
| `exits_from_conditional_loops` | 65 | 4 | 93.8% |
| `expanded_loop_exit_names` | 0 | 0 | n/a |
| `explicit_full_discrete_ranges` | 2 | 1 | 50.0% |
| `explicit_inlining` | 166 | 60 | 63.9% |
| `expression_functions` | 46 | 4 | 91.3% |
| `final_package` | 0 | 0 | n/a |
| `fixed_equality_checks` | 0 | 0 | n/a |
| `float_equality_checks` | 9 | 5 | 44.4% |
| `forbidden_pragmas` | 267 | 52 | 80.5% |
| `function_out_parameters` | 59 | 2 | 96.6% |
| `function_style_procedures` | 69 | 2 | 97.1% |
| `generic_in_out_objects` | 9 | 2 | 77.8% |
| `generics_in_subprograms` | 0 | 0 | n/a |
| `global_variables` | 1 | 0 | 100.0% |
| `goto_statements` | 2 | 0 | 100.0% |
| `implicit_in_mode_parameters` | 4660 | 408 | 91.2% |
| `implicit_small_for_fixed_point_types` | 0 | 0 | n/a |
| `improper_returns` | 669 | 669 | 0.0% |
| `improperly_located_instantiations` | 102 | 18 | 82.4% |
| `incomplete_representation_specifications` | 2 | 2 | 0.0% |
| `library_level_subprograms` | 3 | 2 | 33.3% |
| `local_instantiations` | 52 | 8 | 84.6% |
| `local_packages` | 3 | 1 | 66.7% |
| `local_use_clauses` | 125 | 7 | 94.4% |
| `lowercase_keywords` | 0 | 0 | n/a |
| `max_identifier_length` | 345 | 30 | 91.3% |
| `maximum_expression_complexity` | 450 | 44 | 90.2% |
| `maximum_lines` | 0 | 0 | n/a |
| `maximum_out_parameters` | 5 | 3 | 40.0% |
| `maximum_parameters` | 197 | 197 | 0.0% |
| `maximum_subprogram_lines` | 0 | 0 | n/a |
| `membership_for_validity` | 0 | 0 | n/a |
| `membership_tests` | 48 | 4 | 91.7% |
| `metrics_cyclomatic_complexity` | 202 | 133 | 34.2% |
| `metrics_essential_complexity` | 119 | 5 | 95.8% |
| `metrics_lsloc` | 30 | 0 | 100.0% |
| `min_identifier_length` | 654 | 220 | 66.4% |
| `misnamed_controlling_parameters` | 717 | 329 | 54.1% |
| `misplaced_representation_items` | 1 | 0 | 100.0% |
| `multiple_entries_in_protected_definitions` | 0 | 0 | n/a |
| `nested_paths` | 55 | 2 | 96.4% |
| `nested_subprograms` | 198 | 31 | 84.3% |
| `no_closing_names` | 0 | 0 | n/a |
| `no_explicit_real_range` | 1 | 0 | 100.0% |
| `no_inherited_classwide_pre` | 170 | 159 | 6.5% |
| `no_scalar_storage_order_specified` | 2 | 2 | 0.0% |
| `non_component_in_barriers` | 0 | 0 | n/a |
| `non_constant_overlays` | 4 | 0 | 100.0% |
| `non_qualified_aggregates` | 264 | 81 | 69.3% |
| `non_short_circuit_operators` | 31 | 31 | 0.0% |
| `non_spark_attributes` | 1049 | 156 | 85.1% |
| `non_tagged_derived_types` | 28 | 2 | 92.9% |
| `non_visible_exceptions` | 1 | 0 | 100.0% |
| `nonoverlay_address_specifications` | 0 | 0 | n/a |
| `not_imported_overlays` | 1 | 0 | 100.0% |
| `null_paths` | 43 | 42 | 2.3% |
| `number_declarations` | 28 | 3 | 89.3% |
| `numeric_format` | 57 | 1 | 98.2% |
| `numeric_indexing` | 309 | 267 | 13.6% |
| `numeric_literals` | 578 | 98 | 83.0% |
| `object_declarations_out_of_order` | 6 | 1 | 83.3% |
| `objects_of_anonymous_types` | 26 | 10 | 61.5% |
| `one_construct_per_line` | 61 | 11 | 82.0% |
| `one_tagged_type_per_package` | 17 | 13 | 23.5% |
| `operator_renamings` | 5 | 4 | 20.0% |
| `others_in_aggregates` | 28 | 1 | 96.4% |
| `others_in_case_statements` | 32 | 2 | 93.8% |
| `others_in_exception_handlers` | 35 | 1 | 97.1% |
| `out_parameter_read_in_exception_handler` | 0 | 0 | n/a |
| `outbound_protected_assignments` | 5 | 0 | 100.0% |
| `outer_loop_exits` | 1 | 0 | 100.0% |
| `outside_references_from_subprograms` | 373 | 349 | 6.4% |
| `overloaded_operators` | 73 | 35 | 52.1% |
| `overly_nested_control_structures` | 29 | 29 | 0.0% |
| `overly_nested_scopes` | 0 | 0 | n/a |
| `overriding_indicators` | 0 | 0 | n/a |
| `parameters_aliasing` | 3 | 3 | 0.0% |
| `parameters_out_of_order` | 884 | 96 | 89.1% |
| `pos_on_enumeration_types` | 19 | 19 | 0.0% |
| `positional_actuals_for_defaulted_generic_parameters` | 7 | 7 | 0.0% |
| `positional_actuals_for_defaulted_parameters` | 171 | 156 | 8.8% |
| `positional_components` | 99 | 80 | 19.2% |
| `positional_generic_parameters` | 134 | 26 | 80.6% |
| `positional_parameters` | 1970 | 1830 | 7.1% |
| `potential_parameters_aliasing` | 0 | 0 | n/a |
| `predefined_numeric_types` | 1517 | 1517 | 0.0% |
| `predicate_testing` | 0 | 0 | n/a |
| `printable_ascii` | 1 | 0 | 100.0% |
| `profile_discrepancies` | 44 | 42 | 4.5% |
| `quantified_expressions` | 5 | 0 | 100.0% |
| `raising_external_exceptions` | 77 | 59 | 23.4% |
| `raising_predefined_exceptions` | 30 | 30 | 0.0% |
| `recursive_subprograms` | 0 | 0 | n/a |
| `redundant_boolean_expressions` | 6 | 6 | 0.0% |
| `redundant_null_statements` | 1 | 0 | 100.0% |
| `relative_delay_statements` | 1 | 1 | 0.0% |
| `renamings` | 121 | 11 | 90.9% |
| `representation_specifications` | 113 | 40 | 64.6% |
| `same_logic` | 0 | 0 | n/a |
| `same_operands` | 0 | 0 | n/a |
| `same_tests` | 0 | 0 | n/a |
| `separate_numeric_error_handlers` | 13 | 13 | 0.0% |
| `separates` | 26 | 0 | 100.0% |
| `silent_exception_handlers` | 64 | 60 | 6.2% |
| `simple_loop_statements` | 42 | 41 | 2.4% |
| `single_value_enumeration_types` | 0 | 0 | n/a |
| `size_attribute_for_types` | 8 | 6 | 25.0% |
| `slices` | 411 | 402 | 2.2% |
| `spark_procedures_without_globals` | 0 | 0 | n/a |
| `specific_parent_type_invariant` | 0 | 0 | n/a |
| `specific_pre_post` | 56 | 56 | 0.0% |
| `specific_type_invariants` | 0 | 0 | n/a |
| `style_checks:M` | 0 | 0 | n/a |
| `style_checks:b` | 0 | 0 | n/a |
| `subprogram_access` | 41 | 2 | 95.1% |
| `suspicious_equalities` | 0 | 0 | n/a |
| `too_many_dependencies` | 59 | 59 | 0.0% |
| `too_many_generic_dependencies` | 0 | 0 | n/a |
| `too_many_parents` | 0 | 0 | n/a |
| `too_many_primitives` | 31 | 11 | 64.5% |
| `trivial_exception_handlers` | 0 | 0 | n/a |
| `unassigned_out_parameters` | 4 | 1 | 75.0% |
| `unchecked_address_conversions` | 7 | 7 | 0.0% |
| `unchecked_conversions_as_actuals` | 3 | 3 | 0.0% |
| `uncommented_begin` | 771 | 45 | 94.2% |
| `uncommented_begin_in_package_bodies` | 7 | 0 | 100.0% |
| `uncommented_end_record` | 21 | 3 | 85.7% |
| `unconditional_exits` | 41 | 5 | 87.8% |
| `unconstrained_array_returns` | 239 | 233 | 2.5% |
| `unconstrained_arrays` | 31 | 4 | 87.1% |
| `uninitialized_global_variables` | 7 | 2 | 71.4% |
| `universal_ranges` | 39 | 20 | 48.7% |
| `unnamed_blocks_and_loops` | 307 | 15 | 95.1% |
| `unnamed_exits` | 0 | 0 | n/a |
| `use_array_slices` | 0 | 0 | n/a |
| `use_case_statements` | 12 | 9 | 25.0% |
| `use_for_loops` | 6 | 6 | 0.0% |
| `use_for_of_loops` | 37 | 37 | 0.0% |
| `use_if_expressions` | 187 | 6 | 96.8% |
| `use_memberships` | 2 | 0 | 100.0% |
| `use_package_clauses` | 322 | 28 | 91.3% |
| `use_ranges` | 3 | 0 | 100.0% |
| `use_record_aggregates` | 2 | 2 | 0.0% |
| `use_simple_loops` | 1 | 1 | 0.0% |
| `use_while_loops` | 3 | 0 | 100.0% |
| `variable_scoping` | 8 | 8 | 0.0% |
| `visible_components` | 34 | 9 | 73.5% |
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

- Matching is on `(file basename, line, rule pair)`; rule pairs are name-level matches, not proven semantic equivalence (`docs/src/gnatcheck-rule-comparison.md`).
- `null_paths` family (`Empty_*_Body`, `Null_Case_Alternative`): GNATcheck reports at the empty statement, AdaLang at the branch or alternative.
- `No_Multiple_Return`/`improper_returns` differ in granularity (per subprogram vs. per return); `Too_Many_Parameters`/`maximum_parameters` report spec vs. body and use different default thresholds; `Missing_Global_Contract` deliberately also fires outside `SPARK_Mode`.
- `Identical_Branches`/`Identical_Case_Alternative` vs. `duplicate_branches` (run with `min_stmt=1,min_size=1`, matched on the line GNATcheck names as the duplicate): AdaLang compares adjacent branches only, so GNATcheck's non-adjacent pairs stay GNATcheck-only; GNATcheck reports one pair per `if`/`case`, so the later members of a run of identical adjacent branches stay AdaLang-only.
- The two tools analyse different file sets: AdaLang takes the sources of the root project, GNATcheck the closure it loads. The shared-file figures above leave out findings in files only one tool analysed.
- AdaLang resolves names only among the sources of the root project. Units of an imported project stay unresolved here, so checks that need a type or a declaration (positional associations, predefined numeric types, slices, array returns, object-oriented checks) report less than GNATcheck, and checks that ask whether a body has a separate declaration can report a body GNATcheck attributes to its specification. This is a limitation of the analyzer's project support, not of the individual checks; `skippedChecks` in the AdaLang JSON report counts the affected queries.
