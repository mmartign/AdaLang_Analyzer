--  AdaLang Analyzer
--
--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--
--  Derived from AdaCore's libadalang-tools and substantially extended,
--  integrated, validated, and maintained by Spazio IT as part of the
--  independent AdaLang Analyzer project.
--
--  AdaLang Analyzer is developed and supported by Spazio IT.
--  This project is not endorsed or sponsored by AdaCore.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

--  The authoritative registry of every selectable check: its identity
--  (Rule_Kind), and the fixed metadata shown alongside every violation
--  (description, remediation guidance, and a SonarQube-style Clean Code
--  classification). This is this analyzer's own judgment applying
--  SonarQube's Clean Code taxonomy to Ada constructs, not an imported
--  SonarQube ruleset.
package Adalang_Analyzer.Rules is

   --  This enumeration is the authoritative registry of selectable checks.
   type Rule_Kind is (
      No_Goto,
      No_Abort,
      No_Raise,
      No_Exit,
      No_Label,
      No_Pragma,
      No_Access_To_Subp_Def,
      No_Unchecked_Conversion,
      No_Unchecked_Access,
      Floating_Equality,
      Magic_Number,
      Unused_Parameter,
      Wrong_Parameter_Mode,
      Dead_Store,
      Overwritten_Assignment,
      Shadowed_Declaration,
      Unreachable_Case_Alternative,
      Overlapping_Case_Ranges,
      Infinite_Loop,
      Duplicate_Boolean_Operand,
      Redundant_Abs,
      Redundant_Unary_Minus,
      Exception_Swallowed,
      Cyclomatic_Complexity,
      Constant_Condition,
      Unreachable_Code,
      Division_By_Zero,
      Integer_Division_Before_Multiplication,
      Excessive_Shift_Amount,
      Known_Negative_Shift_Amount_Failure,
      Known_Negative_Exponent_Failure,
      Succ_Pred_Boundary_Overflow,
      Reversed_Range,
      Self_Assignment,
      Same_Operand,
      Duplicate_Condition,
      Duplicate_With_Clause,
      Duplicate_Exception_Choice,
      Null_Statement,
      Redundant_Final_Return,
      Empty_Exception_Handler,
      Unreachable_Branch,
      Contradictory_Condition,
      Contradictory_Range_Condition,
      Identical_Branches,
      Repeated_Statement,
      Ineffective_Operation,
      Constant_Result_Operation,
      Empty_Loop,
      No_Recursion,
      No_Multiple_Return,
      Non_Short_Circuit_Condition,
      Address_Clause,
      Too_Many_Parameters,
      Swappable_Parameters,
      Deep_Nesting,
      Unused_Variable,
      Empty_If_Body,
      Empty_Elsif_Body,
      Empty_Then_Body,
      Empty_Else_Body,
      Null_Case_Alternative,
      Unnecessary_Else_After_Return,
      Redundant_If_Boolean_Return,
      Function_Side_Effect,
      Redundant_Boolean_Comparison,
      Long_Line,
      Trailing_Whitespace,
      SPARK_Mode,
      Missing_Global_Contract,
      Global_Contract_Mismatch,
      Missing_Depends_Contract,
      Incomplete_Depends_Contract,
      Depends_Contract_Mismatch,
      Uninitialized_Output,
      Uninitialized_Read,
      Missing_Overriding_Indicator,
      Inefficient_String_Concatenation,
      Circular_Package_Dependency,
      Duplicate_Subprogram,
      Known_Precondition_Failure,
      Known_Postcondition_Failure,
      Known_Assertion_Failure,
      Assertion_Side_Effect,
      Entry_Barrier_Side_Effect,
      Known_Range_Check_Failure,
      Known_Index_Check_Failure,
      Known_Overflow_Failure,
      Identical_Case_Alternative,
      Redundant_Type_Conversion,
      Handler_Order,
      Reraise_Discards_Occurrence,
      Aliasing_Between_Parameters,
      Missing_Loop_Variant,
      Known_Discriminant_Check_Failure,
      Known_Enum_Val_Failure,
      Known_Value_Conversion_Failure,
      Potentially_Blocking_Operation,
      No_Dynamic_Allocation,
      Restricted_Access_Type,
      No_Explicit_Dereference,
      No_Unchecked_Deallocation,
      No_Tasking,
      No_Rendezvous,
      No_Select,
      No_Requeue,
      No_Asynchronous_Transfer,
      Exception_Propagation,
      No_Dispatching_Call,
      No_Classwide_Type,
      No_Controlled_Type,
      Complete_Initialization,
      Volatile_Atomic_Consistency,
      Representation_Clause_Policy,
      Library_Level_Initialization,
      Generic_Instantiation_Limit,
      Dependency_Limit,
      Naming_Convention,
      No_Compiler_Extensions,
      No_Runtime_Check_Suppression,
      Missing_Requirement_Trace,
      Malformed_Requirement_Trace,
      Suppression_Without_Rationale,
      Use_After_Free,
      Double_Free,
      Unclosed_File_Handle,
      Unused_With_Clause,
      No_Use_Package_Clause,
      Others_In_Case_Statement,
      Others_In_Exception_Handler,
      Others_In_Aggregate,
      Unnamed_Exit,
      Unnamed_Block_Or_Loop,
      Implicit_In_Mode,
      Function_Out_Parameter,
      Raising_Predefined_Exception,
      Anonymous_Array_Type,
      Enumeration_Representation_Clause,
      Relative_Delay,
      No_Block_Statement,
      Global_Variable,
      Predefined_Numeric_Type,
      Abstract_Type_Declaration,
      Exit_From_Conditional_Loop,
      Expanded_Loop_Exit_Name,
      Conditional_Expression,
      Quantified_Expression,
      Membership_Test,
      Generic_In_Out_Object,
      Generic_In_Subprogram,
      Local_Use_Clause,
      Library_Level_Subprogram,
      Multiple_Protected_Entries,
      Non_Tagged_Derived_Type,
      No_Closing_Name,
      Operator_Renaming,
      Overloaded_Operator,
      Single_Value_Enumeration_Type,
      Unconstrained_Array_Type,
      Unconditional_Exit,
      Binary_Case_Statement,
      Concurrent_Interface,
      Anonymous_Access_Type,
      Renaming_Declaration,
      Separate_Unit,
      Array_Slice,
      Number_Declaration,
      Local_Package,
      Declaration_In_Block,
      Outer_Loop_Exit,
      Exit_Without_Loop_Name,
      Expression_Function,
      Size_Attribute_For_Type,
      Enumeration_Range_In_Case_Statement,
      Missing_Header,
      Lowercase_Keyword,
      Printable_ASCII,
      End_Of_Line_Comment,
      Annotated_Comment,
      Maximum_Lines,
      Maximum_Identifier_Length,
      Numeric_Format,
      Parameters_Out_Of_Order,
      Maximum_Subprogram_Lines,
      Maximum_Out_Parameters,
      Default_Parameter,
      Forbidden_Identifier,
      Uncommented_Begin,
      Uncommented_Begin_In_Package_Body,
      Uncommented_End_Record,
      Object_Declaration_Out_Of_Order,
      One_Construct_Per_Line,
      Logical_SLOC,
      Positional_Parameter,
      Positional_Defaulted_Parameter,
      Positional_Generic_Parameter,
      Positional_Component,
      Non_Qualified_Aggregate,
      Nested_Subprogram,
      Boolean_Relational_Operator,
      Fixed_Equality,
      Unconstrained_Array_Return,
      Deriving_From_Predefined_Type,
      Visible_Component,
      Object_Of_Anonymous_Type,
      Numeric_Indexing,
      Local_Instantiation,
      Explicit_Inlining,
      Pos_On_Enumeration_Type,
      Implicit_Small,
      Ada05_Formal_Package,
      Separate_Numeric_Error_Handler,
      Forbidden_Aspect,
      Forbidden_Attribute,
      Forbidden_Dependence,
      One_Tagged_Type_Per_Package,
      Explicit_Full_Discrete_Range,
      Universal_Range,
      Missing_Others_Handler,
      Default_Value_For_Record_Component,
      Uninitialized_Global_Variable,
      Deep_Library_Hierarchy,
      Deeply_Nested_Generic,
      Overly_Nested_Scope,
      Specific_Type_Invariant,
      Volatile_Object_Without_Address,
      Too_Many_Primitives,
      Deep_Inheritance_Hierarchy,
      Too_Many_Parents,
      Specific_Pre_Post,
      Constructor,
      Misnamed_Controlling_Parameter,
      Non_Component_In_Barrier,
      Identifier_Casing,
      Identifier_Prefixes,
      Identifier_Suffixes,
      Constant_Overlay,
      Non_Constant_Overlay,
      Nonoverlay_Address_Specification,
      Not_Imported_Overlay,
      Address_Of_Non_Volatile_Object,
      Access_To_Local_Object,
      Bit_Record_Without_Layout,
      No_Scalar_Storage_Order,
      Incomplete_Representation_Specification,
      Misplaced_Representation_Item,
      Representation_Specification,
      Unchecked_Address_Conversion,
      Unchecked_Conversion_As_Actual,
      Use_Simple_Loop,
      Use_While_Loop,
      Use_For_Loop,
      Use_Range,
      Use_Membership,
      Use_If_Expression,
      Use_Case_Statement,
      Use_Record_Aggregate,
      Use_For_Of_Loop,
      Use_Array_Slice,
      Discriminated_Record,
      Anonymous_Subtype,
      No_Explicit_Real_Range,
      Direct_Equality,
      Membership_For_Validity,
      Positional_Defaulted_Generic_Parameter,
      Deeply_Nested_Instantiation,
      Too_Many_Generic_Dependencies,
      Raising_External_Exception,
      Final_Package,
      Direct_Call_To_Primitive,
      Downward_View_Conversion,
      Specific_Parent_Type_Invariant,
      No_Inherited_Classwide_Pre,
      Non_SPARK_Attribute,
      Nested_Path,
      Essential_Complexity,
      Maximum_Expression_Complexity,
      Improperly_Located_Instantiation,
      Function_Style_Procedure,
      Exception_As_Control_Flow,
      Complex_Inlined_Subprogram,
      Call_In_Exception_Handler,
      Ada_2022_In_Ghost_Code,
      Actual_Parameter,
      Same_Logic,
      Suspicious_Equality,
      Non_Visible_Exception,
      Outbound_Protected_Assignment,
      Outside_Reference_From_Subprogram,
      Variable_Scoping,
      Out_Parameter_Read_In_Exception_Handler,
      Predicate_Testing,
      Profile_Discrepancy,
      Side_Effect_Parameter,
      Use_Clause,
      Unavailable_Body_Call,
      Deeply_Nested_Inlining,
      Integer_Type_As_Enumeration,
      Same_Instantiation,
      Compiler_Warning,
      Compiler_Style_Check,
      Compiler_Restriction
   );

   type Rule_List is array (Positive range <>) of Rule_Kind;

   --  The three DO-178C profile rule groups from Adalang_Analyzer.CLI's
   --  Enable_DO_178C_Preset, promoted here so the profile-enabling logic and
   --  Adalang_Analyzer.Compliance_Mapping's objective-to-rule mapping share
   --  one definition instead of two hand-copied lists that could drift.
   DO_178C_Core_Rules : aliased constant Rule_List :=
     (Exception_Swallowed, Empty_Exception_Handler, Handler_Order,
      Unreachable_Code, Unreachable_Branch,
      Unreachable_Case_Alternative, Division_By_Zero, Reversed_Range,
      Self_Assignment, Contradictory_Condition, Constant_Condition,
      Known_Precondition_Failure, Known_Postcondition_Failure,
      Known_Assertion_Failure, Known_Range_Check_Failure,
      Known_Index_Check_Failure, Known_Overflow_Failure,
      Aliasing_Between_Parameters, Exception_Propagation);

   DO_178C_Level_C_Rules : aliased constant Rule_List :=
     (Missing_Requirement_Trace, Malformed_Requirement_Trace,
      Dead_Store, Overwritten_Assignment, Uninitialized_Output,
      Global_Contract_Mismatch, Incomplete_Depends_Contract,
      Depends_Contract_Mismatch, Function_Side_Effect,
      No_Recursion, Non_Short_Circuit_Condition);

   DO_178C_Level_AB_Rules : aliased constant Rule_List :=
     (Suppression_Without_Rationale, No_Dynamic_Allocation,
      No_Unchecked_Conversion, No_Unchecked_Access,
      No_Unchecked_Deallocation,
      Complete_Initialization, Uninitialized_Read, No_Dispatching_Call,
      Missing_Global_Contract, Missing_Depends_Contract,
      Missing_Loop_Variant, Potentially_Blocking_Operation,
      No_Compiler_Extensions, Library_Level_Initialization,
      Cyclomatic_Complexity, Deep_Nesting);

   --  The automotive profile rule list from Adalang_Analyzer.CLI's
   --  Enable_Automotive_Preset, promoted here for the same reason as the
   --  DO-178C lists above: Adalang_Analyzer.Compliance_Mapping's ISO 26262
   --  objective-to-rule mapping must cite exactly the rules --automotive
   --  actually enables, not a second hand-copied list.
   Automotive_Rules : aliased constant Rule_List :=
     (No_Goto, No_Label, No_Multiple_Return, No_Abort, No_Raise,
      No_Access_To_Subp_Def,
      No_Unchecked_Conversion, No_Unchecked_Access,
      Floating_Equality, Magic_Number,
      Dead_Store, Overwritten_Assignment, Shadowed_Declaration,
      Infinite_Loop, Constant_Condition, Unreachable_Code,
      Unreachable_Branch, Unreachable_Case_Alternative,
      Overlapping_Case_Ranges, Exception_Swallowed,
      Division_By_Zero, Reversed_Range, Self_Assignment,
      Contradictory_Condition, No_Recursion,
      Non_Short_Circuit_Condition, Address_Clause,
      Function_Side_Effect, SPARK_Mode,
      Missing_Global_Contract, Global_Contract_Mismatch,
      Missing_Depends_Contract, Incomplete_Depends_Contract,
      Depends_Contract_Mismatch,
      Uninitialized_Output, Known_Precondition_Failure,
      Known_Postcondition_Failure, Known_Assertion_Failure,
      Known_Range_Check_Failure, Known_Index_Check_Failure,
      Known_Overflow_Failure, Aliasing_Between_Parameters,
      Missing_Loop_Variant, Known_Discriminant_Check_Failure,
      Potentially_Blocking_Operation, No_Dynamic_Allocation,
      Restricted_Access_Type, No_Explicit_Dereference,
      No_Unchecked_Deallocation, No_Tasking, No_Rendezvous,
      No_Select, No_Requeue, No_Asynchronous_Transfer,
      Exception_Propagation, No_Dispatching_Call, No_Classwide_Type,
      No_Controlled_Type, Complete_Initialization, Uninitialized_Read,
      Volatile_Atomic_Consistency, Representation_Clause_Policy,
      Library_Level_Initialization, Redundant_Type_Conversion,
      Missing_Overriding_Indicator,
      Generic_Instantiation_Limit, Dependency_Limit,
      Circular_Package_Dependency,
      Cyclomatic_Complexity, Deep_Nesting,
      Naming_Convention, No_Compiler_Extensions,
      No_Runtime_Check_Suppression, Suppression_Without_Rationale);

   type Software_Quality is
     (Quality_Security, Quality_Reliability, Quality_Maintainability);

   type Issue_Severity is
     (Severity_Blocker, Severity_High, Severity_Medium, Severity_Low);

   function Quality_Name (Quality : Software_Quality) return String;

   function Severity_Name (Severity : Issue_Severity) return String;

   --  The fixed metadata shown alongside every violation of a given check.
   type Rule_Info is record
      Name        : Unbounded_String;
      Description : Unbounded_String;
      Guidance    : Unbounded_String;
      Quality     : Software_Quality;
      Severity    : Issue_Severity;
   end record;

   --  Static text for every check, indexed by Rule_Kind so it stays in sync
   --  with the registry above.
   type Rule_Info_Array is array (Rule_Kind) of Rule_Info;

   Rule_Infos : constant Rule_Info_Array := ( --
      No_Goto =>
        (Name        => To_Unbounded_String ("No_Goto"),
         Description => To_Unbounded_String
           ("Avoid goto statements because they make control flow difficult " &
            "to follow and verify."),
         Guidance    => To_Unbounded_String
           ("Replace the jump with structured control flow such as a loop " &
            "condition, if statement, return, or a small local subprogram."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      No_Abort =>
        (Name        => To_Unbounded_String ("No_Abort"),
         Description => To_Unbounded_String
           ("Avoid abort statements because asynchronous task termination " &
            "can leave shared state and cleanup paths unclear."),
         Guidance    => To_Unbounded_String
           ("Prefer cooperative cancellation, protected objects, or an " &
            "explicit task shutdown protocol."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      No_Raise =>
        (Name        => To_Unbounded_String ("No_Raise"),
         Description => To_Unbounded_String
           ("Avoid explicit raise statements when the code base expects " &
            "errors to be handled through regular control flow."),
         Guidance    => To_Unbounded_String
           ("Return a status/result value where possible, or centralize " &
            "exception raising at a documented boundary."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      No_Exit =>
        (Name        => To_Unbounded_String ("No_Exit"),
         Description => To_Unbounded_String
           ("Avoid exit statements that make loop termination depend on " &
            "hidden branches inside the loop body."),
         Guidance    => To_Unbounded_String
           ("Move the termination condition into the loop condition or " &
            "split the loop so the exit case is explicit."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      No_Label =>
        (Name        => To_Unbounded_String ("No_Label"),
         Description => To_Unbounded_String
           ("Avoid labels because they are normally only needed to support " &
            "unstructured jumps."),
         Guidance    => To_Unbounded_String
           ("Remove the label or replace the surrounding flow with " &
            "structured statements."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low), --
      No_Pragma =>
        (Name        => To_Unbounded_String ("No_Pragma"),
         Description => To_Unbounded_String
           ("Avoid pragmas that may change compiler behavior, runtime " &
            "behavior, portability, or verification assumptions."),
         Guidance    => To_Unbounded_String
           ("Keep only required pragmas, document the reason, and isolate " &
            "compiler-specific pragmas behind project policy."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      No_Access_To_Subp_Def =>
        (Name        => To_Unbounded_String ("No_Access_To_Subp_Def"),
         Description => To_Unbounded_String
           ("Avoid access-to-subprogram type definitions because indirect " &
            "calls make call relationships harder to analyze."),
         Guidance    => To_Unbounded_String
           ("Prefer explicit subprogram parameters, generics, or a small " &
            "dispatching abstraction with a clear ownership boundary."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      No_Unchecked_Conversion =>
        (Name        => To_Unbounded_String ("No_Unchecked_Conversion"),
         Description => To_Unbounded_String
           ("Find instantiations of Ada.Unchecked_Conversion, which bypass " &
            "the language's normal type-safety guarantees."),
         Guidance    => To_Unbounded_String
           ("Replace the conversion with a checked representation or an " &
            "explicit serialization boundary; if it is unavoidable, isolate " &
            "and justify the instantiation."),
         Quality     => Quality_Security,
         Severity    => Severity_High),
      No_Unchecked_Access =>
        (Name        => To_Unbounded_String ("No_Unchecked_Access"),
         Description => To_Unbounded_String
           ("Find uses of the 'Unchecked_Access attribute, which bypasses " &
            "Ada's normal accessibility rules."),
         Guidance    => To_Unbounded_String
           ("Use 'Access under a matching accessibility level, an aliased " &
            "library-level or enclosing-scope object, or isolate and " &
            "justify the escape when the accessibility bypass is required."),
         Quality     => Quality_Security,
         Severity    => Severity_High),
      Floating_Equality =>
        (Name        => To_Unbounded_String ("Floating_Equality"),
         Description => To_Unbounded_String
           ("Find equality and inequality comparisons whose operands have a " &
            "floating-point type."),
         Guidance    => To_Unbounded_String
           ("Compare the absolute or relative difference against a " &
            "tolerance appropriate for the values and numerical algorithm."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Magic_Number =>
        (Name        => To_Unbounded_String ("Magic_Number"),
         Description => To_Unbounded_String
           ("Find unexplained numeric literals other than 0, 1, and -1 that " &
            "are not part of a named constant declaration."),
         Guidance    => To_Unbounded_String
           ("Introduce a descriptively named constant so the value's " &
            "meaning and maintenance policy are explicit."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Unused_Parameter =>
        (Name        => To_Unbounded_String ("Unused_Parameter"),
         Description => To_Unbounded_String
           ("Find subprogram parameters that are never referenced by their " &
            "body."),
         Guidance    => To_Unbounded_String
           ("Remove the parameter, use it as intended, or document why an " &
            "externally required profile must retain it."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Wrong_Parameter_Mode =>
        (Name        => To_Unbounded_String ("Wrong_Parameter_Mode"),
         Description => To_Unbounded_String
           ("Find in out parameters that are only read or only written by " &
            "their subprogram body."),
         Guidance    => To_Unbounded_String
           ("Use mode in for read-only parameters and mode out for " &
            "write-only parameters so the profile states the true contract."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      Dead_Store =>
        (Name        => To_Unbounded_String ("Dead_Store"),
         Description => To_Unbounded_String
           ("Find assignments whose stored value is never read later in the " &
            "enclosing subprogram."),
         Guidance    => To_Unbounded_String
           ("Remove the assignment or restore the later use that was " &
            "intended to consume the value."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      Overwritten_Assignment =>
        (Name        => To_Unbounded_String ("Overwritten_Assignment"),
         Description => To_Unbounded_String
           ("Find assignments overwritten in the same statement list before " &
            "their value is read."),
         Guidance    => To_Unbounded_String
           ("Remove the earlier assignment or use its value before " &
            "assigning the variable again."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Shadowed_Declaration =>
        (Name        => To_Unbounded_String ("Shadowed_Declaration"),
         Description => To_Unbounded_String
           ("Find local object declarations that hide an object or " &
            "parameter declared by an enclosing subprogram."),
         Guidance    => To_Unbounded_String
           ("Rename the inner declaration so references clearly identify " &
            "the intended object."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Unreachable_Case_Alternative =>
        (Name        => To_Unbounded_String
           ("Unreachable_Case_Alternative"),
         Description => To_Unbounded_String
           ("Find case choices wholly covered by an earlier alternative."),
         Guidance    => To_Unbounded_String
           ("Remove the alternative or correct its choice so it selects a " &
            "distinct value range."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Overlapping_Case_Ranges =>
        (Name        => To_Unbounded_String ("Overlapping_Case_Ranges"),
         Description => To_Unbounded_String
           ("Find statically evaluable case choices whose integer ranges " &
            "intersect."),
         Guidance    => To_Unbounded_String
           ("Adjust the choice boundaries so every value belongs to exactly " &
            "one alternative."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Infinite_Loop =>
        (Name        => To_Unbounded_String ("Infinite_Loop"),
         Description => To_Unbounded_String
           ("Find unconditional loops with no exit, return, or raise in " &
            "their body."),
         Guidance    => To_Unbounded_String
           ("Add an explicit termination path or document and isolate an " &
            "intentional nonterminating service loop."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Duplicate_Boolean_Operand =>
        (Name        => To_Unbounded_String ("Duplicate_Boolean_Operand"),
         Description => To_Unbounded_String
           ("Find repeated boolean operands and double negations."),
         Guidance    => To_Unbounded_String
           ("Remove the duplicate operator or correct the operand that was " &
            "probably copied incorrectly."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Redundant_Abs =>
        (Name        => To_Unbounded_String ("Redundant_Abs"),
         Description => To_Unbounded_String
           ("Find 'abs' applied to an operand that is itself an 'abs' " &
            "expression."),
         Guidance    => To_Unbounded_String
           ("Remove the outer 'abs'; applying it twice never changes the " &
            "result."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Redundant_Unary_Minus =>
        (Name        => To_Unbounded_String ("Redundant_Unary_Minus"),
         Description => To_Unbounded_String
           ("Find unary negation applied to an operand that is itself a " &
            "unary negation."),
         Guidance    => To_Unbounded_String
           ("Remove both negations; they cancel out (and share the same " &
            "overflow behavior as the operand alone, so removing them " &
            "does not change whether the expression can raise " &
            "Constraint_Error)."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Exception_Swallowed =>
        (Name        => To_Unbounded_String ("Exception_Swallowed"),
         Description => To_Unbounded_String
           ("Find when-others handlers that neither re-raise nor perform " &
            "substantive handling."),
         Guidance    => To_Unbounded_String
           ("Handle or log the exception, or re-raise it after required " &
            "cleanup."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Cyclomatic_Complexity =>
        (Name        => To_Unbounded_String ("Cyclomatic_Complexity"),
         Description => To_Unbounded_String
           ("Find subprograms whose decision complexity exceeds the " &
            "configured threshold."),
         Guidance    => To_Unbounded_String
           ("Extract cohesive helpers or simplify branching so each " &
            "subprogram has fewer independent paths."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      Constant_Condition =>
        (Name        => To_Unbounded_String ("Constant_Condition"),
         Description => To_Unbounded_String
           ("Find conditions that are statically known to be always true or " &
            "always false."),
         Guidance    => To_Unbounded_String
           ("Remove dead branches, simplify the condition, or replace " &
            "temporary debug logic with an explicit configuration guard."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Unreachable_Code =>
        (Name        => To_Unbounded_String ("Unreachable_Code"),
         Description => To_Unbounded_String
           ("Find statements that cannot execute after an unconditional " &
            "return, raise, goto, or loop exit in the same statement list."),
         Guidance    => To_Unbounded_String
           ("Move the statement before the terminating statement, remove " &
            "it, or make the terminating statement conditional."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      Division_By_Zero =>
        (Name        => To_Unbounded_String ("Division_By_Zero"),
         Description => To_Unbounded_String
           ("Find division, mod, and rem operations whose right operand is " &
            "statically zero."),
         Guidance    => To_Unbounded_String
           ("Guard the operation, change the divisor, or make the " &
            "exceptional case explicit before evaluating the operation."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Blocker),
      Integer_Division_Before_Multiplication =>
        (Name        => To_Unbounded_String
           ("Integer_Division_Before_Multiplication"),
         Description => To_Unbounded_String
           ("Find integer multiplications whose left operand is itself an " &
            "unparenthesized integer division."),
         Guidance    => To_Unbounded_String
           ("Reorder to multiply before dividing when the extra precision " &
            "is needed and does not risk overflow, or wrap the division in " &
            "explicit parentheses to document that the truncation is " &
            "intentional."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Excessive_Shift_Amount =>
        (Name        => To_Unbounded_String ("Excessive_Shift_Amount"),
         Description => To_Unbounded_String
           ("Find Interfaces shift/rotate calls whose statically known " &
            "amount is not less than the operand type's bit width."),
         Guidance    => To_Unbounded_String
           ("Correct the shift amount, or reduce it modulo the operand's " &
            "bit width if the wraparound is intentional."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Known_Negative_Shift_Amount_Failure =>
        (Name        => To_Unbounded_String
           ("Known_Negative_Shift_Amount_Failure"),
         Description => To_Unbounded_String
           ("Find Interfaces shift/rotate calls whose statically known " &
            "amount is negative."),
         Guidance    => To_Unbounded_String
           ("Correct the shift amount to a non-negative value; the " &
            "Amount parameter of every Interfaces shift/rotate function " &
            "is subtype Natural."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Known_Negative_Exponent_Failure =>
        (Name        => To_Unbounded_String
           ("Known_Negative_Exponent_Failure"),
         Description => To_Unbounded_String
           ("Find '**' exponentiations on an integer base whose " &
            "statically known exponent is negative."),
         Guidance    => To_Unbounded_String
           ("Correct the exponent to a non-negative value, or convert the " &
            "base to a floating-point or fixed-point type if a negative " &
            "exponent (reciprocal power) is actually intended."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Succ_Pred_Boundary_Overflow =>
        (Name        => To_Unbounded_String ("Succ_Pred_Boundary_Overflow"),
         Description => To_Unbounded_String
           ("Find 'Succ applied to 'Last or 'Pred applied to 'First of the " &
            "same scalar type, which always raises Constraint_Error."),
         Guidance    => To_Unbounded_String
           ("Guard the call with a range check, or correct the intended " &
            "bound."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Blocker),
      Reversed_Range =>
        (Name        => To_Unbounded_String ("Reversed_Range"),
         Description => To_Unbounded_String
           ("Find static ranges whose lower bound is greater than their " &
            "upper bound."),
         Guidance    => To_Unbounded_String
           ("Swap the bounds, use a reverse iteration form, or document an " &
            "intentional null range with a clearer condition."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Self_Assignment =>
        (Name        => To_Unbounded_String ("Self_Assignment"),
         Description => To_Unbounded_String
           ("Find assignments whose target and value designate the same " &
            "object, including through a simple object rename."),
         Guidance    => To_Unbounded_String
           ("Remove the assignment or replace the right-hand side with the " &
            "value that was intended to update the object."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Same_Operand =>
        (Name        => To_Unbounded_String ("Same_Operand"),
         Description => To_Unbounded_String
           ("Find suspicious binary expressions that use the same " &
            "expression on both sides."),
         Guidance    => To_Unbounded_String
           ("Check for a copied operand, simplify the expression, or add an " &
            "explicit comment if the repetition is intentional."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Duplicate_Condition =>
        (Name        => To_Unbounded_String ("Duplicate_Condition"),
         Description => To_Unbounded_String
           ("Find repeated conditions in the same if/elsif chain."),
         Guidance    => To_Unbounded_String
           ("Replace the repeated condition with the missing case or remove " &
            "the unreachable branch."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Duplicate_With_Clause =>
        (Name        => To_Unbounded_String ("Duplicate_With_Clause"),
         Description => To_Unbounded_String
           ("Find with clauses naming a unit already with'd in the same " &
            "context clause."),
         Guidance    => To_Unbounded_String
           ("Remove the redundant with clause."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Duplicate_Exception_Choice =>
        (Name        => To_Unbounded_String ("Duplicate_Exception_Choice"),
         Description => To_Unbounded_String
           ("Find an exception handler whose own choice list names the " &
            "same exception more than once."),
         Guidance    => To_Unbounded_String
           ("Remove the redundant choice."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Null_Statement =>
        (Name        => To_Unbounded_String ("Null_Statement"),
         Description => To_Unbounded_String
           ("Find null statements in executable code."),
         Guidance    => To_Unbounded_String
           ("Remove the placeholder or replace it with explicit handling so " &
            "the empty action is intentional."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Redundant_Final_Return =>
        (Name        => To_Unbounded_String ("Redundant_Final_Return"),
         Description => To_Unbounded_String
           ("Find a bare 'return;' as the last statement of a procedure " &
            "body, where control would fall through to the same effect " &
            "anyway."),
         Guidance    => To_Unbounded_String
           ("Remove the redundant return statement."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Empty_Exception_Handler =>
        (Name        => To_Unbounded_String ("Empty_Exception_Handler"),
         Description => To_Unbounded_String
           ("Find exception handlers that only contain null statements or " &
            "pragmas."),
         Guidance    => To_Unbounded_String
           ("Handle, log, re-raise, or narrowly document the exception " &
            "instead of silently swallowing it."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Unreachable_Branch =>
        (Name        => To_Unbounded_String ("Unreachable_Branch"),
         Description => To_Unbounded_String
           ("Find if/elsif/else branches made unreachable by static " &
            "conditions earlier in the chain."),
         Guidance    => To_Unbounded_String
           ("Remove the branch or change the condition sequence so each " &
            "branch can be selected."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Contradictory_Condition =>
        (Name        => To_Unbounded_String ("Contradictory_Condition"),
         Description => To_Unbounded_String
           ("Find boolean expressions of the form X and not X or X or not " &
            "X."),
         Guidance    => To_Unbounded_String
           ("Correct the copied or negated operand, or replace the " &
            "expression with the intended constant value."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Contradictory_Range_Condition =>
        (Name        => To_Unbounded_String ("Contradictory_Range_Condition"),
         Description => To_Unbounded_String
           ("Find 'and'/'and then' conditions combining two relational " &
            "comparisons on the same expression whose statically known " &
            "bounds cannot both hold."),
         Guidance    => To_Unbounded_String
           ("Correct the comparison operators or bounds, or replace one " &
            "operator with 'or'/'or else' if either condition alone was " &
            "intended."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Identical_Branches =>
        (Name        => To_Unbounded_String ("Identical_Branches"),
         Description => To_Unbounded_String
           ("Find adjacent if, elsif, or else branches with identical " &
            "bodies."),
         Guidance    => To_Unbounded_String
           ("Merge the conditions or restore the branch-specific operation " &
            "that was probably lost during editing."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Repeated_Statement =>
        (Name        => To_Unbounded_String ("Repeated_Statement"),
         Description => To_Unbounded_String
           ("Find identical assignments repeated consecutively."),
         Guidance    => To_Unbounded_String
           ("Remove the duplicate or correct the operand that should differ " &
            "in the second statement."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Ineffective_Operation =>
        (Name        => To_Unbounded_String ("Ineffective_Operation"),
         Description => To_Unbounded_String
           ("Find arithmetic or boolean operations whose identity operand " &
            "cannot affect the result."),
         Guidance    => To_Unbounded_String
           ("Remove the ineffective operation or correct a constant or " &
            "operand that was entered incorrectly."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Constant_Result_Operation =>
        (Name        => To_Unbounded_String ("Constant_Result_Operation"),
         Description => To_Unbounded_String
           ("Find operations forced to a constant result by zero, one, or a " &
            "boolean absorbing operand."),
         Guidance    => To_Unbounded_String
           ("Replace the expression with the constant when intentional, or " &
            "correct the operand that unexpectedly forces the result."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Empty_Loop =>
        (Name        => To_Unbounded_String ("Empty_Loop"),
         Description => To_Unbounded_String
           ("Find loops whose bodies contain only null statements or " &
            "pragmas."),
         Guidance    => To_Unbounded_String
           ("Implement the missing loop body or remove the loop; an " &
            "intentional wait should use an explicit delay or " &
            "synchronization operation."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      No_Recursion =>
        (Name        => To_Unbounded_String ("No_Recursion"),
         Description => To_Unbounded_String
           ("Find subprograms that call themselves directly, which can make " &
            "stack usage and termination harder to bound and verify."),
         Guidance    => To_Unbounded_String
           ("Replace the recursive call with an explicit loop and work " &
            "list, or document and isolate an intentional recursive " &
            "algorithm."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      No_Multiple_Return =>
        (Name        => To_Unbounded_String ("No_Multiple_Return"),
         Description => To_Unbounded_String
           ("Find subprograms with more than one return statement, which " &
            "can make the exit points of a subprogram harder to audit."),
         Guidance    => To_Unbounded_String
           ("Restructure the subprogram around a single result variable and " &
            "a single return statement at its end."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Non_Short_Circuit_Condition =>
        (Name        => To_Unbounded_String ("Non_Short_Circuit_Condition"),
         Description => To_Unbounded_String
           ("Find plain and/or operators used in an if, elsif, exit-when, " &
            "or while condition, where a guard clause typically requires " &
            "short-circuit evaluation."),
         Guidance    => To_Unbounded_String
           ("Replace 'and'/'or' with 'and then'/'or else' unless evaluating " &
            "both operands unconditionally is required and safe."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Address_Clause =>
        (Name        => To_Unbounded_String ("Address_Clause"),
         Description => To_Unbounded_String
           ("Find address representation clauses, which let two objects " &
            "alias the same storage outside the type system's checks."),
         Guidance    => To_Unbounded_String
           ("Prefer a normal declaration or an explicitly reviewed, " &
            "isolated and documented overlay when aliasing is genuinely " &
            "required."),
         Quality     => Quality_Security,
         Severity    => Severity_High),
      Too_Many_Parameters =>
        (Name        => To_Unbounded_String ("Too_Many_Parameters"),
         Description => To_Unbounded_String
           ("Find subprograms whose parameter count exceeds the configured " &
            "threshold."),
         Guidance    => To_Unbounded_String
           ("Group related parameters into a record, or split the " &
            "subprogram into smaller, more cohesive operations."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      Swappable_Parameters =>
        (Name        => To_Unbounded_String ("Swappable_Parameters"),
         Description => To_Unbounded_String
           ("Find consecutive parameters with the same mode and type, " &
            "which a positional call can transpose without a compile " &
            "error."),
         Guidance    => To_Unbounded_String
           ("Reorder the parameters to separate same-typed neighbors, " &
            "give them distinct types (e.g. derived types), or require " &
            "named association at call sites."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Deep_Nesting =>
        (Name        => To_Unbounded_String ("Deep_Nesting"),
         Description => To_Unbounded_String
           ("Find subprograms whose control-flow nesting depth exceeds the " &
            "configured threshold."),
         Guidance    => To_Unbounded_String
           ("Extract nested blocks into helper subprograms or invert " &
            "conditions with early returns to flatten the structure."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      Unused_Variable =>
        (Name        => To_Unbounded_String ("Unused_Variable"),
         Description => To_Unbounded_String
           ("Find local object declarations that are never referenced by " &
            "the enclosing subprogram's declarations or statements."),
         Guidance    => To_Unbounded_String
           ("Remove the declaration or use the object as intended."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Empty_If_Body =>
        (Name        => To_Unbounded_String ("Empty_If_Body"),
         Description => To_Unbounded_String
           ("Find if statements with no elsif or else part whose then " &
            "branch has no substantive statements, so the statement has no " &
            "effect."),
         Guidance    => To_Unbounded_String
           ("Remove the if statement or implement the missing branch body."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Empty_Elsif_Body =>
        (Name        => To_Unbounded_String ("Empty_Elsif_Body"),
         Description => To_Unbounded_String
           ("Find elsif branches with no substantive statements, so the " &
            "branch has no effect."),
         Guidance    => To_Unbounded_String
           ("Remove the elsif branch or implement its missing body."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Empty_Then_Body =>
        (Name        => To_Unbounded_String ("Empty_Then_Body"),
         Description => To_Unbounded_String
           ("Find if statements whose then branch has no substantive " &
            "statements even though an elsif or else follows, so the then " &
            "branch has no effect (unlike Empty_If_Body, which is scoped " &
            "to a bare if with no elsif or else)."),
         Guidance    => To_Unbounded_String
           ("Implement the then branch's missing body, or restructure the " &
            "condition so the empty case is not a distinct branch."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Empty_Else_Body =>
        (Name        => To_Unbounded_String ("Empty_Else_Body"),
         Description => To_Unbounded_String
           ("Find else parts with no substantive statements, so the else " &
            "branch has no effect."),
         Guidance    => To_Unbounded_String
           ("Remove the else part or implement its missing body."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Null_Case_Alternative =>
        (Name        => To_Unbounded_String ("Null_Case_Alternative"),
         Description => To_Unbounded_String
           ("Find case statement alternatives naming a specific choice " &
            "with no substantive statements, so the alternative has no " &
            "effect. A catch-all `others => null;` is not flagged, since " &
            "that is a common, deliberate idiom."),
         Guidance    => To_Unbounded_String
           ("Implement the alternative's body, or merge its choice into " &
            "another alternative if it truly needs no distinct handling."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Unnecessary_Else_After_Return =>
        (Name        => To_Unbounded_String ("Unnecessary_Else_After_Return"),
         Description => To_Unbounded_String
           ("Find else parts that are unnecessary because the preceding " &
            "then branch always returns, raises, or exits."),
         Guidance    => To_Unbounded_String
           ("Remove the else and dedent its statements to the enclosing " &
            "block, now that the earlier branch always transfers control " &
            "away."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Redundant_If_Boolean_Return =>
        (Name        => To_Unbounded_String ("Redundant_If_Boolean_Return"),
         Description => To_Unbounded_String
           ("Find an if statement whose then and else branches each " &
            "return only an opposite boolean literal."),
         Guidance    => To_Unbounded_String
           ("Return the condition directly (negated if the branches are " &
            "reversed) instead of branching to a boolean literal."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Function_Side_Effect =>
        (Name        => To_Unbounded_String ("Function_Side_Effect"),
         Description => To_Unbounded_String
           ("Find functions that assign to state other than their own local " &
            "variables and parameters."),
         Guidance    => To_Unbounded_String
           ("Move the side effect to a procedure, or return the changed " &
            "value instead of assigning it to shared state."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Redundant_Boolean_Comparison =>
        (Name        => To_Unbounded_String ("Redundant_Boolean_Comparison"),
         Description => To_Unbounded_String
           ("Find equality or inequality comparisons against the literal " &
            "True or False."),
         Guidance    => To_Unbounded_String
           ("Use the boolean expression directly, negating it with 'not' " &
            "when comparing against False."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Long_Line =>
        (Name        => To_Unbounded_String ("Long_Line"),
         Description => To_Unbounded_String
           ("Find source lines longer than the configured threshold."),
         Guidance    => To_Unbounded_String
           ("Wrap the line or shorten the expression so it fits within the " &
            "project's line-length convention."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Trailing_Whitespace =>
        (Name        => To_Unbounded_String ("Trailing_Whitespace"),
         Description => To_Unbounded_String
           ("Find source lines with trailing spaces or tabs."),
         Guidance    => To_Unbounded_String
           ("Remove the trailing whitespace."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      SPARK_Mode =>
        (Name        => To_Unbounded_String ("SPARK_Mode"),
         Description => To_Unbounded_String
           ("Find declarations or regions that explicitly disable " &
            "SPARK_Mode and therefore leave the formally analyzable subset."),
         Guidance    => To_Unbounded_String
           ("Remove SPARK_Mode => Off, or isolate and justify the smallest " &
            "possible non-SPARK boundary."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Missing_Global_Contract =>
        (Name        => To_Unbounded_String ("Missing_Global_Contract"),
         Description => To_Unbounded_String
           ("Find subprograms that access global state without an " &
            "explicit Global contract, the SPARK aspect for documenting " &
            "global effects; fires even before SPARK_Mode is adopted, as " &
            "a readiness check for it."),
         Guidance    => To_Unbounded_String
           ("Add a Global aspect that classifies every global object as " &
            "Input, Output, In_Out, or Proof_In."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      Global_Contract_Mismatch =>
        (Name        => To_Unbounded_String ("Global_Contract_Mismatch"),
         Description => To_Unbounded_String
           ("Find global reads or writes that are omitted from a Global " &
            "contract or declared with an incompatible mode."),
         Guidance    => To_Unbounded_String
           ("Make the Global contract agree with the implementation's " &
            "actual reads and writes."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Missing_Depends_Contract =>
        (Name        => To_Unbounded_String ("Missing_Depends_Contract"),
         Description => To_Unbounded_String
           ("Find subprograms with outputs but no explicit Depends " &
            "contract, the SPARK aspect for documenting " &
            "input-to-output dependencies; fires even before SPARK_Mode " &
            "is adopted, as a readiness check for it."),
         Guidance    => To_Unbounded_String
           ("Add a Depends aspect documenting the inputs on which each " &
            "output depends."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      Incomplete_Depends_Contract =>
        (Name        => To_Unbounded_String ("Incomplete_Depends_Contract"),
         Description => To_Unbounded_String
           ("Find writable parameters or global outputs omitted from a " &
            "Depends contract."),
         Guidance    => To_Unbounded_String
           ("Add a dependency association for every output, using null " &
            "when its value is independent of all inputs."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Depends_Contract_Mismatch =>
        (Name        => To_Unbounded_String ("Depends_Contract_Mismatch"),
         Description => To_Unbounded_String
           ("Find SPARK Depends associations that disagree with inferred " &
            "input-to-output information flow."),
         Guidance    => To_Unbounded_String
           ("Add missing input dependencies, remove demonstrably extra " &
            "ones, or use null only for input-independent outputs."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Uninitialized_Output =>
        (Name        => To_Unbounded_String ("Uninitialized_Output"),
         Description => To_Unbounded_String
           ("Find out parameters whose complete initialization cannot be " &
            "established on every normal return path."),
         Guidance    => To_Unbounded_String
           ("Assign the complete out parameter on every path before the " &
            "subprogram returns."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Uninitialized_Read =>
        (Name        => To_Unbounded_String ("Uninitialized_Read"),
         Description => To_Unbounded_String
           ("Find scalar local variables with no initial value whose " &
            "first use is a read rather than an assignment or an out-mode " &
            "call."),
         Guidance    => To_Unbounded_String
           ("Give the declaration an initial value, or assign it before " &
            "the first read."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Missing_Overriding_Indicator =>
        (Name        => To_Unbounded_String ("Missing_Overriding_Indicator"),
         Description => To_Unbounded_String
           ("Find primitive subprograms that override an inherited " &
            "operation without the 'overriding' keyword."),
         Guidance    => To_Unbounded_String
           ("Mark the subprogram 'overriding' so the override is explicit " &
            "and checked by the compiler."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      Inefficient_String_Concatenation =>
        (Name        => To_Unbounded_String
           ("Inefficient_String_Concatenation"),
         Description => To_Unbounded_String
           ("Find string variables rebuilt with '&' inside a loop, an " &
            "accumulation pattern with quadratic cost."),
         Guidance    => To_Unbounded_String
           ("Accumulate into an Ada.Strings.Unbounded.Unbounded_String or " &
            "a bounded buffer instead of repeatedly concatenating into a " &
            "String."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Circular_Package_Dependency =>
        (Name        => To_Unbounded_String ("Circular_Package_Dependency"),
         Description => To_Unbounded_String
           ("Find groups of analyzed compilation units whose with clauses " &
            "form a dependency cycle."),
         Guidance    => To_Unbounded_String
           ("Break the cycle by extracting a shared abstraction, moving " &
            "the dependency to a child unit, or using a limited with."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      Duplicate_Subprogram =>
        (Name        => To_Unbounded_String ("Duplicate_Subprogram"),
         Description => To_Unbounded_String
           ("Find subprogram bodies, anywhere in the analyzed project, " &
            "whose statement list is textually identical (modulo " &
            "whitespace and identifier casing) to another subprogram's."),
         Guidance    => To_Unbounded_String
           ("Extract the shared logic into one subprogram both callers " &
            "use, or confirm the duplication is intentional and document " &
            "why it can't be shared."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      Known_Precondition_Failure =>
        (Name        => To_Unbounded_String ("Known_Precondition_Failure"),
         Description => To_Unbounded_String
           ("Find calls whose actual arguments make a SPARK precondition " &
            "statically false."),
         Guidance    => To_Unbounded_String
           ("Change the arguments or establish the required condition " &
            "before making the call."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Known_Postcondition_Failure =>
        (Name        => To_Unbounded_String ("Known_Postcondition_Failure"),
         Description => To_Unbounded_String
           ("Find subprogram bodies whose resulting abstract state makes " &
            "their SPARK postcondition statically false."),
         Guidance    => To_Unbounded_String
           ("Correct the implementation or revise a postcondition that does " &
            "not describe the intended result."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Known_Assertion_Failure =>
        (Name        => To_Unbounded_String ("Known_Assertion_Failure"),
         Description => To_Unbounded_String
           ("Find Assert, Assert_And_Cut, Check, and Loop_Invariant pragmas " &
            "whose condition is statically false."),
         Guidance    => To_Unbounded_String
           ("Correct the implementation or assertion so the asserted " &
            "property holds at this program point."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Assertion_Side_Effect =>
        (Name        => To_Unbounded_String ("Assertion_Side_Effect"),
         Description => To_Unbounded_String
           ("Find Assert, Assert_And_Cut, Check, and Loop_Invariant pragmas " &
            "whose condition calls a function with an out or in out " &
            "parameter."),
         Guidance    => To_Unbounded_String
           ("Move the mutation out of the assertion condition. Disabling " &
            "assertions (pragma Assertion_Policy (Ignore), or building " &
            "without -gnata) would silently stop that side effect from " &
            "happening, changing the program's behavior."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Entry_Barrier_Side_Effect =>
        (Name        => To_Unbounded_String ("Entry_Barrier_Side_Effect"),
         Description => To_Unbounded_String
           ("Find protected entry barrier conditions that call a function " &
            "with an out or in out parameter."),
         Guidance    => To_Unbounded_String
           ("Move the mutation out of the barrier condition; a barrier is " &
            "evaluated on every call and exit of the protected object and " &
            "must stay free of side effects."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Known_Range_Check_Failure =>
        (Name        => To_Unbounded_String ("Known_Range_Check_Failure"),
         Description => To_Unbounded_String
           ("Find assignments, initializations, and conversions whose value " &
            "is provably outside the target integer subtype."),
         Guidance    => To_Unbounded_String
           ("Constrain the value before conversion or assignment, or correct " &
            "the target subtype bounds."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Known_Index_Check_Failure =>
        (Name        => To_Unbounded_String ("Known_Index_Check_Failure"),
         Description => To_Unbounded_String
           ("Find array indexing operations whose index is provably outside " &
            "the corresponding index subtype."),
         Guidance    => To_Unbounded_String
           ("Establish that each index is within the array bounds before " &
            "indexing the array."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Known_Overflow_Failure =>
        (Name        => To_Unbounded_String ("Known_Overflow_Failure"),
         Description => To_Unbounded_String
           ("Find integer arithmetic whose result is provably outside the " &
            "operation's base type."),
         Guidance    => To_Unbounded_String
           ("Reorder or widen the computation, or establish tighter operand " &
            "bounds before performing it."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Identical_Case_Alternative =>
        (Name        => To_Unbounded_String ("Identical_Case_Alternative"),
         Description => To_Unbounded_String
           ("Find adjacent case alternatives with identical bodies or " &
            "expressions."),
         Guidance    => To_Unbounded_String
           ("Merge the choices into one alternative or restore the " &
            "choice-specific handling that was probably lost during " &
            "editing."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Redundant_Type_Conversion =>
        (Name        => To_Unbounded_String ("Redundant_Type_Conversion"),
         Description => To_Unbounded_String
           ("Find explicit type conversions whose operand already has the " &
            "target subtype, so the conversion has no effect."),
         Guidance    => To_Unbounded_String
           ("Remove the conversion, or correct the operand or target type " &
            "that was probably intended to differ."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Handler_Order =>
        (Name        => To_Unbounded_String ("Handler_Order"),
         Description => To_Unbounded_String
           ("Find a when others handler that precedes a more specific " &
            "handler in the same exception handler list, making the later " &
            "handler unreachable."),
         Guidance    => To_Unbounded_String
           ("Move the when others handler after every specific handler it " &
            "currently precedes."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Reraise_Discards_Occurrence =>
        (Name        => To_Unbounded_String ("Reraise_Discards_Occurrence"),
         Description => To_Unbounded_String
           ("Find an exception handler's last statement re-raising the " &
            "same single exception it caught by name."),
         Guidance    => To_Unbounded_String
           ("Use a bare 'raise;' to re-propagate the original exception " &
            "occurrence (message and traceback intact) instead of naming " &
            "the exception, which raises a fresh occurrence."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Aliasing_Between_Parameters =>
        (Name        => To_Unbounded_String ("Aliasing_Between_Parameters"),
         Description => To_Unbounded_String
           ("Find calls that pass the same object or component as two " &
            "actual parameters when at least one of the corresponding " &
            "formals is written, which SPARK forbids and plain Ada leaves " &
            "unspecified."),
         Guidance    => To_Unbounded_String
           ("Pass a distinct copy of the object, or restructure the call " &
            "so no written formal aliases another actual."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Missing_Loop_Variant =>
        (Name        => To_Unbounded_String ("Missing_Loop_Variant"),
         Description => To_Unbounded_String
           ("Find loops that carry a Loop_Invariant pragma but no " &
            "Loop_Variant pragma, so GNATprove cannot prove termination."),
         Guidance    => To_Unbounded_String
           ("Add a Loop_Variant pragma identifying an expression that " &
            "strictly decreases or increases on every iteration."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      Known_Discriminant_Check_Failure =>
        (Name        => To_Unbounded_String
           ("Known_Discriminant_Check_Failure"),
         Description => To_Unbounded_String
           ("Find accesses to a variant-part component that a statically " &
            "known discriminant constraint provably excludes."),
         Guidance    => To_Unbounded_String
           ("Access a component that the object's discriminant constraint " &
            "actually permits, or correct the constraint."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Known_Enum_Val_Failure =>
        (Name        => To_Unbounded_String ("Known_Enum_Val_Failure"),
         Description => To_Unbounded_String
           ("Find 'Val attribute calls whose statically known argument is " &
            "outside the enumeration type's literal positions."),
         Guidance    => To_Unbounded_String
           ("Constrain the argument to the type's valid position range, " &
            "or correct the literal that was entered incorrectly."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Known_Value_Conversion_Failure =>
        (Name        => To_Unbounded_String
           ("Known_Value_Conversion_Failure"),
         Description => To_Unbounded_String
           ("Find 'Value attribute calls whose static string literal " &
            "argument can never denote a value of the prefix integer or " &
            "enumeration type."),
         Guidance    => To_Unbounded_String
           ("Correct the string literal to a value the target type " &
            "actually accepts, or handle the malformed input explicitly " &
            "instead of relying on 'Value to raise Constraint_Error."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Potentially_Blocking_Operation =>
        (Name        => To_Unbounded_String
           ("Potentially_Blocking_Operation"),
         Description => To_Unbounded_String
           ("Find entry calls, delay statements, and calls transitively " &
            "reaching them from a protected procedure or function body; " &
            "the Ravenscar and SPARK profiles forbid blocking while " &
            "holding the protected lock."),
         Guidance    => To_Unbounded_String
           ("Move the blocking operation outside the protected operation, " &
            "or restructure the protocol so the protected body only " &
            "performs non-blocking actions."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      No_Dynamic_Allocation =>
        (Name        => To_Unbounded_String ("No_Dynamic_Allocation"),
         Description => To_Unbounded_String
           ("Find allocators whose storage use and failure behavior make " &
            "execution-time and memory bounds harder to establish."),
         Guidance    => To_Unbounded_String
           ("Use statically allocated objects or a bounded pool initialized " &
            "before safety-related operation begins."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Restricted_Access_Type =>
        (Name        => To_Unbounded_String ("Restricted_Access_Type"),
         Description => To_Unbounded_String
           ("Find named and anonymous access-to-object type definitions " &
            "that introduce aliasing and lifetime obligations."),
         Guidance    => To_Unbounded_String
           ("Prefer direct ownership and bounded containers; isolate any " &
            "required access type behind a reviewed interface."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      No_Explicit_Dereference =>
        (Name        => To_Unbounded_String ("No_Explicit_Dereference"),
         Description => To_Unbounded_String
           ("Find explicit .all dereferences that can fail an access check " &
            "and obscure the identity and lifetime of the target."),
         Guidance    => To_Unbounded_String
           ("Replace access-based navigation with direct objects, or prove " &
            "the access value non-null at a tightly controlled boundary."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      No_Unchecked_Deallocation =>
        (Name        => To_Unbounded_String ("No_Unchecked_Deallocation"),
         Description => To_Unbounded_String
           ("Find instantiations of Ada.Unchecked_Deallocation, which can " &
            "create dangling access values and use-after-free defects."),
         Guidance    => To_Unbounded_String
           ("Use static or region-based storage, or confine deallocation to " &
            "a separately justified ownership component."),
         Quality     => Quality_Security,
         Severity    => Severity_High),
      No_Tasking =>
        (Name        => To_Unbounded_String ("No_Tasking"),
         Description => To_Unbounded_String
           ("Find task declarations, whose scheduling and synchronization " &
            "must be justified in deterministic automotive software."),
         Guidance    => To_Unbounded_String
           ("Use a project-approved cyclic executive or a separately " &
            "analyzed restricted tasking profile."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      No_Rendezvous =>
        (Name        => To_Unbounded_String ("No_Rendezvous"),
         Description => To_Unbounded_String
           ("Find task entries and accept statements that introduce " &
            "potentially blocking rendezvous."),
         Guidance    => To_Unbounded_String
           ("Use protected non-blocking communication or a statically " &
            "scheduled message-transfer mechanism."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      No_Select =>
        (Name        => To_Unbounded_String ("No_Select"),
         Description => To_Unbounded_String
           ("Find selective, timed, conditional, or asynchronous select " &
            "statements with timing-dependent control flow."),
         Guidance    => To_Unbounded_String
           ("Replace select statements with deterministic state-machine " &
            "logic and explicitly scheduled communication."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      No_Requeue =>
        (Name        => To_Unbounded_String ("No_Requeue"),
         Description => To_Unbounded_String
           ("Find requeue statements that transfer entry calls and make " &
            "blocking and queue behavior harder to analyze."),
         Guidance    => To_Unbounded_String
           ("Complete the operation locally or use an explicit bounded " &
            "state transition instead of requeue."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      No_Asynchronous_Transfer =>
        (Name        => To_Unbounded_String ("No_Asynchronous_Transfer"),
         Description => To_Unbounded_String
           ("Find asynchronous select then-abort parts that can interrupt " &
            "normal execution at difficult-to-review points."),
         Guidance    => To_Unbounded_String
           ("Use cooperative cancellation checked at explicit safe points."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Exception_Propagation =>
        (Name        => To_Unbounded_String ("Exception_Propagation"),
         Description => To_Unbounded_String
           ("Find calls that can explicitly raise an exception when the " &
            "enclosing subprogram provides no exception boundary."),
         Guidance    => To_Unbounded_String
           ("Convert the failure into an explicit status at the interface, " &
            "or add a narrowly scoped handler with a documented policy."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      No_Dispatching_Call =>
        (Name        => To_Unbounded_String ("No_Dispatching_Call"),
         Description => To_Unbounded_String
           ("Find dynamically dispatching and access-to-subprogram calls " &
            "whose target cannot be determined from local syntax."),
         Guidance    => To_Unbounded_String
           ("Use a statically bound operation or isolate dynamic dispatch " &
            "behind a reviewed, bounded interface."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      No_Classwide_Type =>
        (Name        => To_Unbounded_String ("No_Classwide_Type"),
         Description => To_Unbounded_String
           ("Find uses of T'Class that admit values from an open-ended " &
            "extension hierarchy."),
         Guidance    => To_Unbounded_String
           ("Use a specific tagged type or a closed discriminated union."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      No_Controlled_Type =>
        (Name        => To_Unbounded_String ("No_Controlled_Type"),
         Description => To_Unbounded_String
           ("Find types derived from Ada.Finalization.Controlled or " &
            "Limited_Controlled, whose implicit finalization adds hidden " &
            "control flow."),
         Guidance    => To_Unbounded_String
           ("Use explicit initialization and cleanup operations with " &
            "statically reviewable call sites."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Complete_Initialization =>
        (Name        => To_Unbounded_String ("Complete_Initialization"),
         Description => To_Unbounded_String
           ("Find objects and record components without an explicit default " &
            "value."),
         Guidance    => To_Unbounded_String
           ("Initialize every object and component explicitly at its " &
            "declaration, using a complete aggregate where appropriate."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Volatile_Atomic_Consistency =>
        (Name        => To_Unbounded_String ("Volatile_Atomic_Consistency"),
         Description => To_Unbounded_String
           ("Find volatile declarations that do not also state an atomic " &
            "or full-access synchronization policy."),
         Guidance    => To_Unbounded_String
           ("Add Atomic or Volatile_Full_Access where supported, or document " &
            "and isolate the hardware-specific access protocol."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Representation_Clause_Policy =>
        (Name        => To_Unbounded_String ("Representation_Clause_Policy"),
         Description => To_Unbounded_String
           ("Find explicit representation clauses that require target ABI " &
            "review and consistency evidence."),
         Guidance    => To_Unbounded_String
           ("Centralize the clause in a hardware-boundary package and verify " &
            "size, alignment, position, range, and target assumptions."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Library_Level_Initialization =>
        (Name        => To_Unbounded_String ("Library_Level_Initialization"),
         Description => To_Unbounded_String
           ("Find library-level object initializers containing calls, which " &
            "introduce elaboration-order dependencies."),
         Guidance    => To_Unbounded_String
           ("Use a static initializer and perform fallible setup from an " &
            "explicit, ordered initialization procedure."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Generic_Instantiation_Limit =>
        (Name => To_Unbounded_String ("Generic_Instantiation_Limit"),
         Description => To_Unbounded_String
           ("Find compilation units exceeding the configured number of " &
            "generic instantiations."),
         Guidance => To_Unbounded_String
           ("Reduce generic coupling or split the unit along cohesive " &
            "boundaries."),
         Quality => Quality_Maintainability, Severity => Severity_Medium),
      Dependency_Limit =>
        (Name => To_Unbounded_String ("Dependency_Limit"),
         Description => To_Unbounded_String
           ("Find compilation units exceeding the configured number of " &
            "with-clause dependencies."),
         Guidance => To_Unbounded_String
           ("Introduce narrower interfaces and split highly coupled units."),
         Quality => Quality_Maintainability, Severity => Severity_Medium),
      Naming_Convention =>
        (Name => To_Unbounded_String ("Naming_Convention"),
         Description => To_Unbounded_String
           ("Find one-character defining identifiers outside conventional " &
            "loop-index declarations."),
         Guidance => To_Unbounded_String
           ("Use descriptive identifiers; single-letter loop indices remain " &
            "permitted."),
         Quality => Quality_Maintainability, Severity => Severity_Low),
      No_Compiler_Extensions =>
        (Name => To_Unbounded_String ("No_Compiler_Extensions"),
         Description => To_Unbounded_String
           ("Find implementation-defined pragmas and pragmas that enable " &
            "compiler language extensions."),
         Guidance => To_Unbounded_String
           ("Use language-defined pragmas, compile with extensions disabled, " &
            "and isolate any approved vendor dependency."),
         Quality => Quality_Maintainability, Severity => Severity_High),
      No_Runtime_Check_Suppression =>
        (Name => To_Unbounded_String ("No_Runtime_Check_Suppression"),
         Description => To_Unbounded_String
           ("Find pragmas that suppress Ada run-time checks or configure a " &
            "check policy to ignore them."),
         Guidance => To_Unbounded_String
           ("Keep run-time checks enabled, or isolate and justify any " &
            "suppression with equivalent proof and target evidence."),
         Quality => Quality_Reliability, Severity => Severity_High),
      Missing_Requirement_Trace =>
        (Name => To_Unbounded_String ("Missing_Requirement_Trace"),
         Description => To_Unbounded_String
           ("Find subprogram bodies without a nearby DO-178C low-level " &
            "requirement identifier."),
         Guidance => To_Unbounded_String
           ("Add '--  do-178c: req <identifier>' on the subprogram line or " &
            "within the three immediately preceding lines."),
         Quality => Quality_Reliability, Severity => Severity_High),
      Malformed_Requirement_Trace =>
        (Name => To_Unbounded_String ("Malformed_Requirement_Trace"),
         Description => To_Unbounded_String
           ("Find DO-178C requirement annotations that contain no usable " &
            "requirement identifier."),
         Guidance => To_Unbounded_String
           ("Use '--  do-178c: req <identifier>' with a stable, non-empty " &
            "project requirement identifier."),
         Quality => Quality_Maintainability, Severity => Severity_Medium),
      Suppression_Without_Rationale =>
        (Name => To_Unbounded_String ("Suppression_Without_Rationale"),
         Description => To_Unbounded_String
           ("Find analyzer suppressions that do not record a reviewable " &
            "rationale."),
         Guidance => To_Unbounded_String
           ("Append ' -- rationale: <reason>' to every " &
            "'adalang-analyzer: ignore <rule>' suppression."),
         Quality => Quality_Maintainability, Severity => Severity_High),
      Use_After_Free =>
        (Name        => To_Unbounded_String ("Use_After_Free"),
         Description => To_Unbounded_String
           ("Find a local access object read or dereferenced after it was " &
            "passed to an instantiation of Ada.Unchecked_Deallocation, " &
            "with no intervening assignment."),
         Guidance    => To_Unbounded_String
           ("Assign the object (typically to null) immediately after " &
            "freeing it, and before any further use."),
         Quality     => Quality_Security,
         Severity    => Severity_High),
      Double_Free =>
        (Name        => To_Unbounded_String ("Double_Free"),
         Description => To_Unbounded_String
           ("Find a second call to Ada.Unchecked_Deallocation on the " &
            "same local access object, with no intervening " &
            "assignment."),
         Guidance    => To_Unbounded_String
           ("Assign the object (typically to null) or reassign it to a " &
            "new allocation immediately after freeing it, and before " &
            "any further call to Ada.Unchecked_Deallocation on it."),
         Quality     => Quality_Security,
         Severity    => Severity_High),
      Unclosed_File_Handle =>
        (Name        => To_Unbounded_String ("Unclosed_File_Handle"),
         Description => To_Unbounded_String
           ("Find a local Ada.Text_IO or Ada.Streams.Stream_IO File_Type " &
            "object opened with Open or Create that is not demonstrably " &
            "closed on every normal-return or exception-handler path out " &
            "of the enclosing subprogram."),
         Guidance    => To_Unbounded_String
           ("Call Close on every path that leaves the subprogram after " &
            "the file is opened, including exception handlers."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Unused_With_Clause =>
        (Name        => To_Unbounded_String ("Unused_With_Clause"),
         Description => To_Unbounded_String
           ("Find with clauses naming a unit never referenced elsewhere " &
            "in the compilation unit."),
         Guidance    => To_Unbounded_String
           ("Remove the unused with clause."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      No_Use_Package_Clause =>
        (Name        => To_Unbounded_String ("No_Use_Package_Clause"),
         Description => To_Unbounded_String
           ("Find use clauses that make a whole package's declarations " &
            "directly visible (use type clauses are not reported)."),
         Guidance    => To_Unbounded_String
           ("Refer to the package's entities by expanded name, or use a " &
            "'use type' clause when only operators are needed."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Others_In_Case_Statement =>
        (Name        => To_Unbounded_String ("Others_In_Case_Statement"),
         Description => To_Unbounded_String
           ("Find an others choice in a case statement alternative, " &
            "which hides values added to the selecting type later."),
         Guidance    => To_Unbounded_String
           ("List the remaining values explicitly so a new value forces " &
            "a review of the case statement."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Low),
      Others_In_Exception_Handler =>
        (Name        => To_Unbounded_String ("Others_In_Exception_Handler"),
         Description => To_Unbounded_String
           ("Find an others choice in an exception handler, which " &
            "catches exceptions the code never anticipated."),
         Guidance    => To_Unbounded_String
           ("Name the exceptions the handler is designed for, and let " &
            "unexpected ones propagate to a dedicated boundary."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Others_In_Aggregate =>
        (Name        => To_Unbounded_String ("Others_In_Aggregate"),
         Description => To_Unbounded_String
           ("Find an others choice in an aggregate, except the plain " &
            "(others => X) form and an others choice following exactly " &
            "one single-value association."),
         Guidance    => To_Unbounded_String
           ("Name every component or index explicitly so that a new " &
            "component cannot be initialized by accident."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Low),
      Unnamed_Exit =>
        (Name        => To_Unbounded_String ("Unnamed_Exit"),
         Description => To_Unbounded_String
           ("Find exit statements that do not name the loop they leave " &
            "even though that loop is named."),
         Guidance    => To_Unbounded_String
           ("Add the loop name to the exit statement."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Unnamed_Block_Or_Loop =>
        (Name        => To_Unbounded_String ("Unnamed_Block_Or_Loop"),
         Description => To_Unbounded_String
           ("Find block statements, and loops that nest or are nested " &
            "in another loop, that carry no statement identifier."),
         Guidance    => To_Unbounded_String
           ("Name the block or loop and repeat the name at its end."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Implicit_In_Mode =>
        (Name        => To_Unbounded_String ("Implicit_In_Mode"),
         Description => To_Unbounded_String
           ("Find parameter specifications that rely on the default in " &
            "mode instead of writing it (access parameters are not " &
            "reported)."),
         Guidance    => To_Unbounded_String
           ("Write the in mode explicitly."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Function_Out_Parameter =>
        (Name        => To_Unbounded_String ("Function_Out_Parameter"),
         Description => To_Unbounded_String
           ("Find functions that declare an out or in out parameter."),
         Guidance    => To_Unbounded_String
           ("Return a composite result, or turn the function into a " &
            "procedure."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Raising_Predefined_Exception =>
        (Name        => To_Unbounded_String ("Raising_Predefined_Exception"),
         Description => To_Unbounded_String
           ("Find raise statements that explicitly raise " &
            "Constraint_Error, Program_Error, Storage_Error, " &
            "Tasking_Error or Numeric_Error, directly or through a " &
            "renaming."),
         Guidance    => To_Unbounded_String
           ("Declare and raise a project-specific exception so that " &
            "explicit failures stay distinguishable from " &
            "language-defined checks."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Anonymous_Array_Type =>
        (Name        => To_Unbounded_String ("Anonymous_Array_Type"),
         Description => To_Unbounded_String
           ("Find object declarations whose type is an anonymous array " &
            "type."),
         Guidance    => To_Unbounded_String
           ("Declare a named array type and use it for the object."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Enumeration_Representation_Clause =>
        (Name        => To_Unbounded_String
           ("Enumeration_Representation_Clause"),
         Description => To_Unbounded_String
           ("Find enumeration representation clauses."),
         Guidance    => To_Unbounded_String
           ("Keep the default representation, or isolate and justify " &
            "the clause where an external encoding requires it."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Relative_Delay =>
        (Name        => To_Unbounded_String ("Relative_Delay"),
         Description => To_Unbounded_String
           ("Find delay statements that are relative rather than 'delay " &
            "until'."),
         Guidance    => To_Unbounded_String
           ("Use 'delay until' with an absolute time so that periodic " &
            "activities do not accumulate drift."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      No_Block_Statement =>
        (Name        => To_Unbounded_String ("No_Block_Statement"),
         Description => To_Unbounded_String
           ("Find block statements."),
         Guidance    => To_Unbounded_String
           ("Move the block's statements into a named subprogram, or " &
            "restructure the enclosing body."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Global_Variable =>
        (Name        => To_Unbounded_String ("Global_Variable"),
         Description => To_Unbounded_String
           ("Find variables declared in the visible or private part of " &
            "a package specification that is not nested in another " &
            "package specification."),
         Guidance    => To_Unbounded_String
           ("Move the variable into the package body behind " &
            "subprograms, or make it a constant."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      Predefined_Numeric_Type =>
        (Name        => To_Unbounded_String ("Predefined_Numeric_Type"),
         Description => To_Unbounded_String
           ("Find explicit references to the predefined numeric " &
            "subtypes of package Standard (Integer, Natural, Positive, " &
            "Float, Duration and their Short/Long variants), whose " &
            "ranges and precision depend on the target."),
         Guidance    => To_Unbounded_String
           ("Declare an application-specific numeric type with an " &
            "explicit range or precision."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Abstract_Type_Declaration =>
        (Name        => To_Unbounded_String ("Abstract_Type_Declaration"),
         Description => To_Unbounded_String
           ("Find declarations of abstract types."),
         Guidance    => To_Unbounded_String
           ("Use a concrete type, or justify the abstract type where " &
            "the design calls for one."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Exit_From_Conditional_Loop =>
        (Name        => To_Unbounded_String ("Exit_From_Conditional_Loop"),
         Description => To_Unbounded_String
           ("Find exit statements that leave a for or while loop."),
         Guidance    => To_Unbounded_String
           ("Express the termination in the loop's own condition or " &
            "range, or use a plain loop with an explicit exit."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Expanded_Loop_Exit_Name =>
        (Name        => To_Unbounded_String ("Expanded_Loop_Exit_Name"),
         Description => To_Unbounded_String
           ("Find exit statements that name the loop with an expanded " &
            "name."),
         Guidance    => To_Unbounded_String
           ("Name the loop by its simple identifier."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Conditional_Expression =>
        (Name        => To_Unbounded_String ("Conditional_Expression"),
         Description => To_Unbounded_String
           ("Find if expressions and case expressions."),
         Guidance    => To_Unbounded_String
           ("Use an if or case statement where the coding standard " &
            "excludes conditional expressions."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Quantified_Expression =>
        (Name        => To_Unbounded_String ("Quantified_Expression"),
         Description => To_Unbounded_String
           ("Find quantified expressions."),
         Guidance    => To_Unbounded_String
           ("Use an explicit loop where the coding standard excludes " &
            "quantified expressions."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Membership_Test =>
        (Name        => To_Unbounded_String ("Membership_Test"),
         Description => To_Unbounded_String
           ("Find membership tests."),
         Guidance    => To_Unbounded_String
           ("Compare against explicit bounds or values where the coding " &
            "standard excludes membership tests."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Generic_In_Out_Object =>
        (Name        => To_Unbounded_String ("Generic_In_Out_Object"),
         Description => To_Unbounded_String
           ("Find generic formal objects of mode in out."),
         Guidance    => To_Unbounded_String
           ("Pass the object as a subprogram parameter, or use a formal " &
            "of mode in."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Generic_In_Subprogram =>
        (Name        => To_Unbounded_String ("Generic_In_Subprogram"),
         Description => To_Unbounded_String
           ("Find generic units declared inside a subprogram body."),
         Guidance    => To_Unbounded_String
           ("Declare the generic unit at package level."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Local_Use_Clause =>
        (Name        => To_Unbounded_String ("Local_Use_Clause"),
         Description => To_Unbounded_String
           ("Find use clauses, including use type clauses, that are not " &
            "part of a context clause."),
         Guidance    => To_Unbounded_String
           ("Move the use clause to the context clause, or name " &
            "entities by expanded name."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Library_Level_Subprogram =>
        (Name        => To_Unbounded_String ("Library_Level_Subprogram"),
         Description => To_Unbounded_String
           ("Find subprogram bodies and subprogram instantiations that " &
            "are library units."),
         Guidance    => To_Unbounded_String
           ("Declare the subprogram in a package."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Multiple_Protected_Entries =>
        (Name        => To_Unbounded_String ("Multiple_Protected_Entries"),
         Description => To_Unbounded_String
           ("Find a second or later entry declared in the same part of " &
            "a protected definition."),
         Guidance    => To_Unbounded_String
           ("Keep one entry per protected object, as the Ravenscar " &
            "profile requires."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Non_Tagged_Derived_Type =>
        (Name        => To_Unbounded_String ("Non_Tagged_Derived_Type"),
         Description => To_Unbounded_String
           ("Find derived type definitions that are neither a record " &
            "extension nor a private extension."),
         Guidance    => To_Unbounded_String
           ("Declare a new type or a subtype instead of deriving from " &
            "an untagged type."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      No_Closing_Name =>
        (Name        => To_Unbounded_String ("No_Closing_Name"),
         Description => To_Unbounded_String
           ("Find subprogram, package, task and protected units whose " &
            "end does not repeat the unit name."),
         Guidance    => To_Unbounded_String
           ("Repeat the unit name after end."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Operator_Renaming =>
        (Name        => To_Unbounded_String ("Operator_Renaming"),
         Description => To_Unbounded_String
           ("Find subprogram renaming declarations that rename an " &
            "operator."),
         Guidance    => To_Unbounded_String
           ("Call the operator directly, or make it visible with a use " &
            "type clause."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Overloaded_Operator =>
        (Name        => To_Unbounded_String ("Overloaded_Operator"),
         Description => To_Unbounded_String
           ("Find declarations, bodies without a separate declaration, " &
            "and instantiations that define an operator symbol."),
         Guidance    => To_Unbounded_String
           ("Give the operation an ordinary subprogram name."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Single_Value_Enumeration_Type =>
        (Name        => To_Unbounded_String ("Single_Value_Enumeration_Type"),
         Description => To_Unbounded_String
           ("Find enumeration types that define a single literal."),
         Guidance    => To_Unbounded_String
           ("Add the missing literals, or replace the type with a " &
            "constant."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Unconstrained_Array_Type =>
        (Name        => To_Unbounded_String ("Unconstrained_Array_Type"),
         Description => To_Unbounded_String
           ("Find unconstrained array type definitions other than " &
            "generic formal array types."),
         Guidance    => To_Unbounded_String
           ("Declare the array type with constrained index ranges."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Low),
      Unconditional_Exit =>
        (Name        => To_Unbounded_String ("Unconditional_Exit"),
         Description => To_Unbounded_String
           ("Find exit statements that have no when condition."),
         Guidance    => To_Unbounded_String
           ("Write the exit condition on the exit statement itself."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Binary_Case_Statement =>
        (Name        => To_Unbounded_String ("Binary_Case_Statement"),
         Description => To_Unbounded_String
           ("Find case statements with exactly two alternatives of one " &
            "choice each."),
         Guidance    => To_Unbounded_String
           ("Use an if statement."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Concurrent_Interface =>
        (Name        => To_Unbounded_String ("Concurrent_Interface"),
         Description => To_Unbounded_String
           ("Find task, protected and synchronized interface types."),
         Guidance    => To_Unbounded_String
           ("Use a limited interface, or a concrete task or protected " &
            "type."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Anonymous_Access_Type =>
        (Name        => To_Unbounded_String ("Anonymous_Access_Type"),
         Description => To_Unbounded_String
           ("Find objects and components declared with an anonymous " &
            "access-to-object type."),
         Guidance    => To_Unbounded_String
           ("Declare a named access type and use it."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Renaming_Declaration =>
        (Name        => To_Unbounded_String ("Renaming_Declaration"),
         Description => To_Unbounded_String
           ("Find renaming declarations."),
         Guidance    => To_Unbounded_String
           ("Refer to the renamed entity by its own name."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Separate_Unit =>
        (Name        => To_Unbounded_String ("Separate_Unit"),
         Description => To_Unbounded_String
           ("Find subunits (separate bodies)."),
         Guidance    => To_Unbounded_String
           ("Keep the body in its parent unit, or move it to a child " &
            "package."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Array_Slice =>
        (Name        => To_Unbounded_String ("Array_Slice"),
         Description => To_Unbounded_String
           ("Find array slices."),
         Guidance    => To_Unbounded_String
           ("Copy or process the components with an explicit loop where " &
            "the coding standard excludes slices."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Number_Declaration =>
        (Name        => To_Unbounded_String ("Number_Declaration"),
         Description => To_Unbounded_String
           ("Find named number declarations."),
         Guidance    => To_Unbounded_String
           ("Declare a typed constant instead."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Local_Package =>
        (Name        => To_Unbounded_String ("Local_Package"),
         Description => To_Unbounded_String
           ("Find package specifications declared inside another " &
            "package specification."),
         Guidance    => To_Unbounded_String
           ("Declare a child package instead."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Declaration_In_Block =>
        (Name        => To_Unbounded_String ("Declaration_In_Block"),
         Description => To_Unbounded_String
           ("Find block statements that declare something; a " &
            "declarative part that is empty or holds only pragmas and " &
            "use clauses is not reported."),
         Guidance    => To_Unbounded_String
           ("Move the declarations to the enclosing body, or the block " &
            "into a subprogram."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Outer_Loop_Exit =>
        (Name        => To_Unbounded_String ("Outer_Loop_Exit"),
         Description => To_Unbounded_String
           ("Find named exit statements that leave a loop other than " &
            "the innermost enclosing one."),
         Guidance    => To_Unbounded_String
           ("Restructure the loops so that each exit leaves only its " &
            "own loop."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      Exit_Without_Loop_Name =>
        (Name        => To_Unbounded_String ("Exit_Without_Loop_Name"),
         Description => To_Unbounded_String
           ("Find exit statements that do not name a loop."),
         Guidance    => To_Unbounded_String
           ("Name the loop and repeat the name on the exit statement."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Expression_Function =>
        (Name        => To_Unbounded_String ("Expression_Function"),
         Description => To_Unbounded_String
           ("Find expression functions declared in a package " &
            "specification."),
         Guidance    => To_Unbounded_String
           ("Declare the function and give it a regular body in the " &
            "package body."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Size_Attribute_For_Type =>
        (Name        => To_Unbounded_String ("Size_Attribute_For_Type"),
         Description => To_Unbounded_String
           ("Find the Size attribute applied to a type or subtype " &
            "outside a representation item."),
         Guidance    => To_Unbounded_String
           ("Apply Size to an object, or use Object_Size for the type."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Enumeration_Range_In_Case_Statement =>
        (Name        => To_Unbounded_String
           ("Enumeration_Range_In_Case_Statement"),
         Description => To_Unbounded_String
           ("Find case statements over an enumeration type with a " &
            "choice written as a range, a subtype name or a Range " &
            "attribute."),
         Guidance    => To_Unbounded_String
           ("List the enumeration literals explicitly so that inserting " &
            "a literal forces a review of the choice."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Low),
      Missing_Header =>
        (Name        => To_Unbounded_String ("Missing_Header"),
         Description => To_Unbounded_String
           ("Find compilation units whose text does not start with the " &
            "header given by the header parameter (\n stands for a line " &
            "break); nothing is reported when no header is configured."),
         Guidance    => To_Unbounded_String
           ("Start the file with the project's standard header."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Lowercase_Keyword =>
        (Name        => To_Unbounded_String ("Lowercase_Keyword"),
         Description => To_Unbounded_String
           ("Find reserved words that are not written entirely in lower " &
            "case."),
         Guidance    => To_Unbounded_String
           ("Write reserved words in lower case."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Printable_ASCII =>
        (Name        => To_Unbounded_String ("Printable_ASCII"),
         Description => To_Unbounded_String
           ("Find comments, literals and white space that contain a " &
            "character outside printable ASCII, including horizontal " &
            "tabs."),
         Guidance    => To_Unbounded_String
           ("Use printable ASCII characters and spaces only."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      End_Of_Line_Comment =>
        (Name        => To_Unbounded_String ("End_Of_Line_Comment"),
         Description => To_Unbounded_String
           ("Find comments that share a line with code."),
         Guidance    => To_Unbounded_String
           ("Put the comment on a line of its own above the code it " &
            "describes."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Annotated_Comment =>
        (Name        => To_Unbounded_String ("Annotated_Comment"),
         Description => To_Unbounded_String
           ("Find comments that carry one of the annotation markers " &
            "listed in the s parameter, such as '#hide'; nothing is " &
            "reported when no marker is configured."),
         Guidance    => To_Unbounded_String
           ("Remove the annotation, or justify it where a tool depends " &
            "on it."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Maximum_Lines =>
        (Name        => To_Unbounded_String ("Maximum_Lines"),
         Description => To_Unbounded_String
           ("Find source files with more lines than the n parameter " &
            "allows (default 10000)."),
         Guidance    => To_Unbounded_String
           ("Split the unit into smaller units."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      Maximum_Identifier_Length =>
        (Name        => To_Unbounded_String ("Maximum_Identifier_Length"),
         Description => To_Unbounded_String
           ("Find defining names, other than enumeration literals, " &
            "longer than the n parameter allows (default 20)."),
         Guidance    => To_Unbounded_String
           ("Choose a shorter name."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Numeric_Format =>
        (Name        => To_Unbounded_String ("Numeric_Format"),
         Description => To_Unbounded_String
           ("Find numeric literals that are not written with upper-case " &
            "letters and with digits grouped by underscores: by three " &
            "for decimal and base 8 or 10, by four for base 2 or 16; " &
            "other bases are reported."),
         Guidance    => To_Unbounded_String
           ("Rewrite the literal in the standard layout."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Parameters_Out_Of_Order =>
        (Name        => To_Unbounded_String ("Parameters_Out_Of_Order"),
         Description => To_Unbounded_String
           ("Find parameters declared before a parameter that belongs " &
            "earlier in the order in, access, in out, out, defaulted " &
            "in."),
         Guidance    => To_Unbounded_String
           ("Reorder the formal parameters."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Maximum_Subprogram_Lines =>
        (Name        => To_Unbounded_String ("Maximum_Subprogram_Lines"),
         Description => To_Unbounded_String
           ("Find subprogram bodies whose statement part spans more " &
            "lines than the n parameter allows (default 1000)."),
         Guidance    => To_Unbounded_String
           ("Split the subprogram into smaller ones."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      Maximum_Out_Parameters =>
        (Name        => To_Unbounded_String ("Maximum_Out_Parameters"),
         Description => To_Unbounded_String
           ("Find subprograms with more out and in out parameters than " &
            "the n parameter allows (default 3)."),
         Guidance    => To_Unbounded_String
           ("Group the outputs in a record, or split the subprogram."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      Default_Parameter =>
        (Name        => To_Unbounded_String ("Default_Parameter"),
         Description => To_Unbounded_String
           ("Find parameter lists with more defaulted parameters than " &
            "the n parameter allows (default 0)."),
         Guidance    => To_Unbounded_String
           ("Require callers to pass the value explicitly."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Low),
      Forbidden_Identifier =>
        (Name        => To_Unbounded_String ("Forbidden_Identifier"),
         Description => To_Unbounded_String
           ("Find declarations of a name listed in the forbidden " &
            "parameter (comma-separated, case-insensitive); nothing is " &
            "reported when no name is configured."),
         Guidance    => To_Unbounded_String
           ("Choose a name that the project dictionary allows."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Uncommented_Begin =>
        (Name        => To_Unbounded_String ("Uncommented_Begin"),
         Description => To_Unbounded_String
           ("Find the begin of a subprogram, package, entry or task " &
            "body with declarations that is not directly followed by a " &
            "comment naming the unit."),
         Guidance    => To_Unbounded_String
           ("Write the unit name in a comment after begin."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Uncommented_Begin_In_Package_Body =>
        (Name        => To_Unbounded_String
           ("Uncommented_Begin_In_Package_Body"),
         Description => To_Unbounded_String
           ("Find the begin of a package body with declarations that is " &
            "not directly followed by a comment naming the package."),
         Guidance    => To_Unbounded_String
           ("Write the package name in a comment after begin."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Uncommented_End_Record =>
        (Name        => To_Unbounded_String ("Uncommented_End_Record"),
         Description => To_Unbounded_String
           ("Find record definitions spanning at least as many lines as " &
            "the n parameter (default 10) whose end record is not " &
            "followed on the same line by a comment naming the type."),
         Guidance    => To_Unbounded_String
           ("Write the type name in a comment after end record."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Object_Declaration_Out_Of_Order =>
        (Name        => To_Unbounded_String
           ("Object_Declaration_Out_Of_Order"),
         Description => To_Unbounded_String
           ("Find object declarations in a library unit body that " &
            "directly follow a program unit declaration."),
         Guidance    => To_Unbounded_String
           ("Declare objects before the program units of the same " &
            "declarative part."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      One_Construct_Per_Line =>
        (Name        => To_Unbounded_String ("One_Construct_Per_Line"),
         Description => To_Unbounded_String
           ("Find statements, declarations, clauses and pragmas that " &
            "share a line with other code."),
         Guidance    => To_Unbounded_String
           ("Write each construct on a line of its own."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Logical_SLOC =>
        (Name        => To_Unbounded_String ("Logical_SLOC"),
         Description => To_Unbounded_String
           ("Find packages, subprograms, tasks and protected units with " &
            "more statements and declarations than the n parameter " &
            "allows (default 200)."),
         Guidance    => To_Unbounded_String
           ("Split the unit into smaller units."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      Positional_Parameter =>
        (Name        => To_Unbounded_String ("Positional_Parameter"),
         Description => To_Unbounded_String
           ("Find positional parameter associations in calls to " &
            "subprograms with two or more parameters (three for " &
            "prefixed calls), unless the actual is the only one given " &
            "and stands for the single parameter without a default; " &
            "with the all parameter set to true, every positional " &
            "association is reported."),
         Guidance    => To_Unbounded_String
           ("Use named notation for the parameter."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Positional_Defaulted_Parameter =>
        (Name        => To_Unbounded_String ("Positional_Defaulted_Parameter"),
         Description => To_Unbounded_String
           ("Find positional actuals passed to a parameter that has a " &
            "default value."),
         Guidance    => To_Unbounded_String
           ("Use named notation when overriding a default."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Positional_Generic_Parameter =>
        (Name        => To_Unbounded_String ("Positional_Generic_Parameter"),
         Description => To_Unbounded_String
           ("Find positional associations in generic instantiations, " &
            "unless the generic has a single formal parameter."),
         Guidance    => To_Unbounded_String
           ("Use named notation for the generic actual."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Positional_Component =>
        (Name        => To_Unbounded_String ("Positional_Component"),
         Description => To_Unbounded_String
           ("Find array and record aggregates that have a positional " &
            "component association."),
         Guidance    => To_Unbounded_String
           ("Name every component or index in the aggregate."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Non_Qualified_Aggregate =>
        (Name        => To_Unbounded_String ("Non_Qualified_Aggregate"),
         Description => To_Unbounded_String
           ("Find aggregates of a named type that are not the operand " &
            "of a qualified expression, other than subaggregates and " &
            "aggregates nested in such an aggregate."),
         Guidance    => To_Unbounded_String
           ("Qualify the aggregate with its type."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Nested_Subprogram =>
        (Name        => To_Unbounded_String ("Nested_Subprogram"),
         Description => To_Unbounded_String
           ("Find subprograms declared inside a subprogram, task or " &
            "entry body."),
         Guidance    => To_Unbounded_String
           ("Declare the subprogram at package level."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Boolean_Relational_Operator =>
        (Name        => To_Unbounded_String ("Boolean_Relational_Operator"),
         Description => To_Unbounded_String
           ("Find predefined relational operators applied to Boolean " &
            "operands."),
         Guidance    => To_Unbounded_String
           ("Use the Boolean value, its negation, or a logical " &
            "operator."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Fixed_Equality =>
        (Name        => To_Unbounded_String ("Fixed_Equality"),
         Description => To_Unbounded_String
           ("Find predefined equality and inequality operators applied " &
            "to fixed-point operands."),
         Guidance    => To_Unbounded_String
           ("Compare against a tolerance, or use ordering operators."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Unconstrained_Array_Return =>
        (Name        => To_Unbounded_String ("Unconstrained_Array_Return"),
         Description => To_Unbounded_String
           ("Find functions whose result subtype is an unconstrained " &
            "array type."),
         Guidance    => To_Unbounded_String
           ("Return a constrained subtype, or use an out parameter of a " &
            "bounded type."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Deriving_From_Predefined_Type =>
        (Name        => To_Unbounded_String ("Deriving_From_Predefined_Type"),
         Description => To_Unbounded_String
           ("Find derived types, other than type extensions, whose " &
            "parent type is declared directly in package Standard, " &
            "System, Ada or Interfaces (not in one of their children)."),
         Guidance    => To_Unbounded_String
           ("Declare a new type with an explicit range or precision."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Low),
      Visible_Component =>
        (Name        => To_Unbounded_String ("Visible_Component"),
         Description => To_Unbounded_String
           ("Find record types and record extensions whose components " &
            "are visible in the specification of a non-private library " &
            "package; with the tagged_only parameter set to true, only " &
            "tagged types are reported."),
         Guidance    => To_Unbounded_String
           ("Make the type private and provide accessor subprograms."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      Object_Of_Anonymous_Type =>
        (Name        => To_Unbounded_String ("Object_Of_Anonymous_Type"),
         Description => To_Unbounded_String
           ("Find objects of an anonymous array or access type declared " &
            "in a package."),
         Guidance    => To_Unbounded_String
           ("Declare a named type for the object."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Numeric_Indexing =>
        (Name        => To_Unbounded_String ("Numeric_Indexing"),
         Description => To_Unbounded_String
           ("Find integer literals used as array index values."),
         Guidance    => To_Unbounded_String
           ("Index with a named constant, an enumeration value or an " &
            "attribute."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Local_Instantiation =>
        (Name        => To_Unbounded_String ("Local_Instantiation"),
         Description => To_Unbounded_String
           ("Find generic instantiations made in a subprogram, task, " &
            "entry, protected body or block."),
         Guidance    => To_Unbounded_String
           ("Instantiate the generic at package level."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Explicit_Inlining =>
        (Name        => To_Unbounded_String ("Explicit_Inlining"),
         Description => To_Unbounded_String
           ("Find subprograms that carry the Inline aspect or pragma."),
         Guidance    => To_Unbounded_String
           ("Leave inlining decisions to the compiler."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Pos_On_Enumeration_Type =>
        (Name        => To_Unbounded_String ("Pos_On_Enumeration_Type"),
         Description => To_Unbounded_String
           ("Find the Pos attribute applied to an enumeration type."),
         Guidance    => To_Unbounded_String
           ("Use the enumeration values themselves, or a " &
            "representation-independent mapping."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Implicit_Small =>
        (Name        => To_Unbounded_String ("Implicit_Small"),
         Description => To_Unbounded_String
           ("Find ordinary fixed-point type declarations without a " &
            "Small specification."),
         Guidance    => To_Unbounded_String
           ("Specify Small explicitly so that the representation does " &
            "not depend on the compiler."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Ada05_Formal_Package =>
        (Name        => To_Unbounded_String ("Ada05_Formal_Package"),
         Description => To_Unbounded_String
           ("Find formal packages that mix box and explicit actuals, a " &
            "form introduced by Ada 2005."),
         Guidance    => To_Unbounded_String
           ("Use either (<>) alone or a full actual part."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Separate_Numeric_Error_Handler =>
        (Name        => To_Unbounded_String ("Separate_Numeric_Error_Handler"),
         Description => To_Unbounded_String
           ("Find exception handlers that name Constraint_Error without " &
            "Numeric_Error, or the reverse."),
         Guidance    => To_Unbounded_String
           ("Handle both exceptions in the same handler."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Low),
      Forbidden_Aspect =>
        (Name        => To_Unbounded_String ("Forbidden_Aspect"),
         Description => To_Unbounded_String
           ("Find aspects listed in the forbidden parameter (or every " &
            "aspect when the all parameter is true) and not listed in " &
            "the allowed parameter; nothing is reported when neither is " &
            "configured."),
         Guidance    => To_Unbounded_String
           ("Remove the aspect, or add it to the allowed list with a " &
            "justification."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      Forbidden_Attribute =>
        (Name        => To_Unbounded_String ("Forbidden_Attribute"),
         Description => To_Unbounded_String
           ("Find attributes listed in the forbidden parameter (or " &
            "every attribute when the all parameter is true) and not " &
            "listed in the allowed parameter; nothing is reported when " &
            "neither is configured."),
         Guidance    => To_Unbounded_String
           ("Remove the attribute reference, or add the attribute to " &
            "the allowed list with a justification."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      Forbidden_Dependence =>
        (Name        => To_Unbounded_String ("Forbidden_Dependence"),
         Description => To_Unbounded_String
           ("Find with clauses that name a unit listed in the " &
            "unit_names parameter; nothing is reported when no unit is " &
            "configured."),
         Guidance    => To_Unbounded_String
           ("Remove the dependence on the forbidden unit."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      One_Tagged_Type_Per_Package =>
        (Name        => To_Unbounded_String ("One_Tagged_Type_Per_Package"),
         Description => To_Unbounded_String
           ("Find package specifications whose visible part declares " &
            "more than one tagged type."),
         Guidance    => To_Unbounded_String
           ("Declare each tagged type in a package of its own."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Explicit_Full_Discrete_Range =>
        (Name        => To_Unbounded_String ("Explicit_Full_Discrete_Range"),
         Description => To_Unbounded_String
           ("Find ranges written T'First .. T'Last."),
         Guidance    => To_Unbounded_String
           ("Write the subtype mark or T'Range."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Universal_Range =>
        (Name        => To_Unbounded_String ("Universal_Range"),
         Description => To_Unbounded_String
           ("Find loop ranges and index constraints whose bounds are " &
            "both integer literals or named numbers."),
         Guidance    => To_Unbounded_String
           ("Give the range an explicit type."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Low),
      Missing_Others_Handler =>
        (Name        => To_Unbounded_String ("Missing_Others_Handler"),
         Description => To_Unbounded_String
           ("Find exception handler parts without an others choice, in " &
            "the scopes switched on by the all_handlers, subprogram and " &
            "task parameters; nothing is reported when none is set."),
         Guidance    => To_Unbounded_String
           ("Add a when others handler."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Default_Value_For_Record_Component =>
        (Name        => To_Unbounded_String
           ("Default_Value_For_Record_Component"),
         Description => To_Unbounded_String
           ("Find record components declared with a default value."),
         Guidance    => To_Unbounded_String
           ("Initialize the record explicitly where objects of the type " &
            "are declared."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Uninitialized_Global_Variable =>
        (Name        => To_Unbounded_String ("Uninitialized_Global_Variable"),
         Description => To_Unbounded_String
           ("Find variables declared outside any subprogram, task, " &
            "entry, protected body or block without an initial value."),
         Guidance    => To_Unbounded_String
           ("Give the variable an explicit initial value."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Deep_Library_Hierarchy =>
        (Name        => To_Unbounded_String ("Deep_Library_Hierarchy"),
         Description => To_Unbounded_String
           ("Find packages and package instantiations with more " &
            "ancestor units than the n parameter allows (default 3)."),
         Guidance    => To_Unbounded_String
           ("Flatten the unit hierarchy."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Deeply_Nested_Generic =>
        (Name        => To_Unbounded_String ("Deeply_Nested_Generic"),
         Description => To_Unbounded_String
           ("Find generic units nested in more generic units than the n " &
            "parameter allows (default 5)."),
         Guidance    => To_Unbounded_String
           ("Declare the generic unit at an outer level."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Overly_Nested_Scope =>
        (Name        => To_Unbounded_String ("Overly_Nested_Scope"),
         Description => To_Unbounded_String
           ("Find packages, subprograms, tasks, protected units, " &
            "entries and blocks nested in more such scopes than the n " &
            "parameter allows (default 10)."),
         Guidance    => To_Unbounded_String
           ("Move the nested unit to an outer level."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      Specific_Type_Invariant =>
        (Name        => To_Unbounded_String ("Specific_Type_Invariant"),
         Description => To_Unbounded_String
           ("Find Type_Invariant aspects on tagged types; such an " &
            "invariant is not inherited by extensions."),
         Guidance    => To_Unbounded_String
           ("Use Type_Invariant'Class."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Volatile_Object_Without_Address =>
        (Name        => To_Unbounded_String
           ("Volatile_Object_Without_Address"),
         Description => To_Unbounded_String
           ("Find objects that are volatile, or of a volatile type, and " &
            "have no address specification."),
         Guidance    => To_Unbounded_String
           ("Give the object an address, or remove Volatile if it is " &
            "not a hardware or shared-memory object."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Too_Many_Primitives =>
        (Name        => To_Unbounded_String ("Too_Many_Primitives"),
         Description => To_Unbounded_String
           ("Find tagged types declared in the visible part of a " &
            "package with more primitive operations than the n " &
            "parameter allows (default 5)."),
         Guidance    => To_Unbounded_String
           ("Split the type's responsibilities."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      Deep_Inheritance_Hierarchy =>
        (Name        => To_Unbounded_String ("Deep_Inheritance_Hierarchy"),
         Description => To_Unbounded_String
           ("Find tagged types whose derivation chain is longer than " &
            "the n parameter allows (default 2)."),
         Guidance    => To_Unbounded_String
           ("Flatten the type hierarchy, or use composition."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      Too_Many_Parents =>
        (Name        => To_Unbounded_String ("Too_Many_Parents"),
         Description => To_Unbounded_String
           ("Find tagged, task and protected types that derive, " &
            "directly or not, from more types and interfaces than the n " &
            "parameter allows (default 5)."),
         Guidance    => To_Unbounded_String
           ("Reduce the number of interfaces and ancestors."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      Specific_Pre_Post =>
        (Name        => To_Unbounded_String ("Specific_Pre_Post"),
         Description => To_Unbounded_String
           ("Find primitive operations of tagged types with a Pre or " &
            "Post aspect that is not class-wide."),
         Guidance    => To_Unbounded_String
           ("Use Pre'Class and Post'Class so that the contract applies " &
            "to overridings."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Constructor =>
        (Name        => To_Unbounded_String ("Constructor"),
         Description => To_Unbounded_String
           ("Find primitive functions of a tagged type that return the " &
            "type and take no parameter of it."),
         Guidance    => To_Unbounded_String
           ("Provide an initialization procedure, or declare the " &
            "function in a nested or child package."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Misnamed_Controlling_Parameter =>
        (Name        => To_Unbounded_String ("Misnamed_Controlling_Parameter"),
         Description => To_Unbounded_String
           ("Find primitive operations of a tagged type whose first " &
            "parameter is not a controlling parameter named This."),
         Guidance    => To_Unbounded_String
           ("Make the controlling parameter the first one and name it " &
            "This."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Non_Component_In_Barrier =>
        (Name        => To_Unbounded_String ("Non_Component_In_Barrier"),
         Description => To_Unbounded_String
           ("Find entry barriers that refer to an object, a parameter " &
            "or a component that does not belong to the protected " &
            "object."),
         Guidance    => To_Unbounded_String
           ("Write the barrier in terms of the protected object's own " &
            "components."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Identifier_Casing =>
        (Name        => To_Unbounded_String ("Identifier_Casing"),
         Description => To_Unbounded_String
           ("Find defining names whose casing differs from the scheme " &
            "(upper, lower or mixed) given by the type, enum, constant, " &
            "exception and others parameters; the exclude parameter " &
            "lists words with a fixed spelling. Nothing is reported for " &
            "a kind whose scheme is not configured."),
         Guidance    => To_Unbounded_String
           ("Rename the entity to follow the project's casing " &
            "convention."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Identifier_Prefixes =>
        (Name        => To_Unbounded_String ("Identifier_Prefixes"),
         Description => To_Unbounded_String
           ("Find defining names that lack the prefix required for " &
            "their kind by the type, concurrent, access, class_access, " &
            "subprogram_access, derived, constant, exception and enum " &
            "parameters, or that carry a prefix reserved for another " &
            "kind (unless the exclusive parameter is false)."),
         Guidance    => To_Unbounded_String
           ("Rename the entity to follow the project's prefix " &
            "convention."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Identifier_Suffixes =>
        (Name        => To_Unbounded_String ("Identifier_Suffixes"),
         Description => To_Unbounded_String
           ("Find defining names that lack the suffix required for " &
            "their kind by the type_suffix, access_suffix, " &
            "access_access_suffix, class_access_suffix, " &
            "class_subtype_suffix, constant_suffix, renaming_suffix, " &
            "access_obj_suffix and interrupt_suffix parameters; the " &
            "default parameter selects _T, _A, _C and _R."),
         Guidance    => To_Unbounded_String
           ("Rename the entity to follow the project's suffix " &
            "convention."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Constant_Overlay =>
        (Name        => To_Unbounded_String ("Constant_Overlay"),
         Description => To_Unbounded_String
           ("Find address specifications that make a variable, or a " &
            "volatile object, overlay a constant object."),
         Guidance    => To_Unbounded_String
           ("Declare the overlaying object constant, or do not overlay " &
            "a constant."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Non_Constant_Overlay =>
        (Name        => To_Unbounded_String ("Non_Constant_Overlay"),
         Description => To_Unbounded_String
           ("Find address specifications that make a constant or a " &
            "non-volatile object overlay a variable that can change " &
            "underneath it."),
         Guidance    => To_Unbounded_String
           ("Declare both objects volatile, or remove the overlay."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Nonoverlay_Address_Specification =>
        (Name        => To_Unbounded_String
           ("Nonoverlay_Address_Specification"),
         Description => To_Unbounded_String
           ("Find address specifications of objects whose address is " &
            "not the Address of another object."),
         Guidance    => To_Unbounded_String
           ("Isolate hardware addresses in a dedicated package, or " &
            "express the mapping as an overlay."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Not_Imported_Overlay =>
        (Name        => To_Unbounded_String ("Not_Imported_Overlay"),
         Description => To_Unbounded_String
           ("Find objects that overlay another object without being " &
            "imported, so that default initialization may overwrite the " &
            "overlaid object."),
         Guidance    => To_Unbounded_String
           ("Add the Import aspect to the overlaying object."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Address_Of_Non_Volatile_Object =>
        (Name        => To_Unbounded_String ("Address_Of_Non_Volatile_Object"),
         Description => To_Unbounded_String
           ("Find the Address attribute applied to a variable that is " &
            "not volatile, atomic or shared."),
         Guidance    => To_Unbounded_String
           ("Declare the object volatile, or avoid taking its address."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Access_To_Local_Object =>
        (Name        => To_Unbounded_String ("Access_To_Local_Object"),
         Description => To_Unbounded_String
           ("Find the Access attribute applied to an object, or part of " &
            "an object, that is a parameter or is declared in a " &
            "subprogram, task, entry, protected body or block."),
         Guidance    => To_Unbounded_String
           ("Take the access of a library-level object, or pass the " &
            "object as a parameter."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Bit_Record_Without_Layout =>
        (Name        => To_Unbounded_String ("Bit_Record_Without_Layout"),
         Description => To_Unbounded_String
           ("Find packed record types with a modular component or " &
            "discriminant and no record representation clause."),
         Guidance    => To_Unbounded_String
           ("Give the record an explicit representation clause."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      No_Scalar_Storage_Order =>
        (Name        => To_Unbounded_String ("No_Scalar_Storage_Order"),
         Description => To_Unbounded_String
           ("Find record types with a record representation clause, " &
            "their own or inherited, that do not specify " &
            "Scalar_Storage_Order."),
         Guidance    => To_Unbounded_String
           ("Specify Scalar_Storage_Order (and Bit_Order) on the type."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Incomplete_Representation_Specification =>
        (Name        => To_Unbounded_String
           ("Incomplete_Representation_Specification"),
         Description => To_Unbounded_String
           ("Find record types with a record representation clause that " &
            "do not also have both a Size and a Pack specification."),
         Guidance    => To_Unbounded_String
           ("Complete the representation with Size and Pack."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Misplaced_Representation_Item =>
        (Name        => To_Unbounded_String ("Misplaced_Representation_Item"),
         Description => To_Unbounded_String
           ("Find representation clauses and representation pragmas " &
            "that do not directly follow the declaration they apply to, " &
            "other representation items of the same entity aside."),
         Guidance    => To_Unbounded_String
           ("Move the representation item next to the declaration it " &
            "applies to."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Representation_Specification =>
        (Name        => To_Unbounded_String ("Representation_Specification"),
         Description => To_Unbounded_String
           ("Find record and enumeration representation clauses and " &
            "declarations that carry a representation aspect; with the " &
            "record_rep_clauses_only parameter set to true, only record " &
            "representation clauses are reported."),
         Guidance    => To_Unbounded_String
           ("Remove the representation item, or confine it to a " &
            "hardware-boundary package."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Unchecked_Address_Conversion =>
        (Name        => To_Unbounded_String ("Unchecked_Address_Conversion"),
         Description => To_Unbounded_String
           ("Find instantiations of Ada.Unchecked_Conversion from " &
            "System.Address to an access type; with the all parameter " &
            "set to true, any instantiation involving System.Address is " &
            "reported."),
         Guidance    => To_Unbounded_String
           ("Use System.Address_To_Access_Conversions, or an address " &
            "specification."),
         Quality     => Quality_Security,
         Severity    => Severity_High),
      Unchecked_Conversion_As_Actual =>
        (Name        => To_Unbounded_String ("Unchecked_Conversion_As_Actual"),
         Description => To_Unbounded_String
           ("Find calls to an instance of Ada.Unchecked_Conversion used " &
            "as an actual parameter or as a default parameter value."),
         Guidance    => To_Unbounded_String
           ("Assign the converted value to a constant first and " &
            "validate it."),
         Quality     => Quality_Security,
         Severity    => Severity_Medium),
      Use_Simple_Loop =>
        (Name        => To_Unbounded_String ("Use_Simple_Loop"),
         Description => To_Unbounded_String
           ("Find while loops whose condition is statically true."),
         Guidance    => To_Unbounded_String
           ("Write a plain loop."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Use_While_Loop =>
        (Name        => To_Unbounded_String ("Use_While_Loop"),
         Description => To_Unbounded_String
           ("Find plain loops whose first statement is an exit from " &
            "that loop."),
         Guidance    => To_Unbounded_String
           ("Write a while loop with the negated exit condition."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Use_For_Loop =>
        (Name        => To_Unbounded_String ("Use_For_Loop"),
         Description => To_Unbounded_String
           ("Find while loops that test a local counter and increment " &
            "or decrement it by one as their last statement, where the " &
            "counter is not otherwise written and not used after the " &
            "loop."),
         Guidance    => To_Unbounded_String
           ("Write a for loop over the counter's range."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Use_Range =>
        (Name        => To_Unbounded_String ("Use_Range"),
         Description => To_Unbounded_String
           ("Find T'First .. T'Last ranges, and T'Range of a discrete " &
            "subtype used as a loop range, a membership choice or a " &
            "case choice."),
         Guidance    => To_Unbounded_String
           ("Write the subtype mark, or the Range attribute."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Use_Membership =>
        (Name        => To_Unbounded_String ("Use_Membership"),
         Description => To_Unbounded_String
           ("Find Boolean expressions that only compare one variable " &
            "with several values or ranges; with the short_circuit " &
            "parameter set to true, 'or else' and 'and then' forms are " &
            "reported too."),
         Guidance    => To_Unbounded_String
           ("Write a membership test."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Use_If_Expression =>
        (Name        => To_Unbounded_String ("Use_If_Expression"),
         Description => To_Unbounded_String
           ("Find if statements with an else part whose every branch is " &
            "a single return statement, or a single assignment to the " &
            "same target."),
         Guidance    => To_Unbounded_String
           ("Write one return or assignment with an if expression."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Use_Case_Statement =>
        (Name        => To_Unbounded_String ("Use_Case_Statement"),
         Description => To_Unbounded_String
           ("Find if statements with elsif parts whose conditions all " &
            "compare the same discrete variable or component with a " &
            "static value."),
         Guidance    => To_Unbounded_String
           ("Write a case statement."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Use_Record_Aggregate =>
        (Name        => To_Unbounded_String ("Use_Record_Aggregate"),
         Description => To_Unbounded_String
           ("Find consecutive assignments that set every component of " &
            "an untagged record without discriminants one by one."),
         Guidance    => To_Unbounded_String
           ("Assign an aggregate."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Use_For_Of_Loop =>
        (Name        => To_Unbounded_String ("Use_For_Of_Loop"),
         Description => To_Unbounded_String
           ("Find for loops over the Range of a one-dimensional array " &
            "that use the loop parameter only to index that array."),
         Guidance    => To_Unbounded_String
           ("Write a for-of loop over the array."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Use_Array_Slice =>
        (Name        => To_Unbounded_String ("Use_Array_Slice"),
         Description => To_Unbounded_String
           ("Find for loops whose only statement assigns to an array " &
            "component indexed by the loop parameter a static value or " &
            "the same-indexed component of another array."),
         Guidance    => To_Unbounded_String
           ("Write an array slice assignment."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Discriminated_Record =>
        (Name        => To_Unbounded_String ("Discriminated_Record"),
         Description => To_Unbounded_String
           ("Find type declarations with a known discriminant part, " &
            "other than private types and derived types that only pass " &
            "their discriminants on to the parent type."),
         Guidance    => To_Unbounded_String
           ("Use separate types, or a non-discriminated record, where " &
            "the coding standard excludes discriminants."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Anonymous_Subtype =>
        (Name        => To_Unbounded_String ("Anonymous_Subtype"),
         Description => To_Unbounded_String
           ("Find constrained subtype indications, ranges and Range " &
            "attributes used where a named subtype could be, other than " &
            "in a subtype declaration, a type definition or a " &
            "constraint that depends on a discriminant."),
         Guidance    => To_Unbounded_String
           ("Declare a named subtype and use it."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      No_Explicit_Real_Range =>
        (Name        => To_Unbounded_String ("No_Explicit_Real_Range"),
         Description => To_Unbounded_String
           ("Find floating-point and fixed-point types and subtypes " &
            "that neither declare nor inherit an explicit range."),
         Guidance    => To_Unbounded_String
           ("Declare the range of the real type explicitly."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Direct_Equality =>
        (Name        => To_Unbounded_String ("Direct_Equality"),
         Description => To_Unbounded_String
           ("Find equality and inequality tests on the objects listed, " &
            "by fully qualified name, in the actuals parameter; nothing " &
            "is reported when no object is configured."),
         Guidance    => To_Unbounded_String
           ("Compare the object through the function the project " &
            "provides for it."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Membership_For_Validity =>
        (Name        => To_Unbounded_String ("Membership_For_Validity"),
         Description => To_Unbounded_String
           ("Find membership tests of an object in its own subtype, " &
            "written as the subtype mark, T'Range or T'First .. T'Last."),
         Guidance    => To_Unbounded_String
           ("Use the Valid attribute."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Positional_Defaulted_Generic_Parameter =>
        (Name        => To_Unbounded_String
           ("Positional_Defaulted_Generic_Parameter"),
         Description => To_Unbounded_String
           ("Find positional actuals passed to a generic formal object " &
            "or subprogram that has a default."),
         Guidance    => To_Unbounded_String
           ("Use named notation when overriding a generic default."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Deeply_Nested_Instantiation =>
        (Name        => To_Unbounded_String ("Deeply_Nested_Instantiation"),
         Description => To_Unbounded_String
           ("Find instantiations of a generic whose declaration " &
            "contains an instantiation, to a depth beyond the n " &
            "parameter (default 3)."),
         Guidance    => To_Unbounded_String
           ("Flatten the chain of generic instantiations."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      Too_Many_Generic_Dependencies =>
        (Name        => To_Unbounded_String ("Too_Many_Generic_Dependencies"),
         Description => To_Unbounded_String
           ("Find with clauses naming a generic unit that itself " &
            "depends on generic units through its with clauses, to a " &
            "depth beyond the n parameter (default 3)."),
         Guidance    => To_Unbounded_String
           ("Reduce the chain of generic dependencies."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      Raising_External_Exception =>
        (Name        => To_Unbounded_String ("Raising_External_Exception"),
         Description => To_Unbounded_String
           ("Find raise statements in a library package that raise an " &
            "exception which is neither predefined, nor handled in the " &
            "same unit, nor declared in the visible part of that " &
            "package."),
         Guidance    => To_Unbounded_String
           ("Declare the exception in the package's visible part, or " &
            "handle it locally."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Final_Package =>
        (Name        => To_Unbounded_String ("Final_Package"),
         Description => To_Unbounded_String
           ("Find child packages of a package marked with Annotate => " &
            "(GNATcheck, Final)."),
         Guidance    => To_Unbounded_String
           ("Do not extend a package declared final."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      Direct_Call_To_Primitive =>
        (Name        => To_Unbounded_String ("Direct_Call_To_Primitive"),
         Description => To_Unbounded_String
           ("Find statically bound calls to a primitive operation of a " &
            "tagged type, other than a call to the parent type's " &
            "operation from its own overriding."),
         Guidance    => To_Unbounded_String
           ("Call the operation on a class-wide operand so that it " &
            "dispatches."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Downward_View_Conversion =>
        (Name        => To_Unbounded_String ("Downward_View_Conversion"),
         Description => To_Unbounded_String
           ("Find view conversions from a tagged type, or an access to " &
            "one, to a type derived from it."),
         Guidance    => To_Unbounded_String
           ("Use dispatching, or a membership test before converting."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Specific_Parent_Type_Invariant =>
        (Name        => To_Unbounded_String ("Specific_Parent_Type_Invariant"),
         Description => To_Unbounded_String
           ("Find type extensions whose parent type, or one of its " &
            "ancestors, has a Type_Invariant aspect that is not " &
            "class-wide."),
         Guidance    => To_Unbounded_String
           ("Use Type_Invariant'Class on the parent type."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      No_Inherited_Classwide_Pre =>
        (Name        => To_Unbounded_String ("No_Inherited_Classwide_Pre"),
         Description => To_Unbounded_String
           ("Find overriding primitive operations whose overridden root " &
            "declaration has no Pre'Class aspect."),
         Guidance    => To_Unbounded_String
           ("Give the root operation a Pre'Class aspect, even if it is " &
            "True."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Non_SPARK_Attribute =>
        (Name        => To_Unbounded_String ("Non_SPARK_Attribute"),
         Description => To_Unbounded_String
           ("Find attributes outside the SPARK 2005 attribute subset."),
         Guidance    => To_Unbounded_String
           ("Use an attribute of the subset, or an explicit " &
            "computation."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Nested_Path =>
        (Name        => To_Unbounded_String ("Nested_Path"),
         Description => To_Unbounded_String
           ("Find statements kept inside one branch of an if statement " &
            "whose other branch always leaves it by return, raise, exit " &
            "or goto."),
         Guidance    => To_Unbounded_String
           ("Move the statements after the if statement."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Essential_Complexity =>
        (Name        => To_Unbounded_String ("Essential_Complexity"),
         Description => To_Unbounded_String
           ("Find subprogram bodies whose essential complexity (one " &
            "plus the compound statements left early by a return, " &
            "raise, exit or goto) exceeds the n parameter (default 3)."),
         Guidance    => To_Unbounded_String
           ("Restructure the subprogram around single-exit constructs."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      Maximum_Expression_Complexity =>
        (Name        => To_Unbounded_String ("Maximum_Expression_Complexity"),
         Description => To_Unbounded_String
           ("Find expressions with more names, literals, conditional " &
            "and quantified expressions and aggregates than the n " &
            "parameter allows (default 10)."),
         Guidance    => To_Unbounded_String
           ("Split the expression using named constants or functions."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      Improperly_Located_Instantiation =>
        (Name        => To_Unbounded_String
           ("Improperly_Located_Instantiation"),
         Description => To_Unbounded_String
           ("Find generic instantiations in a library package " &
            "specification or in a subprogram body."),
         Guidance    => To_Unbounded_String
           ("Instantiate the generic as a library unit or in a package " &
            "body."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Function_Style_Procedure =>
        (Name        => To_Unbounded_String ("Function_Style_Procedure"),
         Description => To_Unbounded_String
           ("Find procedures with a single out parameter of a " &
            "non-limited type, no in out parameter and no Global " &
            "aspect."),
         Guidance    => To_Unbounded_String
           ("Declare a function that returns the value."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Exception_As_Control_Flow =>
        (Name        => To_Unbounded_String ("Exception_As_Control_Flow"),
         Description => To_Unbounded_String
           ("Find raise statements whose exception is handled in the " &
            "same subprogram body."),
         Guidance    => To_Unbounded_String
           ("Use ordinary control flow instead of a local exception."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Complex_Inlined_Subprogram =>
        (Name        => To_Unbounded_String ("Complex_Inlined_Subprogram"),
         Description => To_Unbounded_String
           ("Find inlined subprograms whose body declares a nested " &
            "unit, contains a loop, case or if statement, or has more " &
            "statements than the n parameter allows (default 5)."),
         Guidance    => To_Unbounded_String
           ("Remove Inline, or simplify the subprogram."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      Call_In_Exception_Handler =>
        (Name        => To_Unbounded_String ("Call_In_Exception_Handler"),
         Description => To_Unbounded_String
           ("Find exception handlers that call a subprogram listed, by " &
            "fully qualified name, in the subprograms parameter; " &
            "nothing is reported when none is configured."),
         Guidance    => To_Unbounded_String
           ("Keep the listed subprograms out of exception handlers."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Ada_2022_In_Ghost_Code =>
        (Name        => To_Unbounded_String ("Ada_2022_In_Ghost_Code"),
         Description => To_Unbounded_String
           ("Find Ada 2022 constructs used outside ghost code and " &
            "generic units: Image of a composite object, reduction, " &
            "declare expressions, target names, delta and iterated " &
            "aggregates, user-defined literals and aspects on " &
            "parameters and formal subprograms."),
         Guidance    => To_Unbounded_String
           ("Restrict the construct to ghost code, or rewrite it in Ada " &
            "2012."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      Actual_Parameter =>
        (Name        => To_Unbounded_String ("Actual_Parameter"),
         Description => To_Unbounded_String
           ("Find calls that pass a listed object to a listed formal " &
            "parameter; the forbidden parameter holds comma-separated " &
            "subprogram:formal:object triples of fully qualified names. " &
            "Nothing is reported when none is configured."),
         Guidance    => To_Unbounded_String
           ("Pass an object the project's rules allow for that " &
            "parameter."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Same_Logic =>
        (Name        => To_Unbounded_String ("Same_Logic"),
         Description => To_Unbounded_String
           ("Find conditions joined by one logical operator in which " &
            "the same operand appears twice."),
         Guidance    => To_Unbounded_String
           ("Remove the repeated operand, or correct the one that was " &
            "meant to differ."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Suspicious_Equality =>
        (Name        => To_Unbounded_String ("Suspicious_Equality"),
         Description => To_Unbounded_String
           ("Find conditions that test the same name for equality with " &
            "two literals joined by and, or for inequality with two " &
            "literals joined by or."),
         Guidance    => To_Unbounded_String
           ("Correct the operator: such a test is never, respectively " &
            "always, true."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Non_Visible_Exception =>
        (Name        => To_Unbounded_String ("Non_Visible_Exception"),
         Description => To_Unbounded_String
           ("Find exceptions declared in a subprogram body, task body " &
            "or block that the same scope does not handle, and handlers " &
            "that raise or re-raise such a local exception."),
         Guidance    => To_Unbounded_String
           ("Handle the local exception in its scope, or declare it " &
            "where callers can name it."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Outbound_Protected_Assignment =>
        (Name        => To_Unbounded_String ("Outbound_Protected_Assignment"),
         Description => To_Unbounded_String
           ("Find assignments in a protected body to an object declared " &
            "outside the protected unit."),
         Guidance    => To_Unbounded_String
           ("Keep protected operations to the protected object's own " &
            "components."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Outside_Reference_From_Subprogram =>
        (Name        => To_Unbounded_String
           ("Outside_Reference_From_Subprogram"),
         Description => To_Unbounded_String
           ("Find references in a nested subprogram to a local object " &
            "or a parameter of an enclosing subprogram."),
         Guidance    => To_Unbounded_String
           ("Pass the object to the nested subprogram as a parameter."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      Variable_Scoping =>
        (Name        => To_Unbounded_String ("Variable_Scoping"),
         Description => To_Unbounded_String
           ("Find local variables without an initial value that are " &
            "used only inside one declare block of the subprogram, " &
            "outside any loop."),
         Guidance    => To_Unbounded_String
           ("Declare the variable in that block."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Out_Parameter_Read_In_Exception_Handler =>
        (Name        => To_Unbounded_String
           ("Out_Parameter_Read_In_Exception_Handler"),
         Description => To_Unbounded_String
           ("Find out and in out actuals of a call that an exception " &
            "handler of an enclosing block reads; the call may have " &
            "raised before assigning them."),
         Guidance    => To_Unbounded_String
           ("Give the object a defined value before the call, or do not " &
            "read it in the handler."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Predicate_Testing =>
        (Name        => To_Unbounded_String ("Predicate_Testing"),
         Description => To_Unbounded_String
           ("Find membership tests naming a subtype with a predicate, " &
            "and Valid attributes of an object of such a subtype."),
         Guidance    => To_Unbounded_String
           ("Avoid the implicit predicate evaluation, or make it " &
            "explicit with a named function."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Low),
      Profile_Discrepancy =>
        (Name        => To_Unbounded_String ("Profile_Discrepancy"),
         Description => To_Unbounded_String
           ("Find subprogram and entry bodies whose parameter profile " &
            "is written differently from their declaration: grouping of " &
            "names, explicit modes or the spelling of type names."),
         Guidance    => To_Unbounded_String
           ("Write the body's profile exactly as the declaration's."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Side_Effect_Parameter =>
        (Name        => To_Unbounded_String ("Side_Effect_Parameter"),
         Description => To_Unbounded_String
           ("Find calls and instantiations whose actuals call the same " &
            "function, listed by fully qualified name in the functions " &
            "parameter, more than once; nothing is reported when none " &
            "is configured."),
         Guidance    => To_Unbounded_String
           ("Call the function once per statement and pass the results."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Use_Clause =>
        (Name        => To_Unbounded_String ("Use_Clause"),
         Description => To_Unbounded_String
           ("Find each package name in a use clause. The allowed " &
            "parameter lists packages to exempt by fully qualified name, " &
            "and exempt_operator_packages exempts packages that declare " &
            "only operators."),
         Guidance    => To_Unbounded_String
           ("Qualify the names, or use a use type clause."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Unavailable_Body_Call =>
        (Name        => To_Unbounded_String ("Unavailable_Body_Call"),
         Description => To_Unbounded_String
           ("Find calls to a subprogram whose body is not among the " &
            "sources the analyzer can see, such as an imported one. With " &
            "the indirect_calls parameter, calls through an access value " &
            "are reported too."),
         Guidance    => To_Unbounded_String
           ("Add the body's source to the analysis, or review the call " &
            "by hand: checks that follow calls stop here."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Low),
      Deeply_Nested_Inlining =>
        (Name        => To_Unbounded_String ("Deeply_Nested_Inlining"),
         Description => To_Unbounded_String
           ("Find inlined subprograms that call inlined subprograms to a " &
            "depth above the n parameter (3 by default)."),
         Guidance    => To_Unbounded_String
           ("Remove Inline from the outer subprogram or flatten the " &
            "chain of calls."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Integer_Type_As_Enumeration =>
        (Name        => To_Unbounded_String ("Integer_Type_As_Enumeration"),
         Description => To_Unbounded_String
           ("Find integer types that no analyzed source uses in " &
            "arithmetic, converts, derives from, declares a subtype of " &
            "or passes to a generic instantiation."),
         Guidance    => To_Unbounded_String
           ("Consider an enumeration type."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Same_Instantiation =>
        (Name        => To_Unbounded_String ("Same_Instantiation"),
         Description => To_Unbounded_String
           ("Find generic package instantiations that repeat another " &
            "instantiation of the same generic with the same actual " &
            "parameters among the analyzed sources. With the " &
            "library_level_only parameter, local instantiations are " &
            "ignored."),
         Guidance    => To_Unbounded_String
           ("Share one instantiation if the two need not be distinct."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Compiler_Warning =>
        (Name        => To_Unbounded_String ("Compiler_Warning"),
         Description => To_Unbounded_String
           ("Report the GNAT warnings selected by the options parameter, " &
            "which takes the letters of a -gnatw switch; nothing is " &
            "reported when none is configured. Needs GNAT on the path."),
         Guidance    => To_Unbounded_String
           ("Fix the construct the compiler warns about."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Compiler_Style_Check =>
        (Name        => To_Unbounded_String ("Compiler_Style_Check"),
         Description => To_Unbounded_String
           ("Report the GNAT style messages selected by the options " &
            "parameter, which takes the letters of a -gnaty switch; " &
            "nothing is reported when none is configured. Needs GNAT on " &
            "the path."),
         Guidance    => To_Unbounded_String
           ("Lay the source out as the selected style rule requires."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Compiler_Restriction =>
        (Name        => To_Unbounded_String ("Compiler_Restriction"),
         Description => To_Unbounded_String
           ("Report violations of the language restrictions listed in " &
            "the restrictions parameter, as GNAT detects them; nothing " &
            "is reported when none is configured. Needs GNAT on the path."),
         Guidance    => To_Unbounded_String
           ("Remove the construct the restriction forbids."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium)
   );

   function Lookup_Rule_Kind
     (Name : String; Found : out Boolean) return Rule_Kind;
   --  Resolves a check name typed on the command line to its Rule_Kind.
   --  Found is False (with an arbitrary result) when no check matches.

end Adalang_Analyzer.Rules;
