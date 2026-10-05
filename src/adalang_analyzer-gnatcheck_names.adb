--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  AdaLang Analyzer is developed and supported by Spazio IT.
--  This project is not endorsed or sponsored by AdaCore.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Characters.Handling;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package body Adalang_Analyzer.GNATcheck_Names is

   use Rules;

   type Pair is record
      Name : Unbounded_String;
      Rule : Rule_Kind;
   end record;

   function "+" (Text : String) return Unbounded_String
     renames To_Unbounded_String;

   --  In the order of the GNATcheck rule names.
   Pairs : constant array (Positive range <>) of Pair :=
     (
      (+"abort_statements", No_Abort),
      (+"abstract_type_declarations", Abstract_Type_Declaration),
      (+"access_to_local_objects", Access_To_Local_Object),
      (+"actual_parameters", Actual_Parameter),
      (+"ada05_formal_packages", Ada05_Formal_Package),
      (+"ada_2022_in_ghost_code", Ada_2022_In_Ghost_Code),
      (+"address_attribute_for_non_volatile_objects",
       Address_Of_Non_Volatile_Object),
      (+"address_specifications_for_initialized_objects", Address_Clause),
      (+"address_specifications_for_local_objects", Address_Clause),
      (+"annotated_comments", Annotated_Comment),
      (+"anonymous_access", Anonymous_Access_Type),
      (+"anonymous_arrays", Anonymous_Array_Type),
      (+"anonymous_subtypes", Anonymous_Subtype),
      (+"at_representation_clauses", Address_Clause),
      (+"binary_case_statements", Binary_Case_Statement),
      (+"bit_records_without_layout_definition", Bit_Record_Without_Layout),
      (+"blocks", No_Block_Statement),
      (+"boolean_negations", Redundant_Boolean_Comparison),
      (+"boolean_relational_operators", Boolean_Relational_Operator),
      (+"calls_in_exception_handlers", Call_In_Exception_Handler),
      (+"calls_outside_elaboration", Library_Level_Initialization),
      (+"complex_inlined_subprograms", Complex_Inlined_Subprogram),
      (+"concurrent_interfaces", Concurrent_Interface),
      (+"conditional_expressions", Conditional_Expression),
      (+"constant_overlays", Constant_Overlay),
      (+"constructors", Constructor),
      (+"controlled_type_declarations", No_Controlled_Type),
      (+"declarations_in_blocks", Declaration_In_Block),
      (+"deep_inheritance_hierarchies", Deep_Inheritance_Hierarchy),
      (+"deep_library_hierarchy", Deep_Library_Hierarchy),
      (+"deeply_nested_generics", Deeply_Nested_Generic),
      (+"deeply_nested_inlining", Deeply_Nested_Inlining),
      (+"deeply_nested_instantiations", Deeply_Nested_Instantiation),
      (+"default_parameters", Default_Parameter),
      (+"default_values_for_record_components",
       Default_Value_For_Record_Component),
      (+"deriving_from_predefined_type", Deriving_From_Predefined_Type),
      (+"direct_calls_to_primitives", Direct_Call_To_Primitive),
      (+"direct_equalities", Direct_Equality),
      (+"discriminated_records", Discriminated_Record),
      (+"downward_view_conversions", Downward_View_Conversion),
      (+"duplicate_branches", Identical_Branches),
      (+"duplicate_branches", Identical_Case_Alternative),
      (+"end_of_line_comments", End_Of_Line_Comment),
      (+"enumeration_ranges_in_case_statements",
       Enumeration_Range_In_Case_Statement),
      (+"enumeration_representation_clauses",
       Enumeration_Representation_Clause),
      (+"exception_propagation_from_callbacks", Exception_Propagation),
      (+"exception_propagation_from_export", Exception_Propagation),
      (+"exception_propagation_from_tasks", Exception_Propagation),
      (+"exceptions_as_control_flow", Exception_As_Control_Flow),
      (+"exit_statements_with_no_loop_name", Exit_Without_Loop_Name),
      (+"exits_from_conditional_loops", Exit_From_Conditional_Loop),
      (+"expanded_loop_exit_names", Expanded_Loop_Exit_Name),
      (+"explicit_full_discrete_ranges", Explicit_Full_Discrete_Range),
      (+"explicit_inlining", Explicit_Inlining),
      (+"expression_functions", Expression_Function),
      (+"final_package", Final_Package),
      (+"fixed_equality_checks", Fixed_Equality),
      (+"float_equality_checks", Floating_Equality),
      (+"forbidden_aspects", Forbidden_Aspect),
      (+"forbidden_attributes", Forbidden_Attribute),
      (+"forbidden_pragmas", No_Pragma),
      (+"function_out_parameters", Function_Out_Parameter),
      (+"function_style_procedures", Function_Style_Procedure),
      (+"generic_in_out_objects", Generic_In_Out_Object),
      (+"generics_in_subprograms", Generic_In_Subprogram),
      (+"global_variables", Global_Variable),
      (+"goto_statements", No_Goto),
      (+"headers", Missing_Header),
      (+"identifier_casing", Identifier_Casing),
      (+"identifier_prefixes", Identifier_Prefixes),
      (+"identifier_suffixes", Identifier_Suffixes),
      (+"implicit_in_mode_parameters", Implicit_In_Mode),
      (+"implicit_small_for_fixed_point_types", Implicit_Small),
      (+"improper_returns", No_Multiple_Return),
      (+"improperly_located_instantiations", Improperly_Located_Instantiation),
      (+"incomplete_representation_specifications",
       Incomplete_Representation_Specification),
      (+"integer_types_as_enum", Integer_Type_As_Enumeration),
      (+"library_level_subprograms", Library_Level_Subprogram),
      (+"local_instantiations", Local_Instantiation),
      (+"local_packages", Local_Package),
      (+"local_use_clauses", Local_Use_Clause),
      (+"lowercase_keywords", Lowercase_Keyword),
      (+"max_identifier_length", Maximum_Identifier_Length),
      (+"maximum_expression_complexity", Maximum_Expression_Complexity),
      (+"maximum_lines", Maximum_Lines),
      (+"maximum_out_parameters", Maximum_Out_Parameters),
      (+"maximum_parameters", Too_Many_Parameters),
      (+"maximum_subprogram_lines", Maximum_Subprogram_Lines),
      (+"membership_for_validity", Membership_For_Validity),
      (+"membership_tests", Membership_Test),
      (+"metrics_cyclomatic_complexity", Cyclomatic_Complexity),
      (+"metrics_essential_complexity", Essential_Complexity),
      (+"metrics_lsloc", Logical_SLOC),
      (+"min_identifier_length", Naming_Convention),
      (+"misnamed_controlling_parameters", Misnamed_Controlling_Parameter),
      (+"misplaced_representation_items", Misplaced_Representation_Item),
      (+"multiple_entries_in_protected_definitions",
       Multiple_Protected_Entries),
      (+"name_clashes", Forbidden_Identifier),
      (+"nested_paths", Nested_Path),
      (+"nested_subprograms", Nested_Subprogram),
      (+"no_closing_names", No_Closing_Name),
      (+"no_dependence", Forbidden_Dependence),
      (+"no_explicit_real_range", No_Explicit_Real_Range),
      (+"no_inherited_classwide_pre", No_Inherited_Classwide_Pre),
      (+"no_others_in_exception_handlers", Missing_Others_Handler),
      (+"no_scalar_storage_order_specified", No_Scalar_Storage_Order),
      (+"non_component_in_barriers", Non_Component_In_Barrier),
      (+"non_constant_overlays", Non_Constant_Overlay),
      (+"non_qualified_aggregates", Non_Qualified_Aggregate),
      (+"non_short_circuit_operators", Non_Short_Circuit_Condition),
      (+"non_spark_attributes", Non_SPARK_Attribute),
      (+"non_tagged_derived_types", Non_Tagged_Derived_Type),
      (+"non_visible_exceptions", Non_Visible_Exception),
      (+"nonoverlay_address_specifications", Nonoverlay_Address_Specification),
      (+"not_imported_overlays", Not_Imported_Overlay),
      (+"null_paths", Empty_Else_Body),
      (+"null_paths", Empty_Elsif_Body),
      (+"null_paths", Empty_If_Body),
      (+"null_paths", Empty_Then_Body),
      (+"null_paths", Null_Case_Alternative),
      (+"number_declarations", Number_Declaration),
      (+"numeric_format", Numeric_Format),
      (+"numeric_indexing", Numeric_Indexing),
      (+"numeric_literals", Magic_Number),
      (+"object_declarations_out_of_order", Object_Declaration_Out_Of_Order),
      (+"objects_of_anonymous_types", Object_Of_Anonymous_Type),
      (+"one_construct_per_line", One_Construct_Per_Line),
      (+"one_tagged_type_per_package", One_Tagged_Type_Per_Package),
      (+"operator_renamings", Operator_Renaming),
      (+"others_in_aggregates", Others_In_Aggregate),
      (+"others_in_case_statements", Others_In_Case_Statement),
      (+"others_in_exception_handlers", Others_In_Exception_Handler),
      (+"out_parameter_read_in_exception_handler",
       Out_Parameter_Read_In_Exception_Handler),
      (+"outbound_protected_assignments", Outbound_Protected_Assignment),
      (+"outer_loop_exits", Outer_Loop_Exit),
      (+"outside_references_from_subprograms",
       Outside_Reference_From_Subprogram),
      (+"overloaded_operators", Overloaded_Operator),
      (+"overly_nested_control_structures", Deep_Nesting),
      (+"overly_nested_scopes", Overly_Nested_Scope),
      (+"overriding_indicators", Missing_Overriding_Indicator),
      (+"parameters_aliasing", Aliasing_Between_Parameters),
      (+"parameters_out_of_order", Parameters_Out_Of_Order),
      (+"pos_on_enumeration_types", Pos_On_Enumeration_Type),
      (+"positional_actuals_for_defaulted_generic_parameters",
       Positional_Defaulted_Generic_Parameter),
      (+"positional_actuals_for_defaulted_parameters",
       Positional_Defaulted_Parameter),
      (+"positional_components", Positional_Component),
      (+"positional_generic_parameters", Positional_Generic_Parameter),
      (+"positional_parameters", Positional_Parameter),
      (+"potential_parameters_aliasing", Aliasing_Between_Parameters),
      (+"predefined_numeric_types", Predefined_Numeric_Type),
      (+"predicate_testing", Predicate_Testing),
      (+"printable_ascii", Printable_ASCII),
      (+"profile_discrepancies", Profile_Discrepancy),
      (+"quantified_expressions", Quantified_Expression),
      (+"raising_external_exceptions", Raising_External_Exception),
      (+"raising_predefined_exceptions", Raising_Predefined_Exception),
      (+"recursive_subprograms", No_Recursion),
      (+"redundant_boolean_expressions", Duplicate_Boolean_Operand),
      (+"redundant_boolean_expressions", Redundant_Boolean_Comparison),
      (+"redundant_null_statements", Null_Statement),
      (+"relative_delay_statements", Relative_Delay),
      (+"renamings", Renaming_Declaration),
      (+"representation_specifications", Representation_Specification),
      (+"restrictions", Compiler_Restriction),
      (+"same_instantiations", Same_Instantiation),
      (+"same_logic", Same_Logic),
      (+"same_operands", Duplicate_Boolean_Operand),
      (+"same_operands", Same_Operand),
      (+"same_tests", Duplicate_Condition),
      (+"separate_numeric_error_handlers", Separate_Numeric_Error_Handler),
      (+"separates", Separate_Unit),
      (+"side_effect_parameters", Side_Effect_Parameter),
      (+"silent_exception_handlers", Empty_Exception_Handler),
      (+"silent_exception_handlers", Exception_Swallowed),
      (+"simple_loop_statements", Infinite_Loop),
      (+"single_value_enumeration_types", Single_Value_Enumeration_Type),
      (+"size_attribute_for_types", Size_Attribute_For_Type),
      (+"slices", Array_Slice),
      (+"spark_procedures_without_globals", Missing_Global_Contract),
      (+"specific_parent_type_invariant", Specific_Parent_Type_Invariant),
      (+"specific_pre_post", Specific_Pre_Post),
      (+"specific_type_invariants", Specific_Type_Invariant),
      (+"style_checks", Compiler_Style_Check),
      (+"subprogram_access", No_Access_To_Subp_Def),
      (+"suspicious_equalities", Suspicious_Equality),
      (+"too_many_dependencies", Dependency_Limit),
      (+"too_many_generic_dependencies", Too_Many_Generic_Dependencies),
      (+"too_many_parents", Too_Many_Parents),
      (+"too_many_primitives", Too_Many_Primitives),
      (+"trivial_exception_handlers", Exception_Swallowed),
      (+"unassigned_out_parameters", Uninitialized_Output),
      (+"unavailable_body_calls", Unavailable_Body_Call),
      (+"unchecked_address_conversions", Unchecked_Address_Conversion),
      (+"unchecked_conversions_as_actuals", Unchecked_Conversion_As_Actual),
      (+"uncommented_begin", Uncommented_Begin),
      (+"uncommented_begin_in_package_bodies",
       Uncommented_Begin_In_Package_Body),
      (+"uncommented_end_record", Uncommented_End_Record),
      (+"unconditional_exits", Unconditional_Exit),
      (+"unconstrained_array_returns", Unconstrained_Array_Return),
      (+"unconstrained_arrays", Unconstrained_Array_Type),
      (+"uninitialized_global_variables", Uninitialized_Global_Variable),
      (+"universal_ranges", Universal_Range),
      (+"unnamed_blocks_and_loops", Unnamed_Block_Or_Loop),
      (+"unnamed_exits", Unnamed_Exit),
      (+"use_array_slices", Use_Array_Slice),
      (+"use_case_statements", Use_Case_Statement),
      (+"use_clauses", Use_Clause),
      (+"use_for_loops", Use_For_Loop),
      (+"use_for_of_loops", Use_For_Of_Loop),
      (+"use_if_expressions", Use_If_Expression),
      (+"use_memberships", Use_Membership),
      (+"use_package_clauses", No_Use_Package_Clause),
      (+"use_ranges", Use_Range),
      (+"use_record_aggregates", Use_Record_Aggregate),
      (+"use_simple_loops", Use_Simple_Loop),
      (+"use_while_loops", Use_While_Loop),
      (+"variable_scoping", Variable_Scoping),
      (+"visible_components", Visible_Component),
      (+"volatile_objects_without_address_clauses",
       Volatile_Object_Without_Address),
      (+"warnings", Compiler_Warning));

   function Lower (Text : String) return String
     renames Ada.Characters.Handling.To_Lower;

   function Checks_For (Name : String) return Rules.Rule_List is
      Wanted : constant String := Lower (Name);
      Count  : Natural := 0;
   begin
      for Item of Pairs loop
         if To_String (Item.Name) = Wanted then
            Count := Count + 1;
         end if;
      end loop;

      return Result : Rules.Rule_List (1 .. Count) do
         Count := 0;
         for Item of Pairs loop
            if To_String (Item.Name) = Wanted then
               Count := Count + 1;
               Result (Count) := Item.Rule;
            end if;
         end loop;
      end return;
   end Checks_For;

   function Names_Of (Rule : Rules.Rule_Kind) return String is
      Result : Unbounded_String;
   begin
      for Item of Pairs loop
         if Item.Rule = Rule then
            if Length (Result) > 0 then
               Append (Result, ", ");
            end if;
            Append (Result, Item.Name);
         end if;
      end loop;
      return To_String (Result);
   end Names_Of;

end Adalang_Analyzer.GNATcheck_Names;
