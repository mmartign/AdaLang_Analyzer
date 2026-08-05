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
      Exception_Swallowed,
      Cyclomatic_Complexity,
      Constant_Condition,
      Unreachable_Code,
      Division_By_Zero,
      Reversed_Range,
      Self_Assignment,
      Same_Operand,
      Duplicate_Condition,
      Null_Statement,
      Empty_Exception_Handler,
      Unreachable_Branch,
      Contradictory_Condition,
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
      Deep_Nesting,
      Unused_Variable,
      Empty_If_Body,
      Unnecessary_Else_After_Return,
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
      Known_Precondition_Failure,
      Known_Postcondition_Failure,
      Known_Assertion_Failure,
      Known_Range_Check_Failure,
      Known_Index_Check_Failure,
      Known_Overflow_Failure,
      Identical_Case_Alternative,
      Redundant_Type_Conversion,
      Handler_Order,
      Aliasing_Between_Parameters,
      Missing_Loop_Variant,
      Known_Discriminant_Check_Failure,
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
      Suppression_Without_Rationale
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
      No_Unchecked_Conversion, No_Unchecked_Deallocation,
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
      No_Unchecked_Conversion, Floating_Equality, Magic_Number,
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
      Null_Statement =>
        (Name        => To_Unbounded_String ("Null_Statement"),
         Description => To_Unbounded_String
           ("Find null statements in executable code."),
         Guidance    => To_Unbounded_String
           ("Remove the placeholder or replace it with explicit handling so " &
            "the empty action is intentional."),
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
           ("Find SPARK subprograms that access global state without an " &
            "explicit Global contract."),
         Guidance    => To_Unbounded_String
           ("Add a Global aspect that classifies every global object as " &
            "Input, Output, In_Out, or Proof_In."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      Global_Contract_Mismatch =>
        (Name        => To_Unbounded_String ("Global_Contract_Mismatch"),
         Description => To_Unbounded_String
           ("Find global reads or writes that are omitted from a SPARK " &
            "Global contract or declared with an incompatible mode."),
         Guidance    => To_Unbounded_String
           ("Make the Global contract agree with the implementation's " &
            "actual reads and writes."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Missing_Depends_Contract =>
        (Name        => To_Unbounded_String ("Missing_Depends_Contract"),
         Description => To_Unbounded_String
           ("Find SPARK subprograms with outputs but no explicit Depends " &
            "contract."),
         Guidance    => To_Unbounded_String
           ("Add a Depends aspect documenting the inputs on which each " &
            "output depends."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      Incomplete_Depends_Contract =>
        (Name        => To_Unbounded_String ("Incomplete_Depends_Contract"),
         Description => To_Unbounded_String
           ("Find writable parameters or global outputs omitted from a " &
            "SPARK Depends contract."),
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
           ("Find adjacent case alternatives with identical bodies."),
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
         Quality => Quality_Maintainability, Severity => Severity_High)
   );

   function Lookup_Rule_Kind
     (Name : String; Found : out Boolean) return Rule_Kind;
   --  Resolves a check name typed on the command line to its Rule_Kind.
   --  Found is False (with an arbitrary result) when no check matches.

end Adalang_Analyzer.Rules;
