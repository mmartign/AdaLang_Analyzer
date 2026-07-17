--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--  Modified by Spazio IT in 2026.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Libadalang.Analysis;

--  Statement- and control-flow-level checks: statement lists (Unreachable_
--  Code, Repeated_Statement, Overwritten_Assignment), assignments
--  (Self_Assignment, Dead_Store, Function_Side_Effect), case statements,
--  infinite loops, if/elsif/else chains (Duplicate_Condition,
--  Unreachable_Branch, Identical_Branches, Empty_If_Body,
--  Unnecessary_Else_After_Return), and exception handlers. Private to the
--  Checks subsystem.
private package Adalang_Analyzer.Checks.Control_Flow is

   function Has_Substantive_Statement
     (List : Libadalang.Analysis.Stmt_List) return Boolean;
   --  True when List contains anything other than null statements and
   --  pragmas, i.e. it does real work. Shared by Empty_Loop, Empty_If_Body,
   --  and the exception-handler checks; also used directly by
   --  Adalang_Analyzer.Checks for the inline Empty_Loop check on loop
   --  statements.

   procedure Analyze_Statement_List
     (Unit : Libadalang.Analysis.Analysis_Unit;
      List : Libadalang.Analysis.Ada_Node'Class);
   --  Walks one statement list in source order for three intraprocedural,
   --  single-pass checks: Unreachable_Code (anything after an
   --  unconditional transfer of control, until a label resets
   --  reachability), Repeated_Statement (an assignment textually
   --  identical to the one immediately before it), and
   --  Overwritten_Assignment (an assignment to the same object recurring
   --  later in this same list before any intervening read).

   procedure Analyze_Assignment
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Stmt : Libadalang.Analysis.Assign_Stmt);
   --  Runs Self_Assignment (target and value are textually identical),
   --  Dead_Store (a simple-object assignment with no later read in the
   --  enclosing subprogram), and Function_Side_Effect (a function body
   --  assigning to something other than its own parameters or locals) for
   --  one assignment statement.

   procedure Analyze_Call_Statement
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Stmt : Libadalang.Analysis.Call_Stmt);
   --  Reports Dead_Store when a local simple object receives an out/in-out
   --  result from a call and that result is never subsequently read.

   procedure Analyze_Case_Statement
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Stmt : Libadalang.Analysis.Case_Stmt);
   --  Compares every case choice against every earlier choice to flag
   --  Overlapping_Case_Ranges and Unreachable_Case_Alternative.

   procedure Analyze_Infinite_Loop
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Loop_Node : Libadalang.Analysis.Base_Loop_Stmt);
   --  Reports Infinite_Loop for a bare "loop" (always unconditional) or a
   --  "while" loop whose condition is statically True, when its body has
   --  no exit/return/raise.

   procedure Analyze_If_Statement
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Stmt : Libadalang.Analysis.If_Stmt);
   --  Walks an if/elsif/else statement's condition chain to flag
   --  Duplicate_Condition and Unreachable_Branch, and its bodies for
   --  Identical_Branches, Empty_If_Body, and Unnecessary_Else_After_Return.

   procedure Analyze_If_Expression
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Expr : Libadalang.Analysis.If_Expr);
   --  The if-expression counterpart of Analyze_If_Statement.

   procedure Analyze_Exception_Handler
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Handler : Libadalang.Analysis.Exception_Handler);
   --  Reports Empty_Exception_Handler for any handler with no substantive
   --  body, and Exception_Swallowed specifically for a "when others"
   --  handler with no substantive body.

end Adalang_Analyzer.Checks.Control_Flow;
