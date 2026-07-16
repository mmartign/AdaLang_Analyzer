--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--  Modified by Spazio IT in 2026.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Libadalang.Analysis;

--  Checks keyed on a single binary or unary operator expression: division
--  by zero, floating equality, reversed ranges, duplicate/contradictory
--  operands, and identity/absorbing-operand simplifications. Private to
--  the Checks subsystem.
private package Adalang_Analyzer.Checks.Expressions is

   procedure Analyze_Binary_Expression
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Expr : Libadalang.Analysis.Bin_Op);
   --  Runs every check keyed on a binary operator: Division_By_Zero,
   --  Floating_Equality, Reversed_Range, Same_Operand,
   --  Contradictory_Condition, Duplicate_Boolean_Operand,
   --  Ineffective_Operation (an identity operand that doesn't change the
   --  result, e.g. "X + 0"), and Constant_Result_Operation (an absorbing
   --  operand that forces a fixed result, e.g. "X * 0" or "X and False").

   procedure Analyze_Unary_Expression
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Expr : Libadalang.Analysis.Un_Op);
   --  Reports Duplicate_Boolean_Operand for a double negation ("not not X"),
   --  looking through one level of parentheses around the inner operand.

end Adalang_Analyzer.Checks.Expressions;
