--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--  Modified by Spazio IT in 2026.
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
      Known_Precondition_Failure,
      Known_Postcondition_Failure
   );

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
         Severity    => Severity_High)
   );

   function Lookup_Rule_Kind
     (Name : String; Found : out Boolean) return Rule_Kind;
   --  Resolves a check name typed on the command line to its Rule_Kind.
   --  Found is False (with an arbitrary result) when no check matches.

end Adalang_Analyzer.Rules;
