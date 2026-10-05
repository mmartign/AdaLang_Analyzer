# CubedOS: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Current results, refreshed 2026-10-05. This file replaces the earlier dated runs, which remain in the Git history. It covers the rule pairs of the 175 opt-in coding-standard checks (158 of them run here; the other 17 report nothing until configured and are not in the rule map), five of them added since the 2026-10-04 run: `Use_Clause`, `Unavailable_Body_Call`, `Deeply_Nested_Inlining`, `Integer_Type_As_Enumeration` and `Same_Instantiation`. The pairs that were already compared on 2026-09-24 are run again; since then the analyzer resolves names through imported projects (`FP-102`) and applies a project's preprocessing switches (`FP-103`), which can change their numbers too.

## Environment

- Corpus: pinned at `c402301000a5a92237e0f7ab106186a48273cf24` (`CUBEDOS_REVISION`), unchanged.
- AdaLang Analyzer: 1.8.0.
- GNATcheck: the same from-source build as prior runs; one pass with the plain `-r` rules, then one pass per column-4 option line of `benchmarks/gnatcheck_rule_map.tsv` (`benchmarks/gnatcheck_rule_args.awk`).
- Reproduce: `CUBEDOS_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/cubedos/run_gnatcheck.sh` (see this directory's README for
  any setup step).
- GNATcheck worker crashes ("unparsable worker output"): each GNATcheck invocation was repeated until it finished without a crash; the plain rules were run in batches of at most 25 where one pass over all of them kept crashing. Across the attempts logged for this corpus, 0 invocations were repeated. The accepted log has no crash and no GNATcheck error line. The five rules added on 2026-10-05 were run one rule per invocation and appended to it; the analyzer side was then run again against the whole log.

## Totals

| | 2026-10-05, all pairs | 2026-10-05, pairs of 2026-09-24 | 2026-09-24 |
| --- | ---: | ---: | ---: |
| AdaLang findings | 2034 | 411 | 304 |
| &nbsp;&nbsp;matched by GNATcheck | 1891 (93.0%) | 268 (65.2%) | 258 (84.9%) |
| GNATcheck findings | 4283 | 862 | 862 |
| &nbsp;&nbsp;matched by AdaLang | 1891 (44.2%) | 268 (31.1%) | 258 (29.9%) |

Pairs of 2026-09-24 whose numbers changed (findings, tool-only), all others are identical:

- `Constant_Condition`: 2 findings, 2 AdaLang-only then; 3, 3 now.
- `Missing_Overriding_Indicator`: 0 findings, 0 AdaLang-only then; 8, 8 now.
- `Library_Level_Initialization`: 1 findings, 1 AdaLang-only then; 2, 2 now.
- `Dead_Store`: 3 findings, 3 AdaLang-only then; 62, 62 now.
- `Unused_With_Clause`: 17 findings, 17 AdaLang-only then; 18, 18 now.
- `Uninitialized_Output`: 8 findings, 5 AdaLang-only then; 5, 2 now.
- `Non_Short_Circuit_Condition`: 4 findings, 0 AdaLang-only then; 16, 2 now.
- `Missing_Global_Contract`: 4 findings, 4 AdaLang-only then; 32, 32 now.
- `non_short_circuit_operators` (GNATcheck): 62 findings, 58 GNATcheck-only then; 62, 48 now.

## Coding-standard checks

The 158 new pairs, counted over all files: 1623 AdaLang findings, 1623 matched by GNATcheck (100.0%); 3421 GNATcheck findings, 1623 matched by AdaLang (47.4%). 66 of the 158 checks have a finding from one tool or the other on this corpus.

The two tools do not analyse the same set of files (see the notes below), so the same pairs are also counted over the files both analysed: 1623 AdaLang findings and 1624 GNATcheck findings, 1623 at the same file and line; 0 AdaLang-only, 1 GNATcheck-only.

- CubedOS's root project imports its library project (`library/cubedlib.gpr`) and AUnit. GNATcheck analysed 91 files, AdaLang the 49 of the root project.
- This corpus is where `FP-102` showed: AdaLang resolved names only among the root project's sources, so everything that depended on a unit of an imported project went unresolved. The first run of these pairs, before the fix, matched 922 of GNATcheck's 1,577 findings in the shared files and logged 1,562 skipped checks. Now 1,576 match and 5 checks are skipped.
- The one GNATcheck-only finding is `Unconstrained_Array_Return` on a function of a generic package, reported through its instantiation.

## Duplicate branches

`Identical_Branches` + `Identical_Case_Alternative`: 1 findings, 1 matched by GNATcheck's `duplicate_branches` (100.0%); `duplicate_branches`: 1 findings, 1 matched (100.0%). With GNATcheck's default thresholds (4 statements / 14 tokens) this pair had 0 GNATcheck findings on every corpus.

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
| Anonymous_Array_Type | direct | 3 | 0 | 100.0% |
| Anonymous_Subtype | direct | 62 | 0 | 100.0% |
| Array_Slice | direct | 13 | 0 | 100.0% |
| Binary_Case_Statement | direct | 2 | 0 | 100.0% |
| Bit_Record_Without_Layout | direct | 0 | 0 | n/a |
| Boolean_Relational_Operator | direct | 0 | 0 | n/a |
| Complex_Inlined_Subprogram | direct | 0 | 0 | n/a |
| Concurrent_Interface | direct | 0 | 0 | n/a |
| Conditional_Expression | direct | 0 | 0 | n/a |
| Constant_Condition | close | 3 | 3 | 0.0% |
| Constant_Overlay | direct | 0 | 0 | n/a |
| Constructor | direct | 0 | 0 | n/a |
| Cyclomatic_Complexity | direct | 1 | 0 | 100.0% |
| Dead_Store | close | 62 | 62 | 0.0% |
| Declaration_In_Block | close | 1 | 0 | 100.0% |
| Deep_Inheritance_Hierarchy | direct | 4 | 0 | 100.0% |
| Deep_Library_Hierarchy | direct | 0 | 0 | n/a |
| Deep_Nesting | direct | 2 | 2 | 0.0% |
| Deeply_Nested_Generic | direct | 0 | 0 | n/a |
| Deeply_Nested_Inlining | direct | 0 | 0 | n/a |
| Deeply_Nested_Instantiation | direct | 0 | 0 | n/a |
| Default_Parameter | direct | 50 | 0 | 100.0% |
| Default_Value_For_Record_Component | direct | 16 | 0 | 100.0% |
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
| End_Of_Line_Comment | direct | 47 | 0 | 100.0% |
| Enumeration_Range_In_Case_Statement | direct | 0 | 0 | n/a |
| Enumeration_Representation_Clause | direct | 0 | 0 | n/a |
| Essential_Complexity | direct | 2 | 0 | 100.0% |
| Exception_As_Control_Flow | direct | 0 | 0 | n/a |
| Exception_Propagation | close | 0 | 0 | n/a |
| Exception_Swallowed | close | 0 | 0 | n/a |
| Exit_From_Conditional_Loop | direct | 2 | 0 | 100.0% |
| Exit_Without_Loop_Name | direct | 0 | 0 | n/a |
| Expanded_Loop_Exit_Name | direct | 0 | 0 | n/a |
| Explicit_Full_Discrete_Range | direct | 0 | 0 | n/a |
| Explicit_Inlining | direct | 0 | 0 | n/a |
| Expression_Function | direct | 24 | 0 | 100.0% |
| Final_Package | direct | 0 | 0 | n/a |
| Fixed_Equality | direct | 0 | 0 | n/a |
| Floating_Equality | direct | 0 | 0 | n/a |
| Function_Out_Parameter | direct | 0 | 0 | n/a |
| Function_Style_Procedure | direct | 5 | 0 | 100.0% |
| Generic_In_Out_Object | direct | 0 | 0 | n/a |
| Generic_In_Subprogram | direct | 0 | 0 | n/a |
| Global_Variable | direct | 4 | 0 | 100.0% |
| Identical_Branches | direct | 1 | 0 | 100.0% |
| Identical_Case_Alternative | close | 0 | 0 | n/a |
| Implicit_In_Mode | direct | 0 | 0 | n/a |
| Implicit_Small | direct | 0 | 0 | n/a |
| Improperly_Located_Instantiation | direct | 2 | 0 | 100.0% |
| Incomplete_Representation_Specification | direct | 0 | 0 | n/a |
| Infinite_Loop | close | 10 | 0 | 100.0% |
| Integer_Type_As_Enumeration | direct | 1 | 0 | 100.0% |
| Library_Level_Initialization | close | 2 | 2 | 0.0% |
| Library_Level_Subprogram | direct | 5 | 0 | 100.0% |
| Local_Instantiation | direct | 2 | 0 | 100.0% |
| Local_Package | direct | 0 | 0 | n/a |
| Local_Use_Clause | direct | 17 | 0 | 100.0% |
| Logical_SLOC | direct | 3 | 0 | 100.0% |
| Long_Line | direct | 4 | 0 | 100.0% |
| Lowercase_Keyword | direct | 0 | 0 | n/a |
| Magic_Number | close | 104 | 3 | 97.1% |
| Maximum_Expression_Complexity | direct | 102 | 0 | 100.0% |
| Maximum_Identifier_Length | direct | 69 | 0 | 100.0% |
| Maximum_Lines | direct | 0 | 0 | n/a |
| Maximum_Out_Parameters | direct | 7 | 0 | 100.0% |
| Maximum_Subprogram_Lines | direct | 0 | 0 | n/a |
| Membership_For_Validity | direct | 0 | 0 | n/a |
| Membership_Test | direct | 16 | 0 | 100.0% |
| Misnamed_Controlling_Parameter | direct | 8 | 0 | 100.0% |
| Misplaced_Representation_Item | direct | 0 | 0 | n/a |
| Missing_Global_Contract | close | 32 | 32 | 0.0% |
| Missing_Overriding_Indicator | direct | 8 | 8 | 0.0% |
| Multiple_Protected_Entries | direct | 0 | 0 | n/a |
| Naming_Convention | close | 41 | 3 | 92.7% |
| Nested_Path | direct | 2 | 0 | 100.0% |
| Nested_Subprogram | direct | 4 | 0 | 100.0% |
| No_Abort | direct | 0 | 0 | n/a |
| No_Access_To_Subp_Def | direct | 0 | 0 | n/a |
| No_Block_Statement | direct | 4 | 0 | 100.0% |
| No_Closing_Name | direct | 0 | 0 | n/a |
| No_Controlled_Type | direct | 0 | 0 | n/a |
| No_Explicit_Real_Range | direct | 0 | 0 | n/a |
| No_Goto | direct | 0 | 0 | n/a |
| No_Inherited_Classwide_Pre | direct | 8 | 0 | 100.0% |
| No_Multiple_Return | direct | 2 | 2 | 0.0% |
| No_Pragma | close | 94 | 0 | 100.0% |
| No_Recursion | direct | 0 | 0 | n/a |
| No_Scalar_Storage_Order | direct | 0 | 0 | n/a |
| No_Use_Package_Clause | direct | 45 | 0 | 100.0% |
| Non_Component_In_Barrier | direct | 0 | 0 | n/a |
| Non_Constant_Overlay | direct | 0 | 0 | n/a |
| Non_Qualified_Aggregate | direct | 119 | 0 | 100.0% |
| Non_SPARK_Attribute | direct | 136 | 0 | 100.0% |
| Non_Short_Circuit_Condition | direct | 16 | 2 | 87.5% |
| Non_Tagged_Derived_Type | direct | 0 | 0 | n/a |
| Non_Visible_Exception | direct | 0 | 0 | n/a |
| Nonoverlay_Address_Specification | direct | 0 | 0 | n/a |
| Not_Imported_Overlay | direct | 0 | 0 | n/a |
| Null_Case_Alternative | close | 0 | 0 | n/a |
| Null_Statement | direct | 0 | 0 | n/a |
| Number_Declaration | direct | 7 | 0 | 100.0% |
| Numeric_Format | direct | 19 | 0 | 100.0% |
| Numeric_Indexing | direct | 20 | 0 | 100.0% |
| Object_Declaration_Out_Of_Order | direct | 2 | 0 | 100.0% |
| Object_Of_Anonymous_Type | direct | 2 | 0 | 100.0% |
| One_Construct_Per_Line | direct | 4 | 0 | 100.0% |
| One_Tagged_Type_Per_Package | direct | 0 | 0 | n/a |
| Operator_Renaming | direct | 0 | 0 | n/a |
| Others_In_Aggregate | direct | 0 | 0 | n/a |
| Others_In_Case_Statement | direct | 1 | 0 | 100.0% |
| Others_In_Exception_Handler | direct | 3 | 0 | 100.0% |
| Out_Parameter_Read_In_Exception_Handler | direct | 0 | 0 | n/a |
| Outbound_Protected_Assignment | direct | 5 | 0 | 100.0% |
| Outer_Loop_Exit | direct | 0 | 0 | n/a |
| Outside_Reference_From_Subprogram | direct | 10 | 0 | 100.0% |
| Overloaded_Operator | direct | 0 | 0 | n/a |
| Overly_Nested_Scope | direct | 0 | 0 | n/a |
| Overwritten_Assignment | close | 0 | 0 | n/a |
| Parameters_Out_Of_Order | direct | 0 | 0 | n/a |
| Pos_On_Enumeration_Type | direct | 68 | 0 | 100.0% |
| Positional_Component | direct | 49 | 0 | 100.0% |
| Positional_Defaulted_Generic_Parameter | direct | 0 | 0 | n/a |
| Positional_Defaulted_Parameter | direct | 9 | 0 | 100.0% |
| Positional_Generic_Parameter | direct | 0 | 0 | n/a |
| Positional_Parameter | direct | 364 | 0 | 100.0% |
| Predefined_Numeric_Type | direct | 63 | 0 | 100.0% |
| Predicate_Testing | direct | 0 | 0 | n/a |
| Printable_ASCII | direct | 0 | 0 | n/a |
| Profile_Discrepancy | direct | 5 | 0 | 100.0% |
| Quantified_Expression | direct | 0 | 0 | n/a |
| Raising_External_Exception | direct | 0 | 0 | n/a |
| Raising_Predefined_Exception | direct | 0 | 0 | n/a |
| Redundant_Boolean_Comparison | close | 0 | 0 | n/a |
| Redundant_Type_Conversion | close | 0 | 0 | n/a |
| Relative_Delay | direct | 0 | 0 | n/a |
| Renaming_Declaration | direct | 2 | 0 | 100.0% |
| Representation_Specification | direct | 1 | 0 | 100.0% |
| Same_Instantiation | direct | 0 | 0 | n/a |
| Same_Logic | direct | 0 | 0 | n/a |
| Same_Operand | direct | 0 | 0 | n/a |
| Self_Assignment | close | 0 | 0 | n/a |
| Separate_Numeric_Error_Handler | direct | 0 | 0 | n/a |
| Separate_Unit | direct | 0 | 0 | n/a |
| Single_Value_Enumeration_Type | direct | 1 | 0 | 100.0% |
| Size_Attribute_For_Type | direct | 0 | 0 | n/a |
| Specific_Parent_Type_Invariant | direct | 0 | 0 | n/a |
| Specific_Pre_Post | direct | 0 | 0 | n/a |
| Specific_Type_Invariant | direct | 0 | 0 | n/a |
| Suspicious_Equality | direct | 0 | 0 | n/a |
| Too_Many_Generic_Dependencies | direct | 0 | 0 | n/a |
| Too_Many_Parameters | direct | 0 | 0 | n/a |
| Too_Many_Parents | direct | 0 | 0 | n/a |
| Too_Many_Primitives | direct | 4 | 0 | 100.0% |
| Trailing_Whitespace | direct | 0 | 0 | n/a |
| Unavailable_Body_Call | direct | 1 | 0 | 100.0% |
| Unchecked_Address_Conversion | direct | 0 | 0 | n/a |
| Unchecked_Conversion_As_Actual | direct | 0 | 0 | n/a |
| Uncommented_Begin | direct | 103 | 0 | 100.0% |
| Uncommented_Begin_In_Package_Body | direct | 0 | 0 | n/a |
| Uncommented_End_Record | direct | 0 | 0 | n/a |
| Unconditional_Exit | direct | 2 | 0 | 100.0% |
| Unconstrained_Array_Return | direct | 0 | 0 | n/a |
| Unconstrained_Array_Type | direct | 0 | 0 | n/a |
| Uninitialized_Global_Variable | direct | 10 | 0 | 100.0% |
| Uninitialized_Output | close | 5 | 2 | 60.0% |
| Universal_Range | direct | 11 | 0 | 100.0% |
| Unnamed_Block_Or_Loop | direct | 6 | 0 | 100.0% |
| Unnamed_Exit | direct | 0 | 0 | n/a |
| Unused_Parameter | close | 6 | 4 | 33.3% |
| Unused_Variable | close | 0 | 0 | n/a |
| Unused_With_Clause | close | 18 | 18 | 0.0% |
| Use_Array_Slice | direct | 2 | 0 | 100.0% |
| Use_Case_Statement | direct | 0 | 0 | n/a |
| Use_Clause | direct | 45 | 0 | 100.0% |
| Use_For_Loop | direct | 2 | 0 | 100.0% |
| Use_For_Of_Loop | direct | 0 | 0 | n/a |
| Use_If_Expression | direct | 4 | 0 | 100.0% |
| Use_Membership | direct | 4 | 0 | 100.0% |
| Use_Range | direct | 0 | 0 | n/a |
| Use_Record_Aggregate | direct | 3 | 0 | 100.0% |
| Use_Simple_Loop | direct | 0 | 0 | n/a |
| Use_While_Loop | direct | 0 | 0 | n/a |
| Variable_Scoping | direct | 0 | 0 | n/a |
| Visible_Component | direct | 6 | 0 | 100.0% |
| Volatile_Object_Without_Address | direct | 0 | 0 | n/a |
| Wrong_Parameter_Mode | close | 0 | 0 | n/a |

## Per GNATcheck rule

| GNATcheck rule | Findings | GNATcheck-only | Matched |
| --- | ---: | ---: | ---: |
| `abort_statements` | 0 | 0 | n/a |
| `abstract_type_declarations` | 13 | 13 | 0.0% |
| `access_to_local_objects` | 0 | 0 | n/a |
| `ada05_formal_packages` | 0 | 0 | n/a |
| `ada_2022_in_ghost_code` | 0 | 0 | n/a |
| `address_attribute_for_non_volatile_objects` | 0 | 0 | n/a |
| `address_specifications_for_initialized_objects` | 0 | 0 | n/a |
| `address_specifications_for_local_objects` | 1 | 1 | 0.0% |
| `anonymous_access` | 0 | 0 | n/a |
| `anonymous_arrays` | 4 | 1 | 75.0% |
| `anonymous_subtypes` | 120 | 58 | 51.7% |
| `at_representation_clauses` | 0 | 0 | n/a |
| `binary_case_statements` | 3 | 1 | 66.7% |
| `bit_records_without_layout_definition` | 0 | 0 | n/a |
| `blocks` | 17 | 13 | 23.5% |
| `boolean_negations` | 0 | 0 | n/a |
| `boolean_relational_operators` | 0 | 0 | n/a |
| `calls_outside_elaboration` | 0 | 0 | n/a |
| `complex_inlined_subprograms` | 5 | 5 | 0.0% |
| `concurrent_interfaces` | 0 | 0 | n/a |
| `conditional_expressions` | 4 | 4 | 0.0% |
| `constant_overlays` | 1 | 1 | 0.0% |
| `constructors` | 0 | 0 | n/a |
| `controlled_type_declarations` | 0 | 0 | n/a |
| `declarations_in_blocks` | 11 | 10 | 9.1% |
| `deep_inheritance_hierarchies` | 5 | 1 | 80.0% |
| `deep_library_hierarchy` | 0 | 0 | n/a |
| `deeply_nested_generics` | 0 | 0 | n/a |
| `deeply_nested_inlining` | 0 | 0 | n/a |
| `deeply_nested_instantiations` | 0 | 0 | n/a |
| `default_parameters` | 90 | 40 | 55.6% |
| `default_values_for_record_components` | 34 | 18 | 47.1% |
| `deriving_from_predefined_type` | 4 | 4 | 0.0% |
| `direct_calls_to_primitives` | 44 | 44 | 0.0% |
| `discriminated_records` | 2 | 2 | 0.0% |
| `downward_view_conversions` | 5 | 5 | 0.0% |
| `duplicate_branches` | 1 | 0 | 100.0% |
| `end_of_line_comments` | 50 | 3 | 94.0% |
| `enumeration_ranges_in_case_statements` | 0 | 0 | n/a |
| `enumeration_representation_clauses` | 0 | 0 | n/a |
| `exception_propagation_from_callbacks` | 0 | 0 | n/a |
| `exception_propagation_from_export` | 0 | 0 | n/a |
| `exception_propagation_from_tasks` | 8 | 8 | 0.0% |
| `exceptions_as_control_flow` | 0 | 0 | n/a |
| `exit_statements_with_no_loop_name` | 7 | 7 | 0.0% |
| `exits_from_conditional_loops` | 5 | 3 | 40.0% |
| `expanded_loop_exit_names` | 0 | 0 | n/a |
| `explicit_full_discrete_ranges` | 1 | 1 | 0.0% |
| `explicit_inlining` | 11 | 11 | 0.0% |
| `expression_functions` | 28 | 4 | 85.7% |
| `final_package` | 0 | 0 | n/a |
| `fixed_equality_checks` | 0 | 0 | n/a |
| `float_equality_checks` | 0 | 0 | n/a |
| `forbidden_pragmas` | 202 | 108 | 46.5% |
| `function_out_parameters` | 1 | 1 | 0.0% |
| `function_style_procedures` | 6 | 1 | 83.3% |
| `generic_in_out_objects` | 0 | 0 | n/a |
| `generics_in_subprograms` | 0 | 0 | n/a |
| `global_variables` | 4 | 0 | 100.0% |
| `goto_statements` | 0 | 0 | n/a |
| `implicit_in_mode_parameters` | 345 | 345 | 0.0% |
| `implicit_small_for_fixed_point_types` | 0 | 0 | n/a |
| `improper_returns` | 77 | 77 | 0.0% |
| `improperly_located_instantiations` | 20 | 18 | 10.0% |
| `incomplete_representation_specifications` | 0 | 0 | n/a |
| `integer_types_as_enum` | 4 | 3 | 25.0% |
| `library_level_subprograms` | 5 | 0 | 100.0% |
| `local_instantiations` | 15 | 13 | 13.3% |
| `local_packages` | 1 | 1 | 0.0% |
| `local_use_clauses` | 31 | 14 | 54.8% |
| `lowercase_keywords` | 0 | 0 | n/a |
| `max_identifier_length` | 88 | 19 | 78.4% |
| `maximum_expression_complexity` | 139 | 37 | 73.4% |
| `maximum_lines` | 0 | 0 | n/a |
| `maximum_out_parameters` | 7 | 0 | 100.0% |
| `maximum_parameters` | 68 | 68 | 0.0% |
| `maximum_subprogram_lines` | 0 | 0 | n/a |
| `membership_for_validity` | 0 | 0 | n/a |
| `membership_tests` | 31 | 15 | 51.6% |
| `metrics_cyclomatic_complexity` | 20 | 19 | 5.0% |
| `metrics_essential_complexity` | 20 | 18 | 10.0% |
| `metrics_lsloc` | 4 | 1 | 75.0% |
| `min_identifier_length` | 205 | 167 | 18.5% |
| `misnamed_controlling_parameters` | 78 | 70 | 10.3% |
| `misplaced_representation_items` | 0 | 0 | n/a |
| `multiple_entries_in_protected_definitions` | 0 | 0 | n/a |
| `nested_paths` | 4 | 2 | 50.0% |
| `nested_subprograms` | 24 | 20 | 16.7% |
| `no_closing_names` | 0 | 0 | n/a |
| `no_explicit_real_range` | 0 | 0 | n/a |
| `no_inherited_classwide_pre` | 13 | 5 | 61.5% |
| `no_scalar_storage_order_specified` | 0 | 0 | n/a |
| `non_component_in_barriers` | 0 | 0 | n/a |
| `non_constant_overlays` | 0 | 0 | n/a |
| `non_qualified_aggregates` | 159 | 40 | 74.8% |
| `non_short_circuit_operators` | 62 | 48 | 22.6% |
| `non_spark_attributes` | 289 | 153 | 47.1% |
| `non_tagged_derived_types` | 5 | 5 | 0.0% |
| `non_visible_exceptions` | 0 | 0 | n/a |
| `nonoverlay_address_specifications` | 1 | 1 | 0.0% |
| `not_imported_overlays` | 0 | 0 | n/a |
| `null_paths` | 0 | 0 | n/a |
| `number_declarations` | 9 | 2 | 77.8% |
| `numeric_format` | 58 | 39 | 32.8% |
| `numeric_indexing` | 24 | 4 | 83.3% |
| `numeric_literals` | 166 | 65 | 60.8% |
| `object_declarations_out_of_order` | 5 | 3 | 40.0% |
| `objects_of_anonymous_types` | 3 | 1 | 66.7% |
| `one_construct_per_line` | 6 | 2 | 66.7% |
| `one_tagged_type_per_package` | 1 | 1 | 0.0% |
| `operator_renamings` | 0 | 0 | n/a |
| `others_in_aggregates` | 0 | 0 | n/a |
| `others_in_case_statements` | 1 | 0 | 100.0% |
| `others_in_exception_handlers` | 6 | 3 | 50.0% |
| `out_parameter_read_in_exception_handler` | 0 | 0 | n/a |
| `outbound_protected_assignments` | 5 | 0 | 100.0% |
| `outer_loop_exits` | 0 | 0 | n/a |
| `outside_references_from_subprograms` | 12 | 2 | 83.3% |
| `overloaded_operators` | 3 | 3 | 0.0% |
| `overly_nested_control_structures` | 1 | 1 | 0.0% |
| `overly_nested_scopes` | 0 | 0 | n/a |
| `overriding_indicators` | 0 | 0 | n/a |
| `parameters_aliasing` | 0 | 0 | n/a |
| `parameters_out_of_order` | 83 | 83 | 0.0% |
| `pos_on_enumeration_types` | 69 | 1 | 98.6% |
| `positional_actuals_for_defaulted_generic_parameters` | 0 | 0 | n/a |
| `positional_actuals_for_defaulted_parameters` | 23 | 14 | 39.1% |
| `positional_components` | 65 | 16 | 75.4% |
| `positional_generic_parameters` | 18 | 18 | 0.0% |
| `positional_parameters` | 534 | 170 | 68.2% |
| `potential_parameters_aliasing` | 0 | 0 | n/a |
| `predefined_numeric_types` | 121 | 58 | 52.1% |
| `predicate_testing` | 0 | 0 | n/a |
| `printable_ascii` | 0 | 0 | n/a |
| `profile_discrepancies` | 10 | 5 | 50.0% |
| `quantified_expressions` | 8 | 8 | 0.0% |
| `raising_external_exceptions` | 0 | 0 | n/a |
| `raising_predefined_exceptions` | 49 | 49 | 0.0% |
| `recursive_subprograms` | 0 | 0 | n/a |
| `redundant_boolean_expressions` | 0 | 0 | n/a |
| `redundant_null_statements` | 0 | 0 | n/a |
| `relative_delay_statements` | 0 | 0 | n/a |
| `renamings` | 14 | 12 | 14.3% |
| `representation_specifications` | 11 | 10 | 9.1% |
| `same_instantiations` | 0 | 0 | n/a |
| `same_logic` | 0 | 0 | n/a |
| `same_operands` | 0 | 0 | n/a |
| `same_tests` | 0 | 0 | n/a |
| `separate_numeric_error_handlers` | 0 | 0 | n/a |
| `separates` | 4 | 4 | 0.0% |
| `silent_exception_handlers` | 9 | 9 | 0.0% |
| `simple_loop_statements` | 12 | 2 | 83.3% |
| `single_value_enumeration_types` | 1 | 0 | 100.0% |
| `size_attribute_for_types` | 1 | 1 | 0.0% |
| `slices` | 23 | 10 | 56.5% |
| `spark_procedures_without_globals` | 5 | 5 | 0.0% |
| `specific_parent_type_invariant` | 0 | 0 | n/a |
| `specific_pre_post` | 0 | 0 | n/a |
| `specific_type_invariants` | 0 | 0 | n/a |
| `style_checks:M` | 4 | 0 | 100.0% |
| `style_checks:b` | 0 | 0 | n/a |
| `subprogram_access` | 4 | 4 | 0.0% |
| `suspicious_equalities` | 0 | 0 | n/a |
| `too_many_dependencies` | 12 | 12 | 0.0% |
| `too_many_generic_dependencies` | 0 | 0 | n/a |
| `too_many_parents` | 0 | 0 | n/a |
| `too_many_primitives` | 9 | 5 | 44.4% |
| `trivial_exception_handlers` | 0 | 0 | n/a |
| `unassigned_out_parameters` | 3 | 0 | 100.0% |
| `unavailable_body_calls` | 31 | 30 | 3.2% |
| `unchecked_address_conversions` | 1 | 1 | 0.0% |
| `unchecked_conversions_as_actuals` | 5 | 5 | 0.0% |
| `uncommented_begin` | 181 | 78 | 56.9% |
| `uncommented_begin_in_package_bodies` | 0 | 0 | n/a |
| `uncommented_end_record` | 0 | 0 | n/a |
| `unconditional_exits` | 4 | 2 | 50.0% |
| `unconstrained_array_returns` | 2 | 2 | 0.0% |
| `unconstrained_arrays` | 2 | 2 | 0.0% |
| `uninitialized_global_variables` | 14 | 4 | 71.4% |
| `universal_ranges` | 15 | 4 | 73.3% |
| `unnamed_blocks_and_loops` | 21 | 15 | 28.6% |
| `unnamed_exits` | 0 | 0 | n/a |
| `use_array_slices` | 2 | 0 | 100.0% |
| `use_case_statements` | 0 | 0 | n/a |
| `use_clauses` | 87 | 42 | 51.7% |
| `use_for_loops` | 2 | 0 | 100.0% |
| `use_for_of_loops` | 2 | 2 | 0.0% |
| `use_if_expressions` | 8 | 4 | 50.0% |
| `use_memberships` | 4 | 0 | 100.0% |
| `use_package_clauses` | 87 | 42 | 51.7% |
| `use_ranges` | 1 | 1 | 0.0% |
| `use_record_aggregates` | 6 | 3 | 50.0% |
| `use_simple_loops` | 0 | 0 | n/a |
| `use_while_loops` | 0 | 0 | n/a |
| `variable_scoping` | 0 | 0 | n/a |
| `visible_components` | 12 | 6 | 50.0% |
| `volatile_objects_without_address_clauses` | 0 | 0 | n/a |
| `warnings:c.always` | 0 | 0 | n/a |
| `warnings:f` | 2 | 0 | 100.0% |
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
- GNATcheck also reports inside the instances of generic units for rules that follow instantiations; AdaLang reports on the generic's own source only.
