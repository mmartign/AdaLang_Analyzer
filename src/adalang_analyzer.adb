--
--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--  Modified by Spazio IT in 2026.
--
--  SPDX-License-Identifier: GPL-3.0-or-later
--

--  Command-line driver and rule implementation for AdaLang Analyzer. Rules
--  are registered below, evaluated during one recursive Libadalang AST walk,
--  and reported with source locations and remediation guidance.

with Ada.Command_Line;
with Ada.Characters.Latin_1;
with Ada.Characters.Handling;
with Ada.Containers.Indefinite_Vectors;
with Ada.Text_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings;

with Libadalang.Analysis;
with Libadalang.Common;
with Langkit_Support.Text;

procedure Adalang_Analyzer is  --  adalang-analyzer: ignore Cyclomatic_Complexity
   use Ada.Strings.Unbounded;
   use type Libadalang.Analysis.Ada_Node;
   use type Libadalang.Common.Ada_Node_Kind_Type;
   use type Libadalang.Analysis.Basic_Decl;
   use type Ada.Directories.File_Kind;

   --  Whether a given check contributes violations during this run.
   type Rule_State is (Disabled, Enabled);

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
      Trailing_Whitespace
   );

   --  SonarQube-style classification of every check: the Software Quality
   --  it primarily affects, and the severity of a typical violation. This
   --  is this analyzer's own judgment applying SonarQube's Clean Code
   --  taxonomy to Ada constructs, not an imported SonarQube ruleset.
   type Software_Quality is
     (Quality_Security, Quality_Reliability, Quality_Maintainability);

   type Issue_Severity is
     (Severity_Blocker, Severity_High, Severity_Medium, Severity_Low);

   function Quality_Name (Quality : Software_Quality) return String is
   begin
      case Quality is
         when Quality_Security       => return "Security";
         when Quality_Reliability    => return "Reliability";
         when Quality_Maintainability => return "Maintainability";
      end case;
   end Quality_Name;

   function Severity_Name (Severity : Issue_Severity) return String is
   begin
      case Severity is
         when Severity_Blocker => return "Blocker";
         when Severity_High    => return "High";
         when Severity_Medium  => return "Medium";
         when Severity_Low     => return "Low";
      end case;
   end Severity_Name;

   --  The fixed metadata shown alongside every violation of a given check.
   type Rule_Info is record
      Name        : Ada.Strings.Unbounded.Unbounded_String;
      Description : Ada.Strings.Unbounded.Unbounded_String;
      Guidance    : Ada.Strings.Unbounded.Unbounded_String;
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
           ("Avoid goto statements because they make control flow " &
            "difficult to follow and verify."),
         Guidance    => To_Unbounded_String
           ("Replace the jump with structured control flow such as a " &
            "loop condition, if statement, return, or a small local " &
            "subprogram."),
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
           ("Compare the absolute or relative difference against a tolerance " &
            "appropriate for the values and numerical algorithm."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Magic_Number =>
        (Name        => To_Unbounded_String ("Magic_Number"),
         Description => To_Unbounded_String
           ("Find unexplained numeric literals other than 0, 1, and -1 that " &
            "are not part of a named constant declaration."),
         Guidance    => To_Unbounded_String
           ("Introduce a descriptively named constant so the value's meaning " &
            "and maintenance policy are explicit."),
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
      Dead_Store =>
        (Name        => To_Unbounded_String ("Dead_Store"),
         Description => To_Unbounded_String
           ("Find assignments whose stored value is never read later in the " &
            "enclosing subprogram."),
         Guidance    => To_Unbounded_String
           ("Remove the assignment or restore the later use that was intended " &
            "to consume the value."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      Overwritten_Assignment =>
        (Name        => To_Unbounded_String ("Overwritten_Assignment"),
         Description => To_Unbounded_String
           ("Find assignments overwritten in the same statement list before " &
            "their value is read."),
         Guidance    => To_Unbounded_String
           ("Remove the earlier assignment or use its value before assigning " &
            "the variable again."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Shadowed_Declaration =>
        (Name        => To_Unbounded_String ("Shadowed_Declaration"),
         Description => To_Unbounded_String
           ("Find local object declarations that hide an object or parameter " &
            "declared by an enclosing subprogram."),
         Guidance    => To_Unbounded_String
           ("Rename the inner declaration so references clearly identify the " &
            "intended object."),
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
           ("Find unconditional loops with no exit, return, or raise in their " &
            "body."),
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
           ("Find subprograms whose decision complexity exceeds the configured " &
            "threshold."),
         Guidance    => To_Unbounded_String
           ("Extract cohesive helpers or simplify branching so each subprogram " &
            "has fewer independent paths."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      Constant_Condition =>
        (Name        => To_Unbounded_String ("Constant_Condition"),
         Description => To_Unbounded_String
           ("Find conditions that are statically known to be always true " &
            "or always false."),
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
           ("Move the statement before the terminating statement, remove it, " &
            "or make the terminating statement conditional."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Medium),
      Division_By_Zero =>
        (Name        => To_Unbounded_String ("Division_By_Zero"),
         Description => To_Unbounded_String
           ("Find division, mod, and rem operations whose right operand is " &
            "statically zero."),
         Guidance    => To_Unbounded_String
           ("Guard the operation, change the divisor, or make the exceptional " &
            "case explicit before evaluating the operation."),
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
           ("Find assignments where the target and value are the same " &
            "syntactic expression."),
         Guidance    => To_Unbounded_String
           ("Remove the assignment or replace the right-hand side with the " &
            "value that was intended to update the object."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Same_Operand =>
        (Name        => To_Unbounded_String ("Same_Operand"),
         Description => To_Unbounded_String
           ("Find suspicious binary expressions that use the same expression " &
            "on both sides."),
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
           ("Handle, log, re-raise, or narrowly document the exception instead " &
            "of silently swallowing it."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Unreachable_Branch =>
        (Name        => To_Unbounded_String ("Unreachable_Branch"),
         Description => To_Unbounded_String
           ("Find if/elsif/else branches made unreachable by static " &
            "conditions earlier in the chain."),
         Guidance    => To_Unbounded_String
           ("Remove the branch or change the condition sequence so each branch " &
            "can be selected."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      Contradictory_Condition =>
        (Name        => To_Unbounded_String ("Contradictory_Condition"),
         Description => To_Unbounded_String
           ("Find boolean expressions of the form X and not X or X or not X."),
         Guidance    => To_Unbounded_String
           ("Correct the copied or negated operand, or replace the expression " &
            "with the intended constant value."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      Identical_Branches =>
        (Name        => To_Unbounded_String ("Identical_Branches"),
         Description => To_Unbounded_String
           ("Find adjacent if, elsif, or else branches with identical bodies."),
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
           ("Remove the ineffective operation or correct a constant or operand " &
            "that was entered incorrectly."),
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
           ("Find loops whose bodies contain only null statements or pragmas."),
         Guidance    => To_Unbounded_String
           ("Implement the missing loop body or remove the loop; an intentional " &
            "wait should use an explicit delay or synchronization operation."),
         Quality     => Quality_Reliability,
         Severity    => Severity_Medium),
      No_Recursion =>
        (Name        => To_Unbounded_String ("No_Recursion"),
         Description => To_Unbounded_String
           ("Find subprograms that call themselves directly, which can make " &
            "stack usage and termination harder to bound and verify."),
         Guidance    => To_Unbounded_String
           ("Replace the recursive call with an explicit loop and work list, " &
            "or document and isolate an intentional recursive algorithm."),
         Quality     => Quality_Reliability,
         Severity    => Severity_High),
      No_Multiple_Return =>
        (Name        => To_Unbounded_String ("No_Multiple_Return"),
         Description => To_Unbounded_String
           ("Find subprograms with more than one return statement, which can " &
            "make the exit points of a subprogram harder to audit."),
         Guidance    => To_Unbounded_String
           ("Restructure the subprogram around a single result variable and a " &
            "single return statement at its end."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Non_Short_Circuit_Condition =>
        (Name        => To_Unbounded_String ("Non_Short_Circuit_Condition"),
         Description => To_Unbounded_String
           ("Find plain and/or operators used in an if, elsif, exit-when, or " &
            "while condition, where a guard clause typically requires " &
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
           ("Prefer a normal declaration or an explicitly reviewed, isolated " &
            "and documented overlay when aliasing is genuinely required."),
         Quality     => Quality_Security,
         Severity    => Severity_High),
      Too_Many_Parameters =>
        (Name        => To_Unbounded_String ("Too_Many_Parameters"),
         Description => To_Unbounded_String
           ("Find subprograms whose parameter count exceeds the configured " &
            "threshold."),
         Guidance    => To_Unbounded_String
           ("Group related parameters into a record, or split the subprogram " &
            "into smaller, more cohesive operations."),
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
           ("Find local object declarations that are never referenced by the " &
            "enclosing subprogram's declarations or statements."),
         Guidance    => To_Unbounded_String
           ("Remove the declaration or use the object as intended."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Empty_If_Body =>
        (Name        => To_Unbounded_String ("Empty_If_Body"),
         Description => To_Unbounded_String
           ("Find if statements with no elsif or else part whose then branch " &
            "has no substantive statements, so the statement has no effect."),
         Guidance    => To_Unbounded_String
           ("Remove the if statement or implement the missing branch body."),
         Quality     => Quality_Maintainability,
         Severity    => Severity_Low),
      Unnecessary_Else_After_Return =>
        (Name        => To_Unbounded_String ("Unnecessary_Else_After_Return"),
         Description => To_Unbounded_String
           ("Find else parts that are unnecessary because the preceding then " &
            "branch always returns, raises, or exits."),
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
         Severity    => Severity_Low)
   );

   --  Runtime state and counters are indexed by the registry above so adding
   --  a rule automatically includes it in selection and summary operations.
   Rule_States       : array (Rule_Kind) of Rule_State := (others => Disabled);
   Verbose_Mode      : Boolean := False;
   Quiet_Mode        : Boolean := False;
   Show_Help_Flag    : Boolean := False;
   Show_Version      : Boolean := False;
   List_Checks_Only  : Boolean := False;
   Invalid_Options   : Boolean := False;
   Default_Complexity_Threshold : constant Positive := 10;
   Default_Nesting_Threshold     : constant Positive := 4;
   Default_Parameter_Threshold   : constant Positive := 6;
   Default_Line_Length_Threshold : constant Positive := 120;
   Maximum_Highlight_Width       : constant Positive := 120;
   Decimal_Base                  : constant Positive := 10;
   Minimum_Ada_Base              : constant Positive := 2;
   Maximum_Ada_Base              : constant Positive := 16;
   Maximum_Integer_Exponent      : constant Natural := 63;
   Invalid_Digit_Value           : constant Natural := 36;
   Floating_Zero_Tolerance       : constant Long_Long_Float :=
     Long_Long_Float'Model_Epsilon;

   Complexity_Threshold  : Positive := Default_Complexity_Threshold;
   Nesting_Threshold     : Positive := Default_Nesting_Threshold;
   Parameter_Threshold   : Positive := Default_Parameter_Threshold;
   Line_Length_Threshold : Positive := Default_Line_Length_Threshold;
   Source_File_Count : Natural := 0;
   Violations        : Natural := 0;
   Rule_Violations   : array (Rule_Kind) of Natural := (others => 0);
   Skipped_Nodes     : Natural := 0;

   --  Prints a diagnostic line when -verbose is set and -quiet isn't.
   procedure Log_Verbose (Message : String) is
   begin
      if Verbose_Mode and then not Quiet_Mode then
         Ada.Text_IO.Put_Line ("adalang-analyzer [INFO]: " & Message);
      end if;
   end Log_Verbose;

   --  Natural'Image without the leading space it adds for non-negative
   --  values, for compact "line:column:" style output.
   function To_Decimal (N : Natural) return String is
      Result : String := Natural'Image (N);
   begin
      return Ada.Strings.Fixed.Trim (Result, Ada.Strings.Both);
   end To_Decimal;

   --  Folds a check name to a case- and separator-insensitive form so
   --  "No_Goto", "no-goto", and "NO_GOTO" all match the same check.
   function Normalize_Rule_Name (Name : String) return String is
      Result : String (Name'Range) := Name;
   begin
      for I in Result'Range loop
         if Result (I) in 'A' .. 'Z' then
            Result (I) := Ada.Characters.Handling.To_Lower (Result (I));
         elsif Result (I) = '_' then
            Result (I) := '-';
         end if;
      end loop;
      return Result;
   end Normalize_Rule_Name;

   --  Resolves a check name typed on the command line to its Rule_Kind.
   --  Found is False (with an arbitrary result) when no check matches.
   function Lookup_Rule_Kind (Name : String; Found : out Boolean) return Rule_Kind is
      Normalized : constant String := Normalize_Rule_Name (Name);
   begin
      for R in Rule_Kind loop
         if Normalize_Rule_Name
              (Ada.Strings.Unbounded.To_String (Rule_Infos (R).Name)) =
            Normalized
         then
            Found := True;
            return R;
         end if;
      end loop;
      Found := False;
      return No_Goto;
   end Lookup_Rule_Kind;

   --  Count copies of Char, used to draw the "^^^" underline beneath a
   --  reported source excerpt.
   function Repeat_Char (Char : Character; Count : Natural) return String is
   begin
      if Count = 0 then
         return "";
      end if;

      declare
         Result : constant String (1 .. Count) := (others => Char);
      begin
         return Result;
      end;
   end Repeat_Char;

   --  Re-reads Filename to fetch the text of one line for the violation
   --  report. Returns "" rather than raising if the file or line is
   --  unavailable, since the excerpt is a display convenience, not
   --  required for the violation itself to be valid.
   function Source_Line (Filename : String; Line_Number : Natural) return String is
      File         : Ada.Text_IO.File_Type;
      Current_Line : Natural := 0;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Filename);

      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line : constant String := Ada.Text_IO.Get_Line (File);
         begin
            Current_Line := Current_Line + 1;

            if Current_Line = Line_Number then
               Ada.Text_IO.Close (File);
               return Line;
            end if;
         end;
      end loop;

      Ada.Text_IO.Close (File);
      return "";

   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;

         return "";
   end Source_Line;

   --  True when the source line carrying Node contains an explicit,
   --  rule-specific suppression comment. Suppressions are deliberately
   --  local and visible: "--  adalang-analyzer: ignore <Rule_Name>".
   function Is_Suppressed
     (Source_Text : String; Rule_Name : String) return Boolean
   is
      Marker : constant String :=
        "adalang-analyzer: ignore " & Rule_Name;
   begin
      return Ada.Strings.Fixed.Index (Source_Text, Marker) /= 0;
   end Is_Suppressed;

   --  GNAT emits *_config.ads files containing implementation pragmas that
   --  describe the compilation environment. They are generated metadata,
   --  not application source, so No_Pragma does not report them.
   function Is_Generated_Config_File (Filename : String) return Boolean is
      Suffix : constant String := "_config.ads";
   begin
      return Filename'Length >= Suffix'Length
        and then Filename
          (Filename'Last - Suffix'Length + 1 .. Filename'Last) = Suffix;
   end Is_Generated_Config_File;

   --  Length of the caret underline for Node: the node's on-line span, or
   --  a single caret when it crosses lines or has no width. Capped at 120
   --  so a large construct doesn't dominate the terminal output.
   function Highlight_Width
     (Node : Libadalang.Analysis.Ada_Node'Class) return Natural
   is
      Start_Line   : constant Natural := Natural (Node.Sloc_Range.Start_Line);
      End_Line     : constant Natural := Natural (Node.Sloc_Range.End_Line);
      Start_Column : constant Natural := Natural (Node.Sloc_Range.Start_Column);
      End_Column   : constant Natural := Natural (Node.Sloc_Range.End_Column);
      Width        : Natural := 1;
   begin
      if Start_Line = End_Line and then End_Column > Start_Column then
         Width := End_Column - Start_Column;
      end if;

      if Width > Maximum_Highlight_Width then
         return Maximum_Highlight_Width;
      else
         return Width;
      end if;
   end Highlight_Width;

   --  Central sink for every check: counts the violation, and unless
   --  -quiet is set, prints its location, message, rule metadata, and a
   --  source excerpt with a caret under the offending span. Shared by
   --  Report_Rule_Violation (AST-node checks) and Report_Line_Violation
   --  (raw source-text checks that have no single Ada_Node to anchor on).
   procedure Report_Violation_At
     (Filename    : String;
      Line_Number : Natural;
      Column      : Natural;
      Caret_Width : Natural;
      Rule        : Rule_Kind;
      Message     : String)
   is
      Rule_Name    : constant String :=
        Ada.Strings.Unbounded.To_String (Rule_Infos (Rule).Name);
      Source_Text  : constant String := Source_Line (Filename, Line_Number);
   begin
      if Is_Suppressed (Source_Text, Rule_Name) then
         return;
      end if;

      Violations := Violations + 1;
      Rule_Violations (Rule) := Rule_Violations (Rule) + 1;

      if not Quiet_Mode then
         Ada.Text_IO.Put_Line (Filename & ":" &
                   To_Decimal (Line_Number) & ":" &
                   To_Decimal (Column) &
                   ": warning: " & Message & " [" &
                   Rule_Name & "]");
         Ada.Text_IO.Put_Line ("  rule: " &
                   Ada.Strings.Unbounded.To_String (Rule_Infos (Rule).Description));
         Ada.Text_IO.Put_Line ("  advice: " &
                   Ada.Strings.Unbounded.To_String (Rule_Infos (Rule).Guidance));
         Ada.Text_IO.Put_Line ("  quality: " &
                   Quality_Name (Rule_Infos (Rule).Quality) & " (" &
                   Severity_Name (Rule_Infos (Rule).Severity) & ")");

         if Source_Text /= "" then
            Ada.Text_IO.Put_Line ("  source:");
            Ada.Text_IO.Put_Line ("    " & Source_Text);

            if Column > 0 then
               Ada.Text_IO.Put_Line
                 ("    " & Repeat_Char (' ', Column - 1) &
                  Repeat_Char ('^', Caret_Width));
            end if;
         end if;
      end if;
   end Report_Violation_At;

   --  AST-node violation report: derives the location and caret width from
   --  Node's source span.
   procedure Report_Rule_Violation (Unit : Libadalang.Analysis.Analysis_Unit;
                                   Node : Libadalang.Analysis.Ada_Node'Class;
                                   Rule : Rule_Kind;
                                   Message : String) is
   begin
      Report_Violation_At
        (Filename    => Unit.Get_Filename,
         Line_Number => Natural (Node.Sloc_Range.Start_Line),
         Column      => Natural (Node.Sloc_Range.Start_Column),
         Caret_Width => Highlight_Width (Node),
         Rule        => Rule,
         Message     => Message);
   end Report_Rule_Violation;

   --  Raw source-text violation report, for checks (Long_Line,
   --  Trailing_Whitespace) that scan file text directly rather than the
   --  Libadalang AST and so have no Ada_Node to anchor a report on.
   procedure Report_Line_Violation
     (Filename    : String;
      Line_Number : Natural;
      Column      : Natural;
      Caret_Width : Natural;
      Rule        : Rule_Kind;
      Message     : String) is
   begin
      Report_Violation_At
        (Filename    => Filename,
         Line_Number => Line_Number,
         Column      => Column,
         Caret_Width => Caret_Width,
         Rule        => Rule,
         Message     => Message);
   end Report_Line_Violation;

   --  Prints command-line usage for -h/--help and after an option error.
   procedure Show_Help is
   begin
      Ada.Text_IO.Put_Line ("Usage: adalang-analyzer [options] <source_files>");
      Ada.Text_IO.Put_Line ("");
      Ada.Text_IO.Put_Line ("A clang-tidy analyzer for Ada based on Libadalang.");
      Ada.Text_IO.Put_Line ("");
      Ada.Text_IO.Put_Line ("Options:");
      Ada.Text_IO.Put_Line ("  -h, --help            Show this help and exit");
      Ada.Text_IO.Put_Line ("  -version              Show version and exit");
      Ada.Text_IO.Put_Line ("  -P<project>.gpr       Analyze the sources of a GNAT project file");
      Ada.Text_IO.Put_Line ("  -checks=<list>        Enable/disable checks");
      Ada.Text_IO.Put_Line ("  -list-checks          List available checks");
      Ada.Text_IO.Put_Line
        ("  -complexity-threshold=<n>  Set complexity limit (default: 10)");
      Ada.Text_IO.Put_Line
        ("  -nesting-threshold=<n>     Set nesting depth limit (default: 4)");
      Ada.Text_IO.Put_Line
        ("  -parameter-threshold=<n>   Set parameter count limit (default: 6)");
      Ada.Text_IO.Put_Line
        ("  -line-length-threshold=<n> Set line length limit (default: 120)");
      Ada.Text_IO.Put_Line ("  -v, -verbose          Enable verbose output");
      Ada.Text_IO.Put_Line ("  -q, -quiet            Suppress summary output");
      Ada.Text_IO.Put_Line ("  --                    Treat items as files");
   end Show_Help;

   --  Prints the tool's version for -version.
   procedure Print_Version is
   begin
      Ada.Text_IO.Put_Line ("adalang-analyzer version 0.1.0-dev");
   end Print_Version;

   --  Prints every registered check with its description and remediation
   --  guidance, for -list-checks.
   procedure Print_Check_List is
   begin
      Ada.Text_IO.Put_Line ("Available checks:");
      for Rule in Rule_Kind loop
         Ada.Text_IO.Put_Line ("  " & Ada.Strings.Unbounded.To_String (Rule_Infos (Rule).Name) &
                               " [" & Quality_Name (Rule_Infos (Rule).Quality) & "/" &
                               Severity_Name (Rule_Infos (Rule).Severity) & "] - " &
                               Ada.Strings.Unbounded.To_String (Rule_Infos (Rule).Description));
         Ada.Text_IO.Put_Line ("    " &
                               Ada.Strings.Unbounded.To_String (Rule_Infos (Rule).Guidance));
      end loop;
   end Print_Check_List;

   --  Applies a GCC-style "+R<check>" / "-R<check>" switch, enabling or
   --  disabling exactly the named check.
   procedure Process_Command_Switch (Switch : String) is
      procedure Apply (Name : String; Mode : Rule_State) is
         Found : Boolean;
         Kind  : Rule_Kind;
      begin
         Kind := Lookup_Rule_Kind (Name, Found);
         if Found then
            Rule_States (Kind) := Mode;
         else
            Ada.Text_IO.Put_Line ("adalang-analyzer: unknown check '" & Name & "'");
            Invalid_Options := True;
         end if;
      end Apply;
   begin
      if Switch'Length < 3 then  --  adalang-analyzer: ignore Magic_Number
         return;
      end if;

      if Switch (Switch'First) = '-' and then Switch (Switch'First + 1) = 'R' then
         Apply (Switch (Switch'First + 2 .. Switch'Last), Disabled);  --  adalang-analyzer: ignore Magic_Number
      elsif Switch (Switch'First) = '+' and then Switch (Switch'First + 1) = 'R' then
         Apply (Switch (Switch'First + 2 .. Switch'Last), Enabled);  --  adalang-analyzer: ignore Magic_Number
      end if;
   end Process_Command_Switch;

   --  Applies a "-checks=<list>" option: a comma-separated list of check
   --  names, each optionally prefixed with '+' (enable, the default) or
   --  '-' (disable), plus the special items "*" (enable all) and "-*"
   --  (disable all).
   procedure Parse_Checks_Option (Option : String) is
      List_Text : constant String := Option (Option'First + 8 .. Option'Last);

      --  Applies one comma-separated item from the -checks= list.
      procedure Apply_Check_Item (Item_Untrimmed : String) is
         Item   : constant String :=
           Ada.Strings.Fixed.Trim (Item_Untrimmed, Ada.Strings.Both);
         Kind   : Rule_Kind;
         Found  : Boolean;
         Action : Rule_State := Enabled;
         First  : Positive;
      begin
         if Item = "" then
            null;  --  adalang-analyzer: ignore Null_Statement
         elsif Item = "*" then
            for R in Rule_Kind loop
               Rule_States (R) := Enabled;
            end loop;
         elsif Item = "-*" then
            for R in Rule_Kind loop
               Rule_States (R) := Disabled;
            end loop;
         else
            First := Item'First;
            Action := Enabled;

            if Item (First) = '+' then
               First := First + 1;
            elsif Item (First) = '-' then
               Action := Disabled;
               First := First + 1;
            end if;

            if First > Item'Last then
               Ada.Text_IO.Put_Line ("adalang-analyzer: empty check name");
               Invalid_Options := True;
            else
               declare
                  Name : constant String := Item (First .. Item'Last);
               begin
                  Kind := Lookup_Rule_Kind (Name, Found);
                  if Found then
                     Rule_States (Kind) := Action;
                  else
                     Ada.Text_IO.Put_Line
                       ("adalang-analyzer: unknown check '" & Name & "'");
                     Invalid_Options := True;
                  end if;
               end;
            end if;
         end if;
      end Apply_Check_Item;

      Start : Positive := List_Text'First;
   begin
      for Index in List_Text'Range loop
         if List_Text (Index) = ',' then
            Apply_Check_Item (List_Text (Start .. Index - 1));
            Start := Index + 1;
         end if;
      end loop;

      if Start <= List_Text'Last then
         Apply_Check_Item (List_Text (Start .. List_Text'Last));
      end if;
   end Parse_Checks_Option;

   --  Parses the -complexity-threshold value; records an invalid-option
   --  error instead of raising when Text isn't a positive integer.
   procedure Set_Complexity_Threshold (Text : String) is
   begin
      Complexity_Threshold := Positive'Value
        (Ada.Strings.Fixed.Trim (Text, Ada.Strings.Both));
   exception
      when others =>
         Ada.Text_IO.Put_Line
           ("adalang-analyzer: invalid complexity threshold '" & Text & "'");
         Invalid_Options := True;
   end Set_Complexity_Threshold;

   --  Parses the -nesting-threshold value; records an invalid-option error
   --  instead of raising when Text isn't a positive integer.
   procedure Set_Nesting_Threshold (Text : String) is
   begin
      Nesting_Threshold := Positive'Value
        (Ada.Strings.Fixed.Trim (Text, Ada.Strings.Both));
   exception
      when others =>
         Ada.Text_IO.Put_Line
           ("adalang-analyzer: invalid nesting threshold '" & Text & "'");
         Invalid_Options := True;
   end Set_Nesting_Threshold;

   --  Parses the -parameter-threshold value; records an invalid-option
   --  error instead of raising when Text isn't a positive integer.
   procedure Set_Parameter_Threshold (Text : String) is
   begin
      Parameter_Threshold := Positive'Value
        (Ada.Strings.Fixed.Trim (Text, Ada.Strings.Both));
   exception
      when others =>
         Ada.Text_IO.Put_Line
           ("adalang-analyzer: invalid parameter threshold '" & Text & "'");
         Invalid_Options := True;
   end Set_Parameter_Threshold;

   --  Parses the -line-length-threshold value; records an invalid-option
   --  error instead of raising when Text isn't a positive integer.
   procedure Set_Line_Length_Threshold (Text : String) is
   begin
      Line_Length_Threshold := Positive'Value
        (Ada.Strings.Fixed.Trim (Text, Ada.Strings.Both));
   exception
      when others =>
         Ada.Text_IO.Put_Line
           ("adalang-analyzer: invalid line length threshold '" & Text & "'");
         Invalid_Options := True;
   end Set_Line_Length_Threshold;

   --  Small abstract domains support safe constant folding without executing
   --  analyzed code or assuming a value when evaluation is incomplete.
   type Abstract_Bool is (Bool_Unknown, Bool_False, Bool_True);

   function Bool_Name (Value : Abstract_Bool) return String is
   begin
      case Value is
         when Bool_False =>
            return "false";
         when Bool_True =>
            return "true";
         when Bool_Unknown =>
            return "unknown";
      end case;
   end Bool_Name;

   function Not_Bool (Value : Abstract_Bool) return Abstract_Bool is
   begin
      case Value is
         when Bool_False =>
            return Bool_True;
         when Bool_True =>
            return Bool_False;
         when Bool_Unknown =>
            return Bool_Unknown;
      end case;
   end Not_Bool;

   function And_Bool
     (Left : Abstract_Bool; Right : Abstract_Bool) return Abstract_Bool
   is
   begin
      if Left = Bool_False or else Right = Bool_False then
         return Bool_False;
      elsif Left = Bool_True and then Right = Bool_True then
         return Bool_True;
      else
         return Bool_Unknown;
      end if;
   end And_Bool;

   function Or_Bool
     (Left : Abstract_Bool; Right : Abstract_Bool) return Abstract_Bool
   is
   begin
      if Left = Bool_True or else Right = Bool_True then
         return Bool_True;
      elsif Left = Bool_False and then Right = Bool_False then
         return Bool_False;
      else
         return Bool_Unknown;
      end if;
   end Or_Bool;

   function Eq_Bool
     (Left : Abstract_Bool; Right : Abstract_Bool) return Abstract_Bool
   is
   begin
      if Left = Bool_Unknown or else Right = Bool_Unknown then
         return Bool_Unknown;
      elsif Left = Right then
         return Bool_True;
      else
         return Bool_False;
      end if;
   end Eq_Bool;

   function Bool_From (Value : Boolean) return Abstract_Bool is
   begin
      if Value then
         return Bool_True;
      else
         return Bool_False;
      end if;
   end Bool_From;

   type Abstract_Int is record
      Known : Boolean := False;
      Value : Long_Long_Integer := 0;
   end record;

   Unknown_Int : constant Abstract_Int := (Known => False, Value => 0);

   --  Wraps a known value as an Abstract_Int.
   function Known_Int (Value : Long_Long_Integer) return Abstract_Int is
   begin
      return (Known => True, Value => Value);
   end Known_Int;

   --  ------------------------------------------------------------------
   --  Flow-sensitive constant propagation (best effort).
   --
   --  A Flow_State is a small association from a variable's defining name
   --  (not its Basic_Decl: a multi-name declaration like "X, Y : Integer"
   --  shares one Basic_Decl but has distinct defining names, and this map
   --  must not conflate X with Y) to the Abstract_Int it is statically
   --  known to hold at one point in a subprogram body. It backs a second,
   --  stateful walk (see Interpret_Subprogram_Flow) that runs alongside
   --  the ordinary node-local checks and lets Division_By_Zero and
   --  Constant_Condition see values learned from an earlier assignment,
   --  not just literals.
   --  ------------------------------------------------------------------

   Max_Flow_Vars : constant := 64;

   type Flow_Binding is record
      Decl  : Libadalang.Analysis.Ada_Node := Libadalang.Analysis.No_Ada_Node;
      Value : Abstract_Int := Unknown_Int;
   end record;

   type Flow_Binding_Array is array (1 .. Max_Flow_Vars) of Flow_Binding;

   type Flow_State is record
      Count    : Natural := 0;
      Bindings : Flow_Binding_Array;
   end record;

   Empty_Flow_State : constant Flow_State := (Count => 0, Bindings => (others => <>));

   --  The Abstract_Int known for Key, or Unknown_Int if Key isn't tracked.
   function Flow_Lookup
     (State : Flow_State;
      Key   : Libadalang.Analysis.Ada_Node) return Abstract_Int
   is
   begin
      if Libadalang.Analysis.Is_Null (Key) then
         return Unknown_Int;
      end if;

      for I in 1 .. State.Count loop
         if State.Bindings (I).Decl = Key then
            return State.Bindings (I).Value;
         end if;
      end loop;

      return Unknown_Int;
   end Flow_Lookup;

   --  Records that Key now holds Value, replacing any prior binding. Silently
   --  drops the update once Max_Flow_Vars bindings are in use: a subprogram
   --  with that many live scalars is rare, and losing precision there is
   --  safe (Flow_Lookup simply reports Unknown for what didn't fit).
   procedure Flow_Set
     (State : in out Flow_State;
      Key   : Libadalang.Analysis.Ada_Node;
      Value : Abstract_Int)
   is
   begin
      if Libadalang.Analysis.Is_Null (Key) then
         return;
      end if;

      for I in 1 .. State.Count loop
         if State.Bindings (I).Decl = Key then
            State.Bindings (I).Value := Value;
            return;
         end if;
      end loop;

      if State.Count < Max_Flow_Vars then
         State.Count := State.Count + 1;
         State.Bindings (State.Count) := (Decl => Key, Value => Value);
      end if;
   end Flow_Set;

   --  Marks Key as no longer statically known, e.g. because it was passed
   --  to a call this analysis can't see through. A no-op when Key was
   --  never tracked, so this never grows the table.
   procedure Flow_Havoc
     (State : in out Flow_State;
      Key   : Libadalang.Analysis.Ada_Node)
   is
   begin
      if Libadalang.Analysis.Is_Null (Key) then
         return;
      end if;

      for I in 1 .. State.Count loop
         if State.Bindings (I).Decl = Key then
            State.Bindings (I).Value := Unknown_Int;
            return;
         end if;
      end loop;
   end Flow_Havoc;

   --  The state true after either of two branches: a binding survives only
   --  where both sides agree on the same known value, which is exactly
   --  what makes it safe to describe a merged point as "X is always N".
   function Flow_Join (Left, Right : Flow_State) return Flow_State is
      Result : Flow_State := Empty_Flow_State;
   begin
      for I in 1 .. Left.Count loop
         declare
            Left_Value  : constant Abstract_Int := Left.Bindings (I).Value;
            Right_Value : constant Abstract_Int :=
              Flow_Lookup (Right, Left.Bindings (I).Decl);
         begin
            if Left_Value.Known and then Right_Value.Known
              and then Left_Value.Value = Right_Value.Value
            then
               Flow_Set (Result, Left.Bindings (I).Decl, Left_Value);
            end if;
         end;
      end loop;

      return Result;
   end Flow_Join;

   --  ASCII-only lower-casing; avoids pulling in Ada.Characters.Handling
   --  for the single case this tool needs (Ada source is ASCII-identified).
   function Lower_Char (Char : Character) return Character is
   begin
      if Char in 'A' .. 'Z' then
         return Ada.Characters.Handling.To_Lower (Char);
      else
         return Char;
      end if;
   end Lower_Char;

   --  Verbatim source text spanned by Node, or "" for a null node.
   function Node_Text
     (Node : Libadalang.Analysis.Ada_Node'Class) return String is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return "";
      else
         return Langkit_Support.Text.To_UTF8
           (Libadalang.Analysis.Text (Node));
      end if;
   end Node_Text;

   --  Whitespace-stripped, lower-cased source text of Node, used to compare
   --  expressions for textual equality (e.g. duplicate operands, repeated
   --  conditions) regardless of formatting or identifier casing. String
   --  literal contents and character literals are preserved verbatim so
   --  their case and spelling stay significant.
   function Canonical_Text  --  adalang-analyzer: ignore Cyclomatic_Complexity
     (Node : Libadalang.Analysis.Ada_Node'Class) return String
   is
      Text      : constant String := Node_Text (Node);
      Result    : Unbounded_String;
      Index     : Natural := Text'First;
      In_String : Boolean := False;
   begin
      while Index <= Text'Last loop
         if Text (Index) = '"' then
            Append (Result, Text (Index));
            if In_String and then Index < Text'Last
              and then Text (Index + 1) = '"'
            then
               --  Two quotes encode one quote inside an Ada string literal.
               Append (Result, Text (Index + 1));
               Index := Index + 2;  --  adalang-analyzer: ignore Magic_Number
            else
               In_String := not In_String;
               Index := Index + 1;
            end if;
         elsif In_String then
            Append (Result, Text (Index));
            Index := Index + 1;
         elsif Text (Index) = Character'Val (39)  --  adalang-analyzer: ignore Magic_Number
           and then Index + 2 <= Text'Last  --  adalang-analyzer: ignore Magic_Number
           and then Text (Index + 2) = Character'Val (39)  --  adalang-analyzer: ignore Magic_Number
         then
            --  Preserve the spelling and case of character literals.
            Append (Result, Text (Index .. Index + 2));  --  adalang-analyzer: ignore Magic_Number
            Index := Index + 3;  --  adalang-analyzer: ignore Magic_Number
         elsif Text (Index) not in ' '
           | Ada.Characters.Latin_1.HT
           | Ada.Characters.Latin_1.LF
           | Ada.Characters.Latin_1.CR
         then
            Append (Result, Lower_Char (Text (Index)));
            Index := Index + 1;
         else
            Index := Index + 1;  --  adalang-analyzer: ignore Dead_Store
         end if;
      end loop;

      return To_String (Result);
   end Canonical_Text;

   --  Removes numeric-literal digit-group underscores (e.g. "1_000") and
   --  lower-cases the rest, producing a form Long_Long_Integer'Value /
   --  Long_Long_Float'Value or this unit's own parser can consume.
   function Strip_Underscores (Text : String) return String is
      Result : Unbounded_String;
   begin
      for Char of Text loop
         if Char /= '_' then
            Append (Result, Lower_Char (Char));
         end if;
      end loop;

      return To_String (Result);
   end Strip_Underscores;

   --  Index of the first occurrence of Char at or after From, or 0 if
   --  there is none (mirrors Ada.Strings.Fixed.Index's "not found" case
   --  without needing that package's Mapping/Pattern machinery).
   function Find_Char
     (Text : String; Char : Character; From : Positive) return Natural
   is
   begin
      if Text = "" or else From > Text'Last then
         return 0;
      end if;

      for Index in From .. Text'Last loop
         if Text (Index) = Char then
            return Index;
         end if;
      end loop;

      return 0;
   end Find_Char;

   --  Value of a base-16 digit (0-9, a-f); 36 (an impossible digit in any
   --  Ada numeric base, which range up to 16) signals "not a digit".
   function Digit_Value (Char : Character) return Natural is
   begin
      if Char in '0' .. '9' then
         return Character'Pos (Char) - Character'Pos ('0');
      elsif Char in 'a' .. 'f' then
         return Decimal_Base + Character'Pos (Char) - Character'Pos ('a');
      else
         return Invalid_Digit_Value;
      end if;
   end Digit_Value;

   --  Parses Text as an unsigned integer in the given Base, rejecting
   --  out-of-range digits and overflow rather than raising, since this
   --  parser must degrade to Unknown_Int instead of crashing on whatever
   --  numeric literal spelling appears in the analyzed source.
   function Parse_Unsigned
     (Text : String; Base : Positive; Value : out Long_Long_Integer)
      return Boolean
   is
      Result : Long_Long_Integer := 0;
   begin
      if Text = "" then
         return False;
      end if;

      for Char of Text loop
         declare
            Digit : constant Natural := Digit_Value (Char);
         begin
            if Digit >= Base then
               return False;
            end if;

            if Result >
              (Long_Long_Integer'Last - Long_Long_Integer (Digit)) /
              Long_Long_Integer (Base)
            then
               return False;
            end if;

            Result := Result * Long_Long_Integer (Base) +
              Long_Long_Integer (Digit);
         end;
      end loop;

      Value := Result;
      return True;
   end Parse_Unsigned;

   --  Parses the "e<digits>" suffix of an Ada numeric literal (Text is the
   --  part after 'e'); a missing suffix is a valid exponent of 0. A '-'
   --  sign is rejected because Ada only allows positive exponents here.
   function Parse_Exponent
     (Text : String; Value : out Natural) return Boolean
   is
      Start  : Positive := Text'First;
      Parsed : Long_Long_Integer;
   begin
      if Text = "" then
         Value := 0;
         return True;
      end if;

      if Text (Start) = '+' then
         Start := Start + 1;
      elsif Text (Start) = '-' then
         return False;
      end if;

      if Start > Text'Last then
         return False;
      end if;

      if not Parse_Unsigned (Text (Start .. Text'Last), Decimal_Base, Parsed) then
         return False;
      elsif Parsed > Long_Long_Integer (Natural'Last) then
         return False;  --  adalang-analyzer: ignore Identical_Branches
      else
         Value := Natural (Parsed);
         return True;
      end if;
   end Parse_Exponent;

   --  Computes Value * Base**Exponent, returning False on overflow instead
   --  of raising Constraint_Error so the caller can fall back to Unknown_Int.
   function Multiply_By_Power
     (Value : Long_Long_Integer; Base : Positive; Exponent : Natural;
      Result : out Long_Long_Integer) return Boolean
   is
      Current : Long_Long_Integer := Value;
   begin
      if Exponent > Maximum_Integer_Exponent then
         return False;
      end if;

      for Count in 1 .. Exponent loop
         if Current >
           Long_Long_Integer'Last / Long_Long_Integer (Base)
         then
            return False;
         end if;

         Current := Current * Long_Long_Integer (Base);
      end loop;

      Result := Current;
      return True;
   end Multiply_By_Power;

   --  Parses an Ada integer literal, including the based form
   --  "<base>#<digits>#[e<exponent>]" (e.g. "16#FF#") and the decimal form
   --  with an optional exponent (e.g. "12e3"). This hand-written parser
   --  exists because Long_Long_Integer'Value doesn't accept Ada's based
   --  literal syntax.
   function Parse_Integer_Text  --  adalang-analyzer: ignore Cyclomatic_Complexity
     (Raw_Text : String; Value : out Long_Long_Integer) return Boolean
   is
      Text       : constant String := Strip_Underscores (Raw_Text);
      Hash_1     : Natural;
      Hash_2     : Natural;
      Exp_Index  : Natural;
      Base_Value : Long_Long_Integer;
      Number     : Long_Long_Integer;
      Exponent   : Natural := 0;
   begin
      if Text = "" then
         return False;
      end if;

      Hash_1 := Find_Char (Text, '#', Text'First);

      if Hash_1 /= 0 then
         if Hash_1 = Text'First then
            return False;
         end if;

         Hash_2 := Find_Char (Text, '#', Hash_1 + 1);

         if Hash_2 = 0 or else Hash_2 = Hash_1 + 1 then
            return False;
         end if;

         if not Parse_Unsigned
           (Text (Text'First .. Hash_1 - 1), Decimal_Base, Base_Value)
           or else Base_Value < Long_Long_Integer (Minimum_Ada_Base)
           or else Base_Value > Long_Long_Integer (Maximum_Ada_Base)
         then
            return False;
         end if;

         if not Parse_Unsigned
           (Text (Hash_1 + 1 .. Hash_2 - 1), Positive (Base_Value), Number)
         then
            return False;
         end if;

         if Hash_2 < Text'Last then
            if Text (Hash_2 + 1) /= 'e' then
               return False;
            end if;

            if not Parse_Exponent
              (Text (Hash_2 + 2 .. Text'Last), Exponent)  --  adalang-analyzer: ignore Magic_Number
            then
               return False;
            end if;
         end if;

         return Multiply_By_Power
           (Number, Positive (Base_Value), Exponent, Value);
      end if;

      Exp_Index := Find_Char (Text, 'e', Text'First);

      if Exp_Index = 0 then
         return Parse_Unsigned (Text, Decimal_Base, Value);
      elsif Exp_Index = Text'First then
         return False;
      else
         if not Parse_Unsigned
           (Text (Text'First .. Exp_Index - 1), Decimal_Base, Number)
         then
            return False;
         end if;

         if not Parse_Exponent
           (Text (Exp_Index + 1 .. Text'Last), Exponent)
         then
            return False;
         end if;

         return Multiply_By_Power (Number, Decimal_Base, Exponent, Value);
      end if;
   end Parse_Integer_Text;

   --  Safe_Add/Sub/Mul/Pow fold a binary integer operation, collapsing to
   --  Unknown_Int on overflow rather than propagating Constraint_Error out
   --  of the analyzer.
   function Safe_Add
     (Left : Long_Long_Integer; Right : Long_Long_Integer) return Abstract_Int
   is
   begin
      return Known_Int (Left + Right);
   exception
      when Constraint_Error =>
         return Unknown_Int;
   end Safe_Add;

   function Safe_Sub
     (Left : Long_Long_Integer; Right : Long_Long_Integer) return Abstract_Int
   is
   begin
      return Known_Int (Left - Right);
   exception
      when Constraint_Error =>
         return Unknown_Int;
   end Safe_Sub;

   function Safe_Mul
     (Left : Long_Long_Integer; Right : Long_Long_Integer) return Abstract_Int
   is
   begin
      return Known_Int (Left * Right);
   exception
      when Constraint_Error =>
         return Unknown_Int;
   end Safe_Mul;

   function Safe_Pow
     (Left : Long_Long_Integer; Right : Long_Long_Integer) return Abstract_Int
   is
      Result : Long_Long_Integer := 1;
   begin
      --  A 64-bit magnitude can't hold 2**64 or higher, and Ada's "**"
      --  disallows a negative exponent for an integer base.
      if Right < 0 or else Right > Long_Long_Integer (Maximum_Integer_Exponent) then
         return Unknown_Int;
      end if;

      for Count in 1 .. Right loop
         Result := Result * Left;
      end loop;

      return Known_Int (Result);
   exception
      when Constraint_Error =>
         return Unknown_Int;
   end Safe_Pow;

   --  Statically evaluates Node as an integer expression when its value is
   --  determined purely by literals and constant arithmetic (+, -, abs,
   --  and the binary operators), returning Unknown_Int for anything that
   --  depends on a variable, a function call, or unsupported syntax. This
   --  drives the Division_By_Zero, Reversed_Range, and case-range checks
   --  without a full constant-folding evaluator.
   function Integer_Value  --  adalang-analyzer: ignore Cyclomatic_Complexity
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      State : Flow_State := Empty_Flow_State) return Abstract_Int
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return Unknown_Int;
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_Int_Literal =>
            declare
               Parsed : Long_Long_Integer;
            begin
               if Parse_Integer_Text (Node_Text (Node), Parsed) then
                  return Known_Int (Parsed);
               else
                  return Unknown_Int;
               end if;
            end;

         when Libadalang.Common.Ada_Identifier =>
            return Flow_Lookup
              (State,
               Libadalang.Analysis.Ada_Node
                 (Node.As_Name.P_Referenced_Defining_Name));

         when Libadalang.Common.Ada_Paren_Expr =>
            return Integer_Value (Node.As_Paren_Expr.F_Expr, State);

         when Libadalang.Common.Ada_Qual_Expr =>
            return Integer_Value (Node.As_Qual_Expr.F_Suffix, State);

         when Libadalang.Common.Ada_Un_Op =>
            declare
               Expr  : constant Libadalang.Analysis.Un_Op := Node.As_Un_Op;
               Value : constant Abstract_Int :=
                 Integer_Value (Expr.F_Expr, State);
            begin
               if not Value.Known then
                  return Unknown_Int;
               end if;

               case Expr.F_Op is
                  when Libadalang.Common.Ada_Op_Plus =>
                     return Value;
                  when Libadalang.Common.Ada_Op_Minus =>
                     if Value.Value = Long_Long_Integer'First then
                        return Unknown_Int;
                     else
                        return Known_Int (-Value.Value);
                     end if;
                  when Libadalang.Common.Ada_Op_Abs =>
                     if Value.Value = Long_Long_Integer'First then
                        return Unknown_Int;
                     elsif Value.Value < 0 then
                        return Known_Int (-Value.Value);
                     else
                        return Value;
                     end if;
                  when others =>
                     return Unknown_Int;
               end case;
            end;

         when Libadalang.Common.Ada_Bin_Op_Range =>
            declare
               Expr  : constant Libadalang.Analysis.Bin_Op := Node.As_Bin_Op;
               Left  : constant Abstract_Int :=
                 Integer_Value (Expr.F_Left, State);
               Right : constant Abstract_Int :=
                 Integer_Value (Expr.F_Right, State);
            begin
               if not Left.Known or else not Right.Known then
                  return Unknown_Int;
               end if;

               case Expr.F_Op is
                  when Libadalang.Common.Ada_Op_Plus =>
                     return Safe_Add (Left.Value, Right.Value);
                  when Libadalang.Common.Ada_Op_Minus =>
                     return Safe_Sub (Left.Value, Right.Value);
                  when Libadalang.Common.Ada_Op_Mult =>
                     return Safe_Mul (Left.Value, Right.Value);
                  when Libadalang.Common.Ada_Op_Div =>
                     if Right.Value = 0 then
                        return Unknown_Int;
                     else
                        return Known_Int (Left.Value / Right.Value);
                     end if;
                  when Libadalang.Common.Ada_Op_Mod =>
                     if Right.Value = 0 then
                        return Unknown_Int;
                     else
                        return Known_Int (Left.Value mod Right.Value);
                     end if;
                  when Libadalang.Common.Ada_Op_Rem =>
                     if Right.Value = 0 then
                        return Unknown_Int;
                     else
                        return Known_Int (Left.Value rem Right.Value);
                     end if;
                  when Libadalang.Common.Ada_Op_Pow =>
                     return Safe_Pow (Left.Value, Right.Value);
                  when others =>
                     return Unknown_Int;
               end case;
            end;

         when others =>
            return Unknown_Int;
      end case;
   exception
      when others =>
         return Unknown_Int;
   end Integer_Value;

   --  True when Node statically evaluates to 0, covering both integer and
   --  real literals (Integer_Value only handles the integer case).
   function Is_Static_Zero
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Int_Value : constant Abstract_Int := Integer_Value (Node);
   begin
      if Int_Value.Known then
         return Int_Value.Value = 0;
      end if;

      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_Real_Literal =>
            declare
               Value : constant Long_Long_Float :=
                 Long_Long_Float'Value (Strip_Underscores (Node_Text (Node)));
            begin
               return abs Value <= Floating_Zero_Tolerance;
            exception
               when others =>
                  return False;
            end;

         when Libadalang.Common.Ada_Paren_Expr =>
            return Is_Static_Zero (Node.As_Paren_Expr.F_Expr);

         when Libadalang.Common.Ada_Qual_Expr =>
            return Is_Static_Zero (Node.As_Qual_Expr.F_Suffix);

         when Libadalang.Common.Ada_Un_Op =>
            return Is_Static_Zero (Node.As_Un_Op.F_Expr);

         when others =>
            return False;
      end case;
   end Is_Static_Zero;

   --  True when Node statically evaluates to 1 (integer or real).
   function Is_Static_One
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Value : constant Abstract_Int := Integer_Value (Node);
   begin
      if Value.Known then
         return Value.Value = 1;
      end if;

      if Libadalang.Analysis.Is_Null (Node)
        or else Node.Kind /= Libadalang.Common.Ada_Real_Literal
      then
         return False;
      end if;

      return Long_Long_Float'Value
        (Strip_Underscores (Node_Text (Node))) = 1.0;
   exception
      when others =>
         return False;
   end Is_Static_One;

   --  True when Node's nearest enclosing statement/declaration is itself a
   --  named-number or constant object declaration, i.e. Node is the value
   --  being given a name rather than a "magic number" used inline.
   function Is_In_Named_Constant_Declaration
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Ancestor : Libadalang.Analysis.Ada_Node := Node.Parent;
   begin
      while not Libadalang.Analysis.Is_Null (Ancestor) loop
         case Ancestor.Kind is
            when Libadalang.Common.Ada_Number_Decl =>
               return True;

            when Libadalang.Common.Ada_Object_Decl =>
               declare
                  Declaration : constant Libadalang.Analysis.Object_Decl :=
                    Ancestor.As_Object_Decl;
               begin
                  return Declaration.F_Has_Constant
                    or else Ada.Strings.Fixed.Index
                      (Ada.Characters.Handling.To_Lower
                         (Node_Text (Declaration)),
                       "constant") /= 0;
               end;

            when others =>
               if Ancestor.Kind in Libadalang.Common.Ada_Stmt
                 or else Ancestor.Kind in Libadalang.Common.Ada_Basic_Decl
               then
                  return False;
               end if;
               Ancestor := Ancestor.Parent;
         end case;
      end loop;

      return False;
   exception
      when others =>
         return False;
   end Is_In_Named_Constant_Declaration;

   --  True when a numeric literal is exempt from Magic_Number: 0, 1, and
   --  -1 are conventionally self-explanatory, and a literal that is
   --  itself the definition of a named constant is, by definition, named.
   function Is_Allowed_Magic_Number
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean is
   begin
      return Is_Static_Zero (Node)
        or else Is_Static_One (Node)
        or else Is_In_Named_Constant_Declaration (Node);
   end Is_Allowed_Magic_Number;

   function Is_Floating_Expression
     (Node : Libadalang.Analysis.Expr'Class) return Boolean
   is
      Expr_Type : constant Libadalang.Analysis.Base_Type_Decl :=
        Node.P_Expression_Type;
   begin
      return not Libadalang.Analysis.Is_Null (Expr_Type)
        and then Expr_Type.P_Is_Float_Type (Node);
   exception
      when others =>
         --  Name resolution can legitimately fail for incomplete source.
         return False;
   end Is_Floating_Expression;

   --  True when Node is (or parenthesizes/qualifies) the literal "null",
   --  used to recognize "X = null" style comparisons as statically decided.
   function Is_Null_Literal
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_Null_Literal =>
            return True;
         when Libadalang.Common.Ada_Paren_Expr =>
            return Is_Null_Literal (Node.As_Paren_Expr.F_Expr);
         when Libadalang.Common.Ada_Qual_Expr =>
            return Is_Null_Literal (Node.As_Qual_Expr.F_Suffix);
         when others =>
            return False;
      end case;
   end Is_Null_Literal;

   --  True when Node is the identifier "True" or "False" (case-insensitive),
   --  i.e. a syntactic boolean literal rather than an evaluated expression.
   --  Backs Redundant_Boolean_Comparison; uses the same spelling-based
   --  heuristic as Boolean_Value's identifier case further below.
   function Is_Boolean_Literal
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Node)
        or else Node.Kind /= Libadalang.Common.Ada_Identifier
      then
         return False;
      end if;

      declare
         Text : constant String := Normalize_Rule_Name (Node_Text (Node));
      begin
         return Text = "true" or else Text = "false";
      end;
   end Is_Boolean_Literal;

   --  Evaluates a relational operator over two statically known integers;
   --  Bool_Unknown if either operand isn't known or Op isn't relational.
   function Compare_Integers
     (Op : Libadalang.Common.Ada_Node_Kind_Type;
      Left : Abstract_Int; Right : Abstract_Int) return Abstract_Bool
   is
   begin
      if not Left.Known or else not Right.Known then
         return Bool_Unknown;
      end if;

      case Op is
         when Libadalang.Common.Ada_Op_Eq =>
            return Bool_From (Left.Value = Right.Value);
         when Libadalang.Common.Ada_Op_Neq =>
            return Bool_From (Left.Value /= Right.Value);
         when Libadalang.Common.Ada_Op_Lt =>
            return Bool_From (Left.Value < Right.Value);
         when Libadalang.Common.Ada_Op_Lte =>
            return Bool_From (Left.Value <= Right.Value);
         when Libadalang.Common.Ada_Op_Gt =>
            return Bool_From (Left.Value > Right.Value);
         when Libadalang.Common.Ada_Op_Gte =>
            return Bool_From (Left.Value >= Right.Value);
         when others =>
            return Bool_Unknown;
      end case;
   end Compare_Integers;

   --  Statically evaluates Node as a boolean expression: the literals
   --  True/False, "not", "and"/"or"/"xor" (and their short-circuit forms),
   --  relational and equality comparisons on statically known integers,
   --  "= null"/"/= null", and static membership tests. Anything else
   --  (a variable, a function call, ...) yields Bool_Unknown. This backs
   --  Constant_Condition, Infinite_Loop's while-condition check, and the
   --  Ineffective_Operation / Constant_Result_Operation identity folding.
   function Boolean_Value  --  adalang-analyzer: ignore Cyclomatic_Complexity
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      State : Flow_State := Empty_Flow_State) return Abstract_Bool
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return Bool_Unknown;
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_Identifier =>
            declare
               Text : constant String :=
                 Normalize_Rule_Name
                   (Langkit_Support.Text.To_UTF8
                      (Libadalang.Analysis.Text (Node)));
            begin
               if Text = "true" then
                  return Bool_True;
               elsif Text = "false" then
                  return Bool_False;
               else
                  return Bool_Unknown;
               end if;
            end;

         when Libadalang.Common.Ada_Paren_Expr =>
            return Boolean_Value (Node.As_Paren_Expr.F_Expr, State);

         when Libadalang.Common.Ada_Un_Op =>
            declare
               Expr : constant Libadalang.Analysis.Un_Op := Node.As_Un_Op;
            begin
               if Expr.F_Op = Libadalang.Common.Ada_Op_Not then
                  return Not_Bool (Boolean_Value (Expr.F_Expr, State));
               else
                  return Bool_Unknown;
               end if;
            end;

         when Libadalang.Common.Ada_Bin_Op_Range =>
            declare
               Expr  : constant Libadalang.Analysis.Bin_Op := Node.As_Bin_Op;
               Left  : constant Abstract_Bool :=
                 Boolean_Value (Expr.F_Left, State);
               Right : constant Abstract_Bool :=
                 Boolean_Value (Expr.F_Right, State);
               Op    : constant Libadalang.Common.Ada_Node_Kind_Type :=
                 Expr.F_Op;
            begin
               case Op is
                  when Libadalang.Common.Ada_Op_And
                     | Libadalang.Common.Ada_Op_And_Then =>
                     return And_Bool (Left, Right);
                  when Libadalang.Common.Ada_Op_Or
                     | Libadalang.Common.Ada_Op_Or_Else =>
                     return Or_Bool (Left, Right);
                  when Libadalang.Common.Ada_Op_Eq =>
                     declare
                        Bool_Result : constant Abstract_Bool :=
                          Eq_Bool (Left, Right);
                        Int_Result  : constant Abstract_Bool :=
                          Compare_Integers
                            (Op, Integer_Value (Expr.F_Left, State),
                             Integer_Value (Expr.F_Right, State));
                     begin
                        if Bool_Result /= Bool_Unknown then
                           return Bool_Result;
                        elsif Int_Result /= Bool_Unknown then
                           return Int_Result;
                        elsif Is_Null_Literal (Expr.F_Left)
                          and then Is_Null_Literal (Expr.F_Right)
                        then
                           return Bool_True;
                        else
                           return Bool_Unknown;
                        end if;
                     end;
                  when Libadalang.Common.Ada_Op_Neq =>
                     declare
                        Bool_Result : constant Abstract_Bool :=
                          Not_Bool (Eq_Bool (Left, Right));
                        Int_Result  : constant Abstract_Bool :=
                          Compare_Integers
                            (Op, Integer_Value (Expr.F_Left, State),
                             Integer_Value (Expr.F_Right, State));
                     begin
                        if Bool_Result /= Bool_Unknown then
                           return Bool_Result;
                        elsif Int_Result /= Bool_Unknown then
                           return Int_Result;
                        elsif Is_Null_Literal (Expr.F_Left)
                          and then Is_Null_Literal (Expr.F_Right)
                        then
                           return Bool_False;
                        else
                           return Bool_Unknown;
                        end if;
                     end;
                  when Libadalang.Common.Ada_Op_Xor =>
                     return Not_Bool (Eq_Bool (Left, Right));
                  when Libadalang.Common.Ada_Op_Lt
                     | Libadalang.Common.Ada_Op_Lte
                     | Libadalang.Common.Ada_Op_Gt
                     | Libadalang.Common.Ada_Op_Gte =>
                     return Compare_Integers
                       (Op, Integer_Value (Expr.F_Left, State),
                        Integer_Value (Expr.F_Right, State));
                  when others =>
                     return Bool_Unknown;
               end case;
            end;

         when Libadalang.Common.Ada_Membership_Expr =>
            declare
               Expr      : constant Libadalang.Analysis.Membership_Expr :=
                 Node.As_Membership_Expr;
               Subject   : constant Abstract_Int :=
                 Integer_Value (Expr.F_Expr, State);
               Known_All : Boolean := True;
               Matches   : Boolean := False;
            begin
               if not Subject.Known then
                  return Bool_Unknown;
               end if;

               for I in 1 .. Expr.F_Membership_Exprs.Children_Count loop
                  declare
                     Alternative : constant Libadalang.Analysis.Ada_Node :=
                       Expr.F_Membership_Exprs.Child (I);
                  begin
                     if Alternative.Kind in Libadalang.Common.Ada_Bin_Op_Range
                       and then Alternative.As_Bin_Op.F_Op =
                         Libadalang.Common.Ada_Op_Double_Dot
                     then
                        declare
                           Left_Bound  : constant Abstract_Int :=
                             Integer_Value
                               (Alternative.As_Bin_Op.F_Left, State);
                           Right_Bound : constant Abstract_Int :=
                             Integer_Value
                               (Alternative.As_Bin_Op.F_Right, State);
                        begin
                           if Left_Bound.Known and then Right_Bound.Known then
                              Matches := Matches or else
                                (Subject.Value >= Left_Bound.Value
                                 and then Subject.Value <= Right_Bound.Value);
                           else
                              Known_All := False;
                           end if;
                        end;
                     else
                        declare
                           Value : constant Abstract_Int :=
                             Integer_Value (Alternative, State);
                        begin
                           if Value.Known then
                              Matches := Matches or else
                                Subject.Value = Value.Value;
                           else
                              Known_All := False;
                           end if;
                        end;
                     end if;
                  end;
               end loop;

               if not Known_All then
                  return Bool_Unknown;
               elsif Expr.F_Op = Libadalang.Common.Ada_Op_In then
                  return Bool_From (Matches);
               else
                  return Bool_From (not Matches);
               end if;
            end;

         when others =>
            return Bool_Unknown;
      end case;
   end Boolean_Value;

   --  Reports Constant_Condition when Cond statically evaluates to a fixed
   --  boolean. Shared by if/elsif/while/exit-when condition sites.
   procedure Report_Constant_Condition
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Cond : Libadalang.Analysis.Ada_Node'Class)
   is
      Value : constant Abstract_Bool := Boolean_Value (Cond);
   begin
      if Rule_States (Constant_Condition) = Enabled
        and then Value /= Bool_Unknown
      then
         Report_Rule_Violation
           (Unit, Cond, Constant_Condition,
            "condition is always " & Bool_Name (Value));
      end if;
   end Report_Constant_Condition;

   --  Reports Non_Short_Circuit_Condition for every plain "and"/"or"
   --  operator anywhere within Cond's subtree. Shared by if/elsif/while/
   --  exit-when condition sites, alongside Report_Constant_Condition.
   procedure Report_Non_Short_Circuit_Operators
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Cond : Libadalang.Analysis.Ada_Node'Class)
   is
   begin
      if Rule_States (Non_Short_Circuit_Condition) /= Enabled
        or else Libadalang.Analysis.Is_Null (Cond)
      then
         return;
      end if;

      if Cond.Kind in Libadalang.Common.Ada_Bin_Op_Range then
         case Cond.As_Bin_Op.F_Op is
            when Libadalang.Common.Ada_Op_And =>
               Report_Rule_Violation
                 (Unit, Cond, Non_Short_Circuit_Condition,
                  "use 'and then' instead of 'and' in a condition");
            when Libadalang.Common.Ada_Op_Or =>
               Report_Rule_Violation
                 (Unit, Cond, Non_Short_Circuit_Condition,
                  "use 'or else' instead of 'or' in a condition");
            when others =>
               null;  --  adalang-analyzer: ignore Null_Statement
         end case;
      end if;

      for I in 1 .. Cond.Children_Count loop
         Report_Non_Short_Circuit_Operators (Unit, Cond.Child (I));
      end loop;
   end Report_Non_Short_Circuit_Operators;

   --  True when Node unconditionally transfers control out of the
   --  statement list it's in (return, raise, goto, or an unconditional
   --  exit), making any following statement in the same list unreachable.
   function Terminates_Statement
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_Return_Stmt
            | Libadalang.Common.Ada_Extended_Return_Stmt
            | Libadalang.Common.Ada_Raise_Stmt
            | Libadalang.Common.Ada_Goto_Stmt =>
            return True;

         when Libadalang.Common.Ada_Exit_Stmt =>
            return Libadalang.Analysis.Is_Null
              (Node.As_Exit_Stmt.F_Cond_Expr);

         when others =>
            return False;
      end case;
   end Terminates_Statement;

   --  True when List contains anything other than null statements and
   --  pragmas, i.e. it does real work. Shared by Empty_Loop, Empty_If_Body,
   --  and the exception-handler checks.
   function Has_Substantive_Statement
     (List : Libadalang.Analysis.Stmt_List) return Boolean is
   begin
      for I in 1 .. List.Children_Count loop
         declare
            Stmt : constant Libadalang.Analysis.Ada_Node := List.Child (I);
         begin
            if Libadalang.Analysis.Is_Null (Stmt)
              or else Stmt.Kind = Libadalang.Common.Ada_Pragma_Node
              or else Stmt.Kind = Libadalang.Common.Ada_Null_Stmt
            then
               null;  --  adalang-analyzer: ignore Null_Statement
            else
               return True;
            end if;
         end;
      end loop;

      return False;
   end Has_Substantive_Statement;

   --  The declaration an identifier resolves to via Libadalang's semantic
   --  analysis, or No_Basic_Decl for anything else or when resolution
   --  fails (e.g. on source with unresolved references).
   function Referenced_Declaration
     (Node : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Basic_Decl
   is
   begin
      if not Libadalang.Analysis.Is_Null (Node)
        and then Node.Kind = Libadalang.Common.Ada_Identifier
      then
         return Node.As_Name.P_Referenced_Decl;
      end if;

      return Libadalang.Analysis.No_Basic_Decl;
   exception
      when others =>
         return Libadalang.Analysis.No_Basic_Decl;
   end Referenced_Declaration;

   --  True when any identifier under Node resolves to Decl. Used as the
   --  "is this object mentioned at all" building block for the
   --  Unused_Parameter check.
   function References_Declaration
     (Node : Libadalang.Analysis.Ada_Node'Class;
      Decl : Libadalang.Analysis.Basic_Decl) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Node)
        or else Libadalang.Analysis.Is_Null (Decl)
      then
         return False;
      end if;

      if Node.Kind = Libadalang.Common.Ada_Identifier
        and then Referenced_Declaration (Node) = Decl
      then
         return True;
      end if;

      for I in 1 .. Node.Children_Count loop
         if References_Declaration (Node.Child (I), Decl) then
            return True;
         end if;
      end loop;

      return False;
   end References_Declaration;

   --  True when Node contains a read of Decl, as opposed to only a write.
   --  A plain assignment's simple identifier destination doesn't count as
   --  a read; everything else that mentions Decl does. Drives
   --  Overwritten_Assignment's "was the earlier value read first" check.
   function Reads_Declaration
     (Node : Libadalang.Analysis.Ada_Node'Class;
      Decl : Libadalang.Analysis.Basic_Decl) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      elsif Node.Kind = Libadalang.Common.Ada_Assign_Stmt then
         --  A simple assignment destination is a write, while expressions in
         --  the value (and in a complex destination) remain reads.
         declare
            Stmt : constant Libadalang.Analysis.Assign_Stmt :=
              Node.As_Assign_Stmt;
         begin
            return References_Declaration (Stmt.F_Expr, Decl)
              or else (Stmt.F_Dest.Kind /= Libadalang.Common.Ada_Identifier
                       and then References_Declaration (Stmt.F_Dest, Decl));
         end;
      end if;

      if Node.Kind = Libadalang.Common.Ada_Identifier
        and then Referenced_Declaration (Node) = Decl
      then
         return True;
      end if;

      for I in 1 .. Node.Children_Count loop
         if Reads_Declaration (Node.Child (I), Decl) then
            return True;
         end if;
      end loop;

      return False;
   end Reads_Declaration;

   --  The declaration written by an assignment statement whose destination
   --  is a plain identifier, or No_Basic_Decl for anything else (Node
   --  isn't an assignment, or its destination is a more complex form like
   --  an array/record component).
   function Assigned_Declaration
     (Node : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Basic_Decl is
   begin
      if Libadalang.Analysis.Is_Null (Node)
        or else Node.Kind /= Libadalang.Common.Ada_Assign_Stmt
        or else Node.As_Assign_Stmt.F_Dest.Kind /=
          Libadalang.Common.Ada_Identifier
      then
         return Libadalang.Analysis.No_Basic_Decl;
      end if;

      return Referenced_Declaration (Node.As_Assign_Stmt.F_Dest);
   end Assigned_Declaration;

   --  True when some read of Decl occurs at or after Assignment's source
   --  position within Node's subtree, in source (textual) order. This is
   --  the Dead_Store check: an assignment whose value is never read again
   --  in the subprogram is very likely dead code.
   function Has_Read_After
     (Node       : Libadalang.Analysis.Ada_Node'Class;
      Decl       : Libadalang.Analysis.Basic_Decl;
      Assignment : Libadalang.Analysis.Assign_Stmt) return Boolean
   is
      --  Whether Candidate starts at or after the end of Assignment, used
      --  to ignore reads that are the assignment's own destination/value.
      function Starts_After_Assignment
        (Candidate : Libadalang.Analysis.Ada_Node'Class) return Boolean is
      begin
         return Natural (Candidate.Sloc_Range.Start_Line) >
             Natural (Assignment.Sloc_Range.End_Line)
           or else
             (Natural (Candidate.Sloc_Range.Start_Line) =
                Natural (Assignment.Sloc_Range.End_Line)
              and then Natural (Candidate.Sloc_Range.Start_Column) >=
                Natural (Assignment.Sloc_Range.End_Column));
      end Starts_After_Assignment;
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      elsif Node.Kind = Libadalang.Common.Ada_Assign_Stmt then
         declare
            Stmt : constant Libadalang.Analysis.Assign_Stmt :=
              Node.As_Assign_Stmt;
         begin
            if Has_Read_After (Stmt.F_Expr, Decl, Assignment) then
               return True;
            elsif Stmt.F_Dest.Kind /= Libadalang.Common.Ada_Identifier then
               return Has_Read_After (Stmt.F_Dest, Decl, Assignment);
            else
               return False;
            end if;
         end;
      elsif Node.Kind = Libadalang.Common.Ada_Identifier
        and then Starts_After_Assignment (Node)
        and then Referenced_Declaration (Node) = Decl
      then
         return True;
      end if;

      for I in 1 .. Node.Children_Count loop
         if Has_Read_After (Node.Child (I), Decl, Assignment) then
            return True;
         end if;
      end loop;

      return False;
   end Has_Read_After;

   --  Walks up from Node to the nearest enclosing subprogram body, or
   --  No_Subp_Body if Node isn't inside one.
   function Enclosing_Subprogram
     (Node : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Subp_Body
   is
      Ancestor : Libadalang.Analysis.Ada_Node := Node.Parent;
   begin
      while not Libadalang.Analysis.Is_Null (Ancestor) loop
         if Ancestor.Kind = Libadalang.Common.Ada_Subp_Body then
            return Ancestor.As_Subp_Body;
         end if;
         Ancestor := Ancestor.Parent;
      end loop;

      return Libadalang.Analysis.No_Subp_Body;
   end Enclosing_Subprogram;

   --  True when Call's callee resolves to Subprogram itself, i.e. Call is a
   --  direct recursive call. Backs No_Recursion. Scoped to calls written
   --  with an explicit call syntax (Call_Expr); a parameterless procedure
   --  or function call written as a bare name is not recognized, keeping
   --  detection conservative rather than risking a false positive from
   --  misclassifying an ordinary name reference as a call.
   function Is_Direct_Recursive_Call
     (Call       : Libadalang.Analysis.Call_Expr;
      Subprogram : Libadalang.Analysis.Subp_Body) return Boolean
   is
      Referenced : constant Libadalang.Analysis.Basic_Decl :=
        Call.F_Name.P_Referenced_Decl;
   begin
      if Libadalang.Analysis.Is_Null (Referenced) then
         return False;
      end if;

      return Referenced.P_Canonical_Part =
        Libadalang.Analysis.Basic_Decl (Subprogram).P_Canonical_Part;
   exception
      when others =>
         return False;
   end Is_Direct_Recursive_Call;

   --  True when some identifier under Node both spells Identifier and
   --  resolves to Decl. The text comparison is checked first (cheap) so
   --  that the semantic resolution call only runs on plausible matches.
   --  Shared by Unused_Parameter (Decl is the parameter's Param_Spec) and
   --  Unused_Variable (Decl is the local object's Object_Decl); matching by
   --  spelling first lets it correctly tell apart names declared together
   --  in one multi-name declaration, which all share the same Basic_Decl.
   function References_Named_Declaration
     (Node       : Libadalang.Analysis.Ada_Node'Class;
      Decl       : Libadalang.Analysis.Basic_Decl;
      Identifier : String) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      elsif Node.Kind = Libadalang.Common.Ada_Identifier
        and then Canonical_Text (Node) = Identifier
      then
         declare
            Referenced : constant Libadalang.Analysis.Basic_Decl :=
              Referenced_Declaration (Node);
         begin
            --  Prefer semantic identity.  When Libadalang cannot resolve a
            --  name in an otherwise valid unit, conservatively treat the
            --  matching spelling as a use instead of emitting a false
            --  "unused" diagnostic.
            return Libadalang.Analysis.Is_Null (Referenced)
              or else Referenced = Decl;
         end;
      end if;

      for I in 1 .. Node.Children_Count loop
         if References_Named_Declaration (Node.Child (I), Decl, Identifier) then
            return True;
         end if;
      end loop;

      return False;
   end References_Named_Declaration;

   --  True when Node is an object or parameter declaration that introduces
   --  Name (compared via its canonical, case-folded spelling).
   function Declares_Name
     (Node : Libadalang.Analysis.Ada_Node'Class;
      Name : String) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      elsif Node.Kind = Libadalang.Common.Ada_Object_Decl then
         for Id of Node.As_Object_Decl.F_Ids loop
            if Canonical_Text (Id) = Name then
               return True;
            end if;
         end loop;
      elsif Node.Kind = Libadalang.Common.Ada_Param_Spec then
         for Id of Node.As_Param_Spec.F_Ids loop
            if Canonical_Text (Id) = Name then
               return True;
            end if;
         end loop;
      end if;

      return False;
   end Declares_Name;

   --  True when Decl's Name is already declared by an object or parameter
   --  in some scope that textually encloses Decl's own scope, i.e. Decl
   --  hides an outer declaration of the same name. The search walks the
   --  whole compilation unit from its root because Libadalang doesn't
   --  expose an "enclosing scopes" iterator directly usable here; the
   --  Is_Ancestor_Of check filters candidates down to genuine ancestors.
   function Shadows_Enclosing_Declaration
     (Decl : Libadalang.Analysis.Object_Decl; Name : String) return Boolean
   is
      --  The nearest subprogram body, declare block, or package body
      --  enclosing Node, i.e. its lexical scope for shadowing purposes.
      function Scope_Of
        (Node : Libadalang.Analysis.Ada_Node'Class)
         return Libadalang.Analysis.Ada_Node
      is
         Ancestor : Libadalang.Analysis.Ada_Node := Node.Parent;
      begin
         while not Libadalang.Analysis.Is_Null (Ancestor) loop
            if Ancestor.Kind in Libadalang.Common.Ada_Subp_Body
              | Libadalang.Common.Ada_Decl_Block
              | Libadalang.Common.Ada_Package_Body
            then
               return Ancestor;
            end if;
            Ancestor := Ancestor.Parent;
         end loop;
         return Libadalang.Analysis.No_Ada_Node;
      end Scope_Of;

      --  True when Possible_Ancestor is a syntactic ancestor of Node.
      function Is_Ancestor_Of
        (Possible_Ancestor : Libadalang.Analysis.Ada_Node;
         Node              : Libadalang.Analysis.Ada_Node'Class)
         return Boolean
      is
         Ancestor : Libadalang.Analysis.Ada_Node := Node.Parent;
      begin
         while not Libadalang.Analysis.Is_Null (Ancestor) loop
            if Ancestor = Possible_Ancestor then
               return True;
            end if;
            Ancestor := Ancestor.Parent;
         end loop;
         return False;
      end Is_Ancestor_Of;

      Current_Node  : constant Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.Ada_Node (Decl);
      Current_Scope : constant Libadalang.Analysis.Ada_Node := Scope_Of (Decl);
      Root          : Libadalang.Analysis.Ada_Node := Current_Node;

      --  Searches the subtree rooted at Node for a declaration of Name
      --  whose scope both differs from Decl's own scope and encloses it.
      function Has_Outer_Declaration
        (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
      is
         Candidate_Scope : Libadalang.Analysis.Ada_Node;
      begin
         if Libadalang.Analysis.Is_Null (Node) then
            return False;
         end if;

         if Libadalang.Analysis.Ada_Node (Node) /= Current_Node
           and then Node.Kind in Libadalang.Common.Ada_Object_Decl
             | Libadalang.Common.Ada_Param_Spec
           and then Declares_Name (Node, Name)
         then
            Candidate_Scope := Scope_Of (Node);
            if not Libadalang.Analysis.Is_Null (Candidate_Scope)
              and then Candidate_Scope /= Current_Scope
              and then Is_Ancestor_Of (Candidate_Scope, Decl)
            then
               return True;
            end if;
         end if;

         for I in 1 .. Node.Children_Count loop
            if Has_Outer_Declaration (Node.Child (I)) then
               return True;
            end if;
         end loop;
         return False;
      end Has_Outer_Declaration;
   begin
      while not Libadalang.Analysis.Is_Null (Root.Parent) loop
         Root := Root.Parent;
      end loop;
      return Has_Outer_Declaration (Root);
   end Shadows_Enclosing_Declaration;

   --  Sums the decision points in Node's subtree (if/elsif, loops,
   --  exception handlers each add 1, an N-way case adds N-1, and each
   --  short-circuit "and then"/"or else" adds 1), the standard count of
   --  independent paths added to a base complexity of 1 per subprogram.
   --  A nested subprogram body stops the walk and contributes 0, since it
   --  is scored separately when Analyze_Subprogram visits it in turn.
   function Cyclomatic_Value
     (Node : Libadalang.Analysis.Ada_Node'Class) return Natural
   is
      Result : Natural := 0;
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return 0;
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_If_Stmt
            | Libadalang.Common.Ada_Elsif_Stmt_Part
            | Libadalang.Common.Ada_For_Loop_Stmt
            | Libadalang.Common.Ada_Loop_Stmt
            | Libadalang.Common.Ada_While_Loop_Stmt
            | Libadalang.Common.Ada_Exception_Handler =>
            Result := 1;

         when Libadalang.Common.Ada_Case_Stmt =>
            declare
               Count : constant Natural :=
                 Node.As_Case_Stmt.F_Alternatives.Children_Count;
            begin
               if Count > 0 then
                  Result := Count - 1;
               end if;
            end;

         when Libadalang.Common.Ada_Bin_Op =>
            if Node.As_Bin_Op.F_Op in
              Libadalang.Common.Ada_Op_And_Then
                | Libadalang.Common.Ada_Op_Or_Else
            then
               Result := 1;
            end if;

         when Libadalang.Common.Ada_Subp_Body =>
            --  A nested subprogram has its own independent complexity score.
            return 0;

         when others =>
            null;  --  adalang-analyzer: ignore Null_Statement
      end case;

      for I in 1 .. Node.Children_Count loop
         Result := Result + Cyclomatic_Value (Node.Child (I));
      end loop;

      return Result;
   end Cyclomatic_Value;

   --  Deepest control-flow nesting level reached under Node, starting from
   --  Depth. If, case, loop, extended-return, and declare-block statements
   --  each add one level; elsif/else parts share their enclosing if
   --  statement's level rather than adding their own. A nested subprogram
   --  body stops the walk (it is scored separately in its own
   --  Analyze_Subprogram call), matching Cyclomatic_Value's scoping.
   function Max_Nesting_Depth
     (Node : Libadalang.Analysis.Ada_Node'Class; Depth : Natural) return Natural
   is
      Result      : Natural := Depth;
      Child_Depth : Natural := Depth;
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return Depth;
      end if;

      if Node.Kind = Libadalang.Common.Ada_Subp_Body then
         return Depth;
      end if;

      if Node.Kind in Libadalang.Common.Ada_If_Stmt
           | Libadalang.Common.Ada_Case_Stmt
           | Libadalang.Common.Ada_For_Loop_Stmt
           | Libadalang.Common.Ada_While_Loop_Stmt
           | Libadalang.Common.Ada_Loop_Stmt
           | Libadalang.Common.Ada_Extended_Return_Stmt
           | Libadalang.Common.Ada_Decl_Block
      then
         Child_Depth := Depth + 1;
      end if;

      for I in 1 .. Node.Children_Count loop
         declare
            Sub_Depth : constant Natural :=
              Max_Nesting_Depth (Node.Child (I), Child_Depth);
         begin
            if Sub_Depth > Result then
               Result := Sub_Depth;
            end if;
         end;
      end loop;

      return Result;
   end Max_Nesting_Depth;

   --  Number of return statements under Node, not descending into a nested
   --  subprogram body (its own returns belong to that subprogram, not the
   --  one being counted here). Backs No_Multiple_Return.
   function Count_Return_Statements
     (Node : Libadalang.Analysis.Ada_Node'Class) return Natural
   is
      Result : Natural := 0;
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return 0;
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_Return_Stmt
            | Libadalang.Common.Ada_Extended_Return_Stmt =>
            Result := 1;

         when Libadalang.Common.Ada_Subp_Body =>
            return 0;

         when others =>
            null;  --  adalang-analyzer: ignore Null_Statement
      end case;

      for I in 1 .. Node.Children_Count loop
         Result := Result + Count_Return_Statements (Node.Child (I));
      end loop;

      return Result;
   end Count_Return_Statements;

   --  The defining name an identifier resolves to, or No_Ada_Node for
   --  anything else. The Flow_State key type (see above); kept distinct
   --  from Referenced_Declaration, which resolves to the shared Basic_Decl
   --  and so cannot tell apart two names introduced by one multi-name
   --  declaration.
   function Flow_Referenced_Name
     (Node : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Ada_Node
   is
   begin
      if Libadalang.Analysis.Is_Null (Node)
        or else Node.Kind /= Libadalang.Common.Ada_Identifier
      then
         return Libadalang.Analysis.No_Ada_Node;
      end if;

      return Libadalang.Analysis.Ada_Node
        (Node.As_Name.P_Referenced_Defining_Name);
   exception
      when others =>
         return Libadalang.Analysis.No_Ada_Node;
   end Flow_Referenced_Name;

   --  The defining name written by an assignment whose destination is a
   --  plain identifier, or No_Ada_Node for anything else (a more complex
   --  destination such as an array or record component).
   function Flow_Assigned_Name
     (Node : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Ada_Node
   is
   begin
      if Libadalang.Analysis.Is_Null (Node)
        or else Node.Kind /= Libadalang.Common.Ada_Assign_Stmt
        or else Node.As_Assign_Stmt.F_Dest.Kind /=
          Libadalang.Common.Ada_Identifier
      then
         return Libadalang.Analysis.No_Ada_Node;
      end if;

      return Flow_Referenced_Name (Node.As_Assign_Stmt.F_Dest);
   end Flow_Assigned_Name;

   --  Havocs every identifier anywhere under Node. Used to invalidate a
   --  call's actual parameters wholesale (mode information isn't consulted,
   --  so this is deliberately over-conservative rather than risk treating
   --  an out-mode actual as unchanged).
   procedure Havoc_Identifiers_In
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      State : in out Flow_State)
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return;
      end if;

      if Node.Kind = Libadalang.Common.Ada_Identifier then
         Flow_Havoc (State, Flow_Referenced_Name (Node));
      end if;

      for I in 1 .. Node.Children_Count loop
         Havoc_Identifiers_In (Node.Child (I), State);
      end loop;
   end Havoc_Identifiers_In;

   --  Invalidates whatever Node's own evaluation could change: every actual
   --  parameter of any call found within it (Ada_Call_Expr also covers
   --  indexing and conversions, which are harmless to over-invalidate), and
   --  every variable directly assigned to, when Node is itself a statement
   --  list containing assignments (the pre-loop-body havoc case). Does not
   --  descend into a nested subprogram body, which is analyzed separately
   --  on its own terms.
   procedure Havoc_Effects_In
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      State : in out Flow_State)
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return;
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_Assign_Stmt =>
            Flow_Havoc (State, Flow_Assigned_Name (Node));

         when Libadalang.Common.Ada_Call_Expr =>
            Havoc_Identifiers_In (Node, State);
            return;

         when Libadalang.Common.Ada_Subp_Body =>
            return;

         when others =>
            null;  --  adalang-analyzer: ignore Null_Statement
      end case;

      for I in 1 .. Node.Children_Count loop
         Havoc_Effects_In (Node.Child (I), State);
      end loop;
   end Havoc_Effects_In;

   --  Reports Division_By_Zero for every "/", "mod", or "rem" under Node
   --  whose right operand is only known to be zero once State's earlier
   --  assignments are taken into account (a plain literal zero is already
   --  caught by Analyze_Binary_Expression, so this only adds cases that
   --  check would miss).
   procedure Scan_Expression_For_Flow_Bugs
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Node  : Libadalang.Analysis.Ada_Node'Class;
      State : Flow_State)
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return;
      end if;

      if Rule_States (Division_By_Zero) = Enabled
        and then Node.Kind in Libadalang.Common.Ada_Bin_Op_Range
      then
         declare
            Expr  : constant Libadalang.Analysis.Bin_Op := Node.As_Bin_Op;
            Right : constant Abstract_Int :=
              Integer_Value (Expr.F_Right, State);
         begin
            if Expr.F_Op in Libadalang.Common.Ada_Op_Div
                | Libadalang.Common.Ada_Op_Mod
                | Libadalang.Common.Ada_Op_Rem
              and then not Is_Static_Zero (Expr.F_Right)
              and then Right.Known
              and then Right.Value = 0
            then
               Report_Rule_Violation
                 (Unit, Expr.F_Right, Division_By_Zero,
                  "right operand is zero here based on an earlier " &
                    "assignment");
            end if;
         end;
      end if;

      for I in 1 .. Node.Children_Count loop
         Scan_Expression_For_Flow_Bugs (Unit, Node.Child (I), State);
      end loop;
   end Scan_Expression_For_Flow_Bugs;

   --  Reports Constant_Condition for Cond when State's earlier assignments
   --  resolve it to a known value that plain literal evaluation (no state)
   --  could not -- the literal-only case is already handled at the call
   --  site that also reports Non_Short_Circuit_Condition.
   procedure Check_Flow_Condition
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Cond  : Libadalang.Analysis.Ada_Node'Class;
      State : Flow_State)
   is
   begin
      if Rule_States (Constant_Condition) /= Enabled
        or else Libadalang.Analysis.Is_Null (Cond)
        or else Boolean_Value (Cond) /= Bool_Unknown
      then
         return;
      end if;

      declare
         Flow_Value : constant Abstract_Bool := Boolean_Value (Cond, State);
      begin
         if Flow_Value /= Bool_Unknown then
            Report_Rule_Violation
              (Unit, Cond, Constant_Condition,
               "condition is always " & Bool_Name (Flow_Value) &
                 " based on an earlier assignment");
         end if;
      end;
   end Check_Flow_Condition;

   --  Seeds State from every "Name : T := Default;" in Decls, when Default
   --  statically evaluates (possibly using State itself, so an earlier
   --  constant can feed a later one's initializer).
   procedure Seed_Declarations
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Decls : Libadalang.Analysis.Declarative_Part;
      State : in out Flow_State)
   is
   begin
      if Libadalang.Analysis.Is_Null (Decls) then
         return;
      end if;

      for I in 1 .. Decls.F_Decls.Children_Count loop
         declare
            Item : constant Libadalang.Analysis.Ada_Node :=
              Decls.F_Decls.Child (I);
         begin
            if not Libadalang.Analysis.Is_Null (Item)
              and then Item.Kind = Libadalang.Common.Ada_Object_Decl
            then
               declare
                  Decl    : constant Libadalang.Analysis.Object_Decl :=
                    Item.As_Object_Decl;
                  Default : constant Libadalang.Analysis.Expr :=
                    Decl.F_Default_Expr;
               begin
                  if not Libadalang.Analysis.Is_Null (Default) then
                     Scan_Expression_For_Flow_Bugs (Unit, Default, State);

                     declare
                        Value : constant Abstract_Int :=
                          Integer_Value (Default, State);
                     begin
                        if Value.Known then
                           for Id of Decl.F_Ids loop
                              Flow_Set
                                (State,
                                 Libadalang.Analysis.Ada_Node (Id), Value);
                           end loop;
                        end if;
                     end;
                  end if;
               end;
            end if;
         end;
      end loop;
   end Seed_Declarations;

   --  The outcome of interpreting a statement or statement list: the
   --  resulting Flow_State, and whether control can fall through to
   --  whatever follows (False once a return, raise, or unconditional exit
   --  has been seen).
   type Flow_Result is record
      State      : Flow_State;
      Terminated : Boolean;
   end record;

   --  Combines two branches reaching the same merge point. A branch that
   --  terminates contributes nothing to the merged state; if both do, the
   --  merge point itself is unreachable, which is reported by other checks,
   --  not this one -- Empty_Flow_State here is just an inert placeholder.
   function Join_Results (Left, Right : Flow_Result) return Flow_Result is
   begin
      if Left.Terminated and then Right.Terminated then
         return (State => Empty_Flow_State, Terminated => True);
      elsif Left.Terminated then
         return (State => Right.State, Terminated => False);
      elsif Right.Terminated then
         return (State => Left.State, Terminated => False);
      else
         return
           (State => Flow_Join (Left.State, Right.State),
            Terminated => False);
      end if;
   end Join_Results;

   --  Forward declaration: Interpret_Else_Chain, Interpret_If, and
   --  Interpret_Loop all call back into Interpret_Statements, which is
   --  defined after Interpret_Statement further below.
   function Interpret_Statements
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      List  : Libadalang.Analysis.Ada_Node'Class;
      State : Flow_State) return Flow_Result;

   --  Interprets Stmt.F_Alternatives (I .. end) and Stmt.F_Else_Part as one
   --  chain of conditions, since each elsif is semantically nested inside
   --  the previous condition's negation.
   function Interpret_Else_Chain
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Stmt  : Libadalang.Analysis.If_Stmt;
      Index : Positive;
      State : Flow_State) return Flow_Result
   is
      Alternatives : constant Libadalang.Analysis.Elsif_Stmt_Part_List :=
        Stmt.F_Alternatives;
   begin
      if Index > Alternatives.Children_Count then
         if Libadalang.Analysis.Is_Null (Stmt.F_Else_Part) then
            return (State => State, Terminated => False);
         else
            return
              Interpret_Statements (Unit, Stmt.F_Else_Part.F_Stmts, State);
         end if;
      end if;

      declare
         Alt  : constant Libadalang.Analysis.Elsif_Stmt_Part :=
           Alternatives.Child (Index).As_Elsif_Stmt_Part;
         Cond : constant Libadalang.Analysis.Expr := Alt.F_Cond_Expr;
      begin
         Scan_Expression_For_Flow_Bugs (Unit, Cond, State);
         Check_Flow_Condition (Unit, Cond, State);

         declare
            Cond_Value : constant Abstract_Bool := Boolean_Value (Cond, State);
         begin
            if Cond_Value = Bool_True then
               return Interpret_Statements (Unit, Alt.F_Stmts, State);
            elsif Cond_Value = Bool_False then
               return Interpret_Else_Chain (Unit, Stmt, Index + 1, State);
            else
               return Join_Results
                 (Interpret_Statements (Unit, Alt.F_Stmts, State),
                  Interpret_Else_Chain (Unit, Stmt, Index + 1, State));
            end if;
         end;
      end;
   end Interpret_Else_Chain;

   --  Interprets an if statement: picks the live branch when the condition
   --  resolves (via State) to a known value, otherwise interprets both
   --  branches from copies of the entering State and joins the results.
   function Interpret_If
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Stmt  : Libadalang.Analysis.If_Stmt;
      State : Flow_State) return Flow_Result
   is
      Cond : constant Libadalang.Analysis.Expr := Stmt.F_Cond_Expr;
   begin
      Scan_Expression_For_Flow_Bugs (Unit, Cond, State);
      Check_Flow_Condition (Unit, Cond, State);

      declare
         Cond_Value : constant Abstract_Bool := Boolean_Value (Cond, State);
      begin
         if Cond_Value = Bool_True then
            return Interpret_Statements (Unit, Stmt.F_Then_Stmts, State);
         elsif Cond_Value = Bool_False then
            return Interpret_Else_Chain (Unit, Stmt, 1, State);
         end if;
      end;

      return Join_Results
        (Interpret_Statements (Unit, Stmt.F_Then_Stmts, State),
         Interpret_Else_Chain (Unit, Stmt, 1, State));
   end Interpret_If;

   --  Interprets a loop: every variable assigned anywhere in the body (and
   --  every actual parameter of any call within it) is havoced before the
   --  body is interpreted once, since a later iteration could reach any
   --  point in the body with that variable already reassigned -- without
   --  this, a variable's pre-loop value would wrongly look like it still
   --  held after a reassignment later in the same loop body. The state
   --  after the loop is the join of "never entered" and "ran the body",
   --  since a while/for loop may execute zero times.
   function Interpret_Loop
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Stmt  : Libadalang.Analysis.Ada_Node'Class;
      State : Flow_State) return Flow_Result
   is
      Body_Stmts : constant Libadalang.Analysis.Stmt_List :=
        Stmt.As_Base_Loop_Stmt.F_Stmts;
      Havoced    : Flow_State := State;
   begin
      if Stmt.Kind = Libadalang.Common.Ada_While_Loop_Stmt then
         declare
            Spec : constant Libadalang.Analysis.Loop_Spec :=
              Stmt.As_While_Loop_Stmt.F_Spec;
         begin
            if not Libadalang.Analysis.Is_Null (Spec) then
               declare
                  Cond : constant Libadalang.Analysis.Expr :=
                    Spec.As_While_Loop_Spec.F_Expr;
               begin
                  Scan_Expression_For_Flow_Bugs (Unit, Cond, State);
                  Check_Flow_Condition (Unit, Cond, State);
               end;
            end if;
         end;
      end if;

      Havoc_Effects_In (Body_Stmts, Havoced);

      declare
         Body_Result : constant Flow_Result :=
           Interpret_Statements (Unit, Body_Stmts, Havoced);
      begin
         return
           (State => Flow_Join (State, Body_Result.State),
            Terminated => False);
      end;
   end Interpret_Loop;

   --  Interprets a case statement: every alternative is interpreted from a
   --  copy of the entering State (no attempt is made to statically pick a
   --  single alternative even when the selector is known -- that would
   --  need the same choice-range matching Choice_Interval already does for
   --  Overlapping_Case_Ranges, which this pass doesn't reuse), and the
   --  results are joined the same way an if statement's branches are.
   function Interpret_Case
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Stmt  : Libadalang.Analysis.Case_Stmt;
      State : Flow_State) return Flow_Result
   is
      Alternatives : constant Libadalang.Analysis.Case_Stmt_Alternative_List :=
        Stmt.F_Alternatives;
      Result       : Flow_Result := (State => State, Terminated => False);
      First        : Boolean := True;
   begin
      Scan_Expression_For_Flow_Bugs (Unit, Stmt.F_Expr, State);

      for I in 1 .. Alternatives.Children_Count loop
         declare
            Alt    : constant Libadalang.Analysis.Case_Stmt_Alternative :=
              Alternatives.Child (I).As_Case_Stmt_Alternative;
            Branch : constant Flow_Result :=
              Interpret_Statements (Unit, Alt.F_Stmts, State);
         begin
            if First then
               Result := Branch;
               First := False;
            else
               Result := Join_Results (Result, Branch);
            end if;
         end;
      end loop;

      return Result;
   end Interpret_Case;

   --  Interprets a declare block: seeds its own local declarations'
   --  initializers into a copy of the entering State, then interprets its
   --  statements the same way a subprogram body's are (see
   --  Interpret_Subprogram_Flow). Skipped, the same conservative way, when
   --  the block has its own exception handlers.
   function Interpret_Decl_Block
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Block : Libadalang.Analysis.Decl_Block;
      State : Flow_State) return Flow_Result
   is
      Handled : constant Libadalang.Analysis.Handled_Stmts := Block.F_Stmts;
   begin
      if Libadalang.Analysis.Is_Null (Handled)
        or else Handled.F_Exceptions.Children_Count > 0
      then
         return (State => Empty_Flow_State, Terminated => False);
      end if;

      declare
         Seeded : Flow_State := State;
      begin
         Seed_Declarations (Unit, Block.F_Decls, Seeded);
         return Interpret_Statements (Unit, Handled.F_Stmts, Seeded);
      end;
   end Interpret_Decl_Block;

   --  Interprets one statement, threading State to the next. Anything not
   --  explicitly modeled here (select, accept, goto/label targets, ...)
   --  clears all tracked bindings rather than risk carrying a stale one
   --  across a construct this pass doesn't understand; Terminates_Statement
   --  still recognizes return/raise/goto/unconditional-exit so reachability
   --  past them is handled uniformly.
   function Interpret_Statement
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Stmt  : Libadalang.Analysis.Ada_Node'Class;
      State : Flow_State) return Flow_Result
   is
   begin
      case Stmt.Kind is
         when Libadalang.Common.Ada_Assign_Stmt =>
            declare
               Assign : constant Libadalang.Analysis.Assign_Stmt :=
                 Stmt.As_Assign_Stmt;
               Next   : Flow_State := State;
            begin
               Scan_Expression_For_Flow_Bugs (Unit, Assign.F_Expr, State);
               Havoc_Effects_In (Assign.F_Dest, Next);
               Havoc_Effects_In (Assign.F_Expr, Next);

               declare
                  Target : constant Libadalang.Analysis.Ada_Node :=
                    Flow_Assigned_Name (Stmt);
                  Value  : constant Abstract_Int :=
                    Integer_Value (Assign.F_Expr, State);
               begin
                  Flow_Set (Next, Target, Value);
               end;

               return (State => Next, Terminated => False);
            end;

         when Libadalang.Common.Ada_Call_Stmt =>
            declare
               Next : Flow_State := State;
            begin
               Havoc_Effects_In (Stmt.As_Call_Stmt.F_Call, Next);
               return (State => Next, Terminated => False);
            end;

         when Libadalang.Common.Ada_If_Stmt =>
            return Interpret_If (Unit, Stmt.As_If_Stmt, State);

         when Libadalang.Common.Ada_Case_Stmt =>
            return Interpret_Case (Unit, Stmt.As_Case_Stmt, State);

         when Libadalang.Common.Ada_Decl_Block =>
            return Interpret_Decl_Block (Unit, Stmt.As_Decl_Block, State);

         when Libadalang.Common.Ada_While_Loop_Stmt
            | Libadalang.Common.Ada_For_Loop_Stmt
            | Libadalang.Common.Ada_Loop_Stmt =>
            return Interpret_Loop (Unit, Stmt, State);

         when Libadalang.Common.Ada_Null_Stmt
            | Libadalang.Common.Ada_Label
            | Libadalang.Common.Ada_Pragma_Node =>
            return (State => State, Terminated => False);

         when Libadalang.Common.Ada_Exit_Stmt =>
            declare
               Cond : constant Libadalang.Analysis.Expr :=
                 Stmt.As_Exit_Stmt.F_Cond_Expr;
            begin
               if Libadalang.Analysis.Is_Null (Cond) then
                  return (State => State, Terminated => True);
               end if;

               Scan_Expression_For_Flow_Bugs (Unit, Cond, State);
               Check_Flow_Condition (Unit, Cond, State);
               return (State => State, Terminated => False);
            end;

         when others =>
            if Terminates_Statement (Stmt) then
               return (State => State, Terminated => True);
            else
               return (State => Empty_Flow_State, Terminated => False);
            end if;
      end case;
   end Interpret_Statement;

   function Interpret_Statements
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      List  : Libadalang.Analysis.Ada_Node'Class;
      State : Flow_State) return Flow_Result
   is
      Current : Flow_State := State;
   begin
      if Libadalang.Analysis.Is_Null (List) then
         return (State => Current, Terminated => False);
      end if;

      for I in 1 .. List.Children_Count loop
         declare
            Stmt : constant Libadalang.Analysis.Ada_Node := List.Child (I);
         begin
            if not Libadalang.Analysis.Is_Null (Stmt) then
               declare
                  Step : constant Flow_Result :=
                    Interpret_Statement (Unit, Stmt, Current);
               begin
                  Current := Step.State;
                  if Step.Terminated then
                     return (State => Current, Terminated => True);
                  end if;
               end;
            end if;
         end;
      end loop;

      return (State => Current, Terminated => False);
   end Interpret_Statements;

   --  Runs the flow-sensitive pass over one subprogram body: seeds State
   --  from its declarations' initializers, then walks its statements,
   --  strengthening Division_By_Zero and Constant_Condition with values
   --  learned from assignments the plain literal-only evaluation in
   --  Analyze_Binary_Expression / Analyze_Bug_Finding_Node can't see.
   --  Skipped for a body with exception handlers: an exception raised
   --  partway through would jump to the handler with only a prefix of the
   --  assignments applied, which this straight-line model doesn't account
   --  for.
   procedure Interpret_Subprogram_Flow
     (Unit       : Libadalang.Analysis.Analysis_Unit;
      Subprogram : Libadalang.Analysis.Subp_Body)
   is
      Handled : constant Libadalang.Analysis.Handled_Stmts :=
        Subprogram.F_Stmts;
   begin
      if Libadalang.Analysis.Is_Null (Handled)
        or else Handled.F_Exceptions.Children_Count > 0
      then
         return;
      end if;

      declare
         State  : Flow_State := Empty_Flow_State;
         Ignore : Flow_Result;  --  adalang-analyzer: ignore Dead_Store
      begin
         Seed_Declarations (Unit, Subprogram.F_Decls, State);
         Ignore := Interpret_Statements (Unit, Handled.F_Stmts, State);
      end;
   end Interpret_Subprogram_Flow;

   --  Runs the per-subprogram checks: Unused_Parameter and Unused_Variable
   --  (no reference in either the local declarations or the statements),
   --  Cyclomatic_Complexity (base 1 plus every decision point in the
   --  body), Too_Many_Parameters, Deep_Nesting, and No_Multiple_Return.
   procedure Analyze_Subprogram  --  adalang-analyzer: ignore Cyclomatic_Complexity
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Subprogram : Libadalang.Analysis.Subp_Body)
   is
      Param_Count : Natural := 0;
   begin
      if Rule_States (Unused_Parameter) = Enabled
        or else Rule_States (Too_Many_Parameters) = Enabled
      then
         for Param of Subprogram.F_Subp_Spec.P_Params loop
            for Id of Param.F_Ids loop
               Param_Count := Param_Count + 1;

               if Rule_States (Unused_Parameter) = Enabled then
                  declare
                     Name : constant String := Canonical_Text (Id);
                  begin
                     if not References_Named_Declaration
                       (Subprogram.F_Decls,
                        Libadalang.Analysis.Basic_Decl (Param), Name)
                       and then not References_Named_Declaration
                         (Subprogram.F_Stmts,
                          Libadalang.Analysis.Basic_Decl (Param), Name)
                     then
                        Report_Rule_Violation
                          (Unit, Id, Unused_Parameter,
                           "parameter '" & Node_Text (Id) &
                             "' is never referenced");
                     end if;
                  end;
               end if;
            end loop;
         end loop;
      end if;

      if Rule_States (Too_Many_Parameters) = Enabled
        and then Param_Count > Parameter_Threshold
      then
         Report_Rule_Violation
           (Unit, Subprogram.F_Subp_Spec.P_Name, Too_Many_Parameters,
            "parameter count " & To_Decimal (Param_Count) &
              " exceeds threshold " & To_Decimal (Parameter_Threshold));
      end if;

      if Rule_States (Unused_Variable) = Enabled then
         for I in 1 .. Subprogram.F_Decls.F_Decls.Children_Count loop
            declare
               Item : constant Libadalang.Analysis.Ada_Node :=
                 Subprogram.F_Decls.F_Decls.Child (I);
            begin
               if not Libadalang.Analysis.Is_Null (Item)
                 and then Item.Kind = Libadalang.Common.Ada_Object_Decl
               then
                  declare
                     Decl : constant Libadalang.Analysis.Object_Decl :=
                       Item.As_Object_Decl;
                  begin
                     for Id of Decl.F_Ids loop
                        declare
                           Name : constant String := Canonical_Text (Id);
                           Basic : constant Libadalang.Analysis.Basic_Decl :=
                             Libadalang.Analysis.Basic_Decl (Decl);
                           Used_Elsewhere : Boolean := False;
                        begin
                           --  Scan sibling declarations only, skipping this
                           --  declaration's own node: it always contains
                           --  Id's defining occurrence, which would
                           --  otherwise be misread as a use of itself.
                           for J in 1 .. Subprogram.F_Decls.F_Decls.Children_Count loop
                              if J /= I
                                and then References_Named_Declaration
                                  (Subprogram.F_Decls.F_Decls.Child (J),
                                   Basic, Name)
                              then
                                 Used_Elsewhere := True;
                                 exit;  --  adalang-analyzer: ignore No_Exit
                              end if;
                           end loop;

                           if not Used_Elsewhere
                             and then not References_Named_Declaration
                               (Subprogram.F_Stmts, Basic, Name)
                           then
                              Report_Rule_Violation
                                (Unit, Id, Unused_Variable,
                                 "variable '" & Node_Text (Id) &
                                   "' is never referenced");
                           end if;
                        end;
                     end loop;
                  end;
               end if;
            end;
         end loop;
      end if;

      if Rule_States (Cyclomatic_Complexity) = Enabled then
         declare
            Complexity : constant Natural :=
              1 + Cyclomatic_Value (Subprogram.F_Stmts);
         begin
            if Complexity > Complexity_Threshold then
               Report_Rule_Violation
                 (Unit, Subprogram.F_Subp_Spec.P_Name,
                  Cyclomatic_Complexity,
                  "cyclomatic complexity " & To_Decimal (Complexity)
                  & " exceeds threshold " &
                    To_Decimal (Complexity_Threshold));
            end if;
         end;
      end if;

      if Rule_States (Deep_Nesting) = Enabled then
         declare
            Depth : constant Natural :=
              Max_Nesting_Depth (Subprogram.F_Stmts, 0);
         begin
            if Depth > Nesting_Threshold then
               Report_Rule_Violation
                 (Unit, Subprogram.F_Subp_Spec.P_Name, Deep_Nesting,
                  "nesting depth " & To_Decimal (Depth) &
                    " exceeds threshold " & To_Decimal (Nesting_Threshold));
            end if;
         end;
      end if;

      if Rule_States (No_Multiple_Return) = Enabled then
         declare
            Count : constant Natural :=
              Count_Return_Statements (Subprogram.F_Stmts);
         begin
            if Count > 1 then
               Report_Rule_Violation
                 (Unit, Subprogram.F_Subp_Spec.P_Name, No_Multiple_Return,
                  "subprogram has " & To_Decimal (Count) &
                    " return statements");
            end if;
         end;
      end if;

      if Rule_States (Division_By_Zero) = Enabled
        or else Rule_States (Constant_Condition) = Enabled
      then
         Interpret_Subprogram_Flow (Unit, Subprogram);
      end if;
   end Analyze_Subprogram;

   --  Runs Shadowed_Declaration for each name introduced by Decl.
   procedure Analyze_Object_Declaration
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Decl : Libadalang.Analysis.Object_Decl) is
   begin
      if Rule_States (Shadowed_Declaration) = Enabled then
         for Id of Decl.F_Ids loop
            if Shadows_Enclosing_Declaration
              (Decl, Canonical_Text (Id))
            then
               Report_Rule_Violation
                 (Unit, Id, Shadowed_Declaration,
                  "declaration shadows an object in an enclosing subprogram");
            end if;
         end loop;
      end if;
   end Analyze_Object_Declaration;

   --  Walks one statement list in source order for three intraprocedural,
   --  single-pass checks: Unreachable_Code (anything after an
   --  unconditional transfer of control, until a label resets
   --  reachability), Repeated_Statement (an assignment textually
   --  identical to the one immediately before it), and
   --  Overwritten_Assignment (an assignment to the same object recurring
   --  later in this same list before any intervening read). Deliberately
   --  scoped to a single statement list rather than full control flow, so
   --  results stay predictable without whole-program analysis.
   procedure Analyze_Statement_List  --  adalang-analyzer: ignore Cyclomatic_Complexity
     (Unit : Libadalang.Analysis.Analysis_Unit;
      List : Libadalang.Analysis.Ada_Node'Class)
   is
      Previous_Terminates : Boolean := False;
      Previous_Assignment : Unbounded_String;
   begin
      if Rule_States (Unreachable_Code) /= Enabled
        and then Rule_States (Repeated_Statement) /= Enabled
        and then Rule_States (Overwritten_Assignment) /= Enabled
      then
         return;
      end if;

      for I in 1 .. List.Children_Count loop
         declare
            Stmt : constant Libadalang.Analysis.Ada_Node := List.Child (I);
         begin
            if not Libadalang.Analysis.Is_Null (Stmt) then
               if Previous_Terminates
                 and then Stmt.Kind = Libadalang.Common.Ada_Label
               then
                  --  A label is a possible entry point, so statements from
                  --  this point onward are reachable again.
                  Previous_Terminates := False;  --  adalang-analyzer: ignore Dead_Store
               elsif Previous_Terminates
                 and then Stmt.Kind in Libadalang.Common.Ada_Stmt
               then
                  Report_Rule_Violation
                    (Unit, Stmt, Unreachable_Code,
                     "statement is unreachable");
               end if;

               if Rule_States (Repeated_Statement) = Enabled
                 and then Stmt.Kind = Libadalang.Common.Ada_Assign_Stmt
               then
                  declare
                     Current : constant String := Canonical_Text (Stmt);
                  begin
                     if Current /= ""
                       and then Current = To_String (Previous_Assignment)
                     then
                        Report_Rule_Violation
                          (Unit, Stmt, Repeated_Statement,
                           "assignment duplicates the preceding assignment");
                     end if;
                     Previous_Assignment := To_Unbounded_String (Current);
                  end;
               else
                  Previous_Assignment := Null_Unbounded_String;
               end if;

               if Rule_States (Overwritten_Assignment) = Enabled
                 and then Stmt.Kind = Libadalang.Common.Ada_Assign_Stmt
               then
                  declare
                     Decl : constant Libadalang.Analysis.Basic_Decl :=
                       Assigned_Declaration (Stmt);
                  begin
                     if not Libadalang.Analysis.Is_Null (Decl) then
                        for J in I + 1 .. List.Children_Count loop
                           declare
                              Later : constant Libadalang.Analysis.Ada_Node :=
                                List.Child (J);
                           begin
                              if Reads_Declaration (Later, Decl) then
                                 exit;  --  adalang-analyzer: ignore No_Exit
                              elsif Assigned_Declaration (Later) = Decl then
                                 Report_Rule_Violation
                                   (Unit, Later, Overwritten_Assignment,
                                    "assignment overwrites an unread value");
                                 exit;  --  adalang-analyzer: ignore No_Exit
                              end if;
                           end;
                        end loop;
                     end if;
                  end;
               end if;

               if Terminates_Statement (Stmt) then
                  Previous_Terminates := True;  --  adalang-analyzer: ignore Dead_Store
               end if;
            end if;
         end;
      end loop;
   end Analyze_Statement_List;

   --  True when Possible_Not is "not X" and Other's canonical text is
   --  exactly X, i.e. the two operands are syntactic negations of each
   --  other. Backs Contradictory_Condition ("X and not X", "X or not X").
   function Is_Negation_Of
     (Possible_Not : Libadalang.Analysis.Ada_Node'Class;
      Other        : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
   begin
      return not Libadalang.Analysis.Is_Null (Possible_Not)
        and then Possible_Not.Kind = Libadalang.Common.Ada_Un_Op
        and then Possible_Not.As_Un_Op.F_Op = Libadalang.Common.Ada_Op_Not
        and then Canonical_Text (Possible_Not.As_Un_Op.F_Expr) /= ""
        and then Canonical_Text (Possible_Not.As_Un_Op.F_Expr) =
          Canonical_Text (Other);
   end Is_Negation_Of;

   --  True for operators where "X op X" is suspicious rather than a
   --  routine identity (e.g. "+" and "*" are excluded: "X + X" and
   --  "X * X" are ordinary, intentional expressions).
   function Interesting_Same_Operand_Op
     (Op : Libadalang.Common.Ada_Node_Kind_Type) return Boolean is
   begin
      case Op is
         when Libadalang.Common.Ada_Op_And
            | Libadalang.Common.Ada_Op_And_Then
            | Libadalang.Common.Ada_Op_Or
            | Libadalang.Common.Ada_Op_Or_Else
            | Libadalang.Common.Ada_Op_Xor
            | Libadalang.Common.Ada_Op_Eq
            | Libadalang.Common.Ada_Op_Neq
            | Libadalang.Common.Ada_Op_Lt
            | Libadalang.Common.Ada_Op_Lte
            | Libadalang.Common.Ada_Op_Gt
            | Libadalang.Common.Ada_Op_Gte
            | Libadalang.Common.Ada_Op_Minus
            | Libadalang.Common.Ada_Op_Div
            | Libadalang.Common.Ada_Op_Mod
            | Libadalang.Common.Ada_Op_Rem =>
            return True;
         when others =>
            return False;
      end case;
   end Interesting_Same_Operand_Op;

   --  Runs every check keyed on a binary operator: Division_By_Zero,
   --  Floating_Equality, Reversed_Range, Same_Operand,
   --  Contradictory_Condition, Duplicate_Boolean_Operand,
   --  Ineffective_Operation (an identity operand that doesn't change the
   --  result, e.g. "X + 0"), and Constant_Result_Operation (an absorbing
   --  operand that forces a fixed result, e.g. "X * 0" or "X and False").
   procedure Analyze_Binary_Expression  --  adalang-analyzer: ignore Cyclomatic_Complexity
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Expr : Libadalang.Analysis.Bin_Op)
   is
      Op         : constant Libadalang.Common.Ada_Node_Kind_Type :=
        Expr.F_Op;
      Left_Text  : constant String := Canonical_Text (Expr.F_Left);
      Right_Text : constant String := Canonical_Text (Expr.F_Right);
      Left_Int   : constant Abstract_Int := Integer_Value (Expr.F_Left);
      Right_Int  : constant Abstract_Int := Integer_Value (Expr.F_Right);
   begin
      if Rule_States (Division_By_Zero) = Enabled
        and then Op in Libadalang.Common.Ada_Op_Div
          | Libadalang.Common.Ada_Op_Mod
          | Libadalang.Common.Ada_Op_Rem
        and then Is_Static_Zero (Expr.F_Right)
      then
         Report_Rule_Violation
           (Unit, Expr.F_Right, Division_By_Zero,
            "right operand is statically zero");
      end if;

      if Rule_States (Floating_Equality) = Enabled
        and then Op in Libadalang.Common.Ada_Op_Eq
          | Libadalang.Common.Ada_Op_Neq
        and then (Is_Floating_Expression (Expr.F_Left)
                  or else Is_Floating_Expression (Expr.F_Right))
      then
         Report_Rule_Violation
           (Unit, Expr, Floating_Equality,
            "direct equality comparison on floating-point operands");
      end if;

      if Rule_States (Redundant_Boolean_Comparison) = Enabled
        and then Op in Libadalang.Common.Ada_Op_Eq
          | Libadalang.Common.Ada_Op_Neq
        and then (Is_Boolean_Literal (Expr.F_Left)
                    xor Is_Boolean_Literal (Expr.F_Right))
      then
         Report_Rule_Violation
           (Unit, Expr, Redundant_Boolean_Comparison,
            "comparison with a boolean literal can be simplified");
      end if;

      if Rule_States (Reversed_Range) = Enabled
        and then Op = Libadalang.Common.Ada_Op_Double_Dot
        and then Left_Int.Known
        and then Right_Int.Known
        and then Left_Int.Value > Right_Int.Value
      then
         Report_Rule_Violation
           (Unit, Expr, Reversed_Range,
            "range lower bound is greater than upper bound");
      end if;

      if Rule_States (Same_Operand) = Enabled
        and then Interesting_Same_Operand_Op (Op)
        and then Left_Text /= ""
        and then Left_Text = Right_Text
      then
         Report_Rule_Violation
           (Unit, Expr, Same_Operand,
            "same expression appears on both sides of the operator");
      end if;

      if Rule_States (Contradictory_Condition) = Enabled
        and then Op in Libadalang.Common.Ada_Op_And
          | Libadalang.Common.Ada_Op_And_Then
          | Libadalang.Common.Ada_Op_Or
          | Libadalang.Common.Ada_Op_Or_Else
        and then (Is_Negation_Of (Expr.F_Left, Expr.F_Right)
                  or else Is_Negation_Of (Expr.F_Right, Expr.F_Left))
      then
         Report_Rule_Violation
           (Unit, Expr, Contradictory_Condition,
            (if Op in Libadalang.Common.Ada_Op_And
               | Libadalang.Common.Ada_Op_And_Then
             then "condition is always false because it combines X and not X"
             else "condition is always true because it combines X or not X"));
      end if;

      if Rule_States (Duplicate_Boolean_Operand) = Enabled
        and then Op in Libadalang.Common.Ada_Op_And
          | Libadalang.Common.Ada_Op_And_Then
          | Libadalang.Common.Ada_Op_Or
          | Libadalang.Common.Ada_Op_Or_Else
        and then Left_Text /= ""
        and then Left_Text = Right_Text
      then
         Report_Rule_Violation
           (Unit, Expr, Duplicate_Boolean_Operand,
            "boolean expression repeats the same operand");
      end if;

      if Rule_States (Ineffective_Operation) = Enabled then
         if (Op = Libadalang.Common.Ada_Op_Plus
             and then (Is_Static_Zero (Expr.F_Left)
                       or else Is_Static_Zero (Expr.F_Right)))
           or else (Op = Libadalang.Common.Ada_Op_Minus
                    and then Is_Static_Zero (Expr.F_Right))
           or else (Op = Libadalang.Common.Ada_Op_Mult
                    and then (Is_Static_One (Expr.F_Left)
                              or else Is_Static_One (Expr.F_Right)))
           or else (Op = Libadalang.Common.Ada_Op_Div
                    and then Is_Static_One (Expr.F_Right))
           or else (Op = Libadalang.Common.Ada_Op_Pow
                    and then Is_Static_One (Expr.F_Right))
           or else (Op in Libadalang.Common.Ada_Op_And
                      | Libadalang.Common.Ada_Op_And_Then
                    and then (Boolean_Value (Expr.F_Left) = Bool_True
                              or else Boolean_Value (Expr.F_Right) = Bool_True))
           or else (Op in Libadalang.Common.Ada_Op_Or
                      | Libadalang.Common.Ada_Op_Or_Else
                    and then (Boolean_Value (Expr.F_Left) = Bool_False
                              or else Boolean_Value (Expr.F_Right) = Bool_False))
         then
            Report_Rule_Violation
              (Unit, Expr, Ineffective_Operation,
               "identity operand has no effect on the expression result");
         end if;
      end if;

      if Rule_States (Constant_Result_Operation) = Enabled then
         if (Op = Libadalang.Common.Ada_Op_Mult
             and then (Is_Static_Zero (Expr.F_Left)
                       or else Is_Static_Zero (Expr.F_Right)))
           or else (Op = Libadalang.Common.Ada_Op_Pow
                    and then Is_Static_Zero (Expr.F_Right))
           or else (Op in Libadalang.Common.Ada_Op_Mod
                      | Libadalang.Common.Ada_Op_Rem
                    and then Is_Static_One (Expr.F_Right))
           or else (Op in Libadalang.Common.Ada_Op_And
                      | Libadalang.Common.Ada_Op_And_Then
                    and then (Boolean_Value (Expr.F_Left) = Bool_False
                              or else Boolean_Value (Expr.F_Right) = Bool_False))
           or else (Op in Libadalang.Common.Ada_Op_Or
                      | Libadalang.Common.Ada_Op_Or_Else
                    and then (Boolean_Value (Expr.F_Left) = Bool_True
                              or else Boolean_Value (Expr.F_Right) = Bool_True))
         then
            Report_Rule_Violation
              (Unit, Expr, Constant_Result_Operation,
               "an absorbing operand forces this expression to a constant");
         end if;
      end if;
   end Analyze_Binary_Expression;

   --  Dead-store reasoning is valid only for an object declared inside the
   --  same subprogram. Package-level and procedure-level state may be read by
   --  callers or by other subprograms after the current body returns.
   function Is_Local_To_Subprogram
     (Decl       : Libadalang.Analysis.Basic_Decl;
      Subprogram : Libadalang.Analysis.Subp_Body) return Boolean
   is
      Ancestor : Libadalang.Analysis.Ada_Node := Decl.Parent;
   begin
      while not Libadalang.Analysis.Is_Null (Ancestor) loop
         if Ancestor.Kind = Libadalang.Common.Ada_Subp_Body then
            return Ancestor = Libadalang.Analysis.Ada_Node (Subprogram);
         end if;
         Ancestor := Ancestor.Parent;
      end loop;
      return False;
   end Is_Local_To_Subprogram;

   --  Runs Self_Assignment (target and value are textually identical),
   --  Dead_Store (a simple-object assignment with no later read in the
   --  enclosing subprogram), and Function_Side_Effect (a function body
   --  assigning to something other than its own parameters or locals) for
   --  one assignment statement.
   procedure Analyze_Assignment  --  adalang-analyzer: ignore Cyclomatic_Complexity
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Stmt : Libadalang.Analysis.Assign_Stmt)
   is
      Target_Text : constant String := Canonical_Text (Stmt.F_Dest);
      Value_Text  : constant String := Canonical_Text (Stmt.F_Expr);
   begin
      if Rule_States (Self_Assignment) = Enabled
        and then Target_Text /= ""
        and then Target_Text = Value_Text
      then
         Report_Rule_Violation
           (Unit, Stmt, Self_Assignment,
            "assignment stores an expression back into itself");
      end if;

      if Rule_States (Dead_Store) = Enabled
        and then Stmt.F_Dest.Kind = Libadalang.Common.Ada_Identifier
      then
         declare
            Decl : constant Libadalang.Analysis.Basic_Decl :=
              Assigned_Declaration (Stmt);
            Subprogram : constant Libadalang.Analysis.Subp_Body :=
              Enclosing_Subprogram (Stmt);
         begin
            if not Libadalang.Analysis.Is_Null (Decl)
              and then Decl.Kind = Libadalang.Common.Ada_Object_Decl
              and then not Libadalang.Analysis.Is_Null (Subprogram)
              and then Is_Local_To_Subprogram (Decl, Subprogram)
              and then not Has_Read_After
                (Subprogram.F_Stmts, Decl, Stmt)
            then
               Report_Rule_Violation
                 (Unit, Stmt, Dead_Store,
                  "assigned value is never read later in this subprogram");
            end if;
         end;
      end if;

      if Rule_States (Function_Side_Effect) = Enabled
        and then Stmt.F_Dest.Kind = Libadalang.Common.Ada_Identifier
      then
         declare
            Decl : constant Libadalang.Analysis.Basic_Decl :=
              Assigned_Declaration (Stmt);
            Subprogram : constant Libadalang.Analysis.Subp_Body :=
              Enclosing_Subprogram (Stmt);
         begin
            if not Libadalang.Analysis.Is_Null (Decl)
              and then not Libadalang.Analysis.Is_Null (Subprogram)
              and then not Libadalang.Analysis.Is_Null (Subprogram.F_Subp_Spec)
              and then not Libadalang.Analysis.Is_Null
                (Subprogram.F_Subp_Spec.F_Subp_Kind)
              and then Subprogram.F_Subp_Spec.F_Subp_Kind.Kind =
                Libadalang.Common.Ada_Subp_Kind_Function
              and then not Is_Local_To_Subprogram (Decl, Subprogram)
            then
               Report_Rule_Violation
                 (Unit, Stmt, Function_Side_Effect,
                  "function assigns to state outside its own parameters " &
                    "and local variables");
            end if;
         end;
      end if;
   end Analyze_Assignment;

   --  Reports Duplicate_Boolean_Operand for a double negation ("not not X"),
   --  looking through one level of parentheses around the inner operand.
   procedure Analyze_Unary_Expression
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Expr : Libadalang.Analysis.Un_Op)
   is
      Inner : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.Ada_Node (Expr.F_Expr);
   begin
      if Inner.Kind = Libadalang.Common.Ada_Paren_Expr then
         Inner := Libadalang.Analysis.Ada_Node
           (Inner.As_Paren_Expr.F_Expr);
      end if;

      if Rule_States (Duplicate_Boolean_Operand) = Enabled
        and then Expr.F_Op = Libadalang.Common.Ada_Op_Not
        and then Inner.Kind = Libadalang.Common.Ada_Un_Op
        and then Inner.As_Un_Op.F_Op = Libadalang.Common.Ada_Op_Not
      then
         Report_Rule_Violation
           (Unit, Expr, Duplicate_Boolean_Operand,
            "double negation can be simplified");
      end if;
   end Analyze_Unary_Expression;

   --  A statically evaluated case-choice range, used to detect overlapping
   --  or wholly-covered case alternatives.
   type Static_Interval is record
      Known : Boolean := False;
      Low   : Long_Long_Integer := 0;
      High  : Long_Long_Integer := 0;
   end record;

   --  The [Low, High] range covered by one case choice: a single value for
   --  a plain expression, or the statically evaluated bounds of a ".."
   --  range choice. Known is False when either bound can't be evaluated.
   function Choice_Interval
     (Choice : Libadalang.Analysis.Ada_Node'Class) return Static_Interval
   is
      Value : constant Abstract_Int := Integer_Value (Choice);
   begin
      if Value.Known then
         return (Known => True, Low => Value.Value, High => Value.Value);
      elsif Choice.Kind = Libadalang.Common.Ada_Bin_Op
        and then Choice.As_Bin_Op.F_Op =
          Libadalang.Common.Ada_Op_Double_Dot
      then
         declare
            Low  : constant Abstract_Int :=
              Integer_Value (Choice.As_Bin_Op.F_Left);
            High : constant Abstract_Int :=
              Integer_Value (Choice.As_Bin_Op.F_Right);
         begin
            if Low.Known and then High.Known then
               return (Known => True, Low => Low.Value, High => High.Value);
            end if;
         end;
      end if;

      return (Known => False, Low => 0, High => 0);
   end Choice_Interval;

   --  Compares every case choice against every earlier choice (in
   --  alternative order) to flag Overlapping_Case_Ranges (ranges that
   --  intersect) and Unreachable_Case_Alternative (a choice wholly
   --  contained in, or textually identical to, an earlier one, or any
   --  choice following an earlier "others"). Quadratic in the number of
   --  choices, which is acceptable since case statements are small.
   procedure Analyze_Case_Statement  --  adalang-analyzer: ignore Cyclomatic_Complexity
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Stmt : Libadalang.Analysis.Case_Stmt)
   is
      Alternatives : constant Libadalang.Analysis.Case_Stmt_Alternative_List :=
        Stmt.F_Alternatives;
   begin
      if Rule_States (Unreachable_Case_Alternative) /= Enabled
        and then Rule_States (Overlapping_Case_Ranges) /= Enabled
      then
         return;
      end if;

      for Current_Index in 1 .. Alternatives.Children_Count loop
         declare
            Current_Alt : constant Libadalang.Analysis.Case_Stmt_Alternative :=
              Alternatives.Child (Current_Index).As_Case_Stmt_Alternative;
         begin
            for Current_Choice of Current_Alt.F_Choices loop
               declare
                  Current_Range : constant Static_Interval :=
                    Choice_Interval (Current_Choice);
                  Is_Overlapping : Boolean := False;
                  Is_Unreachable : Boolean := False;
               begin
                  for Prior_Index in 1 .. Current_Index - 1 loop
                     declare
                        Prior_Alt : constant
                          Libadalang.Analysis.Case_Stmt_Alternative :=
                            Alternatives.Child (Prior_Index)
                              .As_Case_Stmt_Alternative;
                     begin
                        for Prior_Choice of Prior_Alt.F_Choices loop
                           declare
                              Prior_Range : constant Static_Interval :=
                                Choice_Interval (Prior_Choice);
                              Same_Choice : constant Boolean :=
                                Canonical_Text (Current_Choice) /= ""
                                and then Canonical_Text (Current_Choice) =
                                  Canonical_Text (Prior_Choice);
                           begin
                              if Prior_Choice.Kind =
                                Libadalang.Common.Ada_Others_Designator
                              then
                                 Is_Unreachable := True;
                              elsif Same_Choice then
                                 Is_Overlapping := True;
                                 Is_Unreachable := True;
                              elsif Current_Range.Known
                                and then Prior_Range.Known
                                and then Current_Range.Low <= Prior_Range.High
                                and then Prior_Range.Low <= Current_Range.High
                              then
                                 Is_Overlapping := True;
                                 if Current_Range.Low >= Prior_Range.Low
                                   and then Current_Range.High <= Prior_Range.High
                                 then
                                    Is_Unreachable := True;
                                 end if;
                              end if;
                           end;
                        end loop;
                     end;
                  end loop;

                  if Is_Overlapping
                    and then Rule_States (Overlapping_Case_Ranges) = Enabled
                  then
                     Report_Rule_Violation
                       (Unit, Current_Choice, Overlapping_Case_Ranges,
                        "case choice overlaps an earlier alternative");
                  end if;
                  if Is_Unreachable
                    and then Rule_States (Unreachable_Case_Alternative) = Enabled
                  then
                     Report_Rule_Violation
                       (Unit, Current_Choice, Unreachable_Case_Alternative,
                        "case choice is covered by an earlier alternative");
                  end if;
               end;
            end loop;
         end;
      end loop;
   end Analyze_Case_Statement;

   --  True when Node's subtree contains a statement that can end this
   --  loop: exit, return, or raise. A nested loop is not descended into,
   --  since its own exit/return/raise terminates that inner loop, not the
   --  outer one being checked by Analyze_Infinite_Loop.
   function Has_Loop_Termination
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_Exit_Stmt
            | Libadalang.Common.Ada_Return_Stmt
            | Libadalang.Common.Ada_Extended_Return_Stmt
            | Libadalang.Common.Ada_Raise_Stmt =>
            return True;

         when Libadalang.Common.Ada_For_Loop_Stmt
            | Libadalang.Common.Ada_Loop_Stmt
            | Libadalang.Common.Ada_While_Loop_Stmt =>
            --  A transfer inside a nested loop does not terminate this loop.
            return False;

         when others =>
            null;  --  adalang-analyzer: ignore Null_Statement
      end case;

      for I in 1 .. Node.Children_Count loop
         if Has_Loop_Termination (Node.Child (I)) then
            return True;
         end if;
      end loop;

      return False;
   end Has_Loop_Termination;

   --  Reports Infinite_Loop for a bare "loop" (always unconditional) or a
   --  "while" loop whose condition is statically True, when its body has
   --  no exit/return/raise. "for" loops are never unconditional (they
   --  terminate when the range is exhausted) and so are never flagged.
   procedure Analyze_Infinite_Loop
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Loop_Node : Libadalang.Analysis.Base_Loop_Stmt)
   is
      Is_Unconditional : Boolean :=
        Loop_Node.Kind = Libadalang.Common.Ada_Loop_Stmt;
   begin
      if Loop_Node.Kind = Libadalang.Common.Ada_While_Loop_Stmt then
         declare
            Spec : constant Libadalang.Analysis.Loop_Spec :=
              Loop_Node.As_While_Loop_Stmt.F_Spec;
         begin
            Is_Unconditional := not Libadalang.Analysis.Is_Null (Spec)
              and then Boolean_Value (Spec.As_While_Loop_Spec.F_Expr) =
                Bool_True;
         end;
      end if;

      if Rule_States (Infinite_Loop) = Enabled
        and then Is_Unconditional
        and then not Has_Loop_Termination (Loop_Node.F_Stmts)
      then
         Report_Rule_Violation
           (Unit, Loop_Node, Infinite_Loop,
            "unconditional loop has no explicit termination path");
      end if;
   end Analyze_Infinite_Loop;

   --  Reports Unreachable_Branch for Node, tolerating a null Node so
   --  callers can pass an absent else-part without a guard at each call
   --  site.
   procedure Report_Unreachable_Branch
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class;
      Message : String) is
   begin
      if Rule_States (Unreachable_Branch) = Enabled
        and then not Libadalang.Analysis.Is_Null (Node)
      then
         Report_Rule_Violation (Unit, Node, Unreachable_Branch, Message);
      end if;
   end Report_Unreachable_Branch;

   --  Reports Duplicate_Condition for Cond.
   procedure Report_Duplicate_Condition
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Cond : Libadalang.Analysis.Ada_Node'Class) is
   begin
      if Rule_States (Duplicate_Condition) = Enabled then
         Report_Rule_Violation
           (Unit, Cond, Duplicate_Condition,
            "condition duplicates an earlier condition in this chain");
      end if;
   end Report_Duplicate_Condition;

   --  Reports Identical_Branches when an if/elsif/else statement chain has
   --  two textually identical bodies immediately adjacent to each other
   --  (then-vs-first-elsif, elsif-vs-elsif, or last-elsif-vs-else).
   procedure Report_Identical_Statement_Branches
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Stmt : Libadalang.Analysis.If_Stmt)
   is
      Previous : Unbounded_String :=
        To_Unbounded_String (Canonical_Text (Stmt.F_Then_Stmts));
   begin
      if Rule_States (Identical_Branches) /= Enabled then
         return;
      end if;

      for Alt of Stmt.F_Alternatives loop
         declare
            Current : constant String := Canonical_Text (Alt.F_Stmts);
         begin
            if Current /= "" and then Current = To_String (Previous) then
               Report_Rule_Violation
                 (Unit, Alt.F_Stmts, Identical_Branches,
                  "branch body is identical to the preceding branch");
            end if;
            Previous := To_Unbounded_String (Current);
         end;
      end loop;

      if not Libadalang.Analysis.Is_Null (Stmt.F_Else_Part) then
         declare
            Else_Stmts : constant Libadalang.Analysis.Stmt_List :=
              Stmt.F_Else_Part.F_Stmts;
            Current : constant String := Canonical_Text (Else_Stmts);
         begin
            if Current /= "" and then Current = To_String (Previous) then
               Report_Rule_Violation
                 (Unit, Else_Stmts, Identical_Branches,
                  "else body is identical to the preceding branch");
            end if;
         end;
      end if;
   end Report_Identical_Statement_Branches;

   --  The if-expression counterpart of Report_Identical_Statement_Branches.
   procedure Report_Identical_Expression_Branches
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Expr : Libadalang.Analysis.If_Expr)
   is
      Previous : Unbounded_String :=
        To_Unbounded_String (Canonical_Text (Expr.F_Then_Expr));
   begin
      if Rule_States (Identical_Branches) /= Enabled then
         return;
      end if;

      for Alt of Expr.F_Alternatives loop
         declare
            Current : constant String := Canonical_Text (Alt.F_Then_Expr);
         begin
            if Current /= "" and then Current = To_String (Previous) then
               Report_Rule_Violation
                 (Unit, Alt.F_Then_Expr, Identical_Branches,
                  "conditional expression is identical to the preceding one");
            end if;
            Previous := To_Unbounded_String (Current);
         end;
      end loop;

      if not Libadalang.Analysis.Is_Null (Expr.F_Else_Expr) then
         declare
            Current : constant String := Canonical_Text (Expr.F_Else_Expr);
         begin
            if Current /= "" and then Current = To_String (Previous) then
               Report_Rule_Violation
                 (Unit, Expr.F_Else_Expr, Identical_Branches,
                  "else expression is identical to the preceding expression");
            end if;
         end;
      end if;
   end Report_Identical_Expression_Branches;

   --  Walks an if/elsif/else statement's condition chain to flag
   --  Duplicate_Condition (a condition textually repeating the "if" or an
   --  earlier "elsif") and Unreachable_Branch (a branch whose own
   --  condition is statically false, or that follows a branch whose
   --  condition is statically true and so always short-circuits it), then
   --  delegates to Report_Identical_Statement_Branches for body comparison.
   procedure Analyze_If_Statement  --  adalang-analyzer: ignore Cyclomatic_Complexity
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Stmt : Libadalang.Analysis.If_Stmt)
   is
      First_Cond          : constant Libadalang.Analysis.Expr :=
        Stmt.F_Cond_Expr;
      First_Text          : constant String := Canonical_Text (First_Cond);
      First_Value         : constant Abstract_Bool :=
        Boolean_Value (First_Cond);
      Alternatives        : constant Libadalang.Analysis.Elsif_Stmt_Part_List :=
        Stmt.F_Alternatives;
      Previous_Always_True : Boolean := First_Value = Bool_True;
   begin
      if First_Value = Bool_False then
         Report_Unreachable_Branch
           (Unit, Stmt.F_Then_Stmts,
            "then branch is unreachable because its condition is always false");
      end if;

      for I in 1 .. Alternatives.Children_Count loop
         declare
            Alt_Node : constant Libadalang.Analysis.Ada_Node :=
              Alternatives.Child (I);
            Alt      : constant Libadalang.Analysis.Elsif_Stmt_Part :=
              Alt_Node.As_Elsif_Stmt_Part;
            Cond     : constant Libadalang.Analysis.Expr := Alt.F_Cond_Expr;
            Cond_Text : constant String := Canonical_Text (Cond);
            Value    : constant Abstract_Bool := Boolean_Value (Cond);
         begin
            if Cond_Text /= "" and then Cond_Text = First_Text then
               Report_Duplicate_Condition (Unit, Cond);
            else
               for J in 1 .. I - 1 loop
                  declare
                     Previous : constant Libadalang.Analysis.Ada_Node :=
                       Alternatives.Child (J);
                  begin
                     if Cond_Text /= ""
                       and then Cond_Text =
                         Canonical_Text
                           (Previous.As_Elsif_Stmt_Part.F_Cond_Expr)
                     then
                        Report_Duplicate_Condition (Unit, Cond);
                        exit;  --  adalang-analyzer: ignore No_Exit
                     end if;
                  end;
               end loop;
            end if;

            if Previous_Always_True then
               Report_Unreachable_Branch
                 (Unit, Alt,
                  "elsif branch is unreachable because an earlier condition "
                  & "is always true");
            elsif Value = Bool_False then
               Report_Unreachable_Branch
                 (Unit, Alt.F_Stmts,
                  "elsif branch is unreachable because its condition is "
                  & "always false");
            elsif Value = Bool_True then
               Previous_Always_True := True;  --  adalang-analyzer: ignore Dead_Store
            end if;
         end;
      end loop;

      if Previous_Always_True
        and then not Libadalang.Analysis.Is_Null (Stmt.F_Else_Part)
      then
         Report_Unreachable_Branch
           (Unit, Stmt.F_Else_Part,
            "else branch is unreachable because an earlier condition is "
           & "always true");
      end if;

      if Rule_States (Empty_If_Body) = Enabled
        and then Alternatives.Children_Count = 0
        and then Libadalang.Analysis.Is_Null (Stmt.F_Else_Part)
        and then not Has_Substantive_Statement (Stmt.F_Then_Stmts)
      then
         Report_Rule_Violation
           (Unit, Stmt, Empty_If_Body,
            "if statement has no effect because its body is empty");
      end if;

      if Rule_States (Unnecessary_Else_After_Return) = Enabled
        and then Alternatives.Children_Count = 0
        and then not Libadalang.Analysis.Is_Null (Stmt.F_Else_Part)
        and then Stmt.F_Then_Stmts.Children_Count > 0
        and then Terminates_Statement
          (Stmt.F_Then_Stmts.Child (Stmt.F_Then_Stmts.Children_Count))
      then
         Report_Rule_Violation
           (Unit, Stmt.F_Else_Part, Unnecessary_Else_After_Return,
            "else is unnecessary because the then branch always returns, " &
              "raises, or exits");
      end if;

      Report_Identical_Statement_Branches (Unit, Stmt);
   end Analyze_If_Statement;

   --  The if-expression counterpart of Analyze_If_Statement.
   procedure Analyze_If_Expression  --  adalang-analyzer: ignore Cyclomatic_Complexity
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Expr : Libadalang.Analysis.If_Expr)
   is
      First_Cond          : constant Libadalang.Analysis.Expr :=
        Expr.F_Cond_Expr;
      First_Text          : constant String := Canonical_Text (First_Cond);
      First_Value         : constant Abstract_Bool :=
        Boolean_Value (First_Cond);
      Alternatives        : constant Libadalang.Analysis.Elsif_Expr_Part_List :=
        Expr.F_Alternatives;
      Previous_Always_True : Boolean := First_Value = Bool_True;
   begin
      if First_Value = Bool_False then
         Report_Unreachable_Branch
           (Unit, Expr.F_Then_Expr,
            "then expression is unreachable because its condition is always "
            & "false");
      end if;

      for I in 1 .. Alternatives.Children_Count loop
         declare
            Alt_Node : constant Libadalang.Analysis.Ada_Node :=
              Alternatives.Child (I);
            Alt      : constant Libadalang.Analysis.Elsif_Expr_Part :=
              Alt_Node.As_Elsif_Expr_Part;
            Cond     : constant Libadalang.Analysis.Expr := Alt.F_Cond_Expr;
            Cond_Text : constant String := Canonical_Text (Cond);
            Value    : constant Abstract_Bool := Boolean_Value (Cond);
         begin
            if Cond_Text /= "" and then Cond_Text = First_Text then
               Report_Duplicate_Condition (Unit, Cond);
            else
               for J in 1 .. I - 1 loop
                  declare
                     Previous : constant Libadalang.Analysis.Ada_Node :=
                       Alternatives.Child (J);
                  begin
                     if Cond_Text /= ""
                       and then Cond_Text =
                         Canonical_Text
                           (Previous.As_Elsif_Expr_Part.F_Cond_Expr)
                     then
                        Report_Duplicate_Condition (Unit, Cond);
                        exit;  --  adalang-analyzer: ignore No_Exit
                     end if;
                  end;
               end loop;
            end if;

            if Previous_Always_True then
               Report_Unreachable_Branch
                 (Unit, Alt,
                  "elsif expression is unreachable because an earlier "
                  & "condition is always true");
            elsif Value = Bool_False then
               Report_Unreachable_Branch
                 (Unit, Alt.F_Then_Expr,
                  "elsif expression is unreachable because its condition is "
                  & "always false");
            elsif Value = Bool_True then
               Previous_Always_True := True;  --  adalang-analyzer: ignore Dead_Store
            end if;
         end;
      end loop;

      if Previous_Always_True
        and then not Libadalang.Analysis.Is_Null (Expr.F_Else_Expr)
      then
         Report_Unreachable_Branch
           (Unit, Expr.F_Else_Expr,
            "else expression is unreachable because an earlier condition is "
            & "always true");
      end if;

      Report_Identical_Expression_Branches (Unit, Expr);
   end Analyze_If_Expression;

   --  Reports Empty_Exception_Handler for any handler with no substantive
   --  body, and Exception_Swallowed specifically for a "when others"
   --  handler with no substantive body (the narrower, more actionable
   --  case of silently discarding an unanticipated exception).
   procedure Analyze_Exception_Handler
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Handler : Libadalang.Analysis.Exception_Handler) is
   begin
      if Rule_States (Empty_Exception_Handler) = Enabled
        and then not Has_Substantive_Statement (Handler.F_Stmts)
      then
         Report_Rule_Violation
           (Unit, Handler, Empty_Exception_Handler,
            "exception handler contains no substantive statements");
      end if;

      if Rule_States (Exception_Swallowed) = Enabled then
         declare
            Handles_Others : Boolean := False;
         begin
            for Choice of Handler.F_Handled_Exceptions loop
               if Choice.Kind = Libadalang.Common.Ada_Others_Designator then
                  Handles_Others := True;  --  adalang-analyzer: ignore Dead_Store
               end if;
            end loop;

            if Handles_Others
              and then not Has_Substantive_Statement (Handler.F_Stmts)
            then
               Report_Rule_Violation
                 (Unit, Handler, Exception_Swallowed,
                  "when others handler silently discards the exception");
            end if;
         end;
      end if;
   end Analyze_Exception_Handler;

   --  Dispatches Node to the check(s) keyed on its specific syntactic
   --  kind (statement lists, operators, assignments, if/case/loop
   --  constructs, exception handlers, and so on). Called once per node
   --  from Evaluate_Node, alongside the always-run structural checks
   --  handled directly there.
   procedure Analyze_Bug_Finding_Node  --  adalang-analyzer: ignore Cyclomatic_Complexity
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
   begin
      case Node.Kind is
         when Libadalang.Common.Ada_Stmt_List =>
            Analyze_Statement_List (Unit, Node);

         when Libadalang.Common.Ada_Bin_Op_Range =>
            Analyze_Binary_Expression (Unit, Node.As_Bin_Op);

         when Libadalang.Common.Ada_Un_Op =>
            Analyze_Unary_Expression (Unit, Node.As_Un_Op);

         when Libadalang.Common.Ada_Assign_Stmt =>
            Analyze_Assignment (Unit, Node.As_Assign_Stmt);

         when Libadalang.Common.Ada_Object_Decl =>
            Analyze_Object_Declaration (Unit, Node.As_Object_Decl);

         when Libadalang.Common.Ada_Subp_Body =>
            Analyze_Subprogram (Unit, Node.As_Subp_Body);

         when Libadalang.Common.Ada_Case_Stmt =>
            Analyze_Case_Statement (Unit, Node.As_Case_Stmt);

         when Libadalang.Common.Ada_Call_Expr =>
            if Rule_States (No_Recursion) = Enabled then
               declare
                  Subprogram : constant Libadalang.Analysis.Subp_Body :=
                    Enclosing_Subprogram (Node);
               begin
                  if not Libadalang.Analysis.Is_Null (Subprogram)
                    and then Is_Direct_Recursive_Call
                      (Node.As_Call_Expr, Subprogram)
                  then
                     Report_Rule_Violation
                       (Unit, Node, No_Recursion,
                        "subprogram calls itself");
                  end if;
               end;
            end if;

         when Libadalang.Common.Ada_If_Stmt =>
            Report_Constant_Condition
              (Unit, Node.As_If_Stmt.F_Cond_Expr);
            Report_Non_Short_Circuit_Operators
              (Unit, Node.As_If_Stmt.F_Cond_Expr);
            Analyze_If_Statement (Unit, Node.As_If_Stmt);

         when Libadalang.Common.Ada_Elsif_Stmt_Part =>
            Report_Constant_Condition
              (Unit, Node.As_Elsif_Stmt_Part.F_Cond_Expr);
            Report_Non_Short_Circuit_Operators
              (Unit, Node.As_Elsif_Stmt_Part.F_Cond_Expr);

         when Libadalang.Common.Ada_If_Expr =>
            Report_Constant_Condition
              (Unit, Node.As_If_Expr.F_Cond_Expr);
            Report_Non_Short_Circuit_Operators
              (Unit, Node.As_If_Expr.F_Cond_Expr);
            Analyze_If_Expression (Unit, Node.As_If_Expr);

         when Libadalang.Common.Ada_Elsif_Expr_Part =>
            Report_Constant_Condition
              (Unit, Node.As_Elsif_Expr_Part.F_Cond_Expr);
            Report_Non_Short_Circuit_Operators
              (Unit, Node.As_Elsif_Expr_Part.F_Cond_Expr);

         when Libadalang.Common.Ada_While_Loop_Stmt =>
            declare
               Spec : constant Libadalang.Analysis.Loop_Spec :=
                 Node.As_While_Loop_Stmt.F_Spec;
            begin
               if not Libadalang.Analysis.Is_Null (Spec) then
                  Report_Constant_Condition
                    (Unit, Spec.As_While_Loop_Spec.F_Expr);
                  Report_Non_Short_Circuit_Operators
                    (Unit, Spec.As_While_Loop_Spec.F_Expr);
               end if;
               if Rule_States (Empty_Loop) = Enabled
                 and then not Has_Substantive_Statement
                   (Node.As_Base_Loop_Stmt.F_Stmts)
               then
                  Report_Rule_Violation
                    (Unit, Node, Empty_Loop,
                     "loop body contains no substantive statements");
               end if;
               Analyze_Infinite_Loop (Unit, Node.As_Base_Loop_Stmt);
            end;

         when Libadalang.Common.Ada_Exit_Stmt =>
            declare
               Cond : constant Libadalang.Analysis.Expr :=
                 Node.As_Exit_Stmt.F_Cond_Expr;
            begin
               if not Libadalang.Analysis.Is_Null (Cond) then
                  Report_Constant_Condition (Unit, Cond);
                  Report_Non_Short_Circuit_Operators (Unit, Cond);
               end if;
            end;

         when Libadalang.Common.Ada_Null_Stmt =>
            if Rule_States (Null_Statement) = Enabled then
               Report_Rule_Violation
                 (Unit, Node, Null_Statement,
                  "null statement has no executable effect");
            end if;

         when Libadalang.Common.Ada_Exception_Handler =>
            Analyze_Exception_Handler (Unit, Node.As_Exception_Handler);

         when Libadalang.Common.Ada_For_Loop_Stmt
            | Libadalang.Common.Ada_Loop_Stmt =>
            if Rule_States (Empty_Loop) = Enabled
              and then not Has_Substantive_Statement
                (Node.As_Base_Loop_Stmt.F_Stmts)
            then
               Report_Rule_Violation
                 (Unit, Node, Empty_Loop,
                  "loop body contains no substantive statements");
            end if;
            Analyze_Infinite_Loop (Unit, Node.As_Base_Loop_Stmt);

         when others =>
            null;  --  adalang-analyzer: ignore Null_Statement
      end case;
   end Analyze_Bug_Finding_Node;

   --  True when Name denotes Ada.Unchecked_Conversion, either by its fully
   --  qualified spelling or, for an unqualified "Unchecked_Conversion",
   --  by resolving the name and checking its fully qualified declaration.
   --  Falls back to the qualified-spelling check alone when resolution
   --  fails, rather than risk flagging an unrelated same-named generic.
   function Is_Ada_Unchecked_Conversion
     (Name : Libadalang.Analysis.Name'Class) return Boolean
   is
      Written_Name : constant String := Canonical_Text (Name);
   begin
      if Written_Name = "ada.unchecked_conversion" then
         return True;
      elsif Written_Name /= "unchecked_conversion" then
         return False;
      end if;

      declare
         Declaration : constant Libadalang.Analysis.Basic_Decl :=
           Name.P_Referenced_Decl;
         Full_Name   : constant String := Langkit_Support.Text.To_UTF8
           (Declaration.P_Canonical_Fully_Qualified_Name);
      begin
         return Full_Name = "ada.unchecked_conversion";
      end;
   exception
      when others =>
         --  Keep the qualified spelling useful even when resolution fails,
         --  but do not guess for an unrelated unqualified generic.
         return Written_Name = "ada.unchecked_conversion";
   end Is_Ada_Unchecked_Conversion;

   --  The single recursive AST walk that drives the whole analysis: for
   --  each node it runs the checks that only need the node's own kind
   --  (the restricted-construct rules, No_Unchecked_Conversion,
   --  Magic_Number), delegates the rest to Analyze_Bug_Finding_Node, and
   --  then recurses into every child. Every check therefore runs in a
   --  single pass over the tree rather than one pass per check.
   procedure Evaluate_Node (Unit : Libadalang.Analysis.Analysis_Unit;  --  adalang-analyzer: ignore Cyclomatic_Complexity
                           Node : Libadalang.Analysis.Ada_Node'Class) is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return;
      end if;

      --  A semantic property query below (name resolution, expression
      --  typing, ...) can raise Property_Error on constructs Libadalang's
      --  resolution engine can't fully handle. Confine that failure to
      --  this node's own checks, rather than letting it unwind out of
      --  Process_File and abandon analysis of the rest of the file.
      begin
      if Rule_States (No_Goto) = Enabled and then Node.Kind = Libadalang.Common.Ada_Goto_Stmt then
         Report_Rule_Violation (Unit, Node, No_Goto, "goto statement used");
      end if;
      if Rule_States (No_Abort) = Enabled and then Node.Kind = Libadalang.Common.Ada_Abort_Stmt then
         Report_Rule_Violation (Unit, Node, No_Abort, "abort statement used");
      end if;
      if Rule_States (No_Raise) = Enabled and then Node.Kind = Libadalang.Common.Ada_Raise_Stmt then
         Report_Rule_Violation (Unit, Node, No_Raise, "raise statement used");
      end if;
      if Rule_States (No_Exit) = Enabled and then Node.Kind = Libadalang.Common.Ada_Exit_Stmt then
         Report_Rule_Violation (Unit, Node, No_Exit, "exit statement used");
      end if;
      if Rule_States (No_Label) = Enabled and then Node.Kind = Libadalang.Common.Ada_Label then
         Report_Rule_Violation (Unit, Node, No_Label, "label used");
      end if;
      if Rule_States (No_Pragma) = Enabled
        and then Node.Kind = Libadalang.Common.Ada_Pragma_Node
        and then not Is_Generated_Config_File (Unit.Get_Filename)
      then
         Report_Rule_Violation (Unit, Node, No_Pragma, "pragma used");
      end if;
      if Rule_States (No_Access_To_Subp_Def) = Enabled and then Node.Kind = Libadalang.Common.Ada_Access_To_Subp_Def then
         Report_Rule_Violation (Unit, Node, No_Access_To_Subp_Def,
                                "access-to-subprogram type definition used");
      end if;
      if Rule_States (Address_Clause) = Enabled
        and then Node.Kind = Libadalang.Common.Ada_Attribute_Def_Clause
      then
         declare
            Clause     : constant Libadalang.Analysis.Attribute_Def_Clause :=
              Node.As_Attribute_Def_Clause;
            Attr_Expr  : constant Libadalang.Analysis.Name :=
              Clause.F_Attribute_Expr;
         begin
            if not Libadalang.Analysis.Is_Null (Attr_Expr)
              and then Attr_Expr.Kind = Libadalang.Common.Ada_Attribute_Ref
              and then Normalize_Rule_Name
                (Node_Text (Attr_Expr.As_Attribute_Ref.F_Attribute)) =
                "address"
            then
               Report_Rule_Violation
                 (Unit, Node, Address_Clause, "address clause used");
            end if;
         end;
      end if;
      if Rule_States (No_Unchecked_Conversion) = Enabled
        and then Node.Kind =
          Libadalang.Common.Ada_Generic_Subp_Instantiation
      then
         declare
            Generic_Name : constant Libadalang.Analysis.Name :=
              Node.As_Generic_Subp_Instantiation.F_Generic_Subp_Name;
         begin
            if Is_Ada_Unchecked_Conversion (Generic_Name) then
               Report_Rule_Violation
                 (Unit, Node, No_Unchecked_Conversion,
                  "Ada.Unchecked_Conversion instantiated");
            end if;
         end;
      end if;
      if Rule_States (Magic_Number) = Enabled
        and then Node.Kind in Libadalang.Common.Ada_Int_Literal
          | Libadalang.Common.Ada_Real_Literal
        and then not Is_Allowed_Magic_Number (Node)
      then
         Report_Rule_Violation
           (Unit, Node, Magic_Number,
            "numeric literal should be replaced by a named constant");
      end if;

      --  Apply node-specific checks before recursively visiting descendants.
      Analyze_Bug_Finding_Node (Unit, Node);
      exception
         when Exc : others =>
            Skipped_Nodes := Skipped_Nodes + 1;
            Log_Verbose
              ("skipping checks at " & Node.Image & ": " &
               Ada.Exceptions.Exception_Message (Exc));
      end;

      for I in 1 .. Node.Children_Count loop
         Evaluate_Node (Unit, Node.Child (I));
      end loop;
   end Evaluate_Node;

   --  Collected source file names are stored in an indefinite vector because
   --  the GPR loader below needs to grow lists whose length isn't known
   --  until the project file (and any project it extends) has been read.
   package File_Name_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type   => Positive,
      Element_Type => String);

   --  ------------------------------------------------------------------
   --  Minimal GNAT project (.gpr) file support.
   --
   --  This is a best-effort reader, not a GPR language implementation: it
   --  recognizes the literal forms "for <Attribute> use <value>;" and
   --  "extends <string>" by lexical scanning, and ignores everything else
   --  (scenario variables, case statements, package sections, "with"
   --  imports of other projects). It supports exactly the attributes
   --  needed to discover Ada source files: Source_Dirs, Source_Files,
   --  Excluded_Source_Files / Locally_Removed_Files, and project
   --  extension via "extends". Directory entries ending in "**" are
   --  walked recursively, matching GPR's recursive source dir syntax.
   --  ------------------------------------------------------------------

   function Has_Suffix (Text : String; Suffix : String) return Boolean is
   begin
      return Text'Length >= Suffix'Length
        and then Text (Text'Last - Suffix'Length + 1 .. Text'Last) = Suffix;
   end Has_Suffix;

   function Directory_Name_Of (Path : String) return String is
      Last_Slash : Natural := 0;
   begin
      for I in Path'Range loop
         if Path (I) = '/' then
            Last_Slash := I;
         end if;
      end loop;

      if Last_Slash = 0 then
         return ".";
      else
         return Path (Path'First .. Last_Slash - 1);
      end if;
   end Directory_Name_Of;

   function Join_Path (Dir : String; Name : String) return String is
   begin
      if Dir = "" or else Dir = "." then
         return Name;
      elsif Dir (Dir'Last) = '/' then
         return Dir & Name;
      else
         return Dir & "/" & Name;
      end if;
   end Join_Path;

   function Vector_Contains
     (Items : File_Name_Vectors.Vector; Item : String) return Boolean is
   begin
      for I of Items loop
         if I = Item then
            return True;
         end if;
      end loop;
      return False;
   end Vector_Contains;

   --  Adds Name, replacing any existing entry with the same simple file
   --  name. This gives an extending project's own sources priority over
   --  the same-named files inherited from the project it extends.
   procedure Append_Or_Replace_By_Simple_Name
     (Files : in out File_Name_Vectors.Vector; Name : String)
   is
      Target : constant String := Ada.Directories.Simple_Name (Name);
   begin
      for Index in File_Name_Vectors.First_Index (Files) ..
                   File_Name_Vectors.Last_Index (Files)
      loop
         if Ada.Directories.Simple_Name
              (File_Name_Vectors.Element (Files, Index)) = Target
         then
            File_Name_Vectors.Replace_Element (Files, Index, Name);
            return;
         end if;
      end loop;

      File_Name_Vectors.Append (Files, Name);
   end Append_Or_Replace_By_Simple_Name;

   --  Walks Dir (recursively when Recursive) collecting *.adb/*.ads files.
   procedure Collect_Ada_Sources  --  adalang-analyzer: ignore Cyclomatic_Complexity
     (Dir : String; Recursive : Boolean; Files : in out File_Name_Vectors.Vector)
   is
      Search : Ada.Directories.Search_Type;
      Item   : Ada.Directories.Directory_Entry_Type;
   begin
      if not Ada.Directories.Exists (Dir)
        or else Ada.Directories.Kind (Dir) /= Ada.Directories.Directory
      then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "adalang-analyzer: warning: project source directory not found: "
            & Dir);
         return;
      end if;

      Ada.Directories.Start_Search
        (Search, Dir, "*",
         (Ada.Directories.Ordinary_File => True,
          Ada.Directories.Directory     => True,
          Ada.Directories.Special_File  => False));

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);

         declare
            Name : constant String := Ada.Directories.Simple_Name (Item);
         begin
            if Ada.Directories.Kind (Item) = Ada.Directories.Directory then
               if Recursive and then Name /= "." and then Name /= ".." then
                  Collect_Ada_Sources (Join_Path (Dir, Name), True, Files);
               end if;
            elsif Has_Suffix (Name, ".adb") or else Has_Suffix (Name, ".ads")
            then
               declare
                  Full : constant String := Join_Path (Dir, Name);
               begin
                  if not Vector_Contains (Files, Full) then
                     File_Name_Vectors.Append (Files, Full);
                  end if;
               end;
            end if;
         end;
      end loop;

      Ada.Directories.End_Search (Search);
   exception
      when others =>
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "adalang-analyzer: warning: could not read directory: " & Dir);
   end Collect_Ada_Sources;

   --  A tiny lexer for the subset of GPR syntax this reader understands:
   --  identifiers, double-quoted string literals (with "" escaping), and
   --  single-character punctuation. "--" starts a comment to end of line.
   type Gpr_Token_Kind is (Gpr_Tok_Identifier, Gpr_Tok_String, Gpr_Tok_Symbol, Gpr_Tok_End);

   type Gpr_Token is record
      Kind : Gpr_Token_Kind := Gpr_Tok_End;
      Text : Unbounded_String := Null_Unbounded_String;
   end record;

   function Gpr_Ident_Equals (Left : String; Right : String) return Boolean is
   begin
      if Left'Length /= Right'Length then
         return False;
      end if;

      for I in 0 .. Left'Length - 1 loop
         if Lower_Char (Left (Left'First + I)) /=
            Lower_Char (Right (Right'First + I))
         then
            return False;
         end if;
      end loop;

      return True;
   end Gpr_Ident_Equals;

   procedure Gpr_Skip_Trivia (Text : String; Pos : in out Positive) is  --  adalang-analyzer: ignore Cyclomatic_Complexity
   begin
      loop
         if Pos > Text'Last then
            return;
         elsif Text (Pos) = ' ' or else Text (Pos) = Ada.Characters.Latin_1.HT
           or else Text (Pos) = Ada.Characters.Latin_1.LF
           or else Text (Pos) = Ada.Characters.Latin_1.CR
         then
            Pos := Pos + 1;
         elsif Pos < Text'Last and then Text (Pos) = '-'
           and then Text (Pos + 1) = '-'
         then
            while Pos <= Text'Last
              and then Text (Pos) /= Ada.Characters.Latin_1.LF
            loop
               Pos := Pos + 1;
            end loop;
         else
            return;
         end if;
      end loop;
   end Gpr_Skip_Trivia;

   function Gpr_Next_Token (Text : String; Pos : in out Positive) return Gpr_Token is
   begin
      Gpr_Skip_Trivia (Text, Pos);

      if Pos > Text'Last then
         return (Kind => Gpr_Tok_End, Text => Null_Unbounded_String);
      end if;

      if Text (Pos) in 'A' .. 'Z' | 'a' .. 'z' then
         declare
            Start : constant Positive := Pos;
         begin
            while Pos <= Text'Last
              and then Text (Pos) in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_'
            loop
               Pos := Pos + 1;
            end loop;

            return (Kind => Gpr_Tok_Identifier,
                    Text => To_Unbounded_String (Text (Start .. Pos - 1)));
         end;
      end if;

      if Text (Pos) = '"' then
         declare
            Result : Unbounded_String;
         begin
            Pos := Pos + 1;

            while Pos <= Text'Last loop
               if Text (Pos) = '"' then
                  if Pos < Text'Last and then Text (Pos + 1) = '"' then
                     Append (Result, '"');
                     Pos := Pos + 2;  --  adalang-analyzer: ignore Magic_Number
                  else
                     Pos := Pos + 1;
                     exit;  --  adalang-analyzer: ignore No_Exit
                  end if;
               else
                  Append (Result, Text (Pos));
                  Pos := Pos + 1;
               end if;
            end loop;

            return (Kind => Gpr_Tok_String, Text => Result);
         end;
      end if;

      declare
         Symbol : constant String := Text (Pos .. Pos);
      begin
         Pos := Pos + 1;
         return (Kind => Gpr_Tok_Symbol, Text => To_Unbounded_String (Symbol));
      end;
   end Gpr_Next_Token;

   --  Reads either a single string or a parenthesized, comma-separated
   --  string list, as used on the right of "use" in a GPR attribute.
   --  Anything else (a variable reference, concatenation, ...) is simply
   --  not collected, consistent with this reader's best-effort scope.
   procedure Gpr_Read_String_List
     (Text : String; Pos : in out Positive; Values : in out File_Name_Vectors.Vector)
   is
      Tok : Gpr_Token := Gpr_Next_Token (Text, Pos);
   begin
      if Tok.Kind = Gpr_Tok_String then
         File_Name_Vectors.Append (Values, To_String (Tok.Text));
      elsif Tok.Kind = Gpr_Tok_Symbol and then To_String (Tok.Text) = "(" then
         loop
            Tok := Gpr_Next_Token (Text, Pos);
            exit when Tok.Kind = Gpr_Tok_End;  --  adalang-analyzer: ignore No_Exit

            if Tok.Kind = Gpr_Tok_String then
               File_Name_Vectors.Append (Values, To_String (Tok.Text));
            elsif Tok.Kind = Gpr_Tok_Symbol and then To_String (Tok.Text) = ")" then
               exit;  --  adalang-analyzer: ignore No_Exit
            end if;
         end loop;
      end if;
   end Gpr_Read_String_List;

   --  Reads Project_File (appending ".gpr" if omitted) and appends the Ada
   --  sources it declares to Files. Seen guards against cycles and repeat
   --  work when the same project is reached through more than one path
   --  (for example, a project extended by two different entry points).
   procedure Load_Project_File  --  adalang-analyzer: ignore Cyclomatic_Complexity
     (Project_File : String;
      Files        : in out File_Name_Vectors.Vector;
      Seen         : in out File_Name_Vectors.Vector)
   is
      Actual : constant String :=
        (if Has_Suffix (Project_File, ".gpr") then Project_File
         else Project_File & ".gpr");
   begin
      if Vector_Contains (Seen, Actual) then
         return;
      end if;
      File_Name_Vectors.Append (Seen, Actual);

      if not Ada.Directories.Exists (Actual) then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "adalang-analyzer: project file not found: " & Actual);
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;

      Log_Verbose ("Reading project: " & Actual);

      declare
         Project_Dir : constant String := Directory_Name_Of (Actual);

         function Resolve (Spec : String) return String is
         begin
            if Spec = "" then
               return Project_Dir;
            elsif Spec (Spec'First) = '/' then
               return Spec;
            else
               return Join_Path (Project_Dir, Spec);
            end if;
         end Resolve;

         Input  : Ada.Text_IO.File_Type;
         Buffer : Unbounded_String;
         Pos    : Positive := 1;

         Dir_Specs      : File_Name_Vectors.Vector;
         File_Specs     : File_Name_Vectors.Vector;
         Excluded_Specs : File_Name_Vectors.Vector;
         Extends_Spec   : Unbounded_String := Null_Unbounded_String;
         Collected      : File_Name_Vectors.Vector;
      begin
         Ada.Text_IO.Open (Input, Ada.Text_IO.In_File, Actual);
         while not Ada.Text_IO.End_Of_File (Input) loop
            Append (Buffer, Ada.Text_IO.Get_Line (Input));
            Append (Buffer, Ada.Characters.Latin_1.LF);
         end loop;
         Ada.Text_IO.Close (Input);

         declare
            Source : constant String := To_String (Buffer);
         begin
            loop
               declare
                  Tok : constant Gpr_Token := Gpr_Next_Token (Source, Pos);
               begin
                  exit when Tok.Kind = Gpr_Tok_End;  --  adalang-analyzer: ignore No_Exit

                  if Tok.Kind = Gpr_Tok_Identifier
                    and then Gpr_Ident_Equals (To_String (Tok.Text), "for")
                  then
                     declare
                        Attr_Tok : constant Gpr_Token :=
                          Gpr_Next_Token (Source, Pos);
                     begin
                        if Attr_Tok.Kind = Gpr_Tok_Identifier then
                           declare
                              Use_Tok : constant Gpr_Token :=
                                Gpr_Next_Token (Source, Pos);
                           begin
                              if Use_Tok.Kind = Gpr_Tok_Identifier
                                and then Gpr_Ident_Equals
                                           (To_String (Use_Tok.Text), "use")
                              then
                                 declare
                                    Attr_Name : constant String :=
                                      To_String (Attr_Tok.Text);
                                    Values : File_Name_Vectors.Vector;
                                 begin
                                    Gpr_Read_String_List (Source, Pos, Values);

                                    if Gpr_Ident_Equals
                                         (Attr_Name, "Source_Dirs")
                                    then
                                       for V of Values loop
                                          File_Name_Vectors.Append
                                            (Dir_Specs, V);
                                       end loop;
                                    elsif Gpr_Ident_Equals
                                            (Attr_Name, "Source_Files")
                                    then
                                       for V of Values loop
                                          File_Name_Vectors.Append
                                            (File_Specs, V);
                                       end loop;
                                    elsif Gpr_Ident_Equals
                                            (Attr_Name, "Excluded_Source_Files")
                                      or else Gpr_Ident_Equals
                                                (Attr_Name,
                                                 "Locally_Removed_Files")
                                    then
                                       for V of Values loop
                                          File_Name_Vectors.Append
                                            (Excluded_Specs, V);
                                       end loop;
                                    end if;
                                 end;
                              end if;
                           end;
                        end if;
                     end;
                  elsif Tok.Kind = Gpr_Tok_Identifier
                    and then Gpr_Ident_Equals (To_String (Tok.Text), "extends")
                  then
                     declare
                        Str_Tok : constant Gpr_Token :=
                          Gpr_Next_Token (Source, Pos);
                     begin
                        if Str_Tok.Kind = Gpr_Tok_String then
                           Extends_Spec := Str_Tok.Text;
                        end if;
                     end;
                  end if;
               end;
            end loop;
         end;

         --  Follow the extension chain first so the child project's own
         --  sources can override same-named files inherited from the base.
         if Length (Extends_Spec) > 0 then
            Load_Project_File
              (Resolve (To_String (Extends_Spec)), Files, Seen);
         end if;

         if File_Name_Vectors.Is_Empty (Dir_Specs) then
            File_Name_Vectors.Append (Dir_Specs, "");
         end if;

         for Spec of Dir_Specs loop
            declare
               Recursive : Boolean := False;
               Base      : Unbounded_String := To_Unbounded_String (Spec);
            begin
               if Has_Suffix (Spec, "**") then
                  Recursive := True;  --  adalang-analyzer: ignore Dead_Store
                  Base := To_Unbounded_String
                    (Spec (Spec'First .. Spec'Last - 2));  --  adalang-analyzer: ignore Magic_Number

                  if Length (Base) > 0
                    and then Element (Base, Length (Base)) = '/'
                  then
                     Base := To_Unbounded_String
                       (Slice (Base, 1, Length (Base) - 1));
                  end if;
               end if;

               Collect_Ada_Sources
                 (Resolve (To_String (Base)), Recursive, Collected);
            end;
         end loop;

         if not File_Name_Vectors.Is_Empty (File_Specs) then
            declare
               Filtered : File_Name_Vectors.Vector;
            begin
               for F of Collected loop
                  if Vector_Contains
                       (File_Specs, Ada.Directories.Simple_Name (F))
                  then
                     File_Name_Vectors.Append (Filtered, F);
                  end if;
               end loop;
               Collected := Filtered;
            end;
         end if;

         for F of Collected loop
            if not Vector_Contains
                     (Excluded_Specs, Ada.Directories.Simple_Name (F))
            then
               Append_Or_Replace_By_Simple_Name (Files, F);
            end if;
         end loop;
      end;
   end Load_Project_File;

   --  Runs the checks that scan Filename's raw source text one line at a
   --  time rather than the parsed AST (Long_Line, Trailing_Whitespace).
   --  Running independently of Evaluate_Node lets these still report on a
   --  file that fails to parse. Any I/O failure is swallowed, same as
   --  Source_Line, since these checks are best-effort and must not abort
   --  analysis of the rest of the file.
   procedure Check_Line_Based_Rules (Filename : String) is
      File        : Ada.Text_IO.File_Type;
      Line_Number : Natural := 0;
   begin
      if Rule_States (Long_Line) /= Enabled
        and then Rule_States (Trailing_Whitespace) /= Enabled
      then
         return;
      end if;

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Filename);

      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line : constant String := Ada.Text_IO.Get_Line (File);
         begin
            Line_Number := Line_Number + 1;

            if Rule_States (Long_Line) = Enabled
              and then Line'Length > Line_Length_Threshold
            then
               Report_Line_Violation
                 (Filename    => Filename,
                  Line_Number => Line_Number,
                  Column      => Line_Length_Threshold + 1,
                  Caret_Width => Line'Length - Line_Length_Threshold,
                  Rule        => Long_Line,
                  Message     => "line length " & To_Decimal (Line'Length) &
                    " exceeds threshold " & To_Decimal (Line_Length_Threshold));
            end if;

            if Rule_States (Trailing_Whitespace) = Enabled
              and then Line'Length > 0
              and then (Line (Line'Last) = ' '
                        or else Line (Line'Last) = Ada.Characters.Latin_1.HT)
            then
               declare
                  Trimmed_Length : constant Natural :=
                    Ada.Strings.Fixed.Trim (Line, Ada.Strings.Right)'Length;
               begin
                  Report_Line_Violation
                    (Filename    => Filename,
                     Line_Number => Line_Number,
                     Column      => Trimmed_Length + 1,
                     Caret_Width => Line'Length - Trimmed_Length,
                     Rule        => Trailing_Whitespace,
                     Message     => "line has trailing whitespace");
               end;
            end if;
         end;
      end loop;

      Ada.Text_IO.Close (File);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
   end Check_Line_Based_Rules;

   --  Parses one file with Libadalang and, if it parsed cleanly, walks it
   --  with Evaluate_Node. Parse diagnostics are printed but do not stop
   --  the run; any other failure while processing this file is caught so
   --  one bad file can't abort analysis of the rest.
   procedure Process_File (Filename : String; Ctx : Libadalang.Analysis.Analysis_Context) is
      Unit : Libadalang.Analysis.Analysis_Unit;
   begin
      if not Ada.Directories.Exists (Filename) then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error,
                               "adalang-analyzer: File not found: " & Filename);
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;

      Source_File_Count := Source_File_Count + 1;
      Log_Verbose ("Parsing: " & Filename);

      Check_Line_Based_Rules (Filename);

      Unit := Ctx.Get_From_File (Filename);

      if Unit.Has_Diagnostics then
         for Diagnostic of Libadalang.Analysis.Diagnostics (Unit) loop
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               Libadalang.Analysis.Format_GNU_Diagnostic
                 (Unit, Diagnostic));
         end loop;
      else
         Evaluate_Node (Unit, Unit.Root);
      end if;

   exception
      when Exc : others =>
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error,
                               "Error processing " & Filename & ": " & Ada.Exceptions.Exception_Message (Exc));
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end Process_File;

   Files_To_Process : File_Name_Vectors.Vector;
   Project_Files    : File_Name_Vectors.Vector;
   Seen_Projects    : File_Name_Vectors.Vector;
   Argument_Count   : Natural := Ada.Command_Line.Argument_Count;
   Current_Arg      : Natural := 1;
   Options_Ended    : Boolean := False;
   Ctx              : Libadalang.Analysis.Analysis_Context;

begin
   --  Left-to-right scan of the command line: switches update the mode
   --  flags/rule states above, everything else (or anything after "--")
   --  is collected as either a project file (-P) or a source file name.
   while Current_Arg <= Argument_Count loop
      declare
         Arg : constant String := Ada.Command_Line.Argument (Current_Arg);
      begin
         if not Options_Ended then
            if Arg = "--" then
               Options_Ended := True;  --  adalang-analyzer: ignore Dead_Store
            elsif Arg = "-h" or else Arg = "--help" or else Arg = "-help" then
               Show_Help_Flag := True;
            elsif Arg = "-version" then
               Show_Version := True;
            elsif Arg = "-list-checks" or else Arg = "-list-rules" then
               List_Checks_Only := True;
            elsif Arg = "-q" or else Arg = "-quiet" then
               Quiet_Mode := True;
            elsif Arg = "-v" or else Arg = "-verbose" then
               Verbose_Mode := True;  --  adalang-analyzer: ignore Dead_Store
            elsif Arg = "-checks" then
               if Current_Arg = Argument_Count then
                  Ada.Text_IO.Put_Line ("adalang-analyzer: expected argument for -checks");
                  Invalid_Options := True;
               else
                  Parse_Checks_Option
                    ("-checks="
                     & Ada.Command_Line.Argument (Current_Arg + 1));
                  Current_Arg := Current_Arg + 1;
               end if;
            elsif Arg'Length > 8 and then Arg (Arg'First .. Arg'First + 7) = "-checks=" then  --  adalang-analyzer: ignore Magic_Number
               Parse_Checks_Option (Arg);
            elsif Arg = "-complexity-threshold" then
               if Current_Arg = Argument_Count then
                  Ada.Text_IO.Put_Line
                    ("adalang-analyzer: expected positive threshold value");
                  Invalid_Options := True;
               else
                  Set_Complexity_Threshold
                    (Ada.Command_Line.Argument (Current_Arg + 1));
                  Current_Arg := Current_Arg + 1;
               end if;
            elsif Arg'Length > 22  --  adalang-analyzer: ignore Magic_Number
              and then Arg (Arg'First .. Arg'First + 21) =  --  adalang-analyzer: ignore Magic_Number
                "-complexity-threshold="
            then
               Set_Complexity_Threshold
                 (Arg (Arg'First + 22 .. Arg'Last));  --  adalang-analyzer: ignore Magic_Number
            elsif Arg = "-nesting-threshold" then
               if Current_Arg = Argument_Count then
                  Ada.Text_IO.Put_Line
                    ("adalang-analyzer: expected positive threshold value");
                  Invalid_Options := True;
               else
                  Set_Nesting_Threshold
                    (Ada.Command_Line.Argument (Current_Arg + 1));
                  Current_Arg := Current_Arg + 1;
               end if;
            elsif Arg'Length > 19  --  adalang-analyzer: ignore Magic_Number
              and then Arg (Arg'First .. Arg'First + 18) =  --  adalang-analyzer: ignore Magic_Number
                "-nesting-threshold="
            then
               Set_Nesting_Threshold
                 (Arg (Arg'First + 19 .. Arg'Last));  --  adalang-analyzer: ignore Magic_Number
            elsif Arg = "-parameter-threshold" then
               if Current_Arg = Argument_Count then
                  Ada.Text_IO.Put_Line
                    ("adalang-analyzer: expected positive threshold value");
                  Invalid_Options := True;
               else
                  Set_Parameter_Threshold
                    (Ada.Command_Line.Argument (Current_Arg + 1));
                  Current_Arg := Current_Arg + 1;
               end if;
            elsif Arg'Length > 21  --  adalang-analyzer: ignore Magic_Number
              and then Arg (Arg'First .. Arg'First + 20) =  --  adalang-analyzer: ignore Magic_Number
                "-parameter-threshold="
            then
               Set_Parameter_Threshold
                 (Arg (Arg'First + 21 .. Arg'Last));  --  adalang-analyzer: ignore Magic_Number
            elsif Arg = "-line-length-threshold" then
               if Current_Arg = Argument_Count then
                  Ada.Text_IO.Put_Line
                    ("adalang-analyzer: expected positive threshold value");
                  Invalid_Options := True;
               else
                  Set_Line_Length_Threshold
                    (Ada.Command_Line.Argument (Current_Arg + 1));
                  Current_Arg := Current_Arg + 1;
               end if;
            elsif Arg'Length > 23  --  adalang-analyzer: ignore Magic_Number
              and then Arg (Arg'First .. Arg'First + 22) =  --  adalang-analyzer: ignore Magic_Number
                "-line-length-threshold="
            then
               Set_Line_Length_Threshold
                 (Arg (Arg'First + 23 .. Arg'Last));  --  adalang-analyzer: ignore Magic_Number
            elsif Arg = "-P" then
               if Current_Arg = Argument_Count then
                  Ada.Text_IO.Put_Line ("adalang-analyzer: expected argument for -P");
                  Invalid_Options := True;
               else
                  File_Name_Vectors.Append
                    (Project_Files, Ada.Command_Line.Argument (Current_Arg + 1));
                  Current_Arg := Current_Arg + 1;
               end if;
            elsif Arg'Length > 2 and then Arg (Arg'First .. Arg'First + 1) = "-P" then  --  adalang-analyzer: ignore Magic_Number
               File_Name_Vectors.Append
                 (Project_Files, Arg (Arg'First + 2 .. Arg'Last));  --  adalang-analyzer: ignore Magic_Number
            elsif Arg (Arg'First) = '+' or else Arg (Arg'First) = '-' then
               if Arg'Length > 2 and then Arg (Arg'First + 1) = 'R' then  --  adalang-analyzer: ignore Magic_Number
                  Process_Command_Switch (Arg);
               else
                  Ada.Text_IO.Put_Line ("adalang-analyzer: unknown option '" & Arg & "'");
                  Invalid_Options := True;
               end if;
            else
               File_Name_Vectors.Append (Files_To_Process, Arg);
            end if;
         else
            File_Name_Vectors.Append (Files_To_Process, Arg);
         end if;
      end;
      Current_Arg := Current_Arg + 1;  --  adalang-analyzer: ignore Dead_Store
   end loop;

   if Show_Help_Flag then
      Show_Help;
      return;
   elsif Show_Version then
      Print_Version;
      return;
   elsif Invalid_Options then
      Show_Help;
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   elsif List_Checks_Only then
      Print_Check_List;
      return;
   end if;

   --  Project files contribute their own Ada sources on top of any file
   --  names given directly on the command line.
   for P of Project_Files loop
      Load_Project_File (P, Files_To_Process, Seen_Projects);
   end loop;

   if File_Name_Vectors.Is_Empty (Files_To_Process) then
      if Argument_Count > 0 then
         -- Options were provided, but no files
         null;  --  adalang-analyzer: ignore Null_Statement
      else
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error,
                               "adalang-analyzer: error: no source files provided.");
         Show_Help;
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      end if;
      return;
   end if;

   Ctx := Libadalang.Analysis.Create_Context;

   for F of Files_To_Process loop
      Process_File (F, Ctx);
   end loop;

   if not Quiet_Mode then
      Ada.Text_IO.New_Line;
      Ada.Text_IO.Put_Line ("Files scanned : " & To_Decimal (Source_File_Count));
      Ada.Text_IO.Put_Line ("Violations    : " & To_Decimal (Violations));

      if Skipped_Nodes > 0 then
         --  Surfaced even without -verbose: a nonzero count here means
         --  checks were silently incomplete at some source locations, not
         --  just noisy diagnostics, so it belongs in the default summary.
         Ada.Text_IO.Put_Line
           ("Skipped checks: " & To_Decimal (Skipped_Nodes) &
            " location(s) (semantic resolution limits; rerun with -v for" &
            " details)");
      end if;

      if Violations > 0 then
         Ada.Text_IO.Put_Line ("");
         Ada.Text_IO.Put_Line ("Violations by check:");

         for Rule in Rule_Kind loop
            if Rule_Violations (Rule) > 0 then
               Ada.Text_IO.Put_Line
                 ("  " & Ada.Strings.Unbounded.To_String (Rule_Infos (Rule).Name) &
                  " : " & To_Decimal (Rule_Violations (Rule)) & "  [" &
                  Quality_Name (Rule_Infos (Rule).Quality) & "/" &
                  Severity_Name (Rule_Infos (Rule).Severity) & "]");
            end if;
         end loop;

         Ada.Text_IO.Put_Line ("");
         Ada.Text_IO.Put_Line ("Violations by software quality:");

         for Quality in Software_Quality loop
            declare
               Quality_Total : Natural := 0;
            begin
               for Rule in Rule_Kind loop
                  if Rule_Infos (Rule).Quality = Quality then
                     Quality_Total := Quality_Total + Rule_Violations (Rule);
                  end if;
               end loop;

               if Quality_Total > 0 then
                  Ada.Text_IO.Put_Line
                    ("  " & Quality_Name (Quality) & " : " &
                     To_Decimal (Quality_Total));
               end if;
            end;
         end loop;

         Ada.Text_IO.Put_Line ("");
         Ada.Text_IO.Put_Line ("Violations by severity:");

         for Severity in Issue_Severity loop
            declare
               Severity_Total : Natural := 0;
            begin
               for Rule in Rule_Kind loop
                  if Rule_Infos (Rule).Severity = Severity then
                     Severity_Total := Severity_Total + Rule_Violations (Rule);
                  end if;
               end loop;

               if Severity_Total > 0 then
                  Ada.Text_IO.Put_Line
                    ("  " & Severity_Name (Severity) & " : " &
                     To_Decimal (Severity_Total));
               end if;
            end;
         end loop;
      end if;
   end if;

   if Violations > 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;

exception
   when E : others =>
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error,
                            "Internal error: " & Ada.Exceptions.Exception_Information (E));
      Ada.Command_Line.Set_Exit_Status (2);  --  adalang-analyzer: ignore Magic_Number
end Adalang_Analyzer;
