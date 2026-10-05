# Check catalogue audit — 2026-10-05

A stock-take of the 302 checks before any of them is renamed or merged: what each is paired with in GNATcheck, how its name relates to GNATcheck's, and which checks report the same thing. Nothing in the analyzer is changed by this document.

Sources: `-list-checks`, `benchmarks/gnatcheck_rule_map.tsv`, the configuration-paired table of `docs/src/gnatcheck-rule-comparison.md`, and the findings of every check that ran on the ten benchmark corpora (`benchmark-results/`).

## 1. Names against GNATcheck

| Relation of the AdaLang name to the GNATcheck rule name | Checks |
| --- | ---: |
| same name (case and plural aside) | 144 |
| no GNATcheck counterpart | 78 |
| different wording | 61 |
| paired through a `warnings:` or `style_checks:` letter | 12 |
| AdaLang says `No_X`, GNATcheck names the construct | 7 |
| **Total** | **302** |

No AdaLang check can be selected by its GNATcheck name today, and `-list-checks` does not show it. A GNATcheck user has to look each rule up in the comparison document.

The checks whose wording differs from GNATcheck's:

| AdaLang check | GNATcheck rule |
| --- | --- |
| `No_Goto` | `goto_statements` |
| `No_Abort` | `abort_statements` |
| `No_Pragma` | `forbidden_pragmas` |
| `No_Access_To_Subp_Def` | `subprogram_access` |
| `Floating_Equality` | `float_equality_checks` |
| `Magic_Number` | `numeric_literals` |
| `Infinite_Loop` | `simple_loop_statements` |
| `Duplicate_Boolean_Operand` | `same_operands`, `redundant_boolean_expressions` |
| `Exception_Swallowed` | `silent_exception_handlers`, `trivial_exception_handlers` |
| `Cyclomatic_Complexity` | `metrics_cyclomatic_complexity` |
| `Duplicate_Condition` | `same_tests` |
| `Null_Statement` | `redundant_null_statements` |
| `Empty_Exception_Handler` | `silent_exception_handlers` |
| `Identical_Branches` | `duplicate_branches` |
| `No_Recursion` | `recursive_subprograms` |
| `No_Multiple_Return` | `improper_returns` |
| `Non_Short_Circuit_Condition` | `non_short_circuit_operators` |
| `Address_Clause` | `at_representation_clauses`, `address_specifications_for_initialized_objects`, `address_specifications_for_local_objects` |
| `Too_Many_Parameters` | `maximum_parameters` |
| `Deep_Nesting` | `overly_nested_control_structures` |
| `Empty_If_Body` | `null_paths` |
| `Empty_Elsif_Body` | `null_paths` |
| `Empty_Then_Body` | `null_paths` |
| `Empty_Else_Body` | `null_paths` |
| `Null_Case_Alternative` | `null_paths` |
| `Redundant_Boolean_Comparison` | `redundant_boolean_expressions`, `boolean_negations` |
| `Missing_Global_Contract` | `spark_procedures_without_globals` |
| `Uninitialized_Output` | `unassigned_out_parameters` |
| `Missing_Overriding_Indicator` | `overriding_indicators` |
| `Identical_Case_Alternative` | `duplicate_branches` |
| `Aliasing_Between_Parameters` | `parameters_aliasing`, `potential_parameters_aliasing` |
| `Exception_Propagation` | `exception_propagation_from_callbacks`, `exception_propagation_from_export`, `exception_propagation_from_tasks` |
| `No_Controlled_Type` | `controlled_type_declarations` |
| `Library_Level_Initialization` | `calls_outside_elaboration` |
| `Dependency_Limit` | `too_many_dependencies` |
| `Naming_Convention` | `min_identifier_length` |
| `No_Use_Package_Clause` | `use_package_clauses` |
| `Unnamed_Block_Or_Loop` | `unnamed_blocks_and_loops` |
| `Implicit_In_Mode` | `implicit_in_mode_parameters` |
| `Anonymous_Array_Type` | `anonymous_arrays` |
| `Relative_Delay` | `relative_delay_statements` |
| `No_Block_Statement` | `blocks` |
| `Multiple_Protected_Entries` | `multiple_entries_in_protected_definitions` |
| `Unconstrained_Array_Type` | `unconstrained_arrays` |
| `Anonymous_Access_Type` | `anonymous_access` |
| `Renaming_Declaration` | `renamings` |
| `Separate_Unit` | `separates` |
| `Array_Slice` | `slices` |
| `Exit_Without_Loop_Name` | `exit_statements_with_no_loop_name` |
| `Missing_Header` | `headers` |
| `Maximum_Identifier_Length` | `max_identifier_length` |
| `Forbidden_Identifier` | `name_clashes` |
| `Logical_SLOC` | `metrics_lsloc` |
| `Positional_Defaulted_Parameter` | `positional_actuals_for_defaulted_parameters` |
| `Fixed_Equality` | `fixed_equality_checks` |
| `Implicit_Small` | `implicit_small_for_fixed_point_types` |
| `Forbidden_Dependence` | `no_dependence` |
| `Missing_Others_Handler` | `no_others_in_exception_handlers` |
| `Volatile_Object_Without_Address` | `volatile_objects_without_address_clauses` |
| `Address_Of_Non_Volatile_Object` | `address_attribute_for_non_volatile_objects` |
| `Bit_Record_Without_Layout` | `bit_records_without_layout_definition` |
| `No_Scalar_Storage_Order` | `no_scalar_storage_order_specified` |
| `Positional_Defaulted_Generic_Parameter` | `positional_actuals_for_defaulted_generic_parameters` |
| `Essential_Complexity` | `metrics_essential_complexity` |
| `Integer_Type_As_Enumeration` | `integer_types_as_enum` |
| `Compiler_Warning` | `warnings` |
| `Compiler_Style_Check` | `style_checks` |
| `Compiler_Restriction` | `restrictions` |

## 2. One GNATcheck rule, several AdaLang checks

GNATcheck reports these with one rule; AdaLang splits them. Enabling the GNATcheck rule's equivalent means enabling all of them.

| GNATcheck rule | AdaLang checks |
| --- | --- |
| `null_paths` | `Empty_If_Body`, `Empty_Elsif_Body`, `Empty_Then_Body`, `Empty_Else_Body`, `Null_Case_Alternative` |
| `same_operands` | `Duplicate_Boolean_Operand`, `Same_Operand` |
| `redundant_boolean_expressions` | `Duplicate_Boolean_Operand`, `Redundant_Boolean_Comparison` |
| `silent_exception_handlers` | `Exception_Swallowed`, `Empty_Exception_Handler` |
| `duplicate_branches` | `Identical_Branches`, `Identical_Case_Alternative` |

## 3. One AdaLang check, several GNATcheck rules

| AdaLang check | GNATcheck rules |
| --- | --- |
| `Duplicate_Boolean_Operand` | `same_operands`, `redundant_boolean_expressions` |
| `Exception_Swallowed` | `silent_exception_handlers`, `trivial_exception_handlers` |
| `Address_Clause` | `at_representation_clauses`, `address_specifications_for_initialized_objects`, `address_specifications_for_local_objects` |
| `Redundant_Boolean_Comparison` | `redundant_boolean_expressions`, `boolean_negations` |
| `Aliasing_Between_Parameters` | `parameters_aliasing`, `potential_parameters_aliasing` |
| `Exception_Propagation` | `exception_propagation_from_callbacks`, `exception_propagation_from_export`, `exception_propagation_from_tasks` |

## 4. Checks that report on the same lines

Measured on the ten corpora: pairs where at least 90% of the findings of the rarer check are on a line where the other check also reports (five lines or more). "Both ways" is the share of the *more frequent* check's findings that coincide too: near 100% means the two checks are the same check on this code; a low figure means one is a special case of the other.

| Check | Check | Lines in common | Both ways | Where the overlap comes from |
| --- | --- | ---: | ---: | --- |
| `No_Use_Package_Clause` (907) | `Use_Clause` (927) | 907 | 98% | both tools: GNATcheck has two rules here too |
| `Declaration_In_Block` (789) | `No_Block_Statement` (886) | 789 | 89% | both tools: GNATcheck has two rules here too |
| `Incomplete_Representation_Specification` (25) | `No_Scalar_Storage_Order` (22) | 21 | 84% | both tools: GNATcheck has two rules here too |
| `No_Block_Statement` (886) | `Unnamed_Block_Or_Loop` (1120) | 845 | 75% | both tools: GNATcheck has two rules here too |
| `Empty_Exception_Handler` (44) | `Exception_Swallowed` (32) | 32 | 73% | AdaLang only: both map to the same GNATcheck rule |
| `Declaration_In_Block` (789) | `Unnamed_Block_Or_Loop` (1120) | 751 | 67% | both tools: GNATcheck has two rules here too |
| `Explicit_Full_Discrete_Range` (28) | `Use_Range` (43) | 28 | 65% | both tools: GNATcheck has two rules here too |
| `Non_Constant_Overlay` (19) | `Not_Imported_Overlay` (13) | 12 | 63% | both tools: GNATcheck has two rules here too |
| `Address_Of_Non_Volatile_Object` (31) | `Non_Constant_Overlay` (19) | 19 | 61% | both tools: GNATcheck has two rules here too |
| `Deriving_From_Predefined_Type` (47) | `Non_Tagged_Derived_Type` (91) | 47 | 52% | both tools: GNATcheck has two rules here too |
| `Address_Clause` (37) | `Non_Constant_Overlay` (19) | 19 | 51% | both tools: GNATcheck has two rules here too |
| `Anonymous_Subtype` (3515) | `Array_Slice` (1610) | 1535 | 44% | both tools: GNATcheck has two rules here too |
| `Improperly_Located_Instantiation` (439) | `Local_Instantiation` (181) | 179 | 41% | both tools: GNATcheck has two rules here too |
| `Address_Of_Non_Volatile_Object` (31) | `Not_Imported_Overlay` (13) | 12 | 39% | both tools: GNATcheck has two rules here too |
| `Address_Clause` (37) | `Not_Imported_Overlay` (13) | 13 | 35% | both tools: GNATcheck has two rules here too |
| `No_Raise` (575) | `Raising_Predefined_Exception` (157) | 157 | 27% | AdaLang only: one of the two has no GNATcheck rule |
| `Multiple_Protected_Entries` (10) | `No_Rendezvous` (39) | 9 | 23% | AdaLang only: one of the two has no GNATcheck rule |
| `Address_Clause` (37) | `Nonoverlay_Address_Specification` (8) | 8 | 22% | both tools: GNATcheck has two rules here too |
| `Address_Clause` (37) | `Constant_Overlay` (8) | 8 | 22% | both tools: GNATcheck has two rules here too |
| `No_Raise` (575) | `Raising_External_Exception` (110) | 110 | 19% | AdaLang only: one of the two has no GNATcheck rule |
| `Local_Instantiation` (181) | `Nested_Subprogram` (1063) | 168 | 16% | both tools: GNATcheck has two rules here too |
| `No_Classwide_Type` (739) | `Non_SPARK_Attribute` (4898) | 739 | 15% | AdaLang only: one of the two has no GNATcheck rule |
| `Exception_Swallowed` (32) | `Others_In_Exception_Handler` (233) | 32 | 14% | both tools: GNATcheck has two rules here too |
| `No_Unchecked_Conversion` (56) | `Unchecked_Address_Conversion` (6) | 6 | 11% | AdaLang only: one of the two has no GNATcheck rule |
| `Enumeration_Representation_Clause` (40) | `Representation_Specification` (382) | 40 | 10% | both tools: GNATcheck has two rules here too |
| `No_Compiler_Extensions` (277) | `No_Pragma` (3141) | 277 | 9% | AdaLang only: one of the two has no GNATcheck rule |
| `Boolean_Relational_Operator` (219) | `Redundant_Boolean_Comparison` (18) | 18 | 8% | both tools: GNATcheck has two rules here too |
| `Positional_Defaulted_Generic_Parameter` (25) | `Positional_Generic_Parameter` (326) | 25 | 8% | both tools: GNATcheck has two rules here too |
| `Exit_From_Conditional_Loop` (193) | `Outer_Loop_Exit` (13) | 12 | 6% | both tools: GNATcheck has two rules here too |
| `Positional_Defaulted_Parameter` (641) | `Positional_Parameter` (10475) | 630 | 6% | both tools: GNATcheck has two rules here too |
| `Membership_For_Validity` (40) | `Membership_Test` (670) | 40 | 6% | both tools: GNATcheck has two rules here too |
| `Anonymous_Subtype` (3515) | `Universal_Range` (207) | 207 | 6% | both tools: GNATcheck has two rules here too |
| `Implicit_In_Mode` (16391) | `Swappable_Parameters` (824) | 797 | 5% | AdaLang only: one of the two has no GNATcheck rule |
| `Membership_Test` (670) | `Predicate_Testing` (16) | 16 | 2% | both tools: GNATcheck has two rules here too |
| `Anonymous_Subtype` (3515) | `Use_For_Of_Loop` (71) | 71 | 2% | both tools: GNATcheck has two rules here too |
| `Access_To_Local_Object` (77) | `Non_SPARK_Attribute` (4898) | 77 | 2% | both tools: GNATcheck has two rules here too |
| `Anonymous_Subtype` (3515) | `Use_Range` (43) | 43 | 1% | both tools: GNATcheck has two rules here too |
| `Misnamed_Controlling_Parameter` (1606) | `Missing_Overriding_Indicator` (19) | 19 | 1% | both tools: GNATcheck has two rules here too |
| `No_Unchecked_Access` (49) | `Non_SPARK_Attribute` (4898) | 49 | 1% | AdaLang only: one of the two has no GNATcheck rule |
| `Anonymous_Subtype` (3515) | `Explicit_Full_Discrete_Range` (28) | 28 | 1% | both tools: GNATcheck has two rules here too |
| `Address_Clause` (37) | `Non_SPARK_Attribute` (4898) | 37 | 1% | both tools: GNATcheck has two rules here too |
| `Address_Of_Non_Volatile_Object` (31) | `Non_SPARK_Attribute` (4898) | 31 | 1% | both tools: GNATcheck has two rules here too |
| `Uncommented_Begin` (3061) | `Uncommented_Begin_In_Package_Body` (16) | 16 | 1% | both tools: GNATcheck has two rules here too |
| `No_Pragma` (3141) | `No_Runtime_Check_Suppression` (15) | 15 | 0% | AdaLang only: one of the two has no GNATcheck rule |
| `Non_Constant_Overlay` (19) | `Non_SPARK_Attribute` (4898) | 19 | 0% | both tools: GNATcheck has two rules here too |
| `Non_SPARK_Attribute` (4898) | `Not_Imported_Overlay` (13) | 13 | 0% | both tools: GNATcheck has two rules here too |
| `Non_SPARK_Attribute` (4898) | `Nonoverlay_Address_Specification` (8) | 8 | 0% | both tools: GNATcheck has two rules here too |
| `Constant_Overlay` (8) | `Non_SPARK_Attribute` (4898) | 8 | 0% | both tools: GNATcheck has two rules here too |

48 pairs; 10 of them are AdaLang's own, the rest mirror overlaps between GNATcheck's rules. 1 pairs coincide in both directions on 90% or more of their findings.

## 5. Naming patterns inside the catalogue

First word of the check name, where five or more checks share it:

| First word | Checks |
| --- | ---: |
| `No_…` | 30 |
| `Use_…` | 12 |
| `Known_…` | 11 |
| `Non_…` | 7 |
| `Missing_…` | 7 |
| `Redundant_…` | 6 |
| `Empty_…` | 6 |
| `Duplicate_…` | 5 |
| `Maximum_…` | 5 |
| `Positional_…` | 5 |

How the descriptions begin (`-list-checks`):

| First word | Checks |
| --- | ---: |
| Find | 292 |
| Avoid | 7 |
| Report | 3 |

Quality and severity:

| Quality | Severity | Checks |
| --- | --- | ---: |
| Maintainability | High | 2 |
| Maintainability | Low | 123 |
| Maintainability | Medium | 39 |
| Reliability | Blocker | 2 |
| Reliability | High | 54 |
| Reliability | Low | 10 |
| Reliability | Medium | 64 |
| Security | High | 7 |
| Security | Medium | 1 |

100 checks belong to at least one preset; 202 can only be selected by name. 223 checks produced a finding on the corpora.

## 6. Every check

| Check | Quality / severity | Presets | GNATcheck | Findings on the corpora |
| --- | --- | --- | --- | ---: |
| `No_Goto` | Maintainability / Medium | automotive,spark,verify | `goto_statements` | 138 |
| `No_Abort` | Reliability / High | automotive,spark,verify | `abort_statements` | 1 |
| `No_Raise` | Maintainability / Low | automotive,spark,verify | — | 575 |
| `No_Exit` | Maintainability / Low | - | — | 0 |
| `No_Label` | Maintainability / Low | automotive | — | 0 |
| `No_Pragma` | Maintainability / Low | - | `forbidden_pragmas` | 3141 |
| `No_Access_To_Subp_Def` | Maintainability / Medium | automotive,spark,verify | `subprogram_access` | 152 |
| `No_Unchecked_Conversion` | Security / High | automotive,spark,verify | — | 56 |
| `No_Unchecked_Access` | Security / High | automotive,spark,verify | — | 49 |
| `Floating_Equality` | Reliability / Medium | automotive,spark,verify | `float_equality_checks` | 52 |
| `Magic_Number` | Maintainability / Low | automotive | `numeric_literals` | 5123 |
| `Unused_Parameter` | Maintainability / Low | recommended | `warnings:f` | 94 |
| `Wrong_Parameter_Mode` | Maintainability / Medium | recommended | `warnings:k.mode` | 79 |
| `Dead_Store` | Maintainability / Medium | automotive,recommended,spark,verify | `warnings:m.never` | 199 |
| `Overwritten_Assignment` | Reliability / Medium | automotive,recommended,spark,verify | `warnings:m.overwritten` | 9 |
| `Shadowed_Declaration` | Reliability / Medium | automotive | — | 478 |
| `Unreachable_Case_Alternative` | Reliability / Medium | automotive,recommended | — | 0 |
| `Overlapping_Case_Ranges` | Reliability / High | automotive,recommended | — | 0 |
| `Infinite_Loop` | Reliability / High | automotive,recommended,spark,verify | `simple_loop_statements` | 18 |
| `Duplicate_Boolean_Operand` | Reliability / Medium | recommended | `same_operands`, `redundant_boolean_expressions` | 0 |
| `Redundant_Abs` | Maintainability / Low | - | — | 0 |
| `Redundant_Unary_Minus` | Maintainability / Low | - | — | 0 |
| `Exception_Swallowed` | Reliability / High | automotive,recommended | `silent_exception_handlers`, `trivial_exception_handlers` | 32 |
| `Cyclomatic_Complexity` | Maintainability / Medium | automotive | `metrics_cyclomatic_complexity` | 198 |
| `Constant_Condition` | Reliability / Medium | automotive,recommended,spark,verify | `warnings:c.always` | 13 |
| `Unreachable_Code` | Maintainability / Medium | automotive,recommended,spark,verify | — | 12 |
| `Division_By_Zero` | Reliability / Blocker | automotive,recommended,spark,verify | — | 0 |
| `Integer_Division_Before_Multiplication` | Reliability / Medium | - | — | 0 |
| `Excessive_Shift_Amount` | Reliability / High | - | — | 0 |
| `Known_Negative_Shift_Amount_Failure` | Reliability / High | - | — | 0 |
| `Known_Negative_Exponent_Failure` | Reliability / High | - | — | 0 |
| `Succ_Pred_Boundary_Overflow` | Reliability / Blocker | - | — | 0 |
| `Reversed_Range` | Reliability / Medium | automotive,recommended,spark,verify | — | 0 |
| `Self_Assignment` | Reliability / Medium | automotive,recommended,spark,verify | `warnings:r.self` | 0 |
| `Same_Operand` | Reliability / Medium | recommended | `same_operands` | 0 |
| `Duplicate_Condition` | Reliability / Medium | recommended | `same_tests` | 0 |
| `Duplicate_With_Clause` | Maintainability / Low | - | `warnings:r.with` | 0 |
| `Duplicate_Exception_Choice` | Maintainability / Low | - | — | 0 |
| `Null_Statement` | Maintainability / Low | - | `redundant_null_statements` | 5 |
| `Redundant_Final_Return` | Maintainability / Low | - | — | 0 |
| `Empty_Exception_Handler` | Reliability / High | recommended | `silent_exception_handlers` | 44 |
| `Unreachable_Branch` | Reliability / Medium | automotive,recommended | — | 0 |
| `Contradictory_Condition` | Reliability / High | automotive,recommended,spark,verify | — | 0 |
| `Contradictory_Range_Condition` | Reliability / High | - | — | 0 |
| `Identical_Branches` | Reliability / Medium | recommended | `duplicate_branches` | 20 |
| `Repeated_Statement` | Reliability / Medium | recommended | — | 1 |
| `Ineffective_Operation` | Maintainability / Low | recommended | — | 2 |
| `Constant_Result_Operation` | Reliability / Medium | recommended | — | 1 |
| `Empty_Loop` | Reliability / Medium | recommended | — | 46 |
| `No_Recursion` | Reliability / High | automotive,spark,verify | `recursive_subprograms` | 211 |
| `No_Multiple_Return` | Maintainability / Low | automotive | `improper_returns` | 877 |
| `Non_Short_Circuit_Condition` | Reliability / High | automotive,spark,verify | `non_short_circuit_operators` | 198 |
| `Address_Clause` | Security / High | automotive,spark,verify | `at_representation_clauses`, `address_specifications_for_initialized_objects`, `address_specifications_for_local_objects` | 37 |
| `Too_Many_Parameters` | Maintainability / Medium | - | `maximum_parameters` | 126 |
| `Swappable_Parameters` | Reliability / Medium | recommended | — | 824 |
| `Deep_Nesting` | Maintainability / Medium | automotive | `overly_nested_control_structures` | 92 |
| `Unused_Variable` | Maintainability / Low | recommended | `warnings:u.object` | 15 |
| `Empty_If_Body` | Maintainability / Low | recommended | `null_paths` | 1 |
| `Empty_Elsif_Body` | Maintainability / Low | recommended | `null_paths` | 7 |
| `Empty_Then_Body` | Maintainability / Low | recommended | `null_paths` | 18 |
| `Empty_Else_Body` | Maintainability / Low | recommended | `null_paths` | 5 |
| `Null_Case_Alternative` | Maintainability / Low | recommended | `null_paths` | 53 |
| `Unnecessary_Else_After_Return` | Maintainability / Low | - | — | 0 |
| `Redundant_If_Boolean_Return` | Maintainability / Low | - | — | 0 |
| `Function_Side_Effect` | Reliability / High | automotive,recommended,spark,verify | — | 44 |
| `Redundant_Boolean_Comparison` | Maintainability / Low | recommended | `redundant_boolean_expressions`, `boolean_negations` | 18 |
| `Long_Line` | Maintainability / Low | - | `style_checks:M` | 826 |
| `Trailing_Whitespace` | Maintainability / Low | - | `style_checks:b` | 0 |
| `SPARK_Mode` | Reliability / High | automotive,spark,verify | — | 3 |
| `Missing_Global_Contract` | Maintainability / Medium | automotive,spark,verify | `spark_procedures_without_globals` | 1498 |
| `Global_Contract_Mismatch` | Reliability / High | automotive,spark,verify | — | 7 |
| `Missing_Depends_Contract` | Maintainability / Medium | automotive,spark,verify | — | 1526 |
| `Incomplete_Depends_Contract` | Reliability / High | automotive,spark,verify | — | 0 |
| `Depends_Contract_Mismatch` | Reliability / High | automotive,spark,verify | — | 0 |
| `Uninitialized_Output` | Reliability / High | automotive,recommended,spark,verify | `unassigned_out_parameters` | 139 |
| `Uninitialized_Read` | Reliability / High | automotive,recommended | — | 16 |
| `Missing_Overriding_Indicator` | Maintainability / Medium | automotive | `overriding_indicators` | 19 |
| `Inefficient_String_Concatenation` | Reliability / Medium | - | — | 0 |
| `Circular_Package_Dependency` | Maintainability / Medium | automotive | — | 0 |
| `Duplicate_Subprogram` | Maintainability / Medium | recommended | — | 232 |
| `Known_Precondition_Failure` | Reliability / High | automotive,recommended,spark,verify | — | 0 |
| `Known_Postcondition_Failure` | Reliability / High | automotive,recommended,spark,verify | — | 0 |
| `Known_Assertion_Failure` | Reliability / High | automotive,recommended,spark,verify | — | 1 |
| `Assertion_Side_Effect` | Reliability / Medium | - | — | 0 |
| `Entry_Barrier_Side_Effect` | Reliability / Medium | - | — | 0 |
| `Known_Range_Check_Failure` | Reliability / High | automotive,recommended,spark,verify | — | 0 |
| `Known_Index_Check_Failure` | Reliability / High | automotive,recommended,spark,verify | — | 0 |
| `Known_Overflow_Failure` | Reliability / High | automotive,recommended,spark,verify | — | 0 |
| `Identical_Case_Alternative` | Reliability / Medium | recommended | `duplicate_branches` | 30 |
| `Redundant_Type_Conversion` | Maintainability / Low | automotive,recommended | `warnings:r.conversion` | 27 |
| `Handler_Order` | Reliability / High | recommended | — | 0 |
| `Reraise_Discards_Occurrence` | Reliability / Medium | - | — | 0 |
| `Aliasing_Between_Parameters` | Reliability / High | automotive,recommended,spark,verify | `parameters_aliasing`, `potential_parameters_aliasing` | 1 |
| `Missing_Loop_Variant` | Maintainability / Medium | automotive,spark,verify | — | 0 |
| `Known_Discriminant_Check_Failure` | Reliability / High | automotive,recommended,spark,verify | — | 0 |
| `Known_Enum_Val_Failure` | Reliability / High | - | — | 0 |
| `Known_Value_Conversion_Failure` | Reliability / High | - | — | 0 |
| `Potentially_Blocking_Operation` | Reliability / High | automotive,spark,verify | — | 22 |
| `No_Dynamic_Allocation` | Reliability / High | automotive | — | 224 |
| `Restricted_Access_Type` | Reliability / High | automotive | — | 387 |
| `No_Explicit_Dereference` | Reliability / High | automotive | — | 605 |
| `No_Unchecked_Deallocation` | Security / High | automotive | — | 64 |
| `No_Tasking` | Reliability / High | automotive | — | 11 |
| `No_Rendezvous` | Reliability / High | automotive | — | 39 |
| `No_Select` | Reliability / High | automotive | — | 9 |
| `No_Requeue` | Reliability / High | automotive | — | 4 |
| `No_Asynchronous_Transfer` | Reliability / High | automotive | — | 0 |
| `Exception_Propagation` | Reliability / High | automotive | `exception_propagation_from_callbacks`, `exception_propagation_from_export`, `exception_propagation_from_tasks` | 2035 |
| `No_Dispatching_Call` | Reliability / High | automotive | — | 1128 |
| `No_Classwide_Type` | Reliability / High | automotive | — | 739 |
| `No_Controlled_Type` | Reliability / High | automotive | `controlled_type_declarations` | 34 |
| `Complete_Initialization` | Reliability / High | automotive | — | 2467 |
| `Volatile_Atomic_Consistency` | Reliability / High | automotive | — | 8 |
| `Representation_Clause_Policy` | Reliability / Medium | automotive | — | 67 |
| `Library_Level_Initialization` | Reliability / High | automotive | `calls_outside_elaboration` | 71 |
| `Generic_Instantiation_Limit` | Maintainability / Medium | automotive | — | 2 |
| `Dependency_Limit` | Maintainability / Medium | automotive | `too_many_dependencies` | 4 |
| `Naming_Convention` | Maintainability / Low | automotive | `min_identifier_length` | 4482 |
| `No_Compiler_Extensions` | Maintainability / High | automotive | — | 277 |
| `No_Runtime_Check_Suppression` | Reliability / High | automotive | — | 15 |
| `Missing_Requirement_Trace` | Reliability / High | - | — | 0 |
| `Malformed_Requirement_Trace` | Maintainability / Medium | - | — | 0 |
| `Suppression_Without_Rationale` | Maintainability / High | automotive | — | 0 |
| `Use_After_Free` | Security / High | recommended | — | 14 |
| `Double_Free` | Security / High | recommended | — | 8 |
| `Unclosed_File_Handle` | Reliability / Medium | recommended | — | 1 |
| `Unused_With_Clause` | Maintainability / Low | recommended | `warnings:u.unit` | 95 |
| `No_Use_Package_Clause` | Maintainability / Low | - | `use_package_clauses` | 907 |
| `Others_In_Case_Statement` | Reliability / Low | - | `others_in_case_statements` | 96 |
| `Others_In_Exception_Handler` | Reliability / Medium | - | `others_in_exception_handlers` | 233 |
| `Others_In_Aggregate` | Reliability / Low | - | `others_in_aggregates` | 76 |
| `Unnamed_Exit` | Maintainability / Low | - | `unnamed_exits` | 0 |
| `Unnamed_Block_Or_Loop` | Maintainability / Low | - | `unnamed_blocks_and_loops` | 1120 |
| `Implicit_In_Mode` | Maintainability / Low | - | `implicit_in_mode_parameters` | 16391 |
| `Function_Out_Parameter` | Reliability / Medium | - | `function_out_parameters` | 114 |
| `Raising_Predefined_Exception` | Reliability / Medium | - | `raising_predefined_exceptions` | 157 |
| `Anonymous_Array_Type` | Maintainability / Low | - | `anonymous_arrays` | 64 |
| `Enumeration_Representation_Clause` | Maintainability / Low | - | `enumeration_representation_clauses` | 40 |
| `Relative_Delay` | Reliability / Medium | - | `relative_delay_statements` | 17 |
| `No_Block_Statement` | Maintainability / Low | - | `blocks` | 886 |
| `Global_Variable` | Maintainability / Medium | - | `global_variables` | 45 |
| `Predefined_Numeric_Type` | Reliability / Medium | - | `predefined_numeric_types` | 5088 |
| `Abstract_Type_Declaration` | Maintainability / Low | - | `abstract_type_declarations` | 57 |
| `Exit_From_Conditional_Loop` | Maintainability / Low | - | `exits_from_conditional_loops` | 193 |
| `Expanded_Loop_Exit_Name` | Maintainability / Low | - | `expanded_loop_exit_names` | 0 |
| `Conditional_Expression` | Maintainability / Low | - | `conditional_expressions` | 975 |
| `Quantified_Expression` | Maintainability / Low | - | `quantified_expressions` | 340 |
| `Membership_Test` | Maintainability / Low | - | `membership_tests` | 670 |
| `Generic_In_Out_Object` | Reliability / Medium | - | `generic_in_out_objects` | 7 |
| `Generic_In_Subprogram` | Maintainability / Low | - | `generics_in_subprograms` | 0 |
| `Local_Use_Clause` | Maintainability / Low | - | `local_use_clauses` | 993 |
| `Library_Level_Subprogram` | Maintainability / Low | - | `library_level_subprograms` | 17 |
| `Multiple_Protected_Entries` | Reliability / Medium | - | `multiple_entries_in_protected_definitions` | 10 |
| `Non_Tagged_Derived_Type` | Maintainability / Low | - | `non_tagged_derived_types` | 91 |
| `No_Closing_Name` | Maintainability / Low | - | `no_closing_names` | 1 |
| `Operator_Renaming` | Maintainability / Low | - | `operator_renamings` | 2 |
| `Overloaded_Operator` | Maintainability / Low | - | `overloaded_operators` | 92 |
| `Single_Value_Enumeration_Type` | Maintainability / Low | - | `single_value_enumeration_types` | 6 |
| `Unconstrained_Array_Type` | Reliability / Low | - | `unconstrained_arrays` | 79 |
| `Unconditional_Exit` | Maintainability / Low | - | `unconditional_exits` | 152 |
| `Binary_Case_Statement` | Maintainability / Low | - | `binary_case_statements` | 107 |
| `Concurrent_Interface` | Maintainability / Low | - | `concurrent_interfaces` | 0 |
| `Anonymous_Access_Type` | Reliability / Medium | - | `anonymous_access` | 39 |
| `Renaming_Declaration` | Maintainability / Low | - | `renamings` | 365 |
| `Separate_Unit` | Maintainability / Low | - | `separates` | 49 |
| `Array_Slice` | Maintainability / Low | - | `slices` | 1610 |
| `Number_Declaration` | Maintainability / Low | - | `number_declarations` | 255 |
| `Local_Package` | Maintainability / Low | - | `local_packages` | 11 |
| `Declaration_In_Block` | Maintainability / Low | - | `declarations_in_blocks` | 789 |
| `Outer_Loop_Exit` | Maintainability / Medium | - | `outer_loop_exits` | 13 |
| `Exit_Without_Loop_Name` | Maintainability / Low | - | `exit_statements_with_no_loop_name` | 332 |
| `Expression_Function` | Maintainability / Low | - | `expression_functions` | 795 |
| `Size_Attribute_For_Type` | Reliability / Medium | - | `size_attribute_for_types` | 219 |
| `Enumeration_Range_In_Case_Statement` | Reliability / Low | - | `enumeration_ranges_in_case_statements` | 23 |
| `Missing_Header` | Maintainability / Low | - | `headers` | 0 |
| `Lowercase_Keyword` | Maintainability / Low | - | `lowercase_keywords` | 5 |
| `Printable_ASCII` | Maintainability / Low | - | `printable_ascii` | 11 |
| `End_Of_Line_Comment` | Maintainability / Low | - | `end_of_line_comments` | 836 |
| `Annotated_Comment` | Maintainability / Low | - | `annotated_comments` | 0 |
| `Maximum_Lines` | Maintainability / Medium | - | `maximum_lines` | 0 |
| `Maximum_Identifier_Length` | Maintainability / Low | - | `max_identifier_length` | 2189 |
| `Numeric_Format` | Maintainability / Low | - | `numeric_format` | 773 |
| `Parameters_Out_Of_Order` | Maintainability / Low | - | `parameters_out_of_order` | 3037 |
| `Maximum_Subprogram_Lines` | Maintainability / Medium | - | `maximum_subprogram_lines` | 0 |
| `Maximum_Out_Parameters` | Maintainability / Medium | - | `maximum_out_parameters` | 53 |
| `Default_Parameter` | Reliability / Low | - | `default_parameters` | 1681 |
| `Forbidden_Identifier` | Maintainability / Low | - | `name_clashes` | 0 |
| `Uncommented_Begin` | Maintainability / Low | - | `uncommented_begin` | 3061 |
| `Uncommented_Begin_In_Package_Body` | Maintainability / Low | - | `uncommented_begin_in_package_bodies` | 16 |
| `Uncommented_End_Record` | Maintainability / Low | - | `uncommented_end_record` | 77 |
| `Object_Declaration_Out_Of_Order` | Maintainability / Low | - | `object_declarations_out_of_order` | 36 |
| `One_Construct_Per_Line` | Maintainability / Low | - | `one_construct_per_line` | 544 |
| `Logical_SLOC` | Maintainability / Medium | - | `metrics_lsloc` | 162 |
| `Positional_Parameter` | Maintainability / Low | - | `positional_parameters` | 10475 |
| `Positional_Defaulted_Parameter` | Maintainability / Low | - | `positional_actuals_for_defaulted_parameters` | 641 |
| `Positional_Generic_Parameter` | Maintainability / Low | - | `positional_generic_parameters` | 326 |
| `Positional_Component` | Maintainability / Low | - | `positional_components` | 931 |
| `Non_Qualified_Aggregate` | Maintainability / Low | - | `non_qualified_aggregates` | 2530 |
| `Nested_Subprogram` | Maintainability / Low | - | `nested_subprograms` | 1063 |
| `Boolean_Relational_Operator` | Maintainability / Low | - | `boolean_relational_operators` | 219 |
| `Fixed_Equality` | Reliability / Medium | - | `fixed_equality_checks` | 8 |
| `Unconstrained_Array_Return` | Reliability / Medium | - | `unconstrained_array_returns` | 871 |
| `Deriving_From_Predefined_Type` | Reliability / Low | - | `deriving_from_predefined_type` | 47 |
| `Visible_Component` | Maintainability / Medium | - | `visible_components` | 131 |
| `Object_Of_Anonymous_Type` | Maintainability / Low | - | `objects_of_anonymous_types` | 40 |
| `Numeric_Indexing` | Maintainability / Low | - | `numeric_indexing` | 1637 |
| `Local_Instantiation` | Maintainability / Low | - | `local_instantiations` | 181 |
| `Explicit_Inlining` | Maintainability / Low | - | `explicit_inlining` | 763 |
| `Pos_On_Enumeration_Type` | Maintainability / Low | - | `pos_on_enumeration_types` | 215 |
| `Implicit_Small` | Reliability / Medium | - | `implicit_small_for_fixed_point_types` | 0 |
| `Ada05_Formal_Package` | Maintainability / Low | - | `ada05_formal_packages` | 2 |
| `Separate_Numeric_Error_Handler` | Reliability / Low | - | `separate_numeric_error_handlers` | 33 |
| `Forbidden_Aspect` | Maintainability / Medium | - | `forbidden_aspects` | 0 |
| `Forbidden_Attribute` | Maintainability / Medium | - | `forbidden_attributes` | 0 |
| `Forbidden_Dependence` | Maintainability / Medium | - | `no_dependence` | 0 |
| `One_Tagged_Type_Per_Package` | Maintainability / Low | - | `one_tagged_type_per_package` | 18 |
| `Explicit_Full_Discrete_Range` | Maintainability / Low | - | `explicit_full_discrete_ranges` | 28 |
| `Universal_Range` | Reliability / Low | - | `universal_ranges` | 207 |
| `Missing_Others_Handler` | Reliability / Medium | - | `no_others_in_exception_handlers` | 0 |
| `Default_Value_For_Record_Component` | Maintainability / Low | - | `default_values_for_record_components` | 486 |
| `Uninitialized_Global_Variable` | Reliability / Medium | - | `uninitialized_global_variables` | 124 |
| `Deep_Library_Hierarchy` | Maintainability / Low | - | `deep_library_hierarchy` | 10 |
| `Deeply_Nested_Generic` | Maintainability / Low | - | `deeply_nested_generics` | 0 |
| `Overly_Nested_Scope` | Maintainability / Medium | - | `overly_nested_scopes` | 0 |
| `Specific_Type_Invariant` | Reliability / Medium | - | `specific_type_invariants` | 0 |
| `Volatile_Object_Without_Address` | Reliability / Medium | - | `volatile_objects_without_address_clauses` | 2 |
| `Too_Many_Primitives` | Maintainability / Medium | - | `too_many_primitives` | 120 |
| `Deep_Inheritance_Hierarchy` | Maintainability / Medium | - | `deep_inheritance_hierarchies` | 38 |
| `Too_Many_Parents` | Maintainability / Medium | - | `too_many_parents` | 0 |
| `Specific_Pre_Post` | Reliability / Medium | - | `specific_pre_post` | 239 |
| `Constructor` | Maintainability / Low | - | `constructors` | 108 |
| `Misnamed_Controlling_Parameter` | Maintainability / Low | - | `misnamed_controlling_parameters` | 1606 |
| `Non_Component_In_Barrier` | Reliability / Medium | - | `non_component_in_barriers` | 1 |
| `Identifier_Casing` | Maintainability / Low | - | `identifier_casing` | 0 |
| `Identifier_Prefixes` | Maintainability / Low | - | `identifier_prefixes` | 0 |
| `Identifier_Suffixes` | Maintainability / Low | - | `identifier_suffixes` | 0 |
| `Constant_Overlay` | Reliability / High | - | `constant_overlays` | 8 |
| `Non_Constant_Overlay` | Reliability / High | - | `non_constant_overlays` | 19 |
| `Nonoverlay_Address_Specification` | Reliability / Medium | - | `nonoverlay_address_specifications` | 8 |
| `Not_Imported_Overlay` | Reliability / High | - | `not_imported_overlays` | 13 |
| `Address_Of_Non_Volatile_Object` | Reliability / Medium | - | `address_attribute_for_non_volatile_objects` | 31 |
| `Access_To_Local_Object` | Reliability / High | - | `access_to_local_objects` | 77 |
| `Bit_Record_Without_Layout` | Reliability / Medium | - | `bit_records_without_layout_definition` | 3 |
| `No_Scalar_Storage_Order` | Reliability / Medium | - | `no_scalar_storage_order_specified` | 22 |
| `Incomplete_Representation_Specification` | Reliability / Medium | - | `incomplete_representation_specifications` | 25 |
| `Misplaced_Representation_Item` | Maintainability / Low | - | `misplaced_representation_items` | 13 |
| `Representation_Specification` | Maintainability / Low | - | `representation_specifications` | 382 |
| `Unchecked_Address_Conversion` | Security / High | - | `unchecked_address_conversions` | 6 |
| `Unchecked_Conversion_As_Actual` | Security / Medium | - | `unchecked_conversions_as_actuals` | 7 |
| `Use_Simple_Loop` | Maintainability / Low | - | `use_simple_loops` | 1 |
| `Use_While_Loop` | Maintainability / Low | - | `use_while_loops` | 24 |
| `Use_For_Loop` | Maintainability / Low | - | `use_for_loops` | 13 |
| `Use_Range` | Maintainability / Low | - | `use_ranges` | 43 |
| `Use_Membership` | Maintainability / Low | - | `use_memberships` | 13 |
| `Use_If_Expression` | Maintainability / Low | - | `use_if_expressions` | 619 |
| `Use_Case_Statement` | Maintainability / Low | - | `use_case_statements` | 30 |
| `Use_Record_Aggregate` | Maintainability / Low | - | `use_record_aggregates` | 40 |
| `Use_For_Of_Loop` | Maintainability / Low | - | `use_for_of_loops` | 71 |
| `Use_Array_Slice` | Maintainability / Low | - | `use_array_slices` | 5 |
| `Discriminated_Record` | Maintainability / Low | - | `discriminated_records` | 104 |
| `Anonymous_Subtype` | Maintainability / Low | - | `anonymous_subtypes` | 3515 |
| `No_Explicit_Real_Range` | Reliability / Medium | - | `no_explicit_real_range` | 4 |
| `Direct_Equality` | Reliability / Medium | - | `direct_equalities` | 0 |
| `Membership_For_Validity` | Reliability / Medium | - | `membership_for_validity` | 40 |
| `Positional_Defaulted_Generic_Parameter` | Maintainability / Low | - | `positional_actuals_for_defaulted_generic_parameters` | 25 |
| `Deeply_Nested_Instantiation` | Maintainability / Medium | - | `deeply_nested_instantiations` | 8 |
| `Too_Many_Generic_Dependencies` | Maintainability / Medium | - | `too_many_generic_dependencies` | 5 |
| `Raising_External_Exception` | Reliability / Medium | - | `raising_external_exceptions` | 110 |
| `Final_Package` | Maintainability / Medium | - | `final_package` | 0 |
| `Direct_Call_To_Primitive` | Reliability / Medium | - | `direct_calls_to_primitives` | 3158 |
| `Downward_View_Conversion` | Reliability / Medium | - | `downward_view_conversions` | 209 |
| `Specific_Parent_Type_Invariant` | Reliability / Medium | - | `specific_parent_type_invariant` | 0 |
| `No_Inherited_Classwide_Pre` | Reliability / Medium | - | `no_inherited_classwide_pre` | 401 |
| `Non_SPARK_Attribute` | Maintainability / Low | - | `non_spark_attributes` | 4898 |
| `Nested_Path` | Maintainability / Low | - | `nested_paths` | 212 |
| `Essential_Complexity` | Maintainability / Medium | - | `metrics_essential_complexity` | 299 |
| `Maximum_Expression_Complexity` | Maintainability / Medium | - | `maximum_expression_complexity` | 4357 |
| `Improperly_Located_Instantiation` | Maintainability / Low | - | `improperly_located_instantiations` | 439 |
| `Function_Style_Procedure` | Maintainability / Low | - | `function_style_procedures` | 358 |
| `Exception_As_Control_Flow` | Reliability / Medium | - | `exceptions_as_control_flow` | 9 |
| `Complex_Inlined_Subprogram` | Maintainability / Medium | - | `complex_inlined_subprograms` | 204 |
| `Call_In_Exception_Handler` | Reliability / Medium | - | `calls_in_exception_handlers` | 0 |
| `Ada_2022_In_Ghost_Code` | Maintainability / Medium | - | `ada_2022_in_ghost_code` | 444 |
| `Actual_Parameter` | Reliability / Medium | - | `actual_parameters` | 0 |
| `Same_Logic` | Reliability / Medium | - | `same_logic` | 8 |
| `Suspicious_Equality` | Reliability / High | - | `suspicious_equalities` | 0 |
| `Non_Visible_Exception` | Reliability / Medium | - | `non_visible_exceptions` | 1 |
| `Outbound_Protected_Assignment` | Reliability / Medium | - | `outbound_protected_assignments` | 81 |
| `Outside_Reference_From_Subprogram` | Maintainability / Medium | - | `outside_references_from_subprograms` | 2703 |
| `Variable_Scoping` | Maintainability / Low | - | `variable_scoping` | 20 |
| `Out_Parameter_Read_In_Exception_Handler` | Reliability / High | - | `out_parameter_read_in_exception_handler` | 70 |
| `Predicate_Testing` | Reliability / Low | - | `predicate_testing` | 16 |
| `Profile_Discrepancy` | Maintainability / Low | - | `profile_discrepancies` | 111 |
| `Side_Effect_Parameter` | Reliability / Medium | - | `side_effect_parameters` | 0 |
| `Use_Clause` | Maintainability / Low | - | `use_clauses` | 927 |
| `Unavailable_Body_Call` | Reliability / Low | - | `unavailable_body_calls` | 439 |
| `Deeply_Nested_Inlining` | Maintainability / Low | - | `deeply_nested_inlining` | 0 |
| `Integer_Type_As_Enumeration` | Maintainability / Low | - | `integer_types_as_enum` | 39 |
| `Same_Instantiation` | Maintainability / Low | - | `same_instantiations` | 2 |
| `Compiler_Warning` | Reliability / Medium | - | `warnings` | 0 |
| `Compiler_Style_Check` | Maintainability / Low | - | `style_checks` | 0 |
| `Compiler_Restriction` | Reliability / Medium | - | `restrictions` | 0 |
