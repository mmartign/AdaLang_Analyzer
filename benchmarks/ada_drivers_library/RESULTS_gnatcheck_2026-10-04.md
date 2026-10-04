# Ada_Drivers_Library: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Current results, refreshed 2026-10-04. This file replaces the earlier dated runs, which remain in the Git history. The refresh adds the rule pairs of the 167 opt-in coding-standard checks (153 of them run here; the other 14 report nothing until configured and are not in the rule map). The pairs that were already compared on 2026-09-24 are run again; the analyzer now also resolves names through imported projects (`FP-102`), which can change their numbers too.

## Environment

- Corpus: pinned at `81c04806d267fc12116a6f746c8e05012cef0484` (`ADL_REVISION`), unchanged.
- AdaLang Analyzer: 1.7.0 plus the unreleased coding-standard checks (branch `gnatcheck-rule-parity`).
- GNATcheck: the same from-source build as prior runs; one pass with the plain `-r` rules, then one pass per column-4 option line of `benchmarks/gnatcheck_rule_map.tsv` (`benchmarks/gnatcheck_rule_args.awk`).
- Reproduce: `ADL_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/ada_drivers_library/run_gnatcheck.sh` (see this directory's README for
  any setup step).
- GNATcheck worker crashes ("unparsable worker output"): each GNATcheck invocation was repeated until it finished without a crash; the plain rules were run in batches of at most 25 where one pass over all of them kept crashing. Across the attempts logged for this corpus, 6 invocations were repeated. The accepted log has no crash and no GNATcheck error line.

## Totals

| | 2026-10-04, all pairs | 2026-10-04, pairs of 2026-09-24 | 2026-09-24 |
| --- | ---: | ---: | ---: |
| AdaLang findings | 7038 | 860 | 860 |
| &nbsp;&nbsp;matched by GNATcheck | 6469 (91.9%) | 424 (49.3%) | 425 (49.4%) |
| GNATcheck findings | 7188 | 1135 | 1136 |
| &nbsp;&nbsp;matched by AdaLang | 6469 (90.0%) | 424 (37.4%) | 425 (37.4%) |

Pairs of 2026-09-24 whose numbers changed (findings, tool-only), all others are identical:

- `Naming_Convention`: 39 findings, 32 AdaLang-only then; 39, 34 now.
- `No_Pragma`: 44 findings, 1 AdaLang-only then; 44, 0 now.
- `min_identifier_length` (GNATcheck): 21 findings, 14 GNATcheck-only then; 19, 14 now.
- `forbidden_pragmas` (GNATcheck): 43 findings, 0 GNATcheck-only then; 44, 0 now.

## Coding-standard checks

The 153 new pairs, counted over all files: 6178 AdaLang findings, 6045 matched by GNATcheck (97.8%); 6053 GNATcheck findings, 6045 matched by AdaLang (99.9%). 81 of the 153 checks have a finding from one tool or the other on this corpus.

The two tools do not analyse the same set of files (see the notes below), so the same pairs are also counted over the files both analysed: 6178 AdaLang findings and 6053 GNATcheck findings, 6045 at the same file and line; 133 AdaLang-only, 8 GNATcheck-only.

- This corpus is analysed as two synthetic projects because variant directories hold files with the same name; the comparator matches on file basename, so a finding in one variant can be matched against, or missed in, the other.
- GNATcheck-only findings: 8. AdaLang-only findings: 133, mainly `Representation_Specification` (33), `Positional_Parameter` (32), `Predefined_Numeric_Type` (24) and `Complex_Inlined_Subprogram` (22). This lane analyses synthetic projects written for the benchmark, which do not import the projects the drivers depend on, so about 1,500 checks are still skipped here and the `FP-102` fix does not apply. The differences have not been examined one by one.
- This run found and fixed two defects: `Global_Variable` reported a renaming of a constant as a variable, and `Uninitialized_Global_Variable` reported local variables whose enclosing scope could not be resolved.

## Duplicate branches

`Identical_Branches` + `Identical_Case_Alternative`: 4 findings, 4 matched by GNATcheck's `duplicate_branches` (100.0%); `duplicate_branches`: 6 findings, 4 matched (66.7%). With GNATcheck's default thresholds (4 statements / 14 tokens) this pair had 0 GNATcheck findings on every corpus.

## Per AdaLang rule

| AdaLang rule | Match | Findings | AdaLang-only | Matched |
| --- | --- | ---: | ---: | ---: |
| Abstract_Type_Declaration | direct | 0 | 0 | n/a |
| Access_To_Local_Object | direct | 0 | 0 | n/a |
| Ada05_Formal_Package | direct | 0 | 0 | n/a |
| Ada_2022_In_Ghost_Code | direct | 0 | 0 | n/a |
| Address_Clause | close | 10 | 8 | 20.0% |
| Address_Of_Non_Volatile_Object | direct | 0 | 0 | n/a |
| Aliasing_Between_Parameters | direct | 0 | 0 | n/a |
| Anonymous_Access_Type | direct | 4 | 0 | 100.0% |
| Anonymous_Array_Type | direct | 3 | 0 | 100.0% |
| Anonymous_Subtype | direct | 46 | 0 | 100.0% |
| Array_Slice | direct | 0 | 0 | n/a |
| Binary_Case_Statement | direct | 58 | 0 | 100.0% |
| Bit_Record_Without_Layout | direct | 0 | 0 | n/a |
| Boolean_Relational_Operator | direct | 3 | 0 | 100.0% |
| Complex_Inlined_Subprogram | direct | 44 | 22 | 50.0% |
| Concurrent_Interface | direct | 0 | 0 | n/a |
| Conditional_Expression | direct | 83 | 0 | 100.0% |
| Constant_Condition | close | 0 | 0 | n/a |
| Constant_Overlay | direct | 0 | 0 | n/a |
| Constructor | direct | 0 | 0 | n/a |
| Cyclomatic_Complexity | direct | 17 | 4 | 76.5% |
| Dead_Store | close | 0 | 0 | n/a |
| Declaration_In_Block | close | 16 | 0 | 100.0% |
| Deep_Inheritance_Hierarchy | direct | 0 | 0 | n/a |
| Deep_Library_Hierarchy | direct | 0 | 0 | n/a |
| Deep_Nesting | direct | 1 | 1 | 0.0% |
| Deeply_Nested_Generic | direct | 0 | 0 | n/a |
| Deeply_Nested_Instantiation | direct | 0 | 0 | n/a |
| Default_Parameter | direct | 87 | 0 | 100.0% |
| Default_Value_For_Record_Component | direct | 58 | 0 | 100.0% |
| Dependency_Limit | direct | 0 | 0 | n/a |
| Deriving_From_Predefined_Type | direct | 2 | 0 | 100.0% |
| Direct_Call_To_Primitive | direct | 162 | 6 | 96.3% |
| Discriminated_Record | direct | 24 | 0 | 100.0% |
| Downward_View_Conversion | direct | 0 | 0 | n/a |
| Duplicate_Boolean_Operand | close | 0 | 0 | n/a |
| Duplicate_Condition | direct | 0 | 0 | n/a |
| Duplicate_With_Clause | direct | 0 | 0 | n/a |
| Empty_Else_Body | close | 0 | 0 | n/a |
| Empty_Elsif_Body | close | 0 | 0 | n/a |
| Empty_Exception_Handler | direct | 0 | 0 | n/a |
| Empty_If_Body | close | 0 | 0 | n/a |
| Empty_Then_Body | close | 0 | 0 | n/a |
| End_Of_Line_Comment | direct | 137 | 0 | 100.0% |
| Enumeration_Range_In_Case_Statement | direct | 0 | 0 | n/a |
| Enumeration_Representation_Clause | direct | 21 | 0 | 100.0% |
| Essential_Complexity | direct | 35 | 0 | 100.0% |
| Exception_As_Control_Flow | direct | 0 | 0 | n/a |
| Exception_Propagation | close | 2 | 2 | 0.0% |
| Exception_Swallowed | close | 0 | 0 | n/a |
| Exit_From_Conditional_Loop | direct | 6 | 0 | 100.0% |
| Exit_Without_Loop_Name | direct | 19 | 0 | 100.0% |
| Expanded_Loop_Exit_Name | direct | 0 | 0 | n/a |
| Explicit_Full_Discrete_Range | direct | 0 | 0 | n/a |
| Explicit_Inlining | direct | 123 | 0 | 100.0% |
| Expression_Function | direct | 36 | 0 | 100.0% |
| Final_Package | direct | 0 | 0 | n/a |
| Fixed_Equality | direct | 0 | 0 | n/a |
| Floating_Equality | direct | 0 | 0 | n/a |
| Function_Out_Parameter | direct | 33 | 0 | 100.0% |
| Function_Style_Procedure | direct | 5 | 0 | 100.0% |
| Generic_In_Out_Object | direct | 0 | 0 | n/a |
| Generic_In_Subprogram | direct | 0 | 0 | n/a |
| Global_Variable | direct | 0 | 0 | n/a |
| Identical_Branches | direct | 4 | 0 | 100.0% |
| Identical_Case_Alternative | close | 0 | 0 | n/a |
| Implicit_In_Mode | direct | 1970 | 0 | 100.0% |
| Implicit_Small | direct | 0 | 0 | n/a |
| Improperly_Located_Instantiation | direct | 24 | 0 | 100.0% |
| Incomplete_Representation_Specification | direct | 18 | 0 | 100.0% |
| Infinite_Loop | close | 2 | 0 | 100.0% |
| Library_Level_Initialization | close | 2 | 2 | 0.0% |
| Library_Level_Subprogram | direct | 0 | 0 | n/a |
| Local_Instantiation | direct | 20 | 3 | 85.0% |
| Local_Package | direct | 0 | 0 | n/a |
| Local_Use_Clause | direct | 12 | 0 | 100.0% |
| Logical_SLOC | direct | 14 | 0 | 100.0% |
| Long_Line | direct | 0 | 0 | n/a |
| Lowercase_Keyword | direct | 0 | 0 | n/a |
| Magic_Number | close | 587 | 268 | 54.3% |
| Maximum_Expression_Complexity | direct | 122 | 0 | 100.0% |
| Maximum_Identifier_Length | direct | 597 | 0 | 100.0% |
| Maximum_Lines | direct | 0 | 0 | n/a |
| Maximum_Out_Parameters | direct | 2 | 0 | 100.0% |
| Maximum_Subprogram_Lines | direct | 0 | 0 | n/a |
| Membership_For_Validity | direct | 0 | 0 | n/a |
| Membership_Test | direct | 34 | 0 | 100.0% |
| Misnamed_Controlling_Parameter | direct | 1 | 0 | 100.0% |
| Misplaced_Representation_Item | direct | 0 | 0 | n/a |
| Missing_Global_Contract | close | 12 | 12 | 0.0% |
| Missing_Overriding_Indicator | direct | 0 | 0 | n/a |
| Multiple_Protected_Entries | direct | 0 | 0 | n/a |
| Naming_Convention | close | 39 | 34 | 12.8% |
| Nested_Path | direct | 0 | 0 | n/a |
| Nested_Subprogram | direct | 20 | 0 | 100.0% |
| No_Abort | direct | 0 | 0 | n/a |
| No_Access_To_Subp_Def | direct | 1 | 0 | 100.0% |
| No_Block_Statement | direct | 16 | 0 | 100.0% |
| No_Closing_Name | direct | 0 | 0 | n/a |
| No_Controlled_Type | direct | 0 | 0 | n/a |
| No_Explicit_Real_Range | direct | 0 | 0 | n/a |
| No_Goto | direct | 0 | 0 | n/a |
| No_Inherited_Classwide_Pre | direct | 1 | 0 | 100.0% |
| No_Multiple_Return | direct | 71 | 69 | 2.8% |
| No_Pragma | close | 44 | 0 | 100.0% |
| No_Recursion | direct | 0 | 0 | n/a |
| No_Scalar_Storage_Order | direct | 18 | 0 | 100.0% |
| No_Use_Package_Clause | direct | 101 | 0 | 100.0% |
| Non_Component_In_Barrier | direct | 0 | 0 | n/a |
| Non_Constant_Overlay | direct | 0 | 0 | n/a |
| Non_Qualified_Aggregate | direct | 81 | 6 | 92.6% |
| Non_SPARK_Attribute | direct | 317 | 0 | 100.0% |
| Non_Short_Circuit_Condition | direct | 10 | 1 | 90.0% |
| Non_Tagged_Derived_Type | direct | 16 | 0 | 100.0% |
| Non_Visible_Exception | direct | 0 | 0 | n/a |
| Nonoverlay_Address_Specification | direct | 8 | 0 | 100.0% |
| Not_Imported_Overlay | direct | 0 | 0 | n/a |
| Null_Case_Alternative | close | 4 | 4 | 0.0% |
| Null_Statement | direct | 0 | 0 | n/a |
| Number_Declaration | direct | 50 | 0 | 100.0% |
| Numeric_Format | direct | 107 | 0 | 100.0% |
| Numeric_Indexing | direct | 0 | 0 | n/a |
| Object_Declaration_Out_Of_Order | direct | 1 | 0 | 100.0% |
| Object_Of_Anonymous_Type | direct | 2 | 0 | 100.0% |
| One_Construct_Per_Line | direct | 22 | 0 | 100.0% |
| One_Tagged_Type_Per_Package | direct | 2 | 0 | 100.0% |
| Operator_Renaming | direct | 0 | 0 | n/a |
| Others_In_Aggregate | direct | 28 | 0 | 100.0% |
| Others_In_Case_Statement | direct | 3 | 0 | 100.0% |
| Others_In_Exception_Handler | direct | 0 | 0 | n/a |
| Out_Parameter_Read_In_Exception_Handler | direct | 0 | 0 | n/a |
| Outbound_Protected_Assignment | direct | 23 | 0 | 100.0% |
| Outer_Loop_Exit | direct | 0 | 0 | n/a |
| Outside_Reference_From_Subprogram | direct | 0 | 0 | n/a |
| Overloaded_Operator | direct | 4 | 0 | 100.0% |
| Overly_Nested_Scope | direct | 0 | 0 | n/a |
| Overwritten_Assignment | close | 0 | 0 | n/a |
| Parameters_Out_Of_Order | direct | 440 | 0 | 100.0% |
| Pos_On_Enumeration_Type | direct | 15 | 0 | 100.0% |
| Positional_Component | direct | 6 | 0 | 100.0% |
| Positional_Defaulted_Generic_Parameter | direct | 0 | 0 | n/a |
| Positional_Defaulted_Parameter | direct | 1 | 0 | 100.0% |
| Positional_Generic_Parameter | direct | 31 | 5 | 83.9% |
| Positional_Parameter | direct | 274 | 32 | 88.3% |
| Predefined_Numeric_Type | direct | 202 | 24 | 88.1% |
| Predicate_Testing | direct | 0 | 0 | n/a |
| Printable_ASCII | direct | 1 | 0 | 100.0% |
| Profile_Discrepancy | direct | 0 | 0 | n/a |
| Quantified_Expression | direct | 14 | 0 | 100.0% |
| Raising_External_Exception | direct | 0 | 0 | n/a |
| Raising_Predefined_Exception | direct | 20 | 0 | 100.0% |
| Redundant_Boolean_Comparison | close | 0 | 0 | n/a |
| Redundant_Type_Conversion | close | 0 | 0 | n/a |
| Relative_Delay | direct | 0 | 0 | n/a |
| Renaming_Declaration | direct | 33 | 0 | 100.0% |
| Representation_Specification | direct | 129 | 33 | 74.4% |
| Same_Logic | direct | 0 | 0 | n/a |
| Same_Operand | direct | 0 | 0 | n/a |
| Self_Assignment | close | 0 | 0 | n/a |
| Separate_Numeric_Error_Handler | direct | 0 | 0 | n/a |
| Separate_Unit | direct | 0 | 0 | n/a |
| Single_Value_Enumeration_Type | direct | 0 | 0 | n/a |
| Size_Attribute_For_Type | direct | 0 | 0 | n/a |
| Specific_Parent_Type_Invariant | direct | 0 | 0 | n/a |
| Specific_Pre_Post | direct | 18 | 0 | 100.0% |
| Specific_Type_Invariant | direct | 0 | 0 | n/a |
| Suspicious_Equality | direct | 0 | 0 | n/a |
| Too_Many_Generic_Dependencies | direct | 0 | 0 | n/a |
| Too_Many_Parameters | direct | 20 | 12 | 40.0% |
| Too_Many_Parents | direct | 0 | 0 | n/a |
| Too_Many_Primitives | direct | 8 | 0 | 100.0% |
| Trailing_Whitespace | direct | 0 | 0 | n/a |
| Unchecked_Address_Conversion | direct | 3 | 1 | 66.7% |
| Unchecked_Conversion_As_Actual | direct | 0 | 0 | n/a |
| Uncommented_Begin | direct | 174 | 0 | 100.0% |
| Uncommented_Begin_In_Package_Body | direct | 0 | 0 | n/a |
| Uncommented_End_Record | direct | 20 | 0 | 100.0% |
| Unconditional_Exit | direct | 4 | 0 | 100.0% |
| Unconstrained_Array_Return | direct | 0 | 0 | n/a |
| Unconstrained_Array_Type | direct | 10 | 0 | 100.0% |
| Uninitialized_Global_Variable | direct | 6 | 0 | 100.0% |
| Uninitialized_Output | close | 25 | 10 | 60.0% |
| Universal_Range | direct | 7 | 0 | 100.0% |
| Unnamed_Block_Or_Loop | direct | 51 | 0 | 100.0% |
| Unnamed_Exit | direct | 0 | 0 | n/a |
| Unused_Parameter | close | 0 | 0 | n/a |
| Unused_Variable | close | 2 | 2 | 0.0% |
| Unused_With_Clause | close | 2 | 2 | 0.0% |
| Use_Array_Slice | direct | 0 | 0 | n/a |
| Use_Case_Statement | direct | 1 | 0 | 100.0% |
| Use_For_Loop | direct | 2 | 0 | 100.0% |
| Use_For_Of_Loop | direct | 0 | 0 | n/a |
| Use_If_Expression | direct | 30 | 1 | 96.7% |
| Use_Membership | direct | 0 | 0 | n/a |
| Use_Range | direct | 0 | 0 | n/a |
| Use_Record_Aggregate | direct | 0 | 0 | n/a |
| Use_Simple_Loop | direct | 0 | 0 | n/a |
| Use_While_Loop | direct | 12 | 0 | 100.0% |
| Variable_Scoping | direct | 1 | 0 | 100.0% |
| Visible_Component | direct | 25 | 0 | 100.0% |
| Volatile_Object_Without_Address | direct | 1 | 0 | 100.0% |
| Wrong_Parameter_Mode | close | 5 | 5 | 0.0% |

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
| `address_specifications_for_local_objects` | 6 | 4 | 33.3% |
| `anonymous_access` | 4 | 0 | 100.0% |
| `anonymous_arrays` | 3 | 0 | 100.0% |
| `anonymous_subtypes` | 46 | 0 | 100.0% |
| `at_representation_clauses` | 0 | 0 | n/a |
| `binary_case_statements` | 58 | 0 | 100.0% |
| `bit_records_without_layout_definition` | 0 | 0 | n/a |
| `blocks` | 16 | 0 | 100.0% |
| `boolean_negations` | 0 | 0 | n/a |
| `boolean_relational_operators` | 3 | 0 | 100.0% |
| `calls_outside_elaboration` | 0 | 0 | n/a |
| `complex_inlined_subprograms` | 22 | 0 | 100.0% |
| `concurrent_interfaces` | 0 | 0 | n/a |
| `conditional_expressions` | 83 | 0 | 100.0% |
| `constant_overlays` | 0 | 0 | n/a |
| `constructors` | 0 | 0 | n/a |
| `controlled_type_declarations` | 0 | 0 | n/a |
| `declarations_in_blocks` | 16 | 0 | 100.0% |
| `deep_inheritance_hierarchies` | 0 | 0 | n/a |
| `deep_library_hierarchy` | 0 | 0 | n/a |
| `deeply_nested_generics` | 0 | 0 | n/a |
| `deeply_nested_instantiations` | 0 | 0 | n/a |
| `default_parameters` | 87 | 0 | 100.0% |
| `default_values_for_record_components` | 58 | 0 | 100.0% |
| `deriving_from_predefined_type` | 2 | 0 | 100.0% |
| `direct_calls_to_primitives` | 156 | 0 | 100.0% |
| `discriminated_records` | 24 | 0 | 100.0% |
| `downward_view_conversions` | 0 | 0 | n/a |
| `duplicate_branches` | 6 | 2 | 66.7% |
| `end_of_line_comments` | 137 | 0 | 100.0% |
| `enumeration_ranges_in_case_statements` | 0 | 0 | n/a |
| `enumeration_representation_clauses` | 21 | 0 | 100.0% |
| `exception_propagation_from_callbacks` | 0 | 0 | n/a |
| `exception_propagation_from_export` | 0 | 0 | n/a |
| `exception_propagation_from_tasks` | 0 | 0 | n/a |
| `exceptions_as_control_flow` | 0 | 0 | n/a |
| `exit_statements_with_no_loop_name` | 19 | 0 | 100.0% |
| `exits_from_conditional_loops` | 6 | 0 | 100.0% |
| `expanded_loop_exit_names` | 0 | 0 | n/a |
| `explicit_full_discrete_ranges` | 0 | 0 | n/a |
| `explicit_inlining` | 123 | 0 | 100.0% |
| `expression_functions` | 36 | 0 | 100.0% |
| `final_package` | 0 | 0 | n/a |
| `fixed_equality_checks` | 0 | 0 | n/a |
| `float_equality_checks` | 0 | 0 | n/a |
| `forbidden_pragmas` | 44 | 0 | 100.0% |
| `function_out_parameters` | 33 | 0 | 100.0% |
| `function_style_procedures` | 5 | 0 | 100.0% |
| `generic_in_out_objects` | 0 | 0 | n/a |
| `generics_in_subprograms` | 0 | 0 | n/a |
| `global_variables` | 0 | 0 | n/a |
| `goto_statements` | 0 | 0 | n/a |
| `implicit_in_mode_parameters` | 1970 | 0 | 100.0% |
| `implicit_small_for_fixed_point_types` | 0 | 0 | n/a |
| `improper_returns` | 340 | 338 | 0.6% |
| `improperly_located_instantiations` | 24 | 0 | 100.0% |
| `incomplete_representation_specifications` | 18 | 0 | 100.0% |
| `library_level_subprograms` | 0 | 0 | n/a |
| `local_instantiations` | 19 | 2 | 89.5% |
| `local_packages` | 0 | 0 | n/a |
| `local_use_clauses` | 12 | 0 | 100.0% |
| `lowercase_keywords` | 0 | 0 | n/a |
| `max_identifier_length` | 597 | 0 | 100.0% |
| `maximum_expression_complexity` | 122 | 0 | 100.0% |
| `maximum_lines` | 0 | 0 | n/a |
| `maximum_out_parameters` | 2 | 0 | 100.0% |
| `maximum_parameters` | 155 | 147 | 5.2% |
| `maximum_subprogram_lines` | 0 | 0 | n/a |
| `membership_for_validity` | 0 | 0 | n/a |
| `membership_tests` | 34 | 0 | 100.0% |
| `metrics_cyclomatic_complexity` | 77 | 64 | 16.9% |
| `metrics_essential_complexity` | 35 | 0 | 100.0% |
| `metrics_lsloc` | 14 | 0 | 100.0% |
| `min_identifier_length` | 19 | 14 | 26.3% |
| `misnamed_controlling_parameters` | 1 | 0 | 100.0% |
| `misplaced_representation_items` | 0 | 0 | n/a |
| `multiple_entries_in_protected_definitions` | 0 | 0 | n/a |
| `nested_paths` | 0 | 0 | n/a |
| `nested_subprograms` | 22 | 2 | 90.9% |
| `no_closing_names` | 0 | 0 | n/a |
| `no_explicit_real_range` | 0 | 0 | n/a |
| `no_inherited_classwide_pre` | 1 | 0 | 100.0% |
| `no_scalar_storage_order_specified` | 18 | 0 | 100.0% |
| `non_component_in_barriers` | 0 | 0 | n/a |
| `non_constant_overlays` | 0 | 0 | n/a |
| `non_qualified_aggregates` | 75 | 0 | 100.0% |
| `non_short_circuit_operators` | 55 | 46 | 16.4% |
| `non_spark_attributes` | 317 | 0 | 100.0% |
| `non_tagged_derived_types` | 16 | 0 | 100.0% |
| `non_visible_exceptions` | 0 | 0 | n/a |
| `nonoverlay_address_specifications` | 8 | 0 | 100.0% |
| `not_imported_overlays` | 0 | 0 | n/a |
| `null_paths` | 50 | 50 | 0.0% |
| `number_declarations` | 50 | 0 | 100.0% |
| `numeric_format` | 107 | 0 | 100.0% |
| `numeric_indexing` | 0 | 0 | n/a |
| `numeric_literals` | 319 | 0 | 100.0% |
| `object_declarations_out_of_order` | 1 | 0 | 100.0% |
| `objects_of_anonymous_types` | 2 | 0 | 100.0% |
| `one_construct_per_line` | 22 | 0 | 100.0% |
| `one_tagged_type_per_package` | 2 | 0 | 100.0% |
| `operator_renamings` | 0 | 0 | n/a |
| `others_in_aggregates` | 28 | 0 | 100.0% |
| `others_in_case_statements` | 3 | 0 | 100.0% |
| `others_in_exception_handlers` | 0 | 0 | n/a |
| `out_parameter_read_in_exception_handler` | 0 | 0 | n/a |
| `outbound_protected_assignments` | 23 | 0 | 100.0% |
| `outer_loop_exits` | 0 | 0 | n/a |
| `outside_references_from_subprograms` | 0 | 0 | n/a |
| `overloaded_operators` | 4 | 0 | 100.0% |
| `overly_nested_control_structures` | 0 | 0 | n/a |
| `overly_nested_scopes` | 0 | 0 | n/a |
| `overriding_indicators` | 0 | 0 | n/a |
| `parameters_aliasing` | 0 | 0 | n/a |
| `parameters_out_of_order` | 440 | 0 | 100.0% |
| `pos_on_enumeration_types` | 15 | 0 | 100.0% |
| `positional_actuals_for_defaulted_generic_parameters` | 0 | 0 | n/a |
| `positional_actuals_for_defaulted_parameters` | 1 | 0 | 100.0% |
| `positional_components` | 6 | 0 | 100.0% |
| `positional_generic_parameters` | 26 | 0 | 100.0% |
| `positional_parameters` | 242 | 0 | 100.0% |
| `potential_parameters_aliasing` | 0 | 0 | n/a |
| `predefined_numeric_types` | 182 | 4 | 97.8% |
| `predicate_testing` | 0 | 0 | n/a |
| `printable_ascii` | 1 | 0 | 100.0% |
| `profile_discrepancies` | 0 | 0 | n/a |
| `quantified_expressions` | 14 | 0 | 100.0% |
| `raising_external_exceptions` | 0 | 0 | n/a |
| `raising_predefined_exceptions` | 20 | 0 | 100.0% |
| `recursive_subprograms` | 0 | 0 | n/a |
| `redundant_boolean_expressions` | 0 | 0 | n/a |
| `redundant_null_statements` | 0 | 0 | n/a |
| `relative_delay_statements` | 0 | 0 | n/a |
| `renamings` | 33 | 0 | 100.0% |
| `representation_specifications` | 96 | 0 | 100.0% |
| `same_logic` | 0 | 0 | n/a |
| `same_operands` | 0 | 0 | n/a |
| `same_tests` | 0 | 0 | n/a |
| `separate_numeric_error_handlers` | 0 | 0 | n/a |
| `separates` | 0 | 0 | n/a |
| `silent_exception_handlers` | 0 | 0 | n/a |
| `simple_loop_statements` | 19 | 17 | 10.5% |
| `single_value_enumeration_types` | 0 | 0 | n/a |
| `size_attribute_for_types` | 0 | 0 | n/a |
| `slices` | 0 | 0 | n/a |
| `spark_procedures_without_globals` | 0 | 0 | n/a |
| `specific_parent_type_invariant` | 0 | 0 | n/a |
| `specific_pre_post` | 18 | 0 | 100.0% |
| `specific_type_invariants` | 0 | 0 | n/a |
| `style_checks:M` | 0 | 0 | n/a |
| `style_checks:b` | 0 | 0 | n/a |
| `subprogram_access` | 1 | 0 | 100.0% |
| `suspicious_equalities` | 0 | 0 | n/a |
| `too_many_dependencies` | 0 | 0 | n/a |
| `too_many_generic_dependencies` | 0 | 0 | n/a |
| `too_many_parents` | 0 | 0 | n/a |
| `too_many_primitives` | 8 | 0 | 100.0% |
| `trivial_exception_handlers` | 0 | 0 | n/a |
| `unassigned_out_parameters` | 44 | 29 | 34.1% |
| `unchecked_address_conversions` | 2 | 0 | 100.0% |
| `unchecked_conversions_as_actuals` | 0 | 0 | n/a |
| `uncommented_begin` | 174 | 0 | 100.0% |
| `uncommented_begin_in_package_bodies` | 0 | 0 | n/a |
| `uncommented_end_record` | 20 | 0 | 100.0% |
| `unconditional_exits` | 4 | 0 | 100.0% |
| `unconstrained_array_returns` | 0 | 0 | n/a |
| `unconstrained_arrays` | 10 | 0 | 100.0% |
| `uninitialized_global_variables` | 6 | 0 | 100.0% |
| `universal_ranges` | 7 | 0 | 100.0% |
| `unnamed_blocks_and_loops` | 51 | 0 | 100.0% |
| `unnamed_exits` | 0 | 0 | n/a |
| `use_array_slices` | 0 | 0 | n/a |
| `use_case_statements` | 1 | 0 | 100.0% |
| `use_for_loops` | 2 | 0 | 100.0% |
| `use_for_of_loops` | 0 | 0 | n/a |
| `use_if_expressions` | 29 | 0 | 100.0% |
| `use_memberships` | 0 | 0 | n/a |
| `use_package_clauses` | 101 | 0 | 100.0% |
| `use_ranges` | 0 | 0 | n/a |
| `use_record_aggregates` | 0 | 0 | n/a |
| `use_simple_loops` | 0 | 0 | n/a |
| `use_while_loops` | 12 | 0 | 100.0% |
| `variable_scoping` | 1 | 0 | 100.0% |
| `visible_components` | 25 | 0 | 100.0% |
| `volatile_objects_without_address_clauses` | 1 | 0 | 100.0% |
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

- Before this refresh the runner split each extra GNATcheck pass at spaces (an indented `IFS` value), so none of the fourteen pairs added on 2026-09-23 was actually checked on this corpus: the 2026-09-23 run showed GNATcheck at 0 for all of them, including 44 `No_Pragma` findings as AdaLang-only. Fixed; `No_Pragma` now matches.
- The compiler-driven pairs (`warnings:*`, `style_checks:*`) still cannot be judged here: GNATcheck's `Warnings`/`Style_Checks` rules compile each unit, and the two variant projects do not provide every dependency (e.g. `stm32_svd.ads`), so GNAT emits no warnings. Their GNATcheck column is structurally 0 on this corpus, not agreement or disagreement.
- This from-source GNATcheck build hits a deterministic `too_many_dependencies.lkql` internal issue and stack overflow on this corpus (see the attempt record above).
- Matching is on `(file basename, line, rule pair)`; rule pairs are name-level matches, not proven semantic equivalence (`docs/src/gnatcheck-rule-comparison.md`).
- `null_paths` family (`Empty_*_Body`, `Null_Case_Alternative`): GNATcheck reports at the empty statement, AdaLang at the branch or alternative.
- `No_Multiple_Return`/`improper_returns` differ in granularity (per subprogram vs. per return); `Too_Many_Parameters`/`maximum_parameters` report spec vs. body and use different default thresholds; `Missing_Global_Contract` deliberately also fires outside `SPARK_Mode`.
- `Identical_Branches`/`Identical_Case_Alternative` vs. `duplicate_branches` (run with `min_stmt=1,min_size=1`, matched on the line GNATcheck names as the duplicate): AdaLang compares adjacent branches only, so GNATcheck's non-adjacent pairs stay GNATcheck-only; GNATcheck reports one pair per `if`/`case`, so the later members of a run of identical adjacent branches stay AdaLang-only.
- The two tools analyse different file sets: AdaLang takes the sources of the root project, GNATcheck the closure it loads. The shared-file figures above leave out findings in files only one tool analysed.
