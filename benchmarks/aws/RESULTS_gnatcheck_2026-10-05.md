# AWS: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Current results, refreshed 2026-10-05. This file replaces the earlier dated runs, which remain in the Git history. It covers the rule pairs of the 175 opt-in coding-standard checks (158 of them run here; the other 17 report nothing until configured and are not in the rule map), five of them added since the 2026-10-04 run: `Use_Clause`, `Unavailable_Body_Call`, `Deeply_Nested_Inlining`, `Integer_Type_As_Enumeration` and `Same_Instantiation`. The pairs that were already compared on 2026-09-24 are run again; since then the analyzer resolves names through imported projects (`FP-102`) and applies a project's preprocessing switches (`FP-103`), which can change their numbers too.

## Environment

- Corpus: pinned at `02cbd01c2f96c288440415a46bf865616c0ee0f8` (`AWS_REVISION`), unchanged.
- AdaLang Analyzer: 1.8.0.
- GNATcheck: the same from-source build as prior runs; one pass with the plain `-r` rules, then one pass per column-4 option line of `benchmarks/gnatcheck_rule_map.tsv` (`benchmarks/gnatcheck_rule_args.awk`).
- Reproduce: `AWS_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/aws/run_gnatcheck.sh` (see this directory's README for
  any setup step).
- GNATcheck worker crashes ("unparsable worker output"): each GNATcheck invocation was repeated until it finished without a crash; the plain rules were run in batches of at most 25 where one pass over all of them kept crashing. Across the attempts logged for this corpus, 16 invocations were repeated. The accepted log has no crash and no GNATcheck error line. The five rules added on 2026-10-05 were run one rule per invocation and appended to it; the analyzer side was then run again against the whole log.

## Totals

| | 2026-10-05, all pairs | 2026-10-05, pairs of 2026-09-24 | 2026-09-24 |
| --- | ---: | ---: | ---: |
| AdaLang findings | 46732 | 7252 | 6701 |
| &nbsp;&nbsp;matched by GNATcheck | 42950 (91.9%) | 3636 (50.1%) | 3635 (54.2%) |
| GNATcheck findings | 125491 | 12991 | 12991 |
| &nbsp;&nbsp;matched by AdaLang | 42940 (34.2%) | 3626 (27.9%) | 3625 (27.9%) |

Pairs of 2026-09-24 whose numbers changed (findings, tool-only), all others are identical:

- `Exception_Propagation`: 948 findings, 948 AdaLang-only then; 1365, 1365 now.
- `Floating_Equality`: 10 findings, 5 AdaLang-only then; 12, 6 now.
- `Dead_Store`: 42 findings, 42 AdaLang-only then; 47, 47 now.
- `Unused_With_Clause`: 5 findings, 5 AdaLang-only then; 6, 6 now.
- `Uninitialized_Output`: 70 findings, 66 AdaLang-only then; 59, 55 now.
- `Wrong_Parameter_Mode`: 24 findings, 24 AdaLang-only then; 25, 25 now.
- `Missing_Global_Contract`: 827 findings, 827 AdaLang-only then; 963, 963 now.
- `float_equality_checks` (GNATcheck): 17 findings, 12 GNATcheck-only then; 17, 11 now.

## Coding-standard checks

The 158 new pairs, counted over all files: 39480 AdaLang findings, 39314 matched by GNATcheck (99.6%); 112500 GNATcheck findings, 39314 matched by AdaLang (34.9%). 127 of the 158 checks have a finding from one tool or the other on this corpus.

The two tools do not analyse the same set of files (see the notes below), so the same pairs are also counted over the files both analysed: 39480 AdaLang findings and 39520 GNATcheck findings, 39358 at the same file and line; 122 AdaLang-only, 162 GNATcheck-only.

- The largest corpus: 348 files analysed by AdaLang, 888 by GNATcheck (which also analyses the imported `templates_parser`, XML/Ada and related projects).
- In the shared files 39,358 of GNATcheck's 39,520 findings match (37,772 before `FP-102` was fixed).
- GNATcheck-only (162): `Outside_Reference_From_Subprogram` (97), `Positional_Parameter` (26), `Ada_2022_In_Ghost_Code` (17), `Overloaded_Operator` (15), `Unconstrained_Array_Return` (5) and the documented `Declaration_In_Block` divergence (2). Several of these rules follow generic instantiations.
- AdaLang-only (122): `Outside_Reference_From_Subprogram` (88), `Out_Parameter_Read_In_Exception_Handler` (14), `Integer_Type_As_Enumeration` (13: GNATcheck reports none on this corpus; the rule depends on every source it loads, 888 files against AdaLang's 348), `Complex_Inlined_Subprogram` (4), `Global_Variable` (2) and `Use_Case_Statement` (1). Not examined one by one.
- This run found and fixed a defect: `Deriving_From_Predefined_Type` reported types derived from any unit under `Ada`, `System` or `Interfaces`; GNATcheck's rule covers only types declared directly in those four packages.

## Duplicate branches

`Identical_Branches` + `Identical_Case_Alternative`: 14 findings, 10 matched by GNATcheck's `duplicate_branches` (71.4%); `duplicate_branches`: 45 findings, 10 matched (22.2%). With GNATcheck's default thresholds (4 statements / 14 tokens) this pair had 0 GNATcheck findings on every corpus.

## Per AdaLang rule

| AdaLang rule | Match | Findings | AdaLang-only | Matched |
| --- | --- | ---: | ---: | ---: |
| Abstract_Type_Declaration | direct | 28 | 0 | 100.0% |
| Access_To_Local_Object | direct | 68 | 0 | 100.0% |
| Ada05_Formal_Package | direct | 2 | 0 | 100.0% |
| Ada_2022_In_Ghost_Code | direct | 440 | 0 | 100.0% |
| Address_Clause | close | 21 | 6 | 71.4% |
| Address_Of_Non_Volatile_Object | direct | 24 | 0 | 100.0% |
| Aliasing_Between_Parameters | direct | 0 | 0 | n/a |
| Anonymous_Access_Type | direct | 29 | 0 | 100.0% |
| Anonymous_Array_Type | direct | 34 | 0 | 100.0% |
| Anonymous_Subtype | direct | 1121 | 0 | 100.0% |
| Array_Slice | direct | 530 | 0 | 100.0% |
| Binary_Case_Statement | direct | 34 | 0 | 100.0% |
| Bit_Record_Without_Layout | direct | 0 | 0 | n/a |
| Boolean_Relational_Operator | direct | 13 | 0 | 100.0% |
| Complex_Inlined_Subprogram | direct | 92 | 4 | 95.7% |
| Concurrent_Interface | direct | 0 | 0 | n/a |
| Conditional_Expression | direct | 125 | 0 | 100.0% |
| Constant_Condition | close | 3 | 3 | 0.0% |
| Constant_Overlay | direct | 6 | 0 | 100.0% |
| Constructor | direct | 70 | 0 | 100.0% |
| Cyclomatic_Complexity | direct | 88 | 0 | 100.0% |
| Dead_Store | close | 47 | 47 | 0.0% |
| Declaration_In_Block | close | 425 | 0 | 100.0% |
| Deep_Inheritance_Hierarchy | direct | 34 | 0 | 100.0% |
| Deep_Library_Hierarchy | direct | 10 | 0 | 100.0% |
| Deep_Nesting | direct | 49 | 49 | 0.0% |
| Deeply_Nested_Generic | direct | 0 | 0 | n/a |
| Deeply_Nested_Inlining | direct | 0 | 0 | n/a |
| Deeply_Nested_Instantiation | direct | 0 | 0 | n/a |
| Default_Parameter | direct | 899 | 0 | 100.0% |
| Default_Value_For_Record_Component | direct | 175 | 0 | 100.0% |
| Dependency_Limit | direct | 4 | 4 | 0.0% |
| Deriving_From_Predefined_Type | direct | 17 | 0 | 100.0% |
| Direct_Call_To_Primitive | direct | 1828 | 0 | 100.0% |
| Discriminated_Record | direct | 51 | 0 | 100.0% |
| Downward_View_Conversion | direct | 159 | 0 | 100.0% |
| Duplicate_Boolean_Operand | close | 0 | 0 | n/a |
| Duplicate_Condition | direct | 0 | 0 | n/a |
| Duplicate_With_Clause | direct | 0 | 0 | n/a |
| Empty_Else_Body | close | 2 | 2 | 0.0% |
| Empty_Elsif_Body | close | 2 | 2 | 0.0% |
| Empty_Exception_Handler | direct | 21 | 0 | 100.0% |
| Empty_If_Body | close | 0 | 0 | n/a |
| Empty_Then_Body | close | 7 | 7 | 0.0% |
| End_Of_Line_Comment | direct | 228 | 0 | 100.0% |
| Enumeration_Range_In_Case_Statement | direct | 18 | 0 | 100.0% |
| Enumeration_Representation_Clause | direct | 3 | 0 | 100.0% |
| Essential_Complexity | direct | 115 | 0 | 100.0% |
| Exception_As_Control_Flow | direct | 4 | 0 | 100.0% |
| Exception_Propagation | close | 1365 | 1365 | 0.0% |
| Exception_Swallowed | close | 11 | 0 | 100.0% |
| Exit_From_Conditional_Loop | direct | 48 | 0 | 100.0% |
| Exit_Without_Loop_Name | direct | 132 | 0 | 100.0% |
| Expanded_Loop_Exit_Name | direct | 0 | 0 | n/a |
| Explicit_Full_Discrete_Range | direct | 2 | 0 | 100.0% |
| Explicit_Inlining | direct | 461 | 0 | 100.0% |
| Expression_Function | direct | 83 | 0 | 100.0% |
| Final_Package | direct | 0 | 0 | n/a |
| Fixed_Equality | direct | 8 | 0 | 100.0% |
| Floating_Equality | direct | 12 | 6 | 50.0% |
| Function_Out_Parameter | direct | 24 | 0 | 100.0% |
| Function_Style_Procedure | direct | 74 | 0 | 100.0% |
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
| Integer_Type_As_Enumeration | direct | 13 | 13 | 0.0% |
| Library_Level_Initialization | close | 33 | 33 | 0.0% |
| Library_Level_Subprogram | direct | 6 | 0 | 100.0% |
| Local_Instantiation | direct | 97 | 0 | 100.0% |
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
| Misnamed_Controlling_Parameter | direct | 945 | 0 | 100.0% |
| Misplaced_Representation_Item | direct | 12 | 0 | 100.0% |
| Missing_Global_Contract | close | 963 | 963 | 0.0% |
| Missing_Overriding_Indicator | direct | 0 | 0 | n/a |
| Multiple_Protected_Entries | direct | 9 | 0 | 100.0% |
| Naming_Convention | close | 2809 | 370 | 86.8% |
| Nested_Path | direct | 127 | 0 | 100.0% |
| Nested_Subprogram | direct | 616 | 0 | 100.0% |
| No_Abort | direct | 1 | 0 | 100.0% |
| No_Access_To_Subp_Def | direct | 112 | 0 | 100.0% |
| No_Block_Statement | direct | 492 | 0 | 100.0% |
| No_Closing_Name | direct | 0 | 0 | n/a |
| No_Controlled_Type | direct | 20 | 5 | 75.0% |
| No_Explicit_Real_Range | direct | 3 | 0 | 100.0% |
| No_Goto | direct | 0 | 0 | n/a |
| No_Inherited_Classwide_Pre | direct | 245 | 0 | 100.0% |
| No_Multiple_Return | direct | 423 | 423 | 0.0% |
| No_Pragma | close | 290 | 0 | 100.0% |
| No_Recursion | direct | 0 | 0 | n/a |
| No_Scalar_Storage_Order | direct | 2 | 0 | 100.0% |
| No_Use_Package_Clause | direct | 383 | 0 | 100.0% |
| Non_Component_In_Barrier | direct | 0 | 0 | n/a |
| Non_Constant_Overlay | direct | 15 | 0 | 100.0% |
| Non_Qualified_Aggregate | direct | 623 | 0 | 100.0% |
| Non_SPARK_Attribute | direct | 1773 | 0 | 100.0% |
| Non_Short_Circuit_Condition | direct | 6 | 0 | 100.0% |
| Non_Tagged_Derived_Type | direct | 30 | 0 | 100.0% |
| Non_Visible_Exception | direct | 0 | 0 | n/a |
| Nonoverlay_Address_Specification | direct | 0 | 0 | n/a |
| Not_Imported_Overlay | direct | 12 | 0 | 100.0% |
| Null_Case_Alternative | close | 31 | 26 | 16.1% |
| Null_Statement | direct | 0 | 0 | n/a |
| Number_Declaration | direct | 74 | 0 | 100.0% |
| Numeric_Format | direct | 286 | 0 | 100.0% |
| Numeric_Indexing | direct | 322 | 0 | 100.0% |
| Object_Declaration_Out_Of_Order | direct | 24 | 0 | 100.0% |
| Object_Of_Anonymous_Type | direct | 18 | 0 | 100.0% |
| One_Construct_Per_Line | direct | 317 | 0 | 100.0% |
| One_Tagged_Type_Per_Package | direct | 7 | 0 | 100.0% |
| Operator_Renaming | direct | 1 | 0 | 100.0% |
| Others_In_Aggregate | direct | 15 | 0 | 100.0% |
| Others_In_Case_Statement | direct | 52 | 0 | 100.0% |
| Others_In_Exception_Handler | direct | 104 | 0 | 100.0% |
| Out_Parameter_Read_In_Exception_Handler | direct | 58 | 58 | 0.0% |
| Outbound_Protected_Assignment | direct | 48 | 0 | 100.0% |
| Outer_Loop_Exit | direct | 2 | 0 | 100.0% |
| Outside_Reference_From_Subprogram | direct | 1317 | 88 | 93.3% |
| Overloaded_Operator | direct | 30 | 0 | 100.0% |
| Overly_Nested_Scope | direct | 0 | 0 | n/a |
| Overwritten_Assignment | close | 6 | 6 | 0.0% |
| Parameters_Out_Of_Order | direct | 1104 | 0 | 100.0% |
| Pos_On_Enumeration_Type | direct | 41 | 0 | 100.0% |
| Positional_Component | direct | 677 | 0 | 100.0% |
| Positional_Defaulted_Generic_Parameter | direct | 15 | 0 | 100.0% |
| Positional_Defaulted_Parameter | direct | 397 | 0 | 100.0% |
| Positional_Generic_Parameter | direct | 159 | 0 | 100.0% |
| Positional_Parameter | direct | 4312 | 0 | 100.0% |
| Predefined_Numeric_Type | direct | 2195 | 0 | 100.0% |
| Predicate_Testing | direct | 2 | 0 | 100.0% |
| Printable_ASCII | direct | 0 | 0 | n/a |
| Profile_Discrepancy | direct | 47 | 0 | 100.0% |
| Quantified_Expression | direct | 16 | 0 | 100.0% |
| Raising_External_Exception | direct | 34 | 0 | 100.0% |
| Raising_Predefined_Exception | direct | 111 | 0 | 100.0% |
| Redundant_Boolean_Comparison | close | 3 | 0 | 100.0% |
| Redundant_Type_Conversion | close | 2 | 2 | 0.0% |
| Relative_Delay | direct | 16 | 0 | 100.0% |
| Renaming_Declaration | direct | 186 | 0 | 100.0% |
| Representation_Specification | direct | 88 | 0 | 100.0% |
| Same_Instantiation | direct | 0 | 0 | n/a |
| Same_Logic | direct | 1 | 0 | 100.0% |
| Same_Operand | direct | 0 | 0 | n/a |
| Self_Assignment | close | 0 | 0 | n/a |
| Separate_Numeric_Error_Handler | direct | 19 | 0 | 100.0% |
| Separate_Unit | direct | 13 | 0 | 100.0% |
| Single_Value_Enumeration_Type | direct | 1 | 0 | 100.0% |
| Size_Attribute_For_Type | direct | 17 | 0 | 100.0% |
| Specific_Parent_Type_Invariant | direct | 0 | 0 | n/a |
| Specific_Pre_Post | direct | 173 | 0 | 100.0% |
| Specific_Type_Invariant | direct | 0 | 0 | n/a |
| Suspicious_Equality | direct | 0 | 0 | n/a |
| Too_Many_Generic_Dependencies | direct | 0 | 0 | n/a |
| Too_Many_Parameters | direct | 62 | 62 | 0.0% |
| Too_Many_Parents | direct | 0 | 0 | n/a |
| Too_Many_Primitives | direct | 84 | 0 | 100.0% |
| Trailing_Whitespace | direct | 0 | 0 | n/a |
| Unavailable_Body_Call | direct | 43 | 0 | 100.0% |
| Unchecked_Address_Conversion | direct | 0 | 0 | n/a |
| Unchecked_Conversion_As_Actual | direct | 4 | 0 | 100.0% |
| Uncommented_Begin | direct | 1320 | 0 | 100.0% |
| Uncommented_Begin_In_Package_Body | direct | 8 | 0 | 100.0% |
| Uncommented_End_Record | direct | 35 | 0 | 100.0% |
| Unconditional_Exit | direct | 61 | 0 | 100.0% |
| Unconstrained_Array_Return | direct | 575 | 0 | 100.0% |
| Unconstrained_Array_Type | direct | 29 | 0 | 100.0% |
| Uninitialized_Global_Variable | direct | 46 | 0 | 100.0% |
| Uninitialized_Output | close | 59 | 55 | 6.8% |
| Universal_Range | direct | 90 | 0 | 100.0% |
| Unnamed_Block_Or_Loop | direct | 559 | 0 | 100.0% |
| Unnamed_Exit | direct | 0 | 0 | n/a |
| Unused_Parameter | close | 61 | 61 | 0.0% |
| Unused_Variable | close | 9 | 9 | 0.0% |
| Unused_With_Clause | close | 6 | 6 | 0.0% |
| Use_Array_Slice | direct | 1 | 0 | 100.0% |
| Use_Case_Statement | direct | 13 | 1 | 92.3% |
| Use_Clause | direct | 383 | 0 | 100.0% |
| Use_For_Loop | direct | 1 | 0 | 100.0% |
| Use_For_Of_Loop | direct | 27 | 0 | 100.0% |
| Use_If_Expression | direct | 336 | 0 | 100.0% |
| Use_Membership | direct | 0 | 0 | n/a |
| Use_Range | direct | 5 | 0 | 100.0% |
| Use_Record_Aggregate | direct | 10 | 0 | 100.0% |
| Use_Simple_Loop | direct | 0 | 0 | n/a |
| Use_While_Loop | direct | 7 | 0 | 100.0% |
| Variable_Scoping | direct | 8 | 0 | 100.0% |
| Visible_Component | direct | 21 | 0 | 100.0% |
| Volatile_Object_Without_Address | direct | 0 | 0 | n/a |
| Wrong_Parameter_Mode | close | 25 | 25 | 0.0% |

## Per GNATcheck rule

| GNATcheck rule | Findings | GNATcheck-only | Matched |
| --- | ---: | ---: | ---: |
| `abort_statements` | 1 | 0 | 100.0% |
| `abstract_type_declarations` | 75 | 47 | 37.3% |
| `access_to_local_objects` | 92 | 24 | 73.9% |
| `ada05_formal_packages` | 2 | 0 | 100.0% |
| `ada_2022_in_ghost_code` | 471 | 31 | 93.4% |
| `address_attribute_for_non_volatile_objects` | 31 | 7 | 77.4% |
| `address_specifications_for_initialized_objects` | 1 | 0 | 100.0% |
| `address_specifications_for_local_objects` | 27 | 12 | 55.6% |
| `anonymous_access` | 59 | 30 | 49.2% |
| `anonymous_arrays` | 82 | 48 | 41.5% |
| `anonymous_subtypes` | 2760 | 1639 | 40.6% |
| `at_representation_clauses` | 0 | 0 | n/a |
| `binary_case_statements` | 48 | 14 | 70.8% |
| `bit_records_without_layout_definition` | 3 | 3 | 0.0% |
| `blocks` | 787 | 295 | 62.5% |
| `boolean_negations` | 1 | 1 | 0.0% |
| `boolean_relational_operators` | 21 | 8 | 61.9% |
| `calls_outside_elaboration` | 0 | 0 | n/a |
| `complex_inlined_subprograms` | 172 | 84 | 51.2% |
| `concurrent_interfaces` | 0 | 0 | n/a |
| `conditional_expressions` | 193 | 68 | 64.8% |
| `constant_overlays` | 8 | 2 | 75.0% |
| `constructors` | 110 | 40 | 63.6% |
| `controlled_type_declarations` | 170 | 155 | 8.8% |
| `declarations_in_blocks` | 687 | 262 | 61.9% |
| `deep_inheritance_hierarchies` | 37 | 3 | 91.9% |
| `deep_library_hierarchy` | 10 | 0 | 100.0% |
| `deeply_nested_generics` | 0 | 0 | n/a |
| `deeply_nested_inlining` | 0 | 0 | n/a |
| `deeply_nested_instantiations` | 0 | 0 | n/a |
| `default_parameters` | 1694 | 795 | 53.1% |
| `default_values_for_record_components` | 543 | 368 | 32.2% |
| `deriving_from_predefined_type` | 54 | 37 | 31.5% |
| `direct_calls_to_primitives` | 3162 | 1334 | 57.8% |
| `discriminated_records` | 88 | 37 | 58.0% |
| `downward_view_conversions` | 230 | 71 | 69.1% |
| `duplicate_branches` | 45 | 35 | 22.2% |
| `end_of_line_comments` | 882 | 654 | 25.9% |
| `enumeration_ranges_in_case_statements` | 25 | 7 | 72.0% |
| `enumeration_representation_clauses` | 5 | 2 | 60.0% |
| `exception_propagation_from_callbacks` | 0 | 0 | n/a |
| `exception_propagation_from_export` | 4 | 4 | 0.0% |
| `exception_propagation_from_tasks` | 5 | 5 | 0.0% |
| `exceptions_as_control_flow` | 8 | 4 | 50.0% |
| `exit_statements_with_no_loop_name` | 309 | 177 | 42.7% |
| `exits_from_conditional_loops` | 141 | 93 | 34.0% |
| `expanded_loop_exit_names` | 0 | 0 | n/a |
| `explicit_full_discrete_ranges` | 4 | 2 | 50.0% |
| `explicit_inlining` | 724 | 263 | 63.7% |
| `expression_functions` | 130 | 47 | 63.8% |
| `final_package` | 0 | 0 | n/a |
| `fixed_equality_checks` | 12 | 4 | 66.7% |
| `float_equality_checks` | 17 | 11 | 35.3% |
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
| `integer_types_as_enum` | 0 | 0 | n/a |
| `library_level_subprograms` | 9 | 3 | 66.7% |
| `local_instantiations` | 191 | 94 | 50.8% |
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
| `misnamed_controlling_parameters` | 1872 | 927 | 50.5% |
| `misplaced_representation_items` | 14 | 2 | 85.7% |
| `multiple_entries_in_protected_definitions` | 9 | 0 | 100.0% |
| `nested_paths` | 223 | 96 | 57.0% |
| `nested_subprograms` | 972 | 356 | 63.4% |
| `no_closing_names` | 0 | 0 | n/a |
| `no_explicit_real_range` | 4 | 1 | 75.0% |
| `no_inherited_classwide_pre` | 464 | 219 | 52.8% |
| `no_scalar_storage_order_specified` | 4 | 2 | 50.0% |
| `non_component_in_barriers` | 0 | 0 | n/a |
| `non_constant_overlays` | 19 | 4 | 78.9% |
| `non_qualified_aggregates` | 1202 | 579 | 51.8% |
| `non_short_circuit_operators` | 79 | 73 | 7.6% |
| `non_spark_attributes` | 3602 | 1829 | 49.2% |
| `non_tagged_derived_types` | 84 | 54 | 35.7% |
| `non_visible_exceptions` | 1 | 1 | 0.0% |
| `nonoverlay_address_specifications` | 0 | 0 | n/a |
| `not_imported_overlays` | 13 | 1 | 92.3% |
| `null_paths` | 163 | 158 | 3.1% |
| `number_declarations` | 267 | 193 | 27.7% |
| `numeric_format` | 13146 | 12860 | 2.2% |
| `numeric_indexing` | 746 | 424 | 43.2% |
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
| `outside_references_from_subprograms` | 3045 | 1816 | 40.4% |
| `overloaded_operators` | 188 | 158 | 16.0% |
| `overly_nested_control_structures` | 119 | 119 | 0.0% |
| `overly_nested_scopes` | 0 | 0 | n/a |
| `overriding_indicators` | 0 | 0 | n/a |
| `parameters_aliasing` | 11 | 11 | 0.0% |
| `parameters_out_of_order` | 2550 | 1446 | 43.3% |
| `pos_on_enumeration_types` | 129 | 88 | 31.8% |
| `positional_actuals_for_defaulted_generic_parameters` | 26 | 11 | 57.7% |
| `positional_actuals_for_defaulted_parameters` | 818 | 421 | 48.5% |
| `positional_components` | 879 | 202 | 77.0% |
| `positional_generic_parameters` | 386 | 227 | 41.2% |
| `positional_parameters` | 9157 | 4845 | 47.1% |
| `potential_parameters_aliasing` | 0 | 0 | n/a |
| `predefined_numeric_types` | 4363 | 2168 | 50.3% |
| `predicate_testing` | 2 | 0 | 100.0% |
| `printable_ascii` | 250 | 250 | 0.0% |
| `profile_discrepancies` | 143 | 96 | 32.9% |
| `quantified_expressions` | 21 | 5 | 76.2% |
| `raising_external_exceptions` | 153 | 119 | 22.2% |
| `raising_predefined_exceptions` | 146 | 35 | 76.0% |
| `recursive_subprograms` | 0 | 0 | n/a |
| `redundant_boolean_expressions` | 13 | 10 | 23.1% |
| `redundant_null_statements` | 4 | 4 | 0.0% |
| `relative_delay_statements` | 17 | 1 | 94.1% |
| `renamings` | 768 | 582 | 24.2% |
| `representation_specifications` | 276 | 188 | 31.9% |
| `same_instantiations` | 0 | 0 | n/a |
| `same_logic` | 1 | 0 | 100.0% |
| `same_operands` | 0 | 0 | n/a |
| `same_tests` | 0 | 0 | n/a |
| `separate_numeric_error_handlers` | 48 | 29 | 39.6% |
| `separates` | 37 | 24 | 35.1% |
| `silent_exception_handlers` | 239 | 218 | 8.8% |
| `simple_loop_statements` | 204 | 199 | 2.5% |
| `single_value_enumeration_types` | 1 | 0 | 100.0% |
| `size_attribute_for_types` | 26 | 9 | 65.4% |
| `slices` | 1235 | 705 | 42.9% |
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
| `too_many_primitives` | 134 | 50 | 62.7% |
| `trivial_exception_handlers` | 0 | 0 | n/a |
| `unassigned_out_parameters` | 16 | 12 | 25.0% |
| `unavailable_body_calls` | 265 | 222 | 16.2% |
| `unchecked_address_conversions` | 7 | 7 | 0.0% |
| `unchecked_conversions_as_actuals` | 7 | 3 | 57.1% |
| `uncommented_begin` | 2544 | 1224 | 51.9% |
| `uncommented_begin_in_package_bodies` | 16 | 8 | 50.0% |
| `uncommented_end_record` | 84 | 49 | 41.7% |
| `unconditional_exits` | 131 | 70 | 46.6% |
| `unconstrained_array_returns` | 916 | 341 | 62.8% |
| `unconstrained_arrays` | 76 | 47 | 38.2% |
| `uninitialized_global_variables` | 447 | 401 | 10.3% |
| `universal_ranges` | 152 | 62 | 59.2% |
| `unnamed_blocks_and_loops` | 998 | 439 | 56.0% |
| `unnamed_exits` | 0 | 0 | n/a |
| `use_array_slices` | 2 | 1 | 50.0% |
| `use_case_statements` | 46 | 34 | 26.1% |
| `use_clauses` | 981 | 598 | 39.0% |
| `use_for_loops` | 11 | 10 | 9.1% |
| `use_for_of_loops` | 68 | 41 | 39.7% |
| `use_if_expressions` | 648 | 312 | 51.9% |
| `use_memberships` | 9 | 9 | 0.0% |
| `use_package_clauses` | 981 | 598 | 39.0% |
| `use_ranges` | 8 | 3 | 62.5% |
| `use_record_aggregates` | 16 | 6 | 62.5% |
| `use_simple_loops` | 1 | 1 | 0.0% |
| `use_while_loops` | 9 | 2 | 77.8% |
| `variable_scoping` | 24 | 16 | 33.3% |
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
- GNATcheck also reports inside the instances of generic units for rules that follow instantiations; AdaLang reports on the generic's own source only.
