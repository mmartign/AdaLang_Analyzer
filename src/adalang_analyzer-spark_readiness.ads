--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  Developed, validated, and maintained by Spazio IT.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Libadalang.Analysis;

--  Lightweight SPARK Bronze/readiness checks. This package deliberately
--  checks properties that can be established from Libadalang's semantic AST
--  without attempting to reproduce GNATprove's proof engine.
package Adalang_Analyzer.SPARK_Readiness is

   procedure Analyze_Subprogram
     (Unit       : Libadalang.Analysis.Analysis_Unit;
      Subprogram : Libadalang.Analysis.Subp_Body);

   function Effective_SPARK_Enabled
     (Decl : Libadalang.Analysis.Basic_Decl'Class) return Boolean;
   --  False when Decl, or the nearest enclosing unit that says, has
   --  SPARK_Mode Off.

   function Contract_Expression
     (Decl : Libadalang.Analysis.Basic_Decl'Class;
      Name : String) return Libadalang.Analysis.Expr;
   --  The expression of the aspect Name of Decl, looked for on the
   --  declaration of a subprogram body too. Null when there is none.

   procedure Check_Discriminant_Access
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Dotted_Name'Class);
   --  Reports Known_Discriminant_Check_Failure when Node selects a
   --  variant-part component that a statically known discriminant
   --  constraint on its prefix object provably excludes.

   function Discriminant_Access_Proved
     (Node : Libadalang.Analysis.Dotted_Name'Class) return Boolean;
   --  True when Node selects a variant-part component of an object whose
   --  own static discriminant constraint provably selects that component's
   --  variant, with the prefix object resolved without imprecise fallback.
   --  A constrained object's discriminants cannot change, so the access
   --  can never fail its discriminant check.

end Adalang_Analyzer.SPARK_Readiness;
